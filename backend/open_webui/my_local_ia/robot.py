"""Finds new models on Hugging Face and adds them to the catalog ("auto" entries).

Port of the original site's scripts/update-models.mjs. Sizes come from the
parameter count published on Hugging Face (GGUF: Q4_K_M ≈ 0.6 GB per billion;
audio and embeddings: FP16 = 2 GB per billion); the speed for this server is
then computed by estimate.py like for any other entry. Descriptions are built
from the model card only (no AI), so they are factual but short.
"""

import asyncio
import logging
import re
import time
from datetime import datetime
from typing import Optional

import aiohttp
from open_webui.internal.db import get_async_db
from open_webui.models.config import Config
from open_webui.my_local_ia.catalog import CatalogEntry
from open_webui.my_local_ia.settings import Settings, get_settings
from open_webui.utils.session_pool import get_session
from sqlalchemy import delete, select

log = logging.getLogger(__name__)

API = 'https://huggingface.co/api/models'
STATUS_KEY = 'my_local_ia.robot.status'  # {last_run, added, total, error}
TIMEOUT = aiohttp.ClientTimeout(total=60)

# Hugging Face task → catalog category
TASKS = {
    'text-generation': 'text',
    'image-text-to-text': 'text',
    'text-to-image': 'img',
    'image-to-image': 'img',
    'text-to-video': 'vid',
    'image-to-video': 'vid',
    'automatic-speech-recognition': 'stt',
    'text-to-speech': 'tts',
    'feature-extraction': 'emb',
    'sentence-similarity': 'emb',
}
TRENDING_TASKS = ['automatic-speech-recognition', 'text-to-speech', 'feature-extraction', 'sentence-similarity']
GB_PER_BILLION = {'gguf': 0.6, 'safetensors': 2.0}

_run_lock = asyncio.Lock()

####################
# Descriptions
####################

KIND = {
    'chat': {'en': 'Text model', 'pt-BR': 'Modelo de texto', 'es': 'Modelo de texto'},
    'code': {'en': 'Code model', 'pt-BR': 'Modelo de código', 'es': 'Modelo de código'},
    'vis': {'en': 'Vision and text model', 'pt-BR': 'Modelo de visão e texto', 'es': 'Modelo de visión y texto'},
    'img': {'en': 'Image model', 'pt-BR': 'Modelo de imagem', 'es': 'Modelo de imagen'},
    'vid': {'en': 'Video model', 'pt-BR': 'Modelo de vídeo', 'es': 'Modelo de video'},
    'stt': {
        'en': 'Transcription model (speech to text)',
        'pt-BR': 'Modelo de transcrição (fala → texto)',
        'es': 'Modelo de transcripción (voz → texto)',
    },
    'tts': {
        'en': 'Voice model (text to speech)',
        'pt-BR': 'Modelo de voz (texto → fala)',
        'es': 'Modelo de voz (texto → voz)',
    },
    'emb': {'en': 'Embeddings model', 'pt-BR': 'Modelo de embeddings', 'es': 'Modelo de embeddings'},
}
USE_FOR = {
    'chat': {'en': 'Chat and general tasks', 'pt-BR': 'Chat e tarefas gerais', 'es': 'Chat y tareas generales'},
    'reasoning': {
        'en': 'Reasoning, math, logic',
        'pt-BR': 'Raciocínio, matemática, lógica',
        'es': 'Razonamiento, matemáticas, lógica',
    },
    'code': {
        'en': 'Programming, autocomplete, coding agents',
        'pt-BR': 'Programação, autocomplete, agentes de código',
        'es': 'Programación, autocompletado, agentes de código',
    },
    'vis': {
        'en': 'Reading images, screenshots and documents',
        'pt-BR': 'Ler imagens, prints e documentos',
        'es': 'Leer imágenes, capturas y documentos',
    },
    'img': {
        'en': 'Generating and editing images',
        'pt-BR': 'Gerar e editar imagens',
        'es': 'Generar y editar imágenes',
    },
    'vid': {'en': 'Generating short videos', 'pt-BR': 'Gerar vídeos curtos', 'es': 'Generar videos cortos'},
    'stt': {
        'en': 'Transcribing audio, meetings and videos',
        'pt-BR': 'Transcrever áudios, reuniões e vídeos',
        'es': 'Transcribir audios, reuniones y videos',
    },
    'tts': {
        'en': 'Narration, reading texts aloud, voice assistants',
        'pt-BR': 'Narração, leitura de textos, assistentes de voz',
        'es': 'Narración, lectura de textos, asistentes de voz',
    },
    'emb': {
        'en': 'Document search and RAG',
        'pt-BR': 'Busca em documentos e RAG',
        'es': 'Búsqueda en documentos y RAG',
    },
}
PHRASES = {
    'by': {'en': ' by {maker}', 'pt-BR': ' criado por {maker}', 'es': ' creado por {maker}'},
    'size': {'en': ' with {size}', 'pt-BR': ' com {size}', 'es': ' con {size}'},
    'params': {'en': '{n}B parameters', 'pt-BR': '{n}B parâmetros', 'es': '{n}B parámetros'},
    'params_m': {'en': '{n}M parameters', 'pt-BR': '{n}M parâmetros', 'es': '{n}M parámetros'},
    'moe': {
        'en': ' (MoE, ~{n}B active per token)',
        'pt-BR': ' (MoE, ~{n}B ativos por token)',
        'es': ' (MoE, ~{n}B activos por token)',
    },
    'extra_parts': {
        'en': ' Besides it, the text encoder and the VAE are needed.',
        'pt-BR': ' Além dele, precisa do codificador de texto e do VAE.',
        'es': ' Además, necesita el codificador de texto y el VAE.',
    },
    'context': {
        'en': ' Context of up to {n}K tokens.',
        'pt-BR': ' Contexto de até {n} mil tokens.',
        'es': ' Contexto de hasta {n} mil tokens.',
    },
    'pt': {'en': ' Supports Portuguese.', 'pt-BR': ' Suporta português.', 'es': ' Admite portugués.'},
    'es_lang': {'en': ' Supports Spanish.', 'pt-BR': ' Suporta espanhol.', 'es': ' Admite español.'},
    'en_only': {'en': ' Focused on English.', 'pt-BR': ' Focado em inglês.', 'es': ' Enfocado en inglés.'},
    'license': {'en': ' License {lic}: {rule}.', 'pt-BR': ' Licença {lic}: {rule}.', 'es': ' Licencia {lic}: {rule}.'},
    'commercial': {'en': 'commercial use allowed', 'pt-BR': 'permite uso comercial', 'es': 'permite uso comercial'},
    'non_commercial': {
        'en': 'non-commercial use only',
        'pt-BR': 'só para uso não comercial',
        'es': 'solo para uso no comercial',
    },
    'own_rules': {
        'en': 'own terms; check before commercial use',
        'pt-BR': 'tem regras próprias; confira antes de uso comercial',
        'es': 'tiene reglas propias; revísala antes de uso comercial',
    },
}
LANGS = ('en', 'pt-BR', 'es')


def phrase(key: str, lang: str, **values) -> str:
    return PHRASES[key][lang].format(**values)


def size_text(params_b: float, lang: str) -> str:
    if params_b >= 10:
        n = str(round(params_b))
    elif params_b >= 1:
        n = f'{params_b:.1f}'.replace('.', ',') if lang != 'en' else f'{params_b:.1f}'
    else:
        return phrase('params_m', lang, n=round(params_b * 1000))
    return phrase('params', lang, n=n)


def classify(name: str, hf_task: str) -> tuple[str, bool]:
    """(category, reasoning) for text models; other groups map directly."""
    group = TASKS[hf_task]
    if group != 'text':
        return group, False
    code = bool(re.search(r'coder|code|devstral', name, re.I))
    vision = not code and (hf_task == 'image-text-to-text' or bool(re.search(r'vl|vision', name, re.I)))
    reasoning = bool(re.search(r'r1\b|think|reason|qwq|magistral', name, re.I))
    return ('code' if code else 'vis' if vision else 'chat'), reasoning


def active_ratio_from_name(model_id: str, params_b: float) -> float:
    match = re.search(r'A(\d+(?:\.\d+)?)B', model_id, re.I)  # MoE: "35B-A3B"
    if match and params_b:
        return round(min(1.0, float(match.group(1)) / params_b), 3)
    return 1.0


def describe(
    info: dict, model_id: str, category: str, reasoning: bool, params_b: float, ratio: float, weights: str
) -> tuple[dict, dict]:
    card = info.get('cardData') or {}
    base = ([card.get('base_model')] if isinstance(card.get('base_model'), str) else card.get('base_model') or [None])[
        0
    ]
    maker = base.split('/')[0] if base else (info.get('author') if weights == 'safetensors' else None)
    langs = [
        str(lang).lower()
        for lang in ([card['language']] if isinstance(card.get('language'), str) else card.get('language') or [])
    ]
    license_name = card.get('license_name') or card.get('license')
    ctx = (info.get('gguf') or {}).get('context_length')

    description, use_for = {}, {}
    for lang in LANGS:
        text = KIND[category][lang]
        if maker:
            text += phrase('by', lang, maker=maker)
        text += phrase('size', lang, size=size_text(params_b, lang))
        if ratio < 1:
            text += phrase('moe', lang, n=round(params_b * ratio, 1))
        text += '.'
        if category in ('img', 'vid'):
            text += phrase('extra_parts', lang)
        if ctx:
            text += phrase('context', lang, n=round(ctx / 1024))
        if any(lang_code.startswith('pt') or lang_code == 'portuguese' for lang_code in langs):
            text += phrase('pt', lang)
        if any(lang_code.startswith('es') or lang_code == 'spanish' for lang_code in langs):
            text += phrase('es_lang', lang)
        if langs == ['en']:
            text += phrase('en_only', lang)
        if license_name:
            if re.search(r'nc|non-commercial', license_name, re.I):
                rule = PHRASES['non_commercial'][lang]
            elif re.fullmatch(r'apache-2\.0|mit|bsd.*|cc-by-4\.0', license_name, re.I):
                rule = PHRASES['commercial'][lang]
            else:
                rule = PHRASES['own_rules'][lang]
            text += phrase('license', lang, lic=license_name, rule=rule)
        description[lang] = text
        use_key = 'reasoning' if (category == 'chat' and reasoning) else category
        use_for[lang] = USE_FOR[use_key][lang]
    return description, use_for


def slug(text: str) -> str:
    return re.sub(r'[^a-z0-9]+', '-', text.lower()).strip('-')


def display_name(model_id: str) -> str:
    name = model_id.split('/')[1]
    name = re.sub(r'[-_.]?GGUF$', '', name, flags=re.I)
    return re.sub(r'[-_]', ' ', name)


####################
# Fetch
####################


async def get_json(url: str):
    session = await get_session()
    async with session.get(url, timeout=TIMEOUT) as r:
        r.raise_for_status()
        return await r.json()


def sources(settings: Settings) -> list[tuple[str, str]]:
    urls = [
        (f'{API}?author={author}&filter=gguf&sort=createdAt&direction=-1&limit=100', 'gguf')
        for author in settings.robot_sources
    ]
    if settings.robot_trending_audio_embeddings:
        urls += [
            (f'{API}?pipeline_tag={task}&sort=trendingScore&direction=-1&limit=40', 'safetensors')
            for task in TRENDING_TASKS
        ]
    return urls


async def find_models(settings: Settings) -> list[dict]:
    """Candidate catalog rows from Hugging Face, newest first."""
    seen, found = set(), []
    for url, weights in sources(settings):
        try:
            results = await get_json(url)
        except Exception as e:
            log.warning(f'my-local-ia robot: {url}: {e}')
            continue
        for item in results:
            hf_task = item.get('pipeline_tag')
            if hf_task not in TASKS or (item.get('downloads') or 0) < settings.robot_min_downloads:
                continue
            model_id = item['id']
            name = display_name(model_id)
            key = re.sub(r'[^a-z0-9]', '', name.lower())
            if key in seen:  # same model published by more than one converter
                continue
            seen.add(key)
            try:
                info = await get_json(f'{API}/{model_id}')
            except Exception:
                continue
            params_b = ((info.get(weights) or {}).get('total') or 0) / 1e9
            if not params_b:  # without a parameter count the size cannot be estimated
                continue
            category, reasoning = classify(name, hf_task)
            ratio = active_ratio_from_name(model_id, params_b) if TASKS[hf_task] == 'text' else 1.0
            description, use_for = describe(info, model_id, category, reasoning, params_b, ratio, weights)
            is_gguf_text = weights == 'gguf' and category in ('chat', 'code', 'vis')
            found.append(
                {
                    'id': f'hf-{slug(model_id)}',
                    'name': name,
                    'category': category,
                    'size_gb': round(params_b * GB_PER_BILLION[weights], 1),
                    'active_ratio': ratio,
                    'reasoning': reasoning,
                    'description': description,
                    'use_for': use_for,
                    # Ollama pulls GGUF repositories straight from Hugging Face.
                    'ollama': f'hf.co/{model_id}' if is_gguf_text else None,
                    'meta': {
                        'hf_id': model_id,
                        'created': item.get('createdAt') or '',
                        'downloads': item.get('downloads'),
                    },
                }
            )
    found.sort(key=lambda m: m['meta']['created'], reverse=True)
    return found[: settings.robot_max_models]


####################
# Save and schedule
####################


def known_key(name: str) -> str:
    return re.sub(r'gguf|instruct|\bit\b|[^a-z0-9]', '', name.lower())


async def save(found: list[dict]) -> int:
    """Replaces the auto entries; skips models already in the curated catalog. Returns how many are new."""
    now = int(time.time())
    async with get_async_db() as db:
        rows = (await db.execute(select(CatalogEntry))).scalars().all()
        curated = {known_key(r.name) for r in rows if r.source == 'curated'}
        previous = {r.id: r for r in rows if r.source == 'auto'}
        keep, added = set(), 0
        for item in found:
            if known_key(item['name']) in curated:
                continue
            keep.add(item['id'])
            row = previous.get(item['id'])
            if row is None:
                added += 1
                item['meta']['added'] = now
                db.add(CatalogEntry(source='auto', unsure=False, whisper=None, created_at=now, updated_at=now, **item))
            else:
                item['meta']['added'] = (row.meta or {}).get('added', now)
                for key, value in item.items():
                    setattr(row, key, value)
                row.updated_at = now
        gone = [rid for rid in previous if rid not in keep]
        if gone:
            await db.execute(delete(CatalogEntry).where(CatalogEntry.id.in_(gone)))
        await db.commit()
    return added


async def run(settings: Optional[Settings] = None) -> dict:
    async with _run_lock:
        settings = settings or await get_settings()
        status = {'last_run': int(time.time()), 'added': 0, 'total': 0, 'error': None}
        try:
            found = await find_models(settings)
            status['added'] = await save(found)
            status['total'] = len(found)
        except Exception as e:
            log.exception(f'my-local-ia robot failed: {e}')
            status['error'] = str(e)
        await Config.upsert({STATUS_KEY: status})
        log.info(f'my-local-ia robot: {status["total"]} models found, {status["added"]} new')
        return status


async def get_status() -> dict:
    return await Config.get(STATUS_KEY) or {}


def is_due(settings: Settings, last_run: Optional[int], now: Optional[datetime] = None) -> bool:
    """Daily or weekly, at robot_time (server local time), once per period."""
    if not settings.robot_enabled or settings.robot_frequency == 'manual':
        return False
    now = now or datetime.now()
    hour, minute = map(int, settings.robot_time.split(':'))
    scheduled = now.replace(hour=hour, minute=minute, second=0, microsecond=0)
    if now < scheduled:
        return False
    period = 7 * 86400 if settings.robot_frequency == 'weekly' else 86400
    return last_run is None or now.timestamp() - last_run >= period - 3600

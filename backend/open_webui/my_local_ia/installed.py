"""Models installed in Ollama: what they are, how they run here, who uses them.

Any installed model gets an estimate, not only the ones in the catalog: size,
capabilities and MoE expert counts come from Ollama itself (/api/tags and
/api/show).
"""

import logging
import time
from typing import Optional

from open_webui.internal.db import get_async_db
from open_webui.models.chat_messages import ChatMessage
from open_webui.models.config import Config
from open_webui.my_local_ia import ollama
from open_webui.my_local_ia.catalog import CatalogEntries, CatalogEntryModel, get_hardware
from open_webui.my_local_ia.estimate import Estimate, estimate
from open_webui.my_local_ia.settings import get_settings
from pydantic import BaseModel
from sqlalchemy import func, select

log = logging.getLogger(__name__)

DOWNLOADS_KEY = 'my_local_ia.downloads'  # {model name: {user_id, user_name, at}}

# In a MoE model the experts hold most, but not all, of the weights (attention and
# embeddings are shared). With this share, gpt-oss-20b (4 of 32 experts) comes out
# at ~17% active and Qwen3-30B-A3B (8 of 128) at ~11%, close to their real values.
EXPERT_SHARE = 0.95


class InstalledModel(BaseModel):
    name: str
    size_gb: float
    parameter_size: Optional[str] = None
    quantization: Optional[str] = None
    family: Optional[str] = None
    category: str
    reasoning: bool = False
    active_ratio: float = 1.0
    catalog_id: Optional[str] = None
    estimate: Estimate
    last_used: Optional[int] = None  # epoch seconds of the last answer
    uses_30d: int = 0  # answers in the last 30 days
    downloaded_by: Optional[dict] = None
    protected: Optional[str] = None  # why it cannot be removed, if it cannot
    suggestion: Optional[str] = None  # unused | rarely_used | heavy


def base_name(name: str) -> str:
    return name[: -len(':latest')] if name.endswith(':latest') else name


def active_ratio_from(model_info: dict) -> float:
    count = used = 0
    for key, value in model_info.items():
        if key.endswith('.expert_count'):
            count = value or 0
        elif key.endswith('.expert_used_count'):
            used = value or 0
    if count and used and used < count:
        return round((1 - EXPERT_SHARE) + EXPERT_SHARE * used / count, 3)
    return 1.0


def category_from(name: str, capabilities: list[str]) -> str:
    if 'embedding' in capabilities:
        return 'emb'
    if 'vision' in capabilities:
        return 'vis'
    if any(word in name.lower() for word in ('coder', 'code', 'devstral')):
        return 'code'
    return 'chat'


def match_catalog(name: str, entries: list[CatalogEntryModel]) -> Optional[CatalogEntryModel]:
    wanted = base_name(name)
    for entry in entries:
        if entry.ollama and base_name(entry.ollama) == wanted:
            return entry
    return None


async def usage_stats(days: int = 30) -> tuple[dict[str, int], dict[str, int]]:
    """(answers per model in the last `days`, last answer time per model)."""
    since = int(time.time()) - days * 86400
    async with get_async_db() as db:
        recent = await db.execute(
            select(ChatMessage.model_id, func.count())
            .where(ChatMessage.role == 'assistant', ChatMessage.created_at >= since)
            .group_by(ChatMessage.model_id)
        )
        last = await db.execute(
            select(ChatMessage.model_id, func.max(ChatMessage.created_at))
            .where(ChatMessage.role == 'assistant')
            .group_by(ChatMessage.model_id)
        )
        return dict(recent.all()), dict(last.all())


async def other_users_since(model: str, user_id: str, days: int) -> int:
    """How many other people used the model in the last `days`."""
    since = int(time.time()) - days * 86400
    async with get_async_db() as db:
        result = await db.execute(
            select(func.count(func.distinct(ChatMessage.user_id))).where(
                ChatMessage.model_id.in_([model, base_name(model)]),
                ChatMessage.role == 'assistant',
                ChatMessage.created_at >= since,
                ChatMessage.user_id != user_id,
            )
        )
        return result.scalar() or 0


async def get_downloads() -> dict:
    return await Config.get(DOWNLOADS_KEY) or {}


async def record_download(name: str, user) -> None:
    downloads = await get_downloads()
    downloads[name] = {'user_id': user.id, 'user_name': user.name, 'at': int(time.time())}
    await Config.upsert({DOWNLOADS_KEY: downloads})


async def forget_download(name: str) -> None:
    downloads = await get_downloads()
    if downloads.pop(name, None) is not None:
        await Config.upsert({DOWNLOADS_KEY: downloads})


async def protected_reason(name: str) -> Optional[str]:
    """Models Open WebUI itself depends on cannot be removed from here."""
    rag = await Config.get_many('rag.embedding_engine', 'rag.embedding_model')
    if rag.get('rag.embedding_engine') == 'ollama' and base_name(rag.get('rag.embedding_model') or '') == base_name(
        name
    ):
        return 'rag_embedding'
    return None


async def list_installed() -> list[InstalledModel]:
    """Installed models with estimates and usage, largest first."""
    tags = await ollama.list_models()
    hw = await get_hardware()
    settings = await get_settings()
    entries = await CatalogEntries.get_all()
    uses, last_used = await usage_stats(30)
    downloads = await get_downloads()
    now = int(time.time())

    models = []
    for tag in tags:
        name = tag.get('name') or tag.get('model')
        details = tag.get('details') or {}
        try:
            info = await ollama.show_model(name, tag.get('digest', ''))
        except ollama.OllamaUnavailable as e:
            log.warning(f'my-local-ia: could not read details of {name}: {e}')
            info = {}
        capabilities = info.get('capabilities') or []
        entry = match_catalog(name, entries)
        category = entry.category if entry else category_from(name, capabilities)
        ratio = active_ratio_from(info.get('model_info') or {})
        if entry and ratio == 1.0:
            ratio = entry.active_ratio
        size_gb = round((tag.get('size') or 0) / 1e9, 1)
        model_uses = uses.get(name, 0) + (uses.get(base_name(name), 0) if base_name(name) != name else 0)
        model_last = max(last_used.get(name) or 0, last_used.get(base_name(name)) or 0) or None
        est = estimate(size_gb, ratio, category, hw)
        protected = await protected_reason(name)

        suggestion = None
        if protected:
            pass
        elif model_last is None or now - model_last > settings.unused_days * 86400:
            suggestion = 'unused'
        elif est.level in ('heavy', 'wont_run'):
            suggestion = 'heavy'
        elif model_uses <= 3 and size_gb >= 10:
            suggestion = 'rarely_used'

        models.append(
            InstalledModel(
                name=name,
                size_gb=size_gb,
                parameter_size=details.get('parameter_size'),
                quantization=details.get('quantization_level'),
                family=details.get('family'),
                category=category,
                reasoning='thinking' in capabilities or bool(entry and entry.reasoning),
                active_ratio=ratio,
                catalog_id=entry.id if entry else None,
                estimate=est,
                last_used=model_last,
                uses_30d=model_uses,
                downloaded_by=downloads.get(name),
                protected=protected,
                suggestion=suggestion,
            )
        )
    models.sort(key=lambda m: -m.size_gb)
    return models

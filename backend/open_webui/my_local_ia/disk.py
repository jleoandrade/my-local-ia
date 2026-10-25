"""Disk space of the server: status for everyone, alerts, and download checks.

The installer mounts Ollama's models folder at MY_LOCAL_IA_OLLAMA_MODELS_DIR
(read-only), so the free space measured here is the one of the disk that holds
the models. Without that mount, the disk of Open WebUI's data folder is used.
"""

import asyncio
import logging
import os
import shutil
import time
from typing import Literal, Optional

from open_webui.env import DATA_DIR
from open_webui.models.config import Config
from open_webui.my_local_ia import ollama
from open_webui.my_local_ia.settings import Settings, get_settings
from open_webui.utils.webhook import post_webhook
from pydantic import BaseModel

log = logging.getLogger(__name__)

HISTORY_KEY = 'my_local_ia.disk.history'  # [[epoch day start, used GB], ...], one sample per day
ALERT_LEVEL_KEY = 'my_local_ia.disk.alert_level'  # last level a webhook was sent for
BANNER_ID = 'my-local-ia-disk'
HISTORY_DAYS = 120
APP_SIZE_CACHE_SECONDS = 600

Level = Literal['ok', 'warning', 'critical', 'blocked']
LEVEL_ORDER = {'ok': 0, 'warning': 1, 'critical': 2, 'blocked': 3}

_app_size_cache: tuple[float, float] = (0.0, 0.0)  # (measured at, GB)


class DiskStatus(BaseModel):
    path: str
    models_mounted: bool  # False: measuring Open WebUI's data disk, which may differ from Ollama's
    total_gb: float
    used_gb: float
    free_gb: float
    used_pct: float
    level: Level
    models_gb: Optional[float] = None  # None when Ollama does not answer
    app_gb: float  # users, chats, uploads, vector database
    other_gb: float  # system and everything else
    warning_pct: float
    critical_pct: float
    block_pct: float
    margin_gb: float
    growth_gb_per_day: Optional[float] = None
    days_to_block: Optional[float] = None


class DownloadCheck(BaseModel):
    fits: bool
    needed_gb: float
    free_gb: float
    used_pct_now: float
    used_pct_after: float
    block_pct: float


def models_dir() -> tuple[str, bool]:
    path = os.environ.get('MY_LOCAL_IA_OLLAMA_MODELS_DIR', '')
    if path and os.path.isdir(path):
        return path, True
    return str(DATA_DIR), False


def _folder_size_gb(path: str) -> float:
    total = 0
    for root, _, files in os.walk(path):
        for name in files:
            try:
                total += os.lstat(os.path.join(root, name)).st_size
            except OSError:
                pass
    return total / 1e9


async def app_size_gb() -> float:
    global _app_size_cache
    measured_at, size = _app_size_cache
    if time.time() - measured_at > APP_SIZE_CACHE_SECONDS:
        size = await asyncio.to_thread(_folder_size_gb, str(DATA_DIR))
        _app_size_cache = (time.time(), size)
    return size


def level_for(used_pct: float, settings: Settings) -> Level:
    if used_pct >= settings.disk_block_pct:
        return 'blocked'
    if used_pct >= settings.disk_critical_pct:
        return 'critical'
    if used_pct >= settings.disk_warning_pct:
        return 'warning'
    return 'ok'


def projection(history: list, used_gb: float, block_gb: float) -> tuple[Optional[float], Optional[float]]:
    """Growth per day over the last 30 days of samples, and days left until the block threshold."""
    if not history:
        return None, None
    now = time.time()
    window = [s for s in history if now - s[0] <= 31 * 86400] or history
    first_day, first_used = window[0]
    days = (now - first_day) / 86400
    if days < 1:
        return None, None
    growth = (used_gb - first_used) / days
    if growth <= 0.01:
        return round(growth, 2), None
    return round(growth, 2), round(max(0.0, block_gb - used_gb) / growth, 1)


async def record_sample(used_gb: float) -> list:
    history = await Config.get(HISTORY_KEY) or []
    today = int(time.time()) // 86400 * 86400
    if not history or history[-1][0] < today:
        history.append([today, round(used_gb, 2)])
        history = history[-HISTORY_DAYS:]
        await Config.upsert({HISTORY_KEY: history})
    return history


async def disk_status(settings: Optional[Settings] = None) -> DiskStatus:
    settings = settings or await get_settings()
    path, mounted = models_dir()
    usage = await asyncio.to_thread(shutil.disk_usage, path)
    used, free = usage.used / 1e9, usage.free / 1e9
    # Like df's Use%: the space reserved for root is neither usable nor counted.
    total = used + free
    used_pct = round(100 * used / total, 1) if total else 0.0
    try:
        models_gb = round(sum(m.get('size') or 0 for m in await ollama.list_models()) / 1e9, 1)
    except ollama.OllamaUnavailable:
        models_gb = None
    app_gb = round(await app_size_gb(), 1)
    history = await record_sample(used)
    growth, days_left = projection(history, used, total * settings.disk_block_pct / 100)
    return DiskStatus(
        path=path,
        models_mounted=mounted,
        total_gb=round(total, 1),
        used_gb=round(used, 1),
        free_gb=round(free, 1),
        used_pct=used_pct,
        level=level_for(used_pct, settings),
        models_gb=models_gb,
        app_gb=app_gb,
        other_gb=round(max(0.0, used - (models_gb or 0) - app_gb), 1),
        warning_pct=settings.disk_warning_pct,
        critical_pct=settings.disk_critical_pct,
        block_pct=settings.disk_block_pct,
        margin_gb=settings.disk_margin_gb,
        growth_gb_per_day=growth,
        days_to_block=days_left,
    )


def check_download(status: DiskStatus, size_gb: float, freed_gb: float = 0.0) -> DownloadCheck:
    """Whether a download of `size_gb` keeps the disk under the block threshold (after freeing `freed_gb`)."""
    needed = size_gb + status.margin_gb
    used_after = status.used_gb - freed_gb + size_gb
    pct_after = round(100 * used_after / status.total_gb, 1) if status.total_gb else 100.0
    fits = (status.free_gb + freed_gb) >= needed and (pct_after < status.block_pct)
    return DownloadCheck(
        fits=fits,
        needed_gb=round(needed, 1),
        free_gb=status.free_gb,
        used_pct_now=status.used_pct,
        used_pct_after=pct_after,
        block_pct=status.block_pct,
    )


####################
# Alerts
####################

BANNER_TEXT = {
    'en': (
        'Disk almost full: {pct}% used, {free} GB left.',
        'Before downloading a large model, check the alternatives on the "Disk space" page.',
    ),
    'pt-BR': (
        'Disco quase cheio: {pct}% usado, restam {free} GB.',
        'Antes de baixar um modelo grande, veja as alternativas na página "Espaço em disco".',
    ),
    'es': (
        'Disco casi lleno: {pct}% usado, quedan {free} GB.',
        'Antes de descargar un modelo grande, revisa las alternativas en la página "Espacio en disco".',
    ),
}


def banner_for(status: DiskStatus) -> dict:
    def text(lang: str) -> str:
        title, body = BANNER_TEXT[lang]
        return f'**{title.format(pct=round(status.used_pct), free=status.free_gb)}** {body}'

    return {
        'id': BANNER_ID,
        'type': 'warning' if status.level == 'warning' else 'error',
        'title': '',
        'content': text('en'),
        'dismissible': True,
        'timestamp': int(time.time()),
        # Banner.svelte picks the user's language: "pt-BR", then "pt"; "es-ES", then "es".
        'i18n': {'pt-BR': {'content': text('pt-BR')}, 'pt': {'content': text('pt-BR')}, 'es': {'content': text('es')}},
    }


async def update_banner(status: DiskStatus, settings: Settings) -> None:
    banners = await Config.get('ui.banners') or []
    others = [b for b in banners if b.get('id') != BANNER_ID]
    current = next((b for b in banners if b.get('id') == BANNER_ID), None)
    if settings.alert_banner and status.level != 'ok':
        new = banner_for(status)
        # Keep the timestamp (and so the user's "dismiss") unless the text changed.
        if current and current.get('content') == new['content'] and current.get('type') == new['type']:
            return
        await Config.upsert({'ui.banners': others + [new]})
    elif current:
        await Config.upsert({'ui.banners': others})


async def notify_webhook(status: DiskStatus, settings: Settings) -> None:
    """One message when the level goes up (ok → warning → critical → blocked), not every check."""
    last = await Config.get(ALERT_LEVEL_KEY) or 'ok'
    if status.level == last:
        return
    await Config.upsert({ALERT_LEVEL_KEY: status.level})
    if LEVEL_ORDER[status.level] <= LEVEL_ORDER.get(last, 0) or not settings.alert_webhook_url:
        return
    title, body = BANNER_TEXT['en']
    message = f'my-local-ia: {title.format(pct=round(status.used_pct), free=status.free_gb)} {body}'
    await post_webhook('my-local-ia', settings.alert_webhook_url, message, {'action': 'disk', 'level': status.level})


async def check_and_alert() -> DiskStatus:
    settings = await get_settings()
    status = await disk_status(settings)
    await update_banner(status, settings)
    await notify_webhook(status, settings)
    return status

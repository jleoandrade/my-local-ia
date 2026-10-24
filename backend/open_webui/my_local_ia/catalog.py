"""Model catalog and hardware settings, stored in the Open WebUI database.

The `my_local_ia_model` table is created here with `checkfirst` instead of an
Alembic migration: a migration in a fork would add a second head every time
upstream ships one of its own, and `alembic upgrade head` would refuse to run.
"""

import asyncio
import json
import logging
import time
from pathlib import Path
from typing import Optional

from open_webui.internal.db import Base, async_engine, get_async_db
from open_webui.models.config import Config
from open_webui.my_local_ia.hardware import OVERRIDABLE, Hardware, apply_overrides, detect
from pydantic import BaseModel, ConfigDict
from sqlalchemy import JSON, BigInteger, Boolean, Column, Float, Text, delete, select

log = logging.getLogger(__name__)

CATALOG_FILE = Path(__file__).parent / 'catalog.json'

HARDWARE_DETECTED_KEY = 'my_local_ia.hardware.detected'
HARDWARE_OVERRIDES_KEY = 'my_local_ia.hardware.overrides'

####################
# Catalog DB Schema
####################


class CatalogEntry(Base):
    __tablename__ = 'my_local_ia_model'

    id = Column(Text, primary_key=True)
    name = Column(Text, nullable=False)
    category = Column(Text, nullable=False)  # chat, vis, code, img, vid, stt, tts, emb
    size_gb = Column(Float, nullable=False)
    active_ratio = Column(Float, nullable=False, default=1.0)  # share of the weights read per token (MoE < 1)
    reasoning = Column(Boolean, nullable=False, default=False)
    description = Column(JSON, nullable=True)  # {"en": ..., "pt-BR": ..., "es": ...}
    use_for = Column(JSON, nullable=True)  # same shape as description
    ollama = Column(Text, nullable=True)  # tag for `ollama pull`
    whisper = Column(Text, nullable=True)  # model name for speech-to-text
    unsure = Column(Boolean, nullable=False, default=False)  # description inferred from the name only
    source = Column(Text, nullable=False, default='curated')  # curated (catalog.json) or auto (found by the robot)
    meta = Column(JSON, nullable=True)

    created_at = Column(BigInteger, nullable=False)
    updated_at = Column(BigInteger, nullable=False)


class CatalogEntryModel(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    name: str
    category: str
    size_gb: float
    active_ratio: float = 1.0
    reasoning: bool = False
    description: Optional[dict[str, str]] = None
    use_for: Optional[dict[str, str]] = None
    ollama: Optional[str] = None
    whisper: Optional[str] = None
    unsure: bool = False
    source: str = 'curated'
    meta: Optional[dict] = None

    created_at: int
    updated_at: int


CATALOG_FIELDS = (
    'name',
    'category',
    'size_gb',
    'active_ratio',
    'reasoning',
    'description',
    'use_for',
    'ollama',
    'whisper',
    'unsure',
)


class CatalogEntriesTable:
    async def ensure_table(self) -> None:
        async with async_engine.begin() as conn:
            await conn.run_sync(lambda sync_conn: CatalogEntry.__table__.create(sync_conn, checkfirst=True))

    async def seed_curated(self, path: Path = CATALOG_FILE) -> int:
        """Brings the curated rows in line with catalog.json. Rows found by the robot are left alone."""
        with open(path, encoding='utf-8') as f:
            entries = {m['id']: m for m in json.load(f)['models']}
        now = int(time.time())
        async with get_async_db() as db:
            result = await db.execute(select(CatalogEntry))
            existing = {row.id: row for row in result.scalars().all()}
            for entry_id, entry in entries.items():
                row = existing.get(entry_id)
                fields = {key: entry.get(key) for key in CATALOG_FIELDS}
                fields['meta'] = {'reference': entry.get('reference')}
                if row is None:
                    db.add(CatalogEntry(id=entry_id, source='curated', created_at=now, updated_at=now, **fields))
                elif row.source == 'curated':
                    for key, value in fields.items():
                        setattr(row, key, value)
                    row.updated_at = now
            stale = [eid for eid, row in existing.items() if row.source == 'curated' and eid not in entries]
            if stale:
                await db.execute(delete(CatalogEntry).where(CatalogEntry.id.in_(stale)))
            await db.commit()
        return len(entries)

    async def get_all(self) -> list[CatalogEntryModel]:
        async with get_async_db() as db:
            result = await db.execute(select(CatalogEntry).order_by(CatalogEntry.name))
            return [CatalogEntryModel.model_validate(row) for row in result.scalars().all()]

    async def get_by_id(self, entry_id: str) -> Optional[CatalogEntryModel]:
        async with get_async_db() as db:
            row = await db.get(CatalogEntry, entry_id)
            return CatalogEntryModel.model_validate(row) if row else None


CatalogEntries = CatalogEntriesTable()

####################
# Hardware settings
####################

_detect_lock = asyncio.Lock()


async def detect_hardware() -> Hardware:
    """Runs detection in a thread (it shells out and benchmarks RAM) and saves the result."""
    async with _detect_lock:
        hw = await asyncio.to_thread(detect)
        await Config.upsert({HARDWARE_DETECTED_KEY: hw.model_dump()})
        log.info(f'Hardware detected: {hw.vram_gb} GB VRAM, {hw.ram_total_gb} GB RAM, {hw.ram_bandwidth_gbs} GB/s RAM')
        return hw


async def get_detected_hardware() -> Hardware:
    saved = await Config.get(HARDWARE_DETECTED_KEY)
    if saved:
        return Hardware.model_validate(saved)
    return await detect_hardware()


async def get_overrides() -> dict:
    return await Config.get(HARDWARE_OVERRIDES_KEY) or {}


async def set_overrides(updates: dict) -> dict:
    """Merges admin values; a None value removes that override."""
    overrides = await get_overrides()
    for key, value in updates.items():
        if key not in OVERRIDABLE:
            continue
        if value is None:
            overrides.pop(key, None)
        else:
            overrides[key] = float(value)
    await Config.upsert({HARDWARE_OVERRIDES_KEY: overrides})
    return overrides


async def get_hardware() -> Hardware:
    """Detected hardware with the admin's overrides applied: what estimates are based on."""
    return apply_overrides(await get_detected_hardware(), await get_overrides())


async def startup() -> None:
    await CatalogEntries.ensure_table()
    count = await CatalogEntries.seed_curated()
    log.info(f'my-local-ia: {count} curated models loaded')
    if not await Config.get(HARDWARE_DETECTED_KEY):
        await detect_hardware()

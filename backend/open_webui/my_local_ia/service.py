"""Startup and background work of my-local-ia: catalog seed, hardware, disk alerts and the robot."""

import asyncio
import logging
from typing import Optional

from open_webui.models.config import Config
from open_webui.my_local_ia import disk, robot
from open_webui.my_local_ia.catalog import HARDWARE_DETECTED_KEY, CatalogEntries, detect_hardware
from open_webui.my_local_ia.settings import get_settings

log = logging.getLogger(__name__)

_monitor_task: Optional[asyncio.Task] = None


async def monitor_loop() -> None:
    """Checks the disk every disk_check_minutes and runs the robot when it is due."""
    while True:
        settings = await get_settings()
        try:
            await disk.check_and_alert()
        except Exception as e:
            log.warning(f'my-local-ia: disk check failed: {e}')
        try:
            if robot.is_due(settings, (await robot.get_status()).get('last_run')):
                await robot.run(settings)
        except Exception as e:
            log.warning(f'my-local-ia: robot failed: {e}')
        await asyncio.sleep(settings.disk_check_minutes * 60)


async def startup() -> None:
    global _monitor_task
    await CatalogEntries.ensure_table()
    count = await CatalogEntries.seed_curated()
    log.info(f'my-local-ia: {count} curated models loaded')
    if not await Config.get(HARDWARE_DETECTED_KEY):
        await detect_hardware()
    _monitor_task = asyncio.create_task(monitor_loop())

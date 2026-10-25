"""Model downloads that run on the server, independent of the browser.

A download keeps going when its window is closed or the page changes; every
user sees the progress under the disk meter. Jobs live in memory (Open WebUI
runs one worker by default): if the container restarts mid-download, Ollama
keeps the part already downloaded and the next attempt resumes from there.
"""

import asyncio
import json
import logging
import time
from typing import Literal, Optional

from open_webui.my_local_ia import disk, installed, ollama
from pydantic import BaseModel

log = logging.getLogger(__name__)

FINISHED_VISIBLE_SECONDS = 600  # finished downloads stay listed this long

Status = Literal['downloading', 'done', 'error', 'cancelled']


class Download(BaseModel):
    name: str
    catalog_id: Optional[str] = None
    display_name: str
    size_gb: float = 0.0  # expected, from the catalog (0 when unknown)
    user_id: str
    user_name: str
    status: Status = 'downloading'
    completed: int = 0  # bytes, over every layer
    total: int = 0
    percent: float = 0.0
    message: str = ''  # Ollama's current step ("pulling 29d8c98fa6b0", "verifying sha256 digest"…)
    error: Optional[str] = None
    started_at: int
    finished_at: Optional[int] = None


_downloads: dict[str, Download] = {}
_tasks: dict[str, asyncio.Task] = {}


def full_name(name: str) -> str:
    return name if ':' in name else f'{name}:latest'


class Progress:
    """Adds up Ollama's per-layer progress lines into one percentage."""

    def __init__(self):
        self.layers: dict[str, tuple[int, int]] = {}

    def update(self, line: dict) -> tuple[int, int]:
        digest = line.get('digest')
        if digest and line.get('total'):
            self.layers[digest] = (int(line.get('completed') or 0), int(line['total']))
        completed = sum(c for c, _ in self.layers.values())
        total = sum(t for _, t in self.layers.values())
        return completed, total


async def _run(job: Download, user) -> None:
    progress = Progress()
    try:
        async for raw in ollama.pull_model(job.name):
            try:
                line = json.loads(raw)
            except ValueError:
                continue
            if line.get('error'):
                job.status, job.error = 'error', str(line['error'])
                break
            job.message = str(line.get('status') or '')
            job.completed, job.total = progress.update(line)
            if job.total:
                job.percent = round(100 * job.completed / job.total, 1)
            if line.get('status') == 'success':
                job.status, job.percent = 'done', 100.0
        if job.status == 'downloading':  # the stream ended without "success"
            job.status, job.error = 'error', job.error or 'the download did not finish'
        if job.status == 'done':
            await installed.record_download(full_name(job.name), user)
            log.info(f'my-local-ia: {job.user_name} downloaded {job.name}')
    except asyncio.CancelledError:
        job.status = 'cancelled'
        raise
    except Exception as e:
        log.exception(f'my-local-ia: download of {job.name} failed: {e}')
        job.status, job.error = 'error', str(e)
    finally:
        job.finished_at = int(time.time())
        _tasks.pop(job.name, None)
        try:
            await disk.check_and_alert()
        except Exception:
            pass


def start(
    name: str, user, catalog_id: Optional[str] = None, display_name: Optional[str] = None, size_gb: float = 0.0
) -> Download:
    """Starts a download in the background, or returns the one already running for this model."""
    running = _downloads.get(name)
    if running and running.status == 'downloading':
        return running
    job = Download(
        name=name,
        catalog_id=catalog_id,
        display_name=display_name or name,
        size_gb=size_gb,
        user_id=user.id,
        user_name=user.name,
        started_at=int(time.time()),
    )
    _downloads[name] = job
    _tasks[name] = asyncio.create_task(_run(job, user))
    return job


def pending_gb(except_name: str = '') -> float:
    """Disk still to be taken by the downloads running now."""
    pending = 0.0
    for job in _downloads.values():
        if job.status != 'downloading' or job.name == except_name:
            continue
        if job.total:
            pending += (job.total - job.completed) / 1e9
        else:
            pending += job.size_gb
    return round(pending, 2)


def cancel(name: str) -> bool:
    """Stops a running download (closing the stream makes Ollama stop it too)."""
    task = _tasks.get(name)
    if task is None:
        return False
    task.cancel()
    return True


def get(name: str) -> Optional[Download]:
    return _downloads.get(name)


def listing(now: Optional[float] = None) -> list[Download]:
    """Running downloads and the ones that finished in the last few minutes, newest first."""
    now = now or time.time()
    for name, job in list(_downloads.items()):
        if job.finished_at and now - job.finished_at > FINISHED_VISIBLE_SECONDS:
            del _downloads[name]
    return sorted(_downloads.values(), key=lambda d: d.started_at, reverse=True)

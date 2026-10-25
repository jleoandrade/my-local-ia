"""Best model per task for this hardware, and alternatives when a download does not fit.

Each task has a preference list, best (and biggest) first. The pick is the first
model that runs well here, so a stronger server automatically gets bigger models.
"""

from typing import Optional

from open_webui.my_local_ia.catalog import CatalogEntryModel
from open_webui.my_local_ia.disk import DiskStatus, check_download
from open_webui.my_local_ia.estimate import Estimate, estimate
from open_webui.my_local_ia.hardware import Hardware
from open_webui.my_local_ia.installed import InstalledModel
from pydantic import BaseModel

# Below this, answers come slower than people read comfortably.
MIN_PICK_TPS = 15

TASKS: dict[str, list[str]] = {
    'assistant': [
        'gpt-oss-120b',
        'qwen-3-next-80b-a3b',
        'gpt-oss-20b',
        'qwen-3-14b',
        'qwen-3-8b',
        'qwen-3-5-4b',
        'llama-3-2-3b',
        'gemma-3-1b',
    ],
    'writing': ['gemma-4-31b', 'gemma-3-12b', 'qwen-3-14b', 'qwen-3-8b', 'gemma-3-4b', 'llama-3-2-3b'],
    'coding': ['qwen-3-coder-next-80b-a3b', 'devstral-small-2-24b', 'qwen-2-5-coder-7b', 'qwen-2-5-coder-1-5b'],
    'reasoning': [
        'deepseek-r1-distill-32b',
        'qwen-3-32b',
        'qwen-3-14b',
        'deepseek-r1-distill-14b',
        'phi-4-14b',
        'qwen-3-8b',
        'deepseek-r1-distill-7b',
        'phi-4-mini-reasoning',
    ],
    'vision': ['qwen3-vl-30b-a3b', 'qwen3-vl-8b', 'gemma-3-12b', 'qwen3-vl-4b', 'gemma-3-4b'],
    'transcription': ['whisper-large-v3-turbo', 'whisper-large-v3', 'whisper-small'],
    'documents': ['bge-m3', 'qwen3-embedding-0-6b', 'nomic-embed-text-v1-5'],
}

# Order in which installed models are offered for removal.
REMOVAL_ORDER = {'unused': 0, 'heavy': 1, 'rarely_used': 2}


class Pick(BaseModel):
    task: str
    entry: CatalogEntryModel
    estimate: Estimate
    installed_as: Optional[str] = None  # Ollama name, when already installed


class Alternative(BaseModel):
    kind: str  # smaller | free_space
    entry: Optional[CatalogEntryModel] = None
    estimate: Optional[Estimate] = None
    remove: list[str] = []
    frees_gb: float = 0.0
    used_pct_after: float


def runs_well(est: Estimate) -> bool:
    return est.level in ('smooth', 'usable') and (est.tps is None or est.tps >= MIN_PICK_TPS)


def best_picks(entries: list[CatalogEntryModel], hw: Hardware, installed: list[InstalledModel]) -> list[Pick]:
    by_id = {e.id: e for e in entries if not e.unsure}
    installed_by_catalog = {m.catalog_id: m.name for m in installed if m.catalog_id}
    picks = []
    for task, preferences in TASKS.items():
        for entry_id in preferences:
            entry = by_id.get(entry_id)
            if entry is None:
                continue
            est = estimate(entry.size_gb, entry.active_ratio, entry.category, hw)
            if runs_well(est):
                picks.append(
                    Pick(task=task, entry=entry, estimate=est, installed_as=installed_by_catalog.get(entry.id))
                )
                break
    return picks


def alternatives_for(
    target: CatalogEntryModel,
    entries: list[CatalogEntryModel],
    installed: list[InstalledModel],
    status: DiskStatus,
    hw: Hardware,
) -> list[Alternative]:
    """Up to two smaller models of the same kind that fit, and a set of installed models to remove."""
    alternatives = []

    smaller = []
    for entry in entries:
        if (
            entry.id == target.id
            or entry.unsure
            or entry.category != target.category
            or entry.size_gb >= target.size_gb
        ):
            continue
        if target.reasoning and not entry.reasoning:
            continue
        est = estimate(entry.size_gb, entry.active_ratio, entry.category, hw)
        check = check_download(status, entry.size_gb)
        if check.fits and runs_well(est):
            smaller.append((entry, est, check))
    smaller.sort(key=lambda item: -item[0].size_gb)  # closest to the wanted model first
    for entry, est, check in smaller[:2]:
        alternatives.append(Alternative(kind='smaller', entry=entry, estimate=est, used_pct_after=check.used_pct_after))

    candidates = sorted(
        (m for m in installed if m.suggestion and not m.protected),
        key=lambda m: (REMOVAL_ORDER.get(m.suggestion, 9), -m.size_gb),
    )
    remove, freed = [], 0.0
    for model in candidates:
        remove.append(model.name)
        freed += model.size_gb
        check = check_download(status, target.size_gb, freed)
        if check.fits:
            alternatives.append(
                Alternative(
                    kind='free_space', remove=remove, frees_gb=round(freed, 1), used_pct_after=check.used_pct_after
                )
            )
            break
    return alternatives

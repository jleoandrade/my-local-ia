"""Estimates how a model runs on the detected hardware.

Generating a token means reading every weight the token uses once, so speed
is bandwidth divided by the bytes read per token. When the model does not fit
in VRAM, the part left in RAM is read at RAM speed and dominates the time.
MoE models only read their active experts, a fraction of the total size.
"""

import math
from typing import Literal, Optional

from open_webui.my_local_ia.hardware import Hardware
from pydantic import BaseModel

TEXT_CATEGORIES = ('chat', 'vis', 'code')
# A model using more than this share of VRAM leaves little room for the
# conversation (KV cache): speed drops and long chats may not fit.
TIGHT_VRAM_SHARE = 0.85
TIGHT_VRAM_PENALTY = 0.7
# Scores for models measured by fit rather than tokens per second.
FIT_SCORE = {'img': 40, 'vid': 40, 'stt': 85, 'tts': 85, 'emb': 85}
SPILL_SCORE = 10

# smooth: comfortable to use; usable: works, with waits; heavy: very slow; wont_run: does not load.
# The interface translates these into the user's language.
Level = Literal['smooth', 'usable', 'heavy', 'wont_run']


class Estimate(BaseModel):
    size_gb: float
    placement: Literal['vram', 'vram+ram', 'ram', 'wont_load']
    tps: Optional[float] = None  # tokens per second; None for models that don't write text
    score: int
    level: Level
    tight_vram: bool = False


def level_for(score: int) -> Level:
    if score >= 60:
        return 'smooth'
    if score >= 20:
        return 'usable'
    if score > 0:
        return 'heavy'
    return 'wont_run'


def placement_for(size_gb: float, hw: Hardware) -> str:
    if hw.has_gpu and size_gb <= hw.vram_gb:
        return 'vram'
    if size_gb <= hw.vram_gb + hw.ram_for_models_gb:
        return 'vram+ram' if hw.has_gpu else 'ram'
    return 'wont_load'


def tokens_per_second(size_gb: float, active_ratio: float, hw: Hardware) -> float:
    per_token = size_gb * min(1.0, max(active_ratio, 0.0))  # GB read per generated token
    if per_token <= 0:
        return 0.0
    gpu_bw = hw.gpu_bandwidth_gbs * hw.gpu_efficiency
    ram_bw = hw.ram_bandwidth_gbs
    placement = placement_for(size_gb, hw)
    if placement == 'wont_load':
        return 0.0
    if placement == 'vram':
        tps = gpu_bw / per_token
        if size_gb > TIGHT_VRAM_SHARE * hw.vram_gb:
            tps *= TIGHT_VRAM_PENALTY
        return tps
    on_gpu = per_token * (hw.vram_gb / size_gb) if hw.has_gpu else 0.0
    seconds = (on_gpu / gpu_bw if on_gpu else 0.0) + (per_token - on_gpu) / ram_bw
    return 1 / seconds


def estimate(size_gb: float, active_ratio: float, category: str, hw: Hardware) -> Estimate:
    placement = placement_for(size_gb, hw)
    tight = placement == 'vram' and size_gb > TIGHT_VRAM_SHARE * hw.vram_gb

    if category not in TEXT_CATEGORIES:
        score = {'vram': FIT_SCORE.get(category, 40), 'wont_load': 0}.get(placement, SPILL_SCORE)
        level = level_for(score)
        return Estimate(size_gb=size_gb, placement=placement, score=score, level=level)

    tps = tokens_per_second(size_gb, active_ratio, hw)
    score = min(95, round(100 * (1 - math.exp(-tps / 35)))) if tps > 0 else 0
    if tps > 0 and score == 0:
        score = 1  # loads, but slower than 1 token every 2 seconds
    if tight:
        score = min(score, 59)  # fast, but little room left for the conversation
    level = level_for(score)
    return Estimate(
        size_gb=size_gb,
        placement=placement,
        tps=round(tps, 1),
        score=score,
        level=level,
        tight_vram=tight,
    )

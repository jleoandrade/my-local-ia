"""Detects the hardware that local models will run on.

Everything here is best effort: a missing tool or unreadable file leaves the
field empty and marks where the value came from, so the admin can fill it in.
Sources: 'detected' (read from the system), 'table' (looked up by GPU name),
'measured' (benchmarked), 'default' (fallback) and 'manual' (admin override).
"""

import logging
import os
import re
import shutil
import subprocess
import time
from concurrent.futures import ThreadPoolExecutor
from typing import Optional

from pydantic import BaseModel, Field, computed_field

log = logging.getLogger(__name__)

# Fraction of the theoretical GPU memory bandwidth that inference reaches in practice.
GPU_EFFICIENCY = 0.7
# RAM kept for the OS, Ollama and Open WebUI: 12.5% of the total, at least 4 GB.
RAM_RESERVE_FRACTION = 0.125
RAM_RESERVE_MIN_GB = 4.0
# Used when RAM bandwidth cannot be measured (dual-channel DDR4, effective).
DEFAULT_RAM_BANDWIDTH = 20.0
# Used when the GPU is not in the table below.
DEFAULT_GPU_BANDWIDTH = 300.0

# Theoretical memory bandwidth in GB/s. Keys are matched against the GPU name,
# longest first, so "3060 ti" wins over "3060". A list picks by VRAM:
# [(max_vram_gb, bandwidth), ...] for cards sold with different memory buses.
GPU_BANDWIDTH = {
    # NVIDIA GeForce 10/16
    'gtx 1050 ti': 112,
    'gtx 1060': 192,
    'gtx 1070 ti': 256,
    'gtx 1070': 256,
    'gtx 1080 ti': 484,
    'gtx 1080': 320,
    'gtx 1650': 128,
    'gtx 1660 super': 336,
    'gtx 1660 ti': 288,
    'gtx 1660': 192,
    # NVIDIA RTX 20
    'rtx 2060 super': 448,
    'rtx 2060': 336,
    'rtx 2070 super': 448,
    'rtx 2070': 448,
    'rtx 2080 super': 496,
    'rtx 2080 ti': 616,
    'rtx 2080': 448,
    # NVIDIA RTX 30
    'rtx 3050': 224,
    'rtx 3060 ti': 448,
    'rtx 3060': [(8, 240), (99, 360)],
    'rtx 3070 ti': 608,
    'rtx 3070': 448,
    'rtx 3080 ti': 912,
    'rtx 3080': [(10, 760), (99, 912)],
    'rtx 3090 ti': 1008,
    'rtx 3090': 936,
    # NVIDIA RTX 40
    'rtx 4060 ti': 288,
    'rtx 4060': 272,
    'rtx 4070 ti super': 672,
    'rtx 4070 ti': 504,
    'rtx 4070 super': 504,
    'rtx 4070': 504,
    'rtx 4080 super': 736,
    'rtx 4080': 717,
    'rtx 4090': 1008,
    # NVIDIA RTX 50
    'rtx 5060 ti': 448,
    'rtx 5060': 448,
    'rtx 5070 ti': 896,
    'rtx 5070': 672,
    'rtx 5080': 960,
    'rtx 5090': 1792,
    # NVIDIA workstation and data center
    'rtx a2000': 288,
    'rtx a4000': 448,
    'rtx a5000': 768,
    'rtx a6000': 768,
    'rtx 4000 ada': 360,
    'rtx 6000 ada': 960,
    'tesla t4': 320,
    'tesla p40': 347,
    'tesla p100': 732,
    'tesla v100': 900,
    'a10g': 600,
    'a10': 600,
    'l4': 300,
    'l40s': 864,
    'a100': [(40, 1555), (99, 2039)],
    'h100': 2000,
    # AMD
    'rx 7900 xtx': 960,
    'rx 7900 xt': 800,
    'rx 7800 xt': 624,
    'rx 7700 xt': 432,
    'rx 7600': 288,
    'rx 6900 xt': 512,
    'rx 6800 xt': 512,
    'rx 6800': 512,
    'rx 6700 xt': 384,
    'mi100': 1229,
    'mi210': 1638,
}


class Gpu(BaseModel):
    name: str
    vram_gb: float
    bandwidth_gbs: float
    bandwidth_source: str


class Hardware(BaseModel):
    gpus: list[Gpu] = Field(default_factory=list)
    vram_gb: float = 0.0
    gpu_bandwidth_gbs: float = 0.0
    gpu_efficiency: float = GPU_EFFICIENCY
    ram_total_gb: float = 0.0
    ram_for_models_gb: float = 0.0
    ram_bandwidth_gbs: float = DEFAULT_RAM_BANDWIDTH  # effective, already measured in practice
    cpu_name: Optional[str] = None
    cpu_threads: Optional[int] = None
    sources: dict[str, str] = Field(default_factory=dict)
    detected_at: Optional[int] = None

    @computed_field
    @property
    def has_gpu(self) -> bool:
        return self.vram_gb > 0


OVERRIDABLE = ('vram_gb', 'gpu_bandwidth_gbs', 'gpu_efficiency', 'ram_for_models_gb', 'ram_bandwidth_gbs')


def gpu_bandwidth(name: str, vram_gb: float) -> tuple[float, str]:
    """Theoretical bandwidth for a GPU name, or the default when unknown."""
    normalized = re.sub(r'[\s_-]+', ' ', name.lower().replace('geforce', '').replace('nvidia', '')).strip()
    for key in sorted(GPU_BANDWIDTH, key=len, reverse=True):
        if re.search(r'(^|\s)' + re.escape(key) + r'($|\s)', normalized):
            value = GPU_BANDWIDTH[key]
            if isinstance(value, list):
                value = next(bw for max_vram, bw in value if vram_gb <= max_vram)
            return float(value), 'table'
    return DEFAULT_GPU_BANDWIDTH, 'default'


def parse_nvidia_smi(output: str) -> list[Gpu]:
    """Parses `nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits`."""
    gpus = []
    for line in output.strip().splitlines():
        parts = [p.strip() for p in line.split(',')]
        if len(parts) < 2:
            continue
        try:
            vram = round(float(parts[1]) / 1024, 1)  # MiB → GiB
        except ValueError:
            continue
        bandwidth, source = gpu_bandwidth(parts[0], vram)
        gpus.append(Gpu(name=parts[0], vram_gb=vram, bandwidth_gbs=bandwidth, bandwidth_source=source))
    return gpus


def parse_meminfo(text: str) -> tuple[float, float]:
    """Total RAM and the part left for models, in GB, from /proc/meminfo."""
    match = re.search(r'^MemTotal:\s+(\d+)\s+kB', text, re.M)
    if not match:
        return 0.0, 0.0
    total = int(match.group(1)) / 1024 / 1024
    reserve = max(RAM_RESERVE_MIN_GB, total * RAM_RESERVE_FRACTION)
    return round(total, 1), round(max(0.0, total - reserve), 1)


def parse_cpuinfo(text: str) -> Optional[str]:
    match = re.search(r'^model name\s*:\s*(.+)$', text, re.M)
    return re.sub(r'\s+', ' ', match.group(1)).strip() if match else None


def _run(cmd: list[str]) -> Optional[str]:
    if not shutil.which(cmd[0]):
        return None
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.SubprocessError) as e:
        log.info(f'{cmd[0]} failed: {e}')
        return None
    return result.stdout if result.returncode == 0 else None


def detect_gpus() -> list[Gpu]:
    output = _run(['nvidia-smi', '--query-gpu=name,memory.total', '--format=csv,noheader,nounits'])
    if output:
        return parse_nvidia_smi(output)
    return []


def _read(path: str) -> str:
    try:
        with open(path, encoding='utf-8', errors='replace') as f:
            return f.read()
    except OSError:
        return ''


def measure_ram_bandwidth(size_mb: int = 256, rounds: int = 3) -> Optional[float]:
    """Effective RAM bandwidth in GB/s from a multi-threaded memory copy.

    A copy reads and writes every byte, so bytes moved = 2 × buffer size.
    numpy releases the GIL while copying, which lets the threads run in parallel.
    """
    try:
        import numpy as np
    except ImportError:
        return None
    threads = max(1, min(os.cpu_count() or 1, 8))
    chunk = size_mb * 1024 * 1024 // threads
    sources = [np.ones(chunk, dtype=np.uint8) for _ in range(threads)]
    targets = [np.empty_like(s) for s in sources]
    best = 0.0
    with ThreadPoolExecutor(threads) as pool:
        for _ in range(rounds):
            start = time.perf_counter()
            list(pool.map(lambda pair: np.copyto(pair[1], pair[0]), zip(sources, targets)))
            elapsed = time.perf_counter() - start
            best = max(best, 2 * chunk * threads / elapsed / 1e9)
    return round(best, 1) if best > 0 else None


def detect(measure_ram: bool = True) -> Hardware:
    """Reads GPU, RAM and CPU of this machine. Takes about a second with the RAM benchmark."""
    hw = Hardware(detected_at=int(time.time()))

    gpus = detect_gpus()
    if gpus:
        hw.gpus = gpus
        hw.vram_gb = round(sum(g.vram_gb for g in gpus), 1)
        # Layers are split across GPUs and read one after the other, so the slowest card sets the pace.
        slowest = min(gpus, key=lambda g: g.bandwidth_gbs)
        hw.gpu_bandwidth_gbs = slowest.bandwidth_gbs
        hw.sources.update(vram_gb='detected', gpu_bandwidth_gbs=slowest.bandwidth_source)
    else:
        hw.sources.update(vram_gb='detected', gpu_bandwidth_gbs='detected')
    hw.sources['gpu_efficiency'] = 'default'

    hw.ram_total_gb, hw.ram_for_models_gb = parse_meminfo(_read('/proc/meminfo'))
    hw.sources['ram_for_models_gb'] = 'detected' if hw.ram_total_gb else 'default'

    measured = measure_ram_bandwidth() if measure_ram else None
    if measured:
        hw.ram_bandwidth_gbs = measured
        hw.sources['ram_bandwidth_gbs'] = 'measured'
    else:
        hw.sources['ram_bandwidth_gbs'] = 'default'

    hw.cpu_name = parse_cpuinfo(_read('/proc/cpuinfo'))
    hw.cpu_threads = os.cpu_count()
    return hw


def apply_overrides(hw: Hardware, overrides: dict) -> Hardware:
    """Returns a copy of `hw` with the admin's values on top, marked as 'manual'."""
    merged = hw.model_copy(deep=True)
    for key in OVERRIDABLE:
        value = overrides.get(key)
        if value is not None:
            setattr(merged, key, float(value))
            merged.sources[key] = 'manual'
    return merged

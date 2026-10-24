import json
from pathlib import Path

import pytest
from open_webui import my_local_ia
from open_webui.my_local_ia import hardware
from open_webui.my_local_ia.estimate import estimate
from open_webui.my_local_ia.hardware import (
    Hardware,
    apply_overrides,
    gpu_bandwidth,
    parse_cpuinfo,
    parse_meminfo,
    parse_nvidia_smi,
)

# The machine the original site was built for: RTX 3060 12 GB + 64 GB DDR4.
RTX3060 = Hardware(vram_gb=12, gpu_bandwidth_gbs=360, ram_for_models_gb=56, ram_bandwidth_gbs=21)
CPU_ONLY = Hardware(vram_gb=0, gpu_bandwidth_gbs=0, ram_for_models_gb=28, ram_bandwidth_gbs=20)
# Read directly so these tests don't need the database (catalog.py imports it).
CATALOG_FILE = Path(my_local_ia.__file__).parent / 'catalog.json'


####################
# Hardware detection
####################


def test_parse_nvidia_smi_single_gpu():
    gpus = parse_nvidia_smi('NVIDIA GeForce RTX 3060, 12288\n')
    assert len(gpus) == 1
    assert gpus[0].name == 'NVIDIA GeForce RTX 3060'
    assert gpus[0].vram_gb == 12.0
    assert gpus[0].bandwidth_gbs == 360
    assert gpus[0].bandwidth_source == 'table'


def test_parse_nvidia_smi_skips_bad_lines():
    gpus = parse_nvidia_smi('NVIDIA GeForce RTX 4090, 24564\ngarbage\nNVIDIA A10, [N/A]\n')
    assert [g.name for g in gpus] == ['NVIDIA GeForce RTX 4090']


@pytest.mark.parametrize(
    'name, vram, expected',
    [
        ('NVIDIA GeForce RTX 3060 Ti', 8, 448),  # longest key wins over "3060"
        ('NVIDIA GeForce RTX 3060', 8, 240),  # 8 GB variant has a narrower bus
        ('NVIDIA GeForce RTX 3060', 12, 360),
        ('NVIDIA A100-SXM4-80GB', 80, 2039),
        ('NVIDIA L4', 24, 300),
        ('NVIDIA L40S', 48, 864),
    ],
)
def test_gpu_bandwidth_table(name, vram, expected):
    assert gpu_bandwidth(name, vram) == (expected, 'table')


def test_gpu_bandwidth_unknown_uses_default():
    assert gpu_bandwidth('Some Future GPU 9000', 16) == (hardware.DEFAULT_GPU_BANDWIDTH, 'default')


def test_parse_meminfo_keeps_reserve():
    total, for_models = parse_meminfo('MemTotal:       67108864 kB\nMemFree: 1 kB\n')
    assert total == 64.0
    assert for_models == 56.0  # 12.5% reserved
    assert parse_meminfo('MemTotal: 8388608 kB') == (8.0, 4.0)  # at least 4 GB reserved
    assert parse_meminfo('') == (0.0, 0.0)


def test_parse_cpuinfo():
    assert (
        parse_cpuinfo('processor\t: 0\nmodel name\t: Intel(R) Xeon(R)  CPU E5-2620 v3\n')
        == 'Intel(R) Xeon(R) CPU E5-2620 v3'
    )
    assert parse_cpuinfo('') is None


def test_detect_without_gpu(monkeypatch):
    monkeypatch.setattr(hardware, 'detect_gpus', lambda: [])
    hw = hardware.detect(measure_ram=False)
    assert hw.has_gpu is False
    assert hw.sources['ram_bandwidth_gbs'] == 'default'


def test_detect_multi_gpu_uses_slowest(monkeypatch):
    gpus = parse_nvidia_smi('NVIDIA GeForce RTX 3090, 24576\nNVIDIA GeForce RTX 3060, 12288\n')
    monkeypatch.setattr(hardware, 'detect_gpus', lambda: gpus)
    hw = hardware.detect(measure_ram=False)
    assert hw.vram_gb == 36.0
    assert hw.gpu_bandwidth_gbs == 360


def test_overrides_are_marked_manual():
    hw = apply_overrides(RTX3060, {'vram_gb': 16, 'ram_bandwidth_gbs': None, 'unknown': 5})
    assert hw.vram_gb == 16
    assert hw.sources['vram_gb'] == 'manual'
    assert 'ram_bandwidth_gbs' not in hw.sources
    assert RTX3060.vram_gb == 12  # original untouched


def test_measure_ram_bandwidth_returns_positive():
    assert hardware.measure_ram_bandwidth(size_mb=16, rounds=1) > 0


####################
# Estimates
####################


def test_dense_model_in_vram():
    e = estimate(7.7, 1.0, 'chat', RTX3060)  # Qwen 3 14B
    assert e.placement == 'vram'
    assert e.tps == pytest.approx(32.7, abs=0.1)
    assert e.level == 'smooth'


def test_tight_vram_is_capped_at_usable():
    e = estimate(11.3, 0.171, 'chat', RTX3060)  # GPT-OSS 20B: fast, but fills the card
    assert e.tight_vram
    assert e.tps > 60
    assert e.level == 'usable'


def test_spill_to_ram_is_slow():
    e = estimate(16.9, 1.0, 'chat', RTX3060)  # Qwen 3 32B
    assert e.placement == 'vram+ram'
    assert 2 < e.tps < 6
    assert e.level == 'heavy'


def test_moe_spilling_stays_usable():
    e = estimate(16.4, 0.1, 'vis', RTX3060)  # Qwen3-VL 30B-A3B
    assert e.placement == 'vram+ram'
    assert e.tps > 30


def test_too_big_does_not_load():
    e = estimate(120.9, 0.094, 'chat', RTX3060)
    assert e.placement == 'wont_load'
    assert e.tps == 0
    assert e.level == 'wont_run'


def test_cpu_only():
    small = estimate(2.0, 1.0, 'chat', CPU_ONLY)
    assert small.placement == 'ram'
    assert small.tps == pytest.approx(10.0)
    big = estimate(36.4, 1.0, 'chat', CPU_ONLY)
    assert big.level == 'wont_run'


def test_non_text_models_rated_by_fit():
    assert estimate(1.6, 1.0, 'stt', RTX3060).level == 'smooth'
    assert estimate(14.1, 1.0, 'vid', RTX3060).level == 'heavy'
    assert estimate(5.0, 1.0, 'img', RTX3060).level == 'usable'
    assert estimate(1.6, 1.0, 'stt', RTX3060).tps is None


####################
# Catalog data
####################


def test_catalog_file_is_consistent():
    models = json.loads(CATALOG_FILE.read_text(encoding='utf-8'))['models']
    assert len(models) == 105
    assert len({m['id'] for m in models}) == len(models)
    for m in models:
        assert m['category'] in ('chat', 'vis', 'code', 'img', 'vid', 'stt', 'tts', 'emb')
        assert 0 < m['active_ratio'] <= 1
        assert m['size_gb'] > 0


def test_estimates_match_original_site():
    """On the original site's hardware, most models keep the speed the site showed."""
    models = json.loads(CATALOG_FILE.read_text(encoding='utf-8'))['models']
    close = total = 0
    for m in models:
        ref = m['reference']['tps_rtx3060']
        if m['category'] not in ('chat', 'vis', 'code') or not ref:
            continue
        total += 1
        tps = estimate(m['size_gb'], m['active_ratio'], m['category'], RTX3060).tps
        close += 0.6 <= tps / ref <= 1.6
    assert close / total > 0.95


def test_catalog_texts_are_translated_and_hardware_neutral():
    models = json.loads(CATALOG_FILE.read_text(encoding='utf-8'))['models']
    for m in models:
        for field in ('description', 'use_for'):
            assert set(m[field]) == {'en', 'pt-BR', 'es'}, (m['id'], field)
            assert all(text.strip() for text in m[field].values()), (m['id'], field)
        # Speed and fit come from the estimate, so the texts must not assume one machine.
        for text in m['description'].values():
            for phrase in ('12 GB', 'RTX', 'tok/s', 'nesta placa', 'aqui'):
                assert phrase not in text, (m['id'], phrase)

import asyncio
import json
from datetime import datetime
from pathlib import Path

import pytest
from open_webui import my_local_ia
from open_webui.my_local_ia import robot
from open_webui.my_local_ia.catalog import CatalogEntryModel
from open_webui.my_local_ia.disk import DiskStatus, banner_for, check_download, level_for, projection
from open_webui.my_local_ia.estimate import estimate
from open_webui.my_local_ia.hardware import Hardware
from open_webui.my_local_ia.installed import InstalledModel, active_ratio_from, base_name, category_from
from open_webui.my_local_ia.picks import alternatives_for, best_picks
from open_webui.my_local_ia.settings import Settings, SettingsForm

# The server this was built for: RTX 3060 12 GB in a VM with 32 GB of RAM.
VM = Hardware(vram_gb=12, gpu_bandwidth_gbs=360, ram_for_models_gb=28, ram_bandwidth_gbs=20)
CATALOG_FILE = Path(my_local_ia.__file__).parent / 'catalog.json'


def catalog() -> list[CatalogEntryModel]:
    models = json.loads(CATALOG_FILE.read_text(encoding='utf-8'))['models']
    return [CatalogEntryModel(**m, created_at=0, updated_at=0) for m in models]


def disk(used_gb: float, total_gb: float = 128.0) -> DiskStatus:
    s = Settings()
    return DiskStatus(
        path='/x',
        models_mounted=True,
        total_gb=total_gb,
        used_gb=used_gb,
        free_gb=total_gb - used_gb,
        used_pct=round(100 * used_gb / total_gb, 1),
        level=level_for(100 * used_gb / total_gb, s),
        app_gb=8,
        other_gb=22,
        warning_pct=s.disk_warning_pct,
        critical_pct=s.disk_critical_pct,
        block_pct=s.disk_block_pct,
        margin_gb=s.disk_margin_gb,
    )


def installed_model(name, size, suggestion=None, protected=None, category='chat') -> InstalledModel:
    return InstalledModel(
        name=name,
        size_gb=size,
        category=category,
        estimate=estimate(size, 1.0, category, VM),
        suggestion=suggestion,
        protected=protected,
    )


####################
# Installed models
####################


def test_active_ratio_from_expert_counts():
    assert active_ratio_from({'gptoss.expert_count': 32, 'gptoss.expert_used_count': 4}) == pytest.approx(
        0.169, abs=0.01
    )
    assert active_ratio_from({'qwen3moe.expert_count': 128, 'qwen3moe.expert_used_count': 8}) == pytest.approx(
        0.109, abs=0.01
    )
    assert active_ratio_from({'llama.block_count': 32}) == 1.0


def test_category_and_name_helpers():
    assert category_from('qwen2.5-coder:14b', ['completion']) == 'code'
    assert category_from('gemma3:12b', ['completion', 'vision']) == 'vis'
    assert category_from('bge-m3:latest', ['embedding']) == 'emb'
    assert category_from('llama3.1:8b', ['completion', 'tools']) == 'chat'
    assert base_name('nous-hermes2:latest') == 'nous-hermes2'


####################
# Disk
####################


def test_disk_levels_and_download_check():
    s = Settings()
    assert level_for(50, s) == 'ok'
    assert level_for(82, s) == 'warning'
    assert level_for(92, s) == 'critical'
    assert level_for(95, s) == 'blocked'
    status = disk(105.3)  # 82%
    assert check_download(status, 5.0).fits
    blocked = check_download(status, 16.4)  # would end at 95%
    assert not blocked.fits
    assert blocked.used_pct_after == pytest.approx(95.1, abs=0.1)
    assert check_download(status, 16.4, freed_gb=12.3).fits


def test_projection():
    day = 86400
    now = datetime.now().timestamp()
    history = [[now - 30 * day, 87.0], [now - day, 104.0]]
    growth, days_left = projection(history, 105.0, 121.6)
    assert growth == pytest.approx(0.6, abs=0.05)
    assert days_left == pytest.approx(27.7, abs=2)
    assert projection([], 105, 121.6) == (None, None)


def test_banner_is_translated():
    banner = banner_for(disk(105.3))
    assert banner['id'] == 'my-local-ia-disk'
    assert banner['type'] == 'warning'
    assert 'Disk almost full: 82%' in banner['content']
    assert 'Disco quase cheio' in banner['i18n']['pt-BR']['content']
    assert 'Disco casi lleno' in banner['i18n']['es']['content']


def test_settings_validation():
    assert Settings().disk_block_pct == 95
    with pytest.raises(ValueError):
        Settings(robot_time='25:00')
    assert SettingsForm(disk_warning_pct=70).model_dump(exclude_none=True) == {'disk_warning_pct': 70}


####################
# Picks and alternatives
####################


def test_picks_for_the_vm():
    picks = {p.task: p for p in best_picks(catalog(), VM, [])}
    assert set(picks) == {'assistant', 'writing', 'coding', 'reasoning', 'vision', 'transcription', 'documents'}
    assert picks['assistant'].entry.id == 'gpt-oss-20b'
    assert picks['writing'].entry.id == 'gemma-3-12b'
    assert picks['coding'].entry.id == 'qwen-2-5-coder-7b'
    assert picks['documents'].entry.id == 'bge-m3'
    for pick in picks.values():
        assert pick.estimate.level in ('smooth', 'usable')


def test_bigger_server_gets_bigger_picks():
    big = Hardware(vram_gb=48, gpu_bandwidth_gbs=936, ram_for_models_gb=112, ram_bandwidth_gbs=40)
    picks = {p.task: p for p in best_picks(catalog(), big, [])}
    assert picks['assistant'].entry.size_gb > 30


def test_alternatives_when_the_model_does_not_fit():
    entries = catalog()
    target = next(e for e in entries if e.id == 'qwen3-vl-30b-a3b')
    status = disk(105.3)
    installed = [
        installed_model('deepseek-r1:14b', 7.7, suggestion='unused'),
        installed_model('llama3.1:8b', 4.6, suggestion='unused'),
        installed_model('gpt-oss:20b', 11.3),
        installed_model('bge-m3:latest', 1.1, suggestion='unused', protected='rag_embedding', category='emb'),
    ]
    alternatives = alternatives_for(target, entries, installed, status, VM)
    kinds = [a.kind for a in alternatives]
    assert 'smaller' in kinds and 'free_space' in kinds
    smaller = next(a for a in alternatives if a.kind == 'smaller')
    assert smaller.entry.category == 'vis' and smaller.entry.size_gb < target.size_gb
    free = next(a for a in alternatives if a.kind == 'free_space')
    # Removing the biggest unused model is already enough: only the minimum is suggested.
    assert free.remove == ['deepseek-r1:14b']
    assert free.used_pct_after < status.block_pct


####################
# Robot
####################


def test_robot_classify_and_describe():
    assert robot.classify('Qwen3 Coder 30B A3B Instruct', 'text-generation') == ('code', False)
    assert robot.classify('DeepSeek R1 Distill Llama 8B', 'text-generation') == ('chat', True)
    assert robot.classify('Qwen3 VL 8B', 'image-text-to-text') == ('vis', False)
    assert robot.classify('whisper large', 'automatic-speech-recognition') == ('stt', False)
    assert robot.active_ratio_from_name('unsloth/Qwen3-30B-A3B-GGUF', 30.5) == pytest.approx(0.098, abs=0.01)
    assert robot.display_name('unsloth/Qwen3-30B-A3B-GGUF') == 'Qwen3 30B A3B'
    info = {
        'cardData': {'base_model': 'Qwen/Qwen3-30B-A3B', 'language': ['en', 'pt'], 'license': 'apache-2.0'},
        'gguf': {'context_length': 32768},
    }
    description, use_for = robot.describe(info, 'unsloth/Qwen3-30B-A3B-GGUF', 'chat', False, 30.5, 0.098, 'gguf')
    assert set(description) == {'en', 'pt-BR', 'es'}
    assert description['en'].startswith('Text model by Qwen with 30B parameters (MoE, ~3.0B active per token).')
    assert 'Suporta português' in description['pt-BR']
    assert 'permite uso comercial' in description['es']
    assert use_for['en'] == 'Chat and general tasks'


def test_robot_schedule():
    s = Settings(robot_time='06:17')
    morning = datetime(2026, 10, 25, 6, 20)
    assert robot.is_due(s, None, morning)
    assert not robot.is_due(s, None, datetime(2026, 10, 25, 6, 0))
    assert not robot.is_due(s, int(morning.timestamp()) - 3600, morning)
    assert robot.is_due(s, int(morning.timestamp()) - 86400, morning)
    assert not robot.is_due(Settings(robot_frequency='manual'), None, morning)
    weekly = Settings(robot_frequency='weekly')
    assert not robot.is_due(weekly, int(morning.timestamp()) - 3 * 86400, morning)


####################
# Prefill
####################


def test_prefill_estimate():
    fast = estimate(7.7, 1.0, 'chat', VM)
    slow = estimate(16.9, 1.0, 'chat', VM)
    assert fast.prefill_tps > 500
    assert slow.prefill_tps < fast.prefill_tps
    assert estimate(1.6, 1.0, 'stt', VM).prefill_tps is None


@pytest.mark.asyncio
async def test_robot_run_saves_new_models(monkeypatch):
    from open_webui.my_local_ia.catalog import CatalogEntries

    listing = {
        'unsloth': [
            {
                'id': 'unsloth/NewModel-7B-GGUF',
                'pipeline_tag': 'text-generation',
                'downloads': 5000,
                'createdAt': '2026-10-20',
            },
            {'id': 'unsloth/Tiny-GGUF', 'pipeline_tag': 'text-generation', 'downloads': 10, 'createdAt': '2026-10-21'},
            {
                'id': 'unsloth/gemma-3-12b-it-GGUF',
                'pipeline_tag': 'image-text-to-text',
                'downloads': 9000,
                'createdAt': '2026-10-19',
            },
        ],
    }
    details = {
        'unsloth/NewModel-7B-GGUF': {
            'gguf': {'total': 7.0e9, 'context_length': 131072},
            'cardData': {'license': 'mit', 'language': ['en']},
        },
        'unsloth/gemma-3-12b-it-GGUF': {'gguf': {'total': 12.0e9}},
    }

    async def fake_get_json(url):
        if '?author=' in url:
            return listing.get(url.split('author=')[1].split('&')[0], [])
        if '?pipeline_tag=' in url:
            return []
        return details[url.rsplit('/models/', 1)[1]]

    monkeypatch.setattr(robot, 'get_json', fake_get_json)
    await CatalogEntries.ensure_table()
    await CatalogEntries.seed_curated()
    status = await robot.run(Settings(robot_sources=['unsloth']))
    assert status['error'] is None
    assert status['added'] == 1  # Tiny: too few downloads; Gemma 3 12B: already in the curated catalog
    entry = await CatalogEntries.get_by_id('hf-unsloth-newmodel-7b-gguf')
    assert entry.source == 'auto'
    assert entry.size_gb == 4.2
    assert entry.ollama == 'hf.co/unsloth/NewModel-7B-GGUF'
    assert 'Context of up to 128K tokens' in entry.description['en']
    assert 'Licença mit: permite uso comercial' in entry.description['pt-BR']
    # A second run with the same results adds nothing new.
    assert (await robot.run(Settings(robot_sources=['unsloth'])))['added'] == 0


def test_pulled_at_reads_ollama_dates():
    from open_webui.my_local_ia.installed import pulled_at

    assert pulled_at({'modified_at': '2026-10-20T10:00:00Z'}) == 1792490400
    assert pulled_at({'modified_at': '2026-10-20T07:00:00.123456789-03:00'}) == 1792490400
    assert pulled_at({'modified_at': 'yesterday'}) is None
    assert pulled_at({}) is None


def test_function_calling_mode_for_ollama_models():
    from open_webui.my_local_ia.tool_calling import mode_for, parameters_b

    assert parameters_b({'parameter_size': '7.6B'}) == 7.6
    assert abs(parameters_b({'parameter_size': '494.03M'}) - 0.494) < 0.001
    assert parameters_b({}) is None
    tools = ['completion', 'tools']
    # Coder models answer with the tool call as JSON text: keep tools out of their requests.
    assert mode_for('qwen2.5-coder:7b', tools, {'parameter_size': '7.6B'}) == 'legacy'
    assert mode_for('qwen2.5-coder:32b', tools, {'parameter_size': '32.8B'}) == 'legacy'
    assert mode_for('llama3.2:3b', tools, {'parameter_size': '3.2B'}) == 'legacy'
    # No tool support at all, or too small.
    assert mode_for('gemma2:9b', ['completion'], {'parameter_size': '9.2B'}) == 'legacy'
    assert mode_for('qwen3:1.7b', tools + ['thinking'], {'parameter_size': '1.7B'}) == 'legacy'
    # Good tool callers keep native mode.
    assert mode_for('gpt-oss:20b', tools + ['thinking'], {'parameter_size': '20.9B'}) is None
    assert mode_for('qwen2.5:14b', tools, {'parameter_size': '14.8B'}) is None
    assert mode_for('llama3.1:8b', tools, {'parameter_size': '8.0B'}) is None
    assert mode_for('qwen3-coder:30b', tools, {'parameter_size': '30.5B'}) is None


def test_hardware_refresh_only_when_it_changed(monkeypatch):
    from open_webui.my_local_ia import catalog
    from open_webui.my_local_ia.hardware import Hardware

    async def scenario():
        saved = {}
        calls = []

        async def get(key, default=None):
            return saved.get(key, default)

        async def upsert(updates, **kwargs):
            saved.update(updates)

        machine = {'ram': 15.7}

        def fake_detect(measure_ram=True):
            calls.append(measure_ram)
            return Hardware(ram_total_gb=machine['ram'], ram_for_models_gb=machine['ram'] - 4, cpu_threads=4)

        monkeypatch.setattr(catalog.Config, 'get', get)
        monkeypatch.setattr(catalog.Config, 'upsert', upsert)
        monkeypatch.setattr(catalog, 'detect', fake_detect)

        assert await catalog.refresh_hardware_if_changed() is True  # nothing saved yet
        assert await catalog.refresh_hardware_if_changed() is False
        machine['ram'] = 31.4  # the VM got more memory
        assert await catalog.refresh_hardware_if_changed() is True
        assert saved[catalog.HARDWARE_DETECTED_KEY]['ram_total_gb'] == 31.4
        # Quick checks skip the RAM benchmark; only real changes run the full detection.
        assert calls == [False, True, False, False, True]

    asyncio.run(scenario())

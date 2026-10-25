"""Reads the official Ollama library (ollama.com/library) for the model robot.

The site has no public API for the list, so the page is parsed through the test
markers it puts on every model (x-test-model, x-test-size…). The download size
of each tag comes from the Ollama registry (the standard OCI manifest API), so
it is exact. When the page format changes, `parse_library` finds nothing and the
robot reports it instead of emptying the catalog.
"""

import asyncio
import html
import logging
import re
from typing import Optional

import aiohttp
from open_webui.utils.session_pool import get_session

log = logging.getLogger(__name__)

LIBRARY_URL = 'https://ollama.com/library?sort=popular'
REGISTRY = 'https://registry.ollama.ai/v2/library'
MANIFEST_ACCEPT = 'application/vnd.docker.distribution.manifest.v2+json'
TIMEOUT = aiohttp.ClientTimeout(total=60)
GB_PER_BILLION = 0.6  # Q4_K_M, used only when the registry does not answer

_ITEM = re.compile(r'<li[^>]*\bx-test-model\b[^>]*>(.*?)</li>', re.S)


def _texts(attribute: str, block: str) -> list[str]:
    found = re.findall(r'<span[^>]*\b' + attribute + r'\b[^>]*>(.*?)</span>', block, re.S)
    return [html.unescape(re.sub(r'<[^>]+>', '', t)).strip() for t in found]


def parse_count(text: str) -> int:
    """'63.5M' → 63500000, '820K' → 820000, '1,234' → 1234."""
    match = re.match(r'^\s*([\d.,]+)\s*([KMB]?)', text or '', re.I)
    if not match:
        return 0
    value = float(match.group(1).replace(',', ''))
    return int(value * {'': 1, 'K': 1e3, 'M': 1e6, 'B': 1e9}[match.group(2).upper()])


def parse_library(page: str) -> list[dict]:
    """[{name, description, capabilities, sizes, pulls}] in the page's order (most popular first)."""
    models = []
    for block in _ITEM.findall(page):
        href = re.search(r'href="/library/([^"/?#]+)"', block)
        title = _texts('x-test-search-response-title', block)
        name = (title[0] if title else '') or (href.group(1) if href else '')
        if not name:
            continue
        description = re.search(r'<p[^>]*>(.*?)</p>', block, re.S)
        pulls = _texts('x-test-pull-count', block)
        models.append(
            {
                'name': name,
                'description': html.unescape(re.sub(r'<[^>]+>', '', description.group(1))).strip()
                if description
                else '',
                'capabilities': [c.lower() for c in _texts('x-test-capability', block)],
                'sizes': [s.lower() for s in _texts('x-test-size', block)],
                'pulls': parse_count(pulls[0]) if pulls else 0,
            }
        )
    return models


def size_params(tag: str) -> tuple[Optional[float], Optional[float]]:
    """(total, active) billions of parameters from a size tag.

    '8b' → (8, None); '0.6b' → (0.6, None); 'e4b' → (4, None) (Gemma 3n, effective size);
    '30b-a3b' → (30, 3); '16x17b' → (None, 17) (experts × size: the total comes from the download).
    """
    experts = re.fullmatch(r'(\d+)x(\d+(?:\.\d+)?)b', tag)
    if experts:
        return None, float(experts.group(2))
    match = re.fullmatch(r'e?(\d+(?:\.\d+)?)([bm])(?:-a(\d+(?:\.\d+)?)b)?', tag)
    if not match:
        return None, None
    total = float(match.group(1)) / (1000 if match.group(2) == 'm' else 1)
    return total, float(match.group(3)) if match.group(3) else None


async def download_gb(name: str, tag: str) -> Optional[float]:
    """Size of `name:tag` in GB from the registry manifest (sum of its layers)."""
    session = await get_session()
    try:
        async with session.get(
            f'{REGISTRY}/{name}/manifests/{tag}', headers={'Accept': MANIFEST_ACCEPT}, timeout=TIMEOUT
        ) as r:
            if r.status != 200:
                return None
            manifest = await r.json(content_type=None)
    except Exception as e:
        log.debug(f'my-local-ia robot: manifest {name}:{tag}: {e}')
        return None
    total = sum(layer.get('size') or 0 for layer in manifest.get('layers') or [])
    return round(total / 1e9, 1) if total else None


async def fetch_library() -> list[dict]:
    session = await get_session()
    async with session.get(LIBRARY_URL, timeout=TIMEOUT) as r:
        r.raise_for_status()
        return parse_library(await r.text())


async def with_sizes(variants: list[tuple[dict, str]], concurrency: int = 8) -> list[Optional[float]]:
    """Download size of every (family, tag), a few requests at a time."""
    limit = asyncio.Semaphore(concurrency)

    async def one(family: dict, tag: str) -> Optional[float]:
        async with limit:
            return await download_gb(family['name'], tag)

    return await asyncio.gather(*(one(family, tag) for family, tag in variants))

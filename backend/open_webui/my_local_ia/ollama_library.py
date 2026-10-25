"""Reads the official Ollama library (ollama.com/library) for the model robot.

The site has no public API for the list, so only the model names are taken
from the page: every link to /library/<name>, which survives layout changes.
Description, capability badges, sizes and pull counts are read from the part
of the page around each link when they are there. The sizes that really exist
come from the Ollama registry (the standard OCI API: tags list and manifests),
which also gives the exact download size. When the page has no model links,
`parse_library` returns nothing and the robot reports it instead of emptying
the catalog.
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

_LINK = re.compile(r'href="/library/([a-z0-9][a-z0-9._-]*)"', re.I)
CAPABILITIES = {'tools', 'vision', 'thinking', 'embedding', 'audio', 'cloud'}
# A size tag on its own: 8b, 0.6b, 360m, e4b (Gemma 3n), 30b-a3b (MoE), 16x17b (experts × size).
SIZE_TAG = re.compile(r'(?:e?\d+(?:\.\d+)?[bm](?:-a\d+(?:\.\d+)?b)?|\d+x\d+(?:\.\d+)?b)')


def _text(fragment: str) -> str:
    return re.sub(r'\s+', ' ', html.unescape(re.sub(r'<[^>]+>', ' ', fragment))).strip()


def parse_count(text: str) -> int:
    """'63.5M' → 63500000, '820K' → 820000, '1,234' → 1234."""
    match = re.match(r'^\s*([\d.,]+)\s*([KMB]?)', text or '', re.I)
    if not match:
        return 0
    value = float(match.group(1).replace(',', ''))
    return int(value * {'': 1, 'K': 1e3, 'M': 1e6, 'B': 1e9}[match.group(2).upper()])


def _details(name: str, block: str) -> dict:
    """What the page says about one model, from the HTML between its link and the next model's."""
    description = ''
    for paragraph in re.findall(r'<p[^>]*>(.*?)</p>', block, re.S):
        text = _text(paragraph)
        if len(text) > 20 and not re.search(r'\bpulls?\b', text, re.I):
            description = text
            break
    # Sizes are lowercase on the site (8b, 300m); pull counts are uppercase (40M), so case matters here.
    labels = [_text(t) for t in re.findall(r'<span[^>]*>([^<]{1,30})</span>', block)]
    pulls = re.search(r'x-test-pull-count[^>]*>\s*([\d.,]+\s*[KMB]?)', block) or re.search(
        r'([\d.,]+\s*[KMB]?)\s*(?:<[^>]*>|&nbsp;|\s)*pulls', block, re.I
    )
    return {
        'name': name,
        'description': description,
        'capabilities': [c for c in dict.fromkeys(label.lower() for label in labels) if c in CAPABILITIES],
        'sizes': [t for t in dict.fromkeys(labels) if SIZE_TAG.fullmatch(t) or t == 'cloud'],
        'pulls': parse_count(pulls.group(1)) if pulls else 0,
    }


def parse_library(page: str) -> list[dict]:
    """[{name, description, capabilities, sizes, pulls}] in the page's order (most popular first)."""
    links = [(m.start(), m.group(1).lower()) for m in _LINK.finditer(page)]
    starts: list[tuple[int, str]] = []
    for position, name in links:
        if ':' in name:
            continue  # a link to one tag (name:tag), not to the model
        if not starts or starts[-1][1] != name:
            starts.append((position, name))
    models, seen = [], set()
    for i, (position, name) in enumerate(starts):
        end = starts[i + 1][0] if i + 1 < len(starts) else len(page)
        if name in seen:
            continue
        seen.add(name)
        models.append(_details(name, page[position:end]))
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


MISSING = -1.0  # download_gb: the registry says this tag does not exist


async def download_gb(name: str, tag: str) -> Optional[float]:
    """Size of `name:tag` in GB from the registry manifest (sum of its layers).

    MISSING when the registry has no such tag, None when it could not be asked.
    """
    session = await get_session()
    try:
        async with session.get(
            f'{REGISTRY}/{name}/manifests/{tag}', headers={'Accept': MANIFEST_ACCEPT}, timeout=TIMEOUT
        ) as r:
            if r.status == 404:
                return MISSING
            if r.status != 200:
                return None
            manifest = await r.json(content_type=None)
    except Exception as e:
        log.debug(f'my-local-ia robot: manifest {name}:{tag}: {e}')
        return None
    total = sum(layer.get('size') or 0 for layer in manifest.get('layers') or [])
    return round(total / 1e9, 1) if total else None


async def registry_sizes(name: str) -> Optional[list[str]]:
    """Size tags of a model in the registry (8b, 30b-a3b…), or None when the registry did not answer."""
    session = await get_session()
    try:
        async with session.get(f'{REGISTRY}/{name}/tags/list', timeout=TIMEOUT) as r:
            if r.status != 200:
                return None
            tags = (await r.json(content_type=None)).get('tags') or []
    except Exception as e:
        log.debug(f'my-local-ia robot: tags {name}: {e}')
        return None
    return [t for t in tags if SIZE_TAG.fullmatch(t)]


async def fetch_library() -> list[dict]:
    session = await get_session()
    async with session.get(LIBRARY_URL, timeout=TIMEOUT) as r:
        r.raise_for_status()
        return parse_library(await r.text())


async def fill_sizes(families: list[dict], concurrency: int = 8) -> None:
    """Replaces each family's sizes with the registry's when it answers (the page may not list them)."""
    limit = asyncio.Semaphore(concurrency)

    async def one(family: dict) -> None:
        async with limit:
            sizes = await registry_sizes(family['name'])
        if sizes:
            family['sizes'] = sorted(set(sizes), key=lambda t: size_params(t)[0] or 0)

    await asyncio.gather(*(one(family) for family in families))


async def with_sizes(variants: list[tuple[dict, str]], concurrency: int = 8) -> list[Optional[float]]:
    """Download size of every (family, tag), a few requests at a time."""
    limit = asyncio.Semaphore(concurrency)

    async def one(family: dict, tag: str) -> Optional[float]:
        async with limit:
            return await download_gb(family['name'], tag)

    return await asyncio.gather(*(one(family, tag) for family, tag in variants))

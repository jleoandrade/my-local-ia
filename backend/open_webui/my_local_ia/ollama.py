"""Talks to the first Ollama connection configured in Open WebUI.

Model management (list, details, pull, delete) is done on one Ollama: the one
on this server. Open WebUI's own /ollama proxy is admin-only for pull and
delete, so my-local-ia calls Ollama directly with its own permission rules.
"""

import json
import logging
from collections.abc import AsyncIterator
from typing import Optional

import aiohttp
from open_webui.routers.ollama import get_ollama_connection_config, resolve_api_config
from open_webui.utils.session_pool import get_session

log = logging.getLogger(__name__)

TIMEOUT = aiohttp.ClientTimeout(total=30)
# Pulls take minutes to hours; only the gap between progress lines is bounded.
PULL_TIMEOUT = aiohttp.ClientTimeout(total=None, sock_read=600)

_show_cache: dict[str, dict] = {}  # digest -> /api/show answer


class OllamaUnavailable(Exception):
    pass


async def connection() -> tuple[str, dict]:
    """Base URL and headers of the first Ollama connection."""
    urls, api_configs = await get_ollama_connection_config()
    if not urls:
        raise OllamaUnavailable('no Ollama connection configured')
    url = urls[0].rstrip('/')
    key = resolve_api_config(api_configs, 0, url).get('key')
    headers = {'Authorization': f'Bearer {key}'} if key else {}
    return url, headers


async def _request(method: str, path: str, payload: Optional[dict] = None) -> dict:
    url, headers = await connection()
    session = await get_session()
    try:
        async with session.request(method, f'{url}{path}', json=payload, headers=headers, timeout=TIMEOUT) as r:
            if r.status >= 400:
                raise OllamaUnavailable(f'{path}: HTTP {r.status} {await r.text()}')
            text = await r.text()
            return json.loads(text) if text else {}
    except aiohttp.ClientError as e:
        raise OllamaUnavailable(f'{path}: {e}') from e


async def list_models() -> list[dict]:
    """Installed models, as in /api/tags (name, size in bytes, digest, details, modified_at)."""
    return (await _request('GET', '/api/tags')).get('models', [])


async def show_model(name: str, digest: str = '') -> dict:
    """Details of one model (capabilities, model_info). Cached by digest: it never changes for a digest."""
    if digest and digest in _show_cache:
        return _show_cache[digest]
    info = await _request('POST', '/api/show', {'model': name})
    info.pop('modelfile', None)  # large and unused here
    info.pop('tensors', None)
    if digest:
        _show_cache[digest] = info
    return info


async def delete_model(name: str) -> None:
    await _request('DELETE', '/api/delete', {'model': name})


async def pull_model(name: str) -> AsyncIterator[bytes]:
    """Streams Ollama's NDJSON progress lines ({"status", "total", "completed"}) as they arrive."""
    url, headers = await connection()
    session = await get_session()
    try:
        async with session.post(
            f'{url}/api/pull', json={'model': name, 'stream': True}, headers=headers, timeout=PULL_TIMEOUT
        ) as r:
            if r.status >= 400:
                yield json.dumps({'error': f'HTTP {r.status}: {await r.text()}'}).encode() + b'\n'
                return
            async for line in r.content:
                if line.strip():
                    yield line if line.endswith(b'\n') else line + b'\n'
    except aiohttp.ClientError as e:
        yield json.dumps({'error': str(e)}).encode() + b'\n'

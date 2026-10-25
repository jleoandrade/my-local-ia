"""Default function calling mode for Ollama models.

Open WebUI sends its built-in tools (time, notes, calendar, memory…) with every chat in "native"
mode. Models without tool support make Ollama refuse the request, and some models that claim it
(qwen2.5-coder, the smallest ones) answer with the tool call as plain JSON text instead of the
answer the user asked for. For those, "legacy" mode keeps the tools out of the model's request.

An explicit choice (in the chat or in the model's Advanced Params) always wins over this default.
"""

import logging
import re
from typing import Optional

from open_webui.my_local_ia import ollama

log = logging.getLogger(__name__)

# Models that advertise tools but write the call as text or call tools for any question.
UNRELIABLE = re.compile(
    r'(^|/)(qwen2\.5-coder|qwen2\.5vl|deepseek-coder|codellama|codegemma|starcoder2|llama3\.2|smollm2?|phi4-mini|granite3\.\d-moe)(:|$)'
)
# Below this size, tool calling is too erratic to send tools on every message.
MIN_PARAMS_B = 4.0


def parameters_b(details: dict) -> Optional[float]:
    """'7.6B' → 7.6, '494.03M' → 0.494; None when Ollama does not say."""
    match = re.match(r'^\s*([\d.]+)\s*([BM])', str(details.get('parameter_size') or ''), re.I)
    if not match:
        return None
    value = float(match.group(1))
    return value / 1000 if match.group(2).upper() == 'M' else value


def mode_for(name: str, capabilities: list[str], details: dict) -> Optional[str]:
    """'legacy' when native tool calling would break this model's answers, else None (keep native)."""
    if 'tools' not in capabilities:
        return 'legacy'
    if UNRELIABLE.search(name.lower()):
        return 'legacy'
    size = parameters_b(details)
    if size is not None and size < MIN_PARAMS_B:
        return 'legacy'
    return None


async def default_function_calling(model: dict) -> Optional[str]:
    """Function calling mode for a chat with `model` when nobody chose one."""
    if model.get('owned_by') != 'ollama':
        return None
    tag = model.get('ollama') or {}
    name = tag.get('model') or tag.get('name') or model.get('id', '')
    try:
        info = await ollama.show_model(name, tag.get('digest', ''))
    except Exception as e:  # never block a chat because of this
        log.debug(f'my-local-ia: could not read {name} to choose the function calling mode: {e}')
        return None
    return mode_for(name, info.get('capabilities') or [], info.get('details') or tag.get('details') or {})

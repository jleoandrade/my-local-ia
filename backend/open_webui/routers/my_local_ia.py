import json
import logging
import unicodedata
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import StreamingResponse
from open_webui.constants import ERROR_MESSAGES
from open_webui.my_local_ia import disk, installed, ollama, picks, robot
from open_webui.my_local_ia.catalog import (
    CatalogEntries,
    CatalogEntryModel,
    detect_hardware,
    get_hardware,
    set_overrides,
)
from open_webui.my_local_ia.estimate import Estimate, estimate
from open_webui.my_local_ia.hardware import Hardware
from open_webui.my_local_ia.settings import Settings, SettingsForm, get_settings, update_settings
from open_webui.utils.auth import get_admin_user, get_verified_user
from pydantic import BaseModel

log = logging.getLogger(__name__)

router = APIRouter()

############################
# Hardware
############################


@router.get('/hardware', response_model=Hardware)
async def get_hardware_info(user=Depends(get_verified_user)):
    return await get_hardware()


@router.post('/hardware/detect', response_model=Hardware)
async def redetect_hardware(user=Depends(get_admin_user)):
    await detect_hardware()
    return await get_hardware()


class HardwareOverridesForm(BaseModel):
    """Values set by the admin. Send null to go back to the detected value."""

    vram_gb: Optional[float] = None
    gpu_bandwidth_gbs: Optional[float] = None
    gpu_efficiency: Optional[float] = None
    ram_for_models_gb: Optional[float] = None
    ram_bandwidth_gbs: Optional[float] = None


@router.post('/hardware/overrides', response_model=Hardware)
async def update_hardware_overrides(form_data: HardwareOverridesForm, user=Depends(get_admin_user)):
    updates = form_data.model_dump(exclude_unset=True)
    for key, value in updates.items():
        if value is not None and value < 0:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f'{key} must not be negative')
    if updates.get('gpu_efficiency') is not None and updates['gpu_efficiency'] > 1:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail='gpu_efficiency must be between 0 and 1')
    await set_overrides(updates)
    return await get_hardware()


############################
# Catalog
############################


def fold(text: str) -> str:
    """Lowercase without accents, so 'raciocinio' finds 'raciocínio'."""
    return ''.join(c for c in unicodedata.normalize('NFD', text.lower()) if not unicodedata.combining(c))


class CatalogModelResponse(CatalogEntryModel):
    estimate: Estimate


def with_estimate(model: CatalogEntryModel, hw: Hardware) -> CatalogModelResponse:
    return CatalogModelResponse(
        **model.model_dump(),
        estimate=estimate(model.size_gb, model.active_ratio, model.category, hw),
    )


@router.get('/models', response_model=list[CatalogModelResponse])
async def get_catalog(
    category: Optional[str] = None,
    level: Optional[str] = None,
    reasoning: Optional[bool] = None,
    q: Optional[str] = None,
    user=Depends(get_verified_user),
):
    """The catalog with estimates for this server, best first."""
    hw = await get_hardware()
    query = fold((q or '').strip())
    items = []
    for model in await CatalogEntries.get_all():
        if category and model.category != category:
            continue
        if reasoning is not None and model.reasoning != reasoning:
            continue
        texts = [model.name, *(model.description or {}).values(), *(model.use_for or {}).values()]
        if query and query not in fold(' '.join(texts)):
            continue
        item = with_estimate(model, hw)
        if level and item.estimate.level != level:
            continue
        items.append(item)
    items.sort(key=lambda m: (-m.estimate.score, -(m.estimate.tps or 0), m.name))
    return items


@router.get('/models/{model_id}', response_model=CatalogModelResponse)
async def get_catalog_model(model_id: str, user=Depends(get_verified_user)):
    model = await CatalogEntries.get_by_id(model_id)
    if model is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=ERROR_MESSAGES.NOT_FOUND)
    return with_estimate(model, await get_hardware())


############################
# Picks and installed models
############################


@router.get('/picks', response_model=list[picks.Pick])
async def get_picks(user=Depends(get_verified_user)):
    """The best model per task for this server."""
    try:
        installed_models = await installed.list_installed()
    except ollama.OllamaUnavailable:
        installed_models = []
    return picks.best_picks(await CatalogEntries.get_all(), await get_hardware(), installed_models)


@router.get('/installed', response_model=list[installed.InstalledModel])
async def get_installed(user=Depends(get_verified_user)):
    """Models installed in Ollama, with estimates, usage and removal suggestions."""
    try:
        return await installed.list_installed()
    except ollama.OllamaUnavailable as e:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(e))


async def removal_refusal(user, model: installed.InstalledModel, settings: Settings) -> Optional[str]:
    """Why this user cannot remove the model, or None. Admins can remove anything not protected."""
    if model.protected:
        return f'protected:{model.protected}'
    if user.role == 'admin':
        return None
    if not model.downloaded_by or model.downloaded_by.get('user_id') != user.id:
        return 'not_yours'
    if await installed.other_users_since(model.name, user.id, settings.unused_days):
        return 'used_by_others'
    return None


@router.delete('/installed/{name:path}')
async def delete_installed(name: str, user=Depends(get_verified_user)):
    models = {m.name: m for m in await installed.list_installed()}
    model = models.get(name)
    if model is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=ERROR_MESSAGES.NOT_FOUND)
    refusal = await removal_refusal(user, model, await get_settings())
    if refusal:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=refusal)
    await ollama.delete_model(name)
    await installed.forget_download(name)
    log.info(f'my-local-ia: {user.email} removed {name}')
    return {'removed': name}


############################
# Disk
############################


@router.get('/disk', response_model=disk.DiskStatus)
async def get_disk(user=Depends(get_verified_user)):
    return await disk.disk_status()


@router.post('/disk/check', response_model=disk.DiskStatus)
async def check_disk_now(user=Depends(get_admin_user)):
    """Measures now and updates the banner and webhook alerts."""
    return await disk.check_and_alert()


############################
# Downloads
############################


class PullCheckResponse(BaseModel):
    allowed: bool  # this user may download it
    check: disk.DownloadCheck
    alternatives: list[picks.Alternative] = []


class PullForm(BaseModel):
    catalog_id: Optional[str] = None  # any user (when downloads are open to users)
    model: Optional[str] = None  # any Ollama name: admins only


async def resolve_pull(form: PullForm, user) -> tuple[str, Optional[CatalogEntryModel]]:
    settings = await get_settings()
    if user.role != 'admin' and not settings.users_can_download:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail='downloads_disabled')
    if form.catalog_id:
        entry = await CatalogEntries.get_by_id(form.catalog_id)
        if entry is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=ERROR_MESSAGES.NOT_FOUND)
        if not entry.ollama:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail='not_in_ollama')
        return entry.ollama, entry
    if form.model and user.role == 'admin':
        return form.model.strip(), None
    raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail='catalog_id required')


async def pull_check(form: PullForm, user) -> PullCheckResponse:
    _, entry = await resolve_pull(form, user)
    status_now = await disk.disk_status()
    size = entry.size_gb if entry else 0.0
    check = disk.check_download(status_now, size)
    alternatives = []
    if entry and not check.fits:
        try:
            installed_models = await installed.list_installed()
        except ollama.OllamaUnavailable:
            installed_models = []
        alternatives = picks.alternatives_for(
            entry, await CatalogEntries.get_all(), installed_models, status_now, await get_hardware()
        )
    return PullCheckResponse(allowed=True, check=check, alternatives=alternatives)


@router.post('/pull/check', response_model=PullCheckResponse)
async def check_pull(form: PullForm, user=Depends(get_verified_user)):
    """Before downloading: does it fit, and what are the alternatives if it does not."""
    return await pull_check(form, user)


@router.post('/pull')
async def pull(form: PullForm, user=Depends(get_verified_user)):
    """Downloads a model into Ollama, streaming its progress as NDJSON. Refused if it does not fit the disk."""
    name, _ = await resolve_pull(form, user)
    result = await pull_check(form, user)
    if not result.check.fits:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail='no_space')

    async def stream():
        succeeded = False
        async for line in ollama.pull_model(name):
            try:
                succeeded = succeeded or json.loads(line).get('status') == 'success'
            except ValueError:
                pass
            yield line
        if succeeded:
            await installed.record_download(name if ':' in name else f'{name}:latest', user)
            log.info(f'my-local-ia: {user.email} downloaded {name}')

    return StreamingResponse(stream(), media_type='application/x-ndjson')


############################
# Settings and robot
############################


class PublicSettings(BaseModel):
    users_can_download: bool


@router.get('/settings/public', response_model=PublicSettings)
async def get_public_settings(user=Depends(get_verified_user)):
    return PublicSettings(users_can_download=(await get_settings()).users_can_download)


@router.get('/settings', response_model=Settings)
async def read_settings(user=Depends(get_admin_user)):
    return await get_settings()


@router.post('/settings', response_model=Settings)
async def write_settings(form: SettingsForm, user=Depends(get_admin_user)):
    try:
        settings = await update_settings(form)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    await disk.check_and_alert()  # thresholds or the banner switch may have changed
    return settings


@router.get('/robot')
async def robot_status(user=Depends(get_admin_user)):
    return await robot.get_status()


@router.post('/robot/run')
async def robot_run(user=Depends(get_admin_user)):
    return await robot.run()

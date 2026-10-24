import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from open_webui.constants import ERROR_MESSAGES
from open_webui.rmg.catalog import RmgModelModel, RmgModels, detect_hardware, get_hardware, set_overrides
from open_webui.rmg.estimate import Estimate, estimate
from open_webui.rmg.hardware import Hardware
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


class CatalogModelResponse(RmgModelModel):
    estimate: Estimate


def with_estimate(model: RmgModelModel, hw: Hardware) -> CatalogModelResponse:
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
    query = (q or '').strip().lower()
    items = []
    for model in await RmgModels.get_all():
        if category and model.category != category:
            continue
        if reasoning is not None and model.reasoning != reasoning:
            continue
        if query and query not in f'{model.name} {model.description or ""} {model.use_for or ""}'.lower():
            continue
        item = with_estimate(model, hw)
        if level and item.estimate.level != level:
            continue
        items.append(item)
    items.sort(key=lambda m: (-m.estimate.score, -(m.estimate.tps or 0), m.name))
    return items


@router.get('/models/{model_id}', response_model=CatalogModelResponse)
async def get_catalog_model(model_id: str, user=Depends(get_verified_user)):
    model = await RmgModels.get_by_id(model_id)
    if model is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=ERROR_MESSAGES.NOT_FOUND)
    return with_estimate(model, await get_hardware())

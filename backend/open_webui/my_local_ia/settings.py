"""Admin settings of my-local-ia, stored as one key in the Open WebUI config table."""

from typing import Literal, Optional

from open_webui.models.config import Config
from pydantic import BaseModel, Field

SETTINGS_KEY = 'my_local_ia.settings'

# Where the robot looks for new models: GGUF uploads from well-known converters
# (newest first) and, for audio and embeddings, the trending models of each task.
DEFAULT_ROBOT_SOURCES = ['unsloth', 'ggml-org', 'lmstudio-community', 'city96', 'QuantStack']


class Settings(BaseModel):
    # Downloads
    users_can_download: bool = True  # admins can always download

    # Disk monitoring
    disk_warning_pct: float = Field(80, ge=1, le=100)
    disk_critical_pct: float = Field(90, ge=1, le=100)
    disk_block_pct: float = Field(95, ge=1, le=100)  # downloads that would pass this are refused
    disk_margin_gb: float = Field(2, ge=0)  # kept free on top of every download
    disk_check_minutes: int = Field(5, ge=1, le=1440)
    unused_days: int = Field(30, ge=1)  # models unused this long are suggested for removal
    alert_banner: bool = True  # banner for every user while the disk is at warning level or above
    alert_webhook_url: str = ''  # Discord, Slack, Teams, Google Chat…

    # Robot that finds new models on Hugging Face
    robot_enabled: bool = True
    robot_frequency: Literal['daily', 'weekly', 'manual'] = 'daily'
    robot_time: str = Field('06:17', pattern=r'^([01]\d|2[0-3]):[0-5]\d$')  # server local time
    robot_min_downloads: int = Field(1000, ge=0)
    robot_max_models: int = Field(200, ge=1, le=1000)
    robot_sources: list[str] = Field(default_factory=lambda: list(DEFAULT_ROBOT_SOURCES))
    robot_trending_audio_embeddings: bool = True


class SettingsForm(BaseModel):
    """Partial update: only the fields that are sent change."""

    users_can_download: Optional[bool] = None
    disk_warning_pct: Optional[float] = None
    disk_critical_pct: Optional[float] = None
    disk_block_pct: Optional[float] = None
    disk_margin_gb: Optional[float] = None
    disk_check_minutes: Optional[int] = None
    unused_days: Optional[int] = None
    alert_banner: Optional[bool] = None
    alert_webhook_url: Optional[str] = None
    robot_enabled: Optional[bool] = None
    robot_frequency: Optional[Literal['daily', 'weekly', 'manual']] = None
    robot_time: Optional[str] = None
    robot_min_downloads: Optional[int] = None
    robot_max_models: Optional[int] = None
    robot_sources: Optional[list[str]] = None
    robot_trending_audio_embeddings: Optional[bool] = None


async def get_settings() -> Settings:
    saved = await Config.get(SETTINGS_KEY) or {}
    return Settings(**saved)


async def update_settings(form: SettingsForm) -> Settings:
    """Validates the merged result (thresholds must go up: warning <= critical <= block) and saves it."""
    merged = (await get_settings()).model_dump()
    merged.update(form.model_dump(exclude_none=True))
    settings = Settings(**merged)
    if not settings.disk_warning_pct <= settings.disk_critical_pct <= settings.disk_block_pct:
        raise ValueError('disk thresholds must satisfy warning <= critical <= block')
    settings.robot_sources = [s.strip() for s in settings.robot_sources if s.strip()]
    await Config.upsert({SETTINGS_KEY: settings.model_dump()})
    return settings

"""User preferences for update behavior."""

import json
import os
import time
from enum import Enum
from typing import Optional


class UpdatePreference(Enum):
    ASK = "ask"
    AUTO = "auto"
    NEVER = "never"


DEFAULT_CONFIG = {
    "update_preference": UpdatePreference.ASK.value,
    "last_check_time": 0,
    "check_interval_hours": 24,
}


class Config:
    def __init__(self, config_dir: str):
        self.config_dir = config_dir
        self.config_path = os.path.join(config_dir, "updater_config.json")
        self._config = self._load()

    def _load(self) -> dict:
        try:
            with open(self.config_path, "r") as f:
                loaded = json.load(f)
                config = DEFAULT_CONFIG.copy()
                config.update(loaded)
                return config
        except (IOError, OSError, json.JSONDecodeError):
            return DEFAULT_CONFIG.copy()

    def save(self) -> bool:
        try:
            os.makedirs(self.config_dir, exist_ok=True)
            with open(self.config_path, "w") as f:
                json.dump(self._config, f, indent=2)
            return True
        except (IOError, OSError):
            return False

    @property
    def update_preference(self) -> UpdatePreference:
        pref_str = self._config.get("update_preference", UpdatePreference.ASK.value)
        try:
            return UpdatePreference(pref_str)
        except ValueError:
            return UpdatePreference.ASK

    @update_preference.setter
    def update_preference(self, value: UpdatePreference) -> None:
        self._config["update_preference"] = value.value

    @property
    def last_check_time(self) -> float:
        return self._config.get("last_check_time", 0)

    @last_check_time.setter
    def last_check_time(self, value: float) -> None:
        self._config["last_check_time"] = value

    @property
    def check_interval_hours(self) -> int:
        return self._config.get("check_interval_hours", 24)

    @check_interval_hours.setter
    def check_interval_hours(self, value: int) -> None:
        self._config["check_interval_hours"] = value

    def should_check_for_updates(self) -> bool:
        if self.update_preference == UpdatePreference.NEVER:
            return False
        current_time = time.time()
        hours_since_check = (current_time - self.last_check_time) / 3600
        return hours_since_check >= self.check_interval_hours

    def record_check(self) -> None:
        self.last_check_time = time.time()
        self.save()

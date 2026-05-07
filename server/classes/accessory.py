from enum import Enum
from .item import Item
from pydantic import (
    field_validator
)


class Stat(str, Enum):
    DAMAGE = "dmg"
    MAX_HEALTH = "maxhp"
    HEALING_CAPACITY = "hc"
    DEFENCE = "def"


class Accessory(Item):
    what_stat_is_multiplied: Stat
    stat_multiplier: float

    @field_validator("stat_multiplier")
    @classmethod
    def validate_stat_multiplier(cls, v: float) -> float:
        if v <= 0:
            raise ValueError("stat_multiplier must be greater than 0")
        return v
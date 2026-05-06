from pydantic import (
    BaseModel
)

from item import Item
from enum import Enum

class Stat(str, Enum):
    DAMAGE = "dmg"
    MAX_HEALTH = "maxhp"
    HEALING_CAPASITY = "hc"
    DEFENCE = "def"


class Accessory(Item):
    what_stat_is_multiplied: Stat # For example "dmg" will increase the damage of the player
    stat_multiplier: float # This is the base multiplier of the accesory, so it is affected by the floor multiplier
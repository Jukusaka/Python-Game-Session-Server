from item import Item
from enum import Enum

from pydantic import (
    BaseModel,
    field_validator
)

class WeaponType(str, Enum):
    KNIGHT = "knight"
    CLERIC = "cleric"

class Weapon(BaseModel, Item):
    damage: int # The damage of the weapon
    healing_capacity: int # This should only be for clerics, the higher the number, the higher the ammount of health will be restored
    weapon_type: WeaponType

    @field_validator
    @classmethod
    def validate_damage(cls, v):
        if(v <= 0):
            raise ValueError('damage cannot be less or equal to 0')
        return v
    
    @field_validator('healing_capacity')
    @classmethod
    def validate_healing_capacity(cls, v, info):
        weapon_type = info.data.get('weapon_type')
        if v > 0 and weapon_type == WeaponType.KNIGHT:
            raise ValueError('Knights cannot use healing weapons')
        return v

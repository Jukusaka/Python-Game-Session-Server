from pydantic import (
    BaseModel,
    field_validator,
    ValidationError,
    ConfigDict,
    model_validator
)

from weapon import Weapon
from armour import Armour
from accessory import Accessory, Stat
from item import Item

from enum import Enum

# Remember the class with endums is with capital letters
class Player_Class(str, Enum):
    KNIGHT = "knight"
    CLERIC = "knight"

class Player(BaseModel):
    model_config = ConfigDict(validate_assignment=True) # If the value is updated, then it reruns the validation

    # General info
    player_name: str
    player_class: Player_Class # This is an enum!!!!! remember

    # Stats
    base_max_health: float # This is before stat modifiers
    max_health: float
    current_health: float
    base_damage: float # This is before stat modifiers
    damage: float # This is after stat modifiers
    base_healing_capacity: float # This is before stat modifiers
    healing_capacity: float
    armour: float

    # Items
    weapon_slot: Weapon
    armour_slot: Armour
    accessory_slot_1: Accessory
    accessory_slot_2: Accessory
    accessory_slot_3: Accessory

    # Validators

    # For general info

    @field_validator('player_name')
    @classmethod
    def check_alphanumeric(cls, v: str) -> str:
        if not v.isalnum():
            raise ValueError('Username must be alphanumeric (small or big latin letter and a number)')
        return v
    
    @field_validator('player_class')
    @classmethod
    def check_if_valid_class(cls, v: Player_Class) -> Player_Class:
        allowed = [Player_Class.KNIGHT, Player_Class.CLERIC]
        if v not in allowed:
            raise ValueError('The class of the player is not allowed')
        return v
    
    # For Stats

    @field_validator('base_max_health')
    @classmethod
    def check_if_valid_base_max_health(cls, v: float) -> float:
        if v <= 0:
            raise ValueError('Too little max hp of a player')
        return v
        
    # For items
    @field_validator('weapon_slot')
    @classmethod
    def check_if_valid_weapon(cls, v: Weapon) -> Weapon:
        if v is not Weapon:
            raise ValueError('New Weapon is not a weapon type')
        

    # Model validators
    @model_validator(mode='after')
    def validate_weapon(self):

        # Damage boosts from accesories are multiplicative
        damage_multipliers = 1
        if(self.accessory_slot_1.what_stat_is_multiplied == Stat.DAMAGE):
            damage_multipliers * (self.accessory_slot_1.stat_multiplier * self.self.accessory_slot_1.floor_multiplier)

        if(self.accessory_slot_2.what_stat_is_multiplied == Stat.DAMAGE):
            damage_multipliers * (self.accessory_slot_2.stat_multiplier * self.self.accessory_slot_2.floor_multiplier)

        if(self.accessory_slot_3.what_stat_is_multiplied == Stat.DAMAGE):
            damage_multipliers * (self.accessory_slot_3.stat_multiplier * self.self.accessory_slot_3.floor_multiplier)

        self.damage = (self.base_damage + self.weapon_slot.damage) * damage_multipliers
        



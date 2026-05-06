from pydantic import (
    BaseModel,
    field_validator,
    ValidationError,
    ConfigDict
)

from weapon import Weapon
from armour import Armour
from accessory import Accessory

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

    @field_validator('player_name')
    @classmethod
    def check_alphanumeric(cls, v: str) -> str:
        if not v.isalnum():
            raise ValueError('Username must be alphanumeric (small or big latin letter and a number)')
        return v
    
    @field_validator('player_class')
    @classmethod
    def check_if_valid_class(cls, new_player_class: Player_Class) -> Player_Class:
        allowed = [Player_Class.KNIGHT, Player_Class.CLERIC]
        if new_player_class not in allowed:
            raise ValueError('The class of the player is not allowed')
        return new_player_class

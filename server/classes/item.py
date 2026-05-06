from pydantic import (
    BaseModel
)

class Item(BaseModel):
    sprite_path: str # Path to the item in godot
    floor_multiplier: int # Depending on the floor obtained, this value will be higher to amplify the stats of items

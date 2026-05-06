import random

from pydantic import (
    BaseModel
)

class Enemy(BaseModel):
    max_hp: float
    current_hp: float
    room_number: int
    damage: float
    armour: int

    def take_damage(self, incoming_damage: int) -> int:
        """
        Apply damage to the enemy, accounting for armour.
        Returns the actual damage taken.
        """

        actual_damage = incoming_damage - self.armour

        self.current_hp = self.current_hp - actual_damage

        return actual_damage
    
    def deal_damage(self) -> int:
        if self.current_hp <= 0:
            return 0
        
        variance = random.randint(-2, 2) # ±2 variance

        return self.damage + variance
### 1. Architecture Overview
*   **Frontend (Game Client):** Godot Engine (using HTTPRequest nodes to poll the backend and send actions).
*   **Backend (Server):** Python with FastAPI (providing RESTful endpoints).
*   **Database:** PostgreSQL (storing persistent characters, rooms, and combat state).

### 2. Database Schema (PostgreSQL)
Note: In relational databases like PostgreSQL, creating a new table for every single game room causes severe performance and maintenance issues. Instead, we will use a single Room_Players and Room_Enemies table that links data to a specific room_id. This provides the exact same isolation and data storage requested but follows database best practices.

*   **Characters Table:** (Persistent player stats)
    *   id (UUID, Primary Key)
    *   name (String)
    *   class_type (Enum: 'Knight', 'Priest')
    *   max_hp, max_mp (Int)
    *   base_attack, base_defense (Int)
*   **Equipment Table:** (Linked to Characters)
    *   id (UUID, Primary Key)
    *   character_id (Foreign Key)
    *   slot (Enum: 'sword', 'shield', 'ring1', 'ring2', 'ring3')
    *   item_name (String)
    *   stat_bonus (JSON/Int)
*   **Rooms Table:** (The current state of the tower instance)
    *   id (UUID, Primary Key)
    *   status (Enum: 'waiting_for_players', 'fighting', 'game_over')
    *   current_floor (Int)
    *   current_turn_character_id (UUID, tracks whose turn it is)
*   **Room_Players Table:** (Live combat stats for players inside a room)
    *   room_id (Foreign Key)
    *   character_id (Foreign Key)
    *   current_hp, current_mp (Int)
    *   is_guarding (Boolean - halves damage taken this round)
*   **Room_Enemies Table:** (Live combat stats for up to 5 enemies in a room)
    *   id (UUID, Primary Key)
    *   room_id (Foreign Key)
    *   enemy_type (String)
    *   current_hp (Int)
    *   attack_power (Int)
    *   position_index (Int 1-5)

### 3. FastAPI Endpoints
These will be built using FastAPI, SQLAlchemy (for database ORM), and Pydantic (for data validation).

*   **Character Management:**
    *   POST /createCharacter - Takes name, class type (Knight/Priest). Initializes base HP/MP and default empty equipment.
    *   DELETE /deleteCharacter/{char_id} - Removes a character permanently.
    *   PUT /updateCharacterStats - Updates persistent stats/equipment (e.g., after beating a floor).
*   **Matchmaking & Room Management:**
    *   POST /startMatch - Creates a new room (status: waiting_for_players) or joins an existing one. If 4 players join, shifts status to fighting and generates Floor 1 enemies.
    *   GET /getMatchState/{room_id} - [Crucial for Polling] Returns the entire state of the room: current floor, all players' HP/MP, enemy HP, and current_turn_character_id.
*   **Combat Flow:**
    *   POST /updateMatch (or /submitAction) - A player submits their turn action.
        *   Payload: character_id, room_id, action_type (attack, big_attack, guard, small_heal, big_heal), target_id (enemy or friend).
        *   Server logic: Calculates damage/healing, updates database, shifts current_turn_character_id to the next player (or triggers the enemy turn if all players have gone).

### 4. Godot Frontend Architecture
**UI Layout:**
*   **Center Screen:** 2D rendering of your character, allies, and the 1-5 enemies.
*   **Left Side Panel (Inventory/Equipment/Action Bar):**
    *   Displays Character Portrait and Base Stats (HP/MP bars).
    *   5 Slots: Sword, Shield, Ring 1, Ring 2, Ring 3.
    *   Only becomes active/clickable when the polling detects current_turn_character_id == your_character_id.
    *   **Knight UI:** Buttons for [Attack], [Big Attack (costs MP)], [Guard], [Small Heal (costs MP)].
    *   **Priest UI:** Buttons for [Attack], [Big Heal (costs high MP)], [Guard], [Small Heal (costs MP)].

**Godot Polling Loop:**
1.  A Timer node set to 1.5 - 2.0 seconds.
2.  On timeout, Godot sends a HTTPRequest to GET /getMatchState/{room_id}.
3.  Godot parses the returned JSON.
4.  Updates HP/MP bars for allies and enemies.
5.  If it is your turn, UI unlocks and plays a "Your Turn!" animation.

### 5. Gameplay Loop Example
1. Lobby: 4 players hit startMatch. Backend creates a room, adds players, spawns 3 Goblin enemies, and sets it to Player 1's turn.
2. Polling: Every player's Godot client pings the server every 2 seconds. They see it's Player 1's turn.
3. Turn Action: Player 1 (Knight) selects "Big Attack" on Goblin #2. Godot sends POST /updateMatch.
4. Server Processing: FastAPI deducts MP from Player 1, removes HP from Goblin #2, and changes turn to Player 2.
5. Update: On the next polling tick, all clients see Goblin #2 took damage and it is now Player 2's turn.
6. Floor Clear: Once all enemies hit 0 HP, server grants loot/stats, increments current_floor, spawns new enemies, and resets turn logic.
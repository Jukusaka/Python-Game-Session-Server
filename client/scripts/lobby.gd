extends Control

const BASE_URL = "http://127.0.0.1:8000"

# Preloaded placeholder textures (Point these to your temp.png asset path)
const KNIGHT_SPRITE = preload("res://assets/ui/temp.png")
const CLERIC_SPRITE = preload("res://assets/ui/temp.png")
const EMPTY_SPRITE  = preload("res://assets/ui/temp.png") # Blank slot profile template

@onready var match_title_label: Label = %MatchTitleLabel
@onready var start_match_btn: Button = %StartMatchBtn

# Group node arrays for easy index looping across 4 player configurations
@onready var player_names: Array[Label] = [%P1_Name, %P2_Name, %P3_Name, %P4_Name]
@onready var player_sprites: Array[TextureRect] = [%P1_Sprite, %P2_Sprite, %P3_Sprite, %P4_Sprite]

@onready var lobby_http_request: HTTPRequest = $LobbyHTTPRequest
@onready var start_http_request: HTTPRequest = $StartHTTPRequest
@onready var poll_timer: Timer = $PollTimer

var is_polling: bool = false

func _ready() -> void:
	match_title_label.text = "Lobby Room ID: " + str(GlobalVariables.match_id)
	
	# Keep button turned off by default until verified as the Room Host
	start_match_btn.disabled = true
	start_match_btn.pressed.connect(_on_start_match_pressed)
	
	# Connect signals
	lobby_http_request.request_completed.connect(_on_lobby_poll_completed)
	start_http_request.request_completed.connect(_on_match_started_by_server)
	
	# Connect periodic updater
	poll_timer.timeout.connect(_poll_lobby_status)
	
	# Kickoff the initial check right away
	_poll_lobby_status()

func _poll_lobby_status() -> void:
	if is_polling or GlobalVariables.match_id == -1:
		return
		
	var headers = ["Content-Type: application/json"]
	# We query the server list and parse out our matching room entry
	var error = lobby_http_request.request(BASE_URL + "/getMatches", headers, HTTPClient.METHOD_GET)
	if error == OK:
		is_polling = true

func _on_lobby_poll_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	is_polling = false
	if response_code != 200:
		return
		
	var response_string = body.get_string_from_utf8()
	var json = JSON.new()
	
	if json.parse(response_string) == OK:
		var matches = json.get_data()
		if typeof(matches) == TYPE_ARRAY:
			for match_entry in matches:
				if int(match_entry.get("id")) == GlobalVariables.match_id:
					_process_lobby_state(match_entry)
					break

func _process_lobby_state(match_data: Dictionary) -> void:
	# Check if the host has already updated the match state to started
	if match_data.get("status") == "in_progress":
		_launch_game_world()
		return
		
	# Verify Room Host rules: enable Start Game ONLY if player_id matches player_1_id
	var host_id = match_data.get("player_1_id")
	if host_id != null and int(host_id) == GlobalVariables.player_id:
		start_match_btn.disabled = false
	else:
		start_match_btn.disabled = true
		
	# Synchronize active user profile panels 1 through 4
	var slots = ["player_1_id", "player_2_id", "player_3_id", "player_4_id"]
	for i in range(4):
		var slot_player_id = match_data.get(slots[i])
		if slot_player_id != null:
			_update_player_slot_details(int(slot_player_id), i)
		else:
			player_names[i].text = "Empty Slot..."
			player_sprites[i].texture = EMPTY_SPRITE

# Fetch dynamic player class choices and character names straight from database profiles
func _update_player_slot_details(id_to_fetch: int, slot_idx: int) -> void:
	var player_profile_request = HTTPRequest.new()
	add_child(player_profile_request)
	
	player_profile_request.request_completed.connect(func(result, response_code, headers, body):
		if response_code == 200:
			var data_string = body.get_string_from_utf8()
			var json = JSON.new()
			if json.parse(data_string) == OK:
				var profile = json.get_data()
				player_names[slot_idx].text = str(profile.get("player_name", "Unknown"))
				
				# Set graphic variants depending on chosen database class string entries
				var p_class = str(profile.get("player_class", "")).to_lower()
				if p_class == "knight":
					player_sprites[slot_idx].texture = KNIGHT_SPRITE
				elif p_class == "cleric":
					player_sprites[slot_idx].texture = CLERIC_SPRITE
				else:
					player_sprites[slot_idx].texture = EMPTY_SPRITE
		player_profile_request.queue_free()
	)
	
	player_profile_request.request(BASE_URL + "/player/" + str(id_to_fetch), ["Content-Type: application/json"], HTTPClient.METHOD_GET)

# --- Button Trigger Commands ---

func _on_start_match_pressed() -> void:
	start_match_btn.disabled = true # Lock interactions to prevent spam
	print("Creating match TEMP")
	#var headers = ["Content-Type: application/json"]
	#var url = BASE_URL + "/startMatch/" + str(GlobalVariables.match_id)
	#start_http_request.request(url, headers, HTTPClient.METHOD_POST)

func _on_match_started_by_server(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 200:
		_launch_game_world()
	else:
		start_match_btn.disabled = false # Re-enable if starting request dropped

func _launch_game_world() -> void:
	poll_timer.stop()
	print("Match matches state requirements! Transitioning into floor arena loop...")
	# Change this to point directly to your actual dungeon or battle map asset scene path
	get_tree().change_scene_to_file("res://scenes/battle_arena.tscn")

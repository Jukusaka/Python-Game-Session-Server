extends Control

const BASE_URL = "http://127.0.0.1:8000"

# Allocation Stats & Classes
var starter_points: int = 5
var attack_stat: int = 10
var defence_stat: int = 10

var classes: Array[String] = ["knight", "cleric"]
var current_class_index: int = 0

# Preload your small match UI card scene
@export var match_card_scene: PackedScene = preload("res://scenes/matchInfo.tscn")

# The UI Container where match cards will be instantiated (e.g., a VBoxContainer)
@onready var match_container: VBoxContainer = %RoomListContainer
@onready var poll_http_request: HTTPRequest = $HTTPRequest

# --- FIXED UNIQUE NODE REFERENCES ---
@onready var name_input: LineEdit = %NameInput
@onready var points_label: Label = %PointsLabel
@onready var class_portrait: TextureRect = %ClassPortrait  # Fixed spelling
@onready var def_label: Label = %DefenceRow/%DefLabel    # Explicitly pathing to avoid conflict
@onready var atk_label: Label = %AttackRow/%AtkLabel      # Assumes you rename this node to AtkLabel
@onready var log_message_label: Label = %LogMessageLabel
@onready var http_request: HTTPRequest = $HTTPRequest

func _ready() -> void:
	# Automatically bind buttons if they aren't bound in the inspector
	%DefMinusBtn.pressed.connect(_on_def_minus_btn_pressed)
	%DefPlusBtn.pressed.connect(_on_def_plus_btn_pressed)
	%AtkMinusBtn.pressed.connect(_on_atk_minus_btn_pressed)
	%AtkPlusBtn.pressed.connect(_on_atk_plus_btn_pressed)
	%PrevClassBtn.pressed.connect(_on_prev_class_btn_pressed)
	%NextClassBtn.pressed.connect(_on_next_class_btn_pressed)
	%CreateRoom.pressed.connect(_on_create_room_btn_pressed)
	
	update_ui()
	
	# 1. Connect the HTTP Request node's completion signal
	poll_http_request.request_completed.connect(_on_poll_request_completed)
	
	# 2. Setup the Polling Timer dynamically
	var poll_timer = Timer.new()
	poll_timer.wait_time = 2.0  # Poll every 2 seconds
	poll_timer.autostart = true
	poll_timer.one_shot = false
	
	# Connect the timer to fire the HTTP request
	poll_timer.timeout.connect(_fetch_matches)
	
	add_child(poll_timer)
	
	# Optional: Fire the first request immediately so you don't wait 2 seconds to start
	_fetch_matches()

func update_ui() -> void:
	if points_label: points_label.text = "Available points: " + str(starter_points)
	if def_label: def_label.text = str(defence_stat)
	if atk_label: atk_label.text = str(attack_stat)
	print("Current selected class: ", classes[current_class_index])
	
	if name_input && name_input.text.strip_edges() != "":
		log_message_label.text = ""

# --- Class Swapping Controls ---
func _on_prev_class_btn_pressed() -> void:
	current_class_index = (current_class_index - 1 + classes.size()) % classes.size()
	update_ui()

func _on_next_class_btn_pressed() -> void:
	current_class_index = (current_class_index + 1) % classes.size()
	update_ui()

# --- Stat Altering Handlers ---
func _on_def_minus_btn_pressed() -> void:
	if defence_stat > 1:
		defence_stat -= 1
		starter_points += 1
		update_ui()

func _on_def_plus_btn_pressed() -> void:
	if starter_points > 0:
		defence_stat += 1
		starter_points -= 1
		update_ui()

func _on_atk_minus_btn_pressed() -> void:
	if attack_stat > 1:
		attack_stat -= 1
		starter_points += 1
		update_ui()

func _on_atk_plus_btn_pressed() -> void:
	if starter_points > 0:
		attack_stat += 1
		starter_points -= 1
		update_ui()

# --- Room / Player Creation API Trigger ---
func _on_create_room_btn_pressed() -> void:
	var player_name = name_input.text.strip_edges()
	
	if player_name == "":
		log_message_label.text = "Your player has no name!!!"
		return
	
	if player_name.length() > 10:
		log_message_label.text = "Your player name has more than 10 letters!!!"
		return
		
	
	var chosen_class = classes[current_class_index]
	var is_cleric = (chosen_class == "cleric")
	
	var player_payload = {
		"player_name": player_name,
		"player_class": chosen_class,
		"base_max_health": 120.0 if chosen_class == "knight" else 90.0,
		"base_damage": attack_stat,
		"base_healing_capacity": 8.0 if is_cleric else 0.0,
		"base_defence": defence_stat
	}
	
	var json_body = JSON.stringify(player_payload)
	var headers = ["Content-Type: application/json"]
	
	log_message_label.text = "Creating player profile..."
	
	# Create a dynamic HTTPRequest just for creating the player
	var dynamic_request = HTTPRequest.new()
	add_child(dynamic_request)
	
	# Connect it to your specific function, and make it delete itself when done
	dynamic_request.request_completed.connect(_on_player_created)
	dynamic_request.request_completed.connect(func(_a,_b,_c,_d): dynamic_request.queue_free())
	
	dynamic_request.request(BASE_URL + "/addPlayer", headers, HTTPClient.METHOD_POST, json_body)

# --- Handlers are now cleanly split ---

func _on_player_created(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var response_string = body.get_string_from_utf8()
	
	if response_code in [200, 201]:
		var json = JSON.new()
		if json.parse(response_string) == OK:
			var player_data = json.get_data()
			var player_id = int(str(player_data.get("id")))
			print("player ID: " + str(player_id)) 
			log_message_label.text = "Player ready! Entering matchmaking slot..."
			
			# Now use your main/scene http_request node safely for step 2
			var content_headers = ["Content-Type: application/json"]
			http_request.request(BASE_URL + "/createMatch/" + str(player_id), content_headers, HTTPClient.METHOD_POST)
	else:
		print("Server Validation Error (422) Details: ", response_string)
		log_message_label.text = "Server Error: " + str(response_code)


func _fetch_matches() -> void:
	# Check if the HTTP node is already busy with an unfinished request
	if poll_http_request.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
		var headers = ["Content-Type: application/json"]
		poll_http_request.request(BASE_URL + "/getMatches", headers, HTTPClient.METHOD_GET)

# Handles the server response
func _on_poll_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		print("Polling failed with response code: ", response_code)
		return
		
	var response_string = body.get_string_from_utf8()
	var json = JSON.new()
	
	if json.parse(response_string) == OK:
		var response_data = json.get_data()
		
		# Expecting an Array of match dictionaries from your server
		if typeof(response_data) == TYPE_ARRAY:
			_update_match_list(response_data)
		else:
			print("Server did not return an array of matches!")


# Instantiates and repopulates the UI elements
func _update_match_list(matches: Array) -> void:
	# 1. Clear out ALL existing children from the container object
	for child in match_container.get_children():
		child.queue_free()
		
	# 2. Loop through the returned array and instantiate a scene for each match
	for match_data in matches:
		if match_card_scene:
			# Instantiate the small scene
			var card_instance = match_card_scene.instantiate()
			
			# Add it to your UI container element
			match_container.add_child(card_instance)
			
			# Pass the backend data into the card so it updates its own text/labels
			if card_instance.has_method("set_match_data"):
				card_instance.set_match_data(match_data)

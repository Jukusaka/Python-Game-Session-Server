extends Control

const BASE_URL = "http://127.0.0.1:8000"

# Allocation Stats & Classes
var starter_points: int = 5
var attack_stat: int = 10
var defence_stat: int = 10

var classes: Array[String] = ["knight", "cleric"]
var current_class_index: int = 0

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
	http_request.request_completed.connect(_on_network_request_completed)

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
	http_request.request(BASE_URL + "/addPlayer", headers, HTTPClient.METHOD_POST, json_body)

# --- Server Processing ---
func _on_network_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var response_string = body.get_string_from_utf8()
	
	if response_code == 200 or response_code == 201:
		var json = JSON.new()
		if json.parse(response_string) == OK:
			var player_data = json.get_data()
			var player_id = player_data.get("id")
			print("player ID: " + str(player_id)) 
			log_message_label.text = "Player ready! Entering matchmaking slot..."
			
	else:
		# --- ADD THIS LINE TO SEE THE EXACT ERROR ---
		print("Server Validation Error (422) Details: ", response_string)
		log_message_label.text = "Server Error: " + str(response_code)

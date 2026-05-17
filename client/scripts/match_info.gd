# match_display.gd
extends Control

@onready var match_id_label: Label = $MatchIDLabel
@onready var status_label: Label = $StatusLabel

# A function to populate this specific card's data
func set_match_data(match_data: Dictionary) -> void:
	match_id_label.text = match_data.get+ str(match_data.get("id", "N/A"))
	status_label.text = "Players: " + str(match_data.get("player_count", 0))

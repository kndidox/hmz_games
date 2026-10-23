extends Node

# SaveManager: gestiona la persistencia de récords y preferencias locales

var save_file_path: String = "user://save_data.json"

var _data: Dictionary = {
	"preferences": {
		"music_volume": 1.0,
		"sfx_volume": 1.0,
		"muted": false
	},
	"records": {}
}

func _ready() -> void:
	load_data()

func load_data() -> void:
	if not FileAccess.file_exists(save_file_path):
		return
	
	var file := FileAccess.open(save_file_path, FileAccess.READ)
	if not file:
		return
	
	var content := file.get_as_text()
	var json := JSON.new()
	var error := json.parse(content)
	if error == OK and typeof(json.data) == TYPE_DICTIONARY:
		var loaded_dict: Dictionary = json.data
		if loaded_dict.has("preferences") and typeof(loaded_dict["preferences"]) == TYPE_DICTIONARY:
			for key in loaded_dict["preferences"].keys():
				_data["preferences"][key] = loaded_dict["preferences"][key]
		if loaded_dict.has("records") and typeof(loaded_dict["records"]) == TYPE_DICTIONARY:
			for key in loaded_dict["records"].keys():
				_data["records"][key] = loaded_dict["records"][key]

func save_data() -> void:
	var file := FileAccess.open(save_file_path, FileAccess.WRITE)
	if not file:
		return
	
	var json_string := JSON.stringify(_data, "\t")
	file.store_string(json_string)

func get_high_score(game_id: String) -> int:
	if _data["records"].has(game_id) and _data["records"][game_id].has("high_score"):
		return int(_data["records"][game_id]["high_score"])
	return 0

func save_score(game_id: String, score: int) -> bool:
	var current_high := get_high_score(game_id)
	var games_played := 0
	if _data["records"].has(game_id) and _data["records"][game_id].has("games_played"):
		games_played = int(_data["records"][game_id]["games_played"])
	games_played += 1
	
	var is_new_record := false
	if score > current_high:
		current_high = score
		is_new_record = true
	
	_data["records"][game_id] = {
		"high_score": current_high,
		"games_played": games_played,
		"last_score": score
	}
	save_data()
	return is_new_record

func get_preference(key: String, default_value: Variant = null) -> Variant:
	if _data["preferences"].has(key):
		return _data["preferences"][key]
	return default_value

func set_preference(key: String, value: Variant) -> void:
	_data["preferences"][key] = value
	save_data()

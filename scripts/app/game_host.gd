extends Control

# GameHost: gestiona el ciclo de vida, instanciación y limpieza de minijuegos

var current_game_instance: Node = null
var current_game_id: String = ""

var game_manager: Node = null
var save_manager: Node = null
var audio_manager: Node = null

func _ready() -> void:
	var gm := _get_game_manager()
	if gm:
		gm.game_start_requested.connect(_on_game_start_requested)
		gm.game_exit_requested.connect(_on_game_exit_requested)

func _get_game_manager() -> Node:
	if game_manager != null:
		return game_manager
	if get_tree() and get_tree().root and get_tree().root.has_node("GameManager"):
		return get_tree().root.get_node("GameManager")
	return null

func _get_save_manager() -> Node:
	if save_manager != null:
		return save_manager
	if get_tree() and get_tree().root and get_tree().root.has_node("SaveManager"):
		return get_tree().root.get_node("SaveManager")
	return null

func _get_audio_manager() -> Node:
	if audio_manager != null:
		return audio_manager
	if get_tree() and get_tree().root and get_tree().root.has_node("AudioManager"):
		return get_tree().root.get_node("AudioManager")
	return null

func _on_game_start_requested(game_id: String) -> void:
	start_game(game_id)

func _on_game_exit_requested() -> void:
	unload_current_game()

func start_game(game_id: String) -> bool:
	unload_current_game()
	
	var gm := _get_game_manager()
	if gm == null or not gm.has_game(game_id):
		printerr("GameHost: no existe configuración para el juego: ", game_id)
		return false
	
	var info: Dictionary = gm.get_game_info(game_id)
	var scene_path: String = info.get("scene_path", "")
	if scene_path == "" or not ResourceLoader.exists(scene_path):
		printerr("GameHost: ruta de escena no válida: ", scene_path)
		return false
	
	var packed_scene: PackedScene = load(scene_path)
	if packed_scene == null:
		printerr("GameHost: no se pudo cargar la escena: ", scene_path)
		return false
	
	var instance: Node = packed_scene.instantiate()
	if instance == null:
		printerr("GameHost: no se pudo instanciar la escena: ", scene_path)
		return false
	
	current_game_id = game_id
	current_game_instance = instance
	add_child(current_game_instance)
	
	# Conexión de señales de contrato de minijuego
	if current_game_instance.has_signal("request_exit"):
		current_game_instance.connect("request_exit", Callable(self, "_on_minigame_request_exit"))
	if current_game_instance.has_signal("game_over"):
		current_game_instance.connect("game_over", Callable(self, "_on_minigame_game_over"))
	
	return true

func unload_current_game() -> void:
	if current_game_instance != null:
		if is_instance_valid(current_game_instance):
			if current_game_instance.has_signal("request_exit") and current_game_instance.is_connected("request_exit", Callable(self, "_on_minigame_request_exit")):
				current_game_instance.disconnect("request_exit", Callable(self, "_on_minigame_request_exit"))
			if current_game_instance.has_signal("game_over") and current_game_instance.is_connected("game_over", Callable(self, "_on_minigame_game_over")):
				current_game_instance.disconnect("game_over", Callable(self, "_on_minigame_game_over"))
			
			if current_game_instance.get_parent() == self:
				remove_child(current_game_instance)
			current_game_instance.queue_free()
		current_game_instance = null
		current_game_id = ""

func _on_minigame_request_exit() -> void:
	var gm := _get_game_manager()
	if gm:
		gm.exit_to_menu()

func _on_minigame_game_over(score: int) -> void:
	var sm := _get_save_manager()
	var am := _get_audio_manager()
	if sm and current_game_id != "":
		var is_new_record: bool = sm.save_score(current_game_id, score)
		if am:
			if is_new_record and score > 0:
				am.play_sfx("new_record")
			else:
				am.play_sfx("game_over")

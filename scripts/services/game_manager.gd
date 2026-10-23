extends Node

# GameManager: coordina el catálogo de juegos y transiciones de estado de la aplicación

enum State {
	MENU,
	IN_GAME,
	PAUSED
}

signal game_start_requested(game_id: String)
signal game_exit_requested()
signal state_changed(new_state: int)

var current_state: State = State.MENU

const GAMES: Dictionary = {
	"balloon_pop": {
		"id": "balloon_pop",
		"title": "Explota Globos",
		"description": "¡Toca todos los globos antes de que escapen!",
		"scene_path": "res://scenes/games/balloon_pop/balloon_pop.tscn"
	},
	"minesweeper": {
		"id": "minesweeper",
		"title": "Buscaminas",
		"description": "¡Despeja el campo sin detonar ninguna mina oculta!",
		"scene_path": "res://scenes/games/minesweeper/minesweeper.tscn"
	}
}

func start_game(game_id: String) -> void:
	if not GAMES.has(game_id):
		printerr("GameManager: juego no encontrado: ", game_id)
		return
	
	set_state(State.IN_GAME)
	game_start_requested.emit(game_id)

func exit_to_menu() -> void:
	set_state(State.MENU)
	game_exit_requested.emit()

func set_state(new_state: State) -> void:
	if current_state == new_state:
		return
	current_state = new_state
	state_changed.emit(current_state)

func get_available_games() -> Dictionary:
	return GAMES

func has_game(game_id: String) -> bool:
	return GAMES.has(game_id)

func get_game_info(game_id: String) -> Dictionary:
	return GAMES.get(game_id, {})

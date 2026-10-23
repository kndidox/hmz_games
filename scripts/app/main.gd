extends Control

# Main: orquestador raíz de la aplicación de minijuegos

@onready var menu_container: Control = $MenuContainer
@onready var game_host: Control = $GameHost
@onready var main_menu: Control = $MenuContainer/MainMenu

func _ready() -> void:
	var gm := _get_game_manager()
	if gm:
		gm.state_changed.connect(_on_game_state_changed)
	
	# Estado visual inicial: Menú activo
	_show_menu()

func _get_game_manager() -> Node:
	if get_tree() and get_tree().root and get_tree().root.has_node("GameManager"):
		return get_tree().root.get_node("GameManager")
	return null

func _on_game_state_changed(new_state: int) -> void:
	# 0: MENU, 1: IN_GAME, 2: PAUSED
	if new_state == 0:
		_show_menu()
	elif new_state == 1:
		_show_game()

func _show_menu() -> void:
	if menu_container:
		menu_container.visible = true
	if game_host:
		game_host.visible = false
	if main_menu and main_menu.has_method("refresh_records"):
		main_menu.refresh_records()

func _show_game() -> void:
	if menu_container:
		menu_container.visible = false
	if game_host:
		game_host.visible = true

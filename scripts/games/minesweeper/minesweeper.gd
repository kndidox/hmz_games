extends Control

# Minesweeper: Minijuego Buscaminas optimizado para formato vertical y control táctil

signal request_exit()
signal game_over(score: int)

enum ToolMode {
	DIG,
	FLAG
}

const CELL_SCENE = preload("res://scenes/games/minesweeper/mine_cell.tscn")

const DIFFICULTY_CONFIG: Dictionary = {
	"easy": {
		"id": "easy",
		"name": "Pequeño",
		"cols": 7,
		"rows": 9,
		"mines": 8,
		"cell_size": Vector2(84, 84),
		"save_key": "minesweeper_easy"
	},
	"medium": {
		"id": "medium",
		"name": "Mediano",
		"cols": 9,
		"rows": 12,
		"mines": 16,
		"cell_size": Vector2(66, 66),
		"save_key": "minesweeper_medium"
	},
	"hard": {
		"id": "hard",
		"name": "Grande",
		"cols": 11,
		"rows": 15,
		"mines": 30,
		"cell_size": Vector2(54, 54),
		"save_key": "minesweeper_hard"
	}
}

# Estado del juego
var current_difficulty: String = "easy"
var current_tool_mode: ToolMode = ToolMode.DIG
var is_playing: bool = false
var is_game_over: bool = false
var is_victory: bool = false
var first_click_done: bool = false
var flags_placed: int = 0
var elapsed_seconds: int = 0
var timer_accumulator: float = 0.0

var board_data: Array = [] # 2D Array [rows][cols] of Dictionaries
var cell_nodes: Dictionary = {} # Vector2i -> MineCell

# Referencias UI
@onready var level_select_view: Control = $LevelSelectView
@onready var game_view: Control = $GameView
@onready var grid_container: GridContainer = $GameView/BoardArea/CenterContainer/GridContainer

# HUD
@onready var back_button: Button = $GameView/HUD/TopBar/BackButton
@onready var mines_label: Label = $GameView/HUD/TopBar/MinesLabel
@onready var time_label: Label = $GameView/HUD/TopBar/TimeLabel
@onready var tool_toggle_button: Button = $GameView/HUD/TopBar/ToolToggleButton
@onready var restart_button: Button = $GameView/HUD/TopBar/RestartButton

# Level Select
@onready var select_back_button: Button = $LevelSelectView/MarginContainer/VBoxContainer/HeaderBar/BackButton
@onready var easy_card: Control = $LevelSelectView/MarginContainer/VBoxContainer/CardsContainer/EasyCard
@onready var medium_card: Control = $LevelSelectView/MarginContainer/VBoxContainer/CardsContainer/MediumCard
@onready var hard_card: Control = $LevelSelectView/MarginContainer/VBoxContainer/CardsContainer/HardCard
@onready var easy_button: Button = $LevelSelectView/MarginContainer/VBoxContainer/CardsContainer/EasyCard/HBox/Button
@onready var medium_button: Button = $LevelSelectView/MarginContainer/VBoxContainer/CardsContainer/MediumCard/HBox/Button
@onready var hard_button: Button = $LevelSelectView/MarginContainer/VBoxContainer/CardsContainer/HardCard/HBox/Button
@onready var easy_record_lbl: Label = $LevelSelectView/MarginContainer/VBoxContainer/CardsContainer/EasyCard/HBox/VBox/RecordLabel
@onready var medium_record_lbl: Label = $LevelSelectView/MarginContainer/VBoxContainer/CardsContainer/MediumCard/HBox/VBox/RecordLabel
@onready var hard_record_lbl: Label = $LevelSelectView/MarginContainer/VBoxContainer/CardsContainer/HardCard/HBox/VBox/RecordLabel

# Modal Game Over
@onready var game_over_modal: PanelContainer = $GameOverModal
@onready var modal_title: Label = $GameOverModal/MarginContainer/VBoxContainer/TitleLabel
@onready var new_record_badge: Label = $GameOverModal/MarginContainer/VBoxContainer/NewRecordBadge
@onready var modal_time_label: Label = $GameOverModal/MarginContainer/VBoxContainer/TimeLabel
@onready var modal_score_label: Label = $GameOverModal/MarginContainer/VBoxContainer/ScoreLabel
@onready var modal_high_score_label: Label = $GameOverModal/MarginContainer/VBoxContainer/HighScoreLabel
@onready var modal_retry_button: Button = $GameOverModal/MarginContainer/VBoxContainer/ButtonBox/RetryButton
@onready var modal_change_level_button: Button = $GameOverModal/MarginContainer/VBoxContainer/ButtonBox/ChangeLevelButton
@onready var modal_exit_button: Button = $GameOverModal/MarginContainer/VBoxContainer/ButtonBox/ExitButton

func _ready() -> void:
	_connect_ui_signals()
	show_level_selection()

func _exit_tree() -> void:
	clean_up()

func _process(delta: float) -> void:
	if is_playing and first_click_done and not is_game_over:
		timer_accumulator += delta
		if timer_accumulator >= 1.0:
			timer_accumulator -= 1.0
			elapsed_seconds += 1
			_update_time_display()

func _connect_ui_signals() -> void:
	if back_button:
		back_button.pressed.connect(_on_exit_pressed)
	if select_back_button:
		select_back_button.pressed.connect(_on_exit_pressed)
	if tool_toggle_button:
		tool_toggle_button.pressed.connect(toggle_tool_mode)
	if restart_button:
		restart_button.pressed.connect(func(): start_game(current_difficulty))
		
	if easy_button:
		easy_button.pressed.connect(func(): start_game("easy"))
	if medium_button:
		medium_button.pressed.connect(func(): start_game("medium"))
	if hard_button:
		hard_button.pressed.connect(func(): start_game("hard"))

	if easy_card:
		easy_card.gui_input.connect(func(event: InputEvent): _on_card_gui_input(event, "easy"))
	if medium_card:
		medium_card.gui_input.connect(func(event: InputEvent): _on_card_gui_input(event, "medium"))
	if hard_card:
		hard_card.gui_input.connect(func(event: InputEvent): _on_card_gui_input(event, "hard"))
		
	if modal_retry_button:
		modal_retry_button.pressed.connect(func(): start_game(current_difficulty))
	if modal_change_level_button:
		modal_change_level_button.pressed.connect(show_level_selection)
	if modal_exit_button:
		modal_exit_button.pressed.connect(_on_exit_pressed)

func _on_card_gui_input(event: InputEvent, diff_id: String) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		start_game(diff_id)

func _get_audio_manager() -> Node:
	if not is_inside_tree() or get_tree() == null:
		return null
	if get_tree().root and get_tree().root.has_node("AudioManager"):
		return get_tree().root.get_node("AudioManager")
	return null

func _get_save_manager() -> Node:
	if not is_inside_tree() or get_tree() == null:
		return null
	if get_tree().root and get_tree().root.has_node("SaveManager"):
		return get_tree().root.get_node("SaveManager")
	return null

func show_level_selection() -> void:
	clean_up()
	if level_select_view:
		level_select_view.visible = true
	if game_view:
		game_view.visible = false
	if game_over_modal:
		game_over_modal.visible = false
		
	_refresh_level_records()

func _refresh_level_records() -> void:
	var sm := _get_save_manager()
	if sm == null:
		return
	if easy_record_lbl:
		easy_record_lbl.text = "Récord: %d pts" % sm.get_high_score("minesweeper_easy")
	if medium_record_lbl:
		medium_record_lbl.text = "Récord: %d pts" % sm.get_high_score("minesweeper_medium")
	if hard_record_lbl:
		hard_record_lbl.text = "Récord: %d pts" % sm.get_high_score("minesweeper_hard")

func select_difficulty(diff_id: String) -> void:
	if not DIFFICULTY_CONFIG.has(diff_id):
		diff_id = "easy"
	current_difficulty = diff_id

func start_game(diff_id: String = "") -> void:
	if diff_id != "":
		select_difficulty(diff_id)
		
	var cfg: Dictionary = DIFFICULTY_CONFIG[current_difficulty]
	var cols: int = cfg["cols"]
	var rows: int = cfg["rows"]
	var cell_size: Vector2 = cfg["cell_size"]
	
	is_playing = true
	is_game_over = false
	is_victory = false
	first_click_done = false
	flags_placed = 0
	elapsed_seconds = 0
	timer_accumulator = 0.0
	current_tool_mode = ToolMode.DIG
	
	if level_select_view:
		level_select_view.visible = false
	if game_view:
		game_view.visible = true
	if game_over_modal:
		game_over_modal.visible = false
	if new_record_badge:
		new_record_badge.visible = false
		
	_update_tool_mode_button()
	_update_mines_display()
	_update_time_display()
	
	_build_board(cols, rows, cell_size)

func _build_board(cols: int, rows: int, cell_size: Vector2) -> void:
	_clear_board()
	board_data.clear()
	cell_nodes.clear()
	
	if grid_container:
		grid_container.columns = cols
		
	for r in range(rows):
		var row_array: Array = []
		for c in range(cols):
			var cell_dict := {
				"coord": Vector2i(c, r),
				"is_mine": false,
				"adjacent_mines": 0,
				"is_revealed": false,
				"is_flagged": false
			}
			row_array.append(cell_dict)
			
			if grid_container:
				var cell_node = CELL_SCENE.instantiate()
				cell_node.setup(Vector2i(c, r), cell_size)
				cell_node.cell_pressed.connect(func(pos: Vector2i): on_cell_pressed(pos, false))
				cell_node.cell_long_pressed.connect(func(pos: Vector2i): on_cell_pressed(pos, true))
				grid_container.add_child(cell_node)
				cell_nodes[Vector2i(c, r)] = cell_node
				
		board_data.append(row_array)

func _clear_board() -> void:
	if grid_container:
		for child in grid_container.get_children():
			child.queue_free()
	cell_nodes.clear()

func toggle_tool_mode() -> void:
	if current_tool_mode == ToolMode.DIG:
		current_tool_mode = ToolMode.FLAG
	else:
		current_tool_mode = ToolMode.DIG
		
	var am := _get_audio_manager()
	if am:
		am.play_sfx("click")
		
	_update_tool_mode_button()

func _update_tool_mode_button() -> void:
	if tool_toggle_button == null:
		return
	if current_tool_mode == ToolMode.DIG:
		tool_toggle_button.text = "⛏️ EXCAVAR"
	else:
		tool_toggle_button.text = "🚩 BANDERA"

func on_cell_pressed(pos: Vector2i, is_long_press: bool) -> void:
	if not is_playing or is_game_over:
		return
		
	var cfg: Dictionary = DIFFICULTY_CONFIG[current_difficulty]
	var cols: int = cfg["cols"]
	var rows: int = cfg["rows"]
	
	if pos.y < 0 or pos.y >= rows or pos.x < 0 or pos.x >= cols:
		return
		
	var cell: Dictionary = board_data[pos.y][pos.x]
	
	# Si ya está revelada, ignorar toques
	if cell["is_revealed"]:
		return
		
	# Pulsación prolongada o estar en modo BANDERA alterna la bandera
	if is_long_press or current_tool_mode == ToolMode.FLAG:
		_toggle_flag(cell)
		return
		
	# Modo EXCAVAR: Si tiene bandera, no se descubre para evitar errores accidentales
	if cell["is_flagged"]:
		return
		
	# Primer toque seguro
	if not first_click_done:
		_populate_mines_safe(pos)
		first_click_done = true
		
	# Revelar celda
	_reveal_cell(pos)

func _toggle_flag(cell: Dictionary) -> void:
	var am := _get_audio_manager()
	cell["is_flagged"] = not cell["is_flagged"]
	if cell["is_flagged"]:
		flags_placed += 1
		if am:
			am.play_sfx("pop", 0.12)
	else:
		flags_placed = max(0, flags_placed - 1)
		if am:
			am.play_sfx("click")
			
	var node = cell_nodes.get(cell["coord"])
	if node:
		node.set_cell_state(node.State.FLAGGED if cell["is_flagged"] else node.State.HIDDEN)
		
	_update_mines_display()

func _populate_mines_safe(first_click_pos: Vector2i) -> void:
	var cfg: Dictionary = DIFFICULTY_CONFIG[current_difficulty]
	var cols: int = cfg["cols"]
	var rows: int = cfg["rows"]
	var total_mines: int = cfg["mines"]
	
	# Construir zona segura alrededor de first_click_pos (la celda y sus 8 vecinos)
	var safe_coords: Dictionary = {}
	for dr in range(-1, 2):
		for dc in range(-1, 2):
			var nr := first_click_pos.y + dr
			var nc := first_click_pos.x + dc
			if nr >= 0 and nr < rows and nc >= 0 and nc < cols:
				safe_coords[Vector2i(nc, nr)] = true
				
	# Lista de candidatos fuera de la zona segura
	var candidates: Array[Vector2i] = []
	for r in range(rows):
		for c in range(cols):
			var pt := Vector2i(c, r)
			if not safe_coords.has(pt):
				candidates.append(pt)
				
	# Mezclar aleatoriamente
	candidates.shuffle()
	
	# Si por alguna razón hubiera menos candidatos que minas, añadir de la zona segura excepto first_click
	if candidates.size() < total_mines:
		for pt in safe_coords.keys():
			if pt != first_click_pos and not candidates.has(pt):
				candidates.append(pt)
		candidates.shuffle()
		
	# Colocar las minas
	for i in range(min(total_mines, candidates.size())):
		var mine_pos: Vector2i = candidates[i]
		board_data[mine_pos.y][mine_pos.x]["is_mine"] = true
		var node = cell_nodes.get(mine_pos)
		if node:
			node.is_mine = true
			
	# Calcular adyacencias
	for r in range(rows):
		for c in range(cols):
			var count := 0
			for dr in range(-1, 2):
				for dc in range(-1, 2):
					if dr == 0 and dc == 0:
						continue
					var nr := r + dr
					var nc := c + dc
					if nr >= 0 and nr < rows and nc >= 0 and nc < cols:
						if board_data[nr][nc]["is_mine"]:
							count += 1
			board_data[r][c]["adjacent_mines"] = count
			var node = cell_nodes.get(Vector2i(c, r))
			if node:
				node.set_adjacent_mines(count)

func _reveal_cell(pos: Vector2i) -> void:
	var cell: Dictionary = board_data[pos.y][pos.x]
	if cell["is_revealed"] or cell["is_flagged"]:
		return
		
	cell["is_revealed"] = true
	var node = cell_nodes.get(pos)
	
	# Si es mina -> ¡BOOM! Derrota
	if cell["is_mine"]:
		_trigger_game_over(false, pos)
		return
		
	if node:
		node.set_cell_state(node.State.REVEALED)
		
	var am := _get_audio_manager()
	if am:
		am.play_sfx("pop", 0.08)
		
	# Cascada (Flood Fill) si es casilla con 0 minas adyacentes
	if cell["adjacent_mines"] == 0:
		_flood_fill(pos)
		
	_check_victory()

func _flood_fill(start_pos: Vector2i) -> void:
	var cfg: Dictionary = DIFFICULTY_CONFIG[current_difficulty]
	var cols: int = cfg["cols"]
	var rows: int = cfg["rows"]
	
	var queue: Array[Vector2i] = [start_pos]
	
	while not queue.is_empty():
		var curr: Vector2i = queue.pop_front()
		
		for dr in range(-1, 2):
			for dc in range(-1, 2):
				if dr == 0 and dc == 0:
					continue
				var nr := curr.y + dr
				var nc := curr.x + dc
				if nr >= 0 and nr < rows and nc >= 0 and nc < cols:
					var neighbor: Dictionary = board_data[nr][nc]
					if not neighbor["is_revealed"] and not neighbor["is_flagged"] and not neighbor["is_mine"]:
						neighbor["is_revealed"] = true
						var n_node = cell_nodes.get(Vector2i(nc, nr))
						if n_node:
							n_node.set_cell_state(n_node.State.REVEALED)
						if neighbor["adjacent_mines"] == 0:
							queue.append(Vector2i(nc, nr))

func _check_victory() -> void:
	var cfg: Dictionary = DIFFICULTY_CONFIG[current_difficulty]
	var cols: int = cfg["cols"]
	var rows: int = cfg["rows"]
	var total_mines: int = cfg["mines"]
	var safe_cells: int = (cols * rows) - total_mines
	
	var revealed_count := 0
	for r in range(rows):
		for c in range(cols):
			if board_data[r][c]["is_revealed"] and not board_data[r][c]["is_mine"]:
				revealed_count += 1
				
	if revealed_count >= safe_cells:
		_trigger_game_over(true, Vector2i(-1, -1))

func calculate_score(elapsed_secs: int, diff_id: String) -> int:
	var time_bonus: int = int(maxf(100.0, 10000.0 - (elapsed_secs * 20.0)))
	var diff_mult: float = 1.0
	if diff_id == "medium":
		diff_mult = 1.5
	elif diff_id == "hard":
		diff_mult = 2.0
	return int(time_bonus * diff_mult)

func _trigger_game_over(victory: bool, detonated_pos: Vector2i) -> void:
	is_playing = false
	is_game_over = true
	is_victory = victory
	
	var am := _get_audio_manager()
	var sm := _get_save_manager()
	var cfg: Dictionary = DIFFICULTY_CONFIG[current_difficulty]
	var diff_key: String = cfg["save_key"]
	var final_score := 0
	var is_new_record := false
	var prev_record := 0
	
	if sm:
		prev_record = sm.get_high_score(diff_key)
		
	if victory:
		final_score = calculate_score(elapsed_seconds, current_difficulty)
		if sm:
			is_new_record = sm.save_score(diff_key, final_score)
			sm.save_score("minesweeper", final_score)
		if am:
			if is_new_record:
				am.play_sfx("new_record")
			else:
				am.play_sfx("pop", 0.2)
	else:
		# Revelar todas las minas
		final_score = 0
		var rows: int = cfg["rows"]
		var cols: int = cfg["cols"]
		for r in range(rows):
			for c in range(cols):
				var pos := Vector2i(c, r)
				if board_data[r][c]["is_mine"]:
					var node = cell_nodes.get(pos)
					if node:
						if pos == detonated_pos:
							node.set_cell_state(node.State.EXPLODED)
						else:
							node.set_cell_state(node.State.MINE_REVEALED)
		if am:
			am.play_sfx("game_over")
			
	game_over.emit(final_score)
	_show_game_over_modal(victory, final_score, is_new_record, prev_record)

func _show_game_over_modal(victory: bool, score_val: int, new_rec: bool, _prev_rec: int) -> void:
	if game_over_modal == null:
		return
		
	game_over_modal.visible = true
	var sm := _get_save_manager()
	var diff_key: String = DIFFICULTY_CONFIG[current_difficulty]["save_key"]
	var best_score := 0
	if sm:
		best_score = sm.get_high_score(diff_key)
		
	if modal_title:
		if victory:
			modal_title.text = "¡VICTORIA!"
			modal_title.add_theme_color_override("font_color", Color(0.30, 0.90, 0.40))
		else:
			modal_title.text = "¡BOOM! FIN DE PARTIDA"
			modal_title.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
			
	if new_record_badge:
		new_record_badge.visible = new_rec
		
	if modal_time_label:
		modal_time_label.text = "Tiempo: %02d:%02d" % [elapsed_seconds / 60, elapsed_seconds % 60]
		
	if modal_score_label:
		modal_score_label.text = "Puntuación: %d pts" % score_val
		
	if modal_high_score_label:
		modal_high_score_label.text = "Récord (%s): %d pts" % [DIFFICULTY_CONFIG[current_difficulty]["name"], best_score]

func _update_mines_display() -> void:
	if mines_label == null:
		return
	var total_mines: int = DIFFICULTY_CONFIG[current_difficulty]["mines"]
	var remaining: int = total_mines - flags_placed
	mines_label.text = "🚩 %d" % remaining

func _update_time_display() -> void:
	if time_label == null:
		return
	time_label.text = "⏱️ %02d:%02d" % [elapsed_seconds / 60, elapsed_seconds % 60]

func _on_exit_pressed() -> void:
	var am := _get_audio_manager()
	if am:
		am.play_sfx("click")
	clean_up()
	request_exit.emit()

func clean_up() -> void:
	is_playing = false
	is_game_over = false
	first_click_done = false
	flags_placed = 0
	elapsed_seconds = 0
	timer_accumulator = 0.0
	_clear_board()
	board_data.clear()

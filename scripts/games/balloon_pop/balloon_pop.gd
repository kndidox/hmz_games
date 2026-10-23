extends Control

# BalloonPop: lógica del minijuego Explota Globos

signal request_exit()
signal game_over(score: int)

const BALLOON_SCENE = preload("res://scenes/games/balloon_pop/balloon.tscn")

var score: int = 0
var lives: int = 3
var is_playing: bool = false

@onready var score_label: Label = $HUD/MarginContainer/HBoxContainer/ScoreLabel
@onready var lives_label: Label = $HUD/MarginContainer/HBoxContainer/LivesLabel
@onready var back_button: Button = $HUD/MarginContainer/HBoxContainer/BackButton
@onready var balloon_container: Control = $BalloonContainer
@onready var spawn_timer: Timer = $SpawnTimer

@onready var game_over_modal: PanelContainer = $GameOverModal
@onready var final_score_label: Label = $GameOverModal/MarginContainer/VBoxContainer/FinalScoreLabel
@onready var high_score_label: Label = $GameOverModal/MarginContainer/VBoxContainer/HighScoreLabel
@onready var new_record_badge: Label = $GameOverModal/MarginContainer/VBoxContainer/NewRecordBadge
@onready var retry_button: Button = $GameOverModal/MarginContainer/VBoxContainer/ButtonBox/RetryButton
@onready var modal_exit_button: Button = $GameOverModal/MarginContainer/VBoxContainer/ButtonBox/ExitButton

func _ready() -> void:
	if back_button:
		back_button.pressed.connect(_on_exit_pressed)
	if retry_button:
		retry_button.pressed.connect(start_game)
	if modal_exit_button:
		modal_exit_button.pressed.connect(_on_exit_pressed)
	if spawn_timer:
		spawn_timer.timeout.connect(_on_spawn_timer_timeout)
		
	start_game()

func _exit_tree() -> void:
	clean_up()

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

func _gui_input(event: InputEvent) -> void:
	if not is_playing or balloon_container == null:
		return
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		# Comprobar si tocó algún globo activo (del más reciente al más antiguo)
		var children := balloon_container.get_children()
		for i in range(children.size() - 1, -1, -1):
			var balloon = children[i]
			if balloon.has_method("is_point_inside") and balloon.is_point_inside(event.position):
				balloon.pop()
				accept_event()
				break

func start_game() -> void:
	score = 0
	lives = 3
	is_playing = true
	
	if game_over_modal:
		game_over_modal.visible = false
	if new_record_badge:
		new_record_badge.visible = false
		
	_update_hud()
	_clear_balloons()
	
	if spawn_timer:
		spawn_timer.wait_time = 0.9
		spawn_timer.start()

func _clear_balloons() -> void:
	if balloon_container:
		for child in balloon_container.get_children():
			child.queue_free()

func _on_spawn_timer_timeout() -> void:
	if not is_playing or balloon_container == null:
		return
		
	var balloon = BALLOON_SCENE.instantiate()
	var spawn_x := randf_range(80.0, 640.0)
	
	# Variantes de globos según probabilidad
	var roll := randf()
	if roll < 0.65:
		# Normal (10 pts)
		balloon.points = 10
		balloon.speed = randf_range(190.0, 240.0)
		balloon.radius = 38.0
		var colors := [
			Color(0.92, 0.28, 0.28), # Rojo
			Color(0.24, 0.52, 0.90), # Azul
			Color(0.24, 0.78, 0.45), # Verde
			Color(0.72, 0.35, 0.85)  # Púrpura
		]
		balloon.balloon_color = colors[randi() % colors.size()]
	elif roll < 0.88:
		# Rápido (25 pts)
		balloon.points = 25
		balloon.speed = randf_range(280.0, 340.0)
		balloon.radius = 30.0
		balloon.balloon_color = Color(0.98, 0.55, 0.15) # Naranja vibrante
	else:
		# Dorado (50 pts) - rápido y valioso con área táctil cómoda
		balloon.points = 50
		balloon.speed = randf_range(350.0, 420.0)
		balloon.radius = 26.0
		balloon.balloon_color = Color(1.0, 0.85, 0.20) # Dorado brillante
	
	balloon.position = Vector2(spawn_x - balloon.size.x / 2.0, 1330.0)
	balloon.popped.connect(_on_balloon_popped)
	balloon.escaped.connect(_on_balloon_escaped)
	balloon_container.add_child(balloon)
	
	# Progresión de dificultad: intervalo de spawn disminuye suavemente
	var next_wait := clampf(0.95 - (score / 350.0) * 0.55, 0.35, 0.95)
	spawn_timer.wait_time = next_wait

func _on_balloon_popped(_balloon: Control, pts: int) -> void:
	if not is_playing:
		return
	add_score(pts)

func _on_balloon_escaped(_balloon: Control) -> void:
	if not is_playing:
		return
	lose_life()

func add_score(pts: int) -> void:
	score += pts
	_update_hud()
	var am := _get_audio_manager()
	if am:
		am.play_sfx("pop", 0.12)

func lose_life() -> void:
	lives -= 1
	_update_hud()
	if lives <= 0:
		_end_game()

func _update_hud() -> void:
	if score_label:
		score_label.text = "Puntos: %d" % score
	if lives_label:
		var hearts := ""
		for i in range(max(0, lives)):
			hearts += "❤️"
		lives_label.text = hearts if hearts != "" else "💀"

func _end_game() -> void:
	is_playing = false
	if spawn_timer:
		spawn_timer.stop()
		
	var sm := _get_save_manager()
	var prev_high := 0
	if sm:
		prev_high = sm.get_high_score("balloon_pop")
		
	game_over.emit(score)
	
	if game_over_modal:
		game_over_modal.visible = true
		if final_score_label:
			final_score_label.text = "Puntuación Final: %d" % score
		if high_score_label and sm:
			var current_high: int = sm.get_high_score("balloon_pop")
			high_score_label.text = "Mejor Récord: %d" % current_high
		if new_record_badge:
			new_record_badge.visible = (score > prev_high and score > 0)

func _on_exit_pressed() -> void:
	var am := _get_audio_manager()
	if am:
		am.play_sfx("click")
	clean_up()
	request_exit.emit()

func clean_up() -> void:
	is_playing = false
	if spawn_timer:
		spawn_timer.stop()
	_clear_balloons()

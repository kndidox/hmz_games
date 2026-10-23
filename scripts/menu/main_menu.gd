extends Control

# MainMenu: pantalla principal de selección de minijuegos

@onready var games_container: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/GamesContainer
@onready var mute_button: Button = $MarginContainer/VBoxContainer/Header/TopBar/MuteButton

var game_cards: Dictionary = {}

func _ready() -> void:
	if games_container:
		build_game_list()
	if mute_button:
		mute_button.pressed.connect(_on_mute_pressed)
		_update_mute_button_label()

func _get_game_manager() -> Node:
	if get_tree() and get_tree().root and get_tree().root.has_node("GameManager"):
		return get_tree().root.get_node("GameManager")
	return null

func _get_save_manager() -> Node:
	if get_tree() and get_tree().root and get_tree().root.has_node("SaveManager"):
		return get_tree().root.get_node("SaveManager")
	return null

func _get_audio_manager() -> Node:
	if get_tree() and get_tree().root and get_tree().root.has_node("AudioManager"):
		return get_tree().root.get_node("AudioManager")
	return null

func build_game_list() -> void:
	if games_container == null:
		return
		
	# Limpiar hijos previos
	for child in games_container.get_children():
		child.queue_free()
	game_cards.clear()

	var gm := _get_game_manager()
	if gm == null:
		return

	var games: Dictionary = gm.get_available_games()
	for game_id in games.keys():
		var info: Dictionary = games[game_id]
		var card := _create_game_card(game_id, info)
		games_container.add_child(card)
		game_cards[game_id] = card

	refresh_records()

func _create_game_card(game_id: String, info: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 140)
	
	# Estilo de la tarjeta
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.22, 0.30, 0.95)
	style.set_corner_radius_all(14)
	style.content_margin_left = 20
	style.content_margin_top = 16
	style.content_margin_right = 20
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	panel.add_child(hbox)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(info_vbox)

	var title_lbl := Label.new()
	title_lbl.text = info.get("title", game_id)
	title_lbl.add_theme_font_size_override("font_size", 24)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	info_vbox.add_child(title_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = info.get("description", "")
	desc_lbl.add_theme_font_size_override("font_size", 14)
	desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.80, 0.88))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_vbox.add_child(desc_lbl)

	var record_lbl := Label.new()
	record_lbl.name = "RecordLabel"
	record_lbl.text = "Récord: 0 pts"
	record_lbl.add_theme_font_size_override("font_size", 14)
	record_lbl.add_theme_color_override("font_color", Color(0.98, 0.80, 0.25))
	info_vbox.add_child(record_lbl)

	var play_btn := Button.new()
	play_btn.text = "JUGAR"
	play_btn.custom_minimum_size = Vector2(110, 56)
	play_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	play_btn.add_theme_font_size_override("font_size", 18)
	
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.20, 0.65, 0.35)
	btn_style.set_corner_radius_all(10)
	play_btn.add_theme_stylebox_override("normal", btn_style)
	
	play_btn.pressed.connect(func(): _on_play_pressed(game_id))
	hbox.add_child(play_btn)

	return panel

func refresh_records() -> void:
	var sm := _get_save_manager()
	if sm == null:
		return
		
	for game_id in game_cards.keys():
		var card: PanelContainer = game_cards[game_id]
		var record_lbl: Label = card.find_child("RecordLabel", true, false)
		if record_lbl:
			var high_score: int = sm.get_high_score(game_id)
			record_lbl.text = "Récord: %d pts" % high_score

func _on_play_pressed(game_id: String) -> void:
	var am := _get_audio_manager()
	if am:
		am.play_sfx("click")
		
	var gm := _get_game_manager()
	if gm:
		gm.start_game(game_id)

func _on_mute_pressed() -> void:
	var am := _get_audio_manager()
	var sm := _get_save_manager()
	if am:
		var current_muted: bool = am.get("muted") if "muted" in am else false
		var new_muted: bool = not current_muted
		am.set("muted", new_muted)
		if sm:
			sm.set_preference("muted", new_muted)
		_update_mute_button_label()

func _update_mute_button_label() -> void:
	if mute_button == null:
		return
	var am := _get_audio_manager()
	if am and am.muted:
		mute_button.text = "Audio: OFF"
	else:
		mute_button.text = "Audio: ON"

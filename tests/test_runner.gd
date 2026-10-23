extends SceneTree

# Test Runner para pruebas automatizadas en modo headless

var tests_passed: int = 0
var tests_failed: int = 0

func _init() -> void:
	print("--- INICIANDO SUITE DE PRUEBAS ---")
	run_tests()
	print("--- RESULTADOS: %d PASADAS, %d FALLIDAS ---" % [tests_passed, tests_failed])
	if tests_failed > 0:
		quit(1)
	else:
		quit(0)

func assert_true(condition: bool, message: String) -> void:
	if condition:
		tests_passed += 1
		print("  [PASS] %s" % message)
	else:
		tests_failed += 1
		printerr("  [FAIL] %s" % message)

func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual == expected:
		tests_passed += 1
		print("  [PASS] %s" % message)
	else:
		tests_failed += 1
		printerr("  [FAIL] %s: se esperaba '%s', pero se obtuvo '%s'" % [message, str(expected), str(actual)])

func run_tests() -> void:
	test_save_manager()
	test_audio_manager()
	test_game_manager()
	test_game_host()
	test_main_menu()
	test_main_app()
	test_balloon_pop()
	test_minesweeper_logic()
	test_minesweeper_scene_interactions()
	test_mine_cell()
	test_packed_scenes()

func test_save_manager() -> void:
	print("\nProbando SaveManager...")
	var save_manager_script = load("res://scripts/services/save_manager.gd")
	assert_true(save_manager_script != null, "SaveManager script debe existir y cargar")
	if save_manager_script == null:
		return
		
	var sm = save_manager_script.new()
	sm.save_file_path = "user://test_save_data.json"
	# Limpiar archivo de prueba anterior si existe
	if FileAccess.file_exists(sm.save_file_path):
		DirAccess.remove_absolute(sm.save_file_path)
	
	sm.load_data()
	assert_eq(sm.get_high_score("balloon_pop"), 0, "Récord inicial de balloon_pop debe ser 0")
	
	var is_new_record = sm.save_score("balloon_pop", 150)
	assert_true(is_new_record, "Puntuación de 150 debe ser nuevo récord")
	assert_eq(sm.get_high_score("balloon_pop"), 150, "Récord guardado debe ser 150")
	
	var is_not_new_record = sm.save_score("balloon_pop", 100)
	assert_true(!is_not_new_record, "Puntuación menor (100) no debe ser nuevo récord")
	assert_eq(sm.get_high_score("balloon_pop"), 150, "Récord debe mantenerse en 150")
	
	# Probar persistencia releyendo archivo
	var sm2 = save_manager_script.new()
	sm2.save_file_path = "user://test_save_data.json"
	sm2.load_data()
	assert_eq(sm2.get_high_score("balloon_pop"), 150, "SaveManager debe persistir récord en disco")
	
	# Probar preferencias
	sm.set_preference("sfx_volume", 0.8)
	assert_eq(sm.get_preference("sfx_volume", 1.0), 0.8, "Preferencia de volumen debe guardarse")
	
	# Limpieza
	if FileAccess.file_exists(sm.save_file_path):
		DirAccess.remove_absolute(sm.save_file_path)
	sm.free()
	sm2.free()

func test_audio_manager() -> void:
	print("\nProbando AudioManager...")
	var audio_manager_script = load("res://scripts/services/audio_manager.gd")
	assert_true(audio_manager_script != null, "AudioManager script debe existir y cargar")
	if audio_manager_script == null:
		return
	
	var am = audio_manager_script.new()
	am.init_sounds()
	assert_true(am.has_sound("pop"), "Debe tener sonido sintético 'pop'")
	assert_true(am.has_sound("click"), "Debe tener sonido sintético 'click'")
	assert_true(am.has_sound("game_over"), "Debe tener sonido sintético 'game_over'")
	assert_true(am.has_sound("new_record"), "Debe tener sonido sintético 'new_record'")
	
	var pop_stream = am.get_sound("pop")
	assert_true(pop_stream is AudioStreamWAV, "El sonido generado debe ser AudioStreamWAV")
	assert_true(pop_stream.data.size() > 0, "El buffer de audio del pop debe contener muestras")
	
	am.set_sfx_volume(0.5)
	assert_eq(am.sfx_volume, 0.5, "El volumen de SFX debe actualizarse a 0.5")
	am.free()

func test_game_manager() -> void:
	print("\nProbando GameManager...")
	var game_manager_script = load("res://scripts/services/game_manager.gd")
	assert_true(game_manager_script != null, "GameManager script debe existir y cargar")
	if game_manager_script == null:
		return
	
	var gm = game_manager_script.new()
	assert_true(gm.has_game("balloon_pop"), "El catálogo debe contener balloon_pop")
	var info = gm.get_game_info("balloon_pop")
	assert_eq(info["title"], "Explota Globos", "El título de balloon_pop debe coincidir")
	assert_true(info.has("scene_path"), "Debe tener ruta de escena")
	
	assert_true(gm.has_game("minesweeper"), "El catálogo debe contener minesweeper")
	var ms_info = gm.get_game_info("minesweeper")
	assert_eq(ms_info["title"], "Buscaminas", "El título de minesweeper debe coincidir")
	assert_true(ms_info.has("scene_path"), "Minesweeper debe tener ruta de escena")
	
	assert_eq(gm.current_state, gm.State.MENU, "Estado inicial debe ser MENU")
	
	var received_game_id := [""]
	gm.game_start_requested.connect(func(id: String): received_game_id[0] = id)
	
	gm.start_game("balloon_pop")
	assert_eq(gm.current_state, gm.State.IN_GAME, "El estado debe cambiar a IN_GAME")
	assert_eq(received_game_id[0], "balloon_pop", "Debe emitirse game_start_requested con 'balloon_pop'")
	
	var exit_called := [false]
	gm.game_exit_requested.connect(func(): exit_called[0] = true)
	gm.exit_to_menu()
	assert_eq(gm.current_state, gm.State.MENU, "El estado debe volver a MENU")
	assert_true(exit_called[0], "Debe emitirse game_exit_requested al volver al menú")
	
	gm.free()

func test_game_host() -> void:
	print("\nProbando GameHost...")
	var game_host_script = load("res://scripts/app/game_host.gd")
	assert_true(game_host_script != null, "GameHost script debe existir y cargar")
	if game_host_script == null:
		return
		
	var host = game_host_script.new()
	assert_true(host.has_method("start_game"), "GameHost debe tener método start_game")
	assert_true(host.has_method("unload_current_game"), "GameHost debe tener método unload_current_game")
	assert_true(host.current_game_instance == null, "current_game_instance debe iniciar null")
	
	# Probar con un nodo dummy de prueba
	var dummy_game = Node2D.new()
	dummy_game.name = "DummyGame"
	host.add_child(dummy_game)
	host.current_game_instance = dummy_game
	assert_eq(host.current_game_instance, dummy_game, "GameHost debe registrar la instancia activa")
	
	host.unload_current_game()
	assert_true(host.current_game_instance == null, "current_game_instance debe ser null tras descarga")
	
	host.free()

func test_main_menu() -> void:
	print("\nProbando MainMenu...")
	var menu_script = load("res://scripts/menu/main_menu.gd")
	assert_true(menu_script != null, "MainMenu script debe existir y cargar")
	if menu_script == null:
		return
		
	var menu = menu_script.new()
	assert_true(menu.has_method("refresh_records"), "MainMenu debe tener método refresh_records")
	assert_true(menu.has_method("build_game_list"), "MainMenu debe tener método build_game_list")
	menu.free()

func test_main_app() -> void:
	print("\nProbando Main App...")
	var main_script = load("res://scripts/app/main.gd")
	assert_true(main_script != null, "Main script debe existir y cargar")
	if main_script == null:
		return
		
	var main_instance = main_script.new()
	assert_true(main_instance.has_method("_on_game_state_changed"), "Main debe tener método _on_game_state_changed")
	main_instance.free()

func test_balloon_pop() -> void:
	print("\nProbando Minijuego Balloon Pop...")
	var balloon_script = load("res://scripts/games/balloon_pop/balloon.gd")
	assert_true(balloon_script != null, "Balloon script debe existir y cargar")
	if balloon_script == null:
		return
		
	var balloon = balloon_script.new()
	assert_true(balloon.has_signal("popped"), "Balloon debe tener señal 'popped'")
	assert_true(balloon.has_signal("escaped"), "Balloon debe tener señal 'escaped'")
	assert_true(balloon.has_method("pop"), "Balloon debe tener método 'pop'")
	assert_true(balloon.has_method("_gui_input"), "Balloon debe soportar _gui_input para entrada táctil/ratón")
	assert_true(balloon.has_method("is_point_inside"), "Balloon debe tener método 'is_point_inside'")
	
	# Probar clic mediante _gui_input
	var click_popped := [false]
	balloon.popped.connect(func(_b, _p): click_popped[0] = true)
	balloon.radius = 38.0
	
	var click_event = InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	click_event.position = balloon.size / 2.0 # centro exacto del globo
	
	balloon._gui_input(click_event)
	assert_true(click_popped[0], "El globo debe explotar al recibir un clic dentro de su área")
	
	# Probar método directo pop()
	var direct_balloon = balloon_script.new()
	var popped_data := [0]
	direct_balloon.popped.connect(func(_b, pts): popped_data[0] = pts)
	direct_balloon.points = 25
	direct_balloon.pop()
	assert_eq(popped_data[0], 25, "Al explotar debe emitir puntos correctos (25)")
	
	balloon.free()
	direct_balloon.free()
	
	var game_script = load("res://scripts/games/balloon_pop/balloon_pop.gd")
	assert_true(game_script != null, "BalloonPop script debe existir y cargar")
	if game_script == null:
		return
		
	var game = game_script.new()
	assert_true(game.has_signal("request_exit"), "BalloonPop debe tener señal 'request_exit'")
	assert_true(game.has_signal("game_over"), "BalloonPop debe tener señal 'game_over'")
	assert_true(game.has_method("start_game"), "BalloonPop debe tener método 'start_game'")
	assert_true(game.has_method("add_score"), "BalloonPop debe tener método 'add_score'")
	assert_true(game.has_method("lose_life"), "BalloonPop debe tener método 'lose_life'")
	
	game.start_game()
	assert_eq(game.score, 0, "Puntuación inicial debe ser 0")
	assert_eq(game.lives, 3, "Vidas iniciales deben ser 3")
	assert_true(game.is_playing, "El juego debe estar en estado is_playing = true")
	
	game.add_score(50)
	assert_eq(game.score, 50, "Puntuación tras add_score debe ser 50")
	
	var game_over_score := [-1]
	game.game_over.connect(func(final_score: int): game_over_score[0] = final_score)
	
	game.lose_life()
	assert_eq(game.lives, 2, "Vidas deben decrementar a 2")
	game.lose_life()
	assert_eq(game.lives, 1, "Vidas deben decrementar a 1")
	game.lose_life()
	assert_eq(game.lives, 0, "Vidas deben ser 0")
	assert_true(!game.is_playing, "El juego debe terminar tras perder todas las vidas")
	assert_eq(game_over_score[0], 50, "Debe emitirse señal game_over con puntuación final 50")
	
	game.free()

func test_minesweeper_logic() -> void:
	print("\nProbando Lógica de Buscaminas...")
	var minesweeper_script = load("res://scripts/games/minesweeper/minesweeper.gd")
	assert_true(minesweeper_script != null, "Minesweeper script debe existir y cargar")
	if minesweeper_script == null:
		return
		
	var game = minesweeper_script.new()
	assert_true(game.has_signal("request_exit"), "Minesweeper debe tener señal 'request_exit'")
	assert_true(game.has_signal("game_over"), "Minesweeper debe tener señal 'game_over'")
	assert_true(game.has_method("select_difficulty"), "Minesweeper debe tener método 'select_difficulty'")
	assert_true(game.has_method("start_game"), "Minesweeper debe tener método 'start_game'")
	assert_true(game.has_method("clean_up"), "Minesweeper debe tener método 'clean_up'")
	assert_true(game.has_method("toggle_tool_mode"), "Minesweeper debe tener método 'toggle_tool_mode'")
	assert_true(game.has_method("on_cell_pressed"), "Minesweeper debe tener método 'on_cell_pressed'")
	assert_true(game.has_method("calculate_score"), "Minesweeper debe tener método 'calculate_score'")
	
	# Verificar configuración de dificultades
	assert_true("DIFFICULTY_CONFIG" in minesweeper_script, "Minesweeper debe definir DIFFICULTY_CONFIG")
	var config: Dictionary = minesweeper_script.DIFFICULTY_CONFIG
	assert_true(config.has("easy") and config.has("medium") and config.has("hard"), "Debe tener 3 dificultades: easy, medium, hard")
	
	# Easy: 7x9, 8 minas
	assert_eq(config["easy"]["cols"], 7, "Easy debe tener 7 columnas")
	assert_eq(config["easy"]["rows"], 9, "Easy debe tener 9 filas")
	assert_eq(config["easy"]["mines"], 8, "Easy debe tener 8 minas")
	assert_eq(config["easy"]["save_key"], "minesweeper_easy", "Easy save_key debe ser minesweeper_easy")
	
	# Medium: 9x12, 16 minas
	assert_eq(config["medium"]["cols"], 9, "Medium debe tener 9 columnas")
	assert_eq(config["medium"]["rows"], 12, "Medium debe tener 12 filas")
	assert_eq(config["medium"]["mines"], 16, "Medium debe tener 16 minas")
	assert_eq(config["medium"]["save_key"], "minesweeper_medium", "Medium save_key debe ser minesweeper_medium")
	
	# Hard: 11x15, 30 minas
	assert_eq(config["hard"]["cols"], 11, "Hard debe tener 11 columnas")
	assert_eq(config["hard"]["rows"], 15, "Hard debe tener 15 filas")
	assert_eq(config["hard"]["mines"], 30, "Hard debe tener 30 minas")
	assert_eq(config["hard"]["save_key"], "minesweeper_hard", "Hard save_key debe ser minesweeper_hard")
	
	# Probar cálculo de puntuación
	var score_easy: int = game.calculate_score(10, "easy")
	# time_bonus = max(100, 10000 - 10 * 20) = 9800 * 1.0 = 9800
	assert_eq(score_easy, 9800, "Puntuación en fácil a 10s debe ser 9800")
	var score_med: int = game.calculate_score(10, "medium")
	# 9800 * 1.5 = 14700
	assert_eq(score_med, 14700, "Puntuación en medio a 10s debe ser 14700")
	var score_hard: int = game.calculate_score(10, "hard")
	# 9800 * 2.0 = 19600
	assert_eq(score_hard, 19600, "Puntuación en difícil a 10s debe ser 19600")
	
	# Iniciar partida en fácil
	game.start_game("easy")
	assert_true(game.is_playing, "El juego debe estar activo tras start_game")
	assert_true(!game.first_click_done, "El primer clic aún no debe haberse registrado")
	assert_eq(game.flags_placed, 0, "Banderas iniciales deben ser 0")
	
	# Primer toque seguro en (3, 4)
	var first_click_pos := Vector2i(3, 4)
	game.on_cell_pressed(first_click_pos, false)
	assert_true(game.first_click_done, "first_click_done debe ser true tras el primer toque")
	
	# Contar minas totales en la cuadrícula interna
	var total_mines := 0
	for r in range(9):
		for c in range(7):
			if game.board_data[r][c]["is_mine"]:
				total_mines += 1
	assert_eq(total_mines, 8, "Debe haberse colocado exactamente 8 minas")
	
	# Asegurar que ni (3, 4) ni ninguno de sus 8 vecinos tenga mina
	var safe_zone_has_mine := false
	for dr in range(-1, 2):
		for dc in range(-1, 2):
			var nr := first_click_pos.y + dr
			var nc := first_click_pos.x + dc
			if nr >= 0 and nr < 9 and nc >= 0 and nc < 7:
				if game.board_data[nr][nc]["is_mine"]:
					safe_zone_has_mine = true
	assert_true(!safe_zone_has_mine, "El primer toque y sus 8 casillas adyacentes no deben contener minas")
	assert_true(game.board_data[first_click_pos.y][first_click_pos.x]["is_revealed"], "La celda inicial debe estar revelada")
	
	# Probar modo toggle de herramientas
	assert_eq(game.current_tool_mode, game.ToolMode.DIG, "Modo inicial debe ser DIG (Excavar)")
	game.toggle_tool_mode()
	assert_eq(game.current_tool_mode, game.ToolMode.FLAG, "Modo tras toggle debe ser FLAG (Bandera)")
	game.toggle_tool_mode()
	assert_eq(game.current_tool_mode, game.ToolMode.DIG, "Modo tras segundo toggle debe volver a DIG")
	
	# Probar colocación de bandera mediante pulsación prolongada en celda no revelada
	# Buscar una celda no revelada
	var hidden_pos := Vector2i(-1, -1)
	for r in range(9):
		for c in range(7):
			if not game.board_data[r][c]["is_revealed"]:
				hidden_pos = Vector2i(c, r)
				break
		if hidden_pos.x != -1:
			break
			
	assert_true(hidden_pos.x != -1, "Debe haber celdas no reveladas")
	game.on_cell_pressed(hidden_pos, true) # Long press = toggle flag
	assert_true(game.board_data[hidden_pos.y][hidden_pos.x]["is_flagged"], "Pulsación prolongada debe colocar bandera")
	assert_eq(game.flags_placed, 1, "flags_placed debe ser 1")
	
	# Toque en modo DIG sobre celda con bandera NO debe revelarla
	game.on_cell_pressed(hidden_pos, false)
	assert_true(game.board_data[hidden_pos.y][hidden_pos.x]["is_flagged"], "Celda con bandera no debe revelarse en modo DIG")
	assert_true(!game.board_data[hidden_pos.y][hidden_pos.x]["is_revealed"], "Celda con bandera debe permanecer oculta")
	
	# Quitar bandera con pulsación prolongada
	game.on_cell_pressed(hidden_pos, true)
	assert_true(!game.board_data[hidden_pos.y][hidden_pos.x]["is_flagged"], "Pulsación prolongada debe quitar bandera")
	assert_eq(game.flags_placed, 0, "flags_placed debe ser 0 tras quitar bandera")
	
	# Probar detonación y derrota
	# Buscar una mina
	var mine_pos := Vector2i(-1, -1)
	for r in range(9):
		for c in range(7):
			if game.board_data[r][c]["is_mine"]:
				mine_pos = Vector2i(c, r)
				break
		if mine_pos.x != -1:
			break
			
	var game_over_score := [-1]
	game.game_over.connect(func(final_score: int): game_over_score[0] = final_score)
	
	game.on_cell_pressed(mine_pos, false)
	assert_true(game.is_game_over, "Tocar una mina debe provocar fin de partida")
	assert_true(!game.is_victory, "Tocar una mina no debe ser victoria")
	assert_true(game_over_score[0] == 0, "En derrota, score emitido debe ser 0")
	
	# Probar que flood fill no cruza ni descubre casillas con bandera
	var ff_game = minesweeper_script.new()
	ff_game.start_game("easy")
	ff_game.first_click_done = true
	ff_game.board_data[1][1]["is_flagged"] = true
	ff_game.flags_placed = 1
	ff_game.on_cell_pressed(Vector2i(0, 0), false)
	assert_true(ff_game.board_data[0][0]["is_revealed"], "Celda (0,0) debe estar revelada")
	assert_true(!ff_game.board_data[1][1]["is_revealed"], "Celda con bandera (1,1) NO debe ser revelada por flood fill")
	assert_true(ff_game.board_data[1][1]["is_flagged"], "Celda (1,1) debe mantener su bandera")
	ff_game.clean_up()
	ff_game.free()

	# Probar victoria al revelar todas las casillas seguras
	var vic_game = minesweeper_script.new()
	vic_game.start_game("easy")
	vic_game.on_cell_pressed(Vector2i(3, 4), false)
	var vic_score := [-1]
	vic_game.game_over.connect(func(s: int): vic_score[0] = s)
	for r in range(9):
		for c in range(7):
			if not vic_game.board_data[r][c]["is_mine"] and not vic_game.board_data[r][c]["is_revealed"]:
				vic_game.on_cell_pressed(Vector2i(c, r), false)
	assert_true(vic_game.is_game_over, "Al revelar todas las casillas sin mina debe terminar la partida")
	assert_true(vic_game.is_victory, "Debe ser victoria")
	assert_true(vic_score[0] > 0, "El score de victoria debe ser mayor a 0")
	vic_game.clean_up()
	vic_game.free()

	# Probar limpieza
	game.clean_up()
	assert_true(!game.is_playing, "Tras clean_up(), is_playing debe ser false")
	
	game.free()

func test_minesweeper_scene_interactions() -> void:
	print("\nProbando Interacciones de Escena Minesweeper...")
	var packed = load("res://scenes/games/minesweeper/minesweeper.tscn")
	assert_true(packed != null, "La escena minesweeper.tscn debe cargar")
	if packed == null:
		return
	var inst = packed.instantiate()
	assert_true(inst != null, "La escena minesweeper.tscn debe instanciar")
	root.add_child(inst)
	
	assert_true(inst.easy_button != null, "inst.easy_button no debe ser null")
	assert_true(inst.medium_button != null, "inst.medium_button no debe ser null")
	assert_true(inst.hard_button != null, "inst.hard_button no debe ser null")
	assert_true(inst.easy_card != null, "inst.easy_card no debe ser null")
	assert_true(inst.medium_card != null, "inst.medium_card no debe ser null")
	assert_true(inst.hard_card != null, "inst.hard_card no debe ser null")
	assert_true(inst.easy_record_lbl != null, "inst.easy_record_lbl no debe ser null")
	
	# Probar pulsación de botón fácil
	inst.easy_button.pressed.emit()
	assert_true(inst.is_playing, "Al presionar botón fácil debe iniciar partida")
	assert_eq(inst.current_difficulty, "easy", "Dificultad debe ser 'easy'")
	
	# Probar volver a nivel y seleccionar con tarjeta
	inst.show_level_selection()
	assert_true(!inst.is_playing, "is_playing debe ser false tras show_level_selection")
	
	# Simular clic en la tarjeta mediana (gui_input)
	var touch_event = InputEventScreenTouch.new()
	touch_event.pressed = true
	inst.medium_card.gui_input.emit(touch_event)
	assert_true(inst.is_playing, "Al tocar la tarjeta mediana debe iniciar la partida")
	assert_eq(inst.current_difficulty, "medium", "Dificultad debe ser 'medium'")
	
	# Probar botón difícil
	inst.show_level_selection()
	inst.hard_button.pressed.emit()
	assert_true(inst.is_playing, "Al presionar botón difícil debe iniciar partida")
	assert_eq(inst.current_difficulty, "hard", "Dificultad debe ser 'hard'")
	
	inst.clean_up()
	root.remove_child(inst)
	inst.free()

func test_mine_cell() -> void:
	print("\nProbando Componente MineCell...")
	var cell_script = load("res://scripts/games/minesweeper/mine_cell.gd")
	assert_true(cell_script != null, "MineCell script debe existir y cargar")
	if cell_script == null:
		return
		
	var cell = cell_script.new()
	assert_true(cell.has_signal("cell_pressed"), "MineCell debe tener señal 'cell_pressed'")
	assert_true(cell.has_signal("cell_long_pressed"), "MineCell debe tener señal 'cell_long_pressed'")
	assert_true(cell.has_method("setup"), "MineCell debe tener método 'setup'")
	assert_true(cell.has_method("set_adjacent_mines"), "MineCell debe tener método 'set_adjacent_mines'")
	assert_true(cell.has_method("set_cell_state"), "MineCell debe tener método 'set_cell_state'")
	
	cell.setup(Vector2i(2, 3), Vector2(60, 60))
	assert_eq(cell.coord, Vector2i(2, 3), "La coordenada de la celda debe ser Vector2i(2, 3)")
	assert_eq(cell.custom_minimum_size, Vector2(60, 60), "El tamaño mínimo debe ser Vector2(60, 60)")
	
	cell.set_adjacent_mines(3)
	assert_eq(cell.adjacent_mines, 3, "Minas adyacentes debe ser 3")
	
	cell.set_cell_state(cell.State.FLAGGED)
	assert_eq(cell.current_state, cell.State.FLAGGED, "Estado debe ser FLAGGED")
	
	cell.set_cell_state(cell.State.REVEALED)
	assert_eq(cell.current_state, cell.State.REVEALED, "Estado debe ser REVEALED")
	
	cell.free()

func test_packed_scenes() -> void:
	print("\nProbando Instanciación de Escenas .tscn...")
	var scenes_to_test := [
		"res://scenes/app/game_host.tscn",
		"res://scenes/menu/main_menu.tscn",
		"res://scenes/games/balloon_pop/balloon.tscn",
		"res://scenes/games/balloon_pop/balloon_pop.tscn",
		"res://scenes/games/minesweeper/mine_cell.tscn",
		"res://scenes/games/minesweeper/minesweeper.tscn",
		"res://scenes/app/main.tscn"
	]
	
	for path in scenes_to_test:
		assert_true(ResourceLoader.exists(path), "La escena debe existir en disco: %s" % path)
		var packed: PackedScene = load(path)
		assert_true(packed != null, "La escena debe cargar correctamente: %s" % path)
		if packed:
			var inst = packed.instantiate()
			assert_true(inst != null, "La escena debe poder instanciarse: %s" % path)
			if inst:
				inst.free()

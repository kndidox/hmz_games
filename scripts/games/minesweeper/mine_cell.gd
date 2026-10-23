extends Control

# MineCell: Celda individual para el tablero de Buscaminas
# Soporta estados visuales, pulsación simple, pulsación prolongada (0.35s) y clic derecho.

signal cell_pressed(coord: Vector2i)
signal cell_long_pressed(coord: Vector2i)

enum State {
	HIDDEN,
	REVEALED,
	FLAGGED,
	EXPLODED,
	MINE_REVEALED
}

const NUMBER_COLORS: Dictionary = {
	1: Color(0.30, 0.60, 1.00), # Azul claro
	2: Color(0.30, 0.85, 0.45), # Verde
	3: Color(0.95, 0.32, 0.32), # Rojo
	4: Color(0.60, 0.40, 0.95), # Púrpura / Azul oscuro
	5: Color(0.90, 0.50, 0.20), # Naranja / Marrón
	6: Color(0.20, 0.80, 0.80), # Cian
	7: Color(0.90, 0.90, 0.90), # Gris claro
	8: Color(0.60, 0.60, 0.60)  # Gris medio
}

var coord: Vector2i = Vector2i.ZERO
var current_state: State = State.HIDDEN
var adjacent_mines: int = 0
var is_mine: bool = false

var _label: Label = null
var _touch_down: bool = false
var _touch_time: float = 0.0
var _long_press_triggered: bool = false
var _touch_start_pos: Vector2 = Vector2.ZERO

const LONG_PRESS_DURATION: float = 0.35
const DRAG_THRESHOLD: float = 18.0

func _init() -> void:
	mouse_filter = MOUSE_FILTER_STOP

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	_ensure_label()
	_update_visuals()

func _ensure_label() -> void:
	if _label == null:
		if has_node("Label"):
			_label = $Label as Label
		else:
			_label = Label.new()
			_label.name = "Label"
			_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_label.set_anchors_preset(PRESET_FULL_RECT)
			_label.mouse_filter = MOUSE_FILTER_IGNORE
			add_child(_label)

func setup(p_coord: Vector2i, p_size: Vector2) -> void:
	coord = p_coord
	custom_minimum_size = p_size
	size = p_size
	_ensure_label()
	_update_font_size()
	_update_visuals()

func set_adjacent_mines(count: int) -> void:
	adjacent_mines = count
	_update_visuals()

func set_cell_state(p_state: State) -> void:
	current_state = p_state
	_update_visuals()

func _update_font_size() -> void:
	if _label == null:
		return
	var font_sz := int(clampf(size.y * 0.45, 14.0, 36.0))
	_label.add_theme_font_size_override("font_size", font_sz)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_font_size()
		queue_redraw()

func _process(delta: float) -> void:
	if _touch_down and not _long_press_triggered:
		_touch_time += delta
		if _touch_time >= LONG_PRESS_DURATION:
			_long_press_triggered = true
			cell_long_pressed.emit(coord)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_touch_down = true
				_touch_time = 0.0
				_long_press_triggered = false
				_touch_start_pos = mb.position
			else:
				if _touch_down:
					_touch_down = false
					if not _long_press_triggered and mb.position.distance_to(_touch_start_pos) <= DRAG_THRESHOLD:
						cell_pressed.emit(coord)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			# Atajo de escritorio: clic derecho alterna bandera
			cell_long_pressed.emit(coord)
			accept_event()
			
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_touch_down = true
			_touch_time = 0.0
			_long_press_triggered = false
			_touch_start_pos = st.position
		else:
			if _touch_down:
				_touch_down = false
				if not _long_press_triggered and st.position.distance_to(_touch_start_pos) <= DRAG_THRESHOLD:
					cell_pressed.emit(coord)
		accept_event()
		
	elif event is InputEventMouseMotion or event is InputEventScreenDrag:
		if _touch_down:
			var curr_pos: Vector2 = event.position
			if curr_pos.distance_to(_touch_start_pos) > DRAG_THRESHOLD:
				_touch_down = false # Cancelar si el usuario está arrastrando/scrolleando

func _update_visuals() -> void:
	_ensure_label()
	if _label == null:
		queue_redraw()
		return
		
	match current_state:
		State.HIDDEN:
			_label.text = ""
		State.FLAGGED:
			_label.text = "🚩"
			_label.remove_theme_color_override("font_color")
		State.REVEALED:
			if is_mine:
				_label.text = "💣"
			elif adjacent_mines > 0:
				_label.text = str(adjacent_mines)
				var text_col: Color = NUMBER_COLORS.get(adjacent_mines, Color.WHITE)
				_label.add_theme_color_override("font_color", text_col)
			else:
				_label.text = ""
		State.EXPLODED:
			_label.text = "💥"
		State.MINE_REVEALED:
			_label.text = "💣"
			
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var margin := 2.0
	var inner_rect := rect.grow(-margin)
	var corner_radius := 6.0
	
	match current_state:
		State.HIDDEN, State.FLAGGED:
			# Botón elevado con bordes biselados suaves
			draw_style_box_tile(inner_rect, Color(0.24, 0.28, 0.38), Color(0.34, 0.39, 0.52), Color(0.15, 0.18, 0.25), corner_radius)
		State.REVEALED:
			if is_mine:
				draw_style_box_tile(inner_rect, Color(0.65, 0.18, 0.18), Color(0.85, 0.25, 0.25), Color(0.45, 0.12, 0.12), corner_radius)
			else:
				# Casilla abierta limpia con bajo contraste
				var bg_color := Color(0.12, 0.15, 0.21)
				var border_color := Color(0.18, 0.22, 0.30)
				draw_flat_tile(inner_rect, bg_color, border_color, corner_radius)
		State.EXPLODED:
			# Casilla detonada rojo brillante
			draw_style_box_tile(inner_rect, Color(0.85, 0.20, 0.20), Color(1.0, 0.40, 0.40), Color(0.50, 0.10, 0.10), corner_radius)
		State.MINE_REVEALED:
			# Mina revelada al perder
			draw_flat_tile(inner_rect, Color(0.20, 0.14, 0.16), Color(0.40, 0.20, 0.22), corner_radius)

func draw_flat_tile(r: Rect2, bg: Color, border: Color, radius: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(int(radius))
	sb.draw(get_canvas_item(), r)

func draw_style_box_tile(r: Rect2, bg: Color, light_border: Color, dark_border: Color, radius: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = light_border
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.set_corner_radius_all(int(radius))
	sb.shadow_color = dark_border
	sb.shadow_size = 2
	sb.shadow_offset = Vector2(1, 1)
	sb.draw(get_canvas_item(), r)

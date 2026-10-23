extends Control

# Balloon: entidad interactiva de globo con dibujo procedural y detección táctil/ratón

signal popped(balloon: Control, points: int)
signal escaped(balloon: Control)

@export var speed: float = 220.0
@export var points: int = 10
@export var sway_frequency: float = 2.5
@export var sway_amplitude: float = 30.0
@export var balloon_color: Color = Color(0.92, 0.28, 0.28)
@export var radius: float = 38.0:
	set(val):
		radius = val
		_update_dimensions()
		queue_redraw()

var is_popped: bool = false
var time_passed: float = 0.0

func _init() -> void:
	_update_dimensions()

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	time_passed = randf_range(0.0, TAU)
	_update_dimensions()
	queue_redraw()

func _update_dimensions() -> void:
	var min_w := maxf(radius * 2.6, 96.0)
	var min_h := maxf(radius * 3.4, 110.0)
	custom_minimum_size = Vector2(min_w, min_h)
	size = custom_minimum_size
	# Centrar el pivote para animaciones de escala suaves
	pivot_offset = size / 2.0

func _process(delta: float) -> void:
	if is_popped:
		return
	
	time_passed += delta
	position.y -= speed * delta
	position.x += cos(time_passed * sway_frequency) * sway_amplitude * delta
	
	if position.y < -120.0:
		is_popped = true
		escaped.emit(self)
		queue_free()

func get_touch_radius() -> float:
	# Área táctil generosa (mínimo 48px de radio) para pantallas táctiles móviles
	return maxf(radius * 1.55, 48.0)

func _gui_input(event: InputEvent) -> void:
	if is_popped:
		return
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		var center := size / 2.0
		if event.position.distance_to(center) <= get_touch_radius():
			pop()
			accept_event()

func is_point_inside(global_pos: Vector2) -> bool:
	if is_popped:
		return false
	var center := global_position + (size / 2.0)
	return global_pos.distance_to(center) <= get_touch_radius()

func pop() -> void:
	if is_popped:
		return
	is_popped = true
	mouse_filter = MOUSE_FILTER_IGNORE
	
	popped.emit(self, points)
	
	# Efecto visual de explosión procedural
	var tween := create_tween()
	if tween:
		tween.set_parallel(true)
		tween.tween_property(self, "scale", scale * 1.4, 0.10)
		tween.tween_property(self, "modulate:a", 0.0, 0.10)
		tween.finished.connect(queue_free)
	else:
		queue_free()

func _draw() -> void:
	if is_popped:
		return
		
	var center := size / 2.0
	# Cuerpo del globo (elipse vertical)
	var ellipse_radii := Vector2(radius, radius * 1.25)
	var points_count := 32
	var poly := PackedVector2Array()
	for i in range(points_count):
		var angle := (TAU / points_count) * i
		poly.append(center + Vector2(cos(angle) * ellipse_radii.x, sin(angle) * ellipse_radii.y))
	draw_colored_polygon(poly, balloon_color)
	
	# Brillo / Reflejo superior izquierdo
	var highlight_pos := center + Vector2(-radius * 0.35, -ellipse_radii.y * 0.35)
	draw_circle(highlight_pos, radius * 0.22, Color(1.0, 1.0, 1.0, 0.45))
	
	# Nudo inferior
	var knot_top := center.y + ellipse_radii.y
	var knot_poly := PackedVector2Array([
		Vector2(center.x - 6, knot_top),
		Vector2(center.x + 6, knot_top),
		Vector2(center.x, knot_top + 8)
	])
	draw_colored_polygon(knot_poly, balloon_color.darkened(0.2))
	
	# Cuerda colgante
	var string_start := Vector2(center.x, knot_top + 8)
	var string_mid := Vector2(center.x + 8, knot_top + 28)
	var string_end := Vector2(center.x - 4, knot_top + 50)
	draw_line(string_start, string_mid, Color(0.9, 0.9, 0.9, 0.7), 2.0)
	draw_line(string_mid, string_end, Color(0.9, 0.9, 0.9, 0.7), 2.0)

extends Camera2D

@export var drag_button: MouseButton = MOUSE_BUTTON_LEFT
@export var drag_sensitivity: float = 1.0

@export var zoom_step: float = 0.1
@export var min_zoom: float = 0.5
@export var max_zoom: float = 2.5

var _dragging := false
var _last_mouse_pos := Vector2.ZERO

func _unhandled_input(event: InputEvent) -> void:
	# --- Start/stop dragging ---
	if event is InputEventMouseButton and event.button_index == drag_button:
		_dragging = event.pressed
		_last_mouse_pos = get_viewport().get_mouse_position()
		get_viewport().set_input_as_handled()
		return

	# --- Zoom (mouse wheel) ---
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_set_zoom(zoom.x - zoom_step)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_set_zoom(zoom.x + zoom_step)
			get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not _dragging:
		return

	var mouse_pos := get_viewport().get_mouse_position()
	var delta := mouse_pos - _last_mouse_pos
	_last_mouse_pos = mouse_pos

	# Dragging the view: move camera opposite to mouse movement.
	global_position -= delta * drag_sensitivity / zoom.x

func _set_zoom(z: float) -> void:
	z = clamp(z, min_zoom, max_zoom)
	zoom = Vector2(z, z)

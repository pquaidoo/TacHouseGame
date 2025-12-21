extends Camera2D

@export var drag_button: MouseButton = MOUSE_BUTTON_LEFT
@export var drag_sensitivity: float = 1.0

@export var zoom_step: float = 0.1
@export var min_zoom: float = 0.5
@export var max_zoom: float = 2.5

# How far the mouse must move (in pixels) before we consider it a drag.
@export var drag_threshold_px: float = 8.0

var _pressing := false         # LMB is held down
var _dragging := false         # moved past threshold
var _press_pos := Vector2.ZERO
var _last_mouse_pos := Vector2.ZERO

func _unhandled_input(event: InputEvent) -> void:
	# --- Mouse down/up ---
	if event is InputEventMouseButton and event.button_index == drag_button:
		if event.pressed:
			_pressing = true
			_dragging = false
			_press_pos = get_viewport().get_mouse_position()
			_last_mouse_pos = _press_pos
		else:
			_pressing = false
			_dragging = false
		return

	# --- Zoom (wheel) ---
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_set_zoom(zoom.x - zoom_step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_set_zoom(zoom.x + zoom_step)

func _process(_delta: float) -> void:
	if not _pressing:
		return

	var mouse_pos := get_viewport().get_mouse_position()

	# If we haven't started dragging yet, check threshold
	if not _dragging:
		if mouse_pos.distance_to(_press_pos) >= drag_threshold_px:
			_dragging = true
		else:
			# still considered a click; do nothing yet
			return

	# --- Dragging the view ---
	var delta := mouse_pos - _last_mouse_pos
	_last_mouse_pos = mouse_pos
	global_position -= delta * drag_sensitivity / zoom.x
	
func _set_zoom(z: float) -> void:
	z = clamp(z, min_zoom, max_zoom)
	zoom = Vector2(z, z)

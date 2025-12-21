extends Camera2D

# ============================================================
#  FILE: player_camera.gd
#  NODE: PlayerCamera (Camera2D)
#
#  ROLE: RTS-style camera controls (drag-pan + zoom)
# ------------------------------------------------------------
#  This camera supports:
#    - Drag to pan (default: left mouse button)
#    - Mouse wheel zoom in/out
#
#  CORE DESIGN GOAL: Input priority with selection
#  ------------------------------------------------------------
#  Our game uses the same mouse button for two behaviors:
#    - Dragging = move the camera
#    - Clicking = interact with the map (select chunk, units later)
#
#  We solve this by using a DRAG THRESHOLD:
#    - On mouse press: "maybe dragging"
#    - If the mouse moves >= drag_threshold_px while held: start dragging
#    - If it never crosses the threshold: treat as a click (camera does nothing)
#
#  IMPORTANT: We DO NOT call set_input_as_handled() here.
#  ------------------------------------------------------------
#  That means other nodes (Map) can still receive click events.
#  Map should also do its own click-vs-drag check on release using
#  a similar threshold (which it already does).
#
#  This approach keeps the camera simple and avoids fighting input order.
# ============================================================


# ============================================================
#  SECTION: Drag Settings
# ============================================================

@export var drag_button: MouseButton = MOUSE_BUTTON_LEFT

# Higher sensitivity = camera moves farther per mouse pixel.
@export var drag_sensitivity: float = 1.0

# How far the mouse must move (in pixels) before we consider it a drag.
@export var drag_threshold_px: float = 8.0


# ============================================================
#  SECTION: Zoom Settings
# ============================================================

@export var zoom_step: float = 0.1
@export var min_zoom: float = 0.5
@export var max_zoom: float = 2.5


# ============================================================
#  SECTION: Internal State
# ------------------------------------------------------------
#  _pressing:
#    - True while the drag button is held down.
#
#  _dragging:
#    - True once we have moved past the threshold.
#    - While _dragging, we pan the camera each frame.
#
#  _press_pos:
#    - Mouse position at the moment the button was pressed.
#
#  _last_mouse_pos:
#    - Previous mouse position used to compute per-frame delta.
# ============================================================

var _pressing: bool = false
var _dragging: bool = false
var _press_pos: Vector2 = Vector2.ZERO
var _last_mouse_pos: Vector2 = Vector2.ZERO


# ============================================================
#  SECTION: Public Helpers (optional)
# ------------------------------------------------------------
#  Useful if other systems want to know whether a drag is in progress.
#  Example: Map could ignore selection while dragging (extra safety).
# ============================================================

func is_dragging() -> bool:
	return _dragging


# ============================================================
#  SECTION: Input Handling
# ------------------------------------------------------------
#  _unhandled_input receives input events that were not consumed by UI.
#  We:
#    - Track press/release of the drag button
#    - Zoom on mouse wheel
# ============================================================

func _unhandled_input(event: InputEvent) -> void:
	# --- Drag button down/up ---
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

	# --- Zoom (mouse wheel) ---
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_set_zoom(zoom.x - zoom_step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_set_zoom(zoom.x + zoom_step)


# ============================================================
#  SECTION: Per-frame camera movement
# ------------------------------------------------------------
#  We only pan when:
#    - the drag button is held (_pressing)
#    - and the pointer moved past the drag threshold (_dragging)
#
#  Note:
#    - We divide by zoom.x so panning feels consistent at different zoom levels.
# ============================================================

func _process(_delta: float) -> void:
	if not _pressing:
		return

	var mouse_pos: Vector2 = get_viewport().get_mouse_position()

	# If we haven't started dragging yet, check threshold first
	if not _dragging:
		if mouse_pos.distance_to(_press_pos) >= drag_threshold_px:
			_dragging = true
		else:
			# Still considered a "click": camera should not move.
			return

	# Once dragging, pan by the per-frame delta
	var delta: Vector2 = mouse_pos - _last_mouse_pos
	_last_mouse_pos = mouse_pos

	# Dragging the view: move camera opposite to mouse movement.
	global_position -= delta * drag_sensitivity / zoom.x


# ============================================================
#  SECTION: Zoom helper
# ------------------------------------------------------------
#  Ensures zoom stays within min/max.
#  Zoom is uniform (same on X and Y).
# ============================================================

func _set_zoom(z: float) -> void:
	z = clamp(z, min_zoom, max_zoom)
	zoom = Vector2(z, z)

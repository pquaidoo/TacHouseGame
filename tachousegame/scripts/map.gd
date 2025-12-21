@tool
extends Area2D

# ============================================================
#  MAP CONTROLLER (Editor + Runtime)
# ------------------------------------------------------------
#  Responsibilities:
#    - Coordinate map layers (ground, grass, etc.)
#    - Convert mouse -> tile cell -> chunk coords
#    - Drive a separate ChunkHighlight node (draws above layers)
#
#  Non-responsibilities:
#    - Does NOT draw tiles itself
#    - Does NOT draw highlight itself (ChunkHighlight does)
# ============================================================


# ============================================================
#  SECTION: Map Generation Settings
# ============================================================

@export var chunk_size: int = 5:
	set(value):
		chunk_size = max(value, 3)
		_request_rebuild()

@export var map_size: int = 7:
	set(value):
		map_size = max(value, 1)
		_request_rebuild()

@export var seed: int = 12345:
	set(value):
		seed = value
		_request_rebuild()
		
@export var click_threshold_px: float = 8.0
var _click_press_pos := Vector2.ZERO
var _click_tracking := false



# ============================================================
#  SECTION: Scene Wiring (NodePaths)
# ------------------------------------------------------------
#  Drag these nodes from the Scene Tree into the Inspector:
#    - ground_layer_path    -> your Ground TileMapLayer
#    - grass_layer_path     -> your Grass TileMapLayer (optional)
#    - highlight_node_path  -> ChunkHighlight (Node2D) (optional)
# ============================================================

@export var ground_layer_path: NodePath
@export var grass_layer_path: NodePath
@export var highlight_node_path: NodePath


# ============================================================
#  SECTION: Chunk Hover / Selection
# ============================================================

@export var chunk_selection_enabled: bool = true

# The chunk currently under the mouse. (-1, -1) means "none".
var _hover_chunk: Vector2i = Vector2i(-1, -1)


# ============================================================
#  SECTION: Lifecycle
# ============================================================

func _ready() -> void:
	# Ensure these callbacks run even if tool/editor timing is weird.
	set_process(true)
	set_process_unhandled_input(true)

	rebuild()


# ============================================================
#  SECTION: Public API
# ============================================================

func rebuild() -> void:
	var ground: TileMapLayer = get_node_or_null(ground_layer_path) as TileMapLayer
	var grass: TileMapLayer = get_node_or_null(grass_layer_path) as TileMapLayer

	if ground == null:
		return

	# --- Step 1: Ground builds the base tiles ---
	ground.chunk_size = chunk_size
	ground.map_size = map_size
	ground.rebuild()

	# --- Step 2: Grass paints on top (optional) ---
	if grass != null and grass.has_method("rebuild_from_ground"):
		grass.rebuild_from_ground(ground, seed)

	# Recompute highlight after rebuild (useful in editor)
	_hover_chunk = Vector2i(-1, -1)
	_update_highlight(Vector2i(-1, -1))


# ============================================================
#  SECTION: Hover Update Loop
# ------------------------------------------------------------
#  Each frame:
#    - compute the chunk under the mouse
#    - if it changed, update the ChunkHighlight node
# ============================================================

func _process(_delta: float) -> void:
	if not chunk_selection_enabled:
		return

	var chunk: Vector2i = _chunk_at_mouse()
	if chunk != _hover_chunk:
		_hover_chunk = chunk
		_update_highlight(_hover_chunk)


# ============================================================
#  SECTION: Click Selection
# ============================================================

func _unhandled_input(event: InputEvent) -> void:
	if not chunk_selection_enabled:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_click_tracking = true
			_click_press_pos = get_viewport().get_mouse_position()
			return
		else:
			if not _click_tracking:
				return
			_click_tracking = false

			var release_pos := get_viewport().get_mouse_position()
			if release_pos.distance_to(_click_press_pos) > click_threshold_px:
				# It was a drag, don't select
				return

			var chunk: Vector2i = _chunk_at_mouse()
			if chunk.x != -1:
				print("Selected chunk:", chunk)



# ============================================================
#  SECTION: Mouse -> Cell -> Chunk
# ------------------------------------------------------------
#  1) Convert mouse to ground-local space
#  2) ground.local_to_map() -> tile cell (Vector2i)
#  3) cell / chunk_size -> chunk coord (Vector2i)
# ============================================================

func _chunk_at_mouse() -> Vector2i:
	var ground: TileMapLayer = get_node_or_null(ground_layer_path) as TileMapLayer
	if ground == null:
		return Vector2i(-1, -1)

	var mouse_local: Vector2 = ground.to_local(get_global_mouse_position())
	var cell: Vector2i = ground.local_to_map(mouse_local)

	var n: int = max(chunk_size, 1)
	var cx: int = int(floor(float(cell.x) / float(n)))
	var cy: int = int(floor(float(cell.y) / float(n)))

	# Bounds check (square map_size x map_size)
	if cx < 0 or cy < 0 or cx >= map_size or cy >= map_size:
		return Vector2i(-1, -1)

	return Vector2i(cx, cy)


# ============================================================
#  SECTION: Highlight Driver (Map -> ChunkHighlight)
# ------------------------------------------------------------
#  ChunkHighlight is responsible for drawing.
#  Map is responsible for providing 4 corner points in Map-local space.
# ============================================================

func _update_highlight(chunk: Vector2i) -> void:
	var ground: TileMapLayer = get_node_or_null(ground_layer_path) as TileMapLayer
	var hl: Node = get_node_or_null(highlight_node_path) as Node
	if ground == null or hl == null:
		return

	# No valid chunk -> clear highlight
	if chunk.x == -1:
		if hl.has_method("clear"):
			hl.call("clear")
		return

	var n: int = max(chunk_size, 1)
	var base: Vector2i = Vector2i(chunk.x * n, chunk.y * n)

	# Chunk corners in cell coords
	var c0: Vector2i = base
	var c1: Vector2i = base + Vector2i(n, 0)
	var c2: Vector2i = base + Vector2i(n, n)
	var c3: Vector2i = base + Vector2i(0, n)

	# Transform-safe:
	#   ground.map_to_local(cell) -> ground-local position
	#   ground.to_global(...)     -> global position
	#   Map.to_local(...)         -> Map-local position (what ChunkHighlight expects)
	var p0: Vector2 = to_local(ground.to_global(ground.map_to_local(c0)))
	var p1: Vector2 = to_local(ground.to_global(ground.map_to_local(c1)))
	var p2: Vector2 = to_local(ground.to_global(ground.map_to_local(c2)))
	var p3: Vector2 = to_local(ground.to_global(ground.map_to_local(c3)))

	if hl.has_method("set_points"):
		hl.call("set_points", [p0, p1, p2, p3])


# ============================================================
#  SECTION: Editor Rebuild Scheduling
# ============================================================

func _request_rebuild() -> void:
	if Engine.is_editor_hint():
		call_deferred("rebuild")

@tool
extends Area2D

# ============================================================
#  FILE: map.gd
#  NODE: Map (Area2D)
#
#  ROLE: High-level Map Controller
# ------------------------------------------------------------
#  This node acts as the "brain" of the map system.
#
#  It does NOT draw tiles or highlights directly.
#  Instead, it coordinates child nodes that specialize in:
#    - Tile generation (GroundLayer)
#    - Decorative overlays (GrassLayer)
#    - Visual feedback (ChunkHighlight)
#
#  This separation keeps responsibilities clean and makes
#  future refactors (new layers, new selection logic, etc.)
#  much easier.
# ============================================================


# ============================================================
#  SECTION: Map Generation Settings
# ------------------------------------------------------------
#  These values define the logical structure of the map.
#  Changing them triggers a rebuild (even in the editor).
#
#  chunk_size:
#    - Number of tiles per chunk (width & height)
#    - Must be >= 3 to avoid degenerate chunks
#
#  map_size:
#    - Number of chunks in each dimension
#    - Final map is map_size x map_size chunks
#
#  seed:
#    - Shared random seed used by layers that need randomness
#      (e.g., grass decoration placement)
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


# ============================================================
#  SECTION: Click / Drag Disambiguation
# ------------------------------------------------------------
#  We distinguish between:
#    - A click (select chunk)
#    - A drag (camera movement)
#
#  Camera movement uses a drag threshold.
#  Map selection uses the same idea:
#    - Press position is recorded
#    - On release, if movement < threshold, treat as click
# ============================================================

@export var click_threshold_px: float = 8.0

var _click_press_pos: Vector2 = Vector2.ZERO
var _click_tracking: bool = false


# ============================================================
#  SECTION: Scene Wiring (NodePaths)
# ------------------------------------------------------------
#  These paths are assigned in the Inspector.
#  We use NodePath instead of hard-coded $NodeName
#  to reduce coupling and allow easy refactors.
#
#  ground_layer_path (REQUIRED):
#    - TileMapLayer that generates the base terrain
#
#  grass_layer_path (OPTIONAL):
#    - TileMapLayer that paints decorative tiles over ground
#
#  highlight_node_path (OPTIONAL but recommended):
#    - Node2D that renders chunk hover / selection visuals
# ============================================================

@export var ground_layer_path: NodePath
@export var grass_layer_path: NodePath
@export var highlight_node_path: NodePath


# ============================================================
#  SECTION: Chunk Hover / Selection State
# ------------------------------------------------------------
#  chunk_selection_enabled:
#    - Master toggle for all hover & selection logic
#
#  _hover_chunk:
#    - Currently hovered chunk coordinate
#    - (-1, -1) means "no valid chunk under mouse"
# ============================================================

@export var chunk_selection_enabled: bool = true
var _hover_chunk: Vector2i = Vector2i(-1, -1)


# ============================================================
#  SECTION: Lifecycle
# ------------------------------------------------------------
#  Because this script runs in-editor (@tool),
#  we explicitly enable processing to avoid timing issues.
# ============================================================

func _ready() -> void:
	set_process(true)
	set_process_unhandled_input(true)
	rebuild()


# ============================================================
#  SECTION: Public API
# ------------------------------------------------------------
#  rebuild()
#    - Pushes generation settings into GroundLayer
#    - Triggers GroundLayer rebuild
#    - Triggers GrassLayer rebuild (if present)
#    - Clears any active highlight
#
#  This function is safe to call both in editor and runtime.
# ============================================================

func rebuild() -> void:
	var ground: TileMapLayer = get_node_or_null(ground_layer_path) as TileMapLayer
	var grass: TileMapLayer = get_node_or_null(grass_layer_path) as TileMapLayer

	if ground == null:
		return

	# --- Step 1: Build base terrain ---
	ground.chunk_size = chunk_size
	ground.map_size = map_size
	ground.rebuild()

	# --- Step 2: Paint decorations (optional) ---
	if grass != null and grass.has_method("rebuild_from_ground"):
		grass.rebuild_from_ground(ground, seed)

	# Reset highlight after rebuild
	_hover_chunk = Vector2i(-1, -1)
	_update_highlight(_hover_chunk)


# ============================================================
#  SECTION: Hover Update Loop
# ------------------------------------------------------------
#  Runs every frame:
#    - Determine which chunk is under the mouse
#    - Only update highlight if the chunk changed
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
# ------------------------------------------------------------
#  Selection occurs on mouse RELEASE (not press),
#  and only if the mouse did not move past the threshold.
#
#  This ensures:
#    - Camera drag takes priority
#    - Simple clicks still select chunks
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

			var release_pos: Vector2 = get_viewport().get_mouse_position()
			if release_pos.distance_to(_click_press_pos) > click_threshold_px:
				return  # Treated as a drag

			var chunk: Vector2i = _chunk_at_mouse()
			if chunk.x != -1:
				print("Selected chunk:", chunk)


# ============================================================
#  SECTION: Mouse -> Cell -> Chunk Conversion
# ------------------------------------------------------------
#  Conversion pipeline:
#    1) Global mouse position
#    2) Convert to GroundLayer local space
#    3) local_to_map() -> tile cell (Vector2i)
#    4) cell / chunk_size -> chunk coordinate
#
#  local_to_map() handles isometric projection correctly,
#  assuming the TileSet is configured as isometric.
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

	if cx < 0 or cy < 0 or cx >= map_size or cy >= map_size:
		return Vector2i(-1, -1)

	return Vector2i(cx, cy)


# ============================================================
#  SECTION: Highlight Driver (Map -> ChunkHighlight)
# ------------------------------------------------------------
#  Map computes chunk geometry.
#  ChunkHighlight is responsible for rendering.
#
#  We pass 4 corner points in MAP-LOCAL space.
#  Transform-safe conversion is used to remain correct even if
#  layers or Map are repositioned in the editor.
# ============================================================

func _update_highlight(chunk: Vector2i) -> void:
	var ground: TileMapLayer = get_node_or_null(ground_layer_path) as TileMapLayer
	var hl: Node = get_node_or_null(highlight_node_path)
	if ground == null or hl == null:
		return

	if chunk.x == -1:
		if hl.has_method("clear"):
			hl.call("clear")
		return

	var n: int = max(chunk_size, 1)
	var base: Vector2i = Vector2i(chunk.x * n, chunk.y * n)

	var c0: Vector2i = base
	var c1: Vector2i = base + Vector2i(n, 0)
	var c2: Vector2i = base + Vector2i(n, n)
	var c3: Vector2i = base + Vector2i(0, n)

	var p0: Vector2 = to_local(ground.to_global(ground.map_to_local(c0)))
	var p1: Vector2 = to_local(ground.to_global(ground.map_to_local(c1)))
	var p2: Vector2 = to_local(ground.to_global(ground.map_to_local(c2)))
	var p3: Vector2 = to_local(ground.to_global(ground.map_to_local(c3)))

	if hl.has_method("set_points"):
		hl.call("set_points", [p0, p1, p2, p3])


# ============================================================
#  SECTION: Editor Rebuild Scheduling
# ------------------------------------------------------------
#  Export setters may fire before the scene tree is ready.
#  call_deferred() ensures rebuild happens safely.
# ============================================================

func _request_rebuild() -> void:
	if Engine.is_editor_hint():
		call_deferred("rebuild")

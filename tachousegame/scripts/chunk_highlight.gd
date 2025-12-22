extends Node2D

# ============================================================
#  FILE: chunk_highlight.gd
#  NODE: ChunkHighlight (Node2D)
#
#  ROLE: Self-managing chunk highlight renderer
# ------------------------------------------------------------
#  This node autonomously handles:
#    - Mouse hover detection
#    - Chunk coordinate calculation
#    - Visual highlight rendering
#
#  It queries the Map node for configuration (chunk_size, map_size)
#  and the ground layer for coordinate transforms.
#
#  SCENE WIRING:
#    - map_node_path: Path to the Map node (for chunk_size/map_size)
#    - ground_layer_path: Path to the ground TileMapLayer
# ============================================================


# ============================================================
#  SECTION: Scene Wiring
# ============================================================

@export var map_node_path: NodePath
@export var ground_layer_path: NodePath


# ============================================================
#  SECTION: Appearance Settings
# ============================================================

@export var enabled: bool = true

# Fill inside the quad. Set to 0.0 for "outline only".
@export_range(0.0, 1.0, 0.01) var fill_alpha: float = 0.0

# Outline opacity + thickness.
@export_range(0.0, 1.0, 0.01) var outline_alpha: float = 0.85
@export var outline_width: float = 2.0

# Highlight color (RGB). Alpha is controlled by fill_alpha/outline_alpha.
@export var highlight_color: Color = Color(1, 1, 0)

# z_index used to keep this node on top of map layers.
@export var highlight_z_index: int = 100


# ============================================================
#  SECTION: Isometric Visual Correction (Y Offset)
# ------------------------------------------------------------
#  vertical_offset_px:
#    - Applied to all points RIGHT BEFORE drawing.
#    - Negative values move the highlight UP.
#    - Typical values for 32x16 iso tiles: -4 to -10
# ============================================================

@export var vertical_offset_px: float = -6.0


# ============================================================
#  SECTION: Runtime State
# ============================================================

# Current hovered chunk (or -1, -1 if none)
var _hover_chunk: Vector2i = Vector2i(-1, -1)

# Cached references
var _map_node: Node = null
var _ground_layer: TileMapLayer = null

# Exactly 4 points (or empty when hidden).
var _points: PackedVector2Array = PackedVector2Array()


# ============================================================
#  SECTION: Lifecycle
# ============================================================

func _ready() -> void:
	z_index = highlight_z_index

	# Cache node references
	_map_node = get_node_or_null(map_node_path)
	_ground_layer = get_node_or_null(ground_layer_path) as TileMapLayer


func _process(_delta: float) -> void:
	if not enabled:
		return

	# Ensure we have valid references
	if _map_node == null:
		_map_node = get_node_or_null(map_node_path)
	if _ground_layer == null:
		_ground_layer = get_node_or_null(ground_layer_path) as TileMapLayer

	if _map_node == null or _ground_layer == null:
		return

	# Check if chunk selection is enabled on the map
	if "chunk_selection_enabled" in _map_node and not _map_node.chunk_selection_enabled:
		return

	# Calculate current hovered chunk
	var chunk: Vector2i = _chunk_at_mouse()

	# Update highlight if chunk changed
	if chunk != _hover_chunk:
		_hover_chunk = chunk
		_update_highlight(chunk)


# ============================================================
#  SECTION: Mouse -> Cell -> Chunk Conversion
# ============================================================

func _chunk_at_mouse() -> Vector2i:
	if _ground_layer == null or _map_node == null:
		return Vector2i(-1, -1)

	# Get chunk_size and map_size from the Map node
	var chunk_size: int = 5
	var map_size: int = 7

	if "chunk_size" in _map_node:
		chunk_size = max(int(_map_node.chunk_size), 1)
	if "map_size" in _map_node:
		map_size = max(int(_map_node.map_size), 1)

	# Convert mouse to tile coordinates
	var mouse_local: Vector2 = _ground_layer.to_local(get_global_mouse_position())
	var cell: Vector2i = _ground_layer.local_to_map(mouse_local)

	# Convert tile to chunk coordinates
	var n: int = max(chunk_size, 1)
	var cx: int = int(floor(float(cell.x) / float(n)))
	var cy: int = int(floor(float(cell.y) / float(n)))

	# Validate chunk is within map bounds
	if cx < 0 or cy < 0 or cx >= map_size or cy >= map_size:
		return Vector2i(-1, -1)

	return Vector2i(cx, cy)


# ============================================================
#  SECTION: Highlight Update
# ============================================================

func _update_highlight(chunk: Vector2i) -> void:
	if _ground_layer == null or _map_node == null:
		_points = PackedVector2Array()
		queue_redraw()
		return

	# Hide highlight if no valid chunk
	if chunk.x == -1:
		_points = PackedVector2Array()
		queue_redraw()
		return

	# Get chunk_size from Map
	var chunk_size: int = 5
	if "chunk_size" in _map_node:
		chunk_size = max(int(_map_node.chunk_size), 1)

	var n: int = max(chunk_size, 1)
	var base: Vector2i = Vector2i(chunk.x * n, chunk.y * n)

	# Calculate the 4 corners of the chunk
	var c0: Vector2i = base
	var c1: Vector2i = base + Vector2i(n, 0)
	var c2: Vector2i = base + Vector2i(n, n)
	var c3: Vector2i = base + Vector2i(0, n)

	# Transform corners to local coordinates
	# ground.map_to_local(cell) -> ground-local
	# ground.to_global(...) -> global
	# Map.to_local(...) -> map-local (this node's parent should be Map)
	var parent_node = get_parent()
	if parent_node == null:
		return

	var p0: Vector2 = parent_node.to_local(_ground_layer.to_global(_ground_layer.map_to_local(c0)))
	var p1: Vector2 = parent_node.to_local(_ground_layer.to_global(_ground_layer.map_to_local(c1)))
	var p2: Vector2 = parent_node.to_local(_ground_layer.to_global(_ground_layer.map_to_local(c2)))
	var p3: Vector2 = parent_node.to_local(_ground_layer.to_global(_ground_layer.map_to_local(c3)))

	_points = PackedVector2Array([p0, p1, p2, p3])
	queue_redraw()


# ============================================================
#  SECTION: Rendering
# ============================================================

func _draw() -> void:
	if not enabled:
		return
	if _points.size() != 4:
		return

	# Apply a small vertical correction for isometric visuals.
	# (Negative moves up.)
	var offset: Vector2 = Vector2(0.0, vertical_offset_px)

	# Optional fill
	if fill_alpha > 0.0:
		var filled: PackedVector2Array = PackedVector2Array([
			_points[0] + offset,
			_points[1] + offset,
			_points[2] + offset,
			_points[3] + offset,
		])
		draw_colored_polygon(
			filled,
			Color(highlight_color.r, highlight_color.g, highlight_color.b, fill_alpha)
		)

	# Outline (closed loop)
	var loop: PackedVector2Array = PackedVector2Array([
		_points[0] + offset,
		_points[1] + offset,
		_points[2] + offset,
		_points[3] + offset,
		_points[0] + offset,
	])
	draw_polyline(
		loop,
		Color(highlight_color.r, highlight_color.g, highlight_color.b, outline_alpha),
		outline_width
	)

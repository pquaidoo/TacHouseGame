@tool
extends Area2D

# ============================================================
#  FILE: map.gd
#  NODE: Map (Area2D)
#
#  ROLE: High-level Map Controller (Editor + Runtime)
# ------------------------------------------------------------
#  Map.gd is the coordinator / “brain” of the map system.
#
#  Responsibilities:
#    - Own global map parameters (chunk_size, map_size, seed)
#    - Coordinate build order of layers:
#        1) Ground generates base tiles
#        2) Grass decorates over ground
#        3) Coins spawn on top of ground tiles (tile-based pickups)
#    - Convert mouse -> tile cell -> chunk coords
#    - Drive ChunkHighlight node (visual feedback)
#    - Handle click selection + coin collection (testing input)
#
#  Non-responsibilities:
#    - Does NOT draw tiles itself (TileMapLayers do)
#    - Does NOT draw highlight shapes (ChunkHighlight does)
#    - Does NOT implement camera behavior (Camera2D script does)
#
#  Scene wiring requirements (NodePaths in Inspector):
#    - ground_layer_path:    TileMapLayer (REQUIRED)
#    - grass_layer_path:     TileMapLayer (OPTIONAL)
#    - coin_layer_path:      TileMapLayer (OPTIONAL but used for coins)
#    - highlight_node_path:  Node2D (OPTIONAL but recommended)
#
#  Important ordering rule:
#    - Coins MUST spawn AFTER ground.rebuild()
#      because spawn checks which ground cells exist.
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


# ============================================================
#  SECTION: Click / Drag Disambiguation
# ------------------------------------------------------------
#  We only consider a “selection click” if the mouse didn’t move
#  far while the button was held (so camera dragging wins).
# ============================================================

@export var click_threshold_px: float = 8.0
var _click_press_pos: Vector2 = Vector2.ZERO
var _click_tracking: bool = false


# ============================================================
#  SECTION: Scene Wiring (NodePaths)
# ============================================================

@export var ground_layer_path: NodePath
@export var castle_layer_path: NodePath
@export var grass_layer_path: NodePath
@export var coin_layer_path: NodePath
@export var highlight_node_path: NodePath


# ============================================================
#  SECTION: Coin Generation Settings
# ------------------------------------------------------------
#  coin_chance:
#    - Probability per tile that a coin spawns (1/3/5)
#  Coins are tile-based and tracked by the CoinLayer script.
# ============================================================

@export_range(0.0, 1.0, 0.01) var coin_chance: float = 0.06


# ============================================================
#  SECTION: Chunk Hover / Selection State
# ============================================================

@export var chunk_selection_enabled: bool = true
var _hover_chunk: Vector2i = Vector2i(-1, -1)


# ============================================================
#  SECTION: Lifecycle
# ============================================================

func _ready() -> void:
	# Tool scripts can have odd editor timing; make sure these run.
	set_process(true)
	set_process_unhandled_input(true)
	rebuild()


# ============================================================
#  SECTION: Public API
# ============================================================

func rebuild() -> void:
	var ground: TileMapLayer = get_node_or_null(ground_layer_path) as TileMapLayer
	var grass: TileMapLayer = get_node_or_null(grass_layer_path) as TileMapLayer
	var coins: TileMapLayer = get_node_or_null(coin_layer_path) as TileMapLayer

	if ground == null:
		return

	# --- Step 1: Build base terrain ---
	ground.chunk_size = chunk_size
	ground.map_size = map_size
	ground.rebuild()
	
	var castle: TileMapLayer = get_node_or_null(castle_layer_path) as TileMapLayer
	if castle != null and castle.has_method("rebuild_from_map"):
		castle.call("rebuild_from_map", chunk_size, map_size)

	# --- Step 2: Grass decorates over ground (optional) ---
	if grass != null and grass.has_method("rebuild_from_ground"):
		grass.rebuild_from_ground(ground, seed)

	# --- Step 3: Spawn coins AFTER ground exists (optional) ---
	if coins != null and coins.has_method("clear_coins") and coins.has_method("place_coin"):
		coins.call("clear_coins")
		_spawn_coins(ground, coins)

	# Reset highlight after rebuild
	_hover_chunk = Vector2i(-1, -1)
	_update_highlight(_hover_chunk)


# ============================================================
#  SECTION: Hover Update Loop
# ============================================================

func _process(_delta: float) -> void:
	if not chunk_selection_enabled:
		return

	var chunk: Vector2i = _chunk_at_mouse()
	if chunk != _hover_chunk:
		_hover_chunk = chunk
		_update_highlight(_hover_chunk)


# ============================================================
#  SECTION: Click Selection + Coin Collect
# ------------------------------------------------------------
#  Priority:
#    1) If click hits a coin cell -> collect it and STOP
#    2) Otherwise -> select chunk and print coords
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
				return  # treated as a drag

			# --- 1) Coin collect (if present) ---
			var ground: TileMapLayer = get_node_or_null(ground_layer_path) as TileMapLayer
			var coin_layer: TileMapLayer = get_node_or_null(coin_layer_path) as TileMapLayer

			if ground != null and coin_layer != null and coin_layer.has_method("collect_coin"):
				var mouse_local: Vector2 = ground.to_local(get_global_mouse_position())
				var cell: Vector2i = ground.local_to_map(mouse_local)

				var gained: int = int(coin_layer.call("collect_coin", cell))
				if gained > 0:
					print("Collected coin:", gained, "at cell", cell)
					return

			# --- 2) Chunk select fallback ---
			var chunk: Vector2i = _chunk_at_mouse()
			if chunk.x != -1:
				print("Selected chunk:", chunk)


# ============================================================
#  SECTION: Mouse -> Cell -> Chunk Conversion
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

	# Transform-safe:
	#   ground.map_to_local(cell) -> ground-local
	#   ground.to_global(...)     -> global
	#   Map.to_local(...)         -> map-local (expected by ChunkHighlight)
	var p0: Vector2 = to_local(ground.to_global(ground.map_to_local(c0)))
	var p1: Vector2 = to_local(ground.to_global(ground.map_to_local(c1)))
	var p2: Vector2 = to_local(ground.to_global(ground.map_to_local(c2)))
	var p3: Vector2 = to_local(ground.to_global(ground.map_to_local(c3)))

	if hl.has_method("set_points"):
		hl.call("set_points", [p0, p1, p2, p3])


# ============================================================
#  SECTION: Coin Spawning
# ------------------------------------------------------------
#  We iterate the entire tile rectangle for the current map:
#    width  = map_size * chunk_size
#    height = map_size * chunk_size
#
#  We only place coins on cells where ground has a tile.
#  This prevents coins from spawning off-map.
# ============================================================

func _spawn_coins(ground: TileMapLayer, coin_layer: TileMapLayer) -> void:
	if ground == null or coin_layer == null:
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	var tiles_w: int = map_size * chunk_size
	var tiles_h: int = map_size * chunk_size

	for y in range(tiles_h):
		for x in range(tiles_w):
			var cell := Vector2i(x, y)

			# Only place coins on valid ground cells
			if ground.get_cell_source_id(cell) == -1:
				continue

			if rng.randf() > coin_chance:
				continue

			var amount := 1
			match rng.randi_range(0, 2):
				0: amount = 1
				1: amount = 3
				2: amount = 5

			coin_layer.call("place_coin", cell, amount)


# ============================================================
#  SECTION: Editor Rebuild Scheduling
# ============================================================

func _request_rebuild() -> void:
	if Engine.is_editor_hint():
		call_deferred("rebuild")

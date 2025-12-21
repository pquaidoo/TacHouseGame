@tool
extends TileMapLayer

# ============================================================
#  FILE: castle_layer.gd
#  NODE: CastleLayer (TileMapLayer)
#
#  ROLE: Places starter “castle tower” structures.
# ------------------------------------------------------------
#  This layer is responsible ONLY for static structure placement.
#  It does not perform gameplay logic or input handling.
#
#  CURRENT BEHAVIOR (INTENTIONALLY SIMPLE):
#    - Places exactly ONE tower in each CORNER CHUNK of the map:
#        • (0, 0)
#        • (map_size - 1, 0)
#        • (0, map_size - 1)
#        • (map_size - 1, map_size - 1)
#
#    - Each tower is placed at the CENTER TILE of its chunk.
#    - Assumes chunk_size is ODD (5, 7, 9, …).
#
#  TOWER STRUCTURE:
#    - Towers are composed of TWO separate 1×1 tiles:
#        • Base tile  → atlas coord (0, 4)
#        • Top tile   → atlas coord (0, 3)
#
#  IMPORTANT: ISOMETRIC TILE OFFSET (CRITICAL)
#  ------------------------------------------------------------
#  In isometric grids, the tile that *visually* appears “above” another
#  tile is NOT always at (0, -1) in grid space.
#
#  For the current tower art + TileSet configuration, the correct offset
#  for the TOP tile relative to the BASE tile is:
#
#        top_cell_offset = Vector2i(-2, -2)
#
#  This value was empirically verified and is art-dependent.
#  If the tower art or TileSet configuration changes in the future,
#  this value MUST be re-evaluated.
#
#  DO NOT “simplify” this offset without visually testing.
#
#  PUBLIC API (called by Map.gd):
#    - rebuild_from_map(chunk_size, map_size)
#    - get_occupied_cells() -> Array[Vector2i]
#
#  NOTE:
#    get_occupied_cells() returns ONLY the BASE cells of towers.
#    This is intentional, so other systems (grass, coins, paths)
#    can treat towers as occupying a single logical tile.
# ============================================================


# ============================================================
#  SECTION: TileSet Configuration
# ============================================================

@export var source_id: int = 0
@export var alternative_tile: int = 0


# ============================================================
#  SECTION: Tower Tile Atlas Coordinates
# ============================================================

# Base of the tower (bottom piece)
const TOWER_BASE_ATLAS := Vector2i(0, 4)

# Top of the tower (upper piece)
const TOWER_TOP_ATLAS  := Vector2i(0, 3)


# ============================================================
#  SECTION: Rendering Priority
# ------------------------------------------------------------
#  This layer should render ABOVE ground, grass, and coin layers.
# ============================================================

@export var castle_z_index: int = 50


# ============================================================
#  SECTION: Isometric Offset Configuration
# ------------------------------------------------------------
#  Offset used to place the TOP tile relative to the BASE tile.
#
#  For our current art, this MUST be (-2, -2).
#  Changing this without testing will visually break towers.
# ============================================================

@export var top_cell_offset: Vector2i = Vector2i(-2, -2)


# ============================================================
#  SECTION: Runtime State
# ------------------------------------------------------------
#  Stores BASE cells occupied by towers.
#  Used by other layers to avoid spawning grass/coins under towers.
# ============================================================

var _occupied: Array[Vector2i] = []


# ============================================================
#  SECTION: Lifecycle
# ============================================================

func _ready() -> void:
	# Ensure this layer renders above other TileMapLayers
	z_index = castle_z_index


# ============================================================
#  SECTION: Public API
# ============================================================

func rebuild_from_map(chunk_size: int, map_size: int) -> void:
	# Clear any previous structures
	clear()
	_occupied.clear()

	var n: int = max(chunk_size, 1)
	var half: int = n / 2  # valid when chunk_size is odd

	# Only the four CORNER chunks receive towers
	var corner_chunks: Array[Vector2i] = [
		Vector2i(0, 0),
		Vector2i(map_size - 1, 0),
		Vector2i(0, map_size - 1),
		Vector2i(map_size - 1, map_size - 1),
	]

	for chunk in corner_chunks:
		# Top-left tile coordinate of this chunk
		var chunk_origin := Vector2i(chunk.x * n, chunk.y * n)

		# Center tile inside the chunk
		var center_cell := chunk_origin + Vector2i(half, half)

		_place_tower(center_cell)


func get_occupied_cells() -> Array[Vector2i]:
	# Return a copy so callers cannot mutate internal state
	return _occupied.duplicate()


# ============================================================
#  SECTION: Internal Helpers
# ============================================================

func _place_tower(base_cell: Vector2i) -> void:
	# Base tile (logical occupancy)
	set_cell(base_cell, source_id, TOWER_BASE_ATLAS, alternative_tile)
	_occupied.append(base_cell)

	# Top tile (visual only)
	var top_cell := base_cell + top_cell_offset
	set_cell(top_cell, source_id, TOWER_TOP_ATLAS, alternative_tile)

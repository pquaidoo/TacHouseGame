@tool
extends TileMapLayer

# ============================================================
#  FILE: ground_layer.gd
#  NODE: GroundLayer (TileMapLayer)
#
#  ROLE: Base terrain generator
# ------------------------------------------------------------
#  This TileMapLayer is responsible for generating the “ground”
#  tiles of the map, chunk by chunk.
#
#  It draws a contiguous grid of chunks, where:
#    - Each chunk is chunk_size x chunk_size tiles
#    - The full map is map_size x map_size chunks
#
#  This layer does NOT:
#    - Handle mouse input
#    - Know about selection or highlighting
#    - Place decorations (grass, coins, etc.)
#
#  It is intentionally simple and deterministic.
# ============================================================


# ============================================================
#  SECTION: Parameters (Set by Map)
# ------------------------------------------------------------
#  These values are owned by Map.gd.
#  Map sets them before calling rebuild().
#
#  chunk_size:
#    - Number of tiles per chunk (width & height)
#
#  map_size:
#    - Number of chunks per axis (square map)
# ============================================================

@export var chunk_size: int = 5
@export var map_size: int = 2


# ============================================================
#  SECTION: TileSet Configuration
# ------------------------------------------------------------
#  source_id:
#    - TileSet source index to draw from
#
#  alternative_tile:
#    - Alternative tile index (used for variants if desired)
# ============================================================

@export var source_id: int = 0
@export var alternative_tile: int = 0


# ============================================================
#  SECTION: Tile Atlas Coordinates
# ------------------------------------------------------------
#  These constants define which atlas tile is used
#  depending on position within a chunk.
#
#  Naming convention:
#    - CORNER: outermost corners of a chunk
#    - EDGE:   edges that are not corners
#    - INNER:  interior tiles
#
#  The atlas layout is assumed to match these coordinates.
# ============================================================

const TILE_INNER := Vector2i(0, 0)

const TILE_LEFT_CORNER   := Vector2i(1, 0)
const TILE_TOP_CORNER    := Vector2i(2, 0)
const TILE_RIGHT_CORNER  := Vector2i(3, 0)
const TILE_BOTTOM_CORNER := Vector2i(4, 0)

const TILE_TOP_LEFT     := Vector2i(5, 0)
const TILE_TOP_RIGHT    := Vector2i(6, 0)
const TILE_BOTTOM_RIGHT := Vector2i(7, 0)
const TILE_BOTTOM_LEFT  := Vector2i(8, 0)


# ============================================================
#  SECTION: Lifecycle
# ------------------------------------------------------------
#  If this layer is run by itself (without Map),
#  it still draws once at runtime.
#
#  When Map exists, Map.rebuild() is the authoritative entry point.
# ============================================================

func _ready() -> void:
	if not Engine.is_editor_hint():
		rebuild()


# ============================================================
#  SECTION: Public API
# ------------------------------------------------------------
#  rebuild()
#    - Clears all existing tiles
#    - Regenerates the entire map chunk-by-chunk
#
#  Map.gd is expected to call this after setting parameters.
# ============================================================

func rebuild() -> void:
	_build_chunks()


# ============================================================
#  SECTION: Chunk Generation
# ------------------------------------------------------------
#  _build_chunks():
#    - Iterates over all chunk coordinates (cx, cy)
#    - Delegates tile placement to _build_one_chunk()
#
#  NOTE:
#    - chunk_size is clamped defensively to avoid invalid maps
# ============================================================

func _build_chunks() -> void:
	clear()

	var n: int = max(chunk_size, 5)
	var size: int = max(map_size, 1)

	for cy in range(size):
		for cx in range(size):
			_build_one_chunk(cx, cy, n)


# ============================================================
#  SECTION: Single Chunk Construction
# ------------------------------------------------------------
#  _build_one_chunk(cx, cy, n):
#    - cx, cy: chunk coordinates
#    - n:      chunk_size (tiles per axis)
#
#  We compute the chunk’s top-left tile coordinate in map space,
#  then fill an n x n grid of tiles.
# ============================================================

func _build_one_chunk(cx: int, cy: int, n: int) -> void:
	var base: Vector2i = Vector2i(cx * n, cy * n)

	for y in range(n):
		for x in range(n):
			var atlas: Vector2i = _pick_tile(x, y, n)
			set_cell(base + Vector2i(x, y), source_id, atlas, alternative_tile)


# ============================================================
#  SECTION: Tile Selection Logic
# ------------------------------------------------------------
#  _pick_tile(x, y, n):
#    - x, y: local tile coordinates within the chunk
#    - n:    chunk size
#
#  Determines which atlas tile to use based on position:
#    - Corners
#    - Edges
#    - Interior
#
#  This is purely positional logic and contains no randomness.
# ============================================================

func _pick_tile(x: int, y: int, n: int) -> Vector2i:
	var top_left     := (x == 0)
	var bottom_right := (x == n - 1)
	var top_right    := (y == 0)
	var bottom_left  := (y == n - 1)

	# --- Corners ---
	if top_left and bottom_left:     return TILE_LEFT_CORNER
	if top_right and bottom_right:   return TILE_RIGHT_CORNER
	if top_left and top_right:       return TILE_TOP_CORNER
	if bottom_left and bottom_right: return TILE_BOTTOM_CORNER

	# --- Edges (non-corner) ---
	if top_left:     return TILE_TOP_LEFT
	if top_right:    return TILE_TOP_RIGHT
	if bottom_left:  return TILE_BOTTOM_LEFT
	if bottom_right: return TILE_BOTTOM_RIGHT

	# --- Interior ---
	return TILE_INNER

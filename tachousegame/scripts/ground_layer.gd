@tool
extends TileMapLayer

# tiles per chunk edge
@export var chunk_size: int = 8:
	set(value):
		chunk_size = max(value, 3)
		if Engine.is_editor_hint():
			_build_chunk()

# how many chunks wide/tall the map is
@export var map_size: int = 5:
	set(value):
		map_size = max(value, 1)
		if Engine.is_editor_hint():
			_build_chunk()

# center map in the viewport (if false, it centers around world origin)
@export var center_in_viewport: bool = true:
	set(value):
		center_in_viewport = value
		if Engine.is_editor_hint():
			_build_chunk()

@export var source_id: int = 0
@export var alternative_tile: int = 0

const TILE_INNER := Vector2i(0, 0)
const TILE_LEFT_CORNER := Vector2i(1, 0)     # top-left corner
const TILE_TOP_CORNER := Vector2i(2, 0)      # top edge
const TILE_RIGHT_CORNER := Vector2i(3, 0)    # top-right corner
const TILE_BOTTOM_CORNER := Vector2i(4, 0)   # bottom edge
const TILE_TOP_LEFT := Vector2i(5, 0)        # left edge
const TILE_TOP_RIGHT := Vector2i(6, 0)       # right edge
const TILE_BOTTOM_RIGHT := Vector2i(7, 0)    # bottom-right corner
const TILE_BOTTOM_LEFT := Vector2i(8, 0)     # bottom-left corner

func _ready() -> void:
	print("Map ready:", self)
	_build_chunk()

func rebuild() -> void:
	_build_chunk()

# NOTE: kept name _build_chunk to match your conventions.
# This builds the *whole map* by drawing multiple chunks into this one TileMapLayer.
func _build_chunk() -> void:
	clear()

	var n := chunk_size

	for cy in range(map_size):
		for cx in range(map_size):
			_build_one_chunk(cx, cy, n)

	_center_map() # <- new

# Draw one chunk at chunk-grid coordinate (cx, cy)
func _build_one_chunk(cx: int, cy: int, n: int) -> void:
	var base := Vector2i(cx * n, cy * n) # top-left tile of this chunk in the full map

	for y in range(n):
		for x in range(n):
			var atlas := _pick_tile(x, y, n) # your local chunk logic
			set_cell(base + Vector2i(x, y), source_id, atlas, alternative_tile)

func _center_map() -> void:
	# total map size in tiles
	var tiles_w := map_size * chunk_size
	var tiles_h := map_size * chunk_size

	# tile pixel size from the TileSet (works for iso too; the math below is iso-friendly)
	var tile_px := tile_set.tile_size

	# isometric diamond bounding box approximation
	var map_pixel_width  := (tiles_w + tiles_h) * tile_px.x * 0.5
	var map_pixel_height := (tiles_w + tiles_h) * tile_px.y * 0.5

	if center_in_viewport:
		var viewport_center := get_viewport_rect().size * 0.5
		position = viewport_center - Vector2(map_pixel_width, map_pixel_height) * 0.5
	else:
		# center around world origin (0,0)
		position = -Vector2(map_pixel_width, map_pixel_height) * 0.5

# Kept EXACT function name/signature and your logic.
func _pick_tile(x: int, y: int, n: int) -> Vector2i:
	var top_left := (x == 0)
	var bottom_right := (x == n - 1)
	var top_right := (y == 0)
	var bottom_left := (y == n - 1)

	# corners
	if top_left and bottom_left: return TILE_LEFT_CORNER        # left
	if top_right and bottom_right: return TILE_RIGHT_CORNER      # right
	if top_left and top_right: return TILE_TOP_CORNER   # top
	if bottom_left and bottom_right: return TILE_BOTTOM_CORNER   # bottom

	# edges (not corners)
	if top_left: return TILE_TOP_LEFT # top left
	if top_right: return TILE_TOP_RIGHT # top right
	if bottom_left: return TILE_BOTTOM_LEFT # bottom left
	if bottom_right: return TILE_BOTTOM_RIGHT # bottom right

	# interior
	return TILE_INNER

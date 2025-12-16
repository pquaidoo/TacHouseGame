@tool
extends TileMapLayer

@export var chunk_size: int = 8:
	set(value):
		chunk_size = max(value, 3)
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
	if not Engine.is_editor_hint():
		_build_chunk()

func _build_chunk() -> void:
	clear()

	var n := chunk_size
	for y in range(n):
		for x in range(n):
			var atlas := _pick_tile(x, y, n)
			set_cell(Vector2i(x, y), source_id, atlas, alternative_tile)

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

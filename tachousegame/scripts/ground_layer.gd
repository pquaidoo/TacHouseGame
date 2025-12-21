@tool
extends TileMapLayer

# Map will set these before calling rebuild()
@export var chunk_size: int = 5
@export var map_size: int = 2

@export var source_id: int = 0
@export var alternative_tile: int = 0

const TILE_INNER := Vector2i(0, 0)
const TILE_LEFT_CORNER := Vector2i(1, 0)
const TILE_TOP_CORNER := Vector2i(2, 0)
const TILE_RIGHT_CORNER := Vector2i(3, 0)
const TILE_BOTTOM_CORNER := Vector2i(4, 0)
const TILE_TOP_LEFT := Vector2i(5, 0)
const TILE_TOP_RIGHT := Vector2i(6, 0)
const TILE_BOTTOM_RIGHT := Vector2i(7, 0)
const TILE_BOTTOM_LEFT := Vector2i(8, 0)


func _ready() -> void:
	# If you run the scene without a Map controller, it still draws once.
	# But if Map exists, it will call rebuild() anyway.
	if not Engine.is_editor_hint():
		rebuild()


func rebuild() -> void:
	_build_chunk()


func _build_chunk() -> void:
	clear()

	var n = max(chunk_size, 5)
	var size = max(map_size, 1)

	for cy in range(size):
		for cx in range(size):
			_build_one_chunk(cx, cy, n)
			


func _build_one_chunk(cx: int, cy: int, n: int) -> void:
	var base := Vector2i(cx * n, cy * n)

	for y in range(n):
		for x in range(n):
			var atlas := _pick_tile(x, y, n)
			set_cell(base + Vector2i(x, y), source_id, atlas, alternative_tile)


func _pick_tile(x: int, y: int, n: int) -> Vector2i:
	var top_left := (x == 0)
	var bottom_right := (x == n - 1)
	var top_right := (y == 0)
	var bottom_left := (y == n - 1)

	if top_left and bottom_left: return TILE_LEFT_CORNER
	if top_right and bottom_right: return TILE_RIGHT_CORNER
	if top_left and top_right: return TILE_TOP_CORNER
	if bottom_left and bottom_right: return TILE_BOTTOM_CORNER

	if top_left: return TILE_TOP_LEFT
	if top_right: return TILE_TOP_RIGHT
	if bottom_left: return TILE_BOTTOM_LEFT
	if bottom_right: return TILE_BOTTOM_RIGHT

	return TILE_INNER

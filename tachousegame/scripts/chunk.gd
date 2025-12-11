extends TileMapLayer

@export var rows_cols: Vector2i = Vector2i(8, 8) :
	set(value):
		rows_cols = value
		if Engine.is_editor_hint():
			_build_chunk()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_build_chunk()

# Which tile to use for filling the chunk
@export var source_id: int = 0              # tileset source (usually 0 if you have one atlas)
@export var atlas_coords: Vector2i = Vector2i(0, 0)  # which tile in that atlas
@export var alternative_tile: int = 0       # usually 0 unless you're using alternatives

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func _build_chunk() -> void:
	clear()
	for y in rows_cols.y:
		for x in rows_cols.x:
			set_cell(Vector2i(x, y), source_id, atlas_coords, alternative_tile)

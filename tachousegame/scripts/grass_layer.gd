@tool
extends TileMapLayer

@export var source_id: int = 0
@export var alternative_tile: int = 0

# how much grass to place (0.0 = none, 1.0 = on every tile)
@export_range(0.0, 1.0, 0.01) var grass_chance: float = 0.25

# Put 6 atlas coords here (one per grass variation)
@export var grass_atlas_coords: Array[Vector2i] = [
	Vector2i(0, 1),
	Vector2i(1, 1),
	Vector2i(2, 1),
	Vector2i(3, 1),
	Vector2i(4, 1),
	Vector2i(5, 1),
]

func rebuild_from_ground(ground: TileMapLayer, seed: int) -> void:
	clear()

	if ground == null:
		return
	if grass_atlas_coords.size() == 0:
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	# Every tile that exists on the ground layer
	var cells: Array[Vector2i] = ground.get_used_cells()

	for cell in cells:
		if rng.randf() > grass_chance:
			continue

		var atlas := grass_atlas_coords[rng.randi_range(0, grass_atlas_coords.size() - 1)]
		set_cell(cell, source_id, atlas, alternative_tile)

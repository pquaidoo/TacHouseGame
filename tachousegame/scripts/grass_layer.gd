@tool
extends TileMapLayer

# ============================================================
#  FILE: grass_layer.gd
#  NODE: GrassLayer (TileMapLayer)
#
#  ROLE: Decorative overlay generator
# ------------------------------------------------------------
#  This TileMapLayer paints grass (or similar decorative tiles)
#  on top of an existing ground layer.
#
#  Grass placement:
#    - Is purely decorative
#    - Does NOT affect gameplay or collision
#    - Is driven by randomness + a shared seed
#
#  This layer does NOT:
#    - Know about chunks
#    - Generate its own map bounds
#    - Respond to input or selection
#
#  It relies entirely on the ground layer as its “canvas”.
# ============================================================


# ============================================================
#  SECTION: TileSet Configuration
# ------------------------------------------------------------
#  source_id:
#    - TileSet source index used for grass tiles
#
#  alternative_tile:
#    - Optional alternative tile index (for variants, if used)
# ============================================================

@export var source_id: int = 0
@export var alternative_tile: int = 0


# ============================================================
#  SECTION: Generation Settings
# ------------------------------------------------------------
#  grass_chance:
#    - Probability that any given ground tile gets grass
#    - 0.0 = no grass
#    - 1.0 = grass on every tile
#
#  This value is evaluated independently per tile.
# ============================================================

@export_range(0.0, 1.0, 0.01) var grass_chance: float = 0.25


# ============================================================
#  SECTION: Atlas Variations
# ------------------------------------------------------------
#  grass_atlas_coords:
#    - List of atlas coordinates representing grass variations
#    - One is chosen randomly per placed grass tile
#
#  The atlas layout is assumed to match these coordinates.
#  This makes visual variety easy without extra logic.
# ============================================================

@export var grass_atlas_coords: Array[Vector2i] = [
	Vector2i(0, 1),
	Vector2i(1, 1),
	Vector2i(2, 1),
	Vector2i(3, 1),
	Vector2i(4, 1),
	Vector2i(5, 1),
]


# ============================================================
#  SECTION: Public API (called by Map.gd)
# ------------------------------------------------------------
#  rebuild_from_ground(ground, seed)
#
#  Parameters:
#    - ground: TileMapLayer
#        The already-built ground layer. Grass will only
#        be placed on tiles that exist in this layer.
#
#    - seed: int
#        Shared random seed provided by Map.
#        Ensures deterministic generation when rebuilding.
#
#  Behavior:
#    - Clears any existing grass tiles
#    - Iterates over all used ground cells
#    - Places grass randomly based on grass_chance
# ============================================================

func rebuild_from_ground(ground: TileMapLayer, seed: int) -> void:
	clear()

	if ground == null:
		return
	if grass_atlas_coords.size() == 0:
		return

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed

	# Use the ground layer as the authoritative source of valid tiles.
	var cells: Array[Vector2i] = ground.get_used_cells()

	for cell in cells:
		if rng.randf() > grass_chance:
			continue

		var atlas: Vector2i = grass_atlas_coords[
			rng.randi_range(0, grass_atlas_coords.size() - 1)
		]

		set_cell(cell, source_id, atlas, alternative_tile)

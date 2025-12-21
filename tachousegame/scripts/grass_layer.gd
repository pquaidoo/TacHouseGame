@tool
extends TileMapLayer

# ============================================================
#  FILE: grass_layer.gd
#  NODE: GrassLayer (TileMapLayer)
#
#  ROLE:
#    Decorative grass generation over ground tiles.
#
#  CURRENT GENERATION MODE:
#    RANDOM-WALK BLOBS (drunkard walk + brush stamping)
#
#  PATCH MODEL:
#    - Pick a random ground cell as patch center.
#    - Perform a random walk for N steps.
#    - At each step, stamp a small "brush" disk of grass.
#    - Assign thick/medium/thin based on patch "age":
#        • early steps = thick
#        • mid steps   = medium
#        • late steps  = thin
#
#  WHY THIS MODE:
#    - Produces organic blob shapes (not perfect circles).
#    - Easy to tune: steps, brush radius, jitter, branching.
#
#  SCALING (MAP-SIZE INDEPENDENT):
#    - patch_coverage (0..1): ~ fraction of ground tiles painted as grass
#    - patch_size     (0..1): many small patches -> fewer large patches
#
#  DEBUG:
#    - debug_print_stats prints counts of thick/medium/thin placed.
#    - debug_verify_tiles prints a limited number of cells where we compare:
#         intended atlas vs placed atlas + source id
#      Use this to catch wrong atlas coords or wrong source_id.
#
#  Public API (called by Map.gd):
#    - rebuild_from_ground(ground, seed)
# ============================================================


# ============================================================
#  SECTION: TileSet Configuration
# ============================================================

@export var source_id: int = 0
@export var alternative_tile: int = 0


# ============================================================
#  SECTION: Patch Controls (Sliders)
# ============================================================

@export_range(0.0, 1.0, 0.01) var patch_coverage: float = 0.25
@export_range(0.0, 1.0, 0.01) var patch_size: float = 0.45


# ============================================================
#  SECTION: Random-Walk Controls
# ------------------------------------------------------------
#  These tune the shape of the random-walk patch.
# ============================================================

# Brush radius range (disk stamp) used at each step.
# Higher values = chunkier, more filled blobs.
@export_range(0, 6, 1) var brush_radius_min: int = 1
@export_range(0, 6, 1) var brush_radius_max: int = 2

# Probability to "keep moving in the same direction" vs pick a new direction.
# Higher = longer streaks; lower = jittery clumps.
@export_range(0.0, 1.0, 0.01) var keep_direction_chance: float = 0.70

# Probability to take a diagonal step when choosing direction.
# 0 = strictly 4-neighbor; 1 = allow diagonals equally.
@export_range(0.0, 1.0, 0.01) var diagonal_step_chance: float = 0.35

# Occasionally jump back near the patch center to create denser cores.
@export_range(0.0, 1.0, 0.01) var recenter_chance: float = 0.06

# Optional branching: sometimes we spawn a short sub-walk from the current position.
@export_range(0.0, 1.0, 0.01) var branch_chance: float = 0.05
@export_range(0.0, 1.0, 0.01) var branch_length_scale: float = 0.35

# Overall stamp acceptance probability (in addition to density below).
# Use this if you want “airier” blobs without changing brush size.
@export_range(0.0, 1.0, 0.01) var stamp_chance: float = 1.00


# ============================================================
#  SECTION: Ring / Thickness Controls
# ------------------------------------------------------------
#  In walk-mode, these control how quickly thickness thins out
#  over the course of the walk. Larger ring_scale = thicker core.
# ============================================================

@export_range(0.25, 3.0, 0.05) var ring_scale: float = 1.0


# ============================================================
#  SECTION: Density Controls
# ------------------------------------------------------------
#  density: overall chance a candidate cell gets painted after it
#  passes other checks. Lower = patch more “speckled.”
# ============================================================

@export_range(0.10, 1.00, 0.01) var density: float = 0.85


# ============================================================
#  SECTION: Debug Controls
# ============================================================

@export var debug_print_stats: bool = true

# When true, we read back what was placed after set_cell() and print it.
# This helps catch wrong atlas coords or wrong source_id.
@export var debug_verify_tiles: bool = false

# Hard limit so the console doesn't explode.
@export var debug_verify_limit: int = 20

var _debug_verified: int = 0


# ============================================================
#  SECTION: Atlas Groups (your art buckets)
# ============================================================

@export var thick_grass_atlas_coords: Array[Vector2i] = [
	Vector2i(4, 1)
]

@export var medium_grass_atlas_coords: Array[Vector2i] = [
	Vector2i(3, 1),
	Vector2i(1, 1),
	Vector2i(0, 1)
]

@export var thin_grass_atlas_coords: Array[Vector2i] = [
	Vector2i(2, 1),
	Vector2i(5, 1)
]


# ============================================================
#  SECTION: Entry Point (called by Map.gd)
# ============================================================

func rebuild_from_ground(ground: TileMapLayer, seed: int) -> void:
	# Clear existing decorative grass first.
	clear()
	_debug_verified = 0

	if ground == null:
		return

	var cells: Array[Vector2i] = ground.get_used_cells()
	if cells.is_empty():
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	# painted: Vector2i -> true (prevents double painting / overlap cost)
	var painted: Dictionary = {}

	var total_cells: int = cells.size()
	var target_tiles: int = int(round(float(total_cells) * patch_coverage))
	if target_tiles <= 0:
		return

	# ------------------------------------------------------------
	# Patch sizing: pick an average patch tile budget, then compute
	# how many patches we need to reach target_tiles.
	# ------------------------------------------------------------
	var min_avg_patch_tiles: int = 12
	var max_avg_patch_tiles: int = 180

	var avg_patch_tiles_f: float = lerp(float(min_avg_patch_tiles), float(max_avg_patch_tiles), patch_size)
	var avg_patch_tiles: int = max(1, int(round(avg_patch_tiles_f)))

	var patch_count: int = max(1, int(ceil(float(target_tiles) / float(avg_patch_tiles))))

	# ------------------------------------------------------------
	# Walk parameters derived from avg_patch_tiles:
	# - steps: how long the walk is
	# - rings: what portion of the walk counts as thick/medium/thin
	#   (ring_scale stretches the thick/medium regions)
	# ------------------------------------------------------------
	var steps: int = max(4, int(round(float(avg_patch_tiles) * 1.20)))
	# Use more steps when brush is small; fewer when brush is large.
	var avg_brush: float = float(brush_radius_min + brush_radius_max) * 0.5
	steps = int(round(float(steps) / max(0.75, (avg_brush + 1.0) * 0.75)))

	# Thickness thresholds are based on step index:
	#   [0 .. core_step] => thick
	#   (core_step .. mid_step] => medium
	#   > mid_step => thin
	var base_steps: int = max(6, int(round(float(steps) * ring_scale)))
	var core_step: int = max(2, int(round(float(base_steps) * 0.35)))
	var mid_step: int  = max(core_step + 1, int(round(float(base_steps) * 0.70)))

	# --- Debug counters (what we ACTUALLY place) ---
	var placed_total: int = 0
	var placed_thick: int = 0
	var placed_medium: int = 0
	var placed_thin: int = 0

	var painted_count: int = 0

	for _i in range(patch_count):
		if painted_count >= target_tiles:
			break

		var center: Vector2i = cells[rng.randi_range(0, total_cells - 1)]

		var result: Dictionary = _paint_random_walk_patch(
			ground,
			rng,
			center,
			painted,
			steps,
			core_step,
			mid_step
		)

		var new_total: int = int(result.get("new_total", 0))
		painted_count += new_total

		placed_total += new_total
		placed_thick += int(result.get("new_thick", 0))
		placed_medium += int(result.get("new_medium", 0))
		placed_thin += int(result.get("new_thin", 0))

	if debug_print_stats:
		print(
			"[GrassLayer] total_cells=", total_cells,
			" target_tiles=", target_tiles,
			" placed_total=", placed_total,
			" (thick=", placed_thick,
			" medium=", placed_medium,
			" thin=", placed_thin, ")"
		)
		print(
			"[GrassLayer] patch_count=", patch_count,
			" avg_patch_tiles=", avg_patch_tiles,
			" steps=", steps,
			" core_step=", core_step,
			" mid_step=", mid_step,
			" brush_radius_min=", brush_radius_min,
			" brush_radius_max=", brush_radius_max,
			" keep_direction_chance=", keep_direction_chance,
			" diagonal_step_chance=", diagonal_step_chance,
			" recenter_chance=", recenter_chance,
			" branch_chance=", branch_chance,
			" branch_length_scale=", branch_length_scale,
			" density=", density,
			" stamp_chance=", stamp_chance,
			" ring_scale=", ring_scale,
			" source_id=", source_id
		)


# ============================================================
#  SECTION: Patch Painting (Random-Walk + Brush Stamp)
# ------------------------------------------------------------
#  Performs a walk starting at center, stamping a disk brush.
#
#  Returns a Dictionary:
#    { new_total, new_thick, new_medium, new_thin }
#
#  Thickness decision is based on "age" of the walk (step index),
#  not geometric distance. This gives a strong thick core if
#  recentering is enabled and the walk revisits near the origin.
# ============================================================

func _paint_random_walk_patch(
	ground: TileMapLayer,
	rng: RandomNumberGenerator,
	center: Vector2i,
	painted: Dictionary,
	steps: int,
	core_step: int,
	mid_step: int
) -> Dictionary:
	var newly_painted: int = 0
	var new_thick: int = 0
	var new_medium: int = 0
	var new_thin: int = 0

	var pos: Vector2i = center

	# Current direction: starts random
	var dir: Vector2i = _pick_step_direction(rng, Vector2i.ZERO)

	# One patch may spawn a few branch walks. We budget them by calling
	# a short helper that also stamps using the same rules.
	var main_steps: int = steps

	for step_i in range(main_steps):
		# If we walked onto non-ground, pull back towards center.
		if ground.get_cell_source_id(pos) == -1:
			pos = center

		# Occasional jump back near center to densify core.
		if rng.randf() < recenter_chance:
			pos = center

		# Decide thickness bucket based on walk age.
		var atlas_bucket_primary: Array[Vector2i]
		var atlas_bucket_fallback1: Array[Vector2i]
		var atlas_bucket_fallback2: Array[Vector2i]
		var is_thick := false
		var is_medium := false

		if step_i <= core_step:
			atlas_bucket_primary = thick_grass_atlas_coords
			atlas_bucket_fallback1 = medium_grass_atlas_coords
			atlas_bucket_fallback2 = thin_grass_atlas_coords
			is_thick = true
		elif step_i <= mid_step:
			atlas_bucket_primary = medium_grass_atlas_coords
			atlas_bucket_fallback1 = thick_grass_atlas_coords
			atlas_bucket_fallback2 = thin_grass_atlas_coords
			is_medium = true
		else:
			atlas_bucket_primary = thin_grass_atlas_coords
			atlas_bucket_fallback1 = medium_grass_atlas_coords
			atlas_bucket_fallback2 = thick_grass_atlas_coords

		# Stamp a disk brush at current position.
		var radius: int = _rand_int_inclusive(rng, brush_radius_min, brush_radius_max)
		var stamp_result: Dictionary = _stamp_disk(
			ground,
			rng,
			pos,
			radius,
			painted,
			atlas_bucket_primary,
			atlas_bucket_fallback1,
			atlas_bucket_fallback2,
			is_thick,
			is_medium
		)

		newly_painted += int(stamp_result.get("new_total", 0))
		new_thick += int(stamp_result.get("new_thick", 0))
		new_medium += int(stamp_result.get("new_medium", 0))
		new_thin += int(stamp_result.get("new_thin", 0))

		# Optional branching: spawn a small sub-walk from current pos.
		# This helps create irregular lobes.
		if rng.randf() < branch_chance:
			var branch_len: int = max(2, int(round(float(main_steps) * branch_length_scale)))
			var branch_res: Dictionary = _branch_walk(
				ground,
				rng,
				pos,
				branch_len,
				center,
				painted,
				core_step,
				mid_step
			)
			newly_painted += int(branch_res.get("new_total", 0))
			new_thick += int(branch_res.get("new_thick", 0))
			new_medium += int(branch_res.get("new_medium", 0))
			new_thin += int(branch_res.get("new_thin", 0))

		# Choose next direction:
		# - keep same direction with keep_direction_chance
		# - otherwise pick a new direction
		if rng.randf() > keep_direction_chance:
			dir = _pick_step_direction(rng, dir)

		pos += dir

	return {
		"new_total": newly_painted,
		"new_thick": new_thick,
		"new_medium": new_medium,
		"new_thin": new_thin
	}


# ============================================================
#  SECTION: Branch Walk
# ------------------------------------------------------------
#  A short sub-walk that uses the SAME stamping/thickness logic
#  but reuses the main patch’s thresholds to keep a coherent look.
# ============================================================

func _branch_walk(
	ground: TileMapLayer,
	rng: RandomNumberGenerator,
	start: Vector2i,
	branch_steps: int,
	center: Vector2i,
	painted: Dictionary,
	core_step: int,
	mid_step: int
) -> Dictionary:
	var newly_painted := 0
	var new_thick := 0
	var new_medium := 0
	var new_thin := 0

	var pos := start
	var dir := _pick_step_direction(rng, Vector2i.ZERO)

	for step_i in range(branch_steps):
		if ground.get_cell_source_id(pos) == -1:
			pos = center

		# Branches are usually “later” growth visually, so bias them
		# a bit towards medium/thin by shifting the age index forward.
		var age_i: int = step_i + mid_step

		var atlas_primary: Array[Vector2i]
		var fallback1: Array[Vector2i]
		var fallback2: Array[Vector2i]
		var is_thick := false
		var is_medium := false

		if age_i <= core_step:
			atlas_primary = thick_grass_atlas_coords
			fallback1 = medium_grass_atlas_coords
			fallback2 = thin_grass_atlas_coords
			is_thick = true
		elif age_i <= mid_step:
			atlas_primary = medium_grass_atlas_coords
			fallback1 = thick_grass_atlas_coords
			fallback2 = thin_grass_atlas_coords
			is_medium = true
		else:
			atlas_primary = thin_grass_atlas_coords
			fallback1 = medium_grass_atlas_coords
			fallback2 = thick_grass_atlas_coords

		var radius: int = _rand_int_inclusive(rng, brush_radius_min, brush_radius_max)
		var stamp_result := _stamp_disk(
			ground,
			rng,
			pos,
			radius,
			painted,
			atlas_primary,
			fallback1,
			fallback2,
			is_thick,
			is_medium
		)

		newly_painted += int(stamp_result.get("new_total", 0))
		new_thick += int(stamp_result.get("new_thick", 0))
		new_medium += int(stamp_result.get("new_medium", 0))
		new_thin += int(stamp_result.get("new_thin", 0))

		# Branch direction changes more often to keep branches lumpy.
		if rng.randf() > (keep_direction_chance * 0.6):
			dir = _pick_step_direction(rng, dir)

		pos += dir

	return {
		"new_total": newly_painted,
		"new_thick": new_thick,
		"new_medium": new_medium,
		"new_thin": new_thin
	}


# ============================================================
#  SECTION: Disk Stamp
# ------------------------------------------------------------
#  Stamps a filled disk around center_pos.
#
#  Rules:
#    - only stamp on ground tiles (source_id != -1 in ground layer)
#    - never stamp same cell twice (painted dict)
#    - applies density + stamp_chance as acceptance
#    - chooses atlas from provided buckets
#
#  NOTE:
#    stamp_chance lets you reduce stamping rate without changing
#    brush size or step count.
# ============================================================

func _stamp_disk(
	ground: TileMapLayer,
	rng: RandomNumberGenerator,
	center_pos: Vector2i,
	radius: int,
	painted: Dictionary,
	primary: Array[Vector2i],
	fallback1: Array[Vector2i],
	fallback2: Array[Vector2i],
	count_as_thick: bool,
	count_as_medium: bool
) -> Dictionary:
	var newly_painted := 0
	var new_thick := 0
	var new_medium := 0
	var new_thin := 0

	if radius <= 0:
		# still attempt the center cell
		radius = 0

	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var cell := center_pos + Vector2i(dx, dy)

			# disk check
			if (dx * dx + dy * dy) > (radius * radius):
				continue

			if ground.get_cell_source_id(cell) == -1:
				continue
			if painted.has(cell):
				continue

			# acceptance gates
			if rng.randf() > stamp_chance:
				continue
			if rng.randf() > density:
				continue

			var atlas: Vector2i = _pick_from_bucket(rng, primary, fallback1, fallback2)

			set_cell(cell, source_id, atlas, alternative_tile)
			painted[cell] = true
			newly_painted += 1

			if count_as_thick:
				new_thick += 1
			elif count_as_medium:
				new_medium += 1
			else:
				new_thin += 1

			# DEBUG: Verify what was actually placed
			if debug_verify_tiles and _debug_verified < debug_verify_limit:
				var placed_atlas: Vector2i = get_cell_atlas_coords(cell)
				var placed_src: int = get_cell_source_id(cell)
				print(
					"[GrassLayer VERIFY] cell=", cell,
					" intended_atlas=", atlas,
					" placed_atlas=", placed_atlas,
					" placed_source_id=", placed_src,
					" expected_source_id=", source_id
				)
				_debug_verified += 1

	return {
		"new_total": newly_painted,
		"new_thick": new_thick,
		"new_medium": new_medium,
		"new_thin": new_thin
	}


# ============================================================
#  SECTION: Step Direction Picker
# ------------------------------------------------------------
#  Chooses a step direction, optionally allowing diagonals.
#
#  If prev_dir is non-zero, we try not to immediately reverse
#  direction too often (helps reduce jitter).
# ============================================================

func _pick_step_direction(rng: RandomNumberGenerator, prev_dir: Vector2i) -> Vector2i:
	var dirs_4 := [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1)
	]
	var dirs_8 := [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1),
		Vector2i(1, 1),
		Vector2i(1, -1),
		Vector2i(-1, 1),
		Vector2i(-1, -1)
	]

	var use_diagonal: bool = (rng.randf() < diagonal_step_chance)
	var options = dirs_8 if use_diagonal else dirs_4

	# Avoid immediate reversal if possible.
	var reverse := -prev_dir
	var attempts := 0
	while attempts < 6:
		var d: Vector2i = options[rng.randi_range(0, options.size() - 1)]
		if prev_dir == Vector2i.ZERO:
			return d
		if d != reverse:
			return d
		attempts += 1

	# If we failed to avoid reversal, just return something.
	return options[rng.randi_range(0, options.size() - 1)]


# ============================================================
#  SECTION: Bucket Picker
# ============================================================

func _pick_from_bucket(
	rng: RandomNumberGenerator,
	primary: Array[Vector2i],
	fallback1: Array[Vector2i],
	fallback2: Array[Vector2i]
) -> Vector2i:
	var bucket: Array[Vector2i] = primary
	if bucket.is_empty():
		bucket = fallback1
	if bucket.is_empty():
		bucket = fallback2
	if bucket.is_empty():
		return Vector2i(0, 0)

	return bucket[rng.randi_range(0, bucket.size() - 1)]


# ============================================================
#  SECTION: Small Helpers
# ============================================================

func _rand_int_inclusive(rng: RandomNumberGenerator, a: int, b: int) -> int:
	var lo: int = mini(a, b)
	var hi: int = maxi(a, b)
	return rng.randi_range(lo, hi)

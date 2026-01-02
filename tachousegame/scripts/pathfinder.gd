class_name Pathfinder
extends RefCounted

# ============================================================
#  FILE: pathfinder.gd
#  TYPE: RefCounted (utility class)
#
#  ROLE: A* pathfinding for characters
# ------------------------------------------------------------
#  Provides static pathfinding functions for characters to
#  navigate the tile-based map.
#
#  Features:
#    - A* algorithm with Manhattan distance heuristic
#    - Avoids unwalkable tiles (checks ground layer)
#    - Avoids occupied tiles (checks character layer)
#    - Optional: avoid enemies for RUN_AWAY behavior
#
#  Usage:
#    var path = Pathfinder.find_path(start, end, ground_layer, char_layer)
# ============================================================


# ============================================================
#  SECTION: A* Pathfinding
# ============================================================

static func find_path(
	start: Vector2i,
	end: Vector2i,
	ground_layer: TileMapLayer,
	character_layer: Node2D = null,
	friendly_team: int = -1
) -> Array[Vector2i]:
	"""
	Find path from start to end tile using A* algorithm.
	Returns array of tiles to walk through (excluding start, including end).
	Returns empty array if no path found.
	"""

	if ground_layer == null:
		return []

	# Quick check: start and end must have ground tiles
	if ground_layer.get_cell_source_id(start) == -1:
		return []
	if ground_layer.get_cell_source_id(end) == -1:
		return []

	# Same position
	if start == end:
		return []

	# A* data structures
	var open_set: Array[Vector2i] = [start]
	var came_from: Dictionary = {}  # tile -> previous tile
	var g_score: Dictionary = {start: 0}  # tile -> cost from start
	var f_score: Dictionary = {start: _heuristic(start, end)}  # tile -> estimated total cost

	while open_set.size() > 0:
		# Get tile with lowest f_score
		var current = _get_lowest_f_score(open_set, f_score)

		# Reached goal
		if current == end:
			return _reconstruct_path(came_from, current, start)

		open_set.erase(current)

		# Check all neighbors
		for neighbor in _get_neighbors(current):
			# Skip unwalkable tiles
			if not _is_walkable(neighbor, ground_layer, character_layer, end, friendly_team):
				continue

			var tentative_g_score = g_score[current] + 1

			# Found better path to neighbor
			if not neighbor in g_score or tentative_g_score < g_score[neighbor]:
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g_score
				f_score[neighbor] = tentative_g_score + _heuristic(neighbor, end)

				if not neighbor in open_set:
					open_set.append(neighbor)

	# No path found
	return []


static func find_path_avoiding_enemies(
	start: Vector2i,
	end: Vector2i,
	ground_layer: TileMapLayer,
	character_layer: Node2D,
	friendly_team: int,
	enemy_avoid_radius: int = 3
) -> Array[Vector2i]:
	"""
	Find path that avoids getting near enemies.
	Used for RUN_AWAY behavior.
	"""

	if ground_layer == null or character_layer == null:
		return []

	# Get all enemy positions
	var enemies = character_layer.get_enemies_of_team(friendly_team)
	var enemy_tiles: Array[Vector2i] = []
	for enemy in enemies:
		if enemy != null:
			enemy_tiles.append(enemy.current_tile)

	# Use modified A* that penalizes tiles near enemies
	# For simplicity, just use regular pathfinding for now
	# TODO: Add enemy avoidance cost to A* heuristic
	return find_path(start, end, ground_layer, character_layer)


# ============================================================
#  SECTION: A* Helper Functions
# ============================================================

static func _is_walkable(
	tile: Vector2i,
	ground_layer: TileMapLayer,
	character_layer: Node2D,
	destination: Vector2i,
	friendly_team: int
) -> bool:
	"""Check if tile can be walked on"""

	# Must have ground tile
	if ground_layer.get_cell_source_id(tile) == -1:
		return false

	# Allow destination tile even if occupied (character will move there eventually)
	if tile == destination:
		return true

	# Check for friendly character occupation (avoid pathing through friendlies)
	if character_layer != null and friendly_team >= 0:
		var chars_at_tile = character_layer.get_characters_at_tile(tile)
		for char in chars_at_tile:
			if char != null and char.get_team() == friendly_team:
				# Tile occupied by friendly - avoid it
				return false

	return true


static func _get_neighbors(tile: Vector2i) -> Array[Vector2i]:
	"""Get 4 adjacent tiles (no diagonals for now)"""
	var neighbors: Array[Vector2i] = []

	# Cardinal directions only
	neighbors.append(tile + Vector2i(1, 0))   # Right
	neighbors.append(tile + Vector2i(-1, 0))  # Left
	neighbors.append(tile + Vector2i(0, 1))   # Down
	neighbors.append(tile + Vector2i(0, -1))  # Up

	return neighbors


static func _heuristic(from: Vector2i, to: Vector2i) -> int:
	"""Manhattan distance heuristic for A*"""
	return abs(to.x - from.x) + abs(to.y - from.y)


static func _get_lowest_f_score(open_set: Array[Vector2i], f_score: Dictionary) -> Vector2i:
	"""Get tile with lowest f_score from open_set"""
	var lowest = open_set[0]
	var lowest_score = f_score.get(lowest, 999999)

	for tile in open_set:
		var score = f_score.get(tile, 999999)
		if score < lowest_score:
			lowest = tile
			lowest_score = score

	return lowest


static func _reconstruct_path(came_from: Dictionary, current: Vector2i, start: Vector2i) -> Array[Vector2i]:
	"""Reconstruct path from came_from map"""
	var path: Array[Vector2i] = [current]

	while current in came_from:
		current = came_from[current]
		if current == start:
			break
		path.insert(0, current)

	return path

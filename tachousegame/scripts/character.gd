class_name Character
extends Area2D

# ============================================================
#  Universal Fields (from CharacterClassDocs.txt)
# ============================================================

@export var max_health: int = 100:
	set(value):
		max_health = max(value, 1)
		if health > max_health:
			health = max_health

var speed: int = 1  # tiles per second movement speed
var health: int = 100
var team: int = 0:
	set(value):
		team = clamp(value, 0, 3)

var id: int = -1
var character_type: String = "Pawn"
var mission_complete: bool = false  # false = going to mission, true = returning
var vision: int = 1  # tiles around character (1 = 3x3 square)

# ============================================================
#  Map Integration References
# ============================================================

var map: Node = null
var character_layer: Node2D = null
var ground_layer: TileMapLayer = null

# ============================================================
#  Position & Navigation
# ============================================================

var current_tile: Vector2i = Vector2i(0, 0)
var current_chunk: Vector2i = Vector2i(0, 0)
var target_chunk: Vector2i = Vector2i(-1, -1)
var base_chunk: Vector2i = Vector2i(0, 0)

var path: Array[Vector2i] = []
var path_index: int = 0
var is_moving: bool = false
var move_timer: float = 0.0

# ============================================================
#  Behavior System - Enums
# ============================================================

enum TravelBehavior {
	TRAVEL,      # Path to target chunk
	FIGHT,       # Engage enemies encountered
	COIN,        # Collect coins along the way
	RUN_AWAY     # Flee to base when enemies near
}

enum MissionBehavior {
	DONE,   # Complete mission and return
	FIGHT,  # Fight enemies in chunk
	COIN,   # Collect coins in chunk
	BUILD   # Build structures
}

# ============================================================
#  Behavior Queues (Override in child classes)
# ============================================================

var traveling_behaviors: Array[TravelBehavior] = [TravelBehavior.TRAVEL]
var mission_behaviors: Array[MissionBehavior] = [MissionBehavior.DONE]

# ============================================================
#  State Management
# ============================================================

var is_at_mission_chunk: bool = false
var fleeing: bool = false
var is_selected: bool = false

# Vision tracking
var seen_enemies: Array[Character] = []
var seen_coins: Array[Vector2i] = []

# ============================================================
#  Initialization
# ============================================================

func _ready() -> void:
	health = max_health

# ============================================================
#  Main Process Loop
# ============================================================

func _process(delta: float) -> void:
	if not is_moving:
		return

	# Scan surroundings
	_scan_vision()

	# Execute behaviors
	_update_behavior()

	# Move along path
	_update_movement(delta)

# ============================================================
#  Spawning
# ============================================================

func spawn_at_base(team_id: int, character_id: int, spawn_chunk: Vector2i, map_node: Node, spawn_tile_override: Vector2i = Vector2i(-1, -1)) -> void:
	"""Spawn character at team's base chunk"""
	team = team_id
	id = character_id
	base_chunk = spawn_chunk
	current_chunk = spawn_chunk
	map = map_node

	# Get references
	if map != null:
		ground_layer = map.get_node_or_null(map.ground_layer_path) as TileMapLayer
		character_layer = map.get_node_or_null(map.character_layer_path) as Node2D

	# Use specific tile if provided, otherwise find one
	var spawn_tile: Vector2i
	if spawn_tile_override != Vector2i(-1, -1):
		spawn_tile = spawn_tile_override
	else:
		spawn_tile = _find_open_tile_in_chunk(base_chunk)

	if spawn_tile != Vector2i(-1, -1):
		current_tile = spawn_tile
		_update_visual_position()

	mission_complete = false
	is_at_mission_chunk = false

	print(character_type, " ", id, " spawned at chunk ", base_chunk, " tile ", current_tile)

# ============================================================
#  Player Commands
# ============================================================

func set_mission_target(chunk: Vector2i) -> void:
	"""Player assigns mission to this character"""
	target_chunk = chunk
	mission_complete = false
	is_at_mission_chunk = false
	fleeing = false

	_start_pathing_to_destination()
	print(character_type, " ", id, " mission assigned: chunk ", chunk)

func set_selected(selected: bool) -> void:
	"""Set selection state (shows/hides selection indicator)"""
	is_selected = selected

	# Toggle selection indicator
	var indicator = get_node_or_null("SelectionIndicator")
	if indicator != null:
		indicator.visible = selected

# ============================================================
#  Behavior Logic
# ============================================================

func _update_behavior() -> void:
	"""Execute behaviors based on current context"""

	if is_at_mission_chunk:
		_execute_mission_behaviors()
	else:
		_execute_traveling_behaviors()

func _execute_traveling_behaviors() -> void:
	"""Execute traveling behavior queue"""

	for behavior in traveling_behaviors:
		match behavior:
			TravelBehavior.TRAVEL:
				# Default - just keep pathing
				pass

			TravelBehavior.FIGHT:
				if _behavior_fight_traveling():
					return

			TravelBehavior.COIN:
				_behavior_coin_traveling()

			TravelBehavior.RUN_AWAY:
				if _behavior_run_away():
					return

func _execute_mission_behaviors() -> void:
	"""Execute mission behavior queue"""

	var all_complete = true

	for behavior in mission_behaviors:
		match behavior:
			MissionBehavior.DONE:
				# Will complete at end
				pass

			MissionBehavior.FIGHT:
				if not _behavior_fight_mission():
					all_complete = false

			MissionBehavior.COIN:
				if not _behavior_coin_mission():
					all_complete = false

			MissionBehavior.BUILD:
				_behavior_build()

	# All behaviors complete - return to base
	if all_complete and not mission_complete:
		print(character_type, " ", id, " mission complete! Returning to base.")
		mission_complete = true
		is_at_mission_chunk = false
		_start_pathing_to_destination()

# ============================================================
#  Traveling Behavior Implementations
# ============================================================

func _behavior_fight_traveling() -> bool:
	"""Fight enemies while traveling"""
	if seen_enemies.size() > 0:
		print(character_type, " ", id, " FIGHT! (traveling)")
		# TODO: Implement combat
		return false
	return false

func _behavior_coin_traveling() -> void:
	"""Collect coins while traveling"""
	for coin_tile in seen_coins:
		if _is_tile_on_path(coin_tile) or _is_tile_adjacent(coin_tile):
			_collect_coin(coin_tile)
			break

func _behavior_run_away() -> bool:
	"""Flee to base if enemies nearby"""
	if seen_enemies.size() > 0 and not fleeing:
		print(character_type, " ", id, " RUN AWAY!")
		fleeing = true
		mission_complete = true
		is_at_mission_chunk = false
		_start_pathing_to_destination()
		return true
	return false

# ============================================================
#  Mission Behavior Implementations
# ============================================================

func _behavior_fight_mission() -> bool:
	"""Fight enemies in mission chunk"""
	if seen_enemies.size() > 0:
		print(character_type, " ", id, " FIGHT! (mission)")
		# TODO: Implement combat
		return false  # Still enemies
	return true  # No enemies

func _behavior_coin_mission() -> bool:
	"""Collect coins in mission chunk"""
	if seen_coins.size() > 0:
		var coin_tile = seen_coins[0]
		if _is_tile_adjacent(coin_tile) or current_tile == coin_tile:
			_collect_coin(coin_tile)
		else:
			# Path to coin
			_path_to_tile(coin_tile)
		return false  # Still coins
	return true  # All collected

func _behavior_build() -> void:
	"""Build structure"""
	# TODO: Implement building
	print(character_type, " ", id, " BUILD!")

# ============================================================
#  Vision & Detection
# ============================================================

func _scan_vision() -> void:
	"""Scan tiles within vision range"""
	seen_enemies.clear()
	seen_coins.clear()

	if ground_layer == null:
		return

	# Scan tiles in vision radius
	for dy in range(-vision, vision + 1):
		for dx in range(-vision, vision + 1):
			var check_tile = current_tile + Vector2i(dx, dy)

			# Check for coins
			if _has_coin_at_tile(check_tile):
				seen_coins.append(check_tile)

			# Check for enemies
			var enemy = _get_enemy_at_tile(check_tile)
			if enemy != null:
				seen_enemies.append(enemy)

	# At mission chunk - scan entire chunk
	if is_at_mission_chunk:
		_scan_entire_chunk(current_chunk)

func _scan_entire_chunk(chunk: Vector2i) -> void:
	"""Scan entire chunk when at mission"""
	if ground_layer == null or map == null:
		return

	var chunk_size = map.chunk_size
	var base_tile = chunk * chunk_size

	for dy in range(chunk_size):
		for dx in range(chunk_size):
			var check_tile = base_tile + Vector2i(dx, dy)

			if _has_coin_at_tile(check_tile):
				if not check_tile in seen_coins:
					seen_coins.append(check_tile)

			var enemy = _get_enemy_at_tile(check_tile)
			if enemy != null and not enemy in seen_enemies:
				seen_enemies.append(enemy)

func _has_coin_at_tile(tile: Vector2i) -> bool:
	"""Check if coin exists at tile"""
	if map == null:
		return false

	var coin_layer = map.get_node_or_null(map.coin_layer_path) as TileMapLayer
	if coin_layer == null:
		return false

	return coin_layer.get_cell_source_id(tile) != -1

func _get_enemy_at_tile(tile: Vector2i) -> Character:
	"""Get enemy character at tile"""
	if character_layer == null:
		return null

	return character_layer.get_enemy_at_tile(tile, team)

# ============================================================
#  Pathfinding & Movement
# ============================================================

func _start_pathing_to_destination() -> void:
	"""Calculate path to current destination"""
	var destination_chunk = base_chunk if mission_complete else target_chunk
	var destination_tile = _get_chunk_center_tile(destination_chunk)

	_path_to_tile(destination_tile)

func _path_to_tile(destination: Vector2i) -> void:
	"""Calculate A* path to destination"""
	if ground_layer == null:
		return

	path = Pathfinder.find_path(current_tile, destination, ground_layer, character_layer)
	path_index = 0
	is_moving = path.size() > 0
	move_timer = 0.0

	if path.size() == 0 and current_tile != destination:
		print(character_type, " ", id, " no path to ", destination)

func _update_movement(delta: float) -> void:
	"""Move along path tile by tile"""
	if path.size() == 0 or path_index >= path.size():
		_on_path_complete()
		return

	# Move at speed (tiles per second)
	move_timer += delta * speed

	if move_timer >= 1.0:
		move_timer -= 1.0

		# Move to next tile
		current_tile = path[path_index]
		_update_visual_position()
		_update_current_chunk()
		path_index += 1

		# Check if path complete
		if path_index >= path.size():
			_on_path_complete()

func _on_path_complete() -> void:
	"""Called when path finishes"""
	is_moving = false
	path.clear()
	path_index = 0

	# Reached mission chunk
	if not mission_complete and current_chunk == target_chunk:
		_on_reach_mission_chunk()

	# Returned to base
	elif mission_complete and current_chunk == base_chunk:
		_on_return_to_base()

func _on_reach_mission_chunk() -> void:
	"""Called when entering mission chunk"""
	print(character_type, " ", id, " reached mission chunk ", target_chunk)
	is_at_mission_chunk = true
	fleeing = false
	_scan_entire_chunk(current_chunk)

func _on_return_to_base() -> void:
	"""Called when returning to base"""
	print(character_type, " ", id, " returned to base")
	is_at_mission_chunk = false
	mission_complete = false
	fleeing = false
	target_chunk = Vector2i(-1, -1)

	# Find rest position
	var rest_tile = _find_open_tile_in_chunk(base_chunk)
	if rest_tile != Vector2i(-1, -1) and rest_tile != current_tile:
		_path_to_tile(rest_tile)

# ============================================================
#  Position Management
# ============================================================

func _update_current_chunk() -> void:
	"""Update chunk based on current tile"""
	if map == null:
		return

	var chunk_size = map.chunk_size
	current_chunk = Vector2i(
		int(floor(float(current_tile.x) / float(chunk_size))),
		int(floor(float(current_tile.y) / float(chunk_size)))
	)

func _update_visual_position() -> void:
	"""Update Area2D position to match tile"""
	if ground_layer == null:
		return

	var world_pos = ground_layer.map_to_local(current_tile)
	global_position = ground_layer.to_global(world_pos)

func _get_chunk_center_tile(chunk: Vector2i) -> Vector2i:
	"""Get center tile of chunk"""
	if map == null:
		return Vector2i(0, 0)

	var chunk_size = map.chunk_size
	var base = chunk * chunk_size
	return base + Vector2i(chunk_size / 2, chunk_size / 2)

func _find_open_tile_in_chunk(chunk: Vector2i) -> Vector2i:
	"""Find walkable tile in chunk"""
	if ground_layer == null or map == null:
		return Vector2i(-1, -1)

	var chunk_size = map.chunk_size
	var base = chunk * chunk_size

	# Try center first
	var center = base + Vector2i(chunk_size / 2, chunk_size / 2)
	if _is_tile_walkable(center):
		return center

	# Search chunk
	for dy in range(chunk_size):
		for dx in range(chunk_size):
			var tile = base + Vector2i(dx, dy)
			if _is_tile_walkable(tile):
				return tile

	return Vector2i(-1, -1)

func _is_tile_walkable(tile: Vector2i) -> bool:
	"""Check if tile is walkable"""
	if ground_layer == null:
		return false

	return ground_layer.get_cell_source_id(tile) != -1

# ============================================================
#  Coin Collection
# ============================================================

func _collect_coin(coin_tile: Vector2i) -> void:
	"""Collect coin at tile"""
	if map == null:
		return

	var coin_layer = map.get_node_or_null(map.coin_layer_path) as TileMapLayer
	if coin_layer == null or not coin_layer.has_method("collect_coin"):
		return

	var amount = int(coin_layer.call("collect_coin", coin_tile))
	if amount > 0:
		print(character_type, " ", id, " collected ", amount, " coins at ", coin_tile)
		seen_coins.erase(coin_tile)

# ============================================================
#  Combat
# ============================================================

func take_damage(amount: int) -> void:
	"""Take damage"""
	health -= amount
	print(character_type, " ", id, " took ", amount, " damage. Health: ", health, "/", max_health)

	if health <= 0:
		_die()

func _die() -> void:
	"""Character dies"""
	print(character_type, " ", id, " died!")
	if character_layer != null:
		character_layer.kill_character(id)

# ============================================================
#  Helper Functions
# ============================================================

func _is_tile_adjacent(tile: Vector2i) -> bool:
	"""Check if tile is adjacent"""
	var dist = current_tile - tile
	return abs(dist.x) <= 1 and abs(dist.y) <= 1

func _is_tile_on_path(tile: Vector2i) -> bool:
	"""Check if tile is on current path"""
	return tile in path

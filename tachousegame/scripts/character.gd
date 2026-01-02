class_name Character
extends Area2D

# ============================================================
# Character Fields 
# ============================================================

#Stats
@export var max_health: int = 100:
	set(value):
		max_health = max(value, 1)
		if current_health > max_health:
			current_health = max_health
var current_health: int = max_health
@export var speed: int = 5  # tiles per second movement speed
var move_timer: float = 0.0 # += delta * speed. When =< 1.0 Character Moves

#Id
var id: int = -1
var team: int = 0: # each number is a different team
	set(value):
		team = clamp(value, 0, 3)
var character_type: String = "char"

#Parents
var map: Node = null
var character_layer: Node2D = null
var ground_layer: TileMapLayer = null

#Location
var current_tile: Vector2i = Vector2i(0, 0)
var current_chunk: Vector2i = Vector2i(0, 0)
var target_chunk: Vector2i = Vector2i(-1, -1)
var base_chunk: Vector2i = Vector2i(0, 0)

#Movement
var path: Array[Vector2i] = []
var path_index: int = 0

#State
var current_state: State = null

var is_traveling: bool = false
var mission_complete: bool = false  # Start true (idle at base)
var is_selected: bool = false

var interruptBehaviorList: Array[State] = []    # Checked first always
var missionBehaviorList: Array[State] = []      # Checked when at mission
var travelBehaviorList: Array[State] = []       # Checked when traveling/idle

#Vision
@export var vision: int = 1  # tiles around character (1 = 3x3 square)
var seen_enemies: Array[Character] = []
var seen_coins: Array[Vector2i] = []

# ============================================================
#  Initialization
# ============================================================

func _ready() -> void:
	current_health = max_health

	# Initialize behavior lists
	_initialize_behavior_lists()

	# Assign random pawn sprite (1-4)
	_assign_random_pawn_sprite()

func _initialize_behavior_lists() -> void:
	"""Set up behavior lists with state instances"""

	missionBehaviorList.append(MissionCompleteState.new(self))  # Fallback

	# Travel behaviors (checked when traveling or idle)
	travelBehaviorList.append(TravelState.new(self))
	travelBehaviorList.append(IdleState.new(self))

func _assign_random_pawn_sprite() -> void:
	"""Randomly assign one of the 4 pawn sprites on initialization"""
	var pawn_sprites: Array[String] = [
		"res://assets/PAWNS/pawn1.png",
		"res://assets/PAWNS/pawn2.png",
		"res://assets/PAWNS/pawn3.png",
		"res://assets/PAWNS/pawn4.png"
	]

	# Randomly select one of the 4 pawn sprites
	var random_index = randi_range(0, 3)
	var selected_sprite_path = pawn_sprites[random_index]

	# Load and assign the texture
	var sprite_node = get_node_or_null("Sprite2D") as Sprite2D
	if sprite_node != null:
		sprite_node.texture = load(selected_sprite_path)
		DebugUtils.dprint(str(character_type) + " " + str(id) + " assigned sprite: pawn" + str(random_index + 1))

# ============================================================
#  Main Process Loop
# ============================================================

func _process(delta: float) -> void:
	# Scan surroundings
	_scan_vision()

	# Execute behaviors (states handle their own logic including movement)
	_update_behavior(delta)

# ============================================================
#  Spawning 
#  TODO: spawn at team specific chunks.
# ============================================================

func spawn_at_base(team_id: int, character_id: int, spawn_chunk: Vector2i, map_node: Node, spawn_tile_override: Vector2i = Vector2i(-1, -1)) -> void:
	"""Spawns Character at Top most chunk"""
	#
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

	DebugUtils.dprint(str(character_type) + " " + str(id) + " spawned at chunk " + str(base_chunk) + " tile " + str(current_tile))

# ============================================================
#  Player Commands
# ============================================================

func set_mission_target(chunk: Vector2i) -> void:
	"""Player assigns mission to this character (only when IDLE at base)"""

	# Only accept commands when IDLE at base
	if current_chunk != base_chunk or target_chunk != Vector2i(-1, -1):
		DebugUtils.dprint(str(character_type) + " " + str(id) + " cannot accept mission - not idle at base")
		return

	# Block new missions if already completed one (needs manual reset)
	if mission_complete:
		DebugUtils.dprint(str(character_type) + " " + str(id) + " cannot accept mission - already completed a mission")
		return

	# Set mission target
	target_chunk = chunk
	mission_complete = false

	DebugUtils.dprint(str(character_type) + " " + str(id) + " mission assigned: chunk " + str(chunk))

func set_selected(selected: bool) -> void:
	"""Set selection state (shows/hides selection indicator)"""
	is_selected = selected

	# Toggle selection indicator
	var indicator = get_node_or_null("SelectionIndicator")
	if indicator != null:
		indicator.visible = selected

# ============================================================
#  UI Integration - Getters
# ============================================================

func get_sprite() -> Sprite2D:
	"""Get character sprite node for UI"""
	return get_node_or_null("Sprite2D") as Sprite2D

func get_id() -> int:
	"""Get character ID"""
	return id

func get_type() -> String:
	"""Get character type"""
	return character_type

func get_team() -> int:
	"""Get character team"""
	return team

func get_mission_complete() -> bool:
	"""Get mission completion status"""
	return mission_complete

func get_current_chunk() -> Vector2i:
	"""Get current chunk position"""
	return current_chunk

func get_target_chunk() -> Vector2i:
	"""Get target chunk position"""
	return target_chunk

func get_base_chunk() -> Vector2i:
	"""Get base chunk position"""
	return base_chunk

func enable_mission_acceptance() -> void:
	"""Enable character to accept new missions (resets mission_complete flag)"""
	mission_complete = false

func is_idle_at_base() -> bool:
	"""Check if character is idle at their base"""
	return current_chunk == base_chunk and target_chunk == Vector2i(-1, -1) and mission_complete

# ============================================================
#  Behavior/State Logic
# ============================================================

func _update_behavior(delta: float) -> void:
	"""Check behavior lists and execute valid state"""

	# Step 1: Check interrupts first (always highest priority)
	for state in interruptBehaviorList:
		if state.is_valid():
			_transition_to_state(state, delta)
			return

	# Step 2: Check context-appropriate list
	var context_list: Array[State] = []

	# At mission chunk? Check mission behaviors
	if current_chunk == target_chunk and not mission_complete:
		context_list = missionBehaviorList
	else:
		# Otherwise check travel/idle behaviors
		context_list = travelBehaviorList

	# Step 3: Find first valid state in context list
	for state in context_list:
		if state.is_valid():
			_transition_to_state(state, delta)
			return

	# Step 4: No valid state found - this shouldn't happen
	# Keep current state if one exists
	if current_state != null:
		current_state.do(delta)

func _transition_to_state(new_state: State, delta: float) -> void:
	"""Transition to a new state"""
	# Check if we're changing states
	var is_new_state = (current_state != new_state)

	# Exit old state
	if current_state != null and is_new_state:
		current_state.on_exit()

	# Enter new state (only if different)
	if is_new_state:
		current_state = new_state
		current_state.on_enter()

	# Execute current state (always)
	current_state.do(delta)

# ============================================================
#  Vision & Detection
# ============================================================

func _scan_vision() -> void:
	"""Scan tiles within vision range """
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

func _scan_entire_chunk(chunk: Vector2i) -> void:
	"""
	Scans ALL tiles in a given chunk and appends found coins/enemies 
	to the character's vision lists.
	"""
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
	"""HELPER: Check if coin exists at tile"""
	if map == null:
		return false

	var coin_layer = map.get_node_or_null(map.coin_layer_path) as TileMapLayer
	if coin_layer == null:
		return false

	return coin_layer.get_cell_source_id(tile) != -1

func _get_enemy_at_tile(tile: Vector2i) -> Character:
	"""HELPER Get enemy character at tile"""
	if character_layer == null:
		return null

	return character_layer.get_enemy_at_tile(tile, team)

# ============================================================
#  Pathfinding & Movement Utilities
# ============================================================

func _path_to_tile(destination: Vector2i) -> void:
	"""Resets movement variables for new path"""
	if ground_layer == null:
		return

	# Pass team to pathfinder so it avoids friendly characters
	path = Pathfinder.find_path(current_tile, destination, ground_layer, character_layer, team)
	path_index = 0
	is_traveling = path.size() > 0
	move_timer = 0.0

	if path.size() == 0 and current_tile != destination:
		DebugUtils.dprint(str(character_type) + " " + str(id) + " no path to " + str(destination))

func _update_movement(delta: float) -> void:
	"""Move along path tile by tile"""
	if path.size() == 0 or path_index >= path.size():
		_on_path_complete()
		return

	# Move at speed (tiles per second)
	move_timer += delta * speed

	if move_timer >= 1.0:
		move_timer -= 1.0

		# Check if next tile is blocked by a friendly character
		var next_tile = path[path_index]
		if _is_tile_blocked_by_friendly(next_tile):
			# Recalculate path to avoid the blocking character
			var destination = path[path.size() - 1]  # Final destination
			_path_to_tile(destination)
			# Reset timer to give new path a moment
			move_timer = 0.5
			return

		# Move to next tile
		current_tile = path[path_index]
		_update_visual_position()
		_update_current_chunk()
		path_index += 1

		# Check if path complete
		if path_index >= path.size():
			_on_path_complete()

func _on_path_complete() -> void:
	"""Resets movement variables when path is complete"""
	is_traveling = false
	path.clear()
	path_index = 0

	# State system will handle transitions automatically

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

func _is_tile_blocked_by_friendly(tile: Vector2i) -> bool:
	"""Check if tile is currently blocked by a friendly character"""
	if character_layer == null:
		return false

	var chars_at_tile = character_layer.get_characters_at_tile(tile)
	for char in chars_at_tile:
		if char != null and char != self and char.get_team() == team:
			return true

	return false

# ============================================================
#  Combat
# ============================================================

func take_damage(amount: int) -> void:
	"""Take damage"""
	current_health -= amount
	DebugUtils.dprint(str(character_type) + " " + str(id) + " took " + str(amount) + " damage. Health: " + str(current_health) + "/" + str(max_health))

	if current_health <= 0:
		_die()

func _die() -> void:
	"""Character dies"""
	DebugUtils.dprint(str(character_type) + " " + str(id) + " died!")
	if character_layer != null:
		character_layer.kill_character(id)


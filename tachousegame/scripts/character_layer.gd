@tool
extends Node2D

# ============================================================
#  FILE: character_layer.gd
#  NODE: Character Layer (Node2D)
#
#  ROLE: Character manager (layer pattern)
# ------------------------------------------------------------
#  This Node2D manages all Character instances in the game.
#
#  Responsibilities:
#    - Track all spawned Character instances as children
#    - Manage character IDs (auto-increment)
#    - Handle character spawning at team corners
#    - Provide lookup by tile/chunk/team
#    - Handle player selection (single/multi-select)
#    - Called by Map.gd for character operations
#
#  Pattern follows:
#    - coin_layer.gd (manages coin state)
#    - grass_layer.gd (manages decorations)
#
#  Public API (called by Map.gd and Character.gd):
#    - setup(ground_layer, map_node)
#    - clear_characters()
#    - spawn_character(team, chunk) -> Character
#    - get_character_at_tile(tile) -> Character
#    - get_characters_in_chunk(chunk) -> Array[Character]
#    - get_enemies_of_team(team) -> Array[Character]
#    - set_selected_characters(chars)
#    - get_selected_characters() -> Array[Character]
#    - kill_character(id)
# ============================================================


# ============================================================
#  SECTION: References (Set by Map)
# ============================================================

var map: Node = null
var ground_layer: TileMapLayer = null


# ============================================================
#  SECTION: Character Tracking
# ============================================================

var characters: Dictionary = {}  # id -> Character
var next_character_id: int = 0


# ============================================================
#  SECTION: Selection State
# ============================================================

var selected_characters: Array[Character] = []


# ============================================================
#  SECTION: Team Spawn Locations
# ============================================================

var team_spawn_locations: Dictionary = {}  # team_id -> Array[Vector2i] (chunks)


# ============================================================
#  SECTION: Phase System
# ============================================================

enum Phase { PLANNING, EXECUTING, WAITING }
var current_phase: Phase = Phase.PLANNING
var team_completion_state: Dictionary = {}  # team_id -> bool (tracks previous completion state)


# ============================================================
#  SECTION: Signals
# ============================================================

signal phase_changed(new_phase: Phase)
signal team_completed(team_id: int)
signal all_teams_completed()
signal character_mission_assigned(char_id: int, target: Vector2i)
signal character_spawned(char_id: int, team: int)


# ============================================================
#  SECTION: Public API - Setup
# ============================================================

func setup(ground: TileMapLayer, map_node: Node) -> void:
	"""Called by Map.gd after layers are built"""
	ground_layer = ground
	map = map_node

	# Initialize default team spawn locations (corner chunks)
	_initialize_team_spawn_locations()

	# TEMP DEBUG: Spawn a test character
	if not Engine.is_editor_hint():
		call_deferred("_debug_spawn_test_character")


func _process(_delta: float) -> void:
	"""Monitor team completion and emit signals"""
	if Engine.is_editor_hint():
		return

	# Only monitor during EXECUTING phase
	if current_phase != Phase.EXECUTING:
		return

	# Check each team for completion state changes
	var teams = get_teams()
	for team in teams:
		var is_complete = is_team_complete(team)
		var was_complete = team_completion_state.get(team, false)

		# Team just became complete
		if is_complete and not was_complete:
			team_completion_state[team] = true
			team_completed.emit(team)
			DebugUtils.dprint("Character Layer: Team " + str(team) + " completed")

		# Update state
		team_completion_state[team] = is_complete

	# Check if all teams are complete
	if are_all_teams_complete() and characters.size() > 0:
		current_phase = Phase.WAITING
		all_teams_completed.emit()
		phase_changed.emit(Phase.WAITING)
		DebugUtils.dprint("Character Layer: All teams completed - entering WAITING phase")


# ============================================================
#  SECTION: Public API - Character Management
# ============================================================

func clear_characters() -> void:
	"""Remove all characters from the game"""
	for char in characters.values():
		if is_instance_valid(char):
			char.queue_free()

	characters.clear()
	selected_characters.clear()
	next_character_id = 0


func spawn_character(team: int, chunk: Vector2i, spawn_tile: Vector2i = Vector2i(-1, -1)) -> Character:
	"""Spawn a new character at the given team's chunk"""
	# Load character scene
	var char_scene = preload("res://scenes/Character.tscn")
	var char: Character = char_scene.instantiate()

	# Add to scene tree
	add_child(char)

	# Initialize character
	var char_id = next_character_id
	next_character_id += 1

	char.spawn_at_base(team, char_id, chunk, map, spawn_tile)

	# Track character
	characters[char_id] = char

	DebugUtils.dprint("Character Layer: Spawned character " + str(char_id) + " for team " + str(team) + " at chunk " + str(chunk))

	return char


func kill_character(char_id: int) -> void:
	"""Remove a character by ID (called when character dies)"""
	if not char_id in characters:
		return

	var char = characters[char_id]

	# Remove from tracking
	characters.erase(char_id)
	selected_characters.erase(char)

	# Remove from scene
	if is_instance_valid(char):
		char.queue_free()

	DebugUtils.dprint("Character Layer: Removed character " + str(char_id))


func create_characters(spawn_list: Array[Dictionary]) -> Array[int]:
	"""Create multiple characters from UI spawn list"""
	var created_ids: Array[int] = []

	for spawn_data in spawn_list:
		if not "team" in spawn_data or not "chunk" in spawn_data:
			DebugUtils.dprint("Character Layer: Invalid spawn data - missing team or chunk")
			continue

		var team: int = spawn_data["team"]
		var chunk: Vector2i = spawn_data["chunk"]

		var char = spawn_character(team, chunk)
		created_ids.append(char.get_id())

		# Emit signal for UI
		character_spawned.emit(char.get_id(), team)

	return created_ids


func create_team_characters(team: int, count: int) -> Array[int]:
	"""Spawn multiple characters for a team at their default spawn location"""
	var created_ids: Array[int] = []
	var spawn_chunk = get_default_spawn_for_team(team)

	for i in range(count):
		var char = spawn_character(team, spawn_chunk)
		created_ids.append(char.get_id())

		# Emit signal for UI
		character_spawned.emit(char.get_id(), team)

	DebugUtils.dprint("Character Layer: Created " + str(count) + " characters for team " + str(team))
	return created_ids


func assign_missions(mission_dict: Dictionary) -> Dictionary:
	"""Assign missions to characters from UI (dict of char_id -> target_chunk)"""
	var results: Dictionary = {}

	for char_id in mission_dict:
		var success = false
		var target_chunk: Vector2i = mission_dict[char_id]

		if char_id in characters:
			var char = characters[char_id]
			if is_instance_valid(char):
				char.set_mission_target(target_chunk)
				success = true

				# Emit signal for UI
				character_mission_assigned.emit(char_id, target_chunk)
		else:
			DebugUtils.dprint("Character Layer: Character " + str(char_id) + " not found for mission assignment")

		results[char_id] = success

	return results


# ============================================================
#  SECTION: Phase Control
# ============================================================

func start_planning_phase() -> void:
	"""Enter planning phase - enable characters to accept new missions"""
	current_phase = Phase.PLANNING

	# Enable all characters to accept new missions
	for char in characters.values():
		if is_instance_valid(char):
			char.enable_mission_acceptance()

	phase_changed.emit(Phase.PLANNING)
	DebugUtils.dprint("Character Layer: Entered PLANNING phase")


func start_execution_phase() -> void:
	"""Enter execution phase - characters can now move"""
	current_phase = Phase.EXECUTING
	phase_changed.emit(Phase.EXECUTING)
	DebugUtils.dprint("Character Layer: Entered EXECUTING phase")


# ============================================================
#  SECTION: Public API - Queries
# ============================================================

func get_character_at_tile(tile: Vector2i) -> Character:
	"""Get the character at a specific tile (for click selection)"""
	for char in characters.values():
		if not is_instance_valid(char):
			continue

		if char.current_tile == tile:
			return char

	return null


func get_characters_at_tile(tile: Vector2i) -> Array[Character]:
	"""Get all characters at a specific tile"""
	var result: Array[Character] = []

	for char in characters.values():
		if not is_instance_valid(char):
			continue

		if char.current_tile == tile:
			result.append(char)

	return result


func get_characters_in_chunk(chunk: Vector2i) -> Array[Character]:
	"""Get all characters in a specific chunk"""
	var result: Array[Character] = []

	for char in characters.values():
		if not is_instance_valid(char):
			continue

		if char.current_chunk == chunk:
			result.append(char)

	return result


func get_enemies_of_team(team: int) -> Array[Character]:
	"""Get all characters that are enemies of the given team"""
	var result: Array[Character] = []

	for char in characters.values():
		if not is_instance_valid(char):
			continue

		if char.team != team:
			result.append(char)

	return result


func get_enemy_at_tile(tile: Vector2i, friendly_team: int) -> Character:
	"""Get enemy character at tile (used by character vision)"""
	for char in characters.values():
		if not is_instance_valid(char):
			continue

		if char.current_tile == tile and char.team != friendly_team:
			return char

	return null


func get_character_info(char_id: int) -> Dictionary:
	"""Get character information as dictionary for UI"""
	if not char_id in characters:
		return {}

	var char = characters[char_id]
	if not is_instance_valid(char):
		return {}

	return {
		"id": char.get_id(),
		"team": char.get_team(),
		"type": char.get_type(),
		"current_chunk": char.get_current_chunk(),
		"base_chunk": char.get_base_chunk(),
		"target_chunk": char.get_target_chunk(),
		"mission_complete": char.get_mission_complete(),
		"is_idle": char.is_idle_at_base()
	}


func get_all_character_info() -> Array[Dictionary]:
	"""Get info for all characters as array of dictionaries"""
	var info_list: Array[Dictionary] = []

	for char_id in characters.keys():
		var info = get_character_info(char_id)
		if info.size() > 0:
			info_list.append(info)

	return info_list


func get_team_character_info(team: int) -> Array[Dictionary]:
	"""Get info for all characters of a specific team"""
	var info_list: Array[Dictionary] = []

	for char in characters.values():
		if not is_instance_valid(char):
			continue

		if char.get_team() == team:
			var info = get_character_info(char.get_id())
			if info.size() > 0:
				info_list.append(info)

	return info_list


# ============================================================
#  SECTION: Public API - Selection
# ============================================================

func set_selected_characters(chars: Array[Character]) -> void:
	"""Set which characters are currently selected"""
	# Deselect old
	for char in selected_characters:
		if is_instance_valid(char):
			char.set_selected(false)

	# Select new
	selected_characters = chars
	for char in selected_characters:
		if is_instance_valid(char):
			char.set_selected(true)


func get_selected_characters() -> Array[Character]:
	"""Get currently selected characters"""
	# Clean up invalid references
	selected_characters = selected_characters.filter(func(c): return is_instance_valid(c))
	return selected_characters


func clear_selection() -> void:
	"""Deselect all characters"""
	set_selected_characters([])


# ============================================================
#  SECTION: Helper Methods
# ============================================================

func get_character_by_id(char_id: int) -> Character:
	"""Get character by ID"""
	if char_id in characters:
		return characters[char_id]
	return null


func get_all_characters() -> Array[Character]:
	"""Get all active characters"""
	var result: Array[Character] = []
	for char in characters.values():
		if is_instance_valid(char):
			result.append(char)
	return result


# ============================================================
#  SECTION: Team Completion Checking
# ============================================================

func is_team_complete(team: int) -> bool:
	"""Check if all characters of a team have completed missions and returned to base"""
	for char in characters.values():
		if not is_instance_valid(char):
			continue

		if char.get_team() == team:
			if not char.is_idle_at_base():
				return false

	return true


func get_teams() -> Array[int]:
	"""Get list of unique team IDs currently in the game"""
	var teams: Array[int] = []

	for char in characters.values():
		if not is_instance_valid(char):
			continue

		var team = char.get_team()
		if not team in teams:
			teams.append(team)

	return teams


func are_all_teams_complete() -> bool:
	"""Check if all characters across all teams are complete"""
	if characters.size() == 0:
		return false

	for char in characters.values():
		if not is_instance_valid(char):
			continue

		if not char.is_idle_at_base():
			return false

	return true


# ============================================================
#  SECTION: Team Spawn Management
# ============================================================

func add_team_spawn_location(team: int, chunk: Vector2i) -> void:
	"""Add a spawn location for a team (supports multiple spawn points)"""
	if not team in team_spawn_locations:
		team_spawn_locations[team] = []

	if not chunk in team_spawn_locations[team]:
		team_spawn_locations[team].append(chunk)
		DebugUtils.dprint("Character Layer: Added spawn location " + str(chunk) + " for team " + str(team))


func get_team_spawn_locations(team: int) -> Array[Vector2i]:
	"""Get all spawn locations for a team"""
	if team in team_spawn_locations:
		return team_spawn_locations[team].duplicate()
	return []


func get_default_spawn_for_team(team: int) -> Vector2i:
	"""Get the primary/default spawn location for a team"""
	if team in team_spawn_locations and team_spawn_locations[team].size() > 0:
		return team_spawn_locations[team][0]

	# Fallback: return origin if no spawn location set
	DebugUtils.dprint("Character Layer: WARNING - No spawn location for team " + str(team))
	return Vector2i(0, 0)


func _initialize_team_spawn_locations() -> void:
	"""Initialize default team spawn locations based on corner chunks"""
	if map == null:
		return

	var map_size = map.map_size if "map_size" in map else 4

	# Team spawn locations match castle corner positions
	team_spawn_locations[0] = [Vector2i(0, 0)]  # Top-left
	team_spawn_locations[1] = [Vector2i(map_size - 1, 0)]  # Top-right
	team_spawn_locations[2] = [Vector2i(0, map_size - 1)]  # Bottom-left
	team_spawn_locations[3] = [Vector2i(map_size - 1, map_size - 1)]  # Bottom-right

	DebugUtils.dprint("Character Layer: Initialized team spawn locations for map size " + str(map_size))


# ============================================================
#  SECTION: Debug / Testing
# ============================================================

func _debug_spawn_test_character() -> void:
	"""TEMP: Spawn two test characters for team 0 with different missions"""
	DebugUtils.dprint("Character Layer: Spawning 2 debug test characters for team 0")

	if map == null:
		return

	var map_size = map.map_size if "map_size" in map else 4

	# Spawn character 1 at team 0's base (0,0)
	var char1 = spawn_character(0, Vector2i(0, 0))

	# Spawn character 2 at team 0's base (0,0)
	var char2 = spawn_character(0, Vector2i(0, 0))

	# Character 1: Target center chunk
	var center_chunk = Vector2i(map_size / 2, map_size / 2)
	char1.enable_mission_acceptance()
	char1.set_mission_target(center_chunk)
	DebugUtils.dprint("Character " + str(char1.get_id()) + " targeting center chunk " + str(center_chunk))

	# Character 2: Target random edge chunk
	var edge_chunks = [
		Vector2i(0, map_size / 2),  # Left edge
		Vector2i(map_size - 1, map_size / 2),  # Right edge
		Vector2i(map_size / 2, 0),  # Top edge
		Vector2i(map_size / 2, map_size - 1)  # Bottom edge
	]
	var random_edge_chunk = edge_chunks.pick_random()
	char2.enable_mission_acceptance()
	char2.set_mission_target(random_edge_chunk)
	DebugUtils.dprint("Character " + str(char2.get_id()) + " targeting edge chunk " + str(random_edge_chunk))

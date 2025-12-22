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

var characters: Array[Character] = []
var characters_by_id: Dictionary = {}  # id -> Character
var next_character_id: int = 0


# ============================================================
#  SECTION: Selection State
# ============================================================

var selected_characters: Array[Character] = []


# ============================================================
#  SECTION: Public API - Setup
# ============================================================

func setup(ground: TileMapLayer, map_node: Node) -> void:
	"""Called by Map.gd after layers are built"""
	ground_layer = ground
	map = map_node

	# TEMP DEBUG: Spawn a test character
	# Remove this after Phase 2 testing
	if not Engine.is_editor_hint():
		call_deferred("_debug_spawn_test_character")


# ============================================================
#  SECTION: Public API - Character Management
# ============================================================

func clear_characters() -> void:
	"""Remove all characters from the game"""
	for char in characters:
		if is_instance_valid(char):
			char.queue_free()

	characters.clear()
	characters_by_id.clear()
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
	characters.append(char)
	characters_by_id[char_id] = char

	print("Character Layer: Spawned character ", char_id, " for team ", team, " at chunk ", chunk)

	return char


func kill_character(char_id: int) -> void:
	"""Remove a character by ID (called when character dies)"""
	if not char_id in characters_by_id:
		return

	var char = characters_by_id[char_id]

	# Remove from tracking
	characters.erase(char)
	characters_by_id.erase(char_id)
	selected_characters.erase(char)

	# Remove from scene
	if is_instance_valid(char):
		char.queue_free()

	print("Character Layer: Removed character ", char_id)


# ============================================================
#  SECTION: Public API - Queries
# ============================================================

func get_character_at_tile(tile: Vector2i) -> Character:
	"""Get the character at a specific tile (for click selection)"""
	for char in characters:
		if not is_instance_valid(char):
			continue

		if char.current_tile == tile:
			return char

	return null


func get_characters_at_tile(tile: Vector2i) -> Array[Character]:
	"""Get all characters at a specific tile"""
	var result: Array[Character] = []

	for char in characters:
		if not is_instance_valid(char):
			continue

		if char.current_tile == tile:
			result.append(char)

	return result


func get_characters_in_chunk(chunk: Vector2i) -> Array[Character]:
	"""Get all characters in a specific chunk"""
	var result: Array[Character] = []

	for char in characters:
		if not is_instance_valid(char):
			continue

		if char.current_chunk == chunk:
			result.append(char)

	return result


func get_enemies_of_team(team: int) -> Array[Character]:
	"""Get all characters that are enemies of the given team"""
	var result: Array[Character] = []

	for char in characters:
		if not is_instance_valid(char):
			continue

		if char.team != team:
			result.append(char)

	return result


func get_enemy_at_tile(tile: Vector2i, friendly_team: int) -> Character:
	"""Get enemy character at tile (used by character vision)"""
	for char in characters:
		if not is_instance_valid(char):
			continue

		if char.current_tile == tile and char.team != friendly_team:
			return char

	return null


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
	if char_id in characters_by_id:
		return characters_by_id[char_id]
	return null


func get_all_characters() -> Array[Character]:
	"""Get all active characters"""
	# Clean up invalid references
	characters = characters.filter(func(c): return is_instance_valid(c))
	return characters


# ============================================================
#  SECTION: Debug / Testing
# ============================================================

func _debug_spawn_test_character() -> void:
	"""TEMP: Spawn a test character for Phase 2 testing"""
	print("Character Layer: Spawning debug test character at tile (4,3)")

	# Spawn at chunk (0,0), tile (4,3)
	var char = spawn_character(0, Vector2i(0, 0), Vector2i(4, 3))

	# Wait a moment, then send on a mission
	await get_tree().create_timer(1.0).timeout

	print("Character Layer: Sending test character to chunk (1,1)")
	char.set_mission_target(Vector2i(1, 1))

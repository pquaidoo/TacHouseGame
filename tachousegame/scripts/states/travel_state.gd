class_name TravelState
extends State

# Track where we're currently pathing to
var current_destination: Vector2i = Vector2i(-1, -1)

func is_valid() -> bool:
	# Valid when have target and not there yet, or returning to base
	return character.target_chunk != Vector2i(-1, -1) \
	   and character.current_chunk != character.target_chunk

func do(delta: float) -> void:
	# Check if destination has changed while traveling
	var destination_chunk = character.base_chunk if character.mission_complete else character.target_chunk

	# If destination changed, start new path
	if destination_chunk != current_destination:
		current_destination = destination_chunk
		_start_pathing()

		var dest_name = "base" if character.mission_complete else "mission"
		DebugUtils.dprint(str(character.character_type) + " " + str(character.id) + " traveling to " + dest_name)

	# Handle movement (TravelState owns movement behavior)
	if character.is_traveling:
		character._update_movement(delta)

func on_enter() -> void:
	# Set the destination we're heading to
	current_destination = character.base_chunk if character.mission_complete else character.target_chunk

	# Always start pathing when entering this state (new mission or returning home)
	_start_pathing()

	# Log where we're going
	var destination = "base" if character.mission_complete else "mission"
	DebugUtils.dprint(str(character.character_type) + " " + str(character.id) + " traveling to " + destination)

func _start_pathing() -> void:
	"""TravelState-specific logic: Determine where to path and initiate"""
	# Convert chunk to tile position
	var destination_tile = character._get_chunk_center_tile(current_destination)

	# Use Character's pathfinding utility
	character._path_to_tile(destination_tile)
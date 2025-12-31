class_name IdleState
extends State

func is_valid() -> bool:
	# Valid when at base (either already idle or just returned)
	return character.current_chunk == character.base_chunk \
	   and character.mission_complete

func do(_delta: float) -> void:
	# Do nothing, waiting for player command
	pass

func on_enter() -> void:
	# Clear mission data when becoming idle
	character.target_chunk = Vector2i(-1, -1)
	character.mission_complete = true
	DebugUtils.dprint(str(character.character_type) + " " + str(character.id) + " is idle at base")
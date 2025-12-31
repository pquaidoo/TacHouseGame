class_name ArrivedAtMissionState
extends State

func is_valid() -> bool:
	# Valid when just arrived at mission chunk
	return character.current_chunk == character.target_chunk \
	   and not character.mission_complete \
	   and character.target_chunk != character.base_chunk

func do(delta: float) -> void:
	# Scan happens in on_enter, state machine will switch to mission list
	pass

func on_enter() -> void:
	DebugUtils.dprint(str(character.character_type) + " " + str(character.id) + " arrived at mission chunk")
	character._scan_entire_chunk(character.current_chunk)
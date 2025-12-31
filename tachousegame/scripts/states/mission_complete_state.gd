class_name MissionCompleteState
extends State

func is_valid() -> bool:
	# Valid when at mission with no other tasks
	# This is the fallback for missionBehaviorList
	return character.current_chunk == character.target_chunk \
	   and not character.mission_complete

func do(_delta: float) -> void:
	# Completion handled in on_enter
	pass

func on_enter() -> void:
	DebugUtils.dprint(str(character.character_type) + " " + str(character.id) + " mission complete! Returning to base.")
	character.mission_complete = true
	character.target_chunk = character.base_chunk
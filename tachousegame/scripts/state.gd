class_name State
extends RefCounted

var character: Character

func _init(char: Character) -> void:
	character = char

func is_valid() -> bool:
	# Override: Return true if this state should activate
	return false

func do(_delta: float) -> void:
	# Override: Execute state behavior
	pass

func on_enter() -> void:
	# Override: Called when entering this state
	pass

func on_exit() -> void:
	# Override: Called when exiting this state
	pass
@tool
extends Area2D

@export var chunk_size: int = 5:
	set(value):
		chunk_size = max(value, 3)
		_request_rebuild()

@export var map_size: int = 7:
	set(value):
		map_size = max(value, 1)
		_request_rebuild()

@export var seed: int = 12345:
	set(value):
		seed = value
		_request_rebuild()

@export var ground_layer_path: NodePath
@export var grass_layer_path: NodePath

func _ready() -> void:
	rebuild()

func rebuild() -> void:
	var ground := get_node_or_null(ground_layer_path) as TileMapLayer
	var grass := get_node_or_null(grass_layer_path) as TileMapLayer

	if ground == null:
		return

	ground.chunk_size = chunk_size
	ground.map_size = map_size
	ground.rebuild()

	# Grass paints over whatever ground created
	if grass != null and grass.has_method("rebuild_from_ground"):
		grass.rebuild_from_ground(ground, seed)

func _request_rebuild() -> void:
	if Engine.is_editor_hint():
		call_deferred("rebuild")

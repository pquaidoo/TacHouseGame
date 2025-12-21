@tool
extends Area2D


# Map owns the "settings" (single source of truth)
@export var chunk_size: int = 5:
	set(value):
		chunk_size = max(value, 5)
		_request_rebuild()

@export var map_size: int = 2:
	set(value):
		map_size = max(value, 1)
		_request_rebuild()


# get access to node?
@export var ground_layer_path: NodePath
@onready var ground_layer: TileMapLayer = get_node_or_null(ground_layer_path)


func _ready() -> void:
	rebuild()
	
	
func rebuild() -> void:
	# Avoid null crashes in editor if path not set yet
	if ground_layer == null:
		push_error("Map.gd: ground_layer_path not set or Ground Layer not found.")
		return
		
	# Tell the layer what settings to use (Map -> Layer)
	ground_layer.chunk_size = chunk_size
	ground_layer.map_size = map_size

	# Ask the layer to draw itself
	if ground_layer.has_method("rebuild"):
		ground_layer.rebuild()


func _request_rebuild() -> void:
	# In editor, rebuild safely after property change
	if Engine.is_editor_hint():
		call_deferred("rebuild")

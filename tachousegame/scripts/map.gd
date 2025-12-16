@tool
extends Node2D

@export var chunk_scene: PackedScene          # drag Chunk.tscn here
@export var chunks_xy: Vector2i = Vector2i(3, 3)
@export var chunk_size: int = 8               # passed into chunk
@export var spacing_px: Vector2 = Vector2(300, 300) # TEMP: distance between chunks

@export var rebuild_now := false:
	set(_v):
		rebuild_now = false
		rebuild()

func _ready() -> void:
	rebuild()

func rebuild() -> void:
	_clear_children()

	if chunk_scene == null:
		push_error("Map: Assign Chunk.tscn to chunk_scene.")
		return

	for cy in range(chunks_xy.y):
		for cx in range(chunks_xy.x):
			var chunk := chunk_scene.instantiate()
			add_child(chunk)

			# pass size into the chunk (must exist on the chunk script)
			chunk.chunk_size = chunk_size

			# build tiles (your chunk script's public method)
			chunk.rebuild()

			# TEMP positioning (not iso): easy to debug
			if chunk is Node2D:
				(chunk as Node2D).position = Vector2(cx * spacing_px.x, cy * spacing_px.y)
			else:
				push_error("Chunk root is not Node2D/Node2D-like; can't position it.")

func _clear_children() -> void:
	for c in get_children():
		c.queue_free()

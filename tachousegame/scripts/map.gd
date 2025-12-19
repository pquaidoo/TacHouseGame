extends Node2D


# 1142, 648
@export var ChunkScene: PackedScene
@export var chunk_pixel_size_horiz := 160  # TEMP, adjust later
@export var chunk_pixel_size_verti := 80  # TEMP, adjust later
const X_CENTER = 1152 / 2
const Y_CENTER = 648 / 2


const CHUNK = preload("res://scenes/Chunk.tscn")

func _ready():
	
	var chunk_a = ChunkScene.instantiate()
	add_child(chunk_a)
	chunk_a.position = Vector2(X_CENTER, Y_CENTER)

	var chunk_b = ChunkScene.instantiate()
	add_child(chunk_b)
	chunk_b.position = Vector2(X_CENTER - chunk_pixel_size_horiz / 2, Y_CENTER - chunk_pixel_size_verti / 2)

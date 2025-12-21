extends Node2D

# ============================================================
#  ChunkHighlight
# ------------------------------------------------------------
#  This node only draws a hover/selection outline (and optional fill)
#  given 4 corner points in its LOCAL space.
#
#  Map computes those points and calls:
#    - set_points([p0, p1, p2, p3])
#    - clear()
#
#  Rendering priority:
#    - Put this node AFTER tile layers in the scene tree
#    - Give it a high z_index so it draws on top
# ============================================================

@export var enabled: bool = true

@export_range(0.0, 1.0, 0.01) var fill_alpha: float = 0.0
@export_range(0.0, 1.0, 0.01) var outline_alpha: float = 0.85
@export var outline_width: float = 2.0

# Optional: force draw order in code (you can also set this in the editor)
@export var highlight_z_index: int = 100

var points: PackedVector2Array = PackedVector2Array()

func _ready() -> void:
	z_index = highlight_z_index

func set_points(p: Array) -> void:
	points = PackedVector2Array(p)
	queue_redraw()


func clear() -> void:
	points = PackedVector2Array()
	queue_redraw()

func _draw() -> void:
	if not enabled:
		return
	if points.size() != 4:
		return

	# Optional fill
	if fill_alpha > 0.0:
		draw_colored_polygon(points, Color(1, 1, 0, fill_alpha))

	# Outline (close the loop)
	var loop: PackedVector2Array = PackedVector2Array([
		points[0], points[1], points[2], points[3], points[0]
	])
	draw_polyline(loop, Color(1, 1, 0, outline_alpha), outline_width)

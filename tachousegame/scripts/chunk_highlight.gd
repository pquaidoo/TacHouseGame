extends Node2D

# ============================================================
#  FILE: chunk_highlight.gd
#  NODE: ChunkHighlight (Node2D)
#
#  ROLE: “Dumb” highlight renderer (hover / selection visuals)
# ------------------------------------------------------------
#  This node does NOT know what a “chunk” is.
#  It does NOT read the mouse.
#  It does NOT inspect TileMaps.
#
#  It only draws a shape (outline + optional fill) using 4 points
#  that are provided by some controller (Map.gd).
#
#
#  INPUT CONTRACT (IMPORTANT)
#  ------------------------------------------------------------
#  The controller should call:
#    - set_points([p0, p1, p2, p3])
#      where p0..p3 are Vector2 positions in THIS NODE’S LOCAL SPACE.
#    - set_visible_chunk(false) (or clear()) to hide the highlight
#
#  Expected shape:
#    - points must represent a quad (4 corners in order around the shape)
#    - (p0 -> p1 -> p2 -> p3) should trace the boundary consistently
#
#
#  DRAW ORDER / PRIORITY
#  ------------------------------------------------------------
#  This node should render above tile layers. Two requirements:
#    1) Place ChunkHighlight AFTER TileMapLayers in the scene tree
#    2) Set a high z_index (either in editor or via highlight_z_index)
#
#  ISOMETRIC NOTE (Y OFFSET)
#  ------------------------------------------------------------
#  In isometric TileMaps, TileMapLayer.map_to_local(cell) typically returns
#  an anchor point that is slightly BELOW the visible top edge of the tile.
#  That can make outlines look “too low” by a few pixels.
#
#  We solve this at the RENDERING layer by applying a small screen-space
#  vertical offset to all points before drawing.
# ============================================================


# ============================================================
#  SECTION: Appearance Settings
# ============================================================

@export var enabled: bool = true

# Fill inside the quad. Set to 0.0 for “outline only”.
@export_range(0.0, 1.0, 0.01) var fill_alpha: float = 0.0

# Outline opacity + thickness.
@export_range(0.0, 1.0, 0.01) var outline_alpha: float = 0.85
@export var outline_width: float = 2.0

# Highlight color (RGB). Alpha is controlled by fill_alpha/outline_alpha.
@export var highlight_color: Color = Color(1, 1, 0)

# z_index used to keep this node on top of map layers.
@export var highlight_z_index: int = 100

# ============================================================
#  SECTION: Isometric Visual Correction (Y Offset)
# ------------------------------------------------------------
#  vertical_offset_px:
#    - Applied to all points RIGHT BEFORE drawing.
#    - Negative values move the highlight UP.
#    - Typical values for 32x16 iso tiles: -4 to -10
#
#  Keep this here (rendering) instead of Map.gd so that:
#    - chunk math stays correct
#    - only the visual is adjusted
# ============================================================

@export var vertical_offset_px: float = -6.0


# ============================================================
#  SECTION: Runtime State
# ============================================================

# When false, we render nothing even if points exist.
# This is the “nice API” toggle for the controller.
var _visible_chunk: bool = true

# Exactly 4 points (or empty when hidden).
var points: PackedVector2Array = PackedVector2Array()


# ============================================================
#  SECTION: Lifecycle
# ============================================================

func _ready() -> void:
	z_index = highlight_z_index


# ============================================================
#  SECTION: Public API (called by Map.gd)
# ============================================================

# Toggle highlight visibility without forcing the controller to manage arrays.
func set_visible_chunk(visible: bool) -> void:
	_visible_chunk = visible
	queue_redraw()

# Controller provides the quad corners.
# Accepts untyped Array because Map uses hl.call(...) and Godot is strict
# about typed arrays through call().
func set_points(p: Array) -> void:
	points = PackedVector2Array(p)
	_visible_chunk = true  # IMPORTANT: re-enable after a clear()
	queue_redraw()

# Convenience: hide + clear.
func clear() -> void:
	points = PackedVector2Array()
	_visible_chunk = false
	queue_redraw()


# ============================================================
#  SECTION: Rendering
# ============================================================

func _draw() -> void:
	if not enabled:
		return
	if not _visible_chunk:
		return
	if points.size() != 4:
		return

	# Apply a small vertical correction for isometric visuals.
	# (Negative moves up.)
	var offset: Vector2 = Vector2(0.0, vertical_offset_px)

	# Optional fill
	if fill_alpha > 0.0:
		var filled: PackedVector2Array = PackedVector2Array([
			points[0] + offset,
			points[1] + offset,
			points[2] + offset,
			points[3] + offset,
		])
		draw_colored_polygon(
			filled,
			Color(highlight_color.r, highlight_color.g, highlight_color.b, fill_alpha)
		)

	# Outline (closed loop)
	var loop: PackedVector2Array = PackedVector2Array([
		points[0] + offset,
		points[1] + offset,
		points[2] + offset,
		points[3] + offset,
		points[0] + offset,
	])
	draw_polyline(
		loop,
		Color(highlight_color.r, highlight_color.g, highlight_color.b, outline_alpha),
		outline_width
	)

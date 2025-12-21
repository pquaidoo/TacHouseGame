@tool
extends Area2D

# ============================================================
#  MAP CONTROLLER (Editor + Runtime)
# ------------------------------------------------------------
#  This node does NOT draw tiles itself.
#  It coordinates child layers:
#    1) Ground Layer (TileMapLayer) generates the base map
#    2) Grass Layer  (TileMapLayer) paints decorations over ground
#
#  With @tool enabled, changing exported values in the Inspector
#  can rebuild the map instantly inside the editor.
# ============================================================


# ============================================================
#  SECTION: Map Generation Settings
# ------------------------------------------------------------
#  chunk_size: how many tiles wide/tall one chunk is
#  map_size:   how many chunks in the whole map (square: map_size x map_size)
#  seed:       random seed used by layers that need randomness (like grass)
# ============================================================

@export var chunk_size: int = 5:
	set(value):
		# Keep chunk_size sane (>= 3 avoids "degenerate" chunks).
		chunk_size = max(value, 3)
		_request_rebuild()

@export var map_size: int = 7:
	set(value):
		# Must be at least 1 chunk.
		map_size = max(value, 1)
		_request_rebuild()

@export var seed: int = 12345:
	set(value):
		seed = value
		_request_rebuild()


# ============================================================
#  SECTION: Scene Wiring (NodePaths)
# ------------------------------------------------------------
#  Drag the nodes from the Scene Tree into these fields.
#
#  Why NodePath?
#  - It avoids hard-coding $"Node Names" (less brittle when renaming/moving nodes).
# ============================================================

@export var ground_layer_path: NodePath
@export var grass_layer_path: NodePath


# ============================================================
#  SECTION: Lifecycle
# ------------------------------------------------------------
#  _ready runs when the scene is running (and may run in editor because of @tool).
#  We trigger an initial rebuild so the map appears immediately.
# ============================================================

func _ready() -> void:
	rebuild()


# ============================================================
#  SECTION: Public API
# ------------------------------------------------------------
#  rebuild()
#    - Finds the layer nodes
#    - Pushes settings into the ground layer
#    - Tells ground to generate tiles
#    - Tells grass to paint on top of ground (if present)
# ============================================================

func rebuild() -> void:
	var ground := get_node_or_null(ground_layer_path) as TileMapLayer
	var grass := get_node_or_null(grass_layer_path) as TileMapLayer

	# Ground is required. If it's not wired, do nothing (avoids null crashes).
	if ground == null:
		return

	# --- Step 1: Build the ground layer (base map) ---
	# We set the ground layer's parameters, then ask it to draw itself.
	ground.chunk_size = chunk_size
	ground.map_size = map_size
	ground.rebuild()

	# --- Step 2: Paint grass on top of ground (optional) ---
	# Grass doesn't need chunk logic; it uses ground's used cells as its "canvas".
	if grass != null and grass.has_method("rebuild_from_ground"):
		grass.rebuild_from_ground(ground, seed)


# ============================================================
#  SECTION: Editor Rebuild Scheduling
# ------------------------------------------------------------
#  In @tool scripts, export setters can run at times when the scene tree
#  isn't fully ready. call_deferred() schedules rebuild after the editor
#  finishes its current update, which prevents many timing issues.
# ============================================================

func _request_rebuild() -> void:
	if Engine.is_editor_hint():
		call_deferred("rebuild")

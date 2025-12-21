@tool
extends TileMapLayer

# ============================================================
#  FILE: coin_layer.gd
#  NODE: CoinLayer (TileMapLayer)
#
#  ROLE: Tile-based coin “pickup” layer
# ------------------------------------------------------------
#  Coins are NOT individual nodes right now. They are “map state”:
#
#    - visualized as tiles on this TileMapLayer
#    - tracked as data in coins_by_cell (cell -> value)
#
#  Why this design?
#    - RTS / grid interaction: click -> cell lookup is clean
#    - Much fewer nodes (better performance + simpler logic)
#    - Deterministic + easy to save/load later
#
#  Public API (called by Map.gd):
#    - clear_coins()
#    - place_coin(cell, amount)
#    - collect_coin(cell) -> int
# ============================================================


# ============================================================
#  SECTION: TileSet Configuration
# ============================================================

@export var source_id: int = 0
@export var alternative_tile: int = 0


# ============================================================
#  SECTION: Atlas Coordinates (3 coin piles)
# ------------------------------------------------------------
#  You provided:
#    - pile of 1 at (0,2)
#    - pile of 3 at (1,2)
#    - pile of 5 at (2,2)
# ============================================================

const COIN_1_ATLAS := Vector2i(0, 2)
const COIN_3_ATLAS := Vector2i(1, 2)
const COIN_5_ATLAS := Vector2i(2, 2)


# ============================================================
#  SECTION: Runtime State (Coin tracking)
# ------------------------------------------------------------
#  Key:   Vector2i tile cell coordinate
#  Value: int coin amount (1/3/5)
# ============================================================

var coins_by_cell: Dictionary = {}


# ============================================================
#  SECTION: Public API
# ============================================================

func clear_coins() -> void:
	clear()
	coins_by_cell.clear()

func place_coin(cell: Vector2i, amount: int) -> void:
	var atlas := COIN_1_ATLAS
	match amount:
		1: atlas = COIN_1_ATLAS
		3: atlas = COIN_3_ATLAS
		5: atlas = COIN_5_ATLAS
		_:
			push_error("Coin amount must be 1, 3, or 5 (got %s)" % amount)
			return

	set_cell(cell, source_id, atlas, alternative_tile)
	coins_by_cell[cell] = amount

func has_coin(cell: Vector2i) -> bool:
	return coins_by_cell.has(cell)

func collect_coin(cell: Vector2i) -> int:
	# Returns 0 if there is no coin at that cell.
	if not coins_by_cell.has(cell):
		return 0

	var amount: int = int(coins_by_cell[cell])
	coins_by_cell.erase(cell)
	erase_cell(cell)
	return amount

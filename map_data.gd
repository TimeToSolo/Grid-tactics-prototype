extends Node

# ==================================================
# MAP DATA
# ==================================================
# Stores map layout, terrain rules, grid conversion,
# movement range helpers, and attack line-of-sight checks.
# ==================================================


# ==================================================
# GRID CONSTANTS
# ==================================================

const TILE_SIZE = 64
const GRID_WIDTH = 16
const GRID_HEIGHT = 12
const UI_HEIGHT = 48


# ==================================================
# TERRAIN DATA
# ==================================================
# Symbols:
# "." = grass
# "W" = wall
# "R" = river
#
# Terrain rules:
# - walls block movement and attacks
# - rivers block movement but not attacks
# ==================================================

var terrain_map = [
	"WWWWWWWWWWWWWWWWWWWW",
	"W....W....RR....W..W",
	"W....W....RR....W..W",
	"W.........RR........W",
	"WWW..WWW..RR..WWW..W",
	"W..............W...W",
	"W..WWWW....WWWWW...W",
	"W....R......R......W",
	"W....R......R......W",
	"W....RRRRRRRR......W",
	"W.................WW",
	"W..WWWWW....WWWW..W",
	"W......R....R.....W",
	"W......R....R.....W",
	"W......RRRRRR.....W",
	"WWWWWWWWWWWWWWWWWWWW"
]

var terrain_types = {
	".": {
		"name": "grass",
		"blocks_movement": false,
		"blocks_attack": false,
		"move_cost": 1
	},

	"W": {
		"name": "wall",
		"blocks_movement": true,
		"blocks_attack": true,
		"move_cost": 999
	},

	"R": {
		"name": "river",
		"blocks_movement": true,
		"blocks_attack": false,
		"move_cost": 999
	}
}


# ==================================================
# GRID / WORLD CONVERSION
# ==================================================

# =========================
# Converts a world/pixel position into a grid coordinate.
# =========================

func world_to_grid(pos: Vector2) -> Vector2i:
	return Vector2i(
		int(pos.x / TILE_SIZE),
		int((pos.y - UI_HEIGHT) / TILE_SIZE)
	)


# =========================
# Returns the rectangle area for a grid cell.
# Used by drawing functions.
# =========================

func grid_rect(cell: Vector2i) -> Rect2:
	return Rect2(
		cell.x * TILE_SIZE,
		cell.y * TILE_SIZE + UI_HEIGHT,
		TILE_SIZE,
		TILE_SIZE
	)


# ==================================================
# TERRAIN LOOKUP
# ==================================================

# =========================
# Returns the terrain symbol at a grid cell.
#
# Out-of-bounds cells are treated as walls.
# =========================

func get_tile_symbol(cell: Vector2i) -> String:
	if not is_inside_grid(cell):
		return "W"

	return terrain_map[cell.y][cell.x]


# =========================
# Returns display color for a terrain tile.
# =========================

func get_tile_color(cell: Vector2i) -> Color:
	var symbol = get_tile_symbol(cell)

	if symbol == ".":
		return Color(0.3, 0.45, 0.3)

	if symbol == "W":
		return Color(0.15, 0.15, 0.15)

	if symbol == "R":
		return Color(0.15, 0.35, 0.8)

	return Color(0.3, 0.3, 0.3)


# =========================
# Returns true if terrain blocks movement.
# =========================

func blocks_movement(cell: Vector2i) -> bool:
	var symbol = get_tile_symbol(cell)
	return terrain_types[symbol]["blocks_movement"]


# =========================
# Returns true if terrain blocks attacks / line of sight.
# =========================

func blocks_attack(cell: Vector2i) -> bool:
	var symbol = get_tile_symbol(cell)
	return terrain_types[symbol]["blocks_attack"]


# =========================
# Returns the movement cost of a tile.
#
# Currently:
# - grass = 1
# - blocked tiles use 999 as a safety value
# =========================

func get_tile_move_cost(cell: Vector2i) -> int:
	var symbol = get_tile_symbol(cell)
	return terrain_types[symbol]["move_cost"]


# ==================================================
# GRID HELPERS
# ==================================================

# =========================
# Checks whether a grid cell is inside the board.
# =========================

func is_inside_grid(cell: Vector2i) -> bool:
	return (
		cell.x >= 0
		and cell.x < GRID_WIDTH
		and cell.y >= 0
		and cell.y < GRID_HEIGHT
	)


# =========================
# Checks whether one cell is adjacent to another.
#
# Includes diagonals.
# Does not count the center cell itself.
# =========================

func is_adjacent_to(cell: Vector2i, center: Vector2i) -> bool:
	var diff = cell - center

	return (
		abs(diff.x) <= 1
		and abs(diff.y) <= 1
		and diff != Vector2i.ZERO
	)


# =========================
# Returns grid distance using 4-direction movement.
#
# Example:
# moving 3 left and 2 down = 5 movement.
# =========================

func get_grid_distance(start_cell: Vector2i, end_cell: Vector2i) -> int:
	return (
		abs(end_cell.x - start_cell.x)
		+ abs(end_cell.y - start_cell.y)
	)


# =========================
# Returns true if a tile is at maximum movement range.
#
# Used to indicate limited pivot movement.
# =========================

func is_max_range_tile(
	start: Vector2i,
	target: Vector2i,
	move_points: int
) -> bool:

	return get_grid_distance(start, target) >= move_points


# =========================
# Returns the general direction moved.
#
# Examples:
# - west      = Vector2i(-1, 0)
# - northeast = Vector2i(1, -1)
# =========================

func get_primary_direction(
	start_cell: Vector2i,
	end_cell: Vector2i
) -> Vector2i:

	var diff = end_cell - start_cell

	return Vector2i(
		sign(diff.x),
		sign(diff.y)
	)


# ==================================================
# MOVEMENT RANGE
# ==================================================

# =========================
# Calculates all reachable movement tiles.
#
# Uses:
# - 4-direction movement
# - terrain movement blocking
# - occupied tile blocking
#
# Note:
# This currently assumes each passable tile costs 1 movement.
# Terrain move_cost can be integrated later.
# =========================

func get_move_range(
	start: Vector2i,
	move_points: int,
	occupied_tiles: Array[Vector2i] = []
) -> Array[Vector2i]:

	var reached: Array[Vector2i] = []
	var frontier = [{ "cell": start, "cost": 0 }]
	var visited = { start: true }

	var dirs = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1)
	]

	while frontier.size() > 0:

		var current = frontier.pop_front()
		reached.append(current.cell)

		for dir in dirs:

			var next = current.cell + dir
			var next_cost = current.cost + 1

			if not is_inside_grid(next):
				continue

			if blocks_movement(next):
				continue

			if occupied_tiles.has(next):
				continue

			if visited.has(next):
				continue

			if next_cost > move_points:
				continue

			visited[next] = true
			frontier.append({
				"cell": next,
				"cost": next_cost
			})

	return reached


# ==================================================
# ATTACK LINE OF SIGHT
# ==================================================

# =========================
# Returns true if an attack has clear line of sight.
#
# Used mainly by archers.
#
# Checks tiles between start and target.
# The target tile itself is not checked here.
#
# Current implementation is a simple interpolation check.
# This is good enough for prototype testing, but can later
# be replaced with stricter Bresenham line logic.
# =========================

func has_clear_attack_line(start: Vector2i, target: Vector2i) -> bool:
	var diff = target - start
	var steps = max(abs(diff.x), abs(diff.y))

	if steps <= 1:
		return true

	for i in range(1, steps):

		var t = float(i) / float(steps)

		var check = Vector2i(
			round(start.x + diff.x * t),
			round(start.y + diff.y * t)
		)

		if blocks_attack(check):
			return false

	return true

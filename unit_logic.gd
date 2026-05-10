extends Node

# ==================================================
# UNIT LOGIC
# ==================================================
# Handles unit-specific helper logic:
# - unit colors
# - attack preview tiles
# - attack targeting tiles
# - facing direction options
# - defensive coverage shapes
# - archer targeting validation
# ==================================================


# ==================================================
# DIRECTIONS
# ==================================================

var directions: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, -1),
	Vector2i(1, 0),
	Vector2i(1, 1),
	Vector2i(0, 1),
	Vector2i(-1, 1),
	Vector2i(-1, 0),
	Vector2i(-1, -1)
]


# ==================================================
# UNIT DISPLAY
# ==================================================

# =========================
# Returns the display color for each unit class.
# =========================

func get_unit_color(unit_class: String) -> Color:

	if unit_class == "fighter":
		return Color(0.2, 0.5, 1.0)

	if unit_class == "tank":
		return Color(0.2, 0.9, 0.3)

	if unit_class == "lancer":
		return Color(0.9, 0.3, 0.9)

	if unit_class == "duelist":
		return Color(1.0, 0.4, 0.2)

	if unit_class == "archer":
		return Color(0.6, 0.8, 1.0)

	if unit_class == "healer":
		return Color(0.2, 0.8, 1.0)

	return Color.WHITE


# ==================================================
# ATTACK RANGE / TARGETING
# ==================================================

# =========================
# Returns all attack preview tiles from possible movement tiles.
#
# Used before choosing a destination.
#
# This shows every tile the unit could attack
# after moving somewhere within movement range.
# =========================

func get_attack_tiles(
	start: Vector2i,
	move_points: int,
	unit_class: String,
	map_data
) -> Array[Vector2i]:

	var tiles: Array[Vector2i] = []
	var move_tiles_local = map_data.get_move_range(start, move_points)

	for move_tile in move_tiles_local:

		if is_adjacent_attacker(unit_class):
			add_adjacent_attack_tiles(
				tiles,
				move_tile,
				move_tiles_local,
				map_data
			)

		elif unit_class == "lancer":
			add_lancer_attack_tiles(
				tiles,
				move_tile,
				move_tiles_local,
				map_data
			)

		elif unit_class == "archer":
			add_archer_attack_tiles(
				tiles,
				move_tile,
				move_tiles_local,
				map_data
			)

	return tiles


# =========================
# Returns attack targeting tiles from a specific center tile.
#
# Used after a unit has chosen a pending move tile.
# =========================

func get_attack_choice_tiles(
	center: Vector2i,
	unit_class: String,
	map_data
) -> Array[Vector2i]:

	var tiles: Array[Vector2i] = []

	if unit_class == "archer":
		for x in range(-5, 6):
			for y in range(-5, 6):

				var target = center + Vector2i(x, y)

				if is_valid_archer_target(center, target, map_data):
					tiles.append(target)

		return tiles

	if unit_class == "lancer":
		for offset in get_lancer_attack_offsets():

			var tile = center + offset

			if map_data.is_inside_grid(tile):
				tiles.append(tile)

		return tiles

	for dir in directions:

		var tile = center + dir

		if map_data.is_inside_grid(tile):
			tiles.append(tile)

	return tiles


# =========================
# Returns true if this class uses adjacent attack targeting.
# =========================

func is_adjacent_attacker(unit_class: String) -> bool:
	return (
		unit_class == "fighter"
		or unit_class == "tank"
		or unit_class == "duelist"
		or unit_class == "healer"
	)


# =========================
# Adds adjacent attack preview tiles.
#
# Movement tiles themselves are excluded.
# =========================

func add_adjacent_attack_tiles(
	tiles: Array[Vector2i],
	center: Vector2i,
	move_tiles_local: Array[Vector2i],
	map_data
):

	for dir in directions:

		var target = center + dir

		if not map_data.is_inside_grid(target):
			continue

		if move_tiles_local.has(target):
			continue

		add_unique_tile(tiles, target)


# =========================
# Adds lancer attack preview tiles.
#
# Movement tiles themselves are excluded.
# =========================

func add_lancer_attack_tiles(
	tiles: Array[Vector2i],
	center: Vector2i,
	move_tiles_local: Array[Vector2i],
	map_data
):

	for offset in get_lancer_preview_offsets():

		var target = center + offset

		if not map_data.is_inside_grid(target):
			continue

		if move_tiles_local.has(target):
			continue

		add_unique_tile(tiles, target)


# =========================
# Adds archer attack preview tiles.
#
# Uses the same legal targeting helper
# as actual archer targeting.
# =========================

func add_archer_attack_tiles(
	tiles: Array[Vector2i],
	center: Vector2i,
	move_tiles_local: Array[Vector2i],
	map_data
):

	for x in range(-5, 6):
		for y in range(-5, 6):

			var target = center + Vector2i(x, y)

			if move_tiles_local.has(target):
				continue

			if is_valid_archer_target(center, target, map_data):
				add_unique_tile(tiles, target)


# =========================
# Returns lancer offsets used for movement attack preview.
#
# This is slightly narrower than the full targeting list,
# matching the current prototype behavior.
# =========================

func get_lancer_preview_offsets() -> Array[Vector2i]:
	return [
		Vector2i(2, 0),
		Vector2i(-2, 0),
		Vector2i(0, 2),
		Vector2i(0, -2),

		Vector2i(2, 1),
		Vector2i(2, -1),
		Vector2i(-2, 1),
		Vector2i(-2, -1),

		Vector2i(1, 2),
		Vector2i(-1, 2),
		Vector2i(1, -2),
		Vector2i(-1, -2)
	]


# =========================
# Returns lancer offsets used for actual targeting.
# =========================

func get_lancer_attack_offsets() -> Array[Vector2i]:
	return [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1),
		Vector2i(1, 1),
		Vector2i(1, -1),
		Vector2i(-1, 1),
		Vector2i(-1, -1),

		Vector2i(2, 0),
		Vector2i(-2, 0),
		Vector2i(0, 2),
		Vector2i(0, -2),
		Vector2i(2, 2),
		Vector2i(2, -2),
		Vector2i(-2, 2),
		Vector2i(-2, -2),

		Vector2i(2, 1),
		Vector2i(2, -1),
		Vector2i(-2, 1),
		Vector2i(-2, -1),
		Vector2i(1, 2),
		Vector2i(-1, 2),
		Vector2i(1, -2),
		Vector2i(-1, -2)
	]


# =========================
# Returns true if an archer can legally target a tile.
#
# Checks:
# - not targeting self
# - within archer range
# - inside board
# - clear line of sight
# =========================

func is_valid_archer_target(
	center: Vector2i,
	target: Vector2i,
	map_data
) -> bool:

	var offset = target - center

	if offset == Vector2i.ZERO:
		return false

	var distance_squared = offset.x * offset.x + offset.y * offset.y

	if distance_squared > 18:
		return false

	if not map_data.is_inside_grid(target):
		return false

	if not map_data.has_clear_attack_line(center, target):
		return false

	return true


# ==================================================
# FACING LOGIC
# ==================================================

# =========================
# Returns limited facing directions after max-range movement.
#
# Prevents a unit from sprinting in one direction
# and instantly pivoting to face directly backward.
# =========================

func get_limited_facing_dirs(move_dir: Vector2i) -> Array[Vector2i]:

	var allowed: Array[Vector2i] = []

	for dir: Vector2i in directions:

		if Vector2(move_dir).dot(Vector2(dir)) >= 0:
			allowed.append(dir)

	return allowed


# =========================
# Returns valid facing tiles around a pending destination.
#
# If the unit moved its full movement range,
# facing is restricted by movement direction.
# =========================

func get_facing_choice_tiles(
	center: Vector2i,
	move_distance: int,
	move_direction: Vector2i,
	max_move: int,
	map_data
) -> Array[Vector2i]:

	var tiles: Array[Vector2i] = []
	var allowed_dirs: Array[Vector2i] = directions

	if move_distance >= max_move:
		allowed_dirs = get_limited_facing_dirs(move_direction)

	for dir in allowed_dirs:

		var tile = center + dir

		if map_data.is_inside_grid(tile):
			tiles.append(tile)

	return tiles


# =========================
# Returns all 8 adjacent tiles around a center tile.
#
# Used when targeting should ignore limited pivot rules.
# =========================

func get_adjacent_choice_tiles(
	center: Vector2i,
	map_data
) -> Array[Vector2i]:

	var tiles: Array[Vector2i] = []

	for dir in directions:

		var tile = center + dir

		if map_data.is_inside_grid(tile):
			tiles.append(tile)

	return tiles


# ==================================================
# COVERAGE LOGIC
# ==================================================

# =========================
# Returns defensive coverage tiles based on class.
#
# Fighter:
# - 3-tile frontal arc
#
# Tank:
# - 3-tile hard coverage arc
#
# Lancer:
# - forward spear coverage
#
# Duelist:
# - 1-tile lethal coverage
# =========================

func get_coverage_tiles(
	unit_class: String,
	center: Vector2i,
	facing: Vector2i
) -> Array[Vector2i]:

	if unit_class == "fighter":
		return get_fighter_coverage(center, facing)

	if unit_class == "tank":
		return get_tank_coverage(center, facing)

	if unit_class == "lancer":
		return get_lancer_coverage(center, facing)

	if unit_class == "duelist":
		return get_duelist_coverage(center, facing)

	return []


# =========================
# Fighter coverage.
#
# Covers 3 adjacent tiles centered on facing direction.
#
# Example:
# Facing N  = NW, N, NE
# Facing NW = W, NW, N
# =========================

func get_fighter_coverage(
	center: Vector2i,
	facing: Vector2i
) -> Array[Vector2i]:

	var tiles: Array[Vector2i] = []
	var index = directions.find(facing)

	if index == -1:
		return tiles

	for offset in [-1, 0, 1]:

		var dir = directions[
			(index + offset + directions.size()) % directions.size()
		]

		add_unique_tile(tiles, center + dir)

	return tiles


# =========================
# Tank hard coverage.
#
# Covers 3 adjacent frontal tiles.
# These tiles can trigger reaction damage.
# =========================

func get_tank_coverage(
	center: Vector2i,
	facing: Vector2i
) -> Array[Vector2i]:

	var tiles: Array[Vector2i] = []
	var index = directions.find(facing)

	if index == -1:
		return tiles

	for offset in [-1, 0, 1]:

		var dir = directions[
			(index + offset + directions.size()) % directions.size()
		]

		add_unique_tile(tiles, center + dir)

	return tiles


# =========================
# Tank slow/control zone.
#
# Covers the full 5-tile frontal arc.
#
# Inner 3 tiles:
# - also overlap with hard coverage
#
# Outer 2 tiles:
# - slow/control only
# =========================

func get_tank_slow_tiles(
	center: Vector2i,
	facing: Vector2i
) -> Array[Vector2i]:

	var tiles: Array[Vector2i] = []
	var index = directions.find(facing)

	if index == -1:
		return tiles

	for offset in [-2, -1, 0, 1, 2]:

		var dir = directions[
			(index + offset + directions.size()) % directions.size()
		]

		add_unique_tile(tiles, center + dir)

	return tiles


# =========================
# Lancer coverage.
#
# Cardinal facing:
# - 1 tile forward
# - 3-tile row two spaces forward
#
# Diagonal facing:
# - diagonal tile
# - diagonal tile two spaces out
# - two knight-like diagonal support tiles
# =========================

func get_lancer_coverage(
	center: Vector2i,
	facing: Vector2i
) -> Array[Vector2i]:

	var tiles: Array[Vector2i] = []
	var is_cardinal = facing.x == 0 or facing.y == 0

	if is_cardinal:

		var side = Vector2i(-facing.y, facing.x)

		add_unique_tile(tiles, center + facing)
		add_unique_tile(tiles, center + facing * 2)
		add_unique_tile(tiles, center + facing * 2 + side)
		add_unique_tile(tiles, center + facing * 2 - side)

	else:

		add_unique_tile(tiles, center + facing)
		add_unique_tile(tiles, center + facing * 2)
		add_unique_tile(tiles, center + Vector2i(facing.x * 2, facing.y))
		add_unique_tile(tiles, center + Vector2i(facing.x, facing.y * 2))

	return tiles


# =========================
# Duelist coverage.
#
# Covers only 1 adjacent tile
# directly in the facing direction.
# =========================

func get_duelist_coverage(
	center: Vector2i,
	facing: Vector2i
) -> Array[Vector2i]:

	var tiles: Array[Vector2i] = []

	add_unique_tile(tiles, center + facing)

	return tiles


# ==================================================
# GENERAL HELPERS
# ==================================================

# =========================
# Adds a tile only if it is not already present.
# =========================

func add_unique_tile(
	tiles: Array[Vector2i],
	tile: Vector2i
):

	if not tiles.has(tile):
		tiles.append(tile)

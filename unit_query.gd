extends Node

# ==================================================
# UNIT QUERY HELPERS
# ==================================================
# Read-only helper functions for:
# - tile occupancy
# - unit lookup
# - ally/enemy checks
# - simple unit queries
# ==================================================


# =========================
# Returns unit index at a tile.
#
# Returns:
# - unit index
# - or -1 if empty
# =========================

func get_unit_at(
	units: Array,
	cell: Vector2i
) -> int:

	for i in range(units.size()):

		if units[i]["pos"] == cell:
			return i

	return -1


# =========================
# Returns true if a tile contains any unit.
# =========================

func is_tile_occupied(
	units: Array,
	cell: Vector2i
) -> bool:

	return get_unit_at(units, cell) != -1


# =========================
# Returns true if selected unit
# considers target unit an enemy.
# =========================

func is_enemy_unit(
	units: Array,
	selected_unit: int,
	target_unit: int
) -> bool:

	if selected_unit == -1:
		return false

	if target_unit == -1:
		return false

	return (
		units[target_unit]["team"]
		!= units[selected_unit]["team"]
	)


# =========================
# Returns true if selected unit
# considers target unit an ally.
# =========================

func is_ally_unit(
	units: Array,
	selected_unit: int,
	target_unit: int
) -> bool:

	if selected_unit == -1:
		return false

	if target_unit == -1:
		return false

	return (
		units[target_unit]["team"]
		== units[selected_unit]["team"]
	)


# =========================
# Returns enemy-occupied tiles.
#
# Used to prevent movement through enemies.
# =========================

func get_enemy_occupied_tiles(
	units: Array,
	unit_index: int
) -> Array[Vector2i]:

	var occupied: Array[Vector2i] = []

	var unit_team = units[unit_index]["team"]

	for i in range(units.size()):

		if i == unit_index:
			continue

		if units[i]["team"] != unit_team:
			occupied.append(units[i]["pos"])

	return occupied


# =========================
# Returns true if selected unit is healer.
# =========================

func selected_unit_is_healer(
	units: Array,
	selected_unit: int
) -> bool:

	if selected_unit == -1:
		return false

	return units[selected_unit]["class"] == "healer"

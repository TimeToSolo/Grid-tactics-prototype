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

# ==================================================
# SHARED UNIT QUERY CONSTANTS
# ==================================================

const INVALID_UNIT := -1

# =========================
# Returns the unit index
# occupying a tile.
#
# Returns:
# - unit index
# - INVALID_UNIT if empty
# =========================

func get_unit_at(
	units: Array,
	cell: Vector2i
) -> int:

	for i in range(units.size()):

		if units[i]["pos"] == cell:
			return i

	return INVALID_UNIT

# =========================
# Returns true if a tile
# contains any unit.
# =========================

func is_tile_occupied(
	units: Array,
	cell: Vector2i
) -> bool:

	return get_unit_at(
		units,
		cell
	) != INVALID_UNIT

# =========================
# Returns true if the target
# unit is considered an enemy
# of the selected unit.
#
# Requires:
# - valid selected unit
# - valid target unit
# =========================

func is_enemy_unit(
	units: Array,
	selected_unit: int,
	target_unit: int
) -> bool:

	if selected_unit == INVALID_UNIT:
		return false

	if target_unit == INVALID_UNIT:
		return false

	return (
		units[target_unit]["team"]
		!= units[selected_unit]["team"]
	)

# =========================
# Returns true if the target
# unit is considered an ally
# of the selected unit.
#
# Requires:
# - valid selected unit
# - valid target unit
# =========================

func is_ally_unit(
	units: Array,
	selected_unit: int,
	target_unit: int
) -> bool:

	if selected_unit == INVALID_UNIT:
		return false

	if target_unit == INVALID_UNIT:
		return false

	return (
		units[target_unit]["team"]
		== units[selected_unit]["team"]
	)

# =========================
# Returns all enemy-occupied
# tiles relative to the given unit.
#
# Used to prevent movement
# through enemy units.
# =========================

func get_enemy_occupied_tiles(
	units: Array,
	unit_index: int
) -> Array[Vector2i]:

	var occupied: Array[Vector2i] = []

	if unit_index == INVALID_UNIT:
		return occupied

	if unit_index >= units.size():
		return occupied

	var unit_team = units[unit_index]["team"]

	for i in range(units.size()):

		if i == unit_index:
			continue

		if units[i]["team"] != unit_team:
			occupied.append(units[i]["pos"])

	return occupied

# =========================
# Returns true if the selected
# unit is a healer.
# =========================

func selected_unit_is_healer(
	units: Array,
	selected_unit: int
) -> bool:

	if selected_unit == INVALID_UNIT:
		return false

	if selected_unit >= units.size():
		return false

	return units[selected_unit]["class"] == "healer"

# =========================
# Returns the current array
# index of a unit with the
# given unique ID.
#
# Used to safely track units
# even if array indices shift
# after removals.
#
# Returns:
# - unit index
# - INVALID_UNIT if not found
# =========================

func get_unit_index_by_id(
	units: Array,
	unit_id: int
) -> int:

	for i in range(units.size()):

		if (
			units[i].has("id")
			and units[i]["id"] == unit_id
		):
			return i

	return INVALID_UNIT

# =========================
# Returns all occupied tiles
# except the specified unit's
# current tile.
#
# Used by movement systems
# that should prevent stacking
# with any unit regardless of team.
# =========================

func get_all_occupied_tiles_except_unit(
	units: Array,
	unit_index: int
) -> Array[Vector2i]:

	var occupied: Array[Vector2i] = []

	for i in range(units.size()):

		if i == unit_index:
			continue

		occupied.append(units[i]["pos"])

	return occupied

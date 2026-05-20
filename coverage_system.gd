extends Node

# ==================================================
# COVERAGE SYSTEM
# ==================================================
# Handles coverage state checks,
# movement-path coverage detection,
# and delayed coverage reaction damage.
# ==================================================

# ==================================================
# SHARED COVERAGE CONSTANTS
# ==================================================

const INVALID_UNIT := -1

# =========================
# Returns true if a unit
# currently has active coverage.
#
# Coverage requires:
# - valid unit index
# - valid facing direction
# - enough stamina remaining
# =========================

func has_active_coverage(
	units: Array,
	unit_index: int
) -> bool:

	if unit_index == INVALID_UNIT:
		return false

	if unit_index >= units.size():
		return false

	var unit = units[unit_index]

	if unit["facing"] == Vector2i.ZERO:
		return false

	if unit["stamina"] < unit["counter_stamina_cost"]:
		return false

	return true

# =========================
# Returns all enemies whose
# coverage the moving unit
# entered anywhere along the
# actual movement path.
#
# This checks each step of
# the path instead of only
# start -> destination.
#
# A unit that starts inside
# a coverage zone does not
# trigger that same zone
# unless it exits and re-enters
# in future expanded logic.
# =========================

func get_enemies_entered_coverage_along_path(
	units: Array,
	unit_logic,
	unit_index: int,
	path_cells: Array[Vector2i]
) -> Array[int]:

	var covering_enemies: Array[int] = []

	if unit_index == INVALID_UNIT:
		return covering_enemies

	if unit_index >= units.size():
		return covering_enemies

	if path_cells.size() <= 1:
		return covering_enemies

	var moving_team = units[unit_index]["team"]
	var start_cell = path_cells[0]

	for i in range(units.size()):

		if units[i]["team"] == moving_team:
			continue

		if not has_active_coverage(units, i):
			continue

		var covered_tiles = unit_logic.get_coverage_tiles(
			units[i]["class"],
			units[i]["pos"],
			units[i]["facing"]
		)

		var started_in_coverage = covered_tiles.has(start_cell)

		for path_index in range(1, path_cells.size()):

			var path_cell = path_cells[path_index]

			if covered_tiles.has(path_cell) and not started_in_coverage:
				covering_enemies.append(i)
				break

	return covering_enemies

# =========================
# Resolves all delayed
# coverage reactions against
# the moving unit.
#
# Multiple overlapping coverage
# zones each resolve individually.
#
# Returns:
# - true if moving unit dies
# - false otherwise
# =========================

func resolve_pending_coverage_if_needed(
	units: Array,
	combat_logic,
	selected_unit: int,
	pending_coverage_enemies: Array[int]
) -> bool:

	if selected_unit == INVALID_UNIT:
		pending_coverage_enemies.clear()
		return false

	if selected_unit >= units.size():
		pending_coverage_enemies.clear()
		return false

	if pending_coverage_enemies.is_empty():
		return false

	for covering_enemy in pending_coverage_enemies:

		var unit_died = resolve_coverage_reaction(
			units,
			combat_logic,
			selected_unit,
			covering_enemy
		)

		if unit_died:
			pending_coverage_enemies.clear()
			return true

	pending_coverage_enemies.clear()

	return false

# =========================
# Resolves one coverage
# reaction attack.
#
# The covering unit spends
# counter stamina, then deals
# reaction damage to the
# moving unit.
#
# Returns true if the moving
# unit dies.
# =========================

func resolve_coverage_reaction(
	units: Array,
	combat_logic,
	moving_unit: int,
	covering_unit: int
) -> bool:

	if moving_unit == INVALID_UNIT:
		return false

	if covering_unit == INVALID_UNIT:
		return false

	if moving_unit >= units.size():
		return false

	if covering_unit >= units.size():
		return false

	units[covering_unit]["stamina"] = max(
		units[covering_unit]["stamina"]
		- units[covering_unit]["counter_stamina_cost"],
		0
	)

	var moving_unit_died = combat_logic.resolve_attack(
		units[covering_unit],
		units[moving_unit],
		units[covering_unit]["counter_damage_multiplier"]
	)

	return moving_unit_died

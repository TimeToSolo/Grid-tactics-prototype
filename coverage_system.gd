extends Node

# ==================================================
# COVERAGE SYSTEM
# ==================================================
# Handles coverage state checks and delayed
# coverage reaction damage.
# ==================================================


# =========================
# Returns true if a unit currently
# has active coverage.
#
# Coverage requires:
# - a valid facing direction
# - enough stamina remaining
# =========================

func has_active_coverage(
	units: Array,
	unit_index: int
) -> bool:

	var unit = units[unit_index]

	if unit["facing"] == Vector2i.ZERO:
		return false

	if unit["stamina"] < unit["counter_stamina_cost"]:
		return false

	return true

# =========================
# Returns all enemies whose coverage
# the moving unit ENTERED anywhere
# along the actual movement path.
#
# This checks each step of the path,
# instead of only start -> destination.
# =========================

func get_enemies_entered_coverage_along_path(
	units: Array,
	unit_logic,
	unit_index: int,
	path_cells: Array[Vector2i]
) -> Array[int]:

	var covering_enemies: Array[int] = []

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
# Resolves delayed coverage damage.
#
# Multiple overlapping coverage zones
# each resolve individually.
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
# Resolves a coverage reaction attack.
#
# The covering unit spends stamina
# to perform the reaction attack.
# =========================

func resolve_coverage_reaction(
	units: Array,
	combat_logic,
	moving_unit: int,
	covering_unit: int
) -> bool:

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

extends Node

# ==================================================
# HOVER QUERY
# ==================================================
# Read-only helper functions for checking whether
# the currently hovered tile is a valid action target.
# ==================================================


# =========================
# Returns true if hovering a valid attack target.
# =========================

func is_hovering_attackable_enemy(
	units: Array,
	selected_unit: int,
	pending_move_cell: Vector2i,
	hovered_cell: Vector2i,
	has_pending_move: bool,
	unit_logic,
	unit_query,
	map_data
) -> bool:

	if selected_unit == -1:
		return false

	if not has_pending_move:
		return false

	var attack_tiles: Array[Vector2i]

	if units[selected_unit]["class"] == "healer":
		attack_tiles = unit_logic.get_adjacent_choice_tiles(
			pending_move_cell,
			map_data
		)
	else:
		attack_tiles = unit_logic.get_attack_choice_tiles(
			pending_move_cell,
			units[selected_unit]["class"],
			map_data
		)

	if not attack_tiles.has(hovered_cell):
		return false

	var hovered_unit = unit_query.get_unit_at(
		units,
		hovered_cell
	)

	return unit_query.is_enemy_unit(
		units,
		selected_unit,
		hovered_unit
	)


# =========================
# Returns true if hovering a healable ally.
#
# Uses healer support range, not lancer range.
# =========================

func is_hovering_healable_ally(
	units: Array,
	selected_unit: int,
	pending_move_cell: Vector2i,
	hovered_cell: Vector2i,
	has_pending_move: bool,
	unit_logic,
	unit_query,
	map_data
) -> bool:

	if not unit_query.selected_unit_is_healer(
		units,
		selected_unit
	):
		return false

	if not has_pending_move:
		return false

	var heal_tiles = unit_logic.get_heal_choice_tiles(
		pending_move_cell,
		map_data
	)

	if not heal_tiles.has(hovered_cell):
		return false

	var hovered_unit = unit_query.get_unit_at(
		units,
		hovered_cell
	)

	return unit_query.is_ally_unit(
		units,
		selected_unit,
		hovered_unit
	)

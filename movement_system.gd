extends Node

# ==================================================
# MOVEMENT SYSTEM
# ==================================================
# Handles movement finalization and facing helpers.
# ==================================================


# =========================
# Returns all valid lancer
# facing-selection tiles.
#
# Filters lancer attack tiles using
# movement-based facing restrictions.
# =========================

func get_valid_lancer_facing_tiles(
	unit_logic,
	action_query,
	map_data,
	pending_move_cell: Vector2i,
	pending_move_direction: Vector2i,
	used_max_movement: bool
) -> Array[Vector2i]:

	var valid_tiles: Array[Vector2i] = []

	var lancer_tiles = unit_logic.get_attack_choice_tiles(
		pending_move_cell,
		"lancer",
		map_data
	)

	var allowed_dirs: Array[Vector2i] = []

	if used_max_movement:
		allowed_dirs = unit_logic.get_limited_facing_dirs(
			pending_move_direction
		)
	else:
		allowed_dirs = unit_logic.get_all_facing_dirs()

	for cell in lancer_tiles:

		var facing = action_query.get_lancer_facing_from_target(
			pending_move_cell,
			cell
		)

		if allowed_dirs.has(facing):
			valid_tiles.append(cell)

	return valid_tiles

# =========================
# Finalizes movement facing selection.
#
# Returns:
# - unit_died
# - remove_index
# - pending_facing
# =========================

func handle_facing_click(
	units: Array,
	combat_logic,
	coverage_system,
	stamina_system,
	unit_logic,
	action_query,
	map_data,
	selected_unit: int,
	clicked_cell: Vector2i,
	pending_move_cell: Vector2i,
	pending_move_distance: int,
	pending_move_direction: Vector2i,
	pending_coverage_enemies: Array[int],
	valid_lancer_tiles: Array[Vector2i]
) -> Dictionary:

	if selected_unit == -1:
		return {}

	if pending_move_cell == Vector2i(-1, -1):
		return {}

	var valid_facing_click = false

	if units[selected_unit]["class"] == "lancer":

		valid_facing_click = valid_lancer_tiles.has(clicked_cell)

	else:

		var facing_tiles = unit_logic.get_facing_choice_tiles(
			pending_move_cell,
			pending_move_distance,
			pending_move_direction,
			units[selected_unit]["move"],
			map_data
		)

		valid_facing_click = facing_tiles.has(clicked_cell)

	if not valid_facing_click:
		return {}

	var pending_facing: Vector2i

	if units[selected_unit]["class"] == "lancer":

		pending_facing = action_query.get_lancer_facing_from_target(
			pending_move_cell,
			clicked_cell
		)

	else:

		pending_facing = clicked_cell - pending_move_cell

	units[selected_unit]["facing"] = pending_facing
	units[selected_unit]["has_acted"] = true

	if coverage_system.resolve_pending_coverage_if_needed(
		units,
		combat_logic,
		selected_unit,
		pending_coverage_enemies
	):
		return {
			"unit_died": true,
			"remove_index": selected_unit,
			"pending_facing": pending_facing
		}

	stamina_system.spend_movement_stamina(
		units,
		selected_unit,
		pending_move_distance
	)

	return {
		"unit_died": false,
		"remove_index": -1,
		"pending_facing": pending_facing
	}

# =========================
# Handles clicking a valid movement tile.
#
# The unit visually moves immediately,
# but the move is not finalized until
# the player confirms an action/facing/wait.
#
# Returns pending movement state.
# =========================

func handle_move_tile_click(
	units: Array,
	unit_query,
	coverage_system,
	unit_logic,
	map_data,
	selected_unit: int,
	selected_unit_start_cell: Vector2i,
	clicked_cell: Vector2i,
	move_tiles: Array[Vector2i]
) -> Dictionary:

	if selected_unit == -1:
		return {}

	if (
		unit_query.is_tile_occupied(
			units,
			clicked_cell
		)
		and clicked_cell != units[selected_unit]["pos"]
	):
		return {}

	var start = selected_unit_start_cell

	var pending_move_cell = clicked_cell

	var pending_coverage_enemies = coverage_system.get_enemies_entered_coverage(
		units,
		unit_logic,
		selected_unit,
		selected_unit_start_cell,
		clicked_cell
	)

	units[selected_unit]["pos"] = pending_move_cell

	var pending_move_distance = map_data.get_grid_distance(
		start,
		clicked_cell
	)

	var pending_move_direction = map_data.get_primary_direction(
		start,
		clicked_cell
	)

	move_tiles.clear()

	return {
		"pending_move_cell": pending_move_cell,
		"pending_facing": Vector2i.ZERO,
		"pending_move_distance": pending_move_distance,
		"pending_move_direction": pending_move_direction,
		"pending_coverage_enemies": pending_coverage_enemies
	}

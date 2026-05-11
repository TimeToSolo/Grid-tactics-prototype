extends Node

# ==================================================
# SELECTION SYSTEM
# ==================================================
# Handles unit selection and selection-state setup.
# ==================================================


# =========================
# Selects a unit and prepares
# movement/action state.
#
# Returns full selection state.
# =========================

func select_unit(
	units: Array,
	map_data,
	unit_query,
	unit_index: int
) -> Dictionary:

	var selected_unit = unit_index

	var selected_unit_start_cell = (
		units[selected_unit]["pos"]
	)

	var move_tiles = map_data.get_move_range(
		units[selected_unit]["pos"],
		units[selected_unit]["move"],
		unit_query.get_enemy_occupied_tiles(
			units,
			selected_unit
		)
	)

	return {
		"selected_unit": selected_unit,
		"selected_unit_start_cell": selected_unit_start_cell,
		"move_tiles": move_tiles,

		"pending_move_cell": Vector2i(-1, -1),
		"pending_facing": Vector2i.ZERO,
		"pending_move_distance": 0,
		"pending_move_direction": Vector2i.ZERO,
		"pending_coverage_enemies": [] as Array[int],

		"pending_attack_target": -1,
		"pending_heal_target": -1,

		"awaiting_attack_confirmation": false,
		"awaiting_heal_confirmation": false,
		"awaiting_wait_confirmation": false
	}

# =========================
# Handles clicking a unit or empty tile
# during normal selection mode.
#
# Returns:
# - clear_selection
# - select_unit
# - selected_unit_index
# =========================

func handle_unit_click(
	units: Array,
	unit_query,
	turn_manager,
	selected_unit: int,
	clicked_cell: Vector2i
) -> Dictionary:

	var clicked_unit = unit_query.get_unit_at(
		units,
		clicked_cell
	)

	if clicked_unit == -1:
		return {
			"clear_selection": true,
			"select_unit": false,
			"selected_unit_index": -1
		}

	if units[clicked_unit]["team"] != turn_manager.current_team:
		return {}

	if units[clicked_unit]["has_acted"]:
		return {}

	if selected_unit == clicked_unit:
		return {
			"clear_selection": true,
			"select_unit": false,
			"selected_unit_index": -1
		}

	return {
		"clear_selection": false,
		"select_unit": true,
		"selected_unit_index": clicked_unit
	}

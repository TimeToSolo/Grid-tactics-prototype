extends Node

# ==================================================
# SELECTION SYSTEM
# ==================================================
# Handles unit selection and selection-state setup.
# ==================================================

# ==================================================
# SHARED SELECTION CONSTANTS
# ==================================================

const INVALID_CELL := Vector2i(-1, -1)
const INVALID_UNIT := -1

# =========================
# Selects a unit and prepares
# movement/action state.
#
# Returns full selection + pending action state.
# =========================

func select_unit(
	units: Array,
	map_data,
	unit_query,
	unit_index: int
) -> Dictionary:

	var selected_unit = unit_index

	var selected_unit_start_cell = units[selected_unit]["pos"]

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

		"pending_move_cell": INVALID_CELL,
		"pending_move_distance": 0,
		"pending_coverage_enemies": [] as Array[int],

		"pending_attack_target": INVALID_UNIT,
		"pending_support_target": INVALID_UNIT,

		"awaiting_attack_confirmation": false,
		"awaiting_support_confirmation": false,
		"awaiting_wait_confirmation": false
	}

# =========================
# Handles clicking a unit or empty tile
# during normal selection mode.
#
# Returns a dictionary describing
# how Main should react:
# - clear current selection
# - select a new unit
# - ignore the click
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

	if clicked_unit == INVALID_UNIT:
		return {
			"clear_selection": true,
			"select_unit": false,
			"selected_unit_index": INVALID_UNIT
		}

	if units[clicked_unit]["team"] != turn_manager.current_team:
		return {}

	if units[clicked_unit]["has_acted"]:
		return {}

	if selected_unit == clicked_unit:
		return {
			"clear_selection": true,
			"select_unit": false,
			"selected_unit_index": INVALID_UNIT
		}

	return {
		"clear_selection": false,
		"select_unit": true,
		"selected_unit_index": clicked_unit
	}

# =========================
# Clears selection and pending movement state.
#
# Returns cleared selection state.
# =========================

func clear_selection() -> Dictionary:

	return {
		"selected_unit": INVALID_UNIT,
		"selected_unit_start_cell": INVALID_CELL,
		"move_tiles": [] as Array[Vector2i],

		"pending_move_cell": INVALID_CELL,
		"pending_move_distance": 0,
		"pending_coverage_enemies": [] as Array[int]
	}

# =========================
# Clears pending action confirmation state.
#
# Returns cleared pending action state.
# =========================

func clear_pending_action_state() -> Dictionary:

	var state = clear_selection()

	state["awaiting_attack_confirmation"] = false
	state["awaiting_support_confirmation"] = false
	state["awaiting_wait_confirmation"] = false

	state["pending_attack_target"] = INVALID_UNIT
	state["pending_support_target"] = INVALID_UNIT

	return state

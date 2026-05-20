extends Node

# ==================================================
# POST MOVE ACTION FLOW
# ==================================================
# Handles:
# - deciding which post-move
#   action menu should appear
# - identifying attack/support/wait
#   confirmation menu states
# - returning menu state data to Main
#
# This node does NOT:
# - execute attacks
# - execute heals
# - confirm wait actions
# - mutate unit state directly
#
# Main remains responsible for:
# - applying returned state
# - opening the action menu
# - executing chosen actions
# ==================================================

# ==================================================
# SHARED POST-MOVE CONSTANTS
# ==================================================

const INVALID_CELL := Vector2i(-1, -1)
const INVALID_UNIT := -1

# =========================
# Returns the post-move menu
# state for a clicked cell.
#
# The returned Dictionary tells
# Main which menu to open and
# which pending action state to
# store.
#
# Possible menu modes:
# - confirm_wait
# - confirm_support
# - confirm_attack
# =========================

func get_post_move_menu_state(
	units: Array,
	selected_unit: int,
	clicked_cell: Vector2i,
	pending_move_cell: Vector2i,
	action_query,
	action_system,
	unit_logic,
	unit_query,
	hover_query,
	map_data
) -> Dictionary:

	if selected_unit == INVALID_UNIT:
		return {}

	if clicked_cell == pending_move_cell:
		return {
			"type": "wait",
			"mode": "confirm_wait",
			"options": ["Wait", "Cancel"],
			"pending_facing_cell": INVALID_CELL
		}

	if action_query.should_handle_heal_click(
		units,
		selected_unit,
		pending_move_cell,
		clicked_cell,
		true,
		unit_logic,
		unit_query,
		hover_query,
		map_data
	):
		var state = action_system.get_support_confirmation_state(
			units,
			selected_unit,
			clicked_cell,
			unit_query
		)

		if state.is_empty():
			return {}

		state["type"] = "support"
		state["mode"] = "confirm_support"
		state["options"] = ["Heal", "Regen", "Cancel"]
		state["pending_facing_cell"] = INVALID_CELL

		return state

	if action_query.should_handle_attack_click(
		units,
		selected_unit,
		pending_move_cell,
		clicked_cell,
		true,
		unit_logic,
		unit_query,
		hover_query,
		map_data
	):
		var state = action_system.get_attack_confirmation_state(
			units,
			selected_unit,
			clicked_cell,
			unit_query
		)

		if state.is_empty():
			return {}

		state["type"] = "attack"
		state["mode"] = "confirm_attack"
		state["options"] = ["Attack", "Wait", "Cancel"]
		state["pending_facing_cell"] = clicked_cell

		return state

	if (
		action_query.is_clicking_empty_action_tile(
			units,
			selected_unit,
			clicked_cell,
			pending_move_cell,
			true,
			unit_logic,
			unit_query,
			map_data
		)
		and (
			units[selected_unit]["class"] == "archer"
			or units[selected_unit]["class"] == "healer"
		)
	):
		return {
			"type": "wait",
			"mode": "confirm_wait",
			"options": ["Wait", "Cancel"],
			"pending_facing_cell": clicked_cell
		}

	if action_query.should_handle_facing_click(
		units,
		selected_unit,
		clicked_cell,
		pending_move_cell,
		clicked_cell,
		true,
		unit_logic,
		unit_query,
		hover_query,
		map_data
	):
		return {
			"type": "wait",
			"mode": "confirm_wait",
			"options": ["Wait", "Cancel"],
			"pending_facing_cell": clicked_cell
		}

	return {}

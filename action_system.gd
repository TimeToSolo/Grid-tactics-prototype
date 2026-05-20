extends Node

# ==================================================
# ACTION SYSTEM
# ==================================================
# Handles:
# - action confirmation state
# - attack execution
# - support execution
# - wait execution
# - movement finalization
# - automatic turn ending
# ==================================================

# ==================================================
# SHARED ACTION CONSTANTS
# ==================================================

const INVALID_CELL := Vector2i(-1, -1)
const INVALID_UNIT := -1

# ==================================================
# CONFIRMATION STATE BUILDERS
# ==================================================

# =========================
# Starts wait confirmation.
# =========================

func start_wait_confirmation() -> Dictionary:

	return {
		"awaiting_wait_confirmation": true,
		"awaiting_attack_confirmation": false,
		"awaiting_support_confirmation": false,
		"pending_attack_target": INVALID_UNIT,
		"pending_support_target": INVALID_UNIT
	}

# =========================
# Starts attack confirmation
# against a selected enemy.
#
# Returns action-menu state
# for Main.gd to apply.
# =========================

func start_attack_confirmation(
	target_unit: int
) -> Dictionary:

	return {
		"pending_attack_target": target_unit,
		"awaiting_attack_confirmation": true,
		"awaiting_support_confirmation": false,
		"awaiting_wait_confirmation": false,
		"pending_support_target": INVALID_UNIT
	}

# =========================
# Starts support confirmation
# on a selected allied unit.
#
# Used for:
# - heal
# - regeneration
# =========================

func start_support_confirmation(
	target_unit: int
) -> Dictionary:

	return {
		"pending_support_target": target_unit,
		"awaiting_support_confirmation": true,
		"awaiting_attack_confirmation": false,
		"awaiting_wait_confirmation": false,
		"pending_attack_target": INVALID_UNIT
	}

# ==================================================
# TARGET VALIDATION
# ==================================================

# =========================
# Returns attack confirmation
# state if the clicked unit
# is a valid enemy target.
# =========================

func get_attack_confirmation_state(
	units: Array,
	selected_unit: int,
	clicked_cell: Vector2i,
	unit_query
) -> Dictionary:

	var clicked_unit = unit_query.get_unit_at(
		units,
		clicked_cell
	)

	if unit_query.is_enemy_unit(
		units,
		selected_unit,
		clicked_unit
	):
		return start_attack_confirmation(
			clicked_unit
		)

	return {}

# =========================
# Returns support confirmation
# state if the clicked unit
# is a valid allied target.
# =========================

func get_support_confirmation_state(
	units: Array,
	selected_unit: int,
	clicked_cell: Vector2i,
	unit_query
) -> Dictionary:

	var clicked_unit = unit_query.get_unit_at(
		units,
		clicked_cell
	)

	if unit_query.is_ally_unit(
		units,
		selected_unit,
		clicked_unit
	):
		return start_support_confirmation(
			clicked_unit
		)

	return {}

# ==================================================
# MOVEMENT FINALIZATION
# ==================================================

# =========================
# Finalizes movement before
# executing an action.
#
# Handles:
# - has_acted
# - coverage resolution
# - movement stamina
#
# Returns:
# - unit_died
# - remove_index
# =========================

func finalize_movement_phase(
	units: Array,
	combat_logic,
	coverage_system,
	stamina_system,
	selected_unit: int,
	pending_move_distance: int,
	pending_coverage_enemies: Array[int]
) -> Dictionary:

	units[selected_unit]["has_acted"] = true

	if coverage_system.resolve_pending_coverage_if_needed(
		units,
		combat_logic,
		selected_unit,
		pending_coverage_enemies
	):
		return {
			"unit_died": true,
			"remove_index": selected_unit
		}

	stamina_system.spend_movement_stamina(
		units,
		selected_unit,
		pending_move_distance
	)

	return {
		"unit_died": false,
		"remove_index": INVALID_UNIT
	}

# ==================================================
# WAIT ACTIONS
# ==================================================

# =========================
# Confirms wait action.
#
# Finalizes movement and
# ends the unit's action
# without performing an
# attack or support skill.
#
# Returns:
# - unit_died
# - remove_index
# - action_completed
# - awaiting_wait_confirmation
# =========================

func confirm_wait(
	units: Array,
	combat_logic,
	coverage_system,
	stamina_system,
	selected_unit: int,
	pending_move_cell: Vector2i,
	pending_move_distance: int,
	pending_coverage_enemies: Array[int]
) -> Dictionary:

	if selected_unit == INVALID_UNIT:
		return {}

	if pending_move_cell == INVALID_CELL:
		return {}

	var movement_result = finalize_movement_phase(
		units,
		combat_logic,
		coverage_system,
		stamina_system,
		selected_unit,
		pending_move_distance,
		pending_coverage_enemies
	)

	if movement_result["unit_died"]:
		return {
			"unit_died": true,
			"remove_index": movement_result["remove_index"],
			"action_completed": false,
			"awaiting_wait_confirmation": false
		}

	return {
		"unit_died": false,
		"remove_index": INVALID_UNIT,
		"action_completed": true,
		"awaiting_wait_confirmation": false
	}

# ==================================================
# SUPPORT ACTIONS
# ==================================================

# =========================
# Applies support effect.
#
# Supported actions:
# - heal
# - regen
# =========================

func apply_support_action(
	units: Array,
	selected_unit: int,
	target_unit: int,
	combat_logic,
	support_action: String
) -> bool:

	match support_action:

		"heal":
			combat_logic.apply_heal(
				units[target_unit],
				units[selected_unit]["heal_amount"]
			)

		"regen":
			combat_logic.apply_regen(
				units[target_unit],
				units[selected_unit]["regen_amount"],
				units[selected_unit]["regen_turns"]
			)

		_:
			return false

	return true

# =========================
# Confirms healer support
# action.
#
# Supports:
# - heal
# - regen
#
# Returns:
# - unit_died
# - remove_index
# - action_completed
# - awaiting_support_confirmation
# - pending_support_target
# =========================

func confirm_support_action(
	units: Array,
	combat_logic,
	coverage_system,
	stamina_system,
	selected_unit: int,
	pending_support_target: int,
	pending_move_distance: int,
	pending_coverage_enemies: Array[int],
	support_action: String
) -> Dictionary:

	if selected_unit == INVALID_UNIT:
		return {}

	if pending_support_target == INVALID_UNIT:
		return {}

	var movement_result = finalize_movement_phase(
		units,
		combat_logic,
		coverage_system,
		stamina_system,
		selected_unit,
		pending_move_distance,
		pending_coverage_enemies
	)

	if movement_result["unit_died"]:
		return {
			"unit_died": true,
			"remove_index": movement_result["remove_index"],
			"action_completed": false,
			"awaiting_support_confirmation": false,
			"pending_support_target": INVALID_UNIT
		}

	if not apply_support_action(
		units,
		selected_unit,
		pending_support_target,
		combat_logic,
		support_action
	):
		return {}

	stamina_system.spend_support_stamina(
		units,
		selected_unit,
		support_action
	)

	return {
		"unit_died": false,
		"remove_index": INVALID_UNIT,
		"action_completed": true,
		"awaiting_support_confirmation": false,
		"pending_support_target": INVALID_UNIT
	}

# ==================================================
# ATTACK ACTIONS
# ==================================================

# =========================
# Returns attack facing
# direction from:
# - pending move cell
# - defender position
# =========================

func get_attack_direction(
	pending_move_cell: Vector2i,
	target_pos: Vector2i
) -> Vector2i:

	var attack_diff = target_pos - pending_move_cell

	return Vector2i(
		sign(attack_diff.x),
		sign(attack_diff.y)
	)

# =========================
# Confirms pending attack.
#
# Returns:
# - attacker_died
# - defender_died
# - attacker_remove_index
# - defender_remove_index
# - awaiting_attack_confirmation
# - pending_attack_target
# =========================

func confirm_attack(
	units: Array,
	combat_logic,
	coverage_system,
	stamina_system,
	selected_unit: int,
	pending_attack_target: int,
	pending_move_cell: Vector2i,
	pending_move_distance: int,
	pending_coverage_enemies: Array[int]
) -> Dictionary:

	if selected_unit == INVALID_UNIT:
		return {}

	if pending_attack_target == INVALID_UNIT:
		return {}

	if pending_move_cell == INVALID_CELL:
		return {}

	var target_pos = units[pending_attack_target]["pos"]

	units[selected_unit]["facing"] = get_attack_direction(
		pending_move_cell,
		target_pos
	)

	var movement_result = finalize_movement_phase(
		units,
		combat_logic,
		coverage_system,
		stamina_system,
		selected_unit,
		pending_move_distance,
		pending_coverage_enemies
	)

	if movement_result["unit_died"]:
		return {
			"attacker_died": true,
			"defender_died": false,
			"attacker_remove_index": movement_result["remove_index"],
			"defender_remove_index": INVALID_UNIT,
			"awaiting_attack_confirmation": false,
			"pending_attack_target": INVALID_UNIT
		}

	var defender_died = combat_logic.resolve_attack(
		units[selected_unit],
		units[pending_attack_target]
	)

	stamina_system.spend_attack_stamina(
		units,
		selected_unit
	)

	return {
		"attacker_died": false,
		"defender_died": defender_died,
		"attacker_remove_index": INVALID_UNIT,
		"defender_remove_index": pending_attack_target,
		"awaiting_attack_confirmation": false,
		"pending_attack_target": INVALID_UNIT
	}

# ==================================================
# TURN FLOW
# ==================================================

# =========================
# Automatically ends the
# current team's turn if
# all units on that team
# have acted.
#
# Also handles:
# - healer recovery
# - turn counter updates
#
# Returns updated turn number.
# =========================

func auto_end_turn_if_needed(
	units: Array,
	turn_manager,
	stamina_system,
	turn_number: int
) -> int:

	for unit in units:

		if unit["team"] != turn_manager.current_team:
			continue

		if not unit["has_acted"]:
			return turn_number

	if turn_manager.current_team == "player":

		stamina_system.recover_idle_healers(
			units,
			turn_manager.current_team
		)

	turn_manager.end_turn(units)

	if turn_manager.current_team == "player":
		turn_number += 1

	return turn_number

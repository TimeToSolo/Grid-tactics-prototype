extends Node

# ==================================================
# ACTION SYSTEM
# ==================================================
# Handles starting pending action confirmation states.
# ==================================================


# =========================
# Starts wait confirmation.
# =========================

func start_wait_confirmation() -> Dictionary:

	return {
		"awaiting_wait_confirmation": true,
		"awaiting_attack_confirmation": false,
		"awaiting_heal_confirmation": false,
		"pending_attack_target": -1,
		"pending_heal_target": -1
	}


# =========================
# Starts attack confirmation against an enemy unit.
# =========================

func start_attack_confirmation(target_unit: int) -> Dictionary:

	return {
		"pending_attack_target": target_unit,
		"awaiting_attack_confirmation": true,
		"awaiting_heal_confirmation": false,
		"awaiting_wait_confirmation": false,
		"pending_heal_target": -1
	}


# =========================
# Starts heal/regeneration confirmation
# on an allied unit.
# =========================

func start_heal_confirmation(target_unit: int) -> Dictionary:

	return {
		"pending_heal_target": target_unit,
		"awaiting_heal_confirmation": true,
		"awaiting_attack_confirmation": false,
		"awaiting_wait_confirmation": false,
		"pending_attack_target": -1
	}


# =========================
# Returns state needed to start attack
# confirmation if clicked unit is enemy.
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
		return start_attack_confirmation(clicked_unit)

	return {}


# =========================
# Returns state needed to start heal
# confirmation if clicked unit is ally.
# =========================

func get_heal_confirmation_state(
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
		return start_heal_confirmation(clicked_unit)

	return {}
	
# =========================
# Confirms wait action.
#
# Returns:
# - unit_died
# - remove_index
# - action_completed
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

	if selected_unit == -1:
		return {}

	if pending_move_cell == Vector2i(-1, -1):
		return {}

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
			"action_completed": false,
			"awaiting_wait_confirmation": false
		}

	stamina_system.spend_movement_stamina(
		units,
		selected_unit,
		pending_move_distance
	)

	return {
		"unit_died": false,
		"remove_index": -1,
		"action_completed": true,
		"awaiting_wait_confirmation": false
	}


# =========================
# Automatically ends the current team's turn
# if all units on that team have acted.
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

# =========================
# Confirms instant heal action.
#
# Returns:
# - unit_died
# - remove_index
# - action_completed
# - awaiting_heal_confirmation
# - pending_heal_target
# =========================

func confirm_heal(
	units: Array,
	combat_logic,
	coverage_system,
	stamina_system,
	selected_unit: int,
	pending_heal_target: int,
	pending_move_distance: int,
	pending_coverage_enemies: Array[int]
) -> Dictionary:

	if selected_unit == -1:
		return {}

	if pending_heal_target == -1:
		return {}

	if units[selected_unit]["heal_charges"] <= 0:
		return {}

	var dead_index = selected_unit

	if coverage_system.resolve_pending_coverage_if_needed(
		units,
		combat_logic,
		selected_unit,
		pending_coverage_enemies
	):
		return {
			"unit_died": true,
			"remove_index": dead_index,
			"action_completed": false,
			"awaiting_heal_confirmation": false,
			"pending_heal_target": -1
		}

	stamina_system.spend_movement_stamina(
		units,
		selected_unit,
		pending_move_distance
	)

	combat_logic.apply_heal(
		units[pending_heal_target],
		units[selected_unit]["heal_amount"]
	)

	units[selected_unit]["heal_charges"] -= 1

	units[selected_unit]["stamina"] = max(
		units[selected_unit]["stamina"]
		- units[selected_unit]["heal_stamina_cost"],
		0
	)

	units[selected_unit]["has_acted"] = true

	return {
		"unit_died": false,
		"remove_index": -1,
		"action_completed": true,
		"awaiting_heal_confirmation": false,
		"pending_heal_target": -1
	}
	
# =========================
# Confirms regeneration action.
#
# Returns:
# - unit_died
# - remove_index
# - action_completed
# - awaiting_heal_confirmation
# - pending_heal_target
# =========================

func confirm_regen(
	units: Array,
	combat_logic,
	coverage_system,
	stamina_system,
	selected_unit: int,
	pending_heal_target: int,
	pending_move_distance: int,
	pending_coverage_enemies: Array[int]
) -> Dictionary:

	if selected_unit == -1:
		return {}

	if pending_heal_target == -1:
		return {}

	if units[selected_unit]["heal_charges"] <= 0:
		return {}

	var dead_index = selected_unit

	if coverage_system.resolve_pending_coverage_if_needed(
		units,
		combat_logic,
		selected_unit,
		pending_coverage_enemies
	):
		return {
			"unit_died": true,
			"remove_index": dead_index,
			"action_completed": false,
			"awaiting_heal_confirmation": false,
			"pending_heal_target": -1
		}

	stamina_system.spend_movement_stamina(
		units,
		selected_unit,
		pending_move_distance
	)

	combat_logic.apply_regen(
		units[pending_heal_target],
		units[selected_unit]["regen_amount"],
		units[selected_unit]["regen_turns"]
	)

	units[selected_unit]["heal_charges"] -= 1

	units[selected_unit]["stamina"] = max(
		units[selected_unit]["stamina"]
		- units[selected_unit]["regen_stamina_cost"],
		0
	)

	units[selected_unit]["has_acted"] = true

	return {
		"unit_died": false,
		"remove_index": -1,
		"action_completed": true,
		"awaiting_heal_confirmation": false,
		"pending_heal_target": -1
	}

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

	if selected_unit == -1:
		return {}

	if pending_attack_target == -1:
		return {}

	var target_pos = units[pending_attack_target]["pos"]

	var attack_direction = target_pos - pending_move_cell

	attack_direction = Vector2i(
		sign(attack_direction.x),
		sign(attack_direction.y)
	)

	units[selected_unit]["facing"] = attack_direction
	units[selected_unit]["has_acted"] = true

	if coverage_system.resolve_pending_coverage_if_needed(
		units,
		combat_logic,
		selected_unit,
		pending_coverage_enemies
	):
		return {
			"attacker_died": true,
			"defender_died": false,
			"attacker_remove_index": selected_unit,
			"defender_remove_index": -1,
			"awaiting_attack_confirmation": false,
			"pending_attack_target": -1
		}

	stamina_system.spend_movement_stamina(
		units,
		selected_unit,
		pending_move_distance
	)

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
		"attacker_remove_index": -1,
		"defender_remove_index": pending_attack_target,
		"awaiting_attack_confirmation": false,
		"pending_attack_target": -1
	}

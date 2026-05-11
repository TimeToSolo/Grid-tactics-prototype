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

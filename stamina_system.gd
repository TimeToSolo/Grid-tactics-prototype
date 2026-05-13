extends Node

# ==================================================
# STAMINA SYSTEM
# ==================================================
# Handles stamina spending, stamina display previews,
# and healer charge recovery.
# ==================================================


# =========================
# Spends stamina based on movement distance.
#
# Moving farther reduces remaining
# defensive reaction potential.
# =========================

func spend_movement_stamina(
	units: Array,
	unit_index: int,
	pending_move_distance: int
):

	if unit_index == -1:
		return

	var movement_cost = (
		pending_move_distance
		* units[unit_index]["move_stamina_cost"]
	)

	units[unit_index]["stamina"] = max(
		units[unit_index]["stamina"] - movement_cost,
		0
	)


# =========================
# Spends stamina when a unit attacks.
#
# Archer special rule:
# - firing consumes all remaining stamina
#
# Other classes:
# - spend their attack stamina cost
# =========================

func spend_attack_stamina(
	units: Array,
	unit_index: int
):

	if unit_index == -1:
		return

	if units[unit_index]["class"] == "archer":
		units[unit_index]["stamina"] = 0
		return

	units[unit_index]["stamina"] = max(
		units[unit_index]["stamina"]
		- units[unit_index]["attack_stamina_cost"],
		0
	)


# =========================
# Returns displayed stamina for a unit.
#
# Pending movement does not actually spend
# stamina until the action is confirmed,
# but the UI should preview expected stamina.
# =========================

func get_display_stamina(
	units: Array,
	unit_index: int,
	selected_unit: int,
	has_pending_move: bool,
	pending_move_distance: int
) -> int:

	if unit_index != selected_unit:
		return units[unit_index]["stamina"]

	if not has_pending_move:
		return units[unit_index]["stamina"]

	var movement_cost = (
		pending_move_distance
		* units[unit_index]["move_stamina_cost"]
	)

	return max(
		units[unit_index]["stamina"] - movement_cost,
		0
	)


# =========================
# Recovers healer charges based on
# remaining stamina at turn end.
#
# 90+ stamina = +2 charges
# 50+ stamina = +1 charge
# Below 50 = no recovery
# =========================

func recover_idle_healers(
	units: Array,
	team: String
):

	for unit in units:

		if unit["team"] != team:
			continue

		if unit["class"] != "healer":
			continue

		var recovery_amount = 0

		if (
			unit["stamina"]
			>= unit["charge_recovery_threshold_2"]
		):
			recovery_amount = 2

		elif (
			unit["stamina"]
			>= unit["charge_recovery_threshold_1"]
		):
			recovery_amount = 1

		unit["heal_charges"] = min(
			unit["heal_charges"] + recovery_amount,
			unit["max_heal_charges"]
		)

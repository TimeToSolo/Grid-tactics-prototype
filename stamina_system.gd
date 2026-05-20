extends Node

# ==================================================
# STAMINA SYSTEM
# ==================================================
# Handles:
# - movement stamina spending
# - attack stamina spending
# - support stamina spending
# - stamina display previews
# - healer charge recovery
# ==================================================

# ==================================================
# SHARED STAMINA CONSTANTS
# ==================================================

const INVALID_UNIT := -1
const MINIMUM_ARCHER_DAMAGE := 1

# =========================
# Returns true if a unit index
# is invalid or outside the
# current unit array.
# =========================

func unit_index_is_invalid(
	units: Array,
	unit_index: int
) -> bool:

	if unit_index == INVALID_UNIT:
		return true

	if unit_index >= units.size():
		return true

	return false

# =========================
# Returns stamina cost for
# moving a given distance.
# =========================

func get_movement_stamina_cost(
	unit,
	move_distance: int
) -> int:

	return (
		move_distance
		* unit["move_stamina_cost"]
	)

# =========================
# Spends stamina based on
# movement distance.
#
# Moving farther reduces
# remaining defensive reaction
# potential.
# =========================

func spend_movement_stamina(
	units: Array,
	unit_index: int,
	pending_move_distance: int
):

	if unit_index_is_invalid(
		units,
		unit_index
	):
		return

	var movement_cost = get_movement_stamina_cost(
		units[unit_index],
		pending_move_distance
	)

	units[unit_index]["stamina"] = max(
		units[unit_index]["stamina"] - movement_cost,
		0
	)

# =========================
# Returns projected archer
# damage based on current
# stamina.
#
# Archer stamina cost is tied
# to projected damage.
# =========================

func get_projected_archer_damage(
	unit
) -> int:

	var attack_damage = min(
		unit["attack"],
		int(
			floor(
				float(unit["stamina"])
				/ float(unit["stamina_per_damage"])
			)
		)
	)

	return max(
		attack_damage,
		MINIMUM_ARCHER_DAMAGE
	)

# =========================
# Spends stamina when a unit
# attacks.
#
# Archer special rule:
# - stamina spent is based on
#   current projected damage
#
# Other classes:
# - spend attack stamina cost
# =========================

func spend_attack_stamina(
	units: Array,
	unit_index: int
):

	if unit_index_is_invalid(
		units,
		unit_index
	):
		return

	if units[unit_index]["class"] == "archer":

		var attack_damage = get_projected_archer_damage(
			units[unit_index]
		)

		var stamina_cost = (
			attack_damage
			* units[unit_index]["stamina_per_damage"]
		)

		units[unit_index]["stamina"] = max(
			units[unit_index]["stamina"] - stamina_cost,
			0
		)

		return

	units[unit_index]["stamina"] = max(
		units[unit_index]["stamina"]
		- units[unit_index]["attack_stamina_cost"],
		0
	)

# =========================
# Returns displayed stamina
# for a unit.
#
# Pending movement does not
# actually spend stamina until
# the action is confirmed, but
# the UI should preview expected
# stamina.
# =========================

func get_display_stamina(
	units: Array,
	unit_index: int,
	selected_unit: int,
	has_pending_move: bool,
	pending_move_distance: int
) -> int:

	if unit_index_is_invalid(
		units,
		unit_index
	):
		return 0

	if unit_index != selected_unit:
		return units[unit_index]["stamina"]

	if not has_pending_move:
		return units[unit_index]["stamina"]

	var movement_cost = get_movement_stamina_cost(
		units[unit_index],
		pending_move_distance
	)

	return max(
		units[unit_index]["stamina"] - movement_cost,
		0
	)

# =========================
# Returns stamina cost for
# a support action.
#
# Supported actions:
# - heal
# - regen
# =========================

func get_support_stamina_cost(
	unit,
	support_action: String
) -> int:

	match support_action:

		"heal":
			return unit["heal_stamina_cost"]

		"regen":
			return unit["regen_stamina_cost"]

		_:
			return 0

# =========================
# Spends stamina for a
# support action.
#
# Support actions also consume
# one healer charge.
# =========================

func spend_support_stamina(
	units: Array,
	unit_index: int,
	support_action: String
):

	if unit_index_is_invalid(
		units,
		unit_index
	):
		return

	var stamina_cost = get_support_stamina_cost(
		units[unit_index],
		support_action
	)

	if stamina_cost <= 0:
		return

	units[unit_index]["stamina"] = max(
		units[unit_index]["stamina"] - stamina_cost,
		0
	)

	units[unit_index]["heal_charges"] -= 1

# =========================
# Returns healer charge
# recovery amount based on
# remaining stamina.
#
# Recovery thresholds are
# unit-data driven.
# =========================

func get_healer_charge_recovery_amount(
	unit
) -> int:

	if (
		unit["stamina"]
		>= unit["charge_recovery_threshold_2"]
	):
		return 2

	if (
		unit["stamina"]
		>= unit["charge_recovery_threshold_1"]
	):
		return 1

	return 0

# =========================
# Recovers healer charges
# based on remaining stamina
# at turn end.
#
# High stamina recovery:
# - +2 charges
#
# Medium stamina recovery:
# - +1 charge
#
# Low stamina recovery:
# - no recovery
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

		var recovery_amount = get_healer_charge_recovery_amount(
			unit
		)

		unit["heal_charges"] = min(
			unit["heal_charges"] + recovery_amount,
			unit["max_heal_charges"]
		)

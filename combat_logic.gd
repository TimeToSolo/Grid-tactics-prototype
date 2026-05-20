extends Node

# ==================================================
# COMBAT LOGIC
# ==================================================
# Handles direct combat math:
# - attack damage
# - archer stamina-based damage scaling
# - counter/reaction damage multipliers
# - healing
# - regeneration status setup
#
# This node should NOT remove units directly.
# It only mutates HP/status values and returns
# whether a target was defeated.
# ==================================================

# ==================================================
# SHARED COMBAT CONSTANTS
# ==================================================

const MINIMUM_DAMAGE := 1

# =========================
# Returns final attack damage.
#
# Handles:
# - base attack damage
# - archer stamina-based scaling
# - counter/reaction multipliers
#
# Does NOT apply damage.
# =========================

func get_attack_damage(
	attacker,
	damage_multiplier: float = 1.0
) -> int:

	var damage = attacker["attack"]

	if attacker["class"] == "archer":
		damage = get_archer_stamina_damage(attacker)

	return max(
		int(round(damage * damage_multiplier)),
		MINIMUM_DAMAGE
	)

# =========================
# Returns archer damage based
# on current stamina.
#
# Archer damage is capped by
# base attack and reduced as
# stamina falls.
#
# Always returns at least
# MINIMUM_DAMAGE.
# =========================

func get_archer_stamina_damage(
	attacker
) -> int:

	var stamina_damage = int(
		floor(
			float(attacker["stamina"])
			/ float(attacker["stamina_per_damage"])
		)
	)

	return max(
		min(
			attacker["attack"],
			stamina_damage
		),
		MINIMUM_DAMAGE
	)

# =========================
# Applies attack damage to
# the defender.
#
# Returns:
# - true if defender is defeated
# - false otherwise
# =========================

func resolve_attack(
	attacker,
	defender,
	damage_multiplier: float = 1.0
) -> bool:

	var damage = get_attack_damage(
		attacker,
		damage_multiplier
	)

	defender["hp"] -= damage

	return defender["hp"] <= 0

# =========================
# Applies instant healing
# to a unit.
#
# Healing cannot exceed max HP.
# =========================

func apply_heal(
	target,
	heal_amount: int
):

	target["hp"] = min(
		target["hp"] + heal_amount,
		target["max_hp"]
	)

# =========================
# Applies regeneration status
# to a unit.
#
# Actual regen healing is
# processed elsewhere at the
# start of that unit team's turn.
# =========================

func apply_regen(
	target,
	heal_amount: int,
	turns: int
):

	target["regen_amount"] = heal_amount
	target["regen_turns"] = turns

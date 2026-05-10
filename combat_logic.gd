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
# This file should NOT remove units directly.
# It only returns whether a defender was defeated.
# ==================================================


# =========================
# Resolves attack damage from one unit to another.
#
# damage_multiplier:
# - used for counter/reaction damage scaling
# - normal attacks use 1.0
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

	var damage = attacker["attack"]

	# Archer attacks scale with remaining stamina.
	if attacker["class"] == "archer":

		var stamina_ratio = (
			float(attacker["stamina"])
			/ float(attacker["max_stamina"])
		)

		damage = int(round(damage * stamina_ratio))

		damage = max(damage, 1)

	# Counter/reaction attacks can scale damage separately.
	damage = int(round(damage * damage_multiplier))

	defender["hp"] -= damage

	return defender["hp"] <= 0


# =========================
# Applies instant healing to a unit.
#
# Healing cannot exceed max HP.
# =========================

func apply_heal(target, heal_amount: int):

	target["hp"] = min(
		target["hp"] + heal_amount,
		target["max_hp"]
	)


# =========================
# Applies regeneration status to a unit.
#
# Actual regen healing is processed elsewhere
# at the start of that unit team's turn.
# =========================

func apply_regen(target, heal_amount: int, turns: int):

	target["regen_amount"] = heal_amount
	target["regen_turns"] = turns

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

	# Archer attacks lose damage based on
	# how many tiles worth of stamina were spent moving.
	if attacker["class"] == "archer":

		var spent_stamina = (
			attacker["max_stamina"]
			- attacker["stamina"]
		)

		var moved_tiles = int(round(
			float(spent_stamina)
			/ float(attacker["move_stamina_cost"])
		))

		var move_damage_penalty = 2

		if attacker.has("move_damage_penalty"):
			move_damage_penalty = attacker["move_damage_penalty"]

		damage = max(
			attacker["attack"] - moved_tiles * move_damage_penalty,
			1
		)

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

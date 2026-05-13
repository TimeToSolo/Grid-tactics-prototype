extends Node

# ==================================================
# UNIT DATA
# ==================================================
# Stores reusable unit class templates and creates
# complete unit dictionaries for map placement.
# ==================================================

var next_unit_id := 1

# ==================================================
# UNIT CLASS TEMPLATES
# ==================================================

var unit_templates = {
	"fighter": {
		"move": 5,
		"hp": 26,
		"attack": 9,
		"attack_stamina_cost": 45,
		"counter_stamina_cost": 35,
		"counter_damage_multiplier": 0.8
	},

	"tank": {
		"move": 4,
		"hp": 36,
		"attack": 8,
		"attack_stamina_cost": 50,
		"counter_stamina_cost": 25,
		"counter_damage_multiplier": 0.5
	},

	"lancer": {
		"move": 5,
		"hp": 22,
		"attack": 10,
		"attack_stamina_cost": 40,
		"counter_stamina_cost": 30,
		"counter_damage_multiplier": 0.8
	},

	"duelist": {
		"move": 6,
		"hp": 20,
		"attack": 11,
		"attack_stamina_cost": 30,
		"counter_stamina_cost": 30,
		"counter_damage_multiplier": 1.0
	},

	"healer": {
		"move": 4,
		"hp": 18,
		"attack": 5,
		"attack_stamina_cost": 20,
		"counter_stamina_cost": 999,
		"counter_damage_multiplier": 0.0,

		"heal_stamina_cost": 60,
		"regen_stamina_cost": 60,

		"charge_recovery_threshold_1": 50,
		"charge_recovery_threshold_2": 90,

		"heal_charges": 3,
		"max_heal_charges": 3
	},

	"archer": {
		"move": 5,
		"hp": 20,
		"attack": 10,
		"attack_stamina_cost": 999,
		"counter_stamina_cost": 999,
		"counter_damage_multiplier": 0.0
	}
}


# ==================================================
# DEFAULT STAMINA VALUES
# ==================================================

const DEFAULT_MAX_STAMINA = 100
const DEFAULT_MOVE_STAMINA_COST = 10


# =========================
# Creates a complete unit dictionary.
#
# Required:
# - unit_class: fighter/tank/lancer/etc.
# - team: player/enemy
# - pos: starting grid position
# - facing: starting facing direction
# =========================

func create_unit(
	unit_class: String,
	team: String,
	pos: Vector2i,
	facing: Vector2i,
	ai_profile: String = "barbarian"
) -> Dictionary:

	var template = unit_templates[unit_class]

	var unit = {
		"id": next_unit_id,
		"pos": pos,
		"move": template["move"],
		"facing": facing,

		"class": unit_class,
		"team": team,
		"ai_profile": ai_profile,

		"reaction_used": false,
		"has_acted": false,

		"hp": template["hp"],
		"max_hp": template["hp"],
		"attack": template["attack"],

		"max_stamina": DEFAULT_MAX_STAMINA,
		"stamina": DEFAULT_MAX_STAMINA,
		"move_stamina_cost": DEFAULT_MOVE_STAMINA_COST,
		"attack_stamina_cost": template["attack_stamina_cost"],
		"counter_stamina_cost": template["counter_stamina_cost"],
		"counter_damage_multiplier": template["counter_damage_multiplier"]
	}

	if unit_class == "healer":

		unit["heal_charges"] = template["heal_charges"]
		unit["max_heal_charges"] = template["max_heal_charges"]

		unit["heal_stamina_cost"] = template["heal_stamina_cost"]
		unit["regen_stamina_cost"] = template["regen_stamina_cost"]

		unit["charge_recovery_threshold_1"] = (
			template["charge_recovery_threshold_1"]
		)

		unit["charge_recovery_threshold_2"] = (
			template["charge_recovery_threshold_2"]
		)

	next_unit_id += 1

	return unit

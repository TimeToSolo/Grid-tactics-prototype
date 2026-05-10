extends Node

# ==================================================
# UNIT DATA
# ==================================================
# Stores reusable unit class templates and creates
# complete unit dictionaries for map placement.
# ==================================================


# ==================================================
# UNIT CLASS TEMPLATES
# ==================================================

var unit_templates = {
	"fighter": {
		"move": 5,
		"hp": 26,
		"attack": 9,
		"stance": "prepare",
		"attack_stamina_cost": 45,
		"counter_stamina_cost": 35,
		"counter_damage_multiplier": 0.8
	},

	"tank": {
		"move": 4,
		"hp": 36,
		"attack": 8,
		"stance": "prepare",
		"attack_stamina_cost": 50,
		"counter_stamina_cost": 25,
		"counter_damage_multiplier": 0.5
	},

	"lancer": {
		"move": 5,
		"hp": 22,
		"attack": 10,
		"stance": "prepare",
		"attack_stamina_cost": 40,
		"counter_stamina_cost": 30,
		"counter_damage_multiplier": 0.8
	},

	"duelist": {
		"move": 6,
		"hp": 20,
		"attack": 11,
		"stance": "prepare",
		"attack_stamina_cost": 30,
		"counter_stamina_cost": 30,
		"counter_damage_multiplier": 1.0
	},

	"healer": {
		"move": 5,
		"hp": 18,
		"attack": 5,
		"stance": "attack",
		"attack_stamina_cost": 20,
		"counter_stamina_cost": 999,
		"counter_damage_multiplier": 0.0,
		"heal_charges": 3,
		"max_heal_charges": 3
	},

	"archer": {
		"move": 5,
		"hp": 20,
		"attack": 10,
		"stance": "attack",
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


# ==================================================
# UNIT CREATION
# ==================================================

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
	facing: Vector2i
) -> Dictionary:

	var template = unit_templates[unit_class]

	var unit = {
		"pos": pos,
		"move": template["move"],
		"facing": facing,

		"class": unit_class,
		"team": team,

		"stance": template["stance"],
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

	return unit

extends Node


# ==================================================
# MISSION OBJECTIVES
# ==================================================
# Handles:
# - mission objective state
# - victory checks
# - defeat checks
# - staged objective events
# ==================================================


var active_objective_type := "rout"
var objective_stage := 0
var enemies_defeated := 0
var objective_data := {}

# =========================
# Sets active mission
# objective type.
# =========================

var objective_zones := {}

func setup_objective(
	data: Dictionary,
	zones: Dictionary = {}
):

	objective_data = data
	objective_zones = zones
	active_objective_type = data.get("type", "rout")
	objective_stage = 0
	enemies_defeated = 0

# =========================
# Records enemy defeat for
# objective tracking.
# =========================

func record_enemy_defeated():

	enemies_defeated += 1


# =========================
# Returns mission result
# based on current battle
# and objective state.
# =========================

func get_mission_result(
	units: Array
) -> String:

	if not player_units_exist(units):
		return "defeat"

	if active_objective_type == "layered":
		return get_layered_objective_result(units)

	if active_objective_type == "rout":
		return get_rout_result(units)

	return ""

# =========================
# Returns rout objective
# result.
# =========================

func get_rout_result(units: Array) -> String:

	if not enemy_units_exist(units):
		return "victory"

	return ""

# =========================
# Returns layered objective
# result for current stage.
# =========================

func get_layered_objective_result(units: Array) -> String:

	var stages = objective_data.get("stages", [])

	if objective_stage >= stages.size():
		return ""

	var stage = stages[objective_stage]

	match stage.get("type", ""):

		"defeat_enemy_count":

			var required_count = stage.get(
				"required_count",
				0
			)

			if enemies_defeated >= required_count:

				objective_stage += 1

				return stage.get(
					"on_complete",
					""
				)

		"rout":

			if not enemy_units_exist(units):

				objective_stage += 1

				return stage.get(
					"on_complete",
					""
				)

		"retreat":

			var zone_name = stage.get(
				"zone",
				"retreat_zone"
			)

			var target_area = objective_zones.get(
				zone_name,
				[]
			)

			if all_player_units_in_area(
				units,
				target_area
			):

				objective_stage += 1

				return stage.get(
					"on_complete",
					""
				)

	return ""

# =========================
# Returns true if any player
# unit remains alive.
# =========================

func player_units_exist(units: Array) -> bool:

	for unit in units:
		if unit["team"] == "player":
			return true

	return false


# =========================
# Returns true if any enemy
# unit remains alive.
# =========================

func enemy_units_exist(units: Array) -> bool:

	for unit in units:
		if unit["team"] == "enemy":
			return true

	return false


# =========================
# Returns true if all player
# units are inside target area.
# =========================

func all_player_units_in_area(
	units: Array,
	target_area: Array[Vector2i]
) -> bool:

	if target_area.is_empty():
		return false

	for unit in units:

		if unit["team"] != "player":
			continue

		if not target_area.has(unit["pos"]):
			return false

	return true

# =========================
# Returns current objective
# stage.
# =========================

func get_objective_stage() -> int:

	return objective_stage

# =========================
# Returns current enemy
# defeat count.
# =========================

func get_enemies_defeated() -> int:

	return enemies_defeated

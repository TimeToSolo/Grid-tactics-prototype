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

func setup_objective(data: Dictionary):

	objective_data = data
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
	units: Array,
	player_start_area: Array[Vector2i]
) -> String:

	if not player_units_exist(units):
		return "defeat"

	match active_objective_type:

		"retreat":
			return get_retreat_result(
				units,
				player_start_area
			)

		"rout":
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
# Returns retreat objective
# result.
#
# Stage 0:
# defeat initial enemies.
#
# Stage 1:
# retreat to extraction area.
# =========================

func get_retreat_result(
	units: Array,
	player_start_area: Array[Vector2i]
) -> String:

	if objective_stage == 0:

		var required_defeats = objective_data.get(
			"initial_enemy_defeat_count",
			0
		)

		if enemies_defeated >= required_defeats:
			objective_stage = 1
			return "spawn_reinforcements"

		return ""

	if objective_stage == 1:

		if all_player_units_in_area(
			units,
			player_start_area
		):
			return "victory"

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

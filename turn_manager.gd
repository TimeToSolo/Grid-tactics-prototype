extends Node

# ==================================================
# TURN MANAGER
# ==================================================
# Handles:
# - active team tracking
# - turn swapping
# - start-of-turn unit refresh
# - stamina recovery
# - regeneration healing
# ==================================================


# ==================================================
# TURN STATE
# ==================================================

var team_order: Array[String] = ["player", "enemy"]
var current_team_index := 0
var current_team: String = team_order[current_team_index]

# ==================================================
# DIFFICULTY SETTINGS
# ==================================================

enum Difficulty {
	CASUAL,
	NORMAL,
	HARD
}

var current_difficulty := Difficulty.NORMAL

# =========================
# Returns stamina recovery
# amount based on:
# - difficulty
# - active team
# =========================

func get_stamina_refresh(team: String) -> int:

	match current_difficulty:

		Difficulty.CASUAL:

			if team == "player":
				return 100

			return 80

		Difficulty.NORMAL:
			return 80

		Difficulty.HARD:

			if team == "player":
				return 70

			return 90

	return 80

# ==================================================
# TURN FLOW
# ==================================================

# =========================
# Advances to the next team's turn.
#
# After changing teams, refreshes all units
# belonging to the new active team.
# =========================

func end_turn(units: Array):
	current_team_index = (current_team_index + 1) % team_order.size()
	current_team = team_order[current_team_index]
	refresh_team_units(units, current_team)


# =========================
# Refreshes units at the start of a team's turn.
#
# Refresh includes:
# - restoring action state
# - recovering stamina
# - applying regeneration healing
# =========================

func refresh_team_units(
	units: Array,
	team: String
):

	for unit in units:

		if unit["team"] != team:
			continue

		unit["has_acted"] = false
		unit["reaction_used"] = false

		var stamina_refresh = get_stamina_refresh(team)

		unit["stamina"] = min(
			unit["stamina"] + stamina_refresh,
			unit["max_stamina"]
		)

		apply_regen_if_active(unit)


# ==================================================
# STATUS EFFECTS
# ==================================================

# =========================
# Applies regeneration healing if active.
#
# Regen:
# - heals at the start of the unit team's turn
# - cannot exceed max HP
# - loses 1 remaining turn after triggering
# =========================

func apply_regen_if_active(unit: Dictionary):

	if not unit.has("regen_turns"):
		return

	if unit["regen_turns"] <= 0:
		return

	unit["hp"] = min(
		unit["hp"] + unit["regen_amount"],
		unit["max_hp"]
	)

	unit["regen_turns"] -= 1

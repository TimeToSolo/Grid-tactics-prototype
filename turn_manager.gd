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

var current_team = "player"


# ==================================================
# TURN FLOW
# ==================================================

# =========================
# Advances to the next team's turn.
#
# After changing teams, refreshes all units
# belonging to the new active team.
# =========================

func end_turn(units):

	if current_team == "player":
		current_team = "enemy"
	else:
		current_team = "player"

	refresh_team_units(units, current_team)


# =========================
# Refreshes units at the start of a team's turn.
#
# Refresh includes:
# - clearing action state
# - clearing old reaction state
# - restoring stamina
# - applying regeneration healing
# =========================

func refresh_team_units(units, team):

	for unit in units:

		if unit["team"] != team:
			continue

		unit["has_acted"] = false
		unit["reaction_used"] = false
		unit["stamina"] = unit["max_stamina"]

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

func apply_regen_if_active(unit):

	if not unit.has("regen_turns"):
		return

	if unit["regen_turns"] <= 0:
		return

	unit["hp"] = min(
		unit["hp"] + unit["regen_amount"],
		unit["max_hp"]
	)

	unit["regen_turns"] -= 1

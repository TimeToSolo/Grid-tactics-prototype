extends Node

# ==================================================
# MISSION FLOW CONTROLLER
# ==================================================
# Handles:
# - campaign mission ids
# - mission selection state
# - mission map path lookup
# - mission flow state
# - campaign progression flow
#
# Main remains responsible for:
# - battle loading
# - battle execution
# - gameplay systems
# ==================================================


# =========================
# Ordered campaign mission ids.
#
# Used for:
# - mission browsing
# - mission loading
# - campaign progression
# =========================

var campaign_level_ids := [
	"01a_retreat",
	"01b_hold",
	"01c_vaeren"
]


# =========================
# Currently selected mission
# index in the campaign list.
# =========================

var campaign_level_index := 0


# =========================
# Current mission flow state.
#
# Examples:
# - battle
# - deployment
# - victory
# - defeat
# - vn_intro
# - vn_outro
# =========================

var mission_state := "battle"

# =========================
# Sets current mission flow
# state.
# =========================

func set_mission_state(new_state: String):

	mission_state = new_state


# =========================
# Returns current mission
# flow state.
# =========================

func get_mission_state() -> String:

	return mission_state

# =========================
# Returns current mission data.
#
# Centralized mission lookup
# used by:
# - mission loading
# - campaign progression
# - save systems
# - flow transitions
# =========================

func get_current_mission_data() -> Dictionary:

	var mission_id = get_campaign_level_id()

	return {
		"id": mission_id,
		"map_path": get_campaign_level_path(),
		"title": mission_id
	}

# =========================
# Returns objective type for
# the selected campaign mission.
# =========================

func get_current_objective_type() -> String:

	var mission_id = get_campaign_level_id()

	match mission_id:

		"01a_retreat":
			return "retreat"

		_:
			return "rout"

# =========================
# Returns currently selected
# campaign mission id.
# =========================

func get_campaign_level_id() -> String:

	return campaign_level_ids[campaign_level_index]


# =========================
# Returns repository map path
# for the selected mission.
# =========================

func get_campaign_level_path() -> String:

	return (
		"res://campaign/levels/"
		+ get_campaign_level_id()
		+ ".json"
	)


# =========================
# Changes selected campaign
# mission index.
#
# Negative = previous
# Positive = next
# =========================

func change_campaign_level(direction: int):

	campaign_level_index += direction

	if campaign_level_index < 0:
		campaign_level_index = (
			campaign_level_ids.size() - 1
		)

	if campaign_level_index >= campaign_level_ids.size():
		campaign_level_index = 0

# =========================
# Advances to the next
# campaign mission.
# =========================

func advance_to_next_mission():

	change_campaign_level(1)


# =========================
# Returns true if current
# mission is the final
# campaign mission.
# =========================

func is_final_mission() -> bool:

	return (
		campaign_level_index
		>= campaign_level_ids.size() - 1
	)

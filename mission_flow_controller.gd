extends Node


# ==================================================
# MISSION FLOW CONTROLLER
# ==================================================
# Handles:
# - current campaign mission id
# - campaign level path lookup
# - future mission transitions
# - future VN/battle segment flow
#
# Main remains responsible for:
# - actually loading map data for now
# - starting battle flow
# - resolving battle gameplay
# ==================================================


var campaign_level_ids := [
	"01a_retreat",
	"01b_hold",
	"01c_vaeren"
]

var campaign_level_index := 0


func get_campaign_level_id() -> String:

	return campaign_level_ids[campaign_level_index]


func get_campaign_level_path() -> String:

	return (
		"res://campaign/levels/"
		+ get_campaign_level_id()
		+ ".json"
	)


func change_campaign_level(direction: int):

	campaign_level_index += direction

	if campaign_level_index < 0:
		campaign_level_index = campaign_level_ids.size() - 1

	if campaign_level_index >= campaign_level_ids.size():
		campaign_level_index = 0

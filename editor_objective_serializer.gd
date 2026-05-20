extends Node

# ==================================================
# EDITOR OBJECTIVE SERIALIZER
# ==================================================
# Converts editor objective data between:
# - runtime editor state
# - JSON-safe save data
#
# Main/editor systems can use this node
# without needing to know the save format.
# ==================================================

# =========================
# Builds JSON-safe objective
# data from the current editor
# objective configuration.
# =========================

func build_objective_data_from_editor(
	editor_state
) -> Dictionary:

	return {
		"type": "layered",
		"stages": editor_state.editor_objective_stages.duplicate(true),
		"objective_zones": serialize_objective_zones(editor_state)
	}


# =========================
# Converts runtime objective
# zone Vector2i arrays into
# JSON-safe dictionary data.
# =========================

func serialize_objective_zones(
	editor_state
) -> Dictionary:

	var serialized = {}

	for zone_name in editor_state.objective_zones.keys():

		serialized[zone_name] = []

		for cell in editor_state.objective_zones[zone_name]:

			serialized[zone_name].append({
				"x": cell.x,
				"y": cell.y
			})

	return serialized


# =========================
# Restores serialized objective
# zone save data back into
# runtime Vector2i arrays.
# =========================

func deserialize_objective_zones(
	editor_state,
	data: Dictionary
):

	editor_state.objective_zones.clear()

	for zone_name in data.keys():

		editor_state.objective_zones[zone_name] = []

		for entry in data[zone_name]:

			editor_state.objective_zones[zone_name].append(
				Vector2i(
					entry["x"],
					entry["y"]
				)
			)

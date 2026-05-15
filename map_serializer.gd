extends Node

# =========================
# Saves current map state
# to a JSON file.
# =========================

func save_map(
	map_data,
	units: Array,
	file_path: String
):

	var save_data = {
		"width": map_data.grid_width,
		"height": map_data.grid_height,
		"terrain_map": map_data.terrain_map,
		"units": []
	}

	for unit in units:

		save_data["units"].append({
			"class": unit["class"],
			"team": unit["team"],
			"ai_profile": unit["ai_profile"],
			"pos_x": unit["pos"].x,
			"pos_y": unit["pos"].y,
			"facing_x": unit["facing"].x,
			"facing_y": unit["facing"].y,
			"home_x": unit["home_pos"].x,
			"home_y": unit["home_pos"].y,
			"home_facing_x": unit["home_facing"].x,
			"home_facing_y": unit["home_facing"].y,
			"leash_range": unit["leash_range"]
		})

	DirAccess.make_dir_recursive_absolute("user://maps")

	var file = FileAccess.open(file_path, FileAccess.WRITE)

	if file == null:
		print("Failed to save map: ", file_path)
		return

	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()

	print("Saved map to: ", file_path)


# =========================
# Loads map state from JSON.
# =========================

func load_map(
	map_data,
	units: Array,
	unit_data,
	file_path: String
):

	if not FileAccess.file_exists(file_path):
		print("Map file does not exist: ", file_path)
		return

	var file = FileAccess.open(file_path, FileAccess.READ)

	if file == null:
		print("Failed to load map: ", file_path)
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()

	if json.parse(json_text) != OK:
		print("Failed to parse map JSON.")
		return

	var data = json.data

	map_data.grid_width = data["width"]
	map_data.grid_height = data["height"]
	map_data.terrain_map = data["terrain_map"]

	units.clear()

	for unit_info in data["units"]:

		var ai_profile = "barbarian"

		if unit_info.has("ai_profile"):
			ai_profile = unit_info["ai_profile"]

		var unit = unit_data.create_unit(
			unit_info["class"],
			unit_info["team"],
			Vector2i(
				unit_info["pos_x"],
				unit_info["pos_y"]
			),
			Vector2i(
				unit_info["facing_x"],
				unit_info["facing_y"]
			),
			ai_profile
		)

		if unit_info.has("home_x"):
			unit["home_pos"] = Vector2i(
				unit_info["home_x"],
				unit_info["home_y"]
			)

		if unit_info.has("home_facing_x"):
			unit["home_facing"] = Vector2i(
				unit_info["home_facing_x"],
				unit_info["home_facing_y"]
			)

		if unit_info.has("leash_range"):
			unit["leash_range"] = unit_info["leash_range"]

		units.append(unit)

	print("Loaded map from: ", file_path)

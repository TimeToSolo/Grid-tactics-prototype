extends Node

# ==================================================
# PATH PREVIEW SYSTEM
# ==================================================
# Builds cursor-traced hover paths and detects
# coverage-trigger warning tiles.
# ==================================================


# =========================
# Updates cursor-traced hover path.
#
# Rules:
# - invalid hover clears path
# - hovering start begins path
# - adjacent hover extends path
# - hovering earlier path tile trims path
# - jumping to another valid tile recalculates shortest path
# =========================

func update_hover_path(
	current_path: Array[Vector2i],
	map_data,
	units: Array,
	unit_query,
	selected_unit: int,
	selected_unit_start_cell: Vector2i,
	hovered_cell: Vector2i,
	move_tiles: Array[Vector2i]
) -> Array[Vector2i]:

	if selected_unit == -1:
		return []

	if move_tiles.is_empty():
		return []

	if not move_tiles.has(hovered_cell):
		return []

	if hovered_cell == selected_unit_start_cell:
		return [selected_unit_start_cell]

	if current_path.is_empty():
		return _get_shortest_path_to_hover(
			map_data,
			units,
			unit_query,
			selected_unit,
			selected_unit_start_cell,
			hovered_cell
		)

	if current_path.has(hovered_cell):

		var trim_index = current_path.find(hovered_cell)
		return current_path.slice(0, trim_index + 1)

	var last_cell = current_path[current_path.size() - 1]

	if map_data.get_grid_distance(last_cell, hovered_cell) == 1:

		var new_path = current_path.duplicate()
		new_path.append(hovered_cell)

		# Path includes the starting tile, so spent movement is size - 1.
		var movement_spent = new_path.size() - 1

		if movement_spent > units[selected_unit]["move"]:

			return _get_shortest_path_to_hover(
				map_data,
				units,
				unit_query,
				selected_unit,
				selected_unit_start_cell,
				hovered_cell
			)

		return new_path

	return _get_shortest_path_to_hover(
		map_data,
		units,
		unit_query,
		selected_unit,
		selected_unit_start_cell,
		hovered_cell
	)


# =========================
# Builds preview data from an existing path.
#
# Returns:
# - path_cells
# - danger_cells
# - countering_units
# =========================

func get_path_preview_from_path(
	units: Array,
	coverage_system,
	unit_logic,
	selected_unit: int,
	path_cells: Array[Vector2i]
) -> Dictionary:

	if selected_unit == -1:
		return {}

	if path_cells.is_empty():
		return {}

	var danger_cells: Array[Vector2i] = []
	var countering_units: Array[int] = []

	for i in range(1, path_cells.size()):

		var previous_cell = path_cells[i - 1]
		var current_cell = path_cells[i]

		var step_path: Array[Vector2i] = [
			previous_cell,
			current_cell
		]

		var entered_enemies = coverage_system.get_enemies_entered_coverage_along_path(
			units,
			unit_logic,
			selected_unit,
			step_path
		)

		if entered_enemies.is_empty():
			continue

		danger_cells.append(current_cell)

		for enemy in entered_enemies:
			if not countering_units.has(enemy):
				countering_units.append(enemy)

	return {
		"path_cells": path_cells,
		"danger_cells": danger_cells,
		"countering_units": countering_units
	}

# =========================
# Fallback helper for when cursor jumps
# to another valid tile.
# =========================

func _get_shortest_path_to_hover(
	map_data,
	units: Array,
	unit_query,
	selected_unit: int,
	selected_unit_start_cell: Vector2i,
	hovered_cell: Vector2i
) -> Array[Vector2i]:

	var path_data = map_data.get_movement_path_data(
		selected_unit_start_cell,
		hovered_cell,
		units[selected_unit]["move"],
		unit_query.get_enemy_occupied_tiles(
			units,
			selected_unit
		)
	)

	if path_data.is_empty():
		return []

	return path_data["path_cells"]

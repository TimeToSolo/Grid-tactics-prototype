extends Node

# =========================
# Paints terrain onto the map.
# =========================

func paint_tile(
	map_data,
	cell: Vector2i,
	tile_symbol: String
):

	if not map_data.is_inside_grid(cell):
		return

	var row = map_data.terrain_map[cell.y]

	row = (
		row.substr(0, cell.x)
		+ tile_symbol
		+ row.substr(cell.x + 1)
	)

	map_data.terrain_map[cell.y] = row

# =========================
# Fills a rectangular region
# with the selected terrain tile.
# =========================

func fill_rect(
	map_data,
	start_cell: Vector2i,
	end_cell: Vector2i,
	tile_symbol: String
):

	var min_x = min(start_cell.x, end_cell.x)
	var max_x = max(start_cell.x, end_cell.x)

	var min_y = min(start_cell.y, end_cell.y)
	var max_y = max(start_cell.y, end_cell.y)

	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):

			paint_tile(
				map_data,
				Vector2i(x, y),
				tile_symbol
			)

# =========================
# Removes any unit at a cell.
# =========================

func remove_unit_at(
	units: Array,
	unit_query,
	cell: Vector2i
):

	var unit_index = unit_query.get_unit_at(
		units,
		cell
	)

	if unit_index == -1:
		return

	units.remove_at(unit_index)


# =========================
# Places a unit at a cell.
#
# Uses UnitData templates.
# Also assigns the unit's AI profile
# for automated behavior.
# =========================

func place_unit(
	units: Array,
	unit_query,
	unit_data,
	map_data,
	cell: Vector2i,
	unit_class: String,
	team: String,
	facing: Vector2i,
	ai_profile: String = "barbarian"
):

	if not map_data.is_inside_grid(cell):
		return

	if map_data.blocks_movement(cell):
		return

	remove_unit_at(
		units,
		unit_query,
		cell
	)

	var unit = unit_data.create_unit(
		unit_class,
		team,
		cell,
		facing,
		ai_profile
	)

	units.append(unit)

# =========================
# Moves terrain and units inside
# a selected rectangle by offset.
#
# Cancels if the move would place
# anything outside the map.
# =========================

func move_selection(
	map_data,
	units: Array,
	start_cell: Vector2i,
	end_cell: Vector2i,
	offset: Vector2i
):

	if offset == Vector2i.ZERO:
		return

	var copied_tiles = []
	var copied_units = []

	# =========================
	# First verify destination
	# stays inside map.
	# =========================

	for y in range(start_cell.y, end_cell.y + 1):
		for x in range(start_cell.x, end_cell.x + 1):

			var source_cell = Vector2i(x, y)
			var target_cell = source_cell + offset

			if not map_data.is_inside_grid(source_cell):
				return

			if not map_data.is_inside_grid(target_cell):
				return

	# =========================
	# Copy terrain.
	# =========================

	for y in range(start_cell.y, end_cell.y + 1):
		for x in range(start_cell.x, end_cell.x + 1):

			var source_cell = Vector2i(x, y)

			copied_tiles.append({
				"cell": source_cell,
				"symbol": map_data.get_tile_symbol(source_cell)
			})

	# =========================
	# Copy units inside selection.
	# =========================

	for unit in units:

		var pos = unit["pos"]

		if (
			pos.x >= start_cell.x
			and pos.x <= end_cell.x
			and pos.y >= start_cell.y
			and pos.y <= end_cell.y
		):
			copied_units.append(unit.duplicate(true))

	# =========================
	# Clear source terrain.
	# =========================

	for tile_data in copied_tiles:

		paint_tile(
			map_data,
			tile_data["cell"],
			"."
		)

	# =========================
	# Remove source units.
	# =========================

	for i in range(units.size() - 1, -1, -1):

		var pos = units[i]["pos"]

		if (
			pos.x >= start_cell.x
			and pos.x <= end_cell.x
			and pos.y >= start_cell.y
			and pos.y <= end_cell.y
		):
			units.remove_at(i)

	# =========================
	# Remove units currently occupying
	# destination cells.
	#
	# Moved units replace existing units
	# instead of stacking on top of them.
	# =========================

	for i in range(units.size() - 1, -1, -1):

		var pos = units[i]["pos"]

		for tile_data in copied_tiles:

			var target_cell = tile_data["cell"] + offset

			if pos == target_cell:
				units.remove_at(i)
				break

	# =========================
	# Paint terrain at destination.
	# =========================

	for tile_data in copied_tiles:

		var target_cell = tile_data["cell"] + offset

		paint_tile(
			map_data,
			target_cell,
			tile_data["symbol"]
		)

	# =========================
	# Place copied units at destination.
	# =========================

	for unit in copied_units:

		unit["pos"] += offset
		units.append(unit)

extends Node

# ==================================================
# EDITOR SYSTEM
# ==================================================
# Handles:
# - terrain painting
# - editor unit placement/removal
# - rectangle movement
# - editor palette helpers
# - AI profile validation
# - editor map slot helpers
# ==================================================

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
# Removes the unit occupying
# a grid cell, if one exists.
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
#
# Defender units automatically
# receive default leash data.
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

	if ai_profile == "defender":
		unit["home_pos"] = cell
		unit["leash_range"] = 3

	units.append(unit)

# =========================
# Returns true if a cell lies
# inside a rectangular region.
#
# Rectangle bounds are inclusive.
# =========================

func is_cell_inside_rect(
	cell: Vector2i,
	start_cell: Vector2i,
	end_cell: Vector2i
) -> bool:

	return (
		cell.x >= start_cell.x
		and cell.x <= end_cell.x
		and cell.y >= start_cell.y
		and cell.y <= end_cell.y
	)

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

		if is_cell_inside_rect(
			pos,
			start_cell,
			end_cell
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

		if is_cell_inside_rect(
			pos,
			start_cell,
			end_cell
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

		if unit.has("home_pos"):
			unit["home_pos"] += offset

		units.append(unit)

# ==================================================
# DEFENDER / LEASH HELPERS
# ==================================================

# =========================
# Increases leash range for
# a specific unit index.
#
# This is a helper function.
# The main editor node must pass
# in the units array and selected
# unit index.
# =========================

func increase_unit_leash_range(
	editor_state,
	units: Array,
	unit_index: int
):

	if unit_index == editor_state.INVALID_UNIT:
		return

	if unit_index >= units.size():
		return

	if not units[unit_index].has("leash_range"):
		return

	units[unit_index]["leash_range"] += 1


# =========================
# Decreases leash range for
# a specific unit index.
#
# This is a helper function.
# The main editor node must pass
# in the units array and selected
# unit index.
#
# Leash range cannot go below 0.
# =========================

func decrease_unit_leash_range(
	editor_state,
	units: Array,
	unit_index: int
):

	if unit_index == editor_state.INVALID_UNIT:
		return

	if unit_index >= units.size():
		return

	if not units[unit_index].has("leash_range"):
		return

	units[unit_index]["leash_range"] = max(
		0,
		units[unit_index]["leash_range"] - 1
	)

# =========================
# Returns current editor map path.
# =========================

func get_editor_map_path(editor_state) -> String:

	return (
	"user://maps/map_"
	+ str(editor_state.editor_map_slot)
	+ ".json"
)

# =========================
# Changes active editor map slot.
# =========================

func change_editor_map_slot(
	editor_state,
	direction: int
):

	editor_state.editor_map_slot += direction

	if editor_state.editor_map_slot < 1:
		editor_state.editor_map_slot = editor_state.MAX_EDITOR_MAP_SLOTS

	if editor_state.editor_map_slot > editor_state.MAX_EDITOR_MAP_SLOTS:
		editor_state.editor_map_slot = 1

# =========================
# Returns true if a cell is
# inside the current selected
# editor rectangle area.
#
# Used for selection movement
# and drag detection.
# =========================

func editor_cell_is_inside_selected_area(
	editor_state,
	cell: Vector2i
) -> bool:

	if editor_state.editor_selected_rect_start == editor_state.INVALID_CELL:
		return false

	if editor_state.editor_selected_rect_end == editor_state.INVALID_CELL:
		return false

	return (
		cell.x >= editor_state.editor_selected_rect_start.x
		and cell.x <= editor_state.editor_selected_rect_end.x
		and cell.y >= editor_state.editor_selected_rect_start.y
		and cell.y <= editor_state.editor_selected_rect_end.y
	)

# =========================
# Rotates editor unit facing
# clockwise through 8 directions.
# =========================

func rotate_editor_facing(editor_state):

	var directions = [
		Vector2i(0, -1),   # N
		Vector2i(1, -1),   # NE
		Vector2i(1, 0),    # E
		Vector2i(1, 1),    # SE
		Vector2i(0, 1),    # S
		Vector2i(-1, 1),   # SW
		Vector2i(-1, 0),   # W
		Vector2i(-1, -1)   # NW
	]

	var current_index = directions.find(
		editor_state.selected_editor_facing
	)

	if current_index == -1:
		editor_state.selected_editor_facing = Vector2i(0, -1)
		return

	var next_index = (current_index + 1) % directions.size()

	editor_state.selected_editor_facing = directions[next_index]

# =========================
# Cycles editor palette mode.
# =========================

func cycle_editor_palette(editor_state):

	if not editor_state.editor_mode:
		return

	if editor_state.editor_palette == "terrain":
		editor_state.editor_palette = "player_unit"
	elif editor_state.editor_palette == "player_unit":
		editor_state.editor_palette = "enemy_unit"
	elif editor_state.editor_palette == "enemy_unit":
		editor_state.editor_palette = "reinforcement"
	elif editor_state.editor_palette == "reinforcement":
		editor_state.editor_palette = "zone"
	elif editor_state.editor_palette == "zone":
		editor_state.editor_palette = "select"
	else:
		editor_state.editor_palette = "terrain"

# =========================
# Cycles the AI profile used
# when placing units in editor mode.
#
# Only AI profiles valid for the
# selected unit class are available.
# =========================

func cycle_editor_ai_profile(editor_state):

	var valid_profiles = get_valid_editor_ai_profiles(
		editor_state
	)

	var current_index = valid_profiles.find(
		editor_state.selected_editor_ai_profile
	)

	if current_index == -1:

		editor_state.selected_editor_ai_profile = valid_profiles[0]
		return

	var next_index = (
		current_index + 1
	) % valid_profiles.size()

	editor_state.selected_editor_ai_profile = valid_profiles[next_index]

# =========================
# Returns valid AI profiles for
# the currently selected unit class.
# =========================

func get_valid_editor_ai_profiles(editor_state) -> Array:

	if editor_state.editor_ai_profiles_by_class.has(
		editor_state.selected_editor_unit_class
	):
		return editor_state.editor_ai_profiles_by_class[
			editor_state.selected_editor_unit_class
		]

	return ["barbarian"]

# =========================
# Ensures selected AI profile
# is valid for the selected class.
# =========================

func validate_selected_editor_ai_profile(editor_state):

	var valid_profiles = get_valid_editor_ai_profiles(
		editor_state
	)

	if valid_profiles.has(
		editor_state.selected_editor_ai_profile
	):
		return

	editor_state.selected_editor_ai_profile = valid_profiles[0]

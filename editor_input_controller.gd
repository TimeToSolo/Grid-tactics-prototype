extends Node

# ==================================================
# EDITOR INPUT CONTROLLER
# ==================================================
# Handles editor-only keyboard and mouse input.
#
# Main.gd should remain responsible for:
# - toggling editor mode
# - battle flow
# - non-editor tactical input
# ==================================================

# =========================
# Handles editor keyboard input.
#
# Returns true if input was used.
# =========================

func handle_keyboard_input(
	event,
	editor_state,
	editor_system,
	mission_flow_controller,
	map_data,
	units: Array,
	unit_data,
	map_serializer,
	current_objective_data: Dictionary,
	editor_objective_serializer
) -> bool:

	match event.keycode:

		KEY_A:
			editor_system.cycle_editor_ai_profile(editor_state)
			return true

		KEY_F:
			editor_system.rotate_editor_facing(editor_state)
			return true

		KEY_M:
			editor_state.editor_resize_mode = true
			editor_state.editor_resize_width = map_data.grid_width
			editor_state.editor_resize_height = map_data.grid_height
			return true

		KEY_S:
			if event.ctrl_pressed:
				save_editor_map_data(
					editor_state,
					editor_system,
					map_data,
					units,
					map_serializer,
					current_objective_data,
					editor_objective_serializer
				)
				return true

		KEY_L:
			if event.ctrl_pressed:
				load_editor_map_data(
					editor_state,
					editor_system,
					map_data,
					units,
					unit_data,
					map_serializer,
					current_objective_data,
					editor_objective_serializer
				)
				return true

		KEY_F5:
			save_editor_map_data(
				editor_state,
				editor_system,
				map_data,
				units,
				map_serializer,
				current_objective_data,
				editor_objective_serializer
			)
			return true

		KEY_F6:
			load_editor_map_data(
					editor_state,
					editor_system,
					map_data,
					units,
					unit_data,
					map_serializer,
					current_objective_data,
					editor_objective_serializer
				)
			return true

		KEY_COMMA:
			mission_flow_controller.change_campaign_level(-1)
			return true

		KEY_PERIOD:
			mission_flow_controller.change_campaign_level(1)
			return true

		KEY_TAB:
			editor_system.cycle_editor_palette(editor_state)
			return true

		KEY_BRACKETLEFT:
			editor_system.change_editor_map_slot(editor_state, -1)
			return true

		KEY_BRACKETRIGHT:
			editor_system.change_editor_map_slot(editor_state, 1)
			return true

		KEY_EQUAL:
			if editor_state.editor_palette == "select":
				editor_system.increase_unit_leash_range(
					editor_state,
					units,
					editor_state.selected_editor_unit
				)
				return true

		KEY_MINUS:
			if editor_state.editor_palette == "select":
				editor_system.decrease_unit_leash_range(
					editor_state,
					units,
					editor_state.selected_editor_unit
				)
				return true

		KEY_1:
			set_editor_unit_or_tile(editor_state, editor_system, "fighter", ".")
			return true

		KEY_2:
			set_editor_unit_or_tile(editor_state, editor_system, "tank", "W")
			return true

		KEY_3:
			set_editor_unit_or_tile(editor_state, editor_system, "lancer", "R")
			return true

		KEY_4:
			set_editor_unit_class(editor_state, editor_system, "duelist")
			return true

		KEY_5:
			set_editor_unit_class(editor_state, editor_system, "healer")
			return true

		KEY_6:
			set_editor_unit_class(editor_state, editor_system, "archer")
			return true

		KEY_F7:
			editor_state.show_all_defender_leashes = !editor_state.show_all_defender_leashes
			return true

		KEY_DELETE:
			delete_editor_objective_stage(editor_state)
			return true

		KEY_O:
			add_editor_objective_stage(editor_state)
			return true

		KEY_9:
			change_editor_objective_stage(
				editor_state,
				-1
			)
			return true

		KEY_0:
			change_editor_objective_stage(
				editor_state,
				1
			)
			return true

		KEY_P:
			cycle_editor_objective_stage_type(
				editor_state
			)
			return true

		KEY_BRACELEFT:
			adjust_editor_objective_stage_value(
				editor_state,
				-1
			)
			return true

		KEY_BRACERIGHT:
			adjust_editor_objective_stage_value(
				editor_state,
				1
			)
			return true

		KEY_BACKSLASH:
			cycle_editor_objective_completion(
				editor_state
			)
			return true

	return false

# =========================
# Saves the current editor
# map and objective data.
# =========================

func save_editor_map_data(
	editor_state,
	editor_system,
	map_data,
	units: Array,
	map_serializer,
	current_objective_data: Dictionary,
	editor_objective_serializer
):

	current_objective_data.clear()

	var updated_data = editor_objective_serializer.build_objective_data_from_editor(
		editor_state
	)

	for key in updated_data.keys():
		current_objective_data[key] = updated_data[key]

	map_serializer.save_map(
		map_data,
		units,
		editor_system.get_editor_map_path(editor_state),
		current_objective_data
	)


# =========================
# Loads editor map data and
# restores objective zones
# and stage configuration.
# =========================

func load_editor_map_data(
	editor_state,
	editor_system,
	map_data,
	units: Array,
	unit_data,
	map_serializer,
	current_objective_data: Dictionary,
	editor_objective_serializer
):

	var loaded_data = map_serializer.load_map(
		map_data,
		units,
		unit_data,
		editor_system.get_editor_map_path(editor_state)
	)

	current_objective_data.clear()

	for key in loaded_data.keys():
		current_objective_data[key] = loaded_data[key]

	if current_objective_data.has("objective_zones"):
		editor_objective_serializer.deserialize_objective_zones(
			editor_state,
			current_objective_data["objective_zones"]
		)

	if current_objective_data.has("stages"):
		editor_state.editor_objective_stages = (
			current_objective_data["stages"].duplicate(true)
		)

# =========================
# Adds a new objective stage
# after the currently selected
# objective stage.
# =========================

func add_editor_objective_stage(editor_state):

	var new_stage = get_default_objective_stage(
		"defeat_enemy_count"
	)

	editor_state.editor_objective_stages.insert(
		editor_state.editor_objective_stage_index + 1,
		new_stage
	)

	editor_state.editor_objective_stage_index += 1

# =========================
# Deletes the currently
# selected objective stage.
#
# At least one stage is
# always preserved.
# =========================

func delete_editor_objective_stage(editor_state):

	if editor_state.editor_objective_stages.size() <= 1:
		return

	editor_state.editor_objective_stages.remove_at(
		editor_state.editor_objective_stage_index
	)

	editor_state.editor_objective_stage_index = clamp(
		editor_state.editor_objective_stage_index,
		0,
		editor_state.editor_objective_stages.size() - 1
	)

# =========================
# Changes the currently
# selected objective stage
# in the editor UI.
# =========================

func change_editor_objective_stage(
	editor_state,
	direction: int
):

	editor_state.editor_objective_stage_index += direction

	if editor_state.editor_objective_stage_index < 0:
		editor_state.editor_objective_stage_index = (
			editor_state.editor_objective_stages.size() - 1
		)

	if editor_state.editor_objective_stage_index >= editor_state.editor_objective_stages.size():
		editor_state.editor_objective_stage_index = 0

# =========================
# Cycles the selected
# objective stage between
# supported objective types.
# =========================

func cycle_editor_objective_stage_type(editor_state):

	var current_stage = editor_state.editor_objective_stages[
		editor_state.editor_objective_stage_index
	]

	var current_type = current_stage.get(
		"type",
		"defeat_enemy_count"
	)

	var current_index = editor_state.editor_objective_stage_types.find(
		current_type
	)

	if current_index == -1:
		current_index = 0

	var next_index = (
		current_index + 1
	) % editor_state.editor_objective_stage_types.size()

	var next_type = editor_state.editor_objective_stage_types[next_index]

	editor_state.editor_objective_stages[
		editor_state.editor_objective_stage_index
	] = get_default_objective_stage(next_type)

# =========================
# Adjusts numeric values
# for the selected objective
# stage configuration.
# =========================

func adjust_editor_objective_stage_value(
	editor_state,
	direction: int
):

	var current_stage = editor_state.editor_objective_stages[
		editor_state.editor_objective_stage_index
	]

	match current_stage.get("type", ""):

		"defeat_enemy_count":
			current_stage["required_count"] = max(
				1,
				current_stage.get("required_count", 1) + direction
			)

	editor_state.editor_objective_stages[
		editor_state.editor_objective_stage_index
	] = current_stage

# =========================
# Cycles the completion
# result behavior for the
# selected objective stage.
# =========================

func cycle_editor_objective_completion(editor_state):

	var completion_options = [
		"advance_stage",
		"spawn_reinforcements",
		"victory"
	]

	var current_stage = editor_state.editor_objective_stages[
		editor_state.editor_objective_stage_index
	]

	var current_completion = current_stage.get(
		"on_complete",
		"advance_stage"
	)

	var current_index = completion_options.find(
		current_completion
	)

	if current_index == -1:
		current_index = 0

	var next_index = (
		current_index + 1
	) % completion_options.size()

	current_stage["on_complete"] = completion_options[next_index]

	editor_state.editor_objective_stages[
		editor_state.editor_objective_stage_index
	] = current_stage

# =========================
# Returns default dictionary
# data for a new objective
# stage type.
# =========================

func get_default_objective_stage(stage_type: String) -> Dictionary:

	match stage_type:

		"rout":
			return {
				"type": "rout",
				"on_complete": "advance_stage"
			}

		"retreat":
			return {
				"type": "retreat",
				"zone": "retreat_zone",
				"on_complete": "victory"
			}

		_:
			return {
				"type": "defeat_enemy_count",
				"required_count": 1,
				"on_complete": "advance_stage"
			}

# =========================
# Handles editor mouse input.
#
# Returns true if input was used.
# =========================

func handle_mouse_input(
	event,
	editor_state,
	editor_system,
	map_data,
	units: Array,
	unit_query,
	unit_data,
	hovered_cell: Vector2i
) -> bool:

	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		handle_right_click(
			editor_state,
			editor_system,
			map_data,
			units,
			unit_query,
			hovered_cell
		)
		return true

	if event.button_index != MOUSE_BUTTON_LEFT:
		return false

	if event.pressed:
		handle_left_press(
			editor_state,
			editor_system,
			map_data,
			units,
			unit_query,
			unit_data,
			hovered_cell
		)
		return true

	handle_left_release(
		editor_state,
		editor_system,
		map_data,
		units,
		unit_query,
		hovered_cell
	)

	return true


# =========================
# Handles continuous terrain
# painting while mouse is held.
# =========================

func handle_mouse_drag_paint(
	editor_state,
	editor_system,
	map_data,
	hovered_cell: Vector2i
):

	if editor_state.editor_palette != "terrain":
		return

	if editor_state.editor_rect_dragging:
		return

	if Input.is_key_pressed(KEY_CTRL):
		return

	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return

	editor_system.paint_tile(
		map_data,
		hovered_cell,
		editor_state.selected_editor_tile
	)


# =========================
# Handles right-click editor behavior.
# =========================

func handle_right_click(
	editor_state,
	editor_system,
	map_data,
	units: Array,
	unit_query,
	hovered_cell: Vector2i
):

	if editor_state.editor_palette == "select":
		editor_state.selected_editor_unit = -1

		editor_state.editor_selected_rect_start = Vector2i(-1, -1)
		editor_state.editor_selected_rect_end = Vector2i(-1, -1)

		editor_state.editor_select_dragging = false
		editor_state.editor_select_start_cell = Vector2i(-1, -1)

		return

	if editor_state.editor_palette == "zone":
		remove_cell_from_selected_objective_zone(
			editor_state,
			hovered_cell
		)
		return

	if editor_state.editor_palette == "terrain":
		editor_system.paint_tile(
			map_data,
			hovered_cell,
			"."
		)
		return

	editor_system.remove_unit_at(
		units,
		unit_query,
		hovered_cell
	)


# =========================
# Handles left mouse press.
# =========================

func handle_left_press(
	editor_state,
	editor_system,
	map_data,
	units: Array,
	unit_query,
	unit_data,
	hovered_cell: Vector2i
):

	if editor_state.editor_palette == "select":
		handle_select_press(
			editor_state,
			editor_system,
			units,
			unit_query,
			hovered_cell
		)
		return

	if Input.is_key_pressed(KEY_CTRL):
		editor_state.editor_rect_dragging = true
		editor_state.editor_rect_start_cell = hovered_cell
		return

	handle_editor_left_click(
		editor_state,
		editor_system,
		map_data,
		units,
		unit_query,
		unit_data,
		hovered_cell
	)


# =========================
# Handles left mouse release.
# =========================

func handle_left_release(
	editor_state,
	editor_system,
	map_data,
	units: Array,
	unit_query,
	hovered_cell: Vector2i
):

	if editor_state.editor_unit_move_dragging:
		finish_unit_move_drag(
			editor_state,
			map_data,
			units,
			unit_query,
			hovered_cell
		)
		return

	if editor_state.editor_move_dragging:
		finish_selection_move_drag(
			editor_state,
			editor_system,
			map_data,
			units,
			hovered_cell
		)
		return

	if editor_state.editor_select_dragging:
		finish_rect_select_drag(
			editor_state,
			hovered_cell
		)
		return

	if editor_state.editor_rect_dragging:
		finish_terrain_rect_drag(
			editor_state,
			editor_system,
			map_data,
			hovered_cell
		)


# =========================
# Handles select-palette press.
# =========================

func handle_select_press(
	editor_state,
	editor_system,
	units: Array,
	unit_query,
	hovered_cell: Vector2i
):

	var clicked_unit = unit_query.get_unit_at(
		units,
		hovered_cell
	)

	if clicked_unit != -1:
		editor_state.selected_editor_unit = clicked_unit

		editor_state.editor_selected_rect_start = Vector2i(-1, -1)
		editor_state.editor_selected_rect_end = Vector2i(-1, -1)

		editor_state.editor_unit_move_dragging = true
		editor_state.editor_unit_move_start_cell = hovered_cell

		return

	editor_state.selected_editor_unit = -1

	if editor_system.editor_cell_is_inside_selected_area(
		editor_state,
		hovered_cell
	):
		editor_state.editor_move_dragging = true
		editor_state.editor_move_start_cell = hovered_cell
	else:
		editor_state.editor_select_dragging = true
		editor_state.editor_select_start_cell = hovered_cell


# =========================
# Handles editor placement
# and paint behavior for
# the active editor palette.
# =========================

func handle_editor_left_click(
	editor_state,
	editor_system,
	map_data,
	units: Array,
	unit_query,
	unit_data,
	clicked_cell: Vector2i
):

	if not map_data.is_inside_grid(clicked_cell):
		return

	if editor_state.editor_palette == "terrain":
		editor_system.paint_tile(
			map_data,
			clicked_cell,
			editor_state.selected_editor_tile
		)

	elif editor_state.editor_palette == "zone":
		add_cell_to_selected_objective_zone(
			editor_state,
			clicked_cell
		)

	elif editor_state.editor_palette == "player_unit":
		editor_system.place_unit(
			units,
			unit_query,
			unit_data,
			map_data,
			clicked_cell,
			editor_state.selected_editor_unit_class,
			"player",
			editor_state.selected_editor_facing,
			editor_state.selected_editor_ai_profile
		)

	elif editor_state.editor_palette == "enemy_unit":
		editor_system.place_unit(
			units,
			unit_query,
			unit_data,
			map_data,
			clicked_cell,
			editor_state.selected_editor_unit_class,
			"enemy",
			editor_state.selected_editor_facing,
			editor_state.selected_editor_ai_profile
		)

	elif editor_state.editor_palette == "reinforcement":
		editor_system.place_unit(
			units,
			unit_query,
			unit_data,
			map_data,
			clicked_cell,
			editor_state.selected_editor_unit_class,
			"enemy",
			editor_state.selected_editor_facing,
			editor_state.selected_editor_ai_profile
		)

		var placed_unit = unit_query.get_unit_at(
			units,
			clicked_cell
		)

		if placed_unit != -1:
			units[placed_unit]["reinforcement_stage"] = editor_state.editor_reinforcement_stage
			units[placed_unit]["starts_hidden"] = true


# =========================
# Finishes unit drag movement.
# =========================

func finish_unit_move_drag(
	editor_state,
	map_data,
	units: Array,
	unit_query,
	hovered_cell: Vector2i
):

	var offset = hovered_cell - editor_state.editor_unit_move_start_cell

	if (
		editor_state.selected_editor_unit != -1
		and editor_state.selected_editor_unit < units.size()
		and offset != Vector2i.ZERO
	):

		var target_cell = (
			units[editor_state.selected_editor_unit]["pos"]
			+ offset
		)

		if (
			map_data.is_inside_grid(target_cell)
			and not map_data.blocks_movement(target_cell)
		):

			var occupied_unit = unit_query.get_unit_at(
				units,
				target_cell
			)

			if (
				occupied_unit == -1
				or occupied_unit == editor_state.selected_editor_unit
			):

				units[editor_state.selected_editor_unit]["pos"] = target_cell

				if units[editor_state.selected_editor_unit].has("home_pos"):
					units[editor_state.selected_editor_unit]["home_pos"] += offset

	editor_state.editor_unit_move_dragging = false
	editor_state.editor_unit_move_start_cell = Vector2i(-1, -1)


# =========================
# Finishes selected-area movement.
# =========================

func finish_selection_move_drag(
	editor_state,
	editor_system,
	map_data,
	units: Array,
	hovered_cell: Vector2i
):

	var offset = hovered_cell - editor_state.editor_move_start_cell

	editor_system.move_selection(
		map_data,
		units,
		editor_state.editor_selected_rect_start,
		editor_state.editor_selected_rect_end,
		offset
	)

	editor_state.editor_selected_rect_start += offset
	editor_state.editor_selected_rect_end += offset

	editor_state.editor_move_dragging = false
	editor_state.editor_move_start_cell = Vector2i(-1, -1)


# =========================
# Finishes rectangle selection.
# =========================

func finish_rect_select_drag(
	editor_state,
	hovered_cell: Vector2i
):

	editor_state.editor_selected_rect_start = Vector2i(
		min(editor_state.editor_select_start_cell.x, hovered_cell.x),
		min(editor_state.editor_select_start_cell.y, hovered_cell.y)
	)

	editor_state.editor_selected_rect_end = Vector2i(
		max(editor_state.editor_select_start_cell.x, hovered_cell.x),
		max(editor_state.editor_select_start_cell.y, hovered_cell.y)
	)

	editor_state.editor_select_dragging = false
	editor_state.editor_select_start_cell = Vector2i(-1, -1)


# =========================
# Finishes terrain rectangle fill.
# =========================

func finish_terrain_rect_drag(
	editor_state,
	editor_system,
	map_data,
	hovered_cell: Vector2i
):

	editor_system.fill_rect(
		map_data,
		editor_state.editor_rect_start_cell,
		hovered_cell,
		editor_state.selected_editor_tile
	)

	editor_state.editor_rect_dragging = false
	editor_state.editor_rect_start_cell = Vector2i(-1, -1)


# =========================
# Adds objective zone cell.
# =========================

func add_cell_to_selected_objective_zone(
	editor_state,
	cell: Vector2i
):

	if not editor_state.objective_zones.has(
		editor_state.selected_objective_zone
	):
		editor_state.objective_zones[
			editor_state.selected_objective_zone
		] = []

	if editor_state.objective_zones[
		editor_state.selected_objective_zone
	].has(cell):
		return

	editor_state.objective_zones[
		editor_state.selected_objective_zone
	].append(cell)


# =========================
# Removes objective zone cell.
# =========================

func remove_cell_from_selected_objective_zone(
	editor_state,
	cell: Vector2i
):

	if not editor_state.objective_zones.has(
		editor_state.selected_objective_zone
	):
		return

	editor_state.objective_zones[
		editor_state.selected_objective_zone
	].erase(cell)


# =========================
# Sets class or terrain tile
# depending on palette.
# =========================

func set_editor_unit_or_tile(
	editor_state,
	editor_system,
	unit_class: String,
	tile_symbol: String
):

	if editor_state.editor_palette == "terrain":
		editor_state.selected_editor_tile = tile_symbol
	else:
		set_editor_unit_class(
			editor_state,
			editor_system,
			unit_class
		)


# =========================
# Sets selected editor unit class.
# =========================

func set_editor_unit_class(
	editor_state,
	editor_system,
	unit_class: String
):

	if editor_state.editor_palette == "terrain":
		return

	editor_state.selected_editor_unit_class = unit_class

	editor_system.validate_selected_editor_ai_profile(
		editor_state
	)

# =========================
# Handles map resize prompt input.
#
# Returns true if the resize
# prompt consumed the key.
# =========================

func handle_editor_resize_input(
	event,
	editor_state,
	map_data
) -> bool:

	match event.keycode:

		KEY_RIGHT:
			editor_state.editor_resize_width += 1
			return true

		KEY_LEFT:
			editor_state.editor_resize_width = max(
				1,
				editor_state.editor_resize_width - 1
			)
			return true

		KEY_UP:
			editor_state.editor_resize_height += 1
			return true

		KEY_DOWN:
			editor_state.editor_resize_height = max(
				1,
				editor_state.editor_resize_height - 1
			)
			return true

		KEY_ENTER:
			map_data.resize_map(
				editor_state.editor_resize_width,
				editor_state.editor_resize_height
			)

			editor_state.editor_resize_mode = false
			return true

		KEY_ESCAPE:
			editor_state.editor_resize_mode = false
			return true

	return false

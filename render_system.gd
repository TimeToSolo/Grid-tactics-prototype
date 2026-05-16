extends Node

# ==================================================
# RENDER SYSTEM
# ==================================================
# Handles drawing helpers for map, units, overlays,
# previews, and UI prompts.
# ==================================================


# =========================
# Draws the base terrain grid.
# =========================

func draw_grid(
	canvas: CanvasItem,
	map_data
):

	for y in range(map_data.grid_height):
		for x in range(map_data.grid_width):

			var cell = Vector2i(x, y)
			var rect = map_data.grid_rect(cell)

			canvas.draw_rect(
				rect,
				map_data.get_tile_color(cell),
				true
			)

			canvas.draw_rect(
				rect,
				Color.WHITE,
				false
			)


# =========================
# Draws reachable movement tiles.
#
# Cyan tiles show valid movement.
# =========================

func draw_move_tiles(
	canvas: CanvasItem,
	map_data,
	units: Array,
	selected_unit: int,
	move_tiles: Array[Vector2i]
):
	if selected_unit == -1:
		return

	for cell in move_tiles:
		var rect = map_data.grid_rect(cell)
		canvas.draw_rect(
			rect,
			Color(0.0, 0.8, 1.0, 0.45),
			true
		)


# =========================
# Draws pending destination tile.
# =========================

func draw_pending_move_tile(
	canvas: CanvasItem,
	map_data,
	pending_move_cell: Vector2i,
	has_pending_move: bool
):

	if not has_pending_move:
		return

	canvas.draw_rect(
		map_data.grid_rect(pending_move_cell),
		Color(1.0, 1.0, 0.0, 0.65),
		true
	)

# ==================================================
# ATTACK RANGE DRAWING
# ==================================================

# =========================
# Draws attack preview overlays.
#
# Red tiles show valid attack range.
# =========================

func draw_attack_range(
	canvas: CanvasItem,
	map_data,
	unit_logic,
	units: Array,
	selected_unit: int,
	move_tiles: Array[Vector2i],
	pending_move_cell: Vector2i,
	has_pending_move: bool
):

	if selected_unit == -1:
		return

	var unit = units[selected_unit]
	var unit_class = unit["class"]

	var attack_tiles: Array[Vector2i] = []

	if has_pending_move:

		if unit_class == "healer":
			attack_tiles = unit_logic.get_adjacent_choice_tiles(
				pending_move_cell,
				map_data
			)
		else:
			attack_tiles = unit_logic.get_attack_choice_tiles(
				pending_move_cell,
				unit_class,
				map_data
			)

	else:

		attack_tiles = unit_logic.get_attack_tiles_from_move_tiles(
			move_tiles,
			unit_class,
			map_data
		)

	for tile in attack_tiles:

		if not map_data.is_inside_grid(tile):
			continue

		var rect = map_data.grid_rect(tile)

		var fill_color = Color(1.0, 0.15, 0.15, 0.18)
		var border_color = Color(1.0, 0.1, 0.1, 0.9)

		if unit_class == "healer":
			canvas.draw_rect(rect, border_color, false, 3)
		else:
			canvas.draw_rect(rect, fill_color, true)
			canvas.draw_rect(rect, border_color, false, 3)


# =========================
# Draws healer support range after moving.
#
# Blue tiles show valid heal/regeneration range.
# =========================

func draw_heal_range(
	canvas: CanvasItem,
	map_data,
	unit_logic,
	units: Array,
	selected_unit: int,
	pending_move_cell: Vector2i,
	has_pending_move: bool
):

	if selected_unit == -1:
		return

	if not has_pending_move:
		return

	if units[selected_unit]["class"] != "healer":
		return

	var heal_tiles = unit_logic.get_heal_choice_tiles(
		pending_move_cell,
		map_data
	)

	for tile in heal_tiles:

		if not map_data.is_inside_grid(tile):
			continue

		var rect = map_data.grid_rect(tile)

		canvas.draw_rect(
			rect,
			Color(0.2, 0.8, 1.0, 0.22),
			true
		)

		canvas.draw_rect(
			rect,
			Color(0.2, 0.9, 1.0, 0.9),
			false,
			3
		)

# ==================================================
# COVERAGE DRAWING
# ==================================================

# =========================
# Draws all active coverage zones.
#
# coverage_mode:
# 0 = off
# 1 = player
# 2 = enemy
# 3 = all
# =========================

func draw_all_coverage(
	canvas: CanvasItem,
	map_data,
	unit_logic,
	coverage_system,
	units: Array,
	coverage_mode: int
):

	if coverage_mode == 0:
		return

	for i in range(units.size()):

		var unit = units[i]
		var team = unit["team"]

		if coverage_mode == 1 and team != "player":
			continue

		if coverage_mode == 2 and team != "enemy":
			continue

		if not coverage_system.has_active_coverage(
			units,
			i
		):
			continue

		var pos = unit["pos"]
		var facing = unit["facing"]
		var unit_class = unit["class"]

		if facing == Vector2i.ZERO:
			continue

		var coverage_color = Color(1.0, 0.85, 0.0, 0.35)

		if team == "enemy":
			coverage_color = Color(1.0, 0.1, 0.1, 0.35)

		var covered_tiles = unit_logic.get_coverage_tiles(
			unit_class,
			pos,
			facing
		)

		if unit_class == "tank":

			var slow_tiles = unit_logic.get_tank_slow_tiles(
				pos,
				facing
			)

			for tile in slow_tiles:

				if not map_data.is_inside_grid(tile):
					continue

				var slow_color = Color(0.75, 0.6, 0.1, 0.30)

				if team == "enemy":
					slow_color = Color(0.65, 0.45, 0.0, 0.30)

				canvas.draw_rect(
					map_data.grid_rect(tile),
					slow_color,
					true
				)

		for tile in covered_tiles:

			if not map_data.is_inside_grid(tile):
				continue

			canvas.draw_rect(
				map_data.grid_rect(tile),
				coverage_color,
				true
			)


# =========================
# Draws green preview coverage while hovering
# a valid facing-selection tile.
# =========================

func draw_coverage_preview(
	canvas: CanvasItem,
	map_data,
	unit_logic,
	unit_query,
	hover_query,
	action_query,
	units: Array,
	selected_unit: int,
	pending_move_cell: Vector2i,
	hovered_cell: Vector2i,
	has_pending_move: bool,
	valid_lancer_tiles: Array[Vector2i]
):

	if selected_unit == -1:
		return

	if not has_pending_move:
		return

	if hover_query.is_hovering_attackable_enemy(
		units,
		selected_unit,
		pending_move_cell,
		hovered_cell,
		has_pending_move,
		unit_logic,
		unit_query,
		map_data
	):
		return

	var unit_class = units[selected_unit]["class"]
	var facing: Vector2i = Vector2i.ZERO

	if unit_class == "lancer":

		if not valid_lancer_tiles.has(hovered_cell):
			return

		facing = action_query.get_lancer_facing_from_target(
			pending_move_cell,
			hovered_cell
		)

	else:

		var facing_tiles = unit_logic.get_facing_choice_tiles(
			pending_move_cell,
			map_data
		)

		if not facing_tiles.has(hovered_cell):
			return

		facing = hovered_cell - pending_move_cell

	var coverage_tiles = unit_logic.get_coverage_tiles(
		unit_class,
		pending_move_cell,
		facing
	)

	if unit_class == "tank":

		var slow_tiles = unit_logic.get_tank_slow_tiles(
			pending_move_cell,
			facing
		)

		for cell in slow_tiles:

			if map_data.is_inside_grid(cell):

				canvas.draw_rect(
					map_data.grid_rect(cell),
					Color(0.75, 0.6, 0.1, 0.45),
					true
				)

	for cell in coverage_tiles:

		if map_data.is_inside_grid(cell):

			canvas.draw_rect(
				map_data.grid_rect(cell),
				Color(0.0, 1.0, 0.0, 0.55),
				true
			)


# ==================================================
# FACING DRAWING
# ==================================================

# =========================
# Draws purple facing-selection tiles.
# =========================

func draw_facing_choice_tiles(
	canvas: CanvasItem,
	map_data,
	unit_logic,
	units: Array,
	selected_unit: int,
	move_tiles: Array[Vector2i],
	pending_move_cell: Vector2i,
	has_pending_move: bool,
	valid_lancer_tiles: Array[Vector2i]
):

	if selected_unit == -1:
		return

	if not has_pending_move:
		return

	if move_tiles.size() > 0:
		return

	if (
		units[selected_unit]["class"] == "archer"
		or units[selected_unit]["class"] == "healer"
	):
		return

	if units[selected_unit]["class"] == "lancer":

		for cell in valid_lancer_tiles:
			canvas.draw_rect(
				map_data.grid_rect(cell),
				Color(0.7, 0.2, 1.0, 0.55),
				true
			)

		return

	var facing_tiles = unit_logic.get_facing_choice_tiles(
		pending_move_cell,
		map_data
	)

	for cell in facing_tiles:
		canvas.draw_rect(
			map_data.grid_rect(cell),
			Color(0.7, 0.2, 1.0, 0.55),
			true
		)

# ==================================================
# UNIT DRAWING
# ==================================================

# =========================
# Draws units, outlines, HP, stamina,
# healer charges, and facing indicators.
# =========================

func draw_units(
	canvas: CanvasItem,
	map_data,
	unit_logic,
	stamina_system,
	units: Array,
	selected_unit: int,
	pending_move_distance: int,
	has_pending_move: bool
):

	for i in range(units.size()):

		var unit = units[i]

		var pos = unit["pos"]
		var unit_rect = map_data.grid_rect(pos)

		var unit_color = unit_logic.get_unit_color(
			unit["class"]
		)

		if unit["has_acted"]:
			unit_color = unit_color.darkened(0.45)

		canvas.draw_rect(unit_rect, unit_color, true)

		var outline_color = Color(0.2, 0.5, 1.0)

		if unit["team"] == "enemy":
			outline_color = Color(1.0, 0.2, 0.2)

		if i == selected_unit:
			outline_color = Color(1.0, 0.8, 0.2)

		canvas.draw_rect(unit_rect, outline_color, false, 3)

		canvas.draw_string(
			ThemeDB.fallback_font,
			unit_rect.position + Vector2(8, 22),
			str(unit["hp"]),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			16,
			Color.BLACK
		)

		canvas.draw_string(
			ThemeDB.fallback_font,
			unit_rect.position + Vector2(40, 16),
			str(stamina_system.get_display_stamina(
				units,
				i,
				selected_unit,
				has_pending_move,
				pending_move_distance
			)),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			12,
			Color.BLACK
		)

		if unit["class"] == "healer":

			var charge_text = (
				str(unit["heal_charges"])
				+ "/"
				+ str(unit["max_heal_charges"])
			)

			canvas.draw_string(
				ThemeDB.fallback_font,
				unit_rect.position + Vector2(28, 52),
				charge_text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				12,
				Color.BLACK
			)

		if unit["class"] != "healer" and unit["class"] != "archer":
			draw_unit_facing(
				canvas,
				map_data,
				pos,
				unit["facing"]
			)


# =========================
# Draws facing direction indicator.
# =========================

func draw_unit_facing(
	canvas: CanvasItem,
	map_data,
	pos: Vector2i,
	facing: Vector2i
):

	if facing == Vector2i.ZERO:
		return

	var rect = map_data.grid_rect(pos)

	var center = rect.position + rect.size / 2

	var end = center + (
		Vector2(facing.x, facing.y).normalized() * 24
	)

	canvas.draw_line(
		center,
		end,
		Color.BLACK,
		4
	)

# ==================================================
# UI PROMPTS / HOVER PREVIEW
# ==================================================

# =========================
# Draws current turn indicator.
# =========================

func draw_turn_indicator(
	canvas: CanvasItem,
	turn_manager,
	turn_number: int
):

	var turn_color = Color(0.2, 0.5, 1.0)

	if turn_manager.current_team == "enemy":
		turn_color = Color(1.0, 0.2, 0.2)

	var text = (
		"Turn "
		+ str(turn_number)
		+ " - "
		+ turn_manager.current_team.capitalize()
	)

	canvas.draw_string(
		ThemeDB.fallback_font,
		Vector2(16, 30),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		20,
		turn_color
	)


# =========================
# Draws wait confirmation prompt.
# =========================

func draw_wait_confirmation_prompt(
	canvas: CanvasItem,
	awaiting_wait_confirmation: bool
):

	if not awaiting_wait_confirmation:
		return

	canvas.draw_string(
		ThemeDB.fallback_font,
		Vector2(260, 30),
		"Wait? W / Cancel: N",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		20,
		Color.WHITE
	)


# =========================
# Draws attack confirmation prompt.
# =========================

func draw_attack_confirmation_prompt(
	canvas: CanvasItem,
	awaiting_attack_confirmation: bool
):

	if not awaiting_attack_confirmation:
		return

	canvas.draw_string(
		ThemeDB.fallback_font,
		Vector2(260, 30),
		"Attack? Y/N",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		20,
		Color.WHITE
	)


# =========================
# Draws heal confirmation prompt.
# =========================

func draw_heal_confirmation_prompt(
	canvas: CanvasItem,
	awaiting_heal_confirmation: bool
):

	if not awaiting_heal_confirmation:
		return

	canvas.draw_string(
		ThemeDB.fallback_font,
		Vector2(260, 30),
		"Heal: H / Regen: R / Cancel: N",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		20,
		Color.WHITE
	)

# =========================
# Draws compact hover info
# for the unit under cursor.
#
# Shows:
# - class name
# - HP / stamina labels
# - HP / stamina bars
# - numeric HP / stamina values
#
# HP bar:
# - primary resource
# - larger and more prominent
#
# Stamina bar:
# - secondary tactical resource
# - thinner and more subtle
# =========================

func draw_hover_unit_panel(
	canvas,
	units: Array,
	unit_query,
	hovered_cell: Vector2i,
	inspected_unit: int,
	selected_unit: int
):

	var display_unit = unit_query.get_unit_at(
		units,
		hovered_cell
	)

	if display_unit == -1:
		display_unit = inspected_unit

	if display_unit == -1:
		display_unit = selected_unit

	if display_unit == -1:
		return

	if display_unit < 0 or display_unit >= units.size():
		return

	var unit = units[display_unit]

	var panel_pos = Vector2(16, 16)
	var panel_size = Vector2(380, 112)
	var panel_rect = Rect2(panel_pos, panel_size)

	var font = ThemeDB.fallback_font

	canvas.draw_rect(
		panel_rect,
		Color(0.04, 0.045, 0.05, 0.95),
		true
	)

	canvas.draw_rect(
		panel_rect,
		Color(0.72, 0.66, 0.42, 1.0),
		false,
		2.0
	)

	var label_x = panel_pos.x + 24
	var bar_x = panel_pos.x + 105
	var hp_y = panel_pos.y + 56
	var stamina_y = panel_pos.y + 86

	var hp_bar_size = Vector2(235, 22)
	var stamina_bar_size = Vector2(150, 12)

	var value_x = panel_pos.x + 285

	canvas.draw_string(
		font,
		panel_pos + Vector2(24, 40),
		unit["class"].capitalize(),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		32,
		Color.WHITE
	)

	var hp_text = str(unit["hp"]) + "/" + str(unit["max_hp"])

	canvas.draw_string(
		font,
		Vector2(value_x, panel_pos.y + 44),
		hp_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		26,
		Color(0.85, 1.0, 0.85)
	)

	canvas.draw_string(
		font,
		Vector2(label_x, hp_y + 20),
		"HP",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		22,
		Color.WHITE
	)

	var hp_bar_pos = Vector2(bar_x, hp_y)

	var hp_percent = float(unit["hp"]) / float(unit["max_hp"])
	var hp_fill_width = hp_bar_size.x * hp_percent

	var hp_fill_color = Color(0.2, 0.85, 0.2)

	if unit["team"] == "enemy":
		hp_fill_color = Color(0.85, 0.2, 0.2)

	canvas.draw_rect(
		Rect2(hp_bar_pos, hp_bar_size),
		Color(0.12, 0.12, 0.12),
		true
	)

	canvas.draw_rect(
		Rect2(
			hp_bar_pos,
			Vector2(hp_fill_width, hp_bar_size.y)
		),
		hp_fill_color,
		true
	)

	canvas.draw_rect(
		Rect2(hp_bar_pos, hp_bar_size),
		Color.BLACK,
		false,
		2.0
	)

	canvas.draw_string(
		font,
		Vector2(label_x, stamina_y + 14),
		"STA",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		18,
		Color.WHITE
	)

	var stamina_bar_pos = Vector2(bar_x, stamina_y)

	var stamina_percent = float(unit["stamina"]) / float(unit["max_stamina"])
	var stamina_fill_width = stamina_bar_size.x * stamina_percent

	canvas.draw_rect(
		Rect2(stamina_bar_pos, stamina_bar_size),
		Color(0.12, 0.10, 0.06),
		true
	)

	canvas.draw_rect(
		Rect2(
			stamina_bar_pos,
			Vector2(stamina_fill_width, stamina_bar_size.y)
		),
		Color(0.95, 0.65, 0.18),
		true
	)

	canvas.draw_rect(
		Rect2(stamina_bar_pos, stamina_bar_size),
		Color.BLACK,
		false,
		1.0
	)

	var stamina_text = str(unit["stamina"]) + "/" + str(unit["max_stamina"])

	canvas.draw_string(
		font,
		Vector2(value_x - 25, stamina_y + 14),
		stamina_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		20,
		Color(1.0, 0.9, 0.55)
	)

# =========================
# Draws hover preview for attack targets.
# =========================

func draw_attack_hover_preview(
	canvas: CanvasItem,
	map_data,
	unit_logic,
	unit_query,
	hover_query,
	units: Array,
	selected_unit: int,
	pending_move_cell: Vector2i,
	hovered_cell: Vector2i,
	has_pending_move: bool
):

	if not hover_query.is_hovering_attackable_enemy(
		units,
		selected_unit,
		pending_move_cell,
		hovered_cell,
		has_pending_move,
		unit_logic,
		unit_query,
		map_data
	):
		return

	var rect = map_data.grid_rect(hovered_cell)

	canvas.draw_rect(
		rect,
		Color(1.0, 0.0, 0.0, 0.45),
		true
	)

	canvas.draw_rect(
		rect,
		Color.WHITE,
		false,
		4
	)


# =========================
# Draws hover preview for valid
# healer support targets.
# =========================

func draw_heal_hover_preview(
	canvas: CanvasItem,
	map_data,
	unit_logic,
	unit_query,
	hover_query,
	units: Array,
	selected_unit: int,
	pending_move_cell: Vector2i,
	hovered_cell: Vector2i,
	has_pending_move: bool
):

	if not hover_query.is_hovering_healable_ally(
		units,
		selected_unit,
		pending_move_cell,
		hovered_cell,
		has_pending_move,
		unit_logic,
		unit_query,
		map_data
	):
		return

	var rect = map_data.grid_rect(hovered_cell)

	canvas.draw_rect(
		rect,
		Color(0.2, 0.6, 1.0, 0.45),
		true
	)

	canvas.draw_rect(
		rect,
		Color.WHITE,
		false,
		4
	)

# =========================
# Draws hovered movement path preview.
#
# Yellow:
# - normal path
#
# Red:
# - tile where coverage counter triggers
# =========================

func draw_path_preview(
	canvas: CanvasItem,
	map_data,
	units: Array,
	path_preview: Dictionary
):

	if path_preview.is_empty():
		return

	var path_cells: Array[Vector2i] = path_preview["path_cells"]
	var danger_cells: Array[Vector2i] = path_preview["danger_cells"]
	var countering_units: Array[int] = path_preview["countering_units"]

	for cell in path_cells:

		var rect = map_data.grid_rect(cell)

		if danger_cells.has(cell):

			canvas.draw_rect(
				rect,
				Color(1.0, 0.0, 0.0, 0.55),
				true
			)

			canvas.draw_rect(
				rect,
				Color.WHITE,
				false,
				4
			)

		else:

			canvas.draw_rect(
				rect,
				Color(1.0, 1.0, 0.0, 0.35),
				true
			)

	for unit_index in countering_units:

		if unit_index < 0 or unit_index >= units.size():
			continue

		var unit_cell = units[unit_index]["pos"]
		var rect = map_data.grid_rect(unit_cell)

		canvas.draw_rect(
			rect,
			Color(1.0, 0.0, 0.0, 0.25),
			true
		)

		canvas.draw_rect(
			rect,
			Color(1.0, 0.0, 0.0, 1.0),
			false,
			5
		)

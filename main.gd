extends Node2D

# ==================================================
# MAIN GAME CONTROLLER
# ==================================================
# Handles:
# - player input
# - selection state
# - rendering
# - combat coordination
# - movement flow
# - coverage resolution
# - action confirmation
#
# Specialized logic is delegated to:
# - MapData
# - UnitLogic
# - CombatLogic
# - TurnManager
# ==================================================


# ==================================================
# NODE REFERENCES
# ==================================================

@onready var action_query = $ActionQuery
@onready var battle_setup = $BattleSetup
@onready var combat_logic = $CombatLogic
@onready var coverage_system = $CoverageSystem
@onready var hover_query = $HoverQuery
@onready var map_data = $MapData
@onready var selection_state = $SelectionState
@onready var stamina_system = $StaminaSystem
@onready var turn_manager = $TurnManager
@onready var unit_data = $UnitData
@onready var unit_logic = $UnitLogic
@onready var unit_query = $UnitQuery

# ==================================================
# CONSTANTS
# ==================================================

# Height reserved for top UI bar.
const UI_HEIGHT = 48

# ==================================================
# UNIT DATA
# ==================================================

var units = []

# ==================================================
# SELECTION / MOVEMENT STATE
# ==================================================

# Currently selected unit index.
var selected_unit = -1

# Reachable movement tiles for selected unit.
var move_tiles: Array[Vector2i] = []

# Pending destination tile.
var pending_move_cell: Vector2i = Vector2i(-1, -1)

# Pending facing direction after movement.
var pending_facing: Vector2i = Vector2i.ZERO

# Distance moved during pending movement.
var pending_move_distance = 0

# Primary movement direction.
var pending_move_direction: Vector2i = Vector2i.ZERO

# Original position before movement begins.
var selected_unit_start_cell: Vector2i = Vector2i(-1, -1)

# Mouse hover tracking for previews.
var hovered_cell: Vector2i = Vector2i(-1, -1)


# ==================================================
# ATTACK / HEAL STATE
# ==================================================

# Pending attack target.
var pending_attack_target = -1

# Pending heal/regeneration target.
var pending_heal_target = -1

# Enemy providing delayed coverage reaction.
var pending_coverage_enemies: Array[int] = []


# ==================================================
# CONFIRMATION STATE
# ==================================================

var awaiting_attack_confirmation = false
var awaiting_heal_confirmation = false
var awaiting_wait_confirmation = false


# ==================================================
# GAME STATE
# ==================================================

# Coverage overlay display mode.
# 0 = off
# 1 = player
# 2 = enemy
# 3 = all
var coverage_mode = 0

# Current displayed turn number.
var turn_number = 1

# ==================================================
# RENDERING
# ==================================================

func _draw():

	draw_grid()

	draw_move_tiles()
	draw_heal_range()
	draw_attack_range()

	draw_all_coverage()

	draw_pending_move_tile()
	draw_facing_choice_tiles()
	draw_coverage_preview()

	draw_units()

	draw_attack_hover_preview()
	draw_heal_hover_preview()

	draw_turn_indicator()

	draw_wait_confirmation_prompt()
	draw_attack_confirmation_prompt()
	draw_heal_confirmation_prompt()


# ==================================================
# GRID / TILE DRAWING
# ==================================================

# =========================
# Draws the base terrain grid.
# =========================

func draw_grid():

	for y in range(map_data.GRID_HEIGHT):
		for x in range(map_data.GRID_WIDTH):

			var cell = Vector2i(x, y)
			var rect = map_data.grid_rect(cell)

			draw_rect(
				rect,
				map_data.get_tile_color(cell),
				true
			)

			draw_rect(
				rect,
				Color.WHITE,
				false
			)


# =========================
# Draws reachable movement tiles.
#
# Cyan:
# - normal movement
#
# Darker blue:
# - max-range movement
# - limited pivot/facing
# =========================

func draw_move_tiles():

	if selected_unit == -1:
		return

	var start = selected_unit_start_cell
	var max_move = units[selected_unit]["move"]

	for cell in move_tiles:

		var rect = map_data.grid_rect(cell)

		if map_data.is_max_range_tile(start, cell, max_move):

			draw_rect(
				rect,
				Color(0.0, 0.65, 0.85, 0.60),
				true
			)

		else:

			draw_rect(
				rect,
				Color(0.0, 0.8, 1.0, 0.45),
				true
			)


# =========================
# Draws pending destination tile.
# =========================

func draw_pending_move_tile():

	if not has_pending_move():
		return

	draw_rect(
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

func draw_attack_range():

	if selected_unit == -1:
		return

	var unit = units[selected_unit]
	var unit_class = unit["class"]

	var attack_tiles: Array[Vector2i] = []

	if has_pending_move():

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
			draw_rect(rect, border_color, false, 3)
		else:
			draw_rect(rect, fill_color, true)
			draw_rect(rect, border_color, false, 3)

# =========================
# Draws healer support range after moving.
#
# Blue tiles show valid heal/regeneration range.
# =========================

func draw_heal_range():

	if selected_unit == -1:
		return

	if not has_pending_move():
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

		draw_rect(
			rect,
			Color(0.2, 0.8, 1.0, 0.22),
			true
		)

		draw_rect(
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

func draw_all_coverage():

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

		# Tank slow/control zones.
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

				draw_rect(
					map_data.grid_rect(tile),
					slow_color,
					true
				)

		for tile in covered_tiles:

			if not map_data.is_inside_grid(tile):
				continue

			draw_rect(
				map_data.grid_rect(tile),
				coverage_color,
				true
			)


# =========================
# Draws green preview coverage while hovering
# a valid facing-selection tile.
# =========================

func draw_coverage_preview():

	if selected_unit == -1:
		return

	if not has_pending_move():
		return

	if hover_query.is_hovering_attackable_enemy(
		units,
		selected_unit,
		pending_move_cell,
		hovered_cell,
		has_pending_move(),
		unit_logic,
		unit_query,
		map_data
	):
		return

	var unit_class = units[selected_unit]["class"]
	var facing: Vector2i = Vector2i.ZERO

	if unit_class == "lancer":

		var lancer_tiles = get_valid_lancer_facing_tiles()

		if not lancer_tiles.has(hovered_cell):
			return

		facing = action_query.get_lancer_facing_from_target(
			pending_move_cell,
			hovered_cell
		)

	else:

		var facing_tiles = unit_logic.get_facing_choice_tiles(
			pending_move_cell,
			pending_move_distance,
			pending_move_direction,
			units[selected_unit]["move"],
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

				draw_rect(
					map_data.grid_rect(cell),
					Color(0.75, 0.6, 0.1, 0.45),
					true
				)

	for cell in coverage_tiles:

		if map_data.is_inside_grid(cell):

			draw_rect(
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

func draw_facing_choice_tiles():

	if selected_unit == -1:
		return

	if not has_pending_move():
		return

	if move_tiles.size() > 0:
		return

	if (
		units[selected_unit]["class"] == "archer"
		or units[selected_unit]["class"] == "healer"
	):
		return
		
	if units[selected_unit]["class"] == "lancer":

		for cell in get_valid_lancer_facing_tiles():
			draw_rect(
				map_data.grid_rect(cell),
				Color(0.7, 0.2, 1.0, 0.55),
				true
			)

		return

	var facing_tiles = unit_logic.get_facing_choice_tiles(
		pending_move_cell,
		pending_move_distance,
		pending_move_direction,
		units[selected_unit]["move"],
		map_data
	)

	for cell in facing_tiles:
		draw_rect(
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

func draw_units():

	for i in range(units.size()):

		var unit = units[i]

		var pos = unit["pos"]
		var unit_rect = map_data.grid_rect(pos)

		var unit_color = unit_logic.get_unit_color(
			unit["class"]
		)

		if unit["has_acted"]:
			unit_color = unit_color.darkened(0.45)

		draw_rect(unit_rect, unit_color, true)

		var outline_color = Color(0.2, 0.5, 1.0)

		if unit["team"] == "enemy":
			outline_color = Color(1.0, 0.2, 0.2)

		if i == selected_unit:
			outline_color = Color(1.0, 0.8, 0.2)

		draw_rect(unit_rect, outline_color, false, 3)

		# HP
		draw_string(
			ThemeDB.fallback_font,
			unit_rect.position + Vector2(8, 22),
			str(unit["hp"]),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			16,
			Color.BLACK
		)

		# Stamina
		draw_string(
			ThemeDB.fallback_font,
			unit_rect.position + Vector2(40, 16),
			str(stamina_system.get_display_stamina(
				units,
				i,
				selected_unit,
				has_pending_move(),
				pending_move_distance
			)),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			12,
			Color.BLACK
		)

		# Healer charges
		if unit["class"] == "healer":

			var charge_text = (
				str(unit["heal_charges"])
				+ "/"
				+ str(unit["max_heal_charges"])
			)

			draw_string(
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
				pos,
				unit["facing"]
			)


# =========================
# Draws facing direction indicator.
# =========================

func draw_unit_facing(
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

	draw_line(
		center,
		end,
		Color.BLACK,
		4
	)


# ==================================================
# UI PROMPTS / HOVER PREVIEW
# ==================================================

func draw_turn_indicator():

	var turn_color = Color(0.2, 0.5, 1.0)

	if turn_manager.current_team == "enemy":
		turn_color = Color(1.0, 0.2, 0.2)

	var text = (
		"Turn "
		+ str(turn_number)
		+ " - "
		+ turn_manager.current_team.capitalize()
	)

	draw_string(
		ThemeDB.fallback_font,
		Vector2(16, 30),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		20,
		turn_color
	)


func draw_wait_confirmation_prompt():

	if not awaiting_wait_confirmation:
		return

	draw_string(
		ThemeDB.fallback_font,
		Vector2(260, 30),
		"Wait? W / Cancel: N",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		20,
		Color.WHITE
	)


func draw_attack_confirmation_prompt():

	if not awaiting_attack_confirmation:
		return

	draw_string(
		ThemeDB.fallback_font,
		Vector2(260, 30),
		"Attack? Y/N",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		20,
		Color.WHITE
	)


func draw_heal_confirmation_prompt():

	if not awaiting_heal_confirmation:
		return

	draw_string(
		ThemeDB.fallback_font,
		Vector2(260, 30),
		"Heal: H / Regen: R / Cancel: N",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		20,
		Color.WHITE
	)


func draw_attack_hover_preview():

	if not hover_query.is_hovering_attackable_enemy(
		units,
		selected_unit,
		pending_move_cell,
		hovered_cell,
		has_pending_move(),
		unit_logic,
		unit_query,
		map_data
	):
		return

	var rect = map_data.grid_rect(hovered_cell)

	draw_rect(
		rect,
		Color(1.0, 0.0, 0.0, 0.45),
		true
	)

	draw_rect(
		rect,
		Color.WHITE,
		false,
		4
	)

# =========================
# Draws hover preview for valid
# healer support targets.
#
# Highlights healable allies currently
# inside healer support range.
# =========================

func draw_heal_hover_preview():

	if not hover_query.is_hovering_healable_ally(
		units,
		selected_unit,
		pending_move_cell,
		hovered_cell,
		has_pending_move(),
		unit_logic,
		unit_query,
		map_data
	):
		return

	var rect = map_data.grid_rect(hovered_cell)

	draw_rect(
		rect,
		Color(0.2, 0.6, 1.0, 0.45),
		true
	)

	draw_rect(
		rect,
		Color.WHITE,
		false,
		4
	)
	
# ==================================================
# ENGINE CALLBACKS
# ==================================================

# =========================
# Initial setup.
# =========================

func _ready():

	units = battle_setup.create_battle_units(unit_data)

	queue_redraw()

# =========================
# Per-frame updates.
# =========================

func _process(_delta):

	var mouse_pos = get_viewport().get_mouse_position()

	hovered_cell = map_data.world_to_grid(mouse_pos)

	queue_redraw()


# ==================================================
# INPUT HANDLING
# ==================================================

# =========================
# Main input dispatcher.
# =========================

func _input(event):

	handle_keyboard_input(event)
	handle_mouse_input(event)


# ==================================================
# KEYBOARD INPUT
# ==================================================

# =========================
# Handles keyboard shortcuts and confirmations.
# =========================

func handle_keyboard_input(event):

	if not event is InputEventKey:
		return

	if not event.pressed:
		return

	match event.keycode:

		KEY_C:
			cycle_coverage_mode()

		KEY_T:
			end_player_turn()

		KEY_W:
			handle_wait_hotkey()

		KEY_Y:
			handle_attack_confirm_hotkey()

		KEY_H:
			handle_heal_hotkey()

		KEY_R:
			handle_regen_hotkey()

		KEY_N:
			cancel_pending_action()


# =========================
# Cycles coverage overlay display.
# =========================

func cycle_coverage_mode():

	coverage_mode += 1

	if coverage_mode > 3:
		coverage_mode = 0

	queue_redraw()


# =========================
# Ends the current player turn.
#
# Also restores healer charges for
# idle player healers before the
# turn officially advances.
# =========================

func end_player_turn():

	if turn_manager.current_team == "player":
		stamina_system.recover_idle_player_healers(units)

	turn_manager.end_turn(units)

	if turn_manager.current_team == "player":
		turn_number += 1

	clear_selection()

	queue_redraw()


# =========================
# Confirms wait action.
# =========================

func handle_wait_hotkey():

	if awaiting_wait_confirmation:
		confirm_wait()


# =========================
# Confirms attack action.
# =========================

func handle_attack_confirm_hotkey():

	if awaiting_attack_confirmation:
		confirm_attack()


# =========================
# Confirms direct heal action.
# =========================

func handle_heal_hotkey():

	if awaiting_heal_confirmation:
		confirm_heal()


# =========================
# Confirms regeneration spell.
# =========================

func handle_regen_hotkey():

	if awaiting_heal_confirmation:
		confirm_regen()


# =========================
# Cancels pending actions/selections.
# =========================

func cancel_pending_action():

	clear_pending_action_state()

	queue_redraw()


# ==================================================
# MOUSE INPUT
# ==================================================

# =========================
# Handles mouse click interaction.
# =========================

func handle_mouse_input(event):

	if not event is InputEventMouseButton:
		return

	if not event.pressed:
		return

	# =========================
	# Right click = cancel / deselect
	# =========================

	if event.button_index == MOUSE_BUTTON_RIGHT:

		clear_pending_action_state()

		queue_redraw()

		return

	# =========================
	# Left click = normal selection/action
	# =========================

	if event.button_index == MOUSE_BUTTON_LEFT:
		handle_left_click()


# =========================
# Main left-click handler.
# =========================

func handle_left_click():

	var clicked_cell = hovered_cell

	if not map_data.is_inside_grid(clicked_cell):
		return

	if selected_unit != -1 and has_pending_move():

		if clicked_cell == pending_move_cell:
			start_wait_confirmation()
			return

		if action_query.should_handle_heal_click(
			units,
			selected_unit,
			pending_move_cell,
			hovered_cell,
			has_pending_move(),
			unit_logic,
			unit_query,
			hover_query,
			map_data
		):
			handle_heal_click(clicked_cell)
			return

		if action_query.should_handle_attack_click(
			units,
			selected_unit,
			pending_move_cell,
			hovered_cell,
			has_pending_move(),
			unit_logic,
			unit_query,
			hover_query,
			map_data
		):
			handle_attack_click(clicked_cell)
			return

		if (
			action_query.is_clicking_empty_action_tile(
				units,
				selected_unit,
				clicked_cell,
				pending_move_cell,
				has_pending_move(),
				unit_logic,
				unit_query,
				map_data
			)
			and (
				units[selected_unit]["class"] == "archer"
				or units[selected_unit]["class"] == "healer"
			)
		):
			start_wait_confirmation()
			return

		if action_query.should_handle_facing_click(
			units,
			selected_unit,
			clicked_cell,
			pending_move_cell,
			pending_move_distance,
			pending_move_direction,
			hovered_cell,
			has_pending_move(),
			unit_logic,
			unit_query,
			hover_query,
			map_data
		):
			handle_facing_click(clicked_cell)
			return

		return

	if action_query.should_handle_move_click(
		selected_unit,
		move_tiles,
		clicked_cell
	):
		handle_move_tile_click(clicked_cell)
		return

	handle_unit_click(clicked_cell)

# =========================
# Returns all valid lancer
# facing-selection tiles.
#
# Filters lancer attack tiles using
# movement-based facing restrictions.
# =========================

func get_valid_lancer_facing_tiles() -> Array[Vector2i]:

	var valid_tiles: Array[Vector2i] = []

	var lancer_tiles = unit_logic.get_attack_choice_tiles(
		pending_move_cell,
		"lancer",
		map_data
	)

	var allowed_dirs: Array[Vector2i] = []

	if used_max_movement():
		allowed_dirs = unit_logic.get_limited_facing_dirs(
			pending_move_direction
		)
	else:
		allowed_dirs = unit_logic.get_all_facing_dirs()

	for cell in lancer_tiles:

		var facing = action_query.get_lancer_facing_from_target(
			pending_move_cell,
			cell
		)

		if allowed_dirs.has(facing):
			valid_tiles.append(cell)

	return valid_tiles

# =========================
# Clears selection and pending movement state.
# =========================

func clear_selection():

	selected_unit = -1
	selected_unit_start_cell = Vector2i(-1, -1)

	move_tiles.clear()

	pending_move_cell = Vector2i(-1, -1)
	pending_facing = Vector2i.ZERO
	pending_move_distance = 0
	pending_move_direction = Vector2i.ZERO

	pending_coverage_enemies.clear()


# =========================
# Clears pending action confirmation state.
#
# If a unit had visually moved, it is restored
# to its original starting cell.
# =========================

func clear_pending_action_state():

	if selected_unit != -1 and has_pending_move():
		units[selected_unit]["pos"] = selected_unit_start_cell

	awaiting_attack_confirmation = false
	awaiting_heal_confirmation = false
	awaiting_wait_confirmation = false

	pending_attack_target = -1
	pending_heal_target = -1

	clear_selection()

# ==================================================
# SELECTION / MOVEMENT FLOW
# ==================================================

func has_pending_move() -> bool:

	return selection_state.has_pending_move(
		pending_move_cell
	)


func used_max_movement() -> bool:

	return selection_state.used_max_movement(
		units,
		selected_unit,
		pending_move_cell,
		pending_move_distance
	)

# =========================
# Handles clicking a unit or empty tile
# during normal selection mode.
# =========================

func handle_unit_click(clicked_cell: Vector2i):

	var clicked_unit = unit_query.get_unit_at(
		units,
		clicked_cell
	)

	if clicked_unit == -1:
		clear_selection()
		return

	if units[clicked_unit]["team"] != turn_manager.current_team:
		return

	if units[clicked_unit]["has_acted"]:
		return

	if selected_unit == clicked_unit:
		clear_selection()
		return

	select_unit(clicked_unit)


# =========================
# Selects a unit and calculates movement tiles.
# =========================

func select_unit(unit_index: int):

	selected_unit = unit_index
	selected_unit_start_cell = units[selected_unit]["pos"]

	# Clear pending movement/action state.
	pending_move_cell = Vector2i(-1, -1)
	pending_facing = Vector2i.ZERO
	pending_move_distance = 0
	pending_move_direction = Vector2i.ZERO
	pending_coverage_enemies.clear()

	pending_attack_target = -1
	pending_heal_target = -1

	awaiting_attack_confirmation = false
	awaiting_heal_confirmation = false
	awaiting_wait_confirmation = false

	move_tiles = map_data.get_move_range(
		units[selected_unit]["pos"],
		units[selected_unit]["move"],
		unit_query.get_enemy_occupied_tiles(
		units,
		selected_unit
		)
	)

	queue_redraw()


# =========================
# Handles clicking a valid movement tile.
#
# The unit visually moves immediately,
# but the move is not finalized until
# the player confirms an action/facing/wait.
# =========================

func handle_move_tile_click(clicked_cell: Vector2i):

	if selected_unit == -1:
		return

	if unit_query.is_tile_occupied(
		units,
		clicked_cell
	) and clicked_cell != units[selected_unit]["pos"]:
		return

	var start = selected_unit_start_cell

	pending_move_cell = clicked_cell

	pending_coverage_enemies = coverage_system.get_enemies_entered_coverage(
		units,
		unit_logic,
		selected_unit,
		selected_unit_start_cell,
		clicked_cell
	)

	units[selected_unit]["pos"] = pending_move_cell

	pending_facing = Vector2i.ZERO

	pending_move_distance = map_data.get_grid_distance(
		start,
		clicked_cell
	)

	pending_move_direction = map_data.get_primary_direction(
		start,
		clicked_cell
	)

	move_tiles.clear()

	queue_redraw()


# =========================
# Handles clicking a valid facing tile.
#
# Facing selection confirms movement,
# updates facing direction, and ends the unit's action.
# =========================

func handle_facing_click(clicked_cell: Vector2i):

	if selected_unit == -1:
		return

	if not has_pending_move():
		return

	var valid_facing_click = false

	if units[selected_unit]["class"] == "lancer":
		valid_facing_click = get_valid_lancer_facing_tiles().has(clicked_cell)
	else:
		var facing_tiles = unit_logic.get_facing_choice_tiles(
			pending_move_cell,
			pending_move_distance,
			pending_move_direction,
			units[selected_unit]["move"],
			map_data
		)

		valid_facing_click = facing_tiles.has(clicked_cell)

	if not valid_facing_click:
		return

	if units[selected_unit]["class"] == "lancer":
		pending_facing = action_query.get_lancer_facing_from_target(
			pending_move_cell,
			clicked_cell
		)
	else:
		pending_facing = clicked_cell - pending_move_cell

	units[selected_unit]["facing"] = pending_facing
	units[selected_unit]["has_acted"] = true

	if coverage_system.resolve_pending_coverage_if_needed(
		units,
		combat_logic,
		selected_unit,
		pending_coverage_enemies
	):
		units.remove_at(selected_unit)
		clear_selection()
		queue_redraw()
		return

	stamina_system.spend_movement_stamina(
		units,
		selected_unit,
		pending_move_distance
	)

	clear_selection()
	auto_end_turn_if_needed()

	queue_redraw()


# =========================
# Starts wait confirmation.
# =========================

func start_wait_confirmation():

	awaiting_wait_confirmation = true
	awaiting_attack_confirmation = false
	awaiting_heal_confirmation = false

	pending_attack_target = -1
	pending_heal_target = -1

	queue_redraw()

# ==================================================
# ACTION CONFIRMATION FLOW
# ==================================================

# =========================
# Starts attack confirmation against an enemy unit.
# =========================

func start_attack_confirmation(target_unit: int):

	pending_attack_target = target_unit

	awaiting_attack_confirmation = true
	awaiting_heal_confirmation = false
	awaiting_wait_confirmation = false

	pending_heal_target = -1

	queue_redraw()


# =========================
# Starts heal/regeneration confirmation
# on an allied unit.
# =========================

func start_heal_confirmation(target_unit: int):

	pending_heal_target = target_unit

	awaiting_heal_confirmation = true
	awaiting_attack_confirmation = false
	awaiting_wait_confirmation = false

	pending_attack_target = -1

	queue_redraw()


# =========================
# Handles clicking an enemy attack target.
# =========================

func handle_attack_click(clicked_cell: Vector2i):

	var clicked_unit = unit_query.get_unit_at(
		units,
		clicked_cell
	)

	if unit_query.is_enemy_unit(
		units,
		selected_unit,
		clicked_unit
	):
		start_attack_confirmation(clicked_unit)


# =========================
# Handles clicking an allied heal target.
# =========================

func handle_heal_click(clicked_cell: Vector2i):

	var clicked_unit = unit_query.get_unit_at(
		units,
		clicked_cell
	)

	if unit_query.is_ally_unit(
		units,
		selected_unit,
		clicked_unit
	):
		start_heal_confirmation(clicked_unit)


# =========================
# Confirms pending attack.
#
# Movement is finalized first.
# Then attack stamina is spent.
# Then attack damage is resolved.
# =========================

func confirm_attack():

	if selected_unit == -1:
		return

	if pending_attack_target == -1:
		return

	var target_pos = units[pending_attack_target]["pos"]

	var attack_direction = target_pos - pending_move_cell

	attack_direction = Vector2i(
		sign(attack_direction.x),
		sign(attack_direction.y)
	)

	units[selected_unit]["facing"] = attack_direction
	units[selected_unit]["has_acted"] = true

	if coverage_system.resolve_pending_coverage_if_needed(
		units,
		combat_logic,
		selected_unit,
		pending_coverage_enemies
	):

		units.remove_at(selected_unit)
		clear_selection()
		queue_redraw()
		return

	stamina_system.spend_movement_stamina(
		units,
		selected_unit,
		pending_move_distance
	)

	var defender_died = combat_logic.resolve_attack(
		units[selected_unit],
		units[pending_attack_target]
	)

	stamina_system.spend_attack_stamina(
		units,
		selected_unit
	)

	if defender_died:
		units.remove_at(pending_attack_target)

	pending_attack_target = -1
	awaiting_attack_confirmation = false

	clear_selection()
	auto_end_turn_if_needed()

	queue_redraw()


# =========================
# Confirms wait action.
#
# Used for:
# - archers
# - healers
# - choosing not to attack after moving
# =========================

func confirm_wait():

	if selected_unit == -1:
		return

	if not has_pending_move():
		return

	units[selected_unit]["has_acted"] = true

	if coverage_system.resolve_pending_coverage_if_needed(
		units,
		combat_logic,
		selected_unit,
		pending_coverage_enemies
	):

		units.remove_at(selected_unit)
		clear_selection()
		queue_redraw()
		return

	stamina_system.spend_movement_stamina(
		units,
		selected_unit,
		pending_move_distance
	)

	awaiting_wait_confirmation = false

	clear_selection()
	auto_end_turn_if_needed()

	queue_redraw()


# =========================
# Confirms instant heal action.
# =========================

func confirm_heal():

	if selected_unit == -1:
		return

	if pending_heal_target == -1:
		return

	if units[selected_unit]["heal_charges"] <= 0:
		return

	var dead_index = selected_unit

	if coverage_system.resolve_pending_coverage_if_needed(
		units,
		combat_logic,
		selected_unit,
		pending_coverage_enemies
	):

		units.remove_at(dead_index)
		clear_selection()
		queue_redraw()
		return

	stamina_system.spend_movement_stamina(
		units,
		selected_unit,
		pending_move_distance
	)

	combat_logic.apply_heal(
		units[pending_heal_target],
		15
	)

	units[selected_unit]["heal_charges"] -= 1
	units[selected_unit]["stamina"] = max(
		units[selected_unit]["stamina"]
		- units[selected_unit]["heal_stamina_cost"],
		0
		)
	units[selected_unit]["has_acted"] = true

	pending_heal_target = -1
	awaiting_heal_confirmation = false

	clear_selection()
	auto_end_turn_if_needed()

	queue_redraw()


# =========================
# Confirms regeneration action.
# =========================

func confirm_regen():

	if selected_unit == -1:
		return

	if pending_heal_target == -1:
		return

	if units[selected_unit]["heal_charges"] <= 0:
		return

	var dead_index = selected_unit

	if coverage_system.resolve_pending_coverage_if_needed(
		units,
		combat_logic,
		selected_unit,
		pending_coverage_enemies
	):

		units.remove_at(dead_index)
		clear_selection()
		queue_redraw()
		return

	stamina_system.spend_movement_stamina(
		units,
		selected_unit,
		pending_move_distance
	)

	combat_logic.apply_regen(
		units[pending_heal_target],
		5,
		4
	)

	units[selected_unit]["heal_charges"] -= 1
	units[selected_unit]["stamina"] = max(
		units[selected_unit]["stamina"]
		- units[selected_unit]["regen_stamina_cost"],
		0
		)
	units[selected_unit]["has_acted"] = true

	pending_heal_target = -1
	awaiting_heal_confirmation = false

	clear_selection()
	auto_end_turn_if_needed()

	queue_redraw()


# =========================
# Automatically ends the current team's turn
# if all units on that team have acted.
# =========================

func auto_end_turn_if_needed():

	for unit in units:

		if unit["team"] != turn_manager.current_team:
			continue

		if not unit["has_acted"]:
			return

	if turn_manager.current_team == "player":
		stamina_system.recover_idle_player_healers(units)

	turn_manager.end_turn(units)

	if turn_manager.current_team == "player":
		turn_number += 1

	queue_redraw()
	

# ==================================================
# ARCHER HELPERS
# ==================================================

# =========================
# Returns closest valid archer distance
# from current movement options to a target tile.
#
# Used for future preview/AI logic.
# =========================

func get_best_archer_distance_squared_to_tile(
	target: Vector2i
) -> int:

	var best_distance_squared = 999999

	for move_tile in move_tiles:

		if not map_data.has_clear_attack_line(
			move_tile,
			target
		):
			continue

		var diff = target - move_tile

		var distance_squared = (
			diff.x * diff.x
			+ diff.y * diff.y
		)

		if distance_squared < best_distance_squared:
			best_distance_squared = distance_squared

	return best_distance_squared

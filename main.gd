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

@onready var map_data = $MapData
@onready var unit_logic = $UnitLogic
@onready var combat_logic = $CombatLogic
@onready var turn_manager = $TurnManager
@onready var unit_data = $UnitData

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

		attack_tiles = unit_logic.get_attack_tiles(
			unit["pos"],
			unit["move"],
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

		if not has_active_coverage(i):
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

	if is_hovering_attackable_enemy():
		return

	var unit_class = units[selected_unit]["class"]
	var facing: Vector2i = Vector2i.ZERO

	if unit_class == "lancer":

		var lancer_tiles = get_valid_lancer_facing_tiles()

		if not lancer_tiles.has(hovered_cell):
			return

		facing = get_lancer_facing_from_target(
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
			str(get_display_stamina(i)),
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

	if not is_hovering_attackable_enemy():
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

	if not is_hovering_healable_ally():
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

	units = [
		# Player units - top-left 2x3 block
		unit_data.create_unit("fighter", "player", Vector2i(1, 2), Vector2i(0, 1)),
		unit_data.create_unit("tank", "player", Vector2i(2, 2), Vector2i(0, 1)),
		unit_data.create_unit("lancer", "player", Vector2i(3, 2), Vector2i(0, 1)),
		unit_data.create_unit("duelist", "player", Vector2i(1, 3), Vector2i(0, 1)),
		unit_data.create_unit("healer", "player", Vector2i(2, 3), Vector2i(0, 1)),
		unit_data.create_unit("archer", "player", Vector2i(3, 3), Vector2i(0, 1)),

		# Player units - bottom-left 2x3 block
		unit_data.create_unit("fighter", "player", Vector2i(1, 8), Vector2i(0, -1)),
		unit_data.create_unit("tank", "player", Vector2i(2, 8), Vector2i(0, -1)),
		unit_data.create_unit("lancer", "player", Vector2i(3, 8), Vector2i(0, -1)),
		unit_data.create_unit("duelist", "player", Vector2i(1, 9), Vector2i(0, -1)),
		unit_data.create_unit("healer", "player", Vector2i(2, 9), Vector2i(0, -1)),
		unit_data.create_unit("archer", "player", Vector2i(3, 9), Vector2i(0, -1)),

		# Enemy units - top-right 2x3 block
		unit_data.create_unit("fighter", "enemy", Vector2i(12, 2), Vector2i(0, 1)),
		unit_data.create_unit("tank", "enemy", Vector2i(13, 2), Vector2i(0, 1)),
		unit_data.create_unit("lancer", "enemy", Vector2i(14, 2), Vector2i(0, 1)),
		unit_data.create_unit("duelist", "enemy", Vector2i(12, 3), Vector2i(0, 1)),
		unit_data.create_unit("healer", "enemy", Vector2i(13, 3), Vector2i(0, 1)),
		unit_data.create_unit("archer", "enemy", Vector2i(14, 3), Vector2i(0, 1)),

		# Enemy units - bottom-right 2x3 block
		unit_data.create_unit("fighter", "enemy", Vector2i(12, 8), Vector2i(0, -1)),
		unit_data.create_unit("tank", "enemy", Vector2i(13, 8), Vector2i(0, -1)),
		unit_data.create_unit("lancer", "enemy", Vector2i(14, 8), Vector2i(0, -1)),
		unit_data.create_unit("duelist", "enemy", Vector2i(12, 9), Vector2i(0, -1)),
		unit_data.create_unit("healer", "enemy", Vector2i(13, 9), Vector2i(0, -1)),
		unit_data.create_unit("archer", "enemy", Vector2i(14, 9), Vector2i(0, -1))
	]

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
		recover_idle_player_healers()

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

		if should_handle_heal_click(clicked_cell):
			handle_heal_click(clicked_cell)
			return

		if should_handle_attack_click(clicked_cell):
			handle_attack_click(clicked_cell)
			return

		if (
			is_clicking_empty_action_tile(clicked_cell)
			and (
				units[selected_unit]["class"] == "archer"
				or units[selected_unit]["class"] == "healer"
			)
		):
			start_wait_confirmation()
			return

		if should_handle_facing_click(clicked_cell):
			handle_facing_click(clicked_cell)
			return

		return

	if should_handle_move_click(clicked_cell):
		handle_move_tile_click(clicked_cell)
		return

	handle_unit_click(clicked_cell)

# ==================================================
# CLICK PHASE HELPERS
# ==================================================

# =========================
# Returns true if this click should
# resolve facing selection.
# =========================

func should_handle_facing_click(
	clicked_cell: Vector2i
) -> bool:

	if selected_unit == -1:
		return false

	if not has_pending_move():
		return false

	if (
		units[selected_unit]["class"] == "archer"
		or units[selected_unit]["class"] == "healer"
	):
		return false

	if is_hovering_attackable_enemy():
		return false

	if units[selected_unit]["class"] == "lancer":

		var lancer_tiles = unit_logic.get_attack_choice_tiles(
			pending_move_cell,
			"lancer",
			map_data
		)

		return lancer_tiles.has(clicked_cell)

	var facing_tiles = unit_logic.get_facing_choice_tiles(
		pending_move_cell,
		pending_move_distance,
		pending_move_direction,
		units[selected_unit]["move"],
		map_data
	)

	return facing_tiles.has(clicked_cell)

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

	var allowed_dirs = unit_logic.get_limited_facing_dirs(
		pending_move_direction
	)

	for cell in lancer_tiles:

		var facing = get_lancer_facing_from_target(
			pending_move_cell,
			cell
		)

		if allowed_dirs.has(facing):
			valid_tiles.append(cell)

	return valid_tiles

# =========================
# Returns true if clicking an empty
# action-range tile after moving.
#
# Used by archer/healer to allow
# empty target-range clicks to prompt wait.
# =========================

func is_clicking_empty_action_tile(clicked_cell: Vector2i) -> bool:

	if selected_unit == -1:
		return false

	if not has_pending_move():
		return false

	if get_unit_at(clicked_cell) != -1:
		return false

	var unit_class = units[selected_unit]["class"]

	var attack_tiles: Array[Vector2i] = []

	if unit_class == "healer":

		var heal_tiles = unit_logic.get_heal_choice_tiles(
			pending_move_cell,
			map_data
		)

		attack_tiles = unit_logic.get_adjacent_choice_tiles(
			pending_move_cell,
			map_data
		)

		return (
			heal_tiles.has(clicked_cell)
			or attack_tiles.has(clicked_cell)
		)

	attack_tiles = unit_logic.get_attack_choice_tiles(
		pending_move_cell,
		unit_class,
		map_data
	)

	return attack_tiles.has(clicked_cell)

# =========================
# Returns lancer facing direction
# based on selected attack tile.
#
# Knight-move attack tiles automatically
# resolve to a cardinal facing direction
# using the dominant movement axis.
# =========================

func get_lancer_facing_from_target(
	start_cell: Vector2i,
	target_cell: Vector2i
) -> Vector2i:

	var diff = target_cell - start_cell

	if abs(diff.x) > abs(diff.y):
		return Vector2i(sign(diff.x), 0)

	if abs(diff.y) > abs(diff.x):
		return Vector2i(0, sign(diff.y))

	return Vector2i(
		sign(diff.x),
		sign(diff.y)
	)

# =========================
# Returns true if this click should
# resolve attack targeting.
# =========================

func should_handle_attack_click(
	_clicked_cell: Vector2i
) -> bool:

	if selected_unit == -1:
		return false

	if not has_pending_move():
		return false

	return is_hovering_attackable_enemy()


# =========================
# Returns true if this click should
# resolve healing targeting.
# =========================

func should_handle_heal_click(
	_clicked_cell: Vector2i
) -> bool:

	if selected_unit == -1:
		return false

	if not has_pending_move():
		return false

	if units[selected_unit]["class"] != "healer":
		return false

	return is_hovering_healable_ally()


# =========================
# Returns true if this click should
# resolve movement selection.
# =========================

func should_handle_move_click(
	clicked_cell: Vector2i
) -> bool:

	if selected_unit == -1:
		return false

	return move_tiles.has(clicked_cell)
	
# ==================================================
# SELECTION / MOVEMENT FLOW
# ==================================================

# =========================
# Handles clicking a unit or empty tile
# during normal selection mode.
# =========================

func handle_unit_click(clicked_cell: Vector2i):

	var clicked_unit = get_unit_at(clicked_cell)

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
		get_enemy_occupied_tiles(selected_unit)
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

	if is_tile_occupied(clicked_cell) and clicked_cell != units[selected_unit]["pos"]:
		return

	var start = selected_unit_start_cell

	pending_move_cell = clicked_cell

	pending_coverage_enemies = get_enemies_entered_coverage(
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
		pending_facing = get_lancer_facing_from_target(
			pending_move_cell,
			clicked_cell
		)
	else:
		pending_facing = clicked_cell - pending_move_cell

	units[selected_unit]["facing"] = pending_facing
	units[selected_unit]["has_acted"] = true

	if resolve_pending_coverage_if_needed():
		units.remove_at(selected_unit)
		clear_selection()
		queue_redraw()
		return

	spend_movement_stamina(selected_unit)

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


# =========================
# Returns true if a destination tile
# is currently pending.
# =========================

func has_pending_move() -> bool:

	return pending_move_cell != Vector2i(-1, -1)
	
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

	var clicked_unit = get_unit_at(clicked_cell)

	if is_enemy_unit(clicked_unit):
		start_attack_confirmation(clicked_unit)


# =========================
# Handles clicking an allied heal target.
# =========================

func handle_heal_click(clicked_cell: Vector2i):

	var clicked_unit = get_unit_at(clicked_cell)

	if is_ally_unit(clicked_unit):
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

	if resolve_pending_coverage_if_needed():

		units.remove_at(selected_unit)
		clear_selection()
		queue_redraw()
		return

	spend_movement_stamina(selected_unit)

	var defender_died = combat_logic.resolve_attack(
		units[selected_unit],
		units[pending_attack_target]
	)

	spend_attack_stamina(selected_unit)

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

	if resolve_pending_coverage_if_needed():

		units.remove_at(selected_unit)
		clear_selection()
		queue_redraw()
		return

	spend_movement_stamina(selected_unit)

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

	if resolve_pending_coverage_if_needed():

		units.remove_at(dead_index)
		clear_selection()
		queue_redraw()
		return

	spend_movement_stamina(selected_unit)

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

	if resolve_pending_coverage_if_needed():

		units.remove_at(dead_index)
		clear_selection()
		queue_redraw()
		return

	spend_movement_stamina(selected_unit)

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
		recover_idle_player_healers()

	turn_manager.end_turn(units)

	if turn_manager.current_team == "player":
		turn_number += 1

	queue_redraw()
	
# =========================
# Returns true if a unit currently has active coverage.
#
# Coverage requires:
# - a valid facing direction
# - enough stamina remaining
# - reaction not already used
# =========================

func has_active_coverage(unit_index: int) -> bool:

	var unit = units[unit_index]

	if unit["facing"] == Vector2i.ZERO:
		return false

	if unit["reaction_used"]:
		return false

	if unit["stamina"] < unit["counter_stamina_cost"]:
		return false

	return true


# =========================
# Returns all enemies whose coverage
# the moving unit ENTERED.
#
# Does not trigger if:
# - the unit started inside that same coverage
# - the unit moves out of coverage
# - the unit stands still inside coverage
# =========================

func get_enemies_entered_coverage(
	unit_index: int,
	start_cell: Vector2i,
	target_cell: Vector2i
) -> Array[int]:

	var covering_enemies: Array[int] = []

	var moving_team = units[unit_index]["team"]

	for i in range(units.size()):

		if units[i]["team"] == moving_team:
			continue

		if not has_active_coverage(i):
			continue

		var covered_tiles = unit_logic.get_coverage_tiles(
			units[i]["class"],
			units[i]["pos"],
			units[i]["facing"]
		)

		var started_in_coverage = covered_tiles.has(start_cell)
		var ended_in_coverage = covered_tiles.has(target_cell)

		if ended_in_coverage and not started_in_coverage:
			covering_enemies.append(i)

	return covering_enemies


# =========================
# Resolves delayed coverage damage.
#
# Multiple overlapping coverage zones
# each resolve individually.
#
# Returns:
# - true if selected unit dies
# - false otherwise
# =========================

func resolve_pending_coverage_if_needed() -> bool:

	if pending_coverage_enemies.is_empty():
		return false

	for covering_enemy in pending_coverage_enemies:

		var unit_died = resolve_coverage_reaction(
			selected_unit,
			covering_enemy
		)

		if unit_died:
			pending_coverage_enemies.clear()
			return true

	pending_coverage_enemies.clear()

	return false


# =========================
# Resolves a coverage reaction attack.
#
# The covering unit spends stamina
# to perform the reaction attack.
# =========================

func resolve_coverage_reaction(
	moving_unit: int,
	covering_unit: int
) -> bool:

	units[covering_unit]["reaction_used"] = true

	units[covering_unit]["stamina"] = max(
		units[covering_unit]["stamina"]
		- units[covering_unit]["counter_stamina_cost"],
		0
	)

	var defender_died = combat_logic.resolve_attack(
		units[covering_unit],
		units[moving_unit],
		units[covering_unit]["counter_damage_multiplier"]
	)

	return defender_died


# ==================================================
# STAMINA SYSTEM
# ==================================================

# =========================
# Spends stamina based on movement distance.
#
# Moving farther reduces remaining
# defensive reaction potential.
# =========================

func spend_movement_stamina(unit_index: int):

	if unit_index == -1:
		return

	var movement_cost = (
		pending_move_distance
		* units[unit_index]["move_stamina_cost"]
	)

	units[unit_index]["stamina"] = max(
		units[unit_index]["stamina"] - movement_cost,
		0
	)

# =========================
# Spends stamina when a unit attacks.
#
# Archer special rule:
# - firing consumes all remaining stamina
#
# Other classes:
# - spend their attack stamina cost
# =========================

func spend_attack_stamina(unit_index: int):

	if unit_index == -1:
		return

	if units[unit_index]["class"] == "archer":
		units[unit_index]["stamina"] = 0
		return

	units[unit_index]["stamina"] = max(
		units[unit_index]["stamina"] - units[unit_index]["attack_stamina_cost"],
		0
	)

# =========================
# Returns displayed stamina for a unit.
#
# Pending movement does not actually spend
# stamina until the action is confirmed,
# but the UI should preview expected stamina.
# =========================

func get_display_stamina(unit_index: int) -> int:

	if unit_index != selected_unit:
		return units[unit_index]["stamina"]

	if not has_pending_move():
		return units[unit_index]["stamina"]

	var movement_cost = (
		pending_move_distance
		* units[unit_index]["move_stamina_cost"]
	)

	return max(
		units[unit_index]["stamina"] - movement_cost,
		0
	)

# =========================
# Recovers healer charges based on
# remaining stamina at turn end.
#
# 90+ stamina = +2 charges
# 50+ stamina = +1 charge
# Below 50 = no recovery
# =========================

func recover_idle_player_healers():

	for unit in units:

		if unit["team"] != "player":
			continue

		if unit["class"] != "healer":
			continue

		var recovery_amount = 0

		if (
			unit["stamina"]
			>= unit["charge_recovery_threshold_2"]
		):
			recovery_amount = 2

		elif (
			unit["stamina"]
			>= unit["charge_recovery_threshold_1"]
		):
			recovery_amount = 1

		unit["heal_charges"] = min(
			unit["heal_charges"] + recovery_amount,
			unit["max_heal_charges"]
		)


# =========================
# Returns true if selected unit is healer.
# =========================

func selected_unit_is_healer() -> bool:

	if selected_unit == -1:
		return false

	return units[selected_unit]["class"] == "healer"


# ==================================================
# TILE / UNIT HELPERS
# ==================================================

# =========================
# Returns unit index at a tile.
#
# Returns:
# - unit index
# - or -1 if empty
# =========================

func get_unit_at(cell: Vector2i) -> int:

	for i in range(units.size()):

		if units[i]["pos"] == cell:
			return i

	return -1


# =========================
# Returns true if a tile contains any unit.
# =========================

func is_tile_occupied(cell: Vector2i) -> bool:

	return get_unit_at(cell) != -1


# =========================
# Returns true if selected unit
# considers target unit an enemy.
# =========================

func is_enemy_unit(target_unit: int) -> bool:

	if selected_unit == -1:
		return false

	if target_unit == -1:
		return false

	return (
		units[target_unit]["team"]
		!= units[selected_unit]["team"]
	)


# =========================
# Returns true if selected unit
# considers target unit an ally.
# =========================

func is_ally_unit(target_unit: int) -> bool:

	if selected_unit == -1:
		return false

	if target_unit == -1:
		return false

	return (
		units[target_unit]["team"]
		== units[selected_unit]["team"]
	)


# =========================
# Returns enemy-occupied tiles.
#
# Used to prevent movement through enemies.
# =========================

func get_enemy_occupied_tiles(
	unit_index: int
) -> Array[Vector2i]:

	var occupied: Array[Vector2i] = []

	var unit_team = units[unit_index]["team"]

	for i in range(units.size()):

		if i == unit_index:
			continue

		if units[i]["team"] != unit_team:
			occupied.append(units[i]["pos"])

	return occupied


# ==================================================
# HOVER HELPERS
# ==================================================

# =========================
# Returns true if hovering a valid attack target.
# =========================

func is_hovering_attackable_enemy() -> bool:

	if selected_unit == -1:
		return false

	if not has_pending_move():
		return false

	var attack_tiles: Array[Vector2i] = []

	if units[selected_unit]["class"] == "healer":
		attack_tiles = unit_logic.get_adjacent_choice_tiles(
			pending_move_cell,
			map_data
		)
	else:
		attack_tiles = unit_logic.get_attack_choice_tiles(
			pending_move_cell,
			units[selected_unit]["class"],
			map_data
		)

	if not attack_tiles.has(hovered_cell):
		return false

	var hovered_unit = get_unit_at(hovered_cell)

	return is_enemy_unit(hovered_unit)


# =========================
# Returns true if hovering a healable ally.
#
# Uses healer support range, not lancer range.
# =========================

func is_hovering_healable_ally() -> bool:

	if not selected_unit_is_healer():
		return false

	if not has_pending_move():
		return false

	var heal_tiles = unit_logic.get_heal_choice_tiles(
		pending_move_cell,
		map_data
	)

	if not heal_tiles.has(hovered_cell):
		return false

	var hovered_unit = get_unit_at(hovered_cell)

	return is_ally_unit(hovered_unit)


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

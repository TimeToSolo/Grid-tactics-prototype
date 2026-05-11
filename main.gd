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
@onready var action_system = $ActionSystem
@onready var battle_setup = $BattleSetup
@onready var combat_logic = $CombatLogic
@onready var coverage_system = $CoverageSystem
@onready var hover_query = $HoverQuery
@onready var map_data = $MapData
@onready var movement_system = $MovementSystem
@onready var render_system = $RenderSystem
@onready var selection_state = $SelectionState
@onready var selection_system = $SelectionSystem
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

	render_system.draw_grid(
		self,
		map_data
	)

	render_system.draw_move_tiles(
		self,
		map_data,
		units,
		selected_unit,
		selected_unit_start_cell,
		move_tiles
	)

	render_system.draw_heal_range(
		self,
		map_data,
		unit_logic,
		units,
		selected_unit,
		pending_move_cell,
		has_pending_move()
	)

	render_system.draw_attack_range(
		self,
		map_data,
		unit_logic,
		units,
		selected_unit,
		move_tiles,
		pending_move_cell,
		has_pending_move()
	)

	render_system.draw_all_coverage(
		self,
		map_data,
		unit_logic,
		coverage_system,
		units,
		coverage_mode
	)

	render_system.draw_pending_move_tile(
		self,
		map_data,
		pending_move_cell,
		has_pending_move()
	)

	render_system.draw_facing_choice_tiles(
		self,
		map_data,
		unit_logic,
		units,
		selected_unit,
		move_tiles,
		pending_move_cell,
		pending_move_distance,
		pending_move_direction,
		has_pending_move(),
		get_valid_lancer_facing_tiles()
	)

	render_system.draw_coverage_preview(
		self,
		map_data,
		unit_logic,
		unit_query,
		hover_query,
		action_query,
		units,
		selected_unit,
		pending_move_cell,
		pending_move_distance,
		pending_move_direction,
		hovered_cell,
		has_pending_move(),
		get_valid_lancer_facing_tiles()
	)

	render_system.draw_units(
		self,
		map_data,
		unit_logic,
		stamina_system,
		units,
		selected_unit,
		pending_move_distance,
		has_pending_move()
	)

	render_system.draw_attack_hover_preview(
		self,
		map_data,
		unit_logic,
		unit_query,
		hover_query,
		units,
		selected_unit,
		pending_move_cell,
		hovered_cell,
		has_pending_move()
	)

	render_system.draw_heal_hover_preview(
		self,
		map_data,
		unit_logic,
		unit_query,
		hover_query,
		units,
		selected_unit,
		pending_move_cell,
		hovered_cell,
		has_pending_move()
	)

	render_system.draw_turn_indicator(
		self,
		turn_manager,
		turn_number
	)

	render_system.draw_wait_confirmation_prompt(
		self,
		awaiting_wait_confirmation
	)

	render_system.draw_attack_confirmation_prompt(
		self,
		awaiting_attack_confirmation
	)

	render_system.draw_heal_confirmation_prompt(
		self,
		awaiting_heal_confirmation
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

			var state = action_system.start_wait_confirmation()

			awaiting_wait_confirmation = state["awaiting_wait_confirmation"]
			awaiting_attack_confirmation = state["awaiting_attack_confirmation"]
			awaiting_heal_confirmation = state["awaiting_heal_confirmation"]

			pending_attack_target = state["pending_attack_target"]
			pending_heal_target = state["pending_heal_target"]

			queue_redraw()
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
			var state = action_system.get_heal_confirmation_state(
				units,
				selected_unit,
				clicked_cell,
				unit_query
			)

			if not state.is_empty():

				pending_heal_target = state["pending_heal_target"]

				awaiting_heal_confirmation = state["awaiting_heal_confirmation"]
				awaiting_attack_confirmation = state["awaiting_attack_confirmation"]
				awaiting_wait_confirmation = state["awaiting_wait_confirmation"]

				pending_attack_target = state["pending_attack_target"]

				queue_redraw()

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
			var state = action_system.get_attack_confirmation_state(
				units,
				selected_unit,
				clicked_cell,
				unit_query
			)

			if not state.is_empty():

				pending_attack_target = state["pending_attack_target"]

				awaiting_attack_confirmation = state["awaiting_attack_confirmation"]
				awaiting_heal_confirmation = state["awaiting_heal_confirmation"]
				awaiting_wait_confirmation = state["awaiting_wait_confirmation"]

				pending_heal_target = state["pending_heal_target"]

				queue_redraw()

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
			var state = action_system.start_wait_confirmation()

			awaiting_wait_confirmation = state["awaiting_wait_confirmation"]
			awaiting_attack_confirmation = state["awaiting_attack_confirmation"]
			awaiting_heal_confirmation = state["awaiting_heal_confirmation"]

			pending_attack_target = state["pending_attack_target"]
			pending_heal_target = state["pending_heal_target"]

			queue_redraw()
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

	return movement_system.get_valid_lancer_facing_tiles(
		unit_logic,
		action_query,
		map_data,
		pending_move_cell,
		pending_move_direction,
		used_max_movement()
	)

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

	var result = selection_system.handle_unit_click(
		units,
		unit_query,
		turn_manager,
		selected_unit,
		clicked_cell
	)

	if result.is_empty():
		return

	if result["clear_selection"]:
		clear_selection()
		queue_redraw()
		return

	if result["select_unit"]:
		select_unit(result["selected_unit_index"])

# =========================
# Selects a unit and calculates movement tiles.
# =========================

func select_unit(unit_index: int):

	var state = selection_system.select_unit(
		units,
		map_data,
		unit_query,
		unit_index
	)

	selected_unit = state["selected_unit"]
	selected_unit_start_cell = state["selected_unit_start_cell"]
	move_tiles = state["move_tiles"]

	pending_move_cell = state["pending_move_cell"]
	pending_facing = state["pending_facing"]
	pending_move_distance = state["pending_move_distance"]
	pending_move_direction = state["pending_move_direction"]
	pending_coverage_enemies = state["pending_coverage_enemies"]

	pending_attack_target = state["pending_attack_target"]
	pending_heal_target = state["pending_heal_target"]

	awaiting_attack_confirmation = state["awaiting_attack_confirmation"]
	awaiting_heal_confirmation = state["awaiting_heal_confirmation"]
	awaiting_wait_confirmation = state["awaiting_wait_confirmation"]

	queue_redraw()


# =========================
# Handles clicking a valid movement tile.
#
# The unit visually moves immediately,
# but the move is not finalized until
# the player confirms an action/facing/wait.
# =========================

func handle_move_tile_click(clicked_cell: Vector2i):

	var result = movement_system.handle_move_tile_click(
		units,
		unit_query,
		coverage_system,
		unit_logic,
		map_data,
		selected_unit,
		selected_unit_start_cell,
		clicked_cell,
		move_tiles
	)

	if result.is_empty():
		return

	pending_move_cell = result["pending_move_cell"]
	pending_facing = result["pending_facing"]
	pending_move_distance = result["pending_move_distance"]
	pending_move_direction = result["pending_move_direction"]
	pending_coverage_enemies = result["pending_coverage_enemies"]

	queue_redraw()

# =========================
# Handles clicking a valid facing tile.
#
# Facing selection confirms movement,
# updates facing direction, and ends the unit's action.
# =========================

func handle_facing_click(clicked_cell: Vector2i):

	var result = movement_system.handle_facing_click(
		units,
		combat_logic,
		coverage_system,
		stamina_system,
		unit_logic,
		action_query,
		map_data,
		selected_unit,
		clicked_cell,
		pending_move_cell,
		pending_move_distance,
		pending_move_direction,
		pending_coverage_enemies,
		get_valid_lancer_facing_tiles()
	)

	if result.is_empty():
		return

	pending_facing = result["pending_facing"]

	if result["unit_died"]:
		units.remove_at(result["remove_index"])
		clear_selection()
		queue_redraw()
		return

	clear_selection()

	turn_number = action_system.auto_end_turn_if_needed(
		units,
		turn_manager,
		stamina_system,
		turn_number
	)

	queue_redraw()

# =========================
# Confirms pending attack.
#
# Movement is finalized first.
# Then attack stamina is spent.
# Then attack damage is resolved.
# =========================

func confirm_attack():

	var result = action_system.confirm_attack(
		units,
		combat_logic,
		coverage_system,
		stamina_system,
		selected_unit,
		pending_attack_target,
		pending_move_cell,
		pending_move_distance,
		pending_coverage_enemies
	)

	if result.is_empty():
		return

	awaiting_attack_confirmation = result["awaiting_attack_confirmation"]
	pending_attack_target = result["pending_attack_target"]

	if result["attacker_died"]:
		units.remove_at(result["attacker_remove_index"])
		clear_selection()
		queue_redraw()
		return

	if result["defender_died"]:
		units.remove_at(result["defender_remove_index"])

	clear_selection()

	turn_number = action_system.auto_end_turn_if_needed(
		units,
		turn_manager,
		stamina_system,
		turn_number
	)

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

	var result = action_system.confirm_wait(
		units,
		combat_logic,
		coverage_system,
		stamina_system,
		selected_unit,
		pending_move_cell,
		pending_move_distance,
		pending_coverage_enemies
	)

	if result.is_empty():
		return

	awaiting_wait_confirmation = result["awaiting_wait_confirmation"]

	if result["unit_died"]:
		units.remove_at(result["remove_index"])
		clear_selection()
		queue_redraw()
		return

	clear_selection()

	turn_number = action_system.auto_end_turn_if_needed(
		units,
		turn_manager,
		stamina_system,
		turn_number
	)

	queue_redraw()


# =========================
# Confirms instant heal action.
# =========================

func confirm_heal():

	var result = action_system.confirm_heal(
		units,
		combat_logic,
		coverage_system,
		stamina_system,
		selected_unit,
		pending_heal_target,
		pending_move_distance,
		pending_coverage_enemies
	)

	if result.is_empty():
		return

	awaiting_heal_confirmation = result["awaiting_heal_confirmation"]
	pending_heal_target = result["pending_heal_target"]

	if result["unit_died"]:
		units.remove_at(result["remove_index"])
		clear_selection()
		queue_redraw()
		return

	clear_selection()

	turn_number = action_system.auto_end_turn_if_needed(
		units,
		turn_manager,
		stamina_system,
		turn_number
	)

	queue_redraw()


# =========================
# Confirms regeneration action.
# =========================

func confirm_regen():

	var result = action_system.confirm_regen(
		units,
		combat_logic,
		coverage_system,
		stamina_system,
		selected_unit,
		pending_heal_target,
		pending_move_distance,
		pending_coverage_enemies
	)

	if result.is_empty():
		return

	awaiting_heal_confirmation = result["awaiting_heal_confirmation"]
	pending_heal_target = result["pending_heal_target"]

	if result["unit_died"]:
		units.remove_at(result["remove_index"])
		clear_selection()
		queue_redraw()
		return

	clear_selection()

	turn_number = action_system.auto_end_turn_if_needed(
		units,
		turn_manager,
		stamina_system,
		turn_number
	)

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

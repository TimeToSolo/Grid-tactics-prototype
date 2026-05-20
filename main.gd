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

# =========================
# DATA
# =========================

@onready var battle_setup = $Data/BattleSetup
@onready var map_data = $Data/MapData
@onready var unit_data = $Data/UnitData

# =========================
# LOGIC
# =========================

@onready var combat_logic = $Logic/CombatLogic
@onready var stamina_system = $Logic/StaminaSystem
@onready var turn_manager = $Logic/TurnManager
@onready var unit_logic = $Logic/UnitLogic

# =========================
# QUERIES
# =========================

@onready var action_query = $Queries/ActionQuery
@onready var hover_query = $Queries/HoverQuery
@onready var unit_query = $Queries/UnitQuery

# =========================
# SYSTEMS
# =========================

@onready var action_system = $Systems/ActionSystem
@onready var ai_system = $Systems/AISystem
@onready var coverage_system = $Systems/CoverageSystem
@onready var editor_system = $Systems/EditorSystem
@onready var map_serializer = $Systems/MapSerializer
@onready var movement_system = $Systems/MovementSystem
@onready var mission_flow_controller = $Systems/MissionFlowController
@onready var mission_objectives = $Systems/MissionObjectives
@onready var path_preview_system = $Systems/PathPreviewSystem
@onready var render_system = $Systems/RenderSystem
@onready var selection_state = $Systems/SelectionState
@onready var selection_system = $Systems/SelectionSystem

@onready var action_menu_controller = $Systems/ActionMenuController
@onready var phase_popup_controller = $Systems/PhasePopupController
@onready var tactical_input_controller = $Systems/TacticalInputController
@onready var hover_unit_panel_controller = $Systems/HoverUnitPanelController
@onready var post_move_action_flow = $Systems/PostMoveActionFlow

@onready var editor_state = $Systems/EditorState
@onready var editor_render_system = $Systems/EditorRenderSystem
@onready var editor_input_controller = $Systems/EditorInputController
@onready var editor_objective_serializer = $Systems/EditorObjectiveSerializer

# =========================
# UI
# =========================

@onready var hover_unit_panel = $CanvasLayer/HoverUnitPanel
@onready var hover_unit_name_label = $CanvasLayer/HoverUnitPanel/UnitNameLabel
@onready var hover_hp_value_label = $CanvasLayer/HoverUnitPanel/HPValueLabel
@onready var hover_hp_back_bar = $CanvasLayer/HoverUnitPanel/HPBackBar
@onready var hover_hp_bar = $CanvasLayer/HoverUnitPanel/HPBar
@onready var hover_hp_preview_bar = $CanvasLayer/HoverUnitPanel/HPPreviewBar
@onready var hover_stamina_value_label = $CanvasLayer/HoverUnitPanel/StaminaValueLabel
@onready var hover_stamina_bar = $CanvasLayer/HoverUnitPanel/StaminaBar
@onready var hover_hp_text_label = $CanvasLayer/HoverUnitPanel/HPTextLabel
@onready var hover_stamina_text_label = $CanvasLayer/HoverUnitPanel/StaminaTextLabel

@onready var action_menu = $CanvasLayer/ActionMenu
@onready var action_panel = $CanvasLayer/ActionMenu/ActionPanel

@onready var action_vbox = $CanvasLayer/ActionMenu/ActionPanel/VBoxContainer
@onready var move_option_label = $CanvasLayer/ActionMenu/ActionPanel/VBoxContainer/MoveOptionLabel
@onready var attack_option_label = $CanvasLayer/ActionMenu/ActionPanel/VBoxContainer/AttackOptionLabel
@onready var heal_option_label = $CanvasLayer/ActionMenu/ActionPanel/VBoxContainer/HealOptionLabel
@onready var wait_option_label = $CanvasLayer/ActionMenu/ActionPanel/VBoxContainer/WaitOptionLabel

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

# Distance moved during pending movement.
var pending_move_distance = 0

# Original position before movement begins.
var selected_unit_start_cell: Vector2i = Vector2i(-1, -1)

# Mouse hover tracking for previews.
var hovered_cell: Vector2i = Vector2i(-1, -1)

# Current cursor-traced movement preview path.
var hover_path_cells: Array[Vector2i] = []

# Currently inspected non-active unit ID.
var inspected_unit_id := -1

# Keyboard/grid cursor position.
#
# Used by WASD/arrow movement so the
# cursor snaps between grid cells.
var keyboard_cursor_cell: Vector2i = Vector2i(-1, -1)

# True after keyboard cursor has been initialized.
var keyboard_cursor_active := false

# Last mouse-hovered grid cell.
#
# Used to detect real mouse movement
# without disabling keyboard cursor every frame.
var last_mouse_hover_cell: Vector2i = Vector2i(-1, -1)

# ==================================================
# ACTION MENU STATE
# ==================================================

# True after choosing Wait from the action menu.
#
# Enables directional facing selection.
var awaiting_facing_selection := false

# Facing tile chosen during a confirmation menu.
var pending_facing_cell: Vector2i = Vector2i(-1, -1)

# True while player input is disabled.
var input_locked := false

# ==================================================
# OBJECTIVE / MISSION STATE
# ==================================================

var current_objective_data := {}

# True when reinforcements
# should spawn after the
# current enemy phase ends.
var pending_reinforcement_spawn := false

var pending_reinforcement_stage := -1

var staged_reinforcements: Array = []

# =========================
# Saves editor map.
# =========================

func save_editor_map():

	map_serializer.save_map(
		map_data,
		units,
		editor_system.get_editor_map_path(editor_state),
		current_objective_data
	)

# =========================
# Loads editor map.
# =========================

func load_editor_map():

	current_objective_data = map_serializer.load_map(
		map_data,
		units,
		unit_data,
		editor_system.get_editor_map_path(editor_state)
	)

	if current_objective_data.has("objective_zones"):

		deserialize_objective_zones(
			current_objective_data["objective_zones"]
		)

	queue_redraw()

# =========================
# Saves current map as a
# repository campaign level.
# =========================

func save_campaign_level():

	update_current_objective_from_editor()

	map_serializer.save_map(
		map_data,
		units,
		mission_flow_controller.get_campaign_level_path(),
		current_objective_data
	)

# =========================
# Loads current repository
# campaign level.
# =========================

func load_campaign_level():

	current_objective_data = map_serializer.load_map(
		map_data,
		units,
		unit_data,
		mission_flow_controller.get_campaign_level_path()
	)

	if current_objective_data.has("objective_zones"):

		deserialize_objective_zones(
			current_objective_data["objective_zones"]
		)

	queue_redraw()

# ==================================================
# ATTACK / HEAL STATE
# ==================================================

# Pending attack target.
var pending_attack_target = -1

# Pending heal/regeneration target.
var pending_support_target = -1

# Enemy providing delayed coverage reaction.
var pending_coverage_enemies: Array[int] = []

# ==================================================
# CONFIRMATION STATE
# ==================================================

var awaiting_attack_confirmation = false
var awaiting_support_confirmation = false
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

# Player extraction area for
# retreat-style objectives.
var player_start_area: Array[Vector2i] = []

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
		move_tiles
	)
	
	render_system.draw_path_preview(
		self,
		map_data,
		units,
		path_preview_system.get_path_preview_from_path(
			units,
			coverage_system,
			unit_logic,
			selected_unit,
			hover_path_cells
		)
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
	
	draw_inspected_unit_threat_range()

	render_system.draw_pending_move_tile(
		self,
		map_data,
		pending_move_cell,
		has_pending_move()
	)

	draw_active_objective_zones()
	draw_current_objective_text()
	draw_cursor_preview()

	if not action_menu_controller.is_open():
		render_system.draw_facing_choice_tiles(
			self,
			map_data,
			unit_logic,
			units,
			selected_unit,
			move_tiles,
			pending_move_cell,
			has_pending_move(),
			get_valid_lancer_facing_tiles()
		)

	var selected_menu_option = action_menu_controller.get_selected_option()

	var should_show_coverage_preview = (
		not action_menu_controller.is_open()
		or (
			action_menu_controller.get_mode() == "confirm_attack"
			and selected_menu_option == "Wait"
		)
	)

	if should_show_coverage_preview:

		if (
			action_menu_controller.get_mode() == "confirm_attack"
			and selected_menu_option == "Wait"
			and pending_facing_cell != Vector2i(-1, -1)
		):

			render_system.draw_forced_coverage_preview(
				self,
				map_data,
				unit_logic,
				units,
				selected_unit,
				pending_move_cell,
				pending_facing_cell,
				has_pending_move()
			)

		else:

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

	var attack_preview_cell = hovered_cell

	if (
		action_menu_controller.is_open()
		and action_menu_controller.get_mode() == "confirm_attack"
		and action_menu_controller.get_selected_option() == "Attack"
		and pending_facing_cell != Vector2i(-1, -1)
	):
		attack_preview_cell = pending_facing_cell

	render_system.draw_attack_hover_preview(
		self,
		map_data,
		unit_logic,
		unit_query,
		hover_query,
		units,
		selected_unit,
		pending_move_cell,
		attack_preview_cell,
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

	editor_render_system.draw_editor_rect_preview(
		self,
		map_data,
		editor_state,
		hovered_cell
	)

	editor_render_system.draw_editor_select_drag_preview(
		self,
		map_data,
		editor_state,
		hovered_cell
	)

	editor_render_system.draw_editor_selected_area(
		self,
		map_data,
		editor_state
	)

	editor_render_system.draw_editor_move_preview(
		self,
		map_data,
		editor_state,
		hovered_cell
	)

	editor_render_system.draw_all_defender_leashes(
		self,
		map_data,
		editor_state,
		units
	)

	editor_render_system.draw_selected_editor_unit_leash(
		self,
		map_data,
		editor_state,
		units
	)
	
	editor_render_system.draw_editor_unit_move_preview(
		self,
		map_data,
		editor_state,
		units,
		hovered_cell
	)

	editor_render_system.draw_editor_reinforcement_markers(
		self,
		map_data,
		editor_state,
		units
	)

	editor_render_system.draw_editor_objective_zones(
		self,
		map_data,
		editor_state
	)
	
	editor_render_system.draw_editor_ui(
		self,
		editor_state,
		mission_flow_controller,
		units
	)

	editor_render_system.draw_editor_resize_ui(
		self,
		editor_state
	)

# =========================
# Returns zone name used by
# the active objective stage.
# =========================

func get_active_objective_zone_name() -> String:

	var stages = current_objective_data.get("stages", [])

	var stage_index = mission_objectives.get_objective_stage()

	if stage_index < 0 or stage_index >= stages.size():
		return ""

	var stage = stages[stage_index]

	if not stage.has("zone"):
		return ""

	return stage["zone"]

# =========================
# Draws active objective zone
# tiles during battle.
# =========================

func draw_active_objective_zones():

	if editor_state.editor_mode:
		return

	var zone_name = get_active_objective_zone_name()

	if zone_name == "":
		return

	var zone_tiles = editor_state.objective_zones.get(
		zone_name,
		[]
	)

	for cell in zone_tiles:

		if not map_data.is_inside_grid(cell):
			continue

		draw_rect(
			map_data.grid_rect(cell),
			Color(0.0, 0.8, 1.0, 0.18)
		)

		draw_rect(
			map_data.grid_rect(cell),
			Color(0.0, 0.8, 1.0, 0.65),
			false,
			3
		)

# =========================
# Returns display text for
# the current objective stage.
# =========================

func get_current_objective_text() -> String:

	var stages = current_objective_data.get("stages", [])

	var stage_index = mission_objectives.get_objective_stage()

	if stage_index < 0 or stage_index >= stages.size():
		return ""

	var stage = stages[stage_index]

	match stage.get("type", ""):

		"defeat_enemy_count":

			var required_count = stage.get("required_count", 1)
			var current_count = mission_objectives.get_enemies_defeated()

			return (
				"Defeat enemies: "
				+ str(current_count)
				+ "/"
				+ str(required_count)
			)

		"retreat":
			return "Retreat to the marked zone"

		"rout":
			return "Defeat all enemies"

	return ""

# =========================
# Draws current objective
# text during battle.
# =========================

func draw_current_objective_text():

	if editor_state.editor_mode:
		return

	var objective_text = get_current_objective_text()

	if objective_text == "":
		return

	draw_rect(
		Rect2(12, 58, 360, 48),
		Color(0.0, 0.0, 0.0, 0.65)
	)

	draw_string(
		ThemeDB.fallback_font,
		Vector2(24, 88),
		"OBJECTIVE: " + objective_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		16,
		Color.WHITE
	)

# =========================
# Shows objective update
# feedback after stage change.
# =========================

func show_objective_updated_popup():

	var objective_text = get_current_objective_text()

	if objective_text == "":
		return

	await show_phase_popup(
		"Objective Updated: " + objective_text
	)

# =========================
# Adds a tile to the selected
# objective zone.
# =========================

func add_cell_to_selected_objective_zone(cell: Vector2i):

	if not editor_state.objective_zones.has(editor_state.selected_objective_zone):
		editor_state.objective_zones[editor_state.selected_objective_zone] = []

	if editor_state.objective_zones[editor_state.selected_objective_zone].has(cell):
		return

	editor_state.objective_zones[editor_state.selected_objective_zone].append(cell)

	queue_redraw()

# =========================
# Removes a tile from the
# selected objective zone.
# =========================

func remove_cell_from_selected_objective_zone(cell: Vector2i):

	if not editor_state.objective_zones.has(editor_state.selected_objective_zone):
		return

	editor_state.objective_zones[editor_state.selected_objective_zone].erase(cell)

	queue_redraw()

# =========================
# Draws the inspected enemy's
# maximum threat preview.
#
# Yellow = movement range.
# Red = possible attack range
# from any valid movement tile.
# =========================

func draw_inspected_unit_threat_range():

	if inspected_unit_id == -1:
		return

	var inspected_unit = unit_query.get_unit_index_by_id(
		units,
		inspected_unit_id
	)

	if inspected_unit == -1:
		inspected_unit_id = -1
		return

	var inspected = units[inspected_unit]

	var inspected_move_state = selection_system.select_unit(
		units,
		map_data,
		unit_query,
		inspected_unit
	)

	var inspected_move_tiles = inspected_move_state["move_tiles"]

	for tile in inspected_move_tiles:

		if not map_data.is_inside_grid(tile):
			continue

		draw_rect(
			map_data.grid_rect(tile),
			Color(1.0, 1.0, 0.0, 0.25)
		)

	var threatened_tiles: Array[Vector2i] = []

	for move_tile in inspected_move_tiles:

		var attack_tiles = unit_logic.get_attack_choice_tiles(
			move_tile,
			inspected["class"],
			map_data
		)

		for attack_tile in attack_tiles:

			if not map_data.is_inside_grid(attack_tile):
				continue

			if attack_tile in threatened_tiles:
				continue

			threatened_tiles.append(attack_tile)

	for tile in threatened_tiles:

		draw_rect(
			map_data.grid_rect(tile),
			Color(1.0, 0.0, 0.0, 0.25)
		)

# =========================
# Draws cursor hover tile.
#
# White = empty tile
# Blue = allied unit
# Red = enemy unit
# =========================

func draw_cursor_preview():

	if editor_state.editor_mode:
		return

	if hovered_cell == Vector2i(-1, -1):
		return

	if not map_data.is_inside_grid(hovered_cell):
		return

	var border_color = Color.WHITE
	var border_width = 5

	var hovered_unit = unit_query.get_unit_at(
		units,
		hovered_cell
	)

	if hovered_unit != -1:

		if units[hovered_unit]["team"] == "player":
			border_color = Color(0.5, 0.9, 1.0)
			border_width = 10

		else:
			border_color = Color(1.0, 0.55, 0.55)
			border_width = 10

	draw_rect(
		map_data.grid_rect(hovered_cell),
		border_color,
		false,
		border_width
	)

# =========================
# Updates hover unit UI panel.
# =========================

func update_hover_unit_panel():

	var selected_menu_option = action_menu_controller.get_selected_option()

	if (
		editor_state.editor_mode
		or awaiting_support_confirmation
		or awaiting_wait_confirmation
		or (
			action_menu_controller.is_open()
			and (
				action_menu_controller.get_mode() != "confirm_attack"
				or selected_menu_option != "Attack"
			)
		)
	):
		hover_unit_panel_controller.hide_panel()
		return

	var inspected_unit_index = -1

	if inspected_unit_id != -1:
		inspected_unit_index = unit_query.get_unit_index_by_id(
			units,
			inspected_unit_id
		)

	var preview_unit = -1
	var preview_damage = 0

	if awaiting_attack_confirmation:
		preview_unit = pending_attack_target
		preview_damage = get_pending_attack_preview_damage()

	var display_unit = preview_unit

	if display_unit == -1:
		display_unit = unit_query.get_unit_at(
			units,
			hovered_cell
		)

	if display_unit == -1:
		display_unit = inspected_unit_index

	if display_unit == -1:
		display_unit = selected_unit

	if display_unit == -1:
		hover_unit_panel_controller.hide_panel()
		return

	if display_unit < 0 or display_unit >= units.size():
		hover_unit_panel_controller.hide_panel()
		return

	hover_unit_panel_controller.update_panel(
		units[display_unit],
		preview_damage
	)

# =========================
# Shows center-screen phase popup.
# =========================

func show_phase_popup(custom_text: String = ""):

	await phase_popup_controller.show_phase_popup(
		turn_manager.current_team,
		turn_number,
		custom_text
	)

# =========================
# Cancels one action menu layer.
#
# Confirmation menus return to
# post-move look-around mode.
# =========================

func cancel_action_menu_step():

	var mode = action_menu_controller.get_mode()

	if (
		mode == "confirm_attack"
		or mode == "confirm_wait"
		or mode == "confirm_support"
	):

		action_menu_controller.close_menu()

		keyboard_cursor_cell = pending_move_cell
		keyboard_cursor_active = true
		hovered_cell = keyboard_cursor_cell

		awaiting_attack_confirmation = false
		awaiting_support_confirmation = false
		awaiting_wait_confirmation = false

		pending_attack_target = -1
		pending_support_target = -1
		pending_facing_cell = Vector2i(-1, -1)

		queue_redraw()

# =========================
# Applies post-move action
# menu state returned by
# PostMoveActionFlow.
#
# Transfers confirmation
# state data into Main's
# gameplay state, then opens
# the appropriate action menu.
#
# PostMoveActionFlow decides
# WHAT menu should appear.
#
# Main remains responsible
# for owning gameplay state
# and action consequences.
# =========================

func apply_post_move_menu_state(state: Dictionary):

	if state.is_empty():
		return

	if state.has("pending_attack_target"):
		pending_attack_target = state["pending_attack_target"]

	if state.has("pending_support_target"):
		pending_support_target = state["pending_support_target"]

	if state.has("awaiting_attack_confirmation"):
		awaiting_attack_confirmation = state["awaiting_attack_confirmation"]

	if state.has("awaiting_support_confirmation"):
		awaiting_support_confirmation = state["awaiting_support_confirmation"]

	if state.has("awaiting_wait_confirmation"):
		awaiting_wait_confirmation = state["awaiting_wait_confirmation"]

	if state.has("pending_facing_cell"):
		pending_facing_cell = state["pending_facing_cell"]

	action_menu_controller.sync_context(
		units,
		selected_unit,
		pending_move_cell
	)

	action_menu_controller.open_menu(
		state["mode"],
		state["options"]
	)

	queue_redraw()

# =========================
# Receives confirmed action
# menu selections from the
# ActionMenuController.
#
# Main remains responsible
# for gameplay consequences,
# while the controller only
# manages UI/menu behavior.
# =========================

func _on_action_menu_option_confirmed(option: String):

	match option:

		"Attack":
			action_menu_controller.close_menu()
			confirm_attack()

		"Wait":
			action_menu_controller.close_menu()

			if pending_facing_cell != Vector2i(-1, -1):
				handle_facing_click(pending_facing_cell)
			else:
				confirm_wait()

		"Heal":
			action_menu_controller.close_menu()
			handle_heal_hotkey()

		"Regen":
			action_menu_controller.close_menu()
			handle_regen_hotkey()

		"Cancel":
			_on_action_menu_cancelled()

# =========================
# Receives action menu
# cancellation requests from
# the ActionMenuController.
#
# Returns the player to the
# previous tactical state
# without fully clearing the
# current unit's movement.
# =========================

func _on_action_menu_cancelled():

	cancel_action_menu_step()

# =========================
# Handles keyboard facing selection.
# =========================

func handle_facing_selection_input(event):

	var facing_offset = Vector2i.ZERO

	match event.keycode:

		KEY_UP, KEY_W:
			facing_offset = Vector2i.UP

		KEY_DOWN, KEY_S:
			facing_offset = Vector2i.DOWN

		KEY_LEFT, KEY_A:
			facing_offset = Vector2i.LEFT

		KEY_RIGHT, KEY_D:
			facing_offset = Vector2i.RIGHT

		KEY_X, KEY_ESCAPE:
			cancel_action_menu_step()
			return

	if facing_offset == Vector2i.ZERO:
		return

	var facing_cell = (
		pending_move_cell
		+ facing_offset
	)

	handle_facing_click(facing_cell)

# ==================================================
# ENGINE CALLBACKS
# ==================================================

# =========================
# Starts a fresh battle state.
# =========================

func start_battle_flow():
	input_locked = false

	turn_number = 1
	turn_manager.current_team = "player"

	for unit in units:
		unit["has_acted"] = false

	remove_hidden_reinforcements_from_active_battle()
	clear_selection()
	initialize_keyboard_cursor()
	queue_redraw()

	await show_phase_popup("Battle Commence")
	await show_phase_popup()

# =========================
# Loads the currently
# selected campaign mission.
#
# Retrieves mission metadata
# from MissionFlowController,
# loads the associated map,
# then begins battle flow.
#
# Future expansion:
# - VN intro scenes
# - deployment phase
# - mission objectives
# - music setup
# - cutscene transitions
# =========================

func load_current_campaign_mission():

	mission_flow_controller.set_mission_state("battle")

	current_objective_data = map_serializer.load_map(
		map_data,
		units,
		unit_data,
		mission_flow_controller.get_campaign_level_path()
	)

	if current_objective_data.has("objective_zones"):

		deserialize_objective_zones(
			current_objective_data["objective_zones"]
		)

	setup_current_mission_objective()
	await start_battle_flow()

# =========================
# Stores player starting
# positions as retreat
# extraction tiles.
# =========================

func cache_player_start_area():

	player_start_area.clear()

	for unit in units:

		if unit["team"] != "player":
			continue

		player_start_area.append(unit["pos"])

# =========================
# Returns true if current
# objective data references
# player start area.
# =========================

func objective_uses_player_start_area() -> bool:

	if current_objective_data.get("type", "") == "retreat":
		return true

	if current_objective_data.get("type", "") != "layered":
		return false

	var stages = current_objective_data.get("stages", [])

	for stage in stages:

		if stage.get("zone", "") == "player_start_area":
			return true

	return false

# =========================
# Sets up objective state
# for the current mission.
# =========================

func setup_current_mission_objective():

	if current_objective_data.is_empty():
		current_objective_data = {
			"type": mission_flow_controller.get_current_objective_type()
		}

	mission_objectives.setup_objective(
		current_objective_data,
		editor_state.objective_zones
	)

	if objective_uses_player_start_area():
		cache_player_start_area()

# =========================
# Updates current objective
# data from editor settings.
# =========================

func update_current_objective_from_editor():

	current_objective_data = {
		"type": "layered",
		"stages": editor_state.editor_objective_stages,
		"objective_zones": serialize_objective_zones()
	}

# =========================
# Converts objective zones
# into JSON-safe data.
# =========================

func serialize_objective_zones() -> Dictionary:

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
# Loads serialized objective
# zone data into runtime
# Vector2i arrays.
# =========================

func deserialize_objective_zones(data: Dictionary):

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

# =========================
# Resolves objective stage
# completion events.
#
# Handles:
# - reinforcement spawns
# - victory flow
# - stage advancement
# =========================

func resolve_objective_event(event_name: String):

	match event_name:

		"advance_stage":
			await show_objective_updated_popup()

		"spawn_reinforcements":
			pending_reinforcement_spawn = true
			pending_reinforcement_stage = mission_objectives.get_objective_stage()

			await resolve_pending_reinforcements()

			await show_objective_updated_popup()

		"victory":
			await handle_mission_victory()

		"defeat":
			await handle_mission_defeat()

# =========================
# Spawns queued mission
# reinforcements.
# =========================

func spawn_reinforcements():

	for reinforcement in staged_reinforcements:

		if not reinforcement.has("reinforcement_stage"):
			continue

		if reinforcement["reinforcement_stage"] != pending_reinforcement_stage:
			continue

		reinforcement.erase("starts_hidden")

		var new_unit_index = units.size()

		units.append(reinforcement)

		await animate_reinforcement_entry(
			new_unit_index,
			-reinforcement["facing"]
		)

	pending_reinforcement_stage = -1

	queue_redraw()

# =========================
# Removes staged reinforcement
# units from active battle
# until their trigger occurs.
# =========================

func remove_hidden_reinforcements_from_active_battle():

	staged_reinforcements.clear()

	for i in range(units.size() - 1, -1, -1):

		if not units[i].has("starts_hidden"):
			continue

		if not units[i]["starts_hidden"]:
			continue

		staged_reinforcements.append(
			units[i].duplicate(true)
		)

		units.remove_at(i)

# =========================
# Spawns queued reinforcements
# after enemy phase ends.
# =========================

func resolve_pending_reinforcements():

	if not pending_reinforcement_spawn:
		return

	pending_reinforcement_spawn = false

	await spawn_reinforcements()

# =========================
# Handles mission victory flow.
# =========================

func handle_mission_victory():

	input_locked = true

	mission_flow_controller.set_mission_state(
		"victory"
	)

	await show_phase_popup("Victory")

	await get_tree().create_timer(0.8).timeout

	if not mission_flow_controller.is_final_mission():

		mission_flow_controller.advance_to_next_mission()

		await load_current_campaign_mission()

	else:

		print("Campaign Complete")

# =========================
# Handles mission defeat flow.
# =========================

func handle_mission_defeat():

	input_locked = true

	mission_flow_controller.set_mission_state(
		"defeat"
	)

	await show_phase_popup("Defeat")

	await get_tree().create_timer(0.8).timeout

	await load_current_campaign_mission()

# =========================
# Initial setup.
# =========================

# =========================
# Initializes controllers,
# connects UI signals,
# loads startup battle data,
# and prepares initial
# game state.
# =========================

func _ready():

	# =========================
	# Action menu setup
	# =========================

	action_menu_controller.setup(
		action_menu,
		action_panel,
		action_vbox,
		[
			move_option_label,
			attack_option_label,
			heal_option_label,
			wait_option_label
		],
		map_data
	)

	action_menu_controller.option_confirmed.connect(
		_on_action_menu_option_confirmed
	)

	action_menu_controller.menu_cancelled.connect(
		_on_action_menu_cancelled
	)

	# =========================
	# Hover UI setup
	# =========================

	hover_unit_panel_controller.setup(
		hover_unit_panel,
		hover_unit_name_label,
		hover_hp_value_label,
		hover_hp_back_bar,
		hover_hp_bar,
		hover_hp_preview_bar,
		hover_stamina_value_label,
		hover_stamina_bar,
		hover_hp_text_label,
		hover_stamina_text_label
	)

	# =========================
	# Tactical input signals
	# =========================

	tactical_input_controller.cursor_moved.connect(move_keyboard_cursor)
	tactical_input_controller.keyboard_confirm_requested.connect(handle_keyboard_confirm)
	tactical_input_controller.keyboard_cancel_requested.connect(cancel_pending_action)
	tactical_input_controller.end_turn_requested.connect(end_current_turn)
	tactical_input_controller.coverage_cycle_requested.connect(cycle_coverage_mode)
	tactical_input_controller.tab_cycle_requested.connect(jump_to_next_unmoved_ally)

	# =========================
	# Initial map loading
	# =========================

	if FileAccess.file_exists(editor_system.get_editor_map_path(editor_state)):

		map_serializer.load_map(
			map_data,
			units,
			unit_data,
			editor_system.get_editor_map_path(editor_state)
		)

	else:

		map_data.normalize_terrain_rows()

		units = battle_setup.create_battle_units(
			unit_data
		)

	# =========================
	# Initial battle state
	# =========================

	initialize_keyboard_cursor()

	queue_redraw()

# =========================
# Per-frame updates.
# =========================

func _process(_delta):

	if input_locked:
		action_menu_controller.sync_context(
			units,
			selected_unit,
			pending_move_cell
		)

		action_menu_controller.update_menu()
		queue_redraw()
		return

	var mouse_pos = get_viewport().get_mouse_position()

	var mouse_hover_cell = map_data.world_to_grid(mouse_pos)

	if last_mouse_hover_cell == Vector2i(-1, -1):
		last_mouse_hover_cell = mouse_hover_cell

	if mouse_hover_cell != last_mouse_hover_cell:
		keyboard_cursor_active = false
		last_mouse_hover_cell = mouse_hover_cell

	var suppress_map_hover = (
		action_menu_controller.is_open()
		and (
			action_menu_controller.get_mode() == "destination"
			or action_menu_controller.get_mode() == "confirm_attack"
			or action_menu_controller.get_mode() == "confirm_wait"
			or action_menu_controller.get_mode() == "confirm_support"
		)
	)

	if suppress_map_hover:
		hovered_cell = Vector2i(-1, -1)
	else:
		if keyboard_cursor_active:
			hovered_cell = keyboard_cursor_cell
		else:
			hovered_cell = map_data.world_to_grid(mouse_pos)

	update_hover_unit_panel()

	action_menu_controller.sync_context(
		units,
		selected_unit,
		pending_move_cell
	)

	action_menu_controller.update_menu()

	if action_menu_controller.is_open():
		action_menu_controller.update_hovered_index_from_mouse()

	if editor_state.editor_mode:
		editor_input_controller.handle_mouse_drag_paint(
			editor_state,
			editor_system,
			map_data,
			hovered_cell
		)

	if (
		not editor_state.editor_mode
		and not suppress_map_hover
	):
		hover_path_cells = path_preview_system.update_hover_path(
			hover_path_cells,
			map_data,
			units,
			unit_query,
			coverage_system,
			unit_logic,
			selected_unit,
			selected_unit_start_cell,
			hovered_cell,
			move_tiles
		)

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
# Handles keyboard shortcuts,
# confirmations, and editor hotkeys.
# =========================

func handle_keyboard_input(event):

	if input_locked:
		return

	if not event is InputEventKey:
		return

	if not event.pressed:
		return

	if awaiting_facing_selection:
		handle_facing_selection_input(event)
		return

	if action_menu_controller.is_open():
		action_menu_controller.handle_input(event)
		return

	if editor_state.editor_resize_mode:

		if editor_input_controller.handle_editor_resize_input(
			event,
			editor_state,
			map_data
		):
			queue_redraw()

		return

	if editor_state.editor_mode:
		if editor_input_controller.handle_keyboard_input(
			event,
			editor_state,
			editor_system,
			mission_flow_controller,
			map_data,
			units,
			unit_data,
			map_serializer,
			current_objective_data,
			editor_objective_serializer
		):
			queue_redraw()
			return

	if not editor_state.editor_mode:
		if tactical_input_controller.handle_keyboard_event(event):
			return

	match event.keycode:

		KEY_E:
			editor_state.editor_mode = !editor_state.editor_mode
			clear_pending_action_state()
			if not editor_state.editor_mode:
				setup_current_mission_objective()
				await start_battle_flow()
			queue_redraw()

		KEY_F9:
			if editor_state.editor_mode:
				save_campaign_level()

		KEY_F10:
			if editor_state.editor_mode:
				load_campaign_level()

		KEY_F11:
			if editor_state.editor_mode:
				load_current_campaign_mission()

		KEY_TAB:
			if not editor_state.editor_mode:
				jump_to_next_unmoved_ally()

		KEY_C:
			cycle_coverage_mode()

		KEY_T:
			end_current_turn()

		KEY_X:
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

func end_current_turn():

	stamina_system.recover_idle_healers(
		units,
		turn_manager.current_team
	)

	turn_manager.end_turn(units)

	clear_selection()
	inspected_unit_id = -1

	queue_redraw()

	await start_ai_turn_if_needed()

# =========================
# Confirms wait action.
# =========================

func handle_wait_hotkey():

	if awaiting_wait_confirmation:
		confirm_wait()

# =========================
# Confirms attack action.
# =========================

# =========================
# Returns predicted attack damage
# for the currently pending attack.
#
# Simulates post-movement stamina
# before calculating damage so
# previews match real combat results.
#
# Used by attack confirmation UI.
# =========================

func handle_attack_confirm_hotkey():

	if awaiting_attack_confirmation:
		confirm_attack()

func get_pending_attack_preview_damage() -> int:

	if not awaiting_attack_confirmation:
		return 0

	if selected_unit == -1:
		return 0

	if pending_attack_target == -1:
		return 0

	if selected_unit >= units.size():
		return 0

	if pending_attack_target >= units.size():
		return 0

	var simulated_attacker = units[selected_unit].duplicate()

	var movement_cost = (
		pending_move_distance
		* simulated_attacker["move_stamina_cost"]
	)

	simulated_attacker["stamina"] = max(
		simulated_attacker["stamina"] - movement_cost,
		0
	)

	return combat_logic.get_attack_damage(simulated_attacker)

# =========================
# Confirms direct heal action.
# =========================

func handle_heal_hotkey():

	if awaiting_support_confirmation:
		confirm_support_action("heal")

# =========================
# Confirms regeneration spell.
# =========================

func handle_regen_hotkey():

	if awaiting_support_confirmation:
		confirm_support_action("regen")

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

	if input_locked:
		return

	if not event is InputEventMouseButton:
		return

	if action_menu_controller.is_open():

		if action_menu_controller.handle_mouse_click(event):
			return

	if editor_state.editor_mode:

		if editor_input_controller.handle_mouse_input(
			event,
			editor_state,
			editor_system,
			map_data,
			units,
			unit_query,
			unit_data,
			hovered_cell
		):
			queue_redraw()
			return

	# =========================
	# Right click behavior
	# =========================

	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:

		if inspected_unit_id != -1:
			inspected_unit_id = -1
			queue_redraw()
			return

		clear_pending_action_state()

		queue_redraw()
		return

	# =========================
	# Left click behavior
	# =========================

	if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		handle_left_click()

# =========================
# Main left-click handler.
# =========================

func handle_left_click():

	var clicked_cell = hovered_cell

	if not map_data.is_inside_grid(clicked_cell):
		return

	if selected_unit != -1 and has_pending_move():

		var menu_state = post_move_action_flow.get_post_move_menu_state(
			units,
			selected_unit,
			clicked_cell,
			pending_move_cell,
			action_query,
			action_system,
			unit_logic,
			unit_query,
			hover_query,
			map_data
		)

		if not menu_state.is_empty():
			apply_post_move_menu_state(menu_state)

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
# Converts valid lancer target tiles
# into legal facing-selection tiles.
# =========================

func get_valid_lancer_facing_tiles() -> Array[Vector2i]:

	return movement_system.get_valid_lancer_facing_tiles(
		unit_logic,
		action_query,
		map_data,
		pending_move_cell
	)

# =========================
# Places keyboard cursor on
# the first available player unit.
# =========================

func initialize_keyboard_cursor():

	for unit in units:

		if unit["team"] == "player":
			keyboard_cursor_cell = unit["pos"]
			keyboard_cursor_active = true
			return

	keyboard_cursor_cell = Vector2i(0, 0)
	keyboard_cursor_active = true

# =========================
# Clears selection and pending movement state.
# =========================

func clear_selection():

	awaiting_facing_selection = false

	var state = selection_system.clear_selection()

	selected_unit = state["selected_unit"]
	selected_unit_start_cell = state["selected_unit_start_cell"]
	move_tiles = state["move_tiles"]

	pending_move_cell = state["pending_move_cell"]
	pending_move_distance = state["pending_move_distance"]
	pending_coverage_enemies = state["pending_coverage_enemies"]
	pending_facing_cell = Vector2i(-1, -1)

	action_menu_controller.close_menu()

	hover_path_cells.clear()

# =========================
# Cycles to next allied unit
# that has not acted.
# =========================

func jump_to_next_unmoved_ally():

	var valid_units: Array[int] = []

	for i in range(units.size()):

		if units[i]["team"] != "player":
			continue

		if units[i]["has_acted"]:
			continue

		valid_units.append(i)

	if valid_units.is_empty():
		return

	var current_index := -1

	for i in range(valid_units.size()):

		var unit_index = valid_units[i]

		if units[unit_index]["pos"] == hovered_cell:
			current_index = i
			break

	var next_index := 0

	if current_index != -1:
		next_index = (current_index + 1) % valid_units.size()

	var next_unit = valid_units[next_index]

	keyboard_cursor_cell = units[next_unit]["pos"]
	keyboard_cursor_active = true
	hovered_cell = keyboard_cursor_cell

	queue_redraw()

# =========================
# Clears pending action confirmation state.
#
# If a unit had visually moved, it is restored
# to its original starting cell.
# =========================

func clear_pending_action_state():

	var cursor_return_cell = selected_unit_start_cell

	awaiting_facing_selection = false

	if selected_unit != -1 and has_pending_move():
		units[selected_unit]["pos"] = selected_unit_start_cell

	var state = selection_system.clear_pending_action_state()

	selected_unit = state["selected_unit"]
	selected_unit_start_cell = state["selected_unit_start_cell"]
	move_tiles = state["move_tiles"]

	pending_move_cell = state["pending_move_cell"]
	pending_move_distance = state["pending_move_distance"]
	pending_coverage_enemies = state["pending_coverage_enemies"]

	awaiting_attack_confirmation = state["awaiting_attack_confirmation"]
	awaiting_support_confirmation = state["awaiting_support_confirmation"]
	awaiting_wait_confirmation = state["awaiting_wait_confirmation"]

	pending_attack_target = state["pending_attack_target"]
	pending_support_target = state["pending_support_target"]
	pending_facing_cell = Vector2i(-1, -1)

	action_menu_controller.close_menu()

	if keyboard_cursor_active and cursor_return_cell != Vector2i(-1, -1):
		keyboard_cursor_cell = cursor_return_cell
		hovered_cell = keyboard_cursor_cell

	hover_path_cells.clear()

# =========================
# Moves keyboard cursor by
# one grid cell.
#
# If switching from mouse mode,
# the current hovered cell becomes
# the keyboard cursor starting point.
# =========================

func move_keyboard_cursor(direction: Vector2i):

	if not keyboard_cursor_active:

		if (
			hovered_cell != Vector2i(-1, -1)
			and map_data.is_inside_grid(hovered_cell)
		):
			keyboard_cursor_cell = hovered_cell
		else:
			initialize_keyboard_cursor()

	keyboard_cursor_active = true

	var next_cell = keyboard_cursor_cell + direction

	if not map_data.is_inside_grid(next_cell):
		return

	keyboard_cursor_cell = next_cell
	hovered_cell = keyboard_cursor_cell

	queue_redraw()

# =========================
# Confirms keyboard cursor tile.
#
# Behaves like left-clicking the
# currently hovered grid cell.
# =========================

func handle_keyboard_confirm():

	if not keyboard_cursor_active:
		return

	hovered_cell = keyboard_cursor_cell

	handle_left_click()

# ==================================================
# SELECTION / MOVEMENT FLOW
# ==================================================

func has_pending_move() -> bool:

	return selection_state.has_pending_move(
		pending_move_cell
	)

# =========================
# Handles clicking a unit or empty tile
# during normal selection mode.
# =========================

func handle_unit_click(clicked_cell: Vector2i):

	var clicked_unit = unit_query.get_unit_at(units, clicked_cell)

	if clicked_unit != -1 and units[clicked_unit]["team"] != turn_manager.current_team:

		if inspected_unit_id == units[clicked_unit]["id"]:
			inspected_unit_id = -1
			queue_redraw()
			return

		clear_selection()
		inspected_unit_id = units[clicked_unit]["id"]
		queue_redraw()
		return

	inspected_unit_id = -1

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
	
	inspected_unit_id = -1

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
	pending_move_distance = state["pending_move_distance"]
	pending_coverage_enemies = state["pending_coverage_enemies"]

	pending_attack_target = state["pending_attack_target"]
	pending_support_target = state["pending_support_target"]

	awaiting_attack_confirmation = state["awaiting_attack_confirmation"]
	awaiting_support_confirmation = state["awaiting_support_confirmation"]
	awaiting_wait_confirmation = state["awaiting_wait_confirmation"]

	queue_redraw()

# =========================
# Handles clicking a valid
# movement destination.
#
# The unit visually moves immediately,
# then enters post-move look-around mode.
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
		move_tiles,
		hover_path_cells
	)

	if result.is_empty():
		return

	pending_move_cell = result["pending_move_cell"]
	pending_move_distance = result["pending_move_distance"]
	pending_coverage_enemies = result["pending_coverage_enemies"]

	move_tiles.clear()
	hover_path_cells.clear()

	action_menu_controller.close_menu()

	keyboard_cursor_cell = pending_move_cell
	keyboard_cursor_active = true
	hovered_cell = keyboard_cursor_cell

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
		pending_coverage_enemies,
		get_valid_lancer_facing_tiles()
	)

	if result.is_empty():
		return

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
	await start_ai_turn_if_needed()

# =========================
# Checks whether current
# mission has ended.
#
# MissionObjectives determines
# the mission result.
#
# Main applies the resulting
# campaign flow.
# =========================

func check_mission_end_conditions():

	if mission_flow_controller.get_mission_state() != "battle":
		return

	var mission_result = mission_objectives.get_mission_result(units)

	if mission_result == "":
		return

	await resolve_objective_event(mission_result)

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
		if units[result["defender_remove_index"]]["team"] == "enemy":
			mission_objectives.record_enemy_defeated()
		units.remove_at(result["defender_remove_index"])

	clear_selection()

	turn_number = action_system.auto_end_turn_if_needed(
		units,
		turn_manager,
		stamina_system,
		turn_number
	)

	queue_redraw()
	await check_mission_end_conditions()
	await start_ai_turn_if_needed()

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
	await check_mission_end_conditions()
	await start_ai_turn_if_needed()

# =========================
# Confirms selected support action.
# =========================

func confirm_support_action(
	support_action: String
):

	var result = action_system.confirm_support_action(
		units,
		combat_logic,
		coverage_system,
		stamina_system,
		selected_unit,
		pending_support_target,
		pending_move_distance,
		pending_coverage_enemies,
		support_action
	)

	if result.is_empty():
		return

	awaiting_support_confirmation = result["awaiting_support_confirmation"]
	pending_support_target = result["pending_support_target"]

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
	await check_mission_end_conditions()
	await start_ai_turn_if_needed()

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

# =========================
# Starts AI phase after showing
# the enemy phase popup.
# =========================

func start_ai_turn_if_needed():

	if turn_manager.current_team == "player":
		return

	input_locked = true

	clear_selection()
	inspected_unit_id = -1

	queue_redraw()

	await show_phase_popup()

	await process_ai_turn_if_needed()

	input_locked = false

# =========================
# Processes the current team's AI turn
# if the active team is not player-controlled.
#
# Enemy actions are processed with
# short pauses between units so the
# player can visually follow the
# enemy phase.
# =========================

func process_ai_turn_if_needed():

	if turn_manager.current_team == "player":
		return

	var unit_ids: Array[int] = []

	for unit in units:
		if unit["team"] == turn_manager.current_team and not unit["has_acted"]:
			unit_ids.append(unit["id"])

	for unit_id in unit_ids:

		var unit_index = unit_query.get_unit_index_by_id(
			units,
			unit_id
		)

		if unit_index == -1:
			continue

		if units[unit_index]["has_acted"]:
			continue

		var action_result = ai_system.take_unit_turn(
			units,
			unit_index,
			map_data,
			unit_logic,
			movement_system,
			action_system,
			combat_logic,
			coverage_system,
			stamina_system
		)

		if action_result.has("path_cells"):
			await animate_unit_path(
				unit_index,
				action_result["path_cells"]
			)

		if action_result.has("attacked") and action_result["attacked"]:

			await animate_attack_lunge(
				action_result["attacker_index"],
				action_result["target_index"]
			)

			var target_index = action_result["target_index"]

			if target_index != -1 and target_index < units.size():

				if action_result.has("damage"):
					units[target_index]["hp"] -= action_result["damage"]

				queue_redraw()
				await get_tree().create_timer(0.15).timeout

				if action_result.has("target_died") and action_result["target_died"]:
					units.remove_at(target_index)

		queue_redraw()

		await get_tree().create_timer(0.15).timeout

	stamina_system.recover_idle_healers(
		units,
		turn_manager.current_team
	)

	turn_manager.end_turn(units)

	if turn_manager.current_team == "player":

		await resolve_pending_reinforcements()

		turn_number += 1

	clear_selection()
	inspected_unit_id = -1

	queue_redraw()

	await check_mission_end_conditions()

	await show_phase_popup()

# =========================
# Visually animates a unit
# along a movement path using
# tile-by-tile interpolation.
#
# Logical movement is already
# resolved before animation.
#
# This function only handles
# visual presentation and
# enemy phase readability.
# =========================

func animate_unit_path(
	unit_index: int,
	path_cells: Array
):

	if unit_index == -1:
		return

	if unit_index >= units.size():
		return

	if path_cells.size() <= 1:
		return

	var original_facing = units[unit_index]["facing"]
	units[unit_index]["facing"] = Vector2i.ZERO

	for i in range(1, path_cells.size()):

		if unit_index >= units.size():
			return

		var from_cell = path_cells[i - 1]
		var to_cell = path_cells[i]

		var from_pos = map_data.grid_rect(from_cell).position
		var to_pos = map_data.grid_rect(to_cell).position

		units[unit_index]["draw_offset"] = from_pos - to_pos
		units[unit_index]["pos"] = to_cell

		queue_redraw()
		await get_tree().create_timer(0.08).timeout

		units[unit_index]["draw_offset"] = Vector2.ZERO

		queue_redraw()
		await get_tree().create_timer(0.02).timeout

	units[unit_index]["facing"] = original_facing
	queue_redraw()

# =========================
# Animates a newly spawned
# reinforcement walking into
# its target tile.
#
# The unit already exists at
# its final logical position.
# draw_offset creates the
# visual entrance motion.
# =========================

func animate_reinforcement_entry(
	unit_index: int,
	entry_direction: Vector2i
):

	if unit_index == -1:
		return

	if unit_index >= units.size():
		return

	var final_facing = units[unit_index]["facing"]

	units[unit_index]["facing"] = Vector2i.ZERO

	var start_offset = Vector2(
		entry_direction.x,
		entry_direction.y
	) * map_data.TILE_SIZE * 1.5

	units[unit_index]["draw_offset"] = start_offset

	var steps = 8

	for step in range(steps):

		var t = float(step + 1) / float(steps)

		units[unit_index]["draw_offset"] = start_offset.lerp(
			Vector2.ZERO,
			t
		)

		queue_redraw()
		await get_tree().create_timer(0.04).timeout

	units[unit_index]["draw_offset"] = Vector2.ZERO
	units[unit_index]["facing"] = final_facing

	queue_redraw()

# =========================
# Plays a brief attack lunge
# animation toward the target.
#
# Used during enemy phase to
# improve combat readability
# without large attack effects.
#
# This is purely visual and
# does not affect gameplay logic.
# =========================

func animate_attack_lunge(
	attacker_index: int,
	target_index: int
):

	if attacker_index == -1 or target_index == -1:
		return

	if attacker_index >= units.size() or target_index >= units.size():
		return

	var direction = units[target_index]["pos"] - units[attacker_index]["pos"]

	var offset = Vector2(
		sign(direction.x),
		sign(direction.y)
	) * 10.0

	units[attacker_index]["draw_offset"] = offset

	queue_redraw()
	await get_tree().create_timer(0.1).timeout

	units[attacker_index]["draw_offset"] = Vector2.ZERO

	queue_redraw()
	await get_tree().create_timer(0.1).timeout

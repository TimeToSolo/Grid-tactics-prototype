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
@onready var editor_system = $EditorSystem
@onready var hover_query = $HoverQuery
@onready var map_data = $MapData
@onready var map_serializer = $MapSerializer
@onready var movement_system = $MovementSystem
@onready var path_preview_system = $PathPreviewSystem
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

# Current cursor-traced movement preview path.
var hover_path_cells: Array[Vector2i] = []

# Currently inspected non-active unit ID.
var inspected_unit_id := -1

# ==================================================
# LEVEL EDITOR STATE
# ==================================================

# True while level editor mode is active.
var editor_mode := false

# Currently selected terrain tile symbol
# used for painting terrain.
var selected_editor_tile := "."

# True while dragging a rectangle fill area.
var editor_rect_dragging := false

# Starting cell for Ctrl + left-click rectangle fill.
var editor_rect_start_cell: Vector2i = Vector2i(-1, -1)

# Current editor placement mode.
# "terrain", "player_unit", or "enemy_unit".
var editor_palette := "terrain"

# Currently selected unit class for editor placement.
var selected_editor_unit_class := "fighter"

# Starting facing direction for newly placed editor units.
var selected_editor_facing: Vector2i = Vector2i(0, -1)

# True while the editor resize prompt is active.
var editor_resize_mode := false

# Preview width before confirming resize.
var editor_resize_width := 20

# Preview height before confirming resize.
var editor_resize_height := 16

# True while dragging a selection rectangle.
var editor_select_dragging := false

# Start cell for editor selection rectangle.
var editor_select_start_cell: Vector2i = Vector2i(-1, -1)

# Selected rectangle start.
var editor_selected_rect_start: Vector2i = Vector2i(-1, -1)

# Selected rectangle end.
var editor_selected_rect_end: Vector2i = Vector2i(-1, -1)

# True while dragging a selected editor area.
var editor_move_dragging := false

# Cell where selected-area move drag began.
var editor_move_start_cell: Vector2i = Vector2i(-1, -1)

# Current save/load map slot.
var editor_map_slot := 1

# Total available quick-save slots.
const MAX_EDITOR_MAP_SLOTS = 9

# =========================
# Returns current editor map path.
# =========================

func get_editor_map_path() -> String:

	return "user://maps/map_" + str(editor_map_slot) + ".json"


# =========================
# Changes active editor map slot.
# =========================

func change_editor_map_slot(direction: int):

	editor_map_slot += direction

	if editor_map_slot < 1:
		editor_map_slot = MAX_EDITOR_MAP_SLOTS

	if editor_map_slot > MAX_EDITOR_MAP_SLOTS:
		editor_map_slot = 1

	queue_redraw()

# =========================
# Returns true if a cell is
# inside the current selected
# editor rectangle area.
#
# Used for selection movement
# and drag detection.
# =========================

func editor_cell_is_inside_selected_area(cell: Vector2i) -> bool:

	if editor_selected_rect_start == Vector2i(-1, -1):
		return false

	if editor_selected_rect_end == Vector2i(-1, -1):
		return false

	return (
		cell.x >= editor_selected_rect_start.x
		and cell.x <= editor_selected_rect_end.x
		and cell.y >= editor_selected_rect_start.y
		and cell.y <= editor_selected_rect_end.y
	)

# =========================
# Saves editor map.
# =========================

func save_editor_map():

	map_serializer.save_map(
		map_data,
		units,
		get_editor_map_path()
	)
	
# =========================
# Loads editor map.
# =========================

func load_editor_map():

	map_serializer.load_map(
		map_data,
		units,
		unit_data,
		get_editor_map_path()
	)

	queue_redraw()

# =========================
# Handles map resize prompt input.
# =========================

func handle_editor_resize_input(event):

	match event.keycode:

		KEY_RIGHT:
			editor_resize_width += 1

		KEY_LEFT:
			editor_resize_width = max(1, editor_resize_width - 1)

		KEY_DOWN:
			editor_resize_height += 1

		KEY_UP:
			editor_resize_height = max(1, editor_resize_height - 1)

		KEY_ENTER:
			map_data.resize_map(
				editor_resize_width,
				editor_resize_height
			)

			editor_resize_mode = false

		KEY_ESCAPE:
			editor_resize_mode = false

	queue_redraw()
	
# =========================
# Draws map resize prompt.
# =========================

func draw_editor_resize_ui():

	if not editor_resize_mode:
		return

	draw_rect(
		Rect2(12, 120, 360, 130),
		Color(0.0, 0.0, 0.0, 0.75)
	)

	draw_string(
		ThemeDB.fallback_font,
		Vector2(24, 150),
		"MAP SIZE",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		18,
		Color.WHITE
	)

	draw_string(
		ThemeDB.fallback_font,
		Vector2(24, 180),
		"Width: " + str(editor_resize_width) + "   Left/Right",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		16,
		Color.WHITE
	)

	draw_string(
		ThemeDB.fallback_font,
		Vector2(24, 205),
		"Height: " + str(editor_resize_height) + "   Up/Down",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		16,
		Color.WHITE
	)

	draw_string(
		ThemeDB.fallback_font,
		Vector2(24, 235),
		"Enter: confirm   Esc: cancel",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		16,
		Color.YELLOW
	)

# =========================
# Starts map resize mode.
# =========================

func start_editor_resize_mode():

	if not editor_mode:
		return

	editor_resize_mode = true
	editor_resize_width = map_data.grid_width
	editor_resize_height = map_data.grid_height

	queue_redraw()

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

# =========================
# Draws destination preview
# while moving selected area.
# =========================

func draw_editor_move_preview():

	if not editor_mode:
		return

	if editor_palette != "select":
		return

	if not editor_move_dragging:
		return

	var offset = hovered_cell - editor_move_start_cell

	var preview_start = editor_selected_rect_start + offset
	var preview_end = editor_selected_rect_end + offset

	for y in range(preview_start.y, preview_end.y + 1):
		for x in range(preview_start.x, preview_end.x + 1):

			var cell = Vector2i(x, y)

			if not map_data.is_inside_grid(cell):
				continue

			draw_rect(
				map_data.grid_rect(cell),
				Color(0.0, 1.0, 1.0, 0.35)
			)

# =========================
# Draws selected editor area.
# =========================

func draw_editor_selected_area():

	if not editor_mode:
		return

	if editor_palette != "select":
		return

	if editor_selected_rect_start == Vector2i(-1, -1):
		return

	if editor_selected_rect_end == Vector2i(-1, -1):
		return

	var min_x = min(editor_selected_rect_start.x, editor_selected_rect_end.x)
	var max_x = max(editor_selected_rect_start.x, editor_selected_rect_end.x)

	var min_y = min(editor_selected_rect_start.y, editor_selected_rect_end.y)
	var max_y = max(editor_selected_rect_start.y, editor_selected_rect_end.y)

	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):

			var cell = Vector2i(x, y)

			if not map_data.is_inside_grid(cell):
				continue

			draw_rect(
				map_data.grid_rect(cell),
				Color(1.0, 1.0, 0.0, 0.25)
			)
			

# =========================
# Draws live select rectangle
# while Ctrl-dragging.
# =========================

func draw_editor_select_drag_preview():

	if not editor_mode:
		return

	if editor_palette != "select":
		return

	if not editor_select_dragging:
		return

	var min_x = min(editor_select_start_cell.x, hovered_cell.x)
	var max_x = max(editor_select_start_cell.x, hovered_cell.x)

	var min_y = min(editor_select_start_cell.y, hovered_cell.y)
	var max_y = max(editor_select_start_cell.y, hovered_cell.y)

	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):

			var cell = Vector2i(x, y)

			if not map_data.is_inside_grid(cell):
				continue

			draw_rect(
				map_data.grid_rect(cell),
				Color(1.0, 1.0, 0.0, 0.35)
			)

# =========================
# Draws editor mode controls
# and highlights selected option.
# =========================

func draw_editor_ui():

	if not editor_mode:
		return

	var x = 12
	var y = 32
	var font_size = 16
	var spacing = 95

	var top_y = y
	var palette_y = y + 24
	var option_y = y + 48
	var action_y = y + 72
	var facing_y = y + 96

	draw_string(
		ThemeDB.fallback_font,
		Vector2(x, top_y),
		"EDITOR MODE",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color.WHITE
	)

	draw_string(
		ThemeDB.fallback_font,
		Vector2(x + 170, top_y),
		"Slot " + str(editor_map_slot) + " | Ctrl+S Save | Ctrl+L Load | [ ] Slot",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color.YELLOW
	)

	draw_string(
		ThemeDB.fallback_font,
		Vector2(x + 470, top_y),
		"[TAB] Palette",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color.WHITE
	)

	draw_string(
		ThemeDB.fallback_font,
		Vector2(x + 610, top_y),
		"[M] Resize",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color.WHITE
	)

	draw_string(
		ThemeDB.fallback_font,
		Vector2(x + 760, top_y),
		"[E] Exit",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color.WHITE
	)

	draw_string(
		ThemeDB.fallback_font,
		Vector2(x, palette_y),
		"Terrain",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color.YELLOW if editor_palette == "terrain" else Color.WHITE
	)

	draw_string(
		ThemeDB.fallback_font,
		Vector2(x + 110, palette_y),
		"Player",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color.CORNFLOWER_BLUE if editor_palette == "player_unit" else Color.WHITE
	)

	draw_string(
		ThemeDB.fallback_font,
		Vector2(x + 210, palette_y),
		"Enemy",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color.INDIAN_RED if editor_palette == "enemy_unit" else Color.WHITE
	)

	draw_string(
		ThemeDB.fallback_font,
		Vector2(x + 310, palette_y),
		"Select",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color.YELLOW if editor_palette == "select" else Color.WHITE
	)

	if editor_palette == "terrain":

		draw_string(
			ThemeDB.fallback_font,
			Vector2(x, option_y),
			"[1] Grass",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			Color.YELLOW if selected_editor_tile == "." else Color.WHITE
		)

		draw_string(
			ThemeDB.fallback_font,
			Vector2(x + spacing, option_y),
			"[2] Wall",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			Color.YELLOW if selected_editor_tile == "W" else Color.WHITE
		)

		draw_string(
			ThemeDB.fallback_font,
			Vector2(x + spacing * 2, option_y),
			"[3] River",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			Color.YELLOW if selected_editor_tile == "R" else Color.WHITE
		)

	elif (
		editor_palette == "player_unit"
		or editor_palette == "enemy_unit"
	):

		draw_string(
			ThemeDB.fallback_font,
			Vector2(x, option_y),
			"[1] Fighter",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			Color.YELLOW if selected_editor_unit_class == "fighter" else Color.WHITE
		)

		draw_string(
			ThemeDB.fallback_font,
			Vector2(x + spacing, option_y),
			"[2] Tank",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			Color.YELLOW if selected_editor_unit_class == "tank" else Color.WHITE
		)

		draw_string(
			ThemeDB.fallback_font,
			Vector2(x + spacing * 2, option_y),
			"[3] Lancer",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			Color.YELLOW if selected_editor_unit_class == "lancer" else Color.WHITE
		)

		draw_string(
			ThemeDB.fallback_font,
			Vector2(x + spacing * 3, option_y),
			"[4] Duelist",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			Color.YELLOW if selected_editor_unit_class == "duelist" else Color.WHITE
		)

		draw_string(
			ThemeDB.fallback_font,
			Vector2(x + spacing * 4, option_y),
			"[5] Healer",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			Color.YELLOW if selected_editor_unit_class == "healer" else Color.WHITE
		)

		draw_string(
			ThemeDB.fallback_font,
			Vector2(x + spacing * 5, option_y),
			"[6] Archer",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			Color.YELLOW if selected_editor_unit_class == "archer" else Color.WHITE
		)

	if editor_palette == "select":

		draw_string(
			ThemeDB.fallback_font,
			Vector2(x, action_y),
			"Drag: select area | Right click: deselect",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			Color.YELLOW
		)

	else:

		var action_text = "Left click: place/paint | Right click: remove/erase | Ctrl+drag: rectangle fill"

		draw_string(
			ThemeDB.fallback_font,
			Vector2(x, action_y),
			action_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			Color.WHITE
		)

		var facing_text = "Facing: " + str(selected_editor_facing) + " | [F] Rotate"

		draw_string(
			ThemeDB.fallback_font,
			Vector2(x, facing_y),
			facing_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			Color.WHITE
		)

# =========================
# Rotates editor unit facing
# clockwise through 8 directions.
# =========================

func rotate_editor_facing():

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

	var current_index = directions.find(selected_editor_facing)

	if current_index == -1:
		selected_editor_facing = Vector2i(0, -1)
		return

	var next_index = (current_index + 1) % directions.size()

	selected_editor_facing = directions[next_index]

	queue_redraw()

# =========================
# Cycles editor palette mode.
# =========================

func cycle_editor_palette():

	if not editor_mode:
		return

	if editor_palette == "terrain":
		editor_palette = "player_unit"
	elif editor_palette == "player_unit":
		editor_palette = "enemy_unit"
	elif editor_palette == "enemy_unit":
		editor_palette = "select"
	else:
		editor_palette = "terrain"

	queue_redraw()

# =========================
# Draws rectangle fill preview
# while Ctrl-dragging in editor mode.
# =========================

func draw_editor_rect_preview():

	if not editor_mode:
		return

	if not editor_rect_dragging:
		return

	if editor_rect_start_cell == Vector2i(-1, -1):
		return

	var min_x = min(editor_rect_start_cell.x, hovered_cell.x)
	var max_x = max(editor_rect_start_cell.x, hovered_cell.x)

	var min_y = min(editor_rect_start_cell.y, hovered_cell.y)
	var max_y = max(editor_rect_start_cell.y, hovered_cell.y)

	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):

			var cell = Vector2i(x, y)

			if not map_data.is_inside_grid(cell):
				continue

			draw_rect(
				map_data.grid_rect(cell),
				Color(1.0, 1.0, 0.0, 0.35)
			)

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

	if not editor_mode:

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

	draw_editor_rect_preview()
	draw_editor_select_drag_preview()
	draw_editor_selected_area()
	draw_editor_move_preview()
	draw_editor_ui()
	draw_editor_resize_ui()

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

# ==================================================
# ENGINE CALLBACKS
# ==================================================

# =========================
# Initial setup.
# =========================

func _ready():

	if FileAccess.file_exists(get_editor_map_path()):

		map_serializer.load_map(
			map_data,
			units,
			unit_data,
			get_editor_map_path()
		)

	else:

		map_data.normalize_terrain_rows()
		units = battle_setup.create_battle_units(unit_data)

	queue_redraw()

# =========================
# Per-frame updates.
# =========================

func _process(_delta):

	var mouse_pos = get_viewport().get_mouse_position()

	hovered_cell = map_data.world_to_grid(mouse_pos)

	# =========================
	# Editor drag painting
	# =========================

	if (
		editor_mode
		and editor_palette == "terrain"
		and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		and not Input.is_key_pressed(KEY_CTRL)
		and not editor_rect_dragging
	):
		editor_system.paint_tile(
			map_data,
			hovered_cell,
			selected_editor_tile
		)

	# =========================
	# Normal movement path preview
	# =========================

	if not editor_mode:

		hover_path_cells = path_preview_system.update_hover_path(
			hover_path_cells,
			map_data,
			units,
			unit_query,
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

	if not event is InputEventKey:
		return

	if not event.pressed:
		return

	if editor_resize_mode:
		handle_editor_resize_input(event)
		return

	match event.keycode:

		KEY_E:
			editor_mode = !editor_mode

			clear_pending_action_state()

			queue_redraw()
			
		KEY_F:
			if editor_mode:
				rotate_editor_facing()
				
		KEY_M:
			start_editor_resize_mode()
			
		KEY_S:

			if editor_mode and event.ctrl_pressed:
				save_editor_map()

		KEY_L:

			if editor_mode and event.ctrl_pressed:
				load_editor_map()

		KEY_TAB:
			cycle_editor_palette()
			
		KEY_BRACKETLEFT:
			if editor_mode:
				change_editor_map_slot(-1)

		KEY_BRACKETRIGHT:
			if editor_mode:
				change_editor_map_slot(1)

		KEY_1:
			if editor_palette == "terrain":
				selected_editor_tile = "."
			else:
				selected_editor_unit_class = "fighter"

		KEY_2:
			if editor_palette == "terrain":
				selected_editor_tile = "W"
			else:
				selected_editor_unit_class = "tank"

		KEY_3:
			if editor_palette == "terrain":
				selected_editor_tile = "R"
			else:
				selected_editor_unit_class = "lancer"

		KEY_4:
			if editor_palette != "terrain":
				selected_editor_unit_class = "duelist"
				
		KEY_5:
			if editor_palette != "terrain":
				selected_editor_unit_class = "healer"

		KEY_6:
			if editor_palette != "terrain":
				selected_editor_unit_class = "archer"

		KEY_C:
			cycle_coverage_mode()

		KEY_T:
			end_current_turn()

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

func end_current_turn():

	stamina_system.recover_idle_healers(
		units,
		turn_manager.current_team
	)

	turn_manager.end_turn(units)

	if turn_manager.current_team == "player":
		turn_number += 1

	clear_selection()
	inspected_unit_id = -1

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

	# =========================
	# Right click behavior
	# =========================

	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:

		if editor_mode:

			if editor_palette == "select":

				editor_selected_rect_start = Vector2i(-1, -1)
				editor_selected_rect_end = Vector2i(-1, -1)

				editor_select_dragging = false
				editor_select_start_cell = Vector2i(-1, -1)

				queue_redraw()
				return

			if editor_palette == "terrain":

				editor_system.paint_tile(
					map_data,
					hovered_cell,
					"."
				)

			else:

				editor_system.remove_unit_at(
					units,
					unit_query,
					hovered_cell
				)

			queue_redraw()
			return

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

	if event.button_index == MOUSE_BUTTON_LEFT:

		if editor_mode:

			if event.pressed:

				if editor_palette == "select":

					if editor_cell_is_inside_selected_area(hovered_cell):

						editor_move_dragging = true
						editor_move_start_cell = hovered_cell

					else:

						editor_select_dragging = true
						editor_select_start_cell = hovered_cell

					return

				if event.ctrl_pressed:

					editor_rect_dragging = true
					editor_rect_start_cell = hovered_cell
					return

				handle_left_click()
				return

			if not event.pressed and editor_move_dragging:

				var offset = hovered_cell - editor_move_start_cell

				editor_system.move_selection(
					map_data,
					units,
					editor_selected_rect_start,
					editor_selected_rect_end,
					offset
				)

				editor_selected_rect_start += offset
				editor_selected_rect_end += offset

				editor_move_dragging = false
				editor_move_start_cell = Vector2i(-1, -1)

				queue_redraw()
				return

			if not event.pressed and editor_select_dragging:

				editor_selected_rect_start = Vector2i(
					min(editor_select_start_cell.x, hovered_cell.x),
					min(editor_select_start_cell.y, hovered_cell.y)
				)

				editor_selected_rect_end = Vector2i(
					max(editor_select_start_cell.x, hovered_cell.x),
					max(editor_select_start_cell.y, hovered_cell.y)
				)

				editor_select_dragging = false
				editor_select_start_cell = Vector2i(-1, -1)

				queue_redraw()
				return

			if not event.pressed and editor_rect_dragging:

				editor_system.fill_rect(
					map_data,
					editor_rect_start_cell,
					hovered_cell,
					selected_editor_tile
				)

				editor_rect_dragging = false
				editor_rect_start_cell = Vector2i(-1, -1)

				queue_redraw()
				return

		if event.pressed:
			handle_left_click()

# =========================
# Main left-click handler.
# =========================

func handle_left_click():

	var clicked_cell = hovered_cell

	if not map_data.is_inside_grid(clicked_cell):
		return

	# =========================
	# Editor mode terrain painting
	# =========================

	if editor_mode:

		if editor_palette == "terrain":

			editor_system.paint_tile(
				map_data,
				clicked_cell,
				selected_editor_tile
			)

		elif editor_palette == "player_unit":

			editor_system.place_unit(
				units,
				unit_query,
				unit_data,
				map_data,
				clicked_cell,
				selected_editor_unit_class,
				"player",
				selected_editor_facing
			)

		elif editor_palette == "enemy_unit":

			editor_system.place_unit(
				units,
				unit_query,
				unit_data,
				map_data,
				clicked_cell,
				selected_editor_unit_class,
				"enemy",
				selected_editor_facing
			)

		queue_redraw()
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

	var state = selection_system.clear_selection()

	selected_unit = state["selected_unit"]
	selected_unit_start_cell = state["selected_unit_start_cell"]
	move_tiles = state["move_tiles"]

	pending_move_cell = state["pending_move_cell"]
	pending_facing = state["pending_facing"]
	pending_move_distance = state["pending_move_distance"]
	pending_move_direction = state["pending_move_direction"]
	pending_coverage_enemies = state["pending_coverage_enemies"]

	hover_path_cells.clear()

# =========================
# Clears pending action confirmation state.
#
# If a unit had visually moved, it is restored
# to its original starting cell.
# =========================

func clear_pending_action_state():

	if selected_unit != -1 and has_pending_move():
		units[selected_unit]["pos"] = selected_unit_start_cell

	var state = selection_system.clear_pending_action_state()

	selected_unit = state["selected_unit"]
	selected_unit_start_cell = state["selected_unit_start_cell"]
	move_tiles = state["move_tiles"]

	pending_move_cell = state["pending_move_cell"]
	pending_facing = state["pending_facing"]
	pending_move_distance = state["pending_move_distance"]
	pending_move_direction = state["pending_move_direction"]
	pending_coverage_enemies = state["pending_coverage_enemies"]

	awaiting_attack_confirmation = state["awaiting_attack_confirmation"]
	awaiting_heal_confirmation = state["awaiting_heal_confirmation"]
	awaiting_wait_confirmation = state["awaiting_wait_confirmation"]

	pending_attack_target = state["pending_attack_target"]
	pending_heal_target = state["pending_heal_target"]

	hover_path_cells.clear()

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
		move_tiles,
		hover_path_cells
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

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
@onready var path_preview_system = $Systems/PathPreviewSystem
@onready var render_system = $Systems/RenderSystem
@onready var selection_state = $Systems/SelectionState
@onready var selection_system = $Systems/SelectionSystem

# =========================
# UI
# =========================

@onready var hover_unit_panel = $CanvasLayer/HoverUnitPanel
@onready var hover_unit_name_label = $CanvasLayer/HoverUnitPanel/UnitNameLabel
@onready var hover_hp_value_label = $CanvasLayer/HoverUnitPanel/HPValueLabel
@onready var hover_hp_bar = $CanvasLayer/HoverUnitPanel/HPBar
@onready var hover_hp_preview_bar = $CanvasLayer/HoverUnitPanel/HPPreviewBar
@onready var hover_stamina_value_label = $CanvasLayer/HoverUnitPanel/StaminaValueLabel
@onready var hover_stamina_bar = $CanvasLayer/HoverUnitPanel/StaminaBar
@onready var hover_hp_text_label = $CanvasLayer/HoverUnitPanel/HPTextLabel
@onready var hover_stamina_text_label = $CanvasLayer/HoverUnitPanel/StaminaTextLabel

@onready var phase_popup = $CanvasLayer/PhasePopup
@onready var phase_panel = $CanvasLayer/PhasePopup/PhasePanel
@onready var phase_label = $CanvasLayer/PhasePopup/PhasePanel/PhaseLabel

@onready var phase_dim = $CanvasLayer/PhasePopup/ScreenDim

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

# AI profile assigned to newly placed editor units.
var selected_editor_ai_profile := "barbarian"

var selected_editor_unit := -1

var editor_unit_move_dragging := false
var editor_unit_move_start_cell: Vector2i = Vector2i(-1, -1)

var show_all_defender_leashes := false

var editor_ai_profiles_by_class = {

	"fighter": [
		"barbarian",
		"defender"
	],

	"tank": [
		"barbarian",
		"defender"
	],

	"lancer": [
		"barbarian",
		"defender"
	],

	"duelist": [
		"barbarian",
		"defender"
	],

	"archer": [
		"cautious_ranged"
	],

	"healer": [
		"support_healer"
	]
}

# =========================
# Cycles the AI profile used
# when placing units in editor mode.
#
# Only AI profiles valid for the
# selected unit class are available.
# =========================

func cycle_editor_ai_profile():

	var valid_profiles = get_valid_editor_ai_profiles()

	var current_index = valid_profiles.find(
		selected_editor_ai_profile
	)

	if current_index == -1:

		selected_editor_ai_profile = valid_profiles[0]
		queue_redraw()
		return

	var next_index = (
		current_index + 1
	) % valid_profiles.size()

	selected_editor_ai_profile = valid_profiles[next_index]

	queue_redraw()

# =========================
# Returns valid AI profiles for
# the currently selected unit class.
# =========================

func get_valid_editor_ai_profiles() -> Array:

	if editor_ai_profiles_by_class.has(selected_editor_unit_class):
		return editor_ai_profiles_by_class[selected_editor_unit_class]

	return ["barbarian"]


# =========================
# Ensures selected AI profile
# is valid for the selected class.
# =========================

func validate_selected_editor_ai_profile():

	var valid_profiles = get_valid_editor_ai_profiles()

	if valid_profiles.has(selected_editor_ai_profile):
		return

	selected_editor_ai_profile = valid_profiles[0]

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

		KEY_UP:
			editor_resize_height += 1

		KEY_DOWN:
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
		Vector2(x + 140, top_y),
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

		if selected_editor_unit != -1 and selected_editor_unit < units.size():

			var unit = units[selected_editor_unit]

			var ai_profile = "none"

			if unit.has("ai_profile"):
				ai_profile = unit["ai_profile"]

			var leash_text = "N/A"

			if unit.has("leash_range"):
				leash_text = str(unit["leash_range"])

			draw_string(
				ThemeDB.fallback_font,
				Vector2(x, facing_y),
				"Selected Unit | AI: " + ai_profile + " | Leash: " + leash_text + " | +/- Adjust",
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				font_size,
				Color.CYAN
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

		var facing_text = (
			"Facing: "
			+ str(selected_editor_facing)
			+ " | [F] Rotate"
		)

		draw_string(
			ThemeDB.fallback_font,
			Vector2(x, facing_y),
			facing_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			Color.WHITE
		)

		var ai_text = (
			"AI: "
			+ selected_editor_ai_profile
			+ " | [A] Cycle AI"
		)

		draw_string(
			ThemeDB.fallback_font,
			Vector2(x + 360, facing_y),
			ai_text,
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
		awaiting_support_confirmation
	)

	draw_editor_rect_preview()
	draw_editor_select_drag_preview()
	draw_editor_selected_area()
	draw_all_defender_leashes()
	draw_selected_editor_unit_leash()
	draw_editor_unit_move_preview()
	draw_editor_move_preview()
	draw_editor_ui()
	draw_editor_resize_ui()

# =========================
# Draws all defender leash
# zones while debug overlay
# is enabled.
#
# Used for editor debugging.
#
# Purple overlay = defender
# territory area.
# =========================

func draw_all_defender_leashes():

	if not editor_mode:
		return

	if not show_all_defender_leashes:
		return

	for unit in units:

		if not unit.has("ai_profile"):
			continue

		if unit["ai_profile"] != "defender":
			continue

		if not unit.has("home_pos"):
			continue

		if not unit.has("leash_range"):
			continue

		var occupied_tiles: Array[Vector2i] = []

		var leash_tiles = map_data.get_move_range(
			unit["home_pos"],
			unit["leash_range"],
			occupied_tiles
		)

		for tile in leash_tiles:

			if not map_data.is_inside_grid(tile):
				continue

			draw_rect(
				map_data.grid_rect(tile),
				Color(0.6, 0.2, 1.0, 0.12)
			)

		draw_rect(
			map_data.grid_rect(unit["home_pos"]),
			Color(0.6, 0.2, 1.0, 0.35)
		)

# =========================
# Draws destination preview
# while dragging a selected
# editor unit.
#
# Yellow overlay = unit's
# pending destination tile.
# =========================

func draw_editor_unit_move_preview():

	if not editor_mode:
		return

	if editor_palette != "select":
		return

	if not editor_unit_move_dragging:
		return

	if selected_editor_unit == -1:
		return

	if selected_editor_unit >= units.size():
		return

	var offset = hovered_cell - editor_unit_move_start_cell

	if offset == Vector2i.ZERO:
		return

	var target_cell = units[selected_editor_unit]["pos"] + offset

	if not map_data.is_inside_grid(target_cell):
		return

	draw_rect(
		map_data.grid_rect(target_cell),
		Color(1.0, 1.0, 0.0, 0.45)
	)

# =========================
# Draws leash range preview
# for the currently selected
# editor unit.
#
# Blue overlay = allowed
# defender movement area.
# =========================

func draw_selected_editor_unit_leash():

	if not editor_mode:
		return

	if editor_palette != "select":
		return

	if selected_editor_unit == -1:
		return

	if selected_editor_unit >= units.size():
		return

	var unit = units[selected_editor_unit]

	if not unit.has("home_pos"):
		return

	if not unit.has("leash_range"):
		return

	var occupied_tiles: Array[Vector2i] = []

	var leash_tiles = map_data.get_move_range(
		unit["home_pos"],
		unit["leash_range"],
		occupied_tiles
	)

	for tile in leash_tiles:

		if not map_data.is_inside_grid(tile):
			continue

		draw_rect(
			map_data.grid_rect(tile),
			Color(0.2, 0.5, 1.0, 0.22)
		)

	draw_rect(
		map_data.grid_rect(unit["home_pos"]),
		Color(0.0, 0.8, 1.0, 0.45)
	)

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
# Updates hover unit UI panel.
# =========================

func update_hover_unit_panel():

	if (
		editor_mode
		or awaiting_support_confirmation
		or awaiting_wait_confirmation
	):
		hover_unit_panel.visible = false
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
		hover_unit_panel.visible = false
		return

	if display_unit < 0 or display_unit >= units.size():
		hover_unit_panel.visible = false
		return

	var unit = units[display_unit]

	var panel_style = StyleBoxFlat.new()

	panel_style.bg_color = Color(0.008, 0.008, 0.212, 1.0)

	panel_style.border_width_left = 4
	panel_style.border_width_top = 4
	panel_style.border_width_right = 4
	panel_style.border_width_bottom = 4

	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8

	if unit["team"] == "enemy":

		panel_style.border_color = Color(0.9, 0.2, 0.2)

		panel_style.bg_color = Color(0.028, 0.0, 0.0, 0.949)

	else:

		panel_style.border_color = Color(0.2, 0.45, 1.0)

		panel_style.bg_color = Color(0.02,0.03,0.12,0.95)

	hover_unit_panel.add_theme_stylebox_override(
		"panel",
		panel_style
	)

	hover_unit_panel.visible = true

	hover_hp_text_label.position = Vector2(24, 56)
	hover_hp_text_label.text = "HP"

	hover_stamina_text_label.position = Vector2(24, 78)
	hover_stamina_text_label.text = "STA"

	# Match old drawn panel layout.
	hover_unit_panel.position = Vector2(16, 16)
	hover_unit_panel.size = Vector2(380, 112)

	hover_unit_name_label.position = Vector2(24, 16)
	hover_unit_name_label.text = unit["class"].capitalize()

	var preview_hp = unit["hp"]

	if preview_damage > 0:
		preview_hp = max(unit["hp"] - preview_damage, 0)

	hover_hp_value_label.position = Vector2(285, 18)
	hover_hp_value_label.text = str(preview_hp) + "/" + str(unit["max_hp"])

	var hp_bar_pos = Vector2(105, 56)
	var hp_bar_size = Vector2(235, 22)

	var hp_percent = float(unit["hp"]) / float(unit["max_hp"])
	var hp_fill_width = hp_bar_size.x * hp_percent

	var preview_percent = float(preview_hp) / float(unit["max_hp"])
	var preview_fill_width = hp_bar_size.x * preview_percent

	hover_hp_bar.position = hp_bar_pos
	hover_hp_bar.size = Vector2(hp_fill_width, hp_bar_size.y)

	if unit["team"] == "enemy":
		hover_hp_bar.color = Color(0.85, 0.2, 0.2)
	else:
		hover_hp_bar.color = Color(0.2, 0.85, 0.2)

	var damage_width = hp_fill_width - preview_fill_width

	if preview_damage > 0 and damage_width > 0:
		hover_hp_preview_bar.visible = true
		hover_hp_preview_bar.position = Vector2(
			hp_bar_pos.x + preview_fill_width,
			hp_bar_pos.y
		)
		hover_hp_preview_bar.size = Vector2(damage_width, hp_bar_size.y)
		hover_hp_preview_bar.color = Color(1.0, 0.9, 0.0, 0.95)
	else:
		hover_hp_preview_bar.visible = false

	var stamina_bar_pos = Vector2(105, 86)
	var stamina_bar_size = Vector2(150, 12)

	var stamina_percent = float(unit["stamina"]) / float(unit["max_stamina"])
	var stamina_fill_width = stamina_bar_size.x * stamina_percent

	hover_stamina_bar.position = stamina_bar_pos
	hover_stamina_bar.size = Vector2(stamina_fill_width, stamina_bar_size.y)
	hover_stamina_bar.color = Color(0.95, 0.65, 0.18)

	hover_stamina_value_label.position = Vector2(260, 78)
	hover_stamina_value_label.text = (
		str(unit["stamina"])
		+ "/"
		+ str(unit["max_stamina"])
	)

# =========================
# Shows center-screen phase popup.
# =========================

func show_phase_popup(custom_text: String = ""):

	var phase_text = custom_text

	if phase_text == "":
		phase_text = "Player Phase"

		if turn_manager.current_team == "enemy":
			phase_text = "Enemy Phase"

	if custom_text != "":
		phase_label.text = phase_text
	else:
		phase_label.text = phase_text + "  |  Turn " + str(turn_number)

	var is_enemy_phase = (
		phase_text == "Enemy Phase"
	)

	var phase_border_color = Color(0.2, 0.45, 1.0)
	var phase_bg_color = Color(0.0, 0.02, 0.08, 0.95)
	var phase_text_color = Color(0.45, 0.7, 1.0)

	if is_enemy_phase:
		phase_border_color = Color(0.9, 0.2, 0.2)
		phase_bg_color = Color(0.03, 0.0, 0.0, 0.95)
		phase_text_color = Color(1.0, 0.25, 0.25)

	phase_label.add_theme_color_override(
		"font_color",
		phase_text_color
	)

	var viewport_size = get_viewport_rect().size
	var popup_size = Vector2(620, 120)

	phase_popup.position = Vector2.ZERO
	phase_popup.size = viewport_size

	phase_dim.position = Vector2.ZERO
	phase_dim.size = viewport_size

	if custom_text == "Battle Commence":
		phase_dim.visible = true
		phase_dim.color = Color(0.0, 0.0, 0.0, 0.35)
	else:
		phase_dim.visible = false

	phase_panel.size = popup_size
	phase_panel.position = (viewport_size - popup_size) / 2.0

	phase_label.size = popup_size
	phase_label.position = Vector2.ZERO
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = phase_bg_color
	panel_style.border_color = phase_border_color

	panel_style.border_width_left = 4
	panel_style.border_width_top = 4
	panel_style.border_width_right = 4
	panel_style.border_width_bottom = 4

	panel_style.corner_radius_top_left = 14
	panel_style.corner_radius_top_right = 14
	panel_style.corner_radius_bottom_left = 14
	panel_style.corner_radius_bottom_right = 14

	phase_panel.add_theme_stylebox_override(
		"panel",
		panel_style
	)

	phase_popup.visible = true
	phase_popup.modulate.a = 1.0

	var tween = create_tween()

	tween.tween_interval(1.25)

	tween.tween_property(
		phase_popup,
		"modulate:a",
		0.0,
		0.55
	)

	tween.tween_callback(
		func():
			phase_popup.visible = false
			phase_dim.visible = false
			phase_popup.modulate.a = 1.0
	)

	await tween.finished

# ==================================================
# ENGINE CALLBACKS
# ==================================================

# =========================
# Initial setup.
# =========================

func _ready():

	phase_popup.visible = false

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

	await show_phase_popup("Battle Commence")
	await show_phase_popup()

# =========================
# Per-frame updates.
# =========================

func _process(_delta):

	var mouse_pos = get_viewport().get_mouse_position()

	hovered_cell = map_data.world_to_grid(mouse_pos)
	update_hover_unit_panel()

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

		KEY_A:
			if editor_mode:
				cycle_editor_ai_profile()

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

		KEY_EQUAL:

			if (
				editor_mode
				and editor_palette == "select"
			):

				editor_system.increase_unit_leash_range(
					units,
					selected_editor_unit
				)

				queue_redraw()

		KEY_MINUS:

			if (
				editor_mode
				and editor_palette == "select"
			):

				editor_system.decrease_unit_leash_range(
					units,
					selected_editor_unit
				)

				queue_redraw()

		KEY_1:
			if editor_palette == "terrain":
				selected_editor_tile = "."
			else:
				selected_editor_unit_class = "fighter"
				validate_selected_editor_ai_profile()
				queue_redraw()

		KEY_2:
			if editor_palette == "terrain":
				selected_editor_tile = "W"
			else:
				selected_editor_unit_class = "tank"
				validate_selected_editor_ai_profile()
				queue_redraw()

		KEY_3:
			if editor_palette == "terrain":
				selected_editor_tile = "R"
			else:
				selected_editor_unit_class = "lancer"
				validate_selected_editor_ai_profile()
				queue_redraw()

		KEY_4:
			if editor_palette != "terrain":
				selected_editor_unit_class = "duelist"
				validate_selected_editor_ai_profile()
				queue_redraw()

		KEY_5:
			if editor_palette != "terrain":
				selected_editor_unit_class = "healer"
				validate_selected_editor_ai_profile()
				queue_redraw()

		KEY_6:
			if editor_palette != "terrain":
				selected_editor_unit_class = "archer"
				validate_selected_editor_ai_profile()
				queue_redraw()

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

		KEY_F7:
			if editor_mode:
				show_all_defender_leashes = !show_all_defender_leashes
				queue_redraw()


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

	if not event is InputEventMouseButton:
		return

	# =========================
	# Right click behavior
	# =========================

	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:

		if editor_mode:

			if editor_palette == "select":

				selected_editor_unit = -1

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

					var clicked_unit = unit_query.get_unit_at(
						units,
						hovered_cell
					)

					if clicked_unit != -1:

						selected_editor_unit = clicked_unit

						editor_selected_rect_start = Vector2i(-1, -1)
						editor_selected_rect_end = Vector2i(-1, -1)

						editor_unit_move_dragging = true
						editor_unit_move_start_cell = hovered_cell

						queue_redraw()
						return

					selected_editor_unit = -1

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

			if not event.pressed and editor_unit_move_dragging:

				var offset = hovered_cell - editor_unit_move_start_cell

				if (
					selected_editor_unit != -1
					and selected_editor_unit < units.size()
					and offset != Vector2i.ZERO
				):

					var target_cell = units[selected_editor_unit]["pos"] + offset

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
							or occupied_unit == selected_editor_unit
						):

							units[selected_editor_unit]["pos"] = target_cell

							if units[selected_editor_unit].has("home_pos"):
								units[selected_editor_unit]["home_pos"] += offset

				editor_unit_move_dragging = false
				editor_unit_move_start_cell = Vector2i(-1, -1)

				queue_redraw()
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
				selected_editor_facing,
				selected_editor_ai_profile
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
				selected_editor_facing,
				selected_editor_ai_profile
			)

		queue_redraw()
		return

	if selected_unit != -1 and has_pending_move():

		if clicked_cell == pending_move_cell:

			var state = action_system.start_wait_confirmation()

			awaiting_wait_confirmation = state["awaiting_wait_confirmation"]
			awaiting_attack_confirmation = state["awaiting_attack_confirmation"]
			awaiting_support_confirmation = state["awaiting_support_confirmation"]

			pending_attack_target = state["pending_attack_target"]
			pending_support_target = state["pending_support_target"]

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
			var state = action_system.get_support_confirmation_state(
				units,
				selected_unit,
				clicked_cell,
				unit_query
			)

			if not state.is_empty():

				pending_support_target = state["pending_support_target"]

				awaiting_support_confirmation = state["awaiting_support_confirmation"]
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
				awaiting_support_confirmation = state["awaiting_support_confirmation"]
				awaiting_wait_confirmation = state["awaiting_wait_confirmation"]

				pending_support_target = state["pending_support_target"]

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
			awaiting_support_confirmation = state["awaiting_support_confirmation"]

			pending_attack_target = state["pending_attack_target"]
			pending_support_target = state["pending_support_target"]

			queue_redraw()
			return

		if action_query.should_handle_facing_click(
			units,
			selected_unit,
			clicked_cell,
			pending_move_cell,
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
# Clears selection and pending movement state.
# =========================

func clear_selection():

	var state = selection_system.clear_selection()

	selected_unit = state["selected_unit"]
	selected_unit_start_cell = state["selected_unit_start_cell"]
	move_tiles = state["move_tiles"]

	pending_move_cell = state["pending_move_cell"]
	pending_move_distance = state["pending_move_distance"]
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
	pending_move_distance = state["pending_move_distance"]
	pending_coverage_enemies = state["pending_coverage_enemies"]

	awaiting_attack_confirmation = state["awaiting_attack_confirmation"]
	awaiting_support_confirmation = state["awaiting_support_confirmation"]
	awaiting_wait_confirmation = state["awaiting_wait_confirmation"]

	pending_attack_target = state["pending_attack_target"]
	pending_support_target = state["pending_support_target"]

	hover_path_cells.clear()

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
	pending_move_distance = result["pending_move_distance"]
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

	clear_selection()
	inspected_unit_id = -1

	queue_redraw()

	await show_phase_popup()

	await process_ai_turn_if_needed()

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
		turn_number += 1

	clear_selection()
	inspected_unit_id = -1

	queue_redraw()

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

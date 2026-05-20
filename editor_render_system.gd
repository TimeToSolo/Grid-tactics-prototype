extends Node

# ==================================================
# EDITOR RENDER SYSTEM
# ==================================================
# Handles:
# - editor preview rendering
# - selection overlays
# - drag previews
# - editor visual helpers
#
# All rendering functions receive
# the parent drawing canvas so this
# node remains stateless and reusable.
#
# Main.gd still owns:
# - _draw()
# - render order
# ==================================================

# =========================
# Draws rectangle fill preview
# while Ctrl-dragging in editor mode.
# =========================

func draw_editor_rect_preview(
	canvas,
	map_data,
	editor_state,
	hovered_cell: Vector2i
):

	if not editor_state.editor_mode:
		return

	if not editor_state.editor_rect_dragging:
		return

	if editor_state.editor_rect_start_cell == Vector2i(-1, -1):
		return

	var min_x = min(
		editor_state.editor_rect_start_cell.x,
		hovered_cell.x
	)

	var max_x = max(
		editor_state.editor_rect_start_cell.x,
		hovered_cell.x
	)

	var min_y = min(
		editor_state.editor_rect_start_cell.y,
		hovered_cell.y
	)

	var max_y = max(
		editor_state.editor_rect_start_cell.y,
		hovered_cell.y
	)

	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):

			var cell = Vector2i(x, y)

			if not map_data.is_inside_grid(cell):
				continue

			canvas.draw_rect(
				map_data.grid_rect(cell),
				Color(1.0, 1.0, 0.0, 0.35)
			)

# =========================
# Draws live select rectangle
# while dragging selection.
# =========================

func draw_editor_select_drag_preview(
	canvas,
	map_data,
	editor_state,
	hovered_cell: Vector2i
):

	if not editor_state.editor_mode:
		return

	if editor_state.editor_palette != "select":
		return

	if not editor_state.editor_select_dragging:
		return

	var min_x = min(
		editor_state.editor_select_start_cell.x,
		hovered_cell.x
	)

	var max_x = max(
		editor_state.editor_select_start_cell.x,
		hovered_cell.x
	)

	var min_y = min(
		editor_state.editor_select_start_cell.y,
		hovered_cell.y
	)

	var max_y = max(
		editor_state.editor_select_start_cell.y,
		hovered_cell.y
	)

	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):

			var cell = Vector2i(x, y)

			if not map_data.is_inside_grid(cell):
				continue

			canvas.draw_rect(
				map_data.grid_rect(cell),
				Color(1.0, 1.0, 0.0, 0.35)
			)

# =========================
# Draws the currently
# selected rectangle area
# in select mode.
#
# Yellow overlay =
# active selected region.
# =========================

func draw_editor_selected_area(
	canvas,
	map_data,
	editor_state
):

	if not editor_state.editor_mode:
		return

	if editor_state.editor_palette != "select":
		return

	if editor_state.editor_selected_rect_start == Vector2i(-1, -1):
		return

	if editor_state.editor_selected_rect_end == Vector2i(-1, -1):
		return

	var min_x = min(
		editor_state.editor_selected_rect_start.x,
		editor_state.editor_selected_rect_end.x
	)

	var max_x = max(
		editor_state.editor_selected_rect_start.x,
		editor_state.editor_selected_rect_end.x
	)

	var min_y = min(
		editor_state.editor_selected_rect_start.y,
		editor_state.editor_selected_rect_end.y
	)

	var max_y = max(
		editor_state.editor_selected_rect_start.y,
		editor_state.editor_selected_rect_end.y
	)

	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):

			var cell = Vector2i(x, y)

			if not map_data.is_inside_grid(cell):
				continue

			canvas.draw_rect(
				map_data.grid_rect(cell),
				Color(1.0, 1.0, 0.0, 0.25)
			)

# =========================
# Draws movement preview
# for a selected rectangle
# area while dragging.
#
# Cyan overlay =
# destination preview.
# =========================

func draw_editor_move_preview(
	canvas,
	map_data,
	editor_state,
	hovered_cell: Vector2i
):

	if not editor_state.editor_mode:
		return

	if editor_state.editor_palette != "select":
		return

	if not editor_state.editor_move_dragging:
		return

	var offset = (
		hovered_cell
		- editor_state.editor_move_start_cell
	)

	var preview_start = (
		editor_state.editor_selected_rect_start
		+ offset
	)

	var preview_end = (
		editor_state.editor_selected_rect_end
		+ offset
	)

	for y in range(preview_start.y, preview_end.y + 1):
		for x in range(preview_start.x, preview_end.x + 1):

			var cell = Vector2i(x, y)

			if not map_data.is_inside_grid(cell):
				continue

			canvas.draw_rect(
				map_data.grid_rect(cell),
				Color(0.0, 1.0, 1.0, 0.35)
			)

# =========================
# Draws movement preview
# while dragging a selected
# editor unit.
#
# Yellow overlay =
# predicted destination.
# =========================

func draw_editor_unit_move_preview(
	canvas,
	map_data,
	editor_state,
	units: Array,
	hovered_cell: Vector2i
):

	if not editor_state.editor_mode:
		return

	if editor_state.editor_palette != "select":
		return

	if not editor_state.editor_unit_move_dragging:
		return

	if editor_state.selected_editor_unit == -1:
		return

	if editor_state.selected_editor_unit >= units.size():
		return

	var offset = (
		hovered_cell
		- editor_state.editor_unit_move_start_cell
	)

	if offset == Vector2i.ZERO:
		return

	var target_cell = (
		units[editor_state.selected_editor_unit]["pos"]
		+ offset
	)

	if not map_data.is_inside_grid(target_cell):
		return

	canvas.draw_rect(
		map_data.grid_rect(target_cell),
		Color(1.0, 1.0, 0.0, 0.45)
	)

# =========================
# Draws reinforcement stage
# markers for hidden enemy
# units in editor mode.
#
# Purple border =
# reinforcement unit.
#
# Label format:
# R# = spawn stage.
# =========================

func draw_editor_reinforcement_markers(
	canvas,
	map_data,
	editor_state,
	units: Array
):

	if not editor_state.editor_mode:
		return

	for unit in units:

		if not unit.has("starts_hidden"):
			continue

		if not unit["starts_hidden"]:
			continue

		if not unit.has("reinforcement_stage"):
			continue

		if not unit.has("pos"):
			continue

		if not unit["pos"] is Vector2i:
			continue

		var marker_pos = (
			map_data.grid_rect(unit["pos"]).position
			+ Vector2(6, 58)
		)

		canvas.draw_rect(
			map_data.grid_rect(unit["pos"]),
			Color(0.25, 0.0, 0.35, 0.65),
			false,
			5
		)

		canvas.draw_string(
			ThemeDB.fallback_font,
			marker_pos,
			"R" + str(unit["reinforcement_stage"]),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			16,
			Color(0.15, 0.15, 0.15)
		)

# =========================
# Draws objective zone tiles
# while editing maps.
#
# Cyan overlay =
# objective zone area.
# =========================

func draw_editor_objective_zones(
	canvas,
	map_data,
	editor_state
):

	if not editor_state.editor_mode:
		return

	for zone_name in editor_state.objective_zones.keys():

		if not editor_state.objective_zones[zone_name] is Array:
			continue

		for cell in editor_state.objective_zones[zone_name]:

			if not cell is Vector2i:
				continue

			if not map_data.is_inside_grid(cell):
				continue

			canvas.draw_rect(
				map_data.grid_rect(cell),
				Color(0.0, 0.8, 1.0, 0.25)
			)

			canvas.draw_rect(
				map_data.grid_rect(cell),
				Color(0.0, 0.8, 1.0, 0.8),
				false,
				3
			)

# =========================
# Draws the main editor UI.
#
# Includes:
# - palette selection
# - terrain/unit options
# - objective editing controls
# - reinforcement settings
# - selected unit info
# - editor hotkey hints
#
# This function only handles
# editor UI rendering.
#
# It does NOT:
# - process input
# - modify editor state
# - perform editor actions
# =========================

func draw_editor_ui(
	canvas,
	editor_state,
	mission_flow_controller,
	units: Array
):

	if not editor_state.editor_mode:
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

	canvas.draw_string(
		ThemeDB.fallback_font,
		Vector2(x, top_y),
		"EDITOR MODE",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color.WHITE
	)

	canvas.draw_string(
		ThemeDB.fallback_font,
		Vector2(x + 140, top_y),
		(
			"Slot "
			+ str(editor_state.editor_map_slot)
			+ " | Campaign: "
			+ mission_flow_controller.get_campaign_level_id()
			+ " < >"
			+ " | Ctrl+S/L Custom"
			+ " | F9/F10 Campaign"
		),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color.YELLOW
	)

	canvas.draw_string(
		ThemeDB.fallback_font,
		Vector2(x + 700, top_y),
		"[TAB] Palette",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color.WHITE
	)

	canvas.draw_string(
		ThemeDB.fallback_font,
		Vector2(x + 900, top_y),
		"[M] Resize",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color.WHITE
	)

	canvas.draw_string(
		ThemeDB.fallback_font,
		Vector2(x + 1080, top_y),
		"[E] Exit",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color.WHITE
	)

	canvas.draw_string(
		ThemeDB.fallback_font,
		Vector2(x, palette_y),
		"Terrain",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color.YELLOW if editor_state.editor_palette == "terrain" else Color.WHITE
	)

	canvas.draw_string(
		ThemeDB.fallback_font,
		Vector2(x + 110, palette_y),
		"Player",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color.CORNFLOWER_BLUE if editor_state.editor_palette == "player_unit" else Color.WHITE
	)

	canvas.draw_string(
		ThemeDB.fallback_font,
		Vector2(x + 210, palette_y),
		"Enemy",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color.INDIAN_RED if editor_state.editor_palette == "enemy_unit" else Color.WHITE
	)

	canvas.draw_string(
		ThemeDB.fallback_font,
		Vector2(x + 310, palette_y),
		"Reinf",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color.ORANGE if editor_state.editor_palette == "reinforcement" else Color.WHITE
	)

	canvas.draw_string(
		ThemeDB.fallback_font,
		Vector2(x + 420, palette_y),
		"Zone",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color.CYAN if editor_state.editor_palette == "zone" else Color.WHITE
	)

	canvas.draw_string(
		ThemeDB.fallback_font,
		Vector2(x + 520, palette_y),
		"Select",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color.YELLOW if editor_state.editor_palette == "select" else Color.WHITE
	)

	if editor_state.editor_palette == "terrain":

		canvas.draw_string(
			ThemeDB.fallback_font,
			Vector2(x, option_y),
			"[1] Grass",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			Color.YELLOW if editor_state.selected_editor_tile == "." else Color.WHITE
		)

		canvas.draw_string(
			ThemeDB.fallback_font,
			Vector2(x + spacing, option_y),
			"[2] Wall",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			Color.YELLOW if editor_state.selected_editor_tile == "W" else Color.WHITE
		)

		canvas.draw_string(
			ThemeDB.fallback_font,
			Vector2(x + spacing * 2, option_y),
			"[3] River",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			Color.YELLOW if editor_state.selected_editor_tile == "R" else Color.WHITE
		)

	elif (
		editor_state.editor_palette == "player_unit"
		or editor_state.editor_palette == "enemy_unit"
		or editor_state.editor_palette == "reinforcement"
	):

		canvas.draw_string(
			ThemeDB.fallback_font,
			Vector2(x, option_y),
			"[1] Fighter",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			Color.YELLOW if editor_state.selected_editor_unit_class == "fighter" else Color.WHITE
		)

		canvas.draw_string(
			ThemeDB.fallback_font,
			Vector2(x + spacing, option_y),
			"[2] Tank",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			Color.YELLOW if editor_state.selected_editor_unit_class == "tank" else Color.WHITE
		)

		canvas.draw_string(
			ThemeDB.fallback_font,
			Vector2(x + spacing * 2, option_y),
			"[3] Lancer",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			Color.YELLOW if editor_state.selected_editor_unit_class == "lancer" else Color.WHITE
		)

		canvas.draw_string(
			ThemeDB.fallback_font,
			Vector2(x + spacing * 3, option_y),
			"[4] Duelist",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			Color.YELLOW if editor_state.selected_editor_unit_class == "duelist" else Color.WHITE
		)

		canvas.draw_string(
			ThemeDB.fallback_font,
			Vector2(x + spacing * 4, option_y),
			"[5] Healer",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			Color.YELLOW if editor_state.selected_editor_unit_class == "healer" else Color.WHITE
		)

		canvas.draw_string(
			ThemeDB.fallback_font,
			Vector2(x + spacing * 5, option_y),
			"[6] Archer",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			Color.YELLOW if editor_state.selected_editor_unit_class == "archer" else Color.WHITE
		)

	if editor_state.editor_palette == "select":

		canvas.draw_string(
			ThemeDB.fallback_font,
			Vector2(x, action_y),
			"Drag: select area | Right click: deselect",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			Color.YELLOW
		)

		if editor_state.selected_editor_unit != -1 and editor_state.selected_editor_unit < units.size():

			var unit = units[editor_state.selected_editor_unit]

			var ai_profile = "none"

			if unit.has("ai_profile"):
				ai_profile = unit["ai_profile"]

			var leash_text = "N/A"

			if unit.has("leash_range"):
				leash_text = str(unit["leash_range"])

			canvas.draw_string(
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

		canvas.draw_string(
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
			+ str(editor_state.selected_editor_facing)
			+ " | [F] Rotate"
		)

		canvas.draw_string(
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
			+ editor_state.selected_editor_ai_profile
			+ " | [A] Cycle AI"
		)

		canvas.draw_string(
			ThemeDB.fallback_font,
			Vector2(x + 360, facing_y),
			ai_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			Color.WHITE
		)

		if editor_state.editor_objective_stages.is_empty():
			return

		if editor_state.editor_objective_stage_index < 0:
			return

		if editor_state.editor_objective_stage_index >= editor_state.editor_objective_stages.size():
			return

		var current_stage = editor_state.editor_objective_stages[
			editor_state.editor_objective_stage_index
		]

		var stage_detail = ""

		match current_stage.get("type", ""):

			"defeat_enemy_count":
				stage_detail = (
					"Kills: "
					+ str(current_stage.get("required_count", 1))
				)

			"retreat":
				stage_detail = (
					"Zone: "
					+ str(current_stage.get("zone", ""))
				)

			"rout":
				stage_detail = "Defeat all enemies"

		canvas.draw_string(
			ThemeDB.fallback_font,
			Vector2(x + 620, facing_y),
			(
				"Obj "
				+ str(editor_state.editor_objective_stage_index + 1)
				+ "/"
				+ str(editor_state.editor_objective_stages.size())
				+ " | Type: "
				+ str(current_stage.get("type", ""))
				+ " | "
				+ stage_detail
			),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			Color.YELLOW
		)

		canvas.draw_string(
			ThemeDB.fallback_font,
			Vector2(x + 620, facing_y + 24),
			(
				"[9/0] Stage  "
				+ "[P] Type  "
				+ "[{/}] Value  "
				+ "[\\] Complete: "
				+ str(current_stage.get("on_complete", ""))
				+ "  [O] Add  [Del] Delete"
			),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			Color.YELLOW
		)

# =========================
# Draws the editor map
# resize popup UI while
# resize mode is active.
#
# Displays:
# - current width
# - current height
# - resize controls
# =========================

func draw_editor_resize_ui(
	canvas,
	editor_state
):

	if not editor_state.editor_resize_mode:
		return

	canvas.draw_rect(
		Rect2(12, 120, 360, 130),
		Color(0.0, 0.0, 0.0, 0.75)
	)

	canvas.draw_string(
		ThemeDB.fallback_font,
		Vector2(24, 150),
		"MAP SIZE",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		18,
		Color.WHITE
	)

	canvas.draw_string(
		ThemeDB.fallback_font,
		Vector2(24, 180),
		"Width: " + str(editor_state.editor_resize_width) + "   Left/Right",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		16,
		Color.WHITE
	)

	canvas.draw_string(
		ThemeDB.fallback_font,
		Vector2(24, 205),
		"Height: " + str(editor_state.editor_resize_height) + "   Up/Down",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		16,
		Color.WHITE
	)

	canvas.draw_string(
		ThemeDB.fallback_font,
		Vector2(24, 235),
		"Enter: confirm   Esc: cancel",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		16,
		Color.YELLOW
	)

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

func draw_all_defender_leashes(
	canvas,
	map_data,
	editor_state,
	units: Array
):

	if not editor_state.editor_mode:
		return

	if not editor_state.show_all_defender_leashes:
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

			canvas.draw_rect(
				map_data.grid_rect(tile),
				Color(0.6, 0.2, 1.0, 0.12)
			)

		canvas.draw_rect(
			map_data.grid_rect(unit["home_pos"]),
			Color(0.6, 0.2, 1.0, 0.35)
		)

# =========================
# Draws leash range preview
# for the currently selected
# editor unit.
#
# Blue overlay = allowed
# defender movement area.
# =========================

func draw_selected_editor_unit_leash(
	canvas,
	map_data,
	editor_state,
	units: Array
):

	if not editor_state.editor_mode:
		return

	if editor_state.editor_palette != "select":
		return

	if editor_state.selected_editor_unit == -1:
		return

	if editor_state.selected_editor_unit >= units.size():
		return

	var unit = units[editor_state.selected_editor_unit]

	if not unit.has("home_pos"):
		return

	if not unit.has("leash_range"):
		return

	if not unit["home_pos"] is Vector2i:
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

		canvas.draw_rect(
			map_data.grid_rect(tile),
			Color(0.2, 0.5, 1.0, 0.22)
		)

	canvas.draw_rect(
		map_data.grid_rect(unit["home_pos"]),
		Color(0.0, 0.8, 1.0, 0.45)
	)

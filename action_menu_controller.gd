extends Node

signal option_confirmed(option: String)
signal menu_cancelled

var action_menu
var action_panel
var action_vbox

var option_labels: Array = []

var menu_visible := false
var options: Array[String] = []
var index := 0
var mode := ""

var confirm_source := "keyboard"

var map_data
var units: Array = []
var selected_unit := -1
var pending_move_cell: Vector2i = Vector2i(-1, -1)


# =========================
# Stores references to the
# existing action menu UI nodes.
# =========================

func setup(
	_action_menu,
	_action_panel,
	_action_vbox,
	_option_labels: Array,
	_map_data
):
	action_menu = _action_menu
	action_panel = _action_panel
	action_vbox = _action_vbox
	option_labels = _option_labels
	map_data = _map_data


# =========================
# Updates battle context used
# for menu placement.
# =========================

func sync_context(
	_units: Array,
	_selected_unit: int,
	_pending_move_cell: Vector2i
):
	units = _units
	selected_unit = _selected_unit
	pending_move_cell = _pending_move_cell


# =========================
# Opens the action menu with
# the supplied mode and options.
# =========================

func open_menu(
	new_mode: String,
	new_options: Array,
	start_index := 0
):
	mode = new_mode

	options.clear()

	for option in new_options:
		options.append(str(option))

	index = start_index
	menu_visible = true
	update_menu()


# =========================
# Closes and resets the action
# menu state.
# =========================

func close_menu():

	menu_visible = false
	options.clear()
	index = 0
	mode = ""

	update_menu()


# =========================
# Returns true if the action
# menu is currently open.
# =========================

func is_open() -> bool:

	return menu_visible


# =========================
# Returns the current action
# menu mode.
# =========================

func get_mode() -> String:

	return mode


# =========================
# Returns currently highlighted
# menu option text.
# =========================

func get_selected_option() -> String:

	if options.is_empty():
		return ""

	return options[index]


# =========================
# Handles keyboard navigation
# and confirmation while the
# action menu is open.
# =========================

func handle_input(event):

	if not event is InputEventKey:
		return

	if not event.pressed:
		return

	match event.keycode:

		KEY_UP, KEY_W:
			index -= 1

			if index < 0:
				index = options.size() - 1

		KEY_DOWN, KEY_S:
			index += 1

			if index >= options.size():
				index = 0

		KEY_X, KEY_ESCAPE:
			menu_cancelled.emit()

		KEY_Z:
			confirm_source = "keyboard"
			confirm_selection()

	update_menu()


# =========================
# Emits the currently selected
# action menu option.
# =========================

func confirm_selection():

	if options.is_empty():
		return

	var selected_option = options[index]

	option_confirmed.emit(selected_option)


# =========================
# Returns the menu option index
# currently under the mouse.
# =========================

func get_hovered_index() -> int:

	if not menu_visible:
		return -1

	var mouse_pos = get_viewport().get_mouse_position()

	for i in range(options.size()):

		if i >= option_labels.size():
			continue

		var label = option_labels[i]

		var label_rect = Rect2(
			label.global_position,
			label.size
		)

		if label_rect.has_point(mouse_pos):
			return i

	return -1


# =========================
# Handles mouse clicks while
# the action menu is open.
#
# Returns true when the menu
# consumed the mouse event.
# =========================

func handle_mouse_click(event) -> bool:

	if not menu_visible:
		return false

	if not event is InputEventMouseButton:
		return false

	if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:

		var hovered_index = get_hovered_index()

		if hovered_index != -1:
			index = hovered_index
			confirm_source = "mouse"
			confirm_selection()

		return true

	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		menu_cancelled.emit()
		return true

	return true


# =========================
# Updates highlighted menu
# option based on mouse hover.
# =========================

func update_hovered_index_from_mouse():

	if not menu_visible:
		return

	var hovered_index = get_hovered_index()

	if hovered_index != -1:
		index = hovered_index


# =========================
# Updates menu visibility,
# size, position, and labels.
# =========================

func update_menu():

	if action_menu == null:
		return

	if not menu_visible:
		action_menu.visible = false
		return

	action_menu.visible = true

	var row_height = 32
	var padding_x = 12
	var padding_top = 16
	var padding_bottom = 24

	var widest_text_width = 0

	for option in options:

		var text_width = option.length() * 18

		widest_text_width = max(
			widest_text_width,
			text_width
		)

	var menu_width = max(
		120,
		widest_text_width + padding_x * 2 + 16
	)

	var menu_height = (
		padding_top
		+ padding_bottom
		+ options.size() * row_height
	)

	action_panel.size = Vector2(
		menu_width,
		menu_height
	)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.02, 0.03, 0.12, 0.95)
	panel_style.border_color = Color(0.2, 0.45, 1.0)

	panel_style.border_width_left = 3
	panel_style.border_width_top = 3
	panel_style.border_width_right = 3
	panel_style.border_width_bottom = 3

	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8

	action_panel.add_theme_stylebox_override(
		"panel",
		panel_style
	)

	action_vbox.position = Vector2(
		padding_x,
		padding_top
	)

	action_vbox.size = Vector2(
		menu_width - padding_x * 2,
		menu_height - padding_top - padding_bottom
	)

	var menu_cell = pending_move_cell

	if (
		menu_cell == Vector2i(-1, -1)
		and selected_unit != -1
		and selected_unit < units.size()
	):
		menu_cell = units[selected_unit]["pos"]

	var unit_rect = map_data.grid_rect(menu_cell)

	var menu_pos = (
		unit_rect.position
		+ Vector2(unit_rect.size.x + 8, 0)
	)

	var viewport_size = get_viewport().get_visible_rect().size
	var menu_size = action_panel.size

	if menu_pos.x + menu_size.x > viewport_size.x:
		menu_pos.x = (
			unit_rect.position.x
			- menu_size.x
			- 8
		)

	if menu_pos.y + menu_size.y > viewport_size.y:
		menu_pos.y = (
			viewport_size.y
			- menu_size.y
			- 8
		)

	if menu_pos.y < 8:
		menu_pos.y = 8

	if menu_pos.x < 8:
		menu_pos.x = 8

	action_panel.position = menu_pos

	for label in option_labels:

		label.visible = false
		label.custom_minimum_size = Vector2(
			menu_width - padding_x * 2,
			row_height
		)

	for i in range(options.size()):

		if i >= option_labels.size():
			continue

		var label = option_labels[i]

		label.visible = true

		var option_text = options[i]

		if i == index:

			option_text = "▶ " + option_text

			label.add_theme_color_override(
				"font_color",
				Color(0.45, 0.7, 1.0)
			)

		else:

			option_text = "   " + option_text

			label.add_theme_color_override(
				"font_color",
				Color.WHITE
			)

		label.text = option_text

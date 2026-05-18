extends Node


# ==================================================
# HOVER UNIT PANEL CONTROLLER
# ==================================================
# Handles:
# - hover unit panel visibility
# - HP/stamina bar rendering
# - preview damage display
# - panel styling
# - unit stat label updates
#
# Main remains responsible for:
# - determining WHICH unit
#   should be displayed
# - determining preview damage
# - tactical state logic
#
# Goal:
# Separate tactical UI rendering
# from gameplay orchestration.
# ==================================================


var hover_unit_panel
var hover_unit_name_label

var hover_hp_value_label
var hover_hp_back_bar
var hover_hp_bar
var hover_hp_preview_bar

var hover_stamina_value_label
var hover_stamina_bar

var hover_hp_text_label
var hover_stamina_text_label


# =========================
# Stores references to the
# hover unit panel UI nodes.
# =========================

func setup(
	_panel,
	_name_label,
	_hp_value_label,
	_hp_back_bar,
	_hp_bar,
	_hp_preview_bar,
	_stamina_value_label,
	_stamina_bar,
	_hp_text_label,
	_stamina_text_label
):
	hover_unit_panel = _panel

	hover_unit_name_label = _name_label

	hover_hp_value_label = _hp_value_label
	hover_hp_back_bar = _hp_back_bar
	hover_hp_bar = _hp_bar
	hover_hp_preview_bar = _hp_preview_bar

	hover_stamina_value_label = _stamina_value_label
	hover_stamina_bar = _stamina_bar

	hover_hp_text_label = _hp_text_label
	hover_stamina_text_label = _stamina_text_label


# =========================
# Hides hover unit panel.
# =========================

func hide_panel():

	hover_unit_panel.visible = false


# =========================
# Updates hover unit panel
# visuals for the supplied unit.
#
# Handles:
# - HP bars
# - stamina bars
# - preview damage
# - colors/styling
# - labels
# =========================

func update_panel(
	unit: Dictionary,
	preview_damage: int = 0
):

	if unit.is_empty():
		hide_panel()
		return

	var panel_style = StyleBoxFlat.new()

	panel_style.bg_color = Color(
		0.008,
		0.008,
		0.212,
		1.0
	)

	panel_style.border_width_left = 4
	panel_style.border_width_top = 4
	panel_style.border_width_right = 4
	panel_style.border_width_bottom = 4

	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8

	if unit["team"] == "enemy":

		panel_style.border_color = Color(
			0.9,
			0.2,
			0.2
		)

		panel_style.bg_color = Color(
			0.028,
			0.0,
			0.0,
			0.949
		)

	else:

		panel_style.border_color = Color(
			0.2,
			0.45,
			1.0
		)

		panel_style.bg_color = Color(
			0.02,
			0.03,
			0.12,
			0.95
		)

	hover_unit_panel.add_theme_stylebox_override(
		"panel",
		panel_style
	)

	hover_unit_panel.visible = true

	hover_unit_panel.position = Vector2(16, 16)
	hover_unit_panel.size = Vector2(380, 112)

	hover_hp_text_label.position = Vector2(24, 56)
	hover_hp_text_label.text = "HP"

	hover_stamina_text_label.position = Vector2(24, 78)
	hover_stamina_text_label.text = "STA"

	hover_unit_name_label.position = Vector2(24, 16)

	hover_unit_name_label.text = (
		unit["class"].capitalize()
	)

	var preview_hp = unit["hp"]

	if preview_damage > 0:
		preview_hp = max(
			unit["hp"] - preview_damage,
			0
		)

	hover_hp_value_label.position = Vector2(285, 18)

	hover_hp_value_label.text = (
		str(preview_hp)
		+ "/"
		+ str(unit["max_hp"])
	)

	var hp_bar_pos = Vector2(105, 56)
	var hp_bar_size = Vector2(235, 22)

	var hp_percent = (
		float(preview_hp)
		/ float(unit["max_hp"])
	)

	var hp_fill_width = (
		hp_bar_size.x * hp_percent
	)

	var current_percent = (
		float(unit["hp"])
		/ float(unit["max_hp"])
	)

	var current_fill_width = (
		hp_bar_size.x * current_percent
	)

	hover_hp_back_bar.position = hp_bar_pos
	hover_hp_back_bar.size = hp_bar_size

	hover_hp_back_bar.color = Color(
		0.12,
		0.12,
		0.12,
		1.0
	)

	hover_hp_bar.position = hp_bar_pos

	hover_hp_bar.size = Vector2(
		hp_fill_width,
		hp_bar_size.y
	)

	if unit["team"] == "enemy":
		hover_hp_bar.color = Color(
			0.85,
			0.2,
			0.2
		)
	else:
		hover_hp_bar.color = Color(
			0.2,
			0.85,
			0.2
		)

	var damage_width = (
		current_fill_width
		- hp_fill_width
	)

	if (
		preview_damage > 0
		and damage_width > 0
	):

		hover_hp_preview_bar.visible = true

		hover_hp_preview_bar.position = Vector2(
			hp_bar_pos.x + hp_fill_width,
			hp_bar_pos.y
		)

		hover_hp_preview_bar.size = Vector2(
			damage_width,
			hp_bar_size.y
		)

		hover_hp_preview_bar.color = Color(
			1.0,
			0.9,
			0.0,
			0.95
		)

	else:

		hover_hp_preview_bar.visible = false

	var stamina_bar_pos = Vector2(105, 86)

	var stamina_bar_size = Vector2(
		150,
		12
	)

	var stamina_percent = (
		float(unit["stamina"])
		/ float(unit["max_stamina"])
	)

	var stamina_fill_width = (
		stamina_bar_size.x
		* stamina_percent
	)

	hover_stamina_bar.position = stamina_bar_pos

	hover_stamina_bar.size = Vector2(
		stamina_fill_width,
		stamina_bar_size.y
	)

	hover_stamina_bar.color = Color(
		0.95,
		0.65,
		0.18
	)

	hover_stamina_value_label.position = Vector2(260, 78)

	hover_stamina_value_label.text = (
		str(unit["stamina"])
		+ "/"
		+ str(unit["max_stamina"])
	)

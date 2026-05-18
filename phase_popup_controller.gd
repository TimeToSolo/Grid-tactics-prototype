extends Node


# ==================================================
# PHASE POPUP CONTROLLER
# ==================================================
# Handles:
# - turn transition popups
# - popup styling
# - popup animation/fade timing
# - phase text updates
# - screen dim overlay
#
# Main remains responsible for:
# - determining turn flow
# - determining current team
# - deciding when popups appear
# ==================================================


# =========================
# Phase popup UI references.
#
# Controller now owns its
# own UI node lookups rather
# than receiving them from
# Main during setup.
# =========================

@onready var phase_popup = $"../../CanvasLayer/PhasePopup"

@onready var phase_panel = (
	$"../../CanvasLayer/PhasePopup/PhasePanel"
)

@onready var phase_label = (
	$"../../CanvasLayer/PhasePopup/PhasePanel/PhaseLabel"
)

@onready var phase_dim = (
	$"../../CanvasLayer/PhasePopup/ScreenDim"
)


# =========================
# Initializes popup state.
# =========================

func _ready():

	phase_popup.visible = false


# =========================
# Displays animated center-
# screen phase transition UI.
#
# Supports:
# - Player Phase
# - Enemy Phase
# - custom messages
#
# Handles:
# - popup styling
# - positioning
# - dim overlays
# - fade animation
# =========================

func show_phase_popup(
	current_team: String,
	turn_number: int,
	custom_text: String = ""
):

	var phase_text = custom_text

	if phase_text == "":

		phase_text = "Player Phase"

		if current_team == "enemy":
			phase_text = "Enemy Phase"

	if custom_text != "":

		phase_label.text = phase_text

	else:

		phase_label.text = (
			phase_text
			+ "  |  Turn "
			+ str(turn_number)
		)

	var is_enemy_phase = (
		phase_text == "Enemy Phase"
	)

	var phase_border_color = Color(
		0.2,
		0.45,
		1.0
	)

	var phase_bg_color = Color(
		0.0,
		0.02,
		0.08,
		0.95
	)

	var phase_text_color = Color(
		0.45,
		0.7,
		1.0
	)

	if is_enemy_phase:

		phase_border_color = Color(
			0.9,
			0.2,
			0.2
		)

		phase_bg_color = Color(
			0.03,
			0.0,
			0.0,
			0.95
		)

		phase_text_color = Color(
			1.0,
			0.25,
			0.25
		)

	phase_label.add_theme_color_override(
		"font_color",
		phase_text_color
	)

	var viewport_size = (
		get_viewport()
		.get_visible_rect()
		.size
	)

	var popup_size = Vector2(620, 120)

	phase_popup.position = Vector2.ZERO
	phase_popup.size = viewport_size

	phase_dim.position = Vector2.ZERO
	phase_dim.size = viewport_size

	if custom_text == "Battle Commence":

		phase_dim.visible = true

		phase_dim.color = Color(
			0.0,
			0.0,
			0.0,
			0.35
		)

	else:

		phase_dim.visible = false

	phase_panel.size = popup_size

	phase_panel.position = (
		viewport_size - popup_size
	) / 2.0

	phase_label.size = popup_size
	phase_label.position = Vector2.ZERO

	phase_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	phase_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

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

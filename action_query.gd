extends Node

# ==================================================
# ACTION QUERY
# ==================================================
# Read-only helper functions for deciding which
# click/action phase should be handled.
# ==================================================

# ==================================================
# SHARED ACTION QUERY CONSTANTS
# ==================================================

const INVALID_UNIT := -1

# =========================
# Returns true if this click
# should resolve facing selection.
#
# Facing selection is ignored when:
# - no unit is selected
# - no movement is pending
# - selected unit does not use facing
# - cursor is over an attackable enemy
# =========================

func should_handle_facing_click(
	units: Array,
	selected_unit: int,
	clicked_cell: Vector2i,
	pending_move_cell: Vector2i,
	hovered_cell: Vector2i,
	has_pending_move: bool,
	unit_logic,
	unit_query,
	hover_query,
	map_data
) -> bool:

	if selected_unit == INVALID_UNIT:
		return false

	if not has_pending_move:
		return false

	if (
		units[selected_unit]["class"] == "archer"
		or units[selected_unit]["class"] == "healer"
	):
		return false

	if hover_query.is_hovering_attackable_enemy(
		units,
		selected_unit,
		pending_move_cell,
		hovered_cell,
		has_pending_move,
		unit_logic,
		unit_query,
		map_data
	):
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
		map_data
	)

	return facing_tiles.has(clicked_cell)

# =========================
# Returns true if clicking
# an empty action-range tile
# after moving.
#
# Used by archer/healer to
# allow empty target-range
# clicks to prompt wait.
# =========================

func is_clicking_empty_action_tile(
	units: Array,
	selected_unit: int,
	clicked_cell: Vector2i,
	pending_move_cell: Vector2i,
	has_pending_move: bool,
	unit_logic,
	unit_query,
	map_data
) -> bool:

	if selected_unit == INVALID_UNIT:
		return false

	if not has_pending_move:
		return false

	if unit_query.get_unit_at(
		units,
		clicked_cell
	) != INVALID_UNIT:
		return false

	var unit_class = units[selected_unit]["class"]

	if unit_class == "healer":

		var heal_tiles = unit_logic.get_heal_choice_tiles(
			pending_move_cell,
			map_data
		)

		var adjacent_attack_tiles = unit_logic.get_adjacent_choice_tiles(
			pending_move_cell,
			map_data
		)

		return (
			heal_tiles.has(clicked_cell)
			or adjacent_attack_tiles.has(clicked_cell)
		)

	var attack_tiles = unit_logic.get_attack_choice_tiles(
		pending_move_cell,
		unit_class,
		map_data
	)

	return attack_tiles.has(clicked_cell)

# =========================
# Returns lancer facing
# direction based on selected
# attack tile.
#
# Knight-move attack tiles
# automatically resolve to a
# cardinal facing direction
# using the dominant movement
# axis.
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
# Returns true if this click
# should resolve attack targeting.
#
# Requires:
# - selected unit
# - pending movement
# - hovered enemy is attackable
# =========================

func should_handle_attack_click(
	units: Array,
	selected_unit: int,
	pending_move_cell: Vector2i,
	hovered_cell: Vector2i,
	has_pending_move: bool,
	unit_logic,
	unit_query,
	hover_query,
	map_data
) -> bool:

	if selected_unit == INVALID_UNIT:
		return false

	if not has_pending_move:
		return false

	return hover_query.is_hovering_attackable_enemy(
		units,
		selected_unit,
		pending_move_cell,
		hovered_cell,
		has_pending_move,
		unit_logic,
		unit_query,
		map_data
	)

# =========================
# Returns true if this click
# should resolve healing
# targeting.
#
# Requires:
# - selected healer
# - pending movement
# - hovered ally is healable
# =========================

func should_handle_heal_click(
	units: Array,
	selected_unit: int,
	pending_move_cell: Vector2i,
	hovered_cell: Vector2i,
	has_pending_move: bool,
	unit_logic,
	unit_query,
	hover_query,
	map_data
) -> bool:

	if selected_unit == INVALID_UNIT:
		return false

	if not has_pending_move:
		return false

	if units[selected_unit]["class"] != "healer":
		return false

	return hover_query.is_hovering_healable_ally(
		units,
		selected_unit,
		pending_move_cell,
		hovered_cell,
		has_pending_move,
		unit_logic,
		unit_query,
		map_data
	)

# =========================
# Returns true if this click
# should resolve movement
# selection.
#
# Requires:
# - selected unit
# - clicked tile is reachable
# =========================

func should_handle_move_click(
	selected_unit: int,
	move_tiles: Array[Vector2i],
	clicked_cell: Vector2i
) -> bool:

	if selected_unit == INVALID_UNIT:
		return false

	return move_tiles.has(clicked_cell)

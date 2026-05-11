extends Node

# ==================================================
# SELECTION STATE HELPERS
# ==================================================


# =========================
# Returns true if a destination tile
# is currently pending.
# =========================

func has_pending_move(
	pending_move_cell: Vector2i
) -> bool:

	return pending_move_cell != Vector2i(-1, -1)


# =========================
# Returns true if the selected unit
# used its full movement range.
# =========================

func used_max_movement(
	units: Array,
	selected_unit: int,
	pending_move_cell: Vector2i,
	pending_move_distance: int
) -> bool:

	if selected_unit == -1:
		return false

	if not has_pending_move(pending_move_cell):
		return false

	return pending_move_distance >= units[selected_unit]["move"]

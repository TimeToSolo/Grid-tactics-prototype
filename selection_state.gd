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

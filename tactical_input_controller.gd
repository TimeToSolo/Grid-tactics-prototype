extends Node


# ==================================================
# TACTICAL INPUT CONTROLLER
# ==================================================
# Handles:
# - keyboard tactical input routing
# - mouse tactical input routing
# - cursor movement signals
# - confirm/cancel requests
# - generic gameplay hotkey signals
#
# This controller does NOT:
# - execute gameplay actions
# - modify combat state
# - move units directly
# - end turns directly
#
# Instead, it emits signals
# which Main uses to apply
# gameplay consequences.
# ==================================================


signal keyboard_confirm_requested
signal keyboard_cancel_requested
signal end_turn_requested
signal coverage_cycle_requested
signal tab_cycle_requested
signal cursor_moved(direction: Vector2i)


func handle_keyboard_event(event) -> bool:

	if not event is InputEventKey:
		return false

	if not event.pressed:
		return false

	match event.keycode:

		KEY_UP, KEY_W:
			cursor_moved.emit(Vector2i.UP)
			return true

		KEY_LEFT, KEY_A:
			cursor_moved.emit(Vector2i.LEFT)
			return true

		KEY_DOWN, KEY_S:
			cursor_moved.emit(Vector2i.DOWN)
			return true

		KEY_RIGHT, KEY_D:
			cursor_moved.emit(Vector2i.RIGHT)
			return true

		KEY_Z:
			keyboard_confirm_requested.emit()
			return true

		KEY_X, KEY_ESCAPE:
			keyboard_cancel_requested.emit()
			return true

		KEY_T:
			end_turn_requested.emit()
			return true

		KEY_C:
			coverage_cycle_requested.emit()
			return true

		KEY_TAB:
			tab_cycle_requested.emit()
			return true

	return false

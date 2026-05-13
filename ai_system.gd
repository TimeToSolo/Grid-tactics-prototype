extends Node

# ==================================================
# AI SYSTEM
# ==================================================
# Handles automated turns for non-player teams.
#
# Current supported AI profiles:
# - barbarian:
#   - charges nearest enemy
#   - attacks if possible
#   - ignores coverage danger
#
# Future profiles:
# - chokepoint_holder
# - disciplined
# - cautious_ranged
# - support
# - objective_guard
# ==================================================


func take_team_turn(
	units: Array,
	team: String,
	map_data,
	unit_query,
	unit_logic,
	movement_system,
	action_system,
	combat_logic,
	coverage_system,
	stamina_system
):

	var unit_ids: Array[int] = []

	for unit in units:
		if unit["team"] == team and not unit["has_acted"]:
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

		take_unit_turn(
			units,
			unit_index,
			map_data,
			unit_query,
			unit_logic,
			movement_system,
			action_system,
			combat_logic,
			coverage_system,
			stamina_system
		)

# =========================
# Processes one AI unit's turn
# by dispatching to that unit's
# assigned AI profile.
#
# Team controls allegiance.
# AI profile controls behavior.
# =========================

func take_unit_turn(
	units: Array,
	unit_index: int,
	map_data,
	unit_query,
	unit_logic,
	movement_system,
	action_system,
	combat_logic,
	coverage_system,
	stamina_system
):

	var ai_profile = "barbarian"

	if units[unit_index].has("ai_profile"):
		ai_profile = units[unit_index]["ai_profile"]

	match ai_profile:

		"barbarian":
			process_barbarian_turn(
				units,
				unit_index,
				map_data,
				unit_query,
				unit_logic,
				movement_system,
				action_system,
				combat_logic,
				coverage_system,
				stamina_system
			)

		_:
			process_barbarian_turn(
				units,
				unit_index,
				map_data,
				unit_query,
				unit_logic,
				movement_system,
				action_system,
				combat_logic,
				coverage_system,
				stamina_system
			)

# =========================
# Processes one barbarian AI turn.
#
# Barbarian behavior:
# - finds nearest enemy
# - attacks immediately if already in range
# - otherwise charges toward nearest enemy
# - attacks after moving if possible
# - faces nearest enemy if no attack is available
# - ignores coverage danger
# - does not evaluate overlap
# =========================

func process_barbarian_turn(
	units: Array,
	unit_index: int,
	map_data,
	unit_query,
	unit_logic,
	_movement_system,
	_action_system,
	combat_logic,
	_coverage_system,
	stamina_system
):

	var target_index = get_nearest_enemy(
		units,
		unit_index,
		map_data
	)

	if target_index == -1:
		units[unit_index]["has_acted"] = true
		return

	if try_attack_target(
		units,
		unit_index,
		target_index,
		map_data,
		unit_logic,
		unit_query,
		combat_logic,
		stamina_system
	):
		return

	var start_pos = units[unit_index]["pos"]

	var destination = get_best_move_toward_target(
		units,
		unit_index,
		target_index,
		map_data,
		unit_query
	)

	var move_direction = Vector2i(
		sign(destination.x - start_pos.x),
		sign(destination.y - start_pos.y)
	)

	var move_distance = map_data.get_grid_distance(
		start_pos,
		destination
	)

	var used_max_movement = (
		move_distance >= units[unit_index]["move"]
	)

	units[unit_index]["pos"] = destination

	target_index = get_nearest_enemy(
		units,
		unit_index,
		map_data
	)

	if target_index != -1:

		if try_attack_target(
			units,
			unit_index,
			target_index,
			map_data,
			unit_logic,
			unit_query,
			combat_logic,
			stamina_system
		):
			return

	target_index = get_nearest_enemy(
		units,
		unit_index,
		map_data
	)

	if target_index != -1:

		face_target(
			units,
			unit_index,
			target_index,
			unit_logic,
			move_direction,
			used_max_movement
		)

	units[unit_index]["has_acted"] = true

# =========================
# Attempts to attack a target unit.
#
# Returns:
# - true if an attack was performed
# - false if target is not in range
# =========================

func try_attack_target(
	units: Array,
	attacker_index: int,
	target_index: int,
	map_data,
	unit_logic,
	unit_query,
	combat_logic,
	stamina_system
) -> bool:

	if attacker_index == -1:
		return false

	if target_index == -1:
		return false

	var attacker = units[attacker_index]
	var target = units[target_index]

	var attack_tiles: Array[Vector2i] = []

	if attacker["class"] == "healer":

		attack_tiles = unit_logic.get_adjacent_choice_tiles(
			attacker["pos"],
			map_data
		)

	else:

		attack_tiles = unit_logic.get_attack_choice_tiles(
			attacker["pos"],
			attacker["class"],
			map_data
		)

	if not attack_tiles.has(target["pos"]):
		return false

	var attack_direction = target["pos"] - attacker["pos"]

	attack_direction = Vector2i(
		sign(attack_direction.x),
		sign(attack_direction.y)
	)

	attacker["facing"] = attack_direction

	var target_died = combat_logic.resolve_attack(
		attacker,
		target
	)

	stamina_system.spend_attack_stamina(
		units,
		attacker_index
	)

	attacker["has_acted"] = true

	if target_died:
		units.remove_at(target_index)

	return true

# =========================
# Returns the nearest enemy unit index
# relative to the given unit.
#
# Distance uses grid distance only.
#
# Returns:
# - enemy unit index
# - or -1 if no enemies exist
# =========================

func get_nearest_enemy(
	units: Array,
	unit_index: int,
	map_data
) -> int:

	var best_index = -1
	var best_distance = 999999

	var unit_team = units[unit_index]["team"]
	var unit_pos = units[unit_index]["pos"]

	for i in range(units.size()):

		if i == unit_index:
			continue

		if units[i]["team"] == unit_team:
			continue

		var distance = map_data.get_grid_distance(
			unit_pos,
			units[i]["pos"]
		)

		if distance < best_distance:
			best_distance = distance
			best_index = i

	return best_index

# =========================
# Returns the best reachable tile
# for moving toward a target.
#
# Primary goal:
# - minimize distance to target
#
# Tie-breaker:
# - prefer movement that matches the
#   target direction ratio
#
# Returns:
# - selected destination tile
# =========================

func get_best_move_toward_target(
	units: Array,
	unit_index: int,
	target_index: int,
	map_data,
	unit_query
) -> Vector2i:

	var unit = units[unit_index]
	var target = units[target_index]

	var move_tiles = map_data.get_move_range(
		unit["pos"],
		unit["move"],
		unit_query.get_all_occupied_tiles_except_unit(
			units,
			unit_index
		)
	)

	var best_tile = unit["pos"]
	var best_distance = map_data.get_grid_distance(
		unit["pos"],
		target["pos"]
	)
	var best_alignment_score = 999999

	var total_dx = abs(target["pos"].x - unit["pos"].x)
	var total_dy = abs(target["pos"].y - unit["pos"].y)

	for tile in move_tiles:

		var distance = map_data.get_grid_distance(
			tile,
			target["pos"]
		)

		var moved_dx = abs(tile.x - unit["pos"].x)
		var moved_dy = abs(tile.y - unit["pos"].y)

		var alignment_score = abs(
			(moved_dx * total_dy)
			- (moved_dy * total_dx)
		)

		if (
			distance < best_distance
			or (
				distance == best_distance
				and alignment_score < best_alignment_score
			)
		):
			best_distance = distance
			best_alignment_score = alignment_score
			best_tile = tile

	return best_tile

# =========================
# Faces a unit toward a target unit.
#
# Respects movement-based facing limits.
#
# Used when an AI unit waits after moving
# without attacking, so its coverage points
# toward the nearest enemy.
# =========================

func face_target(
	units: Array,
	unit_index: int,
	target_index: int,
	unit_logic,
	move_direction: Vector2i,
	used_max_movement: bool
):

	if unit_index == -1:
		return

	if target_index == -1:
		return

	if unit_index >= units.size():
		return

	if target_index >= units.size():
		return

	var desired_direction = (
		units[target_index]["pos"]
		- units[unit_index]["pos"]
	)

	desired_direction = Vector2i(
		sign(desired_direction.x),
		sign(desired_direction.y)
	)

	var allowed_dirs: Array[Vector2i]

	if used_max_movement:

		allowed_dirs = unit_logic.get_limited_facing_dirs(
			move_direction
		)

	else:

		allowed_dirs = unit_logic.get_all_facing_dirs()

	if allowed_dirs.has(desired_direction):

		units[unit_index]["facing"] = desired_direction
		return

	units[unit_index]["facing"] = allowed_dirs[0]

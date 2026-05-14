extends Node

@onready var unit_query = $"../../Queries/UnitQuery"

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
				unit_logic,
				movement_system,
				action_system,
				combat_logic,
				coverage_system,
				stamina_system
			)

		"cautious_ranged":
			process_cautious_ranged_turn(
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

		"defender":
			process_defender_turn(
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

		"support_healer":
			process_support_healer_turn(
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

		_:
			process_barbarian_turn(
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

# =========================
# Returns expected archer damage
# after moving a given distance.
#
# Archer damage is reduced by a
# flat penalty per tile moved.
# =========================

func get_archer_expected_damage_after_move(
	unit,
	move_distance: int
) -> int:

	var move_damage_penalty = 2

	if unit.has("move_damage_penalty"):
		move_damage_penalty = unit["move_damage_penalty"]

	return max(
		unit["attack"] - move_distance * move_damage_penalty,
		1
	)

# =========================
# Returns preferred retreat distance
# for cautious archer behavior.
#
# The archer retreats as much as possible
# while still preserving lethal damage.
#
# Returns:
# - 2 if retreating 2 still kills
# - 1 if retreating 1 still kills
# - 0 if standing still is needed to kill
# - 2 if no lethal shot is available
# =========================

func get_archer_desired_retreat_distance(
	archer,
	target
) -> int:

	for retreat_distance in [2, 1, 0]:

		var expected_damage = get_archer_expected_damage_after_move(
			archer,
			retreat_distance
		)

		if target["hp"] <= expected_damage:
			return retreat_distance

	return 2

# =========================
# Returns true if a unit can attack
# a target from a specific cell.
#
# Used by AI to evaluate movement
# before actually changing position.
# =========================

func can_attack_target_from_cell(
	units: Array,
	attacker_index: int,
	target_index: int,
	test_cell: Vector2i,
	map_data,
	unit_logic
) -> bool:

	if attacker_index == -1:
		return false

	if target_index == -1:
		return false

	if attacker_index >= units.size():
		return false

	if target_index >= units.size():
		return false

	var attacker = units[attacker_index]
	var target = units[target_index]

	var attack_tiles: Array[Vector2i] = []

	if attacker["class"] == "healer":

		attack_tiles = unit_logic.get_adjacent_choice_tiles(
			test_cell,
			map_data
		)

	else:

		attack_tiles = unit_logic.get_attack_choice_tiles(
			test_cell,
			attacker["class"],
			map_data
		)

	return attack_tiles.has(target["pos"])
	
# =========================
# Returns the best retreat tile for
# cautious ranged behavior.
#
# Retreat priority:
# - move along the strongest axis away
#   from the target
# - only move up to desired retreat distance
# - preserve attack range / line of sight
#
# This avoids max-range diagonal kiting.
# =========================

func get_best_archer_retreat_tile(
	units: Array,
	archer_index: int,
	target_index: int,
	desired_retreat_distance: int,
	map_data,
	unit_logic
) -> Vector2i:

	var archer = units[archer_index]
	var target = units[target_index]

	var current_distance = map_data.get_grid_distance(
		archer["pos"],
		target["pos"]
	)

	var ideal_distance = 4

	if current_distance >= ideal_distance:
		return archer["pos"]

	var diff = archer["pos"] - target["pos"]

	var retreat_step = Vector2i.ZERO

	if abs(diff.x) >= abs(diff.y):
		retreat_step = Vector2i(sign(diff.x), 0)
	else:
		retreat_step = Vector2i(0, sign(diff.y))

	var occupied_tiles = unit_query.get_all_occupied_tiles_except_unit(
		units,
		archer_index
	)

	for distance in range(desired_retreat_distance, -1, -1):

		var test_tile = archer["pos"] + retreat_step * distance

		if not map_data.is_inside_grid(test_tile):
			continue

		if map_data.blocks_movement(test_tile):
			continue

		if occupied_tiles.has(test_tile):
			continue

		if not can_attack_target_from_cell(
			units,
			archer_index,
			target_index,
			test_tile,
			map_data,
			unit_logic
		):
			continue

		return test_tile

	return archer["pos"]
	
# =========================
# Processes one cautious ranged AI turn.
#
# Cautious ranged behavior:
# - targets the nearest enemy
# - approaches until it can shoot
# - if already able to shoot, retreats slightly
# - retreats as much as possible while
#   preserving lethal damage
# - shoots after repositioning if possible
# =========================

func process_cautious_ranged_turn(
	units: Array,
	unit_index: int,
	map_data,
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

	var can_attack_now = can_attack_target_from_cell(
		units,
		unit_index,
		target_index,
		units[unit_index]["pos"],
		map_data,
		unit_logic
	)

	var start_pos = units[unit_index]["pos"]
	var destination = start_pos

	if can_attack_now:

		var desired_retreat_distance = get_archer_desired_retreat_distance(
			units[unit_index],
			units[target_index]
		)

		destination = get_best_archer_retreat_tile(
			units,
			unit_index,
			target_index,
			desired_retreat_distance,
			map_data,
			unit_logic
		)

	else:

		destination = get_best_archer_approach_tile(
			units,
			unit_index,
			target_index,
			map_data,
			unit_logic
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
	stamina_system.spend_movement_stamina(
		units,
		unit_index,
		move_distance
	)

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
			combat_logic,
			stamina_system
		):
			return

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
# Returns the best reachable tile
# where an archer can attack its target.
#
# Used when cautious ranged AI is not
# currently in attack range.
#
# The archer approaches only far enough
# to gain a valid shot instead of moving
# directly into melee.
#
# Returns:
# - best firing tile
# - or fallback movement tile if no shot is available
# =========================

func get_best_archer_approach_tile(
	units: Array,
	archer_index: int,
	target_index: int,
	map_data,
	unit_logic
) -> Vector2i:

	var archer = units[archer_index]

	var move_tiles = map_data.get_move_range(
		archer["pos"],
		archer["move"],
		unit_query.get_all_occupied_tiles_except_unit(
			units,
			archer_index
		)
	)

	var best_tile = archer["pos"]
	var best_move_distance = 999999
	var found_attack_tile = false

	for tile in move_tiles:

		if not can_attack_target_from_cell(
			units,
			archer_index,
			target_index,
			tile,
			map_data,
			unit_logic
		):
			continue

		var move_distance = map_data.get_grid_distance(
			archer["pos"],
			tile
		)

		if (
			not found_attack_tile
			or move_distance < best_move_distance
		):
			found_attack_tile = true
			best_move_distance = move_distance
			best_tile = tile

	if found_attack_tile:
		return best_tile

	return get_best_move_toward_target(
		units,
		archer_index,
		target_index,
		map_data
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
		combat_logic,
		stamina_system
	):
		return

	var start_pos = units[unit_index]["pos"]

	var destination = get_best_move_toward_target(
		units,
		unit_index,
		target_index,
		map_data
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
	stamina_system.spend_movement_stamina(
		units,
		unit_index,
		move_distance
	)

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
# Returns the nearest enemy
# that is currently inside
# the defender's leash area.
#
# Unlike normal nearest-enemy logic,
# this ignores enemies outside the
# defender's assigned territory.
#
# Used by defender AI so units:
# - guard territory
# - disengage when enemies leave
# - return home instead of chasing
#
# Returns:
# - enemy unit index
# - or -1 if no valid enemy exists
# =========================

func get_nearest_enemy_inside_defender_leash(
	units: Array,
	unit_index: int,
	map_data
) -> int:

	var unit = units[unit_index]

	var best_index = -1
	var best_distance = 999999

	for i in range(units.size()):

		if i == unit_index:
			continue

		if units[i]["team"] == unit["team"]:
			continue

		# Ignore enemies outside territory
		if not is_tile_inside_defender_leash(
			unit,
			units[i]["pos"],
			map_data
		):
			continue

		var distance = map_data.get_grid_distance(
			unit["pos"],
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
	map_data
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

# =========================
# Processes one defender AI turn.
#
# Defender behavior:
# - remembers a home position
# - remembers original facing
# - stays within leash range of home
# - attacks enemies already in range
# - moves only inside its leash area
# - returns home when no enemies exist
# - faces original direction when home
#
# Design goal:
# Defender AI should hold territory
# instead of chasing endlessly.
# =========================

func process_defender_turn(
	units: Array,
	unit_index: int,
	map_data,
	unit_logic,
	_movement_system,
	_action_system,
	combat_logic,
	_coverage_system,
	stamina_system
):

	ensure_defender_home_data(
		units,
		unit_index
	)

	var target_index = get_nearest_enemy_inside_defender_leash(
		units,
		unit_index,
		map_data
	)

	# =========================
	# No enemy found.
	# Return to home position.
	# =========================

	if target_index == -1:

		if units[unit_index]["pos"] != units[unit_index]["home_pos"]:

			var return_tile = get_best_return_home_tile(
				units,
				unit_index,
				map_data
			)

			var return_distance = map_data.get_grid_distance(
				units[unit_index]["pos"],
				return_tile
			)

			units[unit_index]["pos"] = return_tile

			stamina_system.spend_movement_stamina(
				units,
				unit_index,
				return_distance
			)

		else:

			if units[unit_index].has("home_facing"):
				units[unit_index]["facing"] = units[unit_index]["home_facing"]

		units[unit_index]["has_acted"] = true
		return

	if try_attack_target(
		units,
		unit_index,
		target_index,
		map_data,
		unit_logic,
		combat_logic,
		stamina_system
	):
		return

	var start_pos = units[unit_index]["pos"]

	var destination = get_best_defender_tile(
		units,
		unit_index,
		target_index,
		map_data,
		unit_logic
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

	stamina_system.spend_movement_stamina(
		units,
		unit_index,
		move_distance
	)

	target_index = get_nearest_enemy_inside_defender_leash(
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
			combat_logic,
			stamina_system
		):
			return

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
# Finds the best tile for a
# defender to move toward home.
#
# Used when no enemies are found.
# =========================

func get_best_return_home_tile(
	units: Array,
	unit_index: int,
	map_data
) -> Vector2i:

	var unit = units[unit_index]

	var occupied_tiles = unit_query.get_all_occupied_tiles_except_unit(
		units,
		unit_index
	)

	var move_tiles = map_data.get_move_range(
		unit["pos"],
		unit["move"],
		occupied_tiles
	)

	var best_tile = unit["pos"]
	var best_distance = map_data.get_grid_distance(
		unit["pos"],
		unit["home_pos"]
	)

	for tile in move_tiles:

		var distance = map_data.get_grid_distance(
			tile,
			unit["home_pos"]
		)

		if distance < best_distance:
			best_distance = distance
			best_tile = tile

	return best_tile

# =========================
# Ensures defender units have
# required home/leash data.
#
# If no home position exists,
# the unit's current position
# becomes its home position.
#
# If no leash range exists,
# a default value is assigned.
# =========================

func ensure_defender_home_data(
	units: Array,
	unit_index: int
):

	if not units[unit_index].has("home_pos"):
		units[unit_index]["home_pos"] = units[unit_index]["pos"]

	if not units[unit_index].has("leash_range"):
		units[unit_index]["leash_range"] = 3

	if not units[unit_index].has("home_facing"):
		units[unit_index]["home_facing"] = units[unit_index]["facing"]


# =========================
# Returns true if a tile is
# inside the defender's leash.
#
# The leash is measured from
# the unit's home position.
# =========================

func is_tile_inside_defender_leash(
	unit,
	tile: Vector2i,
	map_data
) -> bool:

	var distance_from_home = map_data.get_grid_distance(
		unit["home_pos"],
		tile
	)

	return distance_from_home <= unit["leash_range"]


# =========================
# Returns the best reachable tile
# for a defender.
#
# Priority:
# 1. stay inside leash range
# 2. prefer tiles that can attack target
# 3. otherwise move closer to target
# 4. never leave assigned territory
# =========================

func get_best_defender_tile(
	units: Array,
	unit_index: int,
	target_index: int,
	map_data,
	unit_logic
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
	var best_score = 999999

	for tile in move_tiles:

		if not is_tile_inside_defender_leash(
			unit,
			tile,
			map_data
		):
			continue

		var score = 0

		var distance_to_target = map_data.get_grid_distance(
			tile,
			target["pos"]
		)

		score += distance_to_target * 10

		if can_attack_target_from_cell(
			units,
			unit_index,
			target_index,
			tile,
			map_data,
			unit_logic
		):
			score -= 100

		var distance_from_home = map_data.get_grid_distance(
			unit["home_pos"],
			tile
		)

		score += distance_from_home

		if score < best_score:
			best_score = score
			best_tile = tile

	return best_tile

# =========================
# Processes one support healer AI turn.
#
# Support healer behavior:
# - heals the most wounded nearby ally
# - moves toward wounded allies if needed
# - attacks only if no healing is useful
# - waits if nothing useful can be done
# =========================

func process_support_healer_turn(
	units: Array,
	unit_index: int,
	map_data,
	unit_logic,
	_movement_system,
	_action_system,
	combat_logic,
	_coverage_system,
	stamina_system
):

	var heal_target_index = get_best_heal_target(
		units,
		unit_index,
		map_data
	)

	if heal_target_index != -1:

		if try_heal_target(
			units,
			unit_index,
			heal_target_index,
			map_data,
			unit_logic,
			combat_logic,
			stamina_system
		):
			return

		var start_pos = units[unit_index]["pos"]

		var destination = get_best_healer_approach_tile(
			units,
			unit_index,
			heal_target_index,
			map_data,
			unit_logic
		)

		var move_distance = map_data.get_grid_distance(
			start_pos,
			destination
		)

		units[unit_index]["pos"] = destination

		stamina_system.spend_movement_stamina(
			units,
			unit_index,
			move_distance
		)

		heal_target_index = get_best_heal_target(
			units,
			unit_index,
			map_data
		)

		if heal_target_index != -1:

			if try_heal_target(
				units,
				unit_index,
				heal_target_index,
				map_data,
				unit_logic,
				combat_logic,
				stamina_system
			):
				return

		units[unit_index]["has_acted"] = true
		return

	# No useful healing available.
	# Fall back to adjacent attack if possible.

	var enemy_index = get_nearest_enemy(
		units,
		unit_index,
		map_data
	)

	if enemy_index != -1:

		if try_attack_target(
			units,
			unit_index,
			enemy_index,
			map_data,
			unit_logic,
			combat_logic,
			stamina_system
		):
			return

	units[unit_index]["has_acted"] = true


# =========================
# Returns the best wounded ally
# for a healer to prioritize.
#
# Priority:
# 1. lowest HP percentage
# 2. largest missing HP
# 3. closest distance
# =========================

func get_best_heal_target(
	units: Array,
	healer_index: int,
	map_data
) -> int:

	var healer = units[healer_index]

	if healer.has("heal_charges"):
		if healer["heal_charges"] <= 0:
			return -1

	var best_index = -1
	var best_score = 999999

	for i in range(units.size()):

		if i == healer_index:
			continue

		if units[i]["team"] != healer["team"]:
			continue

		if not units[i].has("max_hp"):
			continue

		if units[i]["hp"] >= units[i]["max_hp"]:
			continue

		var missing_hp = units[i]["max_hp"] - units[i]["hp"]

		var hp_percent_score = int(
			float(units[i]["hp"]) / float(units[i]["max_hp"]) * 100.0
		)

		var distance = map_data.get_grid_distance(
			healer["pos"],
			units[i]["pos"]
		)

		var score = 0
		score += hp_percent_score * 10
		score -= missing_hp * 2
		score += distance

		if score < best_score:
			best_score = score
			best_index = i

	return best_index


# =========================
# Attempts to heal a target ally.
#
# Returns:
# - true if healing was performed
# - false if target is not adjacent
# =========================

func try_heal_target(
	units: Array,
	healer_index: int,
	target_index: int,
	map_data,
	unit_logic,
	combat_logic,
	stamina_system
) -> bool:

	if healer_index == -1:
		return false

	if target_index == -1:
		return false

	if healer_index >= units.size():
		return false

	if target_index >= units.size():
		return false

	var healer = units[healer_index]
	var target = units[target_index]

	if healer.has("heal_charges"):
		if healer["heal_charges"] <= 0:
			return false

	if target["hp"] >= target["max_hp"]:
		return false

	var heal_tiles = unit_logic.get_adjacent_choice_tiles(
		healer["pos"],
		map_data
	)

	if not heal_tiles.has(target["pos"]):
		return false

	var heal_direction = target["pos"] - healer["pos"]

	healer["facing"] = Vector2i(
		sign(heal_direction.x),
		sign(heal_direction.y)
	)

	combat_logic.apply_heal(
		target,
		healer["heal_amount"]
	)

	if healer.has("heal_charges"):
		healer["heal_charges"] -= 1

	healer["stamina"] = max(
		healer["stamina"] - healer["heal_stamina_cost"],
		0
	)

	healer["has_acted"] = true

	return true


# =========================
# Returns true if a healer can heal
# a target ally from a test cell.
# =========================

func can_heal_target_from_cell(
	units: Array,
	healer_index: int,
	target_index: int,
	test_cell: Vector2i,
	map_data,
	unit_logic
) -> bool:

	if healer_index == -1:
		return false

	if target_index == -1:
		return false

	if healer_index >= units.size():
		return false

	if target_index >= units.size():
		return false

	var target = units[target_index]

	if target["hp"] >= target["max_hp"]:
		return false

	var heal_tiles = unit_logic.get_adjacent_choice_tiles(
		test_cell,
		map_data
	)

	return heal_tiles.has(target["pos"])


# =========================
# Returns the best reachable tile
# for moving toward a wounded ally.
#
# Priority:
# 1. move to a tile that can heal
# 2. use the shortest movement needed
# 3. otherwise move closer
# =========================

func get_best_healer_approach_tile(
	units: Array,
	healer_index: int,
	target_index: int,
	map_data,
	unit_logic
) -> Vector2i:

	var healer = units[healer_index]
	var target = units[target_index]

	var move_tiles = map_data.get_move_range(
		healer["pos"],
		healer["move"],
		unit_query.get_all_occupied_tiles_except_unit(
			units,
			healer_index
		)
	)

	var best_tile = healer["pos"]
	var best_score = 999999

	for tile in move_tiles:

		var score = 0

		var distance_to_target = map_data.get_grid_distance(
			tile,
			target["pos"]
		)

		score += distance_to_target * 10

		if can_heal_target_from_cell(
			units,
			healer_index,
			target_index,
			tile,
			map_data,
			unit_logic
		):
			score -= 1000

		var move_distance = map_data.get_grid_distance(
			healer["pos"],
			tile
		)

		score += move_distance

		if score < best_score:
			best_score = score
			best_tile = tile

	return best_tile

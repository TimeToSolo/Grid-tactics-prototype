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
) -> Array:

	var action_results: Array = []
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

		var action_result = take_unit_turn(
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

		if action_result != null:
			action_results.append(action_result)

	return action_results

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
			return process_barbarian_turn(
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
			return process_cautious_ranged_turn(
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
			return process_defender_turn(
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
			return process_support_healer_turn(
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
			return process_barbarian_turn(
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
	move_distance: int,
	combat_logic
) -> int:

	var simulated_unit = unit.duplicate()

	simulated_unit["stamina"] = max(
		simulated_unit["max_stamina"]
		- (
			move_distance
			* simulated_unit["move_stamina_cost"]
		),
		0
	)

	return combat_logic.get_attack_damage(simulated_unit)

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
	target,
	combat_logic
) -> int:

	for retreat_distance in [2, 1, 0]:

		var expected_damage = get_archer_expected_damage_after_move(
			archer,
			retreat_distance,
			combat_logic
		)

		if target["hp"] <= expected_damage:
			return retreat_distance

	return 2

# =========================
# Returns attack tiles for AI evaluation.
#
# Healers use adjacent attacks.
# Other classes use normal attack ranges.
# =========================

func get_ai_attack_tiles(
	unit,
	from_cell: Vector2i,
	unit_logic,
	map_data
) -> Array[Vector2i]:

	if unit["class"] == "healer":
		return unit_logic.get_adjacent_choice_tiles(
			from_cell,
			map_data
		)

	return unit_logic.get_attack_choice_tiles(
		from_cell,
		unit["class"],
		map_data
	)

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

	var attack_tiles = get_ai_attack_tiles(
		attacker,
		test_cell,
		unit_logic,
		map_data
	)

	return attack_tiles.has(target["pos"])

# =========================
# Moves an AI unit using real
# path data and resolves coverage.
#
# Returns action result data:
# - died: true if moving unit died
# - moved: true if movement occurred
# - path_cells: actual movement path
# =========================

func move_ai_unit(
	units: Array,
	unit_index: int,
	destination: Vector2i,
	map_data,
	unit_logic,
	coverage_system,
	combat_logic,
	stamina_system
) -> Dictionary:

	if unit_index == -1:
		return {
			"died": false,
			"path_cells": [],
			"moved": false
		}

	if unit_index >= units.size():
		return {
			"died": false,
			"path_cells": [],
			"moved": false
		}

	var start_pos = units[unit_index]["pos"]

	if start_pos == destination:
		return {
			"died": false,
			"path_cells": [],
			"moved": false
		}

	var path_data = map_data.get_movement_path_data(
		start_pos,
		destination,
		units[unit_index]["move"],
		unit_query.get_all_occupied_tiles_except_unit(
			units,
			unit_index
		)
	)

	if path_data.is_empty():
		return {
			"died": false,
			"path_cells": [],
			"moved": false
		}

	var path_cells: Array[Vector2i] = path_data["path_cells"]
	var move_distance: int = path_data["cost"]

	var pending_coverage_enemies = (
		coverage_system.get_enemies_entered_coverage_along_path(
			units,
			unit_logic,
			unit_index,
			path_cells
		)
	)

	units[unit_index]["pos"] = destination

	if coverage_system.resolve_pending_coverage_if_needed(
		units,
		combat_logic,
		unit_index,
		pending_coverage_enemies
	):
		return {
			"died": true,
			"path_cells": path_cells,
			"moved": true
		}

	stamina_system.spend_movement_stamina(
		units,
		unit_index,
		move_distance
	)

	return {
		"died": false,
		"path_cells": path_cells,
		"moved": true
	}

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
	coverage_system,
	stamina_system
):

	var target_index = get_nearest_enemy(
		units,
		unit_index,
		map_data
	)

	if target_index == -1:
		units[unit_index]["has_acted"] = true

		return {
			"moved": false,
			"path_cells": [],
			"unit_died": false,
			"attacked": false
		}

	var can_attack_now = can_attack_target_from_cell(
		units,
		unit_index,
		target_index,
		units[unit_index]["pos"],
		map_data,
		unit_logic
	)

	var destination = units[unit_index]["pos"]

	if can_attack_now:

		var desired_retreat_distance = get_archer_desired_retreat_distance(
			units[unit_index],
			units[target_index],
			combat_logic
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

	var move_result = move_ai_unit(
		units,
		unit_index,
		destination,
		map_data,
		unit_logic,
		coverage_system,
		combat_logic,
		stamina_system
	)

	if move_result["died"]:
		units.remove_at(unit_index)

		return {
			"moved": move_result["moved"],
			"path_cells": move_result["path_cells"],
			"unit_died": true,
			"attacked": false
		}

	target_index = get_nearest_enemy(
		units,
		unit_index,
		map_data
	)

	if target_index != -1:

		var attack_result = try_attack_target(
			units,
			unit_index,
			target_index,
			map_data,
			unit_logic,
			combat_logic,
			stamina_system
		)

		if attack_result["attacked"]:
			return {
				"moved": move_result["moved"],
				"path_cells": move_result["path_cells"],
				"unit_died": false,
				"attacked": true,
				"attacker_index": attack_result["attacker_index"],
				"target_index": attack_result["target_index"],
				"target_died": attack_result["target_died"],
				"damage": attack_result["damage"]
			}

	units[unit_index]["has_acted"] = true

	return {
		"moved": move_result["moved"],
		"path_cells": move_result["path_cells"],
		"unit_died": false,
		"attacked": false
	}

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
# Returns the broader future
# movement direction toward
# a target unit.
#
# Used by AI after movement
# when no attack occurred.
#
# This calculates a fresh path
# from the unit's CURRENT
# position toward the target,
# then faces toward the
# general route ahead.
#
# Unlike movement-facing,
# this reflects where the unit
# intends to continue moving
# on future turns.
# =========================

func get_future_path_facing(
	units: Array,
	unit_index: int,
	target_index: int,
	map_data
) -> Vector2i:

	if unit_index == -1 or target_index == -1:
		return Vector2i.ZERO

	if unit_index >= units.size() or target_index >= units.size():
		return Vector2i.ZERO

	var occupied_tiles = unit_query.get_enemy_occupied_tiles(
		units,
		unit_index
	)

	var path_data = map_data.get_path_to_nearest_adjacent_tile(
		units[unit_index]["pos"],
		units[target_index]["pos"],
		occupied_tiles
	)

	if path_data.is_empty():
		return Vector2i.ZERO

	var path_cells = path_data["path_cells"]

	if path_cells.size() < 2:
		return Vector2i.ZERO

	var lookahead_index = min(
		path_cells.size() - 1,
		3
	)

	var direction = path_cells[lookahead_index] - path_cells[0]

	return Vector2i(
		sign(direction.x),
		sign(direction.y)
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
	coverage_system,
	stamina_system
):

	var target_index = get_nearest_enemy(
		units,
		unit_index,
		map_data
	)

	if target_index == -1:
		units[unit_index]["has_acted"] = true

		return {
			"moved": false,
			"path_cells": [],
			"unit_died": false,
			"attacked": false
		}

	var attack_result = try_attack_target(
		units,
		unit_index,
		target_index,
		map_data,
		unit_logic,
		combat_logic,
		stamina_system
	)

	if attack_result["attacked"]:
		return {
			"moved": false,
			"path_cells": [],
			"unit_died": false,
			"attacked": true,
			"attacker_index": attack_result["attacker_index"],
			"target_index": attack_result["target_index"],
			"target_died": attack_result["target_died"],
			"damage": attack_result["damage"]
		}

	var destination = get_best_move_toward_target(
		units,
		unit_index,
		target_index,
		map_data
	)

	var move_result = move_ai_unit(
		units,
		unit_index,
		destination,
		map_data,
		unit_logic,
		coverage_system,
		combat_logic,
		stamina_system
	)

	if move_result["died"]:
		units.remove_at(unit_index)

		return {
			"moved": move_result["moved"],
			"path_cells": move_result["path_cells"],
			"unit_died": true,
			"attacked": false
		}

	target_index = get_nearest_enemy(
		units,
		unit_index,
		map_data
	)

	if target_index != -1:

		attack_result = try_attack_target(
			units,
			unit_index,
			target_index,
			map_data,
			unit_logic,
			combat_logic,
			stamina_system
		)

		if attack_result["attacked"]:
			return {
				"moved": move_result["moved"],
				"path_cells": move_result["path_cells"],
				"unit_died": false,
				"attacked": true,
				"attacker_index": attack_result["attacker_index"],
				"target_index": attack_result["target_index"],
				"target_died": attack_result["target_died"],
				"damage": attack_result["damage"]
			}

	target_index = get_nearest_enemy(
		units,
		unit_index,
		map_data
	)

	var future_facing = get_future_path_facing(
		units,
		unit_index,
		target_index,
		map_data
	)

	if future_facing != Vector2i.ZERO:
		units[unit_index]["facing"] = future_facing

	units[unit_index]["has_acted"] = true

	return {
		"moved": move_result["moved"],
		"path_cells": move_result["path_cells"],
		"unit_died": false,
		"attacked": false
	}

# =========================
# Attempts to attack a target unit.
#
# Returns action result data:
# - attacked: true if attack occurred
# - attacker_index
# - target_index
# - target_died
# =========================

func try_attack_target(
	units: Array,
	attacker_index: int,
	target_index: int,
	map_data,
	unit_logic,
	combat_logic,
	stamina_system
) -> Dictionary:

	if attacker_index == -1:
		return {
			"attacked": false,
			"attacker_index": attacker_index,
			"target_index": target_index,
			"target_died": false
		}

	if target_index == -1:
		return {
			"attacked": false,
			"attacker_index": attacker_index,
			"target_index": target_index,
			"target_died": false
		}

	if attacker_index >= units.size():
		return {
			"attacked": false,
			"attacker_index": attacker_index,
			"target_index": target_index,
			"target_died": false
		}

	if target_index >= units.size():
		return {
			"attacked": false,
			"attacker_index": attacker_index,
			"target_index": target_index,
			"target_died": false
		}

	var attacker = units[attacker_index]
	var target = units[target_index]

	var attack_tiles = get_ai_attack_tiles(
		attacker,
		attacker["pos"],
		unit_logic,
		map_data
	)

	if not attack_tiles.has(target["pos"]):
		return {
			"attacked": false,
			"attacker_index": attacker_index,
			"target_index": target_index,
			"target_died": false
		}

	var attack_direction = target["pos"] - attacker["pos"]

	attack_direction = Vector2i(
		sign(attack_direction.x),
		sign(attack_direction.y)
	)

	attacker["facing"] = attack_direction

	var damage = combat_logic.get_attack_damage(attacker)

	var target_died = target["hp"] - damage <= 0

	stamina_system.spend_attack_stamina(
		units,
		attacker_index
	)

	attacker["has_acted"] = true

	return {
		"attacked": true,
		"attacker_index": attacker_index,
		"target_index": target_index,
		"target_died": target_died,
		"damage": damage
	}

# =========================
# Returns the nearest reachable
# enemy unit index relative to
# the given unit.
#
# Distance uses actual traversable
# path cost rather than direct
# grid distance.
#
# This allows AI to correctly
# navigate around:
# - rivers
# - walls
# - blocked chokepoints
# - occupied tiles
#
# Returns:
# - enemy unit index
# - or -1 if no reachable enemies exist
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

	var occupied_tiles = unit_query.get_enemy_occupied_tiles(
		units,
		unit_index
	)

	for i in range(units.size()):

		if i == unit_index:
			continue

		if units[i]["team"] == unit_team:
			continue

		var path_data = map_data.get_path_to_nearest_adjacent_tile(
			unit_pos,
			units[i]["pos"],
			occupied_tiles
		)

		if path_data.is_empty():
			continue

		var distance = path_data["cost"]

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
	var best_distance = 999999
	var best_move_cost = 999999

	var planning_occupied_tiles = unit_query.get_enemy_occupied_tiles(
		units,
		unit_index
	)

	var movement_occupied_tiles = unit_query.get_all_occupied_tiles_except_unit(
		units,
		unit_index
	)

	for tile in move_tiles:

		var path_to_target = map_data.get_path_to_nearest_adjacent_tile(
			tile,
			target["pos"],
			planning_occupied_tiles
		)

		if path_to_target.is_empty():
			continue

		var distance_to_target = path_to_target["cost"]

		var path_from_start = map_data.get_movement_path_data(
			unit["pos"],
			tile,
			unit["move"],
			movement_occupied_tiles
		)

		if path_from_start.is_empty():
			continue

		var move_cost = path_from_start["cost"]

		if (
			distance_to_target < best_distance
			or (
				distance_to_target == best_distance
				and move_cost < best_move_cost
			)
		):
			best_distance = distance_to_target
			best_move_cost = move_cost
			best_tile = tile

	return best_tile

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
	coverage_system,
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

	if target_index == -1:

		if units[unit_index]["pos"] != units[unit_index]["home_pos"]:

			var return_tile = get_best_return_home_tile(
				units,
				unit_index,
				map_data
			)

			var move_result = move_ai_unit(
				units,
				unit_index,
				return_tile,
				map_data,
				unit_logic,
				coverage_system,
				combat_logic,
				stamina_system
			)

			if move_result["died"]:
				units.remove_at(unit_index)

				return {
					"moved": move_result["moved"],
					"path_cells": move_result["path_cells"],
					"unit_died": true,
					"attacked": false
				}

			units[unit_index]["has_acted"] = true

			return {
				"moved": move_result["moved"],
				"path_cells": move_result["path_cells"],
				"unit_died": false,
				"attacked": false
			}

		else:

			if units[unit_index].has("home_facing"):
				units[unit_index]["facing"] = units[unit_index]["home_facing"]

			units[unit_index]["has_acted"] = true

			return {
				"moved": false,
				"path_cells": [],
				"unit_died": false,
				"attacked": false
			}

	var attack_result = try_attack_target(
		units,
		unit_index,
		target_index,
		map_data,
		unit_logic,
		combat_logic,
		stamina_system
	)

	if attack_result["attacked"]:
		return {
			"moved": false,
			"path_cells": [],
			"unit_died": false,
			"attacked": true,
			"attacker_index": attack_result["attacker_index"],
			"target_index": attack_result["target_index"],
			"target_died": attack_result["target_died"],
			"damage": attack_result["damage"]
		}

	var destination = get_best_defender_tile(
		units,
		unit_index,
		target_index,
		map_data,
		unit_logic
	)

	var combat_move_result = move_ai_unit(
		units,
		unit_index,
		destination,
		map_data,
		unit_logic,
		coverage_system,
		combat_logic,
		stamina_system
	)

	if combat_move_result["died"]:
		units.remove_at(unit_index)

		return {
			"moved": combat_move_result["moved"],
			"path_cells": combat_move_result["path_cells"],
			"unit_died": true,
			"attacked": false
		}

	target_index = get_nearest_enemy_inside_defender_leash(
		units,
		unit_index,
		map_data
	)

	if target_index != -1:

		attack_result = try_attack_target(
			units,
			unit_index,
			target_index,
			map_data,
			unit_logic,
			combat_logic,
			stamina_system
		)

		if attack_result["attacked"]:
			return {
				"moved": combat_move_result["moved"],
				"path_cells": combat_move_result["path_cells"],
				"unit_died": false,
				"attacked": true,
				"attacker_index": attack_result["attacker_index"],
				"target_index": attack_result["target_index"],
				"target_died": attack_result["target_died"],
				"damage": attack_result["damage"]
			}

	var future_facing = get_future_path_facing(
		units,
		unit_index,
		target_index,
		map_data
	)

	if future_facing != Vector2i.ZERO:
		units[unit_index]["facing"] = future_facing

	units[unit_index]["has_acted"] = true

	return {
		"moved": combat_move_result["moved"],
		"path_cells": combat_move_result["path_cells"],
		"unit_died": false,
		"attacked": false
	}

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
	coverage_system,
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
			return {
				"moved": false,
				"path_cells": [],
				"unit_died": false,
				"attacked": false
			}

		var destination = get_best_healer_approach_tile(
			units,
			unit_index,
			heal_target_index,
			map_data,
			unit_logic
		)

		var move_result = move_ai_unit(
			units,
			unit_index,
			destination,
			map_data,
			unit_logic,
			coverage_system,
			combat_logic,
			stamina_system
		)

		if move_result["died"]:
			units.remove_at(unit_index)

			return {
				"moved": move_result["moved"],
				"path_cells": move_result["path_cells"],
				"unit_died": true,
				"attacked": false
			}

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
				return {
					"moved": move_result["moved"],
					"path_cells": move_result["path_cells"],
					"unit_died": false,
					"attacked": false
				}

		units[unit_index]["has_acted"] = true

		return {
			"moved": move_result["moved"],
			"path_cells": move_result["path_cells"],
			"unit_died": false,
			"attacked": false
		}

	var enemy_index = get_nearest_enemy(
		units,
		unit_index,
		map_data
	)

	if enemy_index != -1:

		var attack_result = try_attack_target(
			units,
			unit_index,
			enemy_index,
			map_data,
			unit_logic,
			combat_logic,
			stamina_system
		)

		if attack_result["attacked"]:
			return {
				"moved": false,
				"path_cells": [],
				"unit_died": false,
				"attacked": true,
				"attacker_index": attack_result["attacker_index"],
				"target_index": attack_result["target_index"],
				"target_died": attack_result["target_died"],
				"damage": attack_result["damage"]
			}

	units[unit_index]["has_acted"] = true

	return {
		"moved": false,
		"path_cells": [],
		"unit_died": false,
		"attacked": false
	}

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

	stamina_system.spend_support_stamina(
		units,
		healer_index,
		"heal"
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

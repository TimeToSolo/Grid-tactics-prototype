extends Node

# ==================================================
# BATTLE SETUP
# ==================================================
# Provides initial battle deployment data.
#
# Future expansion:
# - map-specific setups
# - deployment screens
# - reinforcements
# - objectives
# - scripted encounters
# ==================================================


# =========================
# Creates all battle units.
# =========================

func create_battle_units(unit_data) -> Array:

	return [

		# Player units - top-left 2x3 block
		unit_data.create_unit("fighter", "player", Vector2i(1, 2), Vector2i(0, 1)),
		unit_data.create_unit("tank", "player", Vector2i(2, 2), Vector2i(0, 1)),
		unit_data.create_unit("lancer", "player", Vector2i(3, 2), Vector2i(0, 1)),
		unit_data.create_unit("duelist", "player", Vector2i(1, 3), Vector2i(0, 1)),
		unit_data.create_unit("healer", "player", Vector2i(2, 3), Vector2i(0, 1)),
		unit_data.create_unit("archer", "player", Vector2i(3, 3), Vector2i(0, 1)),

		# Player units - bottom-left 2x3 block
		unit_data.create_unit("fighter", "player", Vector2i(1, 8), Vector2i(0, -1)),
		unit_data.create_unit("tank", "player", Vector2i(2, 8), Vector2i(0, -1)),
		unit_data.create_unit("lancer", "player", Vector2i(3, 8), Vector2i(0, -1)),
		unit_data.create_unit("duelist", "player", Vector2i(1, 9), Vector2i(0, -1)),
		unit_data.create_unit("healer", "player", Vector2i(2, 9), Vector2i(0, -1)),
		unit_data.create_unit("archer", "player", Vector2i(3, 9), Vector2i(0, -1)),

		# Enemy units - top-right 2x3 block
		unit_data.create_unit("fighter", "enemy", Vector2i(12, 2), Vector2i(0, 1)),
		unit_data.create_unit("tank", "enemy", Vector2i(13, 2), Vector2i(0, 1)),
		unit_data.create_unit("lancer", "enemy", Vector2i(14, 2), Vector2i(0, 1)),
		unit_data.create_unit("duelist", "enemy", Vector2i(12, 3), Vector2i(0, 1)),
		unit_data.create_unit("healer", "enemy", Vector2i(13, 3), Vector2i(0, 1)),
		unit_data.create_unit("archer", "enemy", Vector2i(14, 3), Vector2i(0, 1)),

		# Enemy units - bottom-right 2x3 block
		unit_data.create_unit("fighter", "enemy", Vector2i(12, 8), Vector2i(0, -1)),
		unit_data.create_unit("tank", "enemy", Vector2i(13, 8), Vector2i(0, -1)),
		unit_data.create_unit("lancer", "enemy", Vector2i(14, 8), Vector2i(0, -1)),
		unit_data.create_unit("duelist", "enemy", Vector2i(12, 9), Vector2i(0, -1)),
		unit_data.create_unit("healer", "enemy", Vector2i(13, 9), Vector2i(0, -1)),
		unit_data.create_unit("archer", "enemy", Vector2i(14, 9), Vector2i(0, -1))
	]

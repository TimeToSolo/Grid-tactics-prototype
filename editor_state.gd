extends Node

# ==================================================
# SHARED EDITOR CONSTANTS
# ==================================================

const INVALID_CELL := Vector2i(-1, -1)
const INVALID_UNIT := -1

# ==================================================
# EDITOR STATE
# ==================================================
# Owns all editor-related state.
#
# This keeps Main.gd from becoming
# a giant state container.
# ==================================================

# ==================================================
# EDITOR MODE
# ==================================================

var editor_mode := false

# ==================================================
# PALETTE / TILE STATE
# ==================================================

var selected_editor_tile := "."

var editor_palette := "terrain"

var selected_editor_unit_class := "fighter"

var selected_editor_facing := Vector2i(0, -1)

var selected_editor_ai_profile := "barbarian"

# ==================================================
# RECTANGLE DRAGGING
# ==================================================

var editor_rect_dragging := false

var editor_rect_start_cell := INVALID_CELL

# ==================================================
# RESIZE STATE
# ==================================================

var editor_resize_mode := false

var editor_resize_width := 20

var editor_resize_height := 16

# ==================================================
# SELECTION STATE
# ==================================================

var editor_select_dragging := false

var editor_select_start_cell := INVALID_CELL

var editor_selected_rect_start := INVALID_CELL

var editor_selected_rect_end := INVALID_CELL

# ==================================================
# MOVE DRAGGING
# ==================================================

var editor_move_dragging := false

var editor_move_start_cell := INVALID_CELL

# ==================================================
# MAP SLOT STATE
# ==================================================

var editor_map_slot := 1

const MAX_EDITOR_MAP_SLOTS := 9

# ==================================================
# UNIT EDITOR STATE
# ==================================================

var selected_editor_unit := INVALID_UNIT

var editor_reinforcement_stage := 1

var editor_unit_move_dragging := false

var editor_unit_move_start_cell := INVALID_CELL

# ==================================================
# DEBUG
# ==================================================

var show_all_defender_leashes := false

# ==================================================
# OBJECTIVE ZONES
# ==================================================

var objective_zones := {
	"retreat_zone": []
}

var selected_objective_zone := "retreat_zone"

# ==================================================
# AI PROFILE FILTERS
# ==================================================

var editor_ai_profiles_by_class = {

	"fighter": [
		"barbarian",
		"defender"
	],

	"tank": [
		"barbarian",
		"defender"
	],

	"lancer": [
		"barbarian",
		"defender"
	],

	"duelist": [
		"barbarian",
		"defender"
	],

	"archer": [
		"cautious_ranged"
	],

	"healer": [
		"support_healer"
	]
}

# ==================================================
# OBJECTIVE EDITOR STATE
# ==================================================

var editor_objective_stage_index := 0

var editor_objective_stage_types := [
	"defeat_enemy_count",
	"rout",
	"retreat"
]

var editor_objective_stages := [
	{
		"type": "defeat_enemy_count",
		"required_count": 3,
		"on_complete": "spawn_reinforcements"
	},
	{
		"type": "retreat",
		"zone": "retreat_zone",
		"on_complete": "victory"
	}
]

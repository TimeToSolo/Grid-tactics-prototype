extends Node

# =========================
# Paints terrain onto the map.
# =========================

func paint_tile(
	map_data,
	cell: Vector2i,
	tile_symbol: String
):

	if not map_data.is_inside_grid(cell):
		return

	var row = map_data.terrain_map[cell.y]

	row = (
		row.substr(0, cell.x)
		+ tile_symbol
		+ row.substr(cell.x + 1)
	)

	map_data.terrain_map[cell.y] = row

# =========================
# Fills a rectangular region
# with the selected terrain tile.
# =========================

func fill_rect(
	map_data,
	start_cell: Vector2i,
	end_cell: Vector2i,
	tile_symbol: String
):

	var min_x = min(start_cell.x, end_cell.x)
	var max_x = max(start_cell.x, end_cell.x)

	var min_y = min(start_cell.y, end_cell.y)
	var max_y = max(start_cell.y, end_cell.y)

	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):

			paint_tile(
				map_data,
				Vector2i(x, y),
				tile_symbol
			)

package dungeon_visualizer

import rl "vendor:raylib"

COLOR_WALL  :: rl.Color{30,  30,  35,  255}
COLOR_FLOOR :: rl.Color{140, 120, 100, 255}

draw_dungeon :: proc(d: ^Dungeon_Map) {
	for y in 0..<d.height {
		for x in 0..<d.width {
			color := COLOR_WALL if d.tiles[y][x] == .Wall else COLOR_FLOOR
			rl.DrawRectangle(
				i32(x * TILE_SIZE), i32(y * TILE_SIZE),
				i32(TILE_SIZE), i32(TILE_SIZE),
				color,
			)
		}
	}
}

package dungeon_visualizer

import rl "vendor:raylib"
import "core:fmt"

COLOR_WALL    :: rl.Color{30,  30,  35,  255}
COLOR_FLOOR   :: rl.Color{140, 120, 100, 255}
COLOR_START   :: rl.Color{0,   255, 0,   255}  // Green for player start
COLOR_END     :: rl.Color{255, 0,   0,   255}  // Red for goal/end
COLOR_ROOM    :: rl.Color{100, 100, 150, 100} // Blue overlay for rooms
MARKER_SIZE   :: 12  // Pixel size of spawn markers

// draw_dungeon renders the tile grid
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

// draw_spawn_points renders start (green) and end (red) markers
// Call after draw_dungeon for layering
draw_spawn_points :: proc(spawn: SpawnPoints) {
	if !spawn.valid {
		return  // Don't draw invalid spawn points
	}

	// Start marker (green)
	start_px := i32(spawn.start_x * TILE_SIZE + TILE_SIZE / 2 - MARKER_SIZE / 2)
	start_py := i32(spawn.start_y * TILE_SIZE + TILE_SIZE / 2 - MARKER_SIZE / 2)
	rl.DrawRectangle(start_px, start_py, i32(MARKER_SIZE), i32(MARKER_SIZE), COLOR_START)
	rl.DrawRectangleLines(start_px - 1, start_py - 1, i32(MARKER_SIZE + 2), i32(MARKER_SIZE + 2), rl.LIME)

	// End marker (red)
	end_px := i32(spawn.end_x * TILE_SIZE + TILE_SIZE / 2 - MARKER_SIZE / 2)
	end_py := i32(spawn.end_y * TILE_SIZE + TILE_SIZE / 2 - MARKER_SIZE / 2)
	rl.DrawRectangle(end_px, end_py, i32(MARKER_SIZE), i32(MARKER_SIZE), COLOR_END)
	rl.DrawRectangleLines(end_px - 1, end_py - 1, i32(MARKER_SIZE + 2), i32(MARKER_SIZE + 2), rl.MAROON)
}

// draw_dungeon_stats displays dungeon information at bottom of screen
// Shows: floor %, room count, spawn distance, connectivity
draw_dungeon_stats :: proc(d: ^Dungeon_Map, spawn: SpawnPoints, val_result: ValidationResult) {
	// Calculate statistics
	floor_count := val_result.total_floor_tiles
	total_tiles := d.width * d.height
	floor_percent := total_tiles > 0 ? int(f32(floor_count) * 100.0 / f32(total_tiles)) : 0
	room_count := len(d.rooms)

	// Position: bottom-left area
	y_pos := i32(SCREEN_H - 80)

	// Line 1: Floor coverage & rooms
	rl.DrawText(
		fmt.ctprintf("Floor: %d%% | Rooms: %d | Reachable: %d/%d",
			floor_percent, room_count, val_result.reachable_tiles, floor_count),
		10, y_pos, 16, rl.WHITE,
	)

	// Line 2: Spawn info (if valid)
	if spawn.valid {
		rl.DrawText(
			fmt.ctprintf("Start→End Distance: %d tiles", spawn.distance),
			10, y_pos + 20, 16, rl.WHITE,
		)
	}

	// Line 3: Connectivity status
	connectivity_text := spawn.valid ? "✓ Connected" : "✗ Disconnected"
	connectivity_color := spawn.valid ? rl.LIME : rl.RED
	rl.DrawText(
		fmt.ctprintf("Status: %s", connectivity_text),
		10, y_pos + 40, 16, connectivity_color,
	)
}

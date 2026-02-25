package dungeon_visualizer

import "core:math/rand"

// =============================================================================
// CORRIDOR CARVING & CONNECTIVITY
// =============================================================================
// Explicit corridor carving between rooms/regions with multiple strategies.
// Used by hybrid generation and as standalone connector.
//
// Strategies:
//   - STRAIGHT: Direct line between points (simple, can look unnatural)
//   - LSHAPED: L-shaped path (horizontal first, then vertical)
//   - WAYPOINT: Multi-waypoint path with random intermediate points
//
// Can carve corridors between rooms, region centers, or arbitrary points.
// All corridors have configurable width and can avoid obstacles.
// =============================================================================

CorridorStyle :: enum {
	LShaped,    // Horizontal then vertical (default, natural-looking)
	Straight,   // Direct line (rare, can look wrong)
	Waypoint,   // Multi-segment with random waypoints (complex, organic)
}

CorridorConfig :: struct {
	style: CorridorStyle,
	width: int,             // Corridor width in tiles (1-3 typical)
	waypoint_count: int,    // For waypoint style: max intermediate points
}

CORRIDOR_DEFAULT_CONFIG :: CorridorConfig{
	style = .LShaped,
	width = 1,
	waypoint_count = 2,
}

// carve_corridor_between_rooms connects two rooms with a corridor
// Uses room centers as start/end points, applies configured style
//
// Parameters:
//   dungeon: Dungeon to carve into
//   room1, room2: Rooms to connect
//   config: Style, width, and algorithm parameters
carve_corridor_between_rooms :: proc(
	dungeon: ^Dungeon_Map,
	room1, room2: Room,
	config := CORRIDOR_DEFAULT_CONFIG,
) {
	// Get room centers
	x1 := room1.x + room1.w / 2
	y1 := room1.y + room1.h / 2
	x2 := room2.x + room2.w / 2
	y2 := room2.y + room2.h / 2

	carve_corridor(dungeon, x1, y1, x2, y2, config)
}

// carve_corridor connects two arbitrary points (x1,y1) to (x2,y2)
// Applies corridor style and width settings
// Modifies dungeon.tiles in-place, converting walls to floor
//
// Parameters:
//   dungeon: Dungeon to carve into
//   x1, y1: Start point
//   x2, y2: End point
//   config: Style, width, waypoint settings
carve_corridor :: proc(
	dungeon: ^Dungeon_Map,
	x1, y1, x2, y2: int,
	config := CORRIDOR_DEFAULT_CONFIG,
) {
	switch config.style {
	case .LShaped:
		carve_lshaped_corridor(dungeon, x1, y1, x2, y2, config.width)
	case .Straight:
		carve_straight_corridor(dungeon, x1, y1, x2, y2, config.width)
	case .Waypoint:
		carve_waypoint_corridor(dungeon, x1, y1, x2, y2, config)
	}
}

// carve_lshaped_corridor creates an L-shaped corridor
// First horizontal segment from (x1,y1) to (x2,y1)
// Then vertical segment from (x2,y1) to (x2,y2)
// This is natural-looking and commonly used in roguelikes
//
// Width parameter makes corridor N tiles wide:
//   width=1: single-tile corridor
//   width=2: 2-tile wide corridor
//   width=3: 3-tile wide corridor (useful for large dungeons)
carve_lshaped_corridor :: proc(
	dungeon: ^Dungeon_Map,
	x1, y1, x2, y2: int,
	width: int,
) {
	// Horizontal segment: y=y1, x goes from x1 to x2
	if x1 <= x2 {
		for x in x1..=x2 {
			carve_corridor_tile(dungeon, x, y1, width)
		}
	} else {
		for x in x2..=x1 {
			carve_corridor_tile(dungeon, x, y1, width)
		}
	}

	// Vertical segment: x=x2, y goes from y1 to y2
	if y1 <= y2 {
		for y in y1..=y2 {
			carve_corridor_tile(dungeon, x2, y, width)
		}
	} else {
		for y in y2..=y1 {
			carve_corridor_tile(dungeon, x2, y, width)
		}
	}
}

// carve_straight_corridor creates a direct line from (x1,y1) to (x2,y2)
// Uses Bresenham-like stepping to approximate a straight line
// Results can look odd in grid-based dungeons; prefer L-shaped
//
// Note: This is rarely the best choice for roguelikes, but available
// for experimentation or special cases
carve_straight_corridor :: proc(
	dungeon: ^Dungeon_Map,
	x1, y1, x2, y2: int,
	width: int,
) {
	// Simple stepping toward target
	x, y := x1, y1
	steps := max(abs(x2 - x1), abs(y2 - y1))

	if steps == 0 {
		return  // Start and end are same point
	}

	for step in 0..=steps {
		// Linear interpolation toward target
		t := f32(step) / f32(steps)
		x = x1 + int(f32(x2 - x1) * t)
		y = y1 + int(f32(y2 - y1) * t)

		carve_corridor_tile(dungeon, x, y, width)
	}
}

// carve_waypoint_corridor creates a multi-segment path
// Picks random waypoints between start and end, connects them
// Results in more organic, winding corridors
//
// Algorithm:
//   1. Create waypoints: start → random midpoints → end
//   2. Connect consecutive waypoints with L-shaped segments
//   3. Apply width to each segment
carve_waypoint_corridor :: proc(
	dungeon: ^Dungeon_Map,
	x1, y1, x2, y2: int,
	config: CorridorConfig,
) {
	// Build waypoint list
	waypoints := make([dynamic][2]int)
	defer delete(waypoints)

	append(&waypoints, [2]int{x1, y1})

	// Add random intermediate waypoints
	for _ in 0..<config.waypoint_count {
		wp_x := x1 + int(rand.float32() * f32(x2 - x1))
		wp_y := y1 + int(rand.float32() * f32(y2 - y1))
		append(&waypoints, [2]int{wp_x, wp_y})
	}

	append(&waypoints, [2]int{x2, y2})

	// Connect consecutive waypoints with L-shaped corridors
	for i in 0..<len(waypoints) - 1 {
		wp_curr := waypoints[i]
		wp_next := waypoints[i + 1]
		carve_lshaped_corridor(
			dungeon,
			wp_curr.x, wp_curr.y,
			wp_next.x, wp_next.y,
			config.width,
		)
	}
}

// carve_corridor_tile carves a single tile and its neighbors (for width)
// Converts wall to floor in a cross pattern based on width
//
// width=1: carves (x,y)
// width=2: carves (x,y) and one neighbor
// width=3: carves (x,y) and cross of 4 neighbors
//
// Helper used by all carving strategies
carve_corridor_tile :: proc(dungeon: ^Dungeon_Map, x, y: int, width: int) {
	// Bounds check and carve center
	if x >= 0 && x < dungeon.width && y >= 0 && y < dungeon.height {
		dungeon.tiles[y][x] = .Floor
	}

	// For width > 1, carve neighbors
	if width >= 2 {
		// North
		if y > 0 {
			dungeon.tiles[y - 1][x] = .Floor
		}
		// South
		if y < dungeon.height - 1 {
			dungeon.tiles[y + 1][x] = .Floor
		}
	}

	if width >= 3 {
		// East
		if x < dungeon.width - 1 {
			dungeon.tiles[y][x + 1] = .Floor
		}
		// West
		if x > 0 {
			dungeon.tiles[y][x - 1] = .Floor
		}
	}
}

// carve_corridors_between_rooms connects multiple rooms in sequence
// Useful for linking generated rooms into a connected graph
//
// Parameters:
//   dungeon: Dungeon to carve into
//   rooms: Array of rooms to connect
//   config: Corridor style and settings
//
// Connects: room[0]→room[1]→room[2]→...→room[n-1]
// Creates a spanning tree of corridors (minimal connectivity)
carve_corridors_between_rooms :: proc(
	dungeon: ^Dungeon_Map,
	rooms: [dynamic]Room,
	config := CORRIDOR_DEFAULT_CONFIG,
) {
	if len(rooms) < 2 {
		return  // Need at least 2 rooms to connect
	}

	// Connect each room to the next in sequence
	for i in 0..<len(rooms) - 1 {
		carve_corridor_between_rooms(dungeon, rooms[i], rooms[i + 1], config)
	}
}

package dungeon_visualizer

// =============================================================================
// DRUNKARD'S WALK ALGORITHM
// =============================================================================
// Simple procedural cave carver: a walker starts at the map center and
// randomly stumbles around, carving floor tiles. Continues until ~35% of
// the map is open. Produces organic, winding cave systems.
//
// Pros: Simple, organic, fast
// Cons: No explicit rooms, can feel "samey", may produce narrow corridors
// Best for: Organic cave networks, dungeon transitions
// =============================================================================

import "core:math/rand"
import "core:time"

// Walker represents a single point moving through the dungeon
// Used by drunkards_walk to track the carving position
Walker :: struct { x, y: int }

// make_dungeon initializes and generates a Drunkard's Walk dungeon
// Returns a fully allocated Dungeon_Map with tiles carved
// Caller is responsible for calling free_dungeon() when done
// Seed is based on system time (non-deterministic)
make_dungeon :: proc() -> Dungeon_Map {
	// Seed RNG with nanosecond timestamp for variety
	// Note: rapid generation may see repeated seeds
	t := time.now()._nsec
	rand.reset(u64(t))

	// Initialize dungeon structure
	dungeon := Dungeon_Map{
		width  = MAP_WIDTH,
		height = MAP_HEIGHT,
		rooms  = make([dynamic]Room),  // Drunkard's Walk doesn't populate this
	}

	// Allocate 2D tile array: [height][width]
	// Odin zero-initializes all tiles to .Wall (enum value 0)
	dungeon.tiles = make([][]Tile_Type, MAP_HEIGHT)
	for y in 0..<MAP_HEIGHT {
		dungeon.tiles[y] = make([]Tile_Type, MAP_WIDTH)
		// All tiles are now .Wall by default
	}

	// Run the carving algorithm
	drunkards_walk(&dungeon)
	return dungeon
}

// free_dungeon deallocates all memory associated with the dungeon
// Must be called to prevent memory leaks
// Safe to call multiple times on same dungeon (will panic if already freed)
free_dungeon :: proc(d: ^Dungeon_Map) {
	// Free each row of the 2D array
	for y in 0..<d.height { delete(d.tiles[y]) }
	// Free the row array itself
	delete(d.tiles)
	// Free the room list
	delete(d.rooms)
}

// drunkards_walk implements the core carving algorithm
// Modifies dungeon.tiles in-place, converting Wall→Floor as the walker moves
// Continues until FLOOR_TARGET (35% of map) is reached
//
// Algorithm:
//   1. Start walker at center of map
//   2. If current tile is wall, carve it to floor
//   3. Move walker one step in random cardinal direction
//   4. Clamp position to avoid hitting outer border
//   5. Repeat until floor count reaches target
drunkards_walk :: proc(d: ^Dungeon_Map) {
	// Start at map center
	walker := Walker{ x = d.width / 2, y = d.height / 2 }
	floor_count := 0

	// Keep moving and carving until we hit 35% floor coverage
	for floor_count < FLOOR_TARGET {
		// If standing on a wall, carve it
		if d.tiles[walker.y][walker.x] == .Wall {
			d.tiles[walker.y][walker.x] = .Floor
			floor_count += 1
		}

		// Pick random direction: 0=North, 1=East, 2=South, 3=West
		dir := rand.int_max(4)
		dx, dy: int  // Cardinal direction delta
		switch dir {
		case 0: dy = -1  // North (up)
		case 1: dx =  1  // East (right)
		case 2: dy =  1  // South (down)
		case 3: dx = -1  // West (left)
		}

		// Move walker, clamped to border area
		// Clamping to [1, width-2] keeps 1-tile border of walls intact
		walker.x = clamp(walker.x + dx, 1, d.width  - 2)
		walker.y = clamp(walker.y + dy, 1, d.height - 2)
	}
	// When loop exits, ~35% of non-border tiles are carved to floor
}

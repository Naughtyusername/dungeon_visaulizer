package dungeon_visualizer

import "core:math/rand"
import "core:time"

// =============================================================================
// PREFAB-BASED DUNGEON GENERATION
// =============================================================================
// Builds dungeons from hand-crafted room templates (prefabs).
// Simple approach: fill dungeon with walls, scatter prefabs randomly.
// No overlaps checked (can create interesting overlapping rooms later).
//
// Use cases:
//   - Showcase hand-designed rooms
//   - Hybrid approach: blend prefabs with procedural generation
//   - Build dungeons from a room library
// =============================================================================

PrefabConfig :: struct {
	prefab_count: int,      // How many prefabs to place
	prefer_variety: bool,   // Try to avoid repeating same prefab
}

PREFAB_DEFAULT_CONFIG :: PrefabConfig{
	prefab_count = 6,
	prefer_variety = true,
}

// make_dungeon_prefab creates a dungeon from scattered prefab rooms
// Algorithm:
//   1. Start with all walls
//   2. Randomly place prefab templates until target count reached
//   3. Connect all rooms with corridors (via dungeon.rooms list)
//   4. Validate connectivity
//
// Returns a Dungeon_Map with placed prefab rooms
make_dungeon_prefab :: proc(config := PREFAB_DEFAULT_CONFIG) -> Dungeon_Map {
	t := time.now()._nsec
	rand.reset(u64(t))

	dungeon := Dungeon_Map{
		width  = MAP_WIDTH,
		height = MAP_HEIGHT,
		rooms  = make([dynamic]Room),
	}

	// Allocate tile grid (all walls initially)
	dungeon.tiles = make([][]Tile_Type, MAP_HEIGHT)
	for y in 0..<MAP_HEIGHT {
		dungeon.tiles[y] = make([]Tile_Type, MAP_WIDTH)
		// All tiles start as .Wall (zero-initialized)
	}

	// Place prefabs (actual count may be less if space constrained)
	_ = place_random_prefabs(&dungeon, config.prefab_count)

	// Extract room bounds from placed prefabs and store in dungeon.rooms
	// This allows connectivity checking and corridor carving
	prefab_find_rooms(&dungeon)

	// Connect rooms if we have multiple
	if len(dungeon.rooms) >= 2 {
		carve_corridors_between_rooms(&dungeon, dungeon.rooms)
	}

	// Validate connectivity
	validate_connectivity(&dungeon, MAP_WIDTH / 2, MAP_HEIGHT / 2, true)

	return dungeon
}

// prefab_find_rooms scans the dungeon and extracts rectangular rooms
// Identifies contiguous floor regions and approximates them as rooms
// (Simple version: just creates rooms from the placed prefabs)
//
// Advanced version would do flood-fill to find actual connected regions
prefab_find_rooms :: proc(dungeon: ^Dungeon_Map) {
	// Simple approach: scan for rectangular floor regions
	// This is a heuristic; more sophisticated than brute-force but not perfect

	visited := make([][]bool, dungeon.height)
	defer {
		for y in 0..<dungeon.height { delete(visited[y]) }
		delete(visited)
	}
	for y in 0..<dungeon.height {
		visited[y] = make([]bool, dungeon.width)
	}

	// Scan for floor tile clusters
	for y in 1..<dungeon.height - 1 {
		for x in 1..<dungeon.width - 1 {
			if dungeon.tiles[y][x] == .Floor && !visited[y][x] {
				// Found a new floor region; find its bounding box
				min_x, max_x := x, x
				min_y, max_y := y, y

				// Simple flood-fill to find extent
				find_region_bounds(dungeon, visited, x, y, &min_x, &max_x, &min_y, &max_y)

				// Create a room from the bounds
				room_w := max_x - min_x + 1
				room_h := max_y - min_y + 1

				if room_w >= 3 && room_h >= 3 {  // Only significant rooms
					room := Room{x = min_x, y = min_y, w = room_w, h = room_h}
					append(&dungeon.rooms, room)
				}
			}
		}
	}
}

// find_region_bounds does a limited flood-fill to find room extents
// Marks visited tiles to avoid double-counting
find_region_bounds :: proc(
	dungeon: ^Dungeon_Map,
	visited: [][]bool,
	x, y: int,
	min_x, max_x, min_y, max_y: ^int,
) {
	if x < 0 || x >= dungeon.width || y < 0 || y >= dungeon.height {
		return
	}
	if visited[y][x] || dungeon.tiles[y][x] == .Wall {
		return
	}

	visited[y][x] = true
	min_x^ = min(min_x^, x)
	max_x^ = max(max_x^, x)
	min_y^ = min(min_y^, y)
	max_y^ = max(max_y^, y)

	// Recurse to 4 neighbors
	find_region_bounds(dungeon, visited, x + 1, y, min_x, max_x, min_y, max_y)
	find_region_bounds(dungeon, visited, x - 1, y, min_x, max_x, min_y, max_y)
	find_region_bounds(dungeon, visited, x, y + 1, min_x, max_x, min_y, max_y)
	find_region_bounds(dungeon, visited, x, y - 1, min_x, max_x, min_y, max_y)
}

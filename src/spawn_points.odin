package dungeon_visualizer

// =============================================================================
// SPAWN POINT PLACEMENT & VALIDATION
// =============================================================================
// Guarantees valid start and end positions for player and goal.
// Uses distance-based separation to ensure interesting layouts.
//
// Usage:
//   - Call place_spawn_points() after dungeon generation
//   - Returns SpawnPoints with start and end locations
//   - Validates: both on floor, distance apart, reachable from each other
// =============================================================================

SpawnPoints :: struct {
	start_x, start_y: int,  // Player spawn location
	end_x, end_y: int,      // Goal/exit location
	distance: int,          // Manhattan distance between them
	valid: bool,            // True if both points are valid and separated
}

SpawnConfig :: struct {
	min_distance: int,  // Minimum tiles apart (Manhattan distance)
}

SPAWN_DEFAULT_CONFIG :: SpawnConfig{
	min_distance = 25,  // ~5x5 room separation at minimum
}

// place_spawn_points finds valid start/end locations in a dungeon.
// Strategy — double-BFS (finds near-optimal diameter, no center bias):
//   1. Find any floor tile as a throwaway seed (top-left scan)
//   2. BFS from seed → farthest reachable floor tile = start (one extreme)
//   3. BFS from start → farthest reachable floor tile = end (opposite extreme)
//   4. Validate distance meets minimum separation
//
// Why double-BFS instead of "prefer center":
//   Single-pass from center always placed stairs at center for DW (the walker
//   starts there) and BSP (corridors pass through center). Double-BFS finds
//   the actual diameter of the dungeon regardless of shape or algorithm.
//
// Parameters:
//   dungeon: Fully generated dungeon
//   config:  SpawnConfig with min_distance requirement
//
// Returns SpawnPoints with start, end, distance, and validity
place_spawn_points :: proc(
	dungeon: ^Dungeon_Map,
	config := SPAWN_DEFAULT_CONFIG,
) -> SpawnPoints {
	result := SpawnPoints{valid = false}

	// Pass 1: seed BFS from any floor tile (top-left scan, no center bias)
	seed_x, seed_y := find_any_floor(dungeon)
	if dungeon.tiles[seed_y][seed_x] != .Floor {
		return result
	}

	// Pass 2: BFS from seed → finds one extreme of the dungeon = start (up stairs)
	start_x, start_y := find_farthest_point(dungeon, seed_x, seed_y)
	if dungeon.tiles[start_y][start_x] != .Floor {
		return result
	}

	// Pass 3: BFS from start → finds the opposite extreme = end (down stairs)
	end_x, end_y := find_farthest_point(dungeon, start_x, start_y)
	if dungeon.tiles[end_y][end_x] != .Floor {
		return result
	}

	result.start_x = start_x
	result.start_y = start_y
	result.end_x   = end_x
	result.end_y   = end_y
	result.distance = abs(end_x - start_x) + abs(end_y - start_y)
	result.valid    = (result.distance >= config.min_distance)

	return result
}

// find_any_floor returns the first floor tile found by top-left scan.
// Used as a bias-free seed for the double-BFS spawn placement.
// Does NOT prefer center — that's intentional to avoid the center-bias bug.
find_any_floor :: proc(dungeon: ^Dungeon_Map) -> (int, int) {
	for y in 0..<dungeon.height {
		for x in 0..<dungeon.width {
			if dungeon.tiles[y][x] == .Floor {
				return x, y
			}
		}
	}
	return 0, 0
}

// find_farthest_point locates the farthest reachable floor from (start_x, start_y)
// Uses BFS with distance tracking to find max-distance tile
// Returns the tile with maximum distance (greedy farthest point)
find_farthest_point :: proc(dungeon: ^Dungeon_Map, start_x, start_y: int) -> (int, int) {
	// BFS distance array
	dist := make([][]int, dungeon.height)
	defer {
		for y in 0..<dungeon.height { delete(dist[y]) }
		delete(dist)
	}

	for y in 0..<dungeon.height {
		dist[y] = make([]int, dungeon.width)
		for x in 0..<dungeon.width {
			dist[y][x] = -1  // -1 = unvisited
		}
	}

	// BFS from start
	queue := make([dynamic][2]int)
	defer delete(queue)

	dist[start_y][start_x] = 0
	append(&queue, [2]int{start_x, start_y})

	max_dist := 0
	farthest_x := start_x
	farthest_y := start_y
	queue_idx := 0

	for queue_idx < len(queue) {
		// Get next from queue
		pos := queue[queue_idx]
		queue_idx += 1
		x, y := pos.x, pos.y
		d := dist[y][x]

		// Explore 4 neighbors
		neighbors := [4][2]int{
			{x + 1, y},  // East
			{x - 1, y},  // West
			{x, y + 1},  // South
			{x, y - 1},  // North
		}

		for neighbor in neighbors {
			nx, ny := neighbor.x, neighbor.y
			if nx >= 0 && nx < dungeon.width && ny >= 0 && ny < dungeon.height {
				// Traverse floor AND door tiles — doors are passable
				// Only update farthest when on actual floor (not doorway)
				tile := dungeon.tiles[ny][nx]
				if (tile == .Floor || tile == .Door) && dist[ny][nx] == -1 {
					dist[ny][nx] = d + 1
					if dist[ny][nx] > max_dist && tile == .Floor {
						max_dist = dist[ny][nx]
						farthest_x = nx
						farthest_y = ny
					}
					append(&queue, [2]int{nx, ny})
				}
			}
		}
	}

	return farthest_x, farthest_y
}

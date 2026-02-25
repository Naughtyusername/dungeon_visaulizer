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

// place_spawn_points finds valid start/end locations in a dungeon
// Strategy:
//   1. Pick start from largest open area (usually center floor region)
//   2. Do floodfill from start to find reachable tiles
//   3. Pick end from farthest reachable point (greedy max distance)
//   4. Validate both are on floor and far enough apart
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

	// Find a floor tile to start from (prefer center area)
	start_x, start_y := find_best_start_point(dungeon)
	if dungeon.tiles[start_y][start_x] == .Wall {
		return result  // No valid start found
	}

	result.start_x = start_x
	result.start_y = start_y

	// Find end point: farthest floor from start using BFS distance
	end_x, end_y := find_farthest_point(dungeon, start_x, start_y)
	if dungeon.tiles[end_y][end_x] == .Wall {
		return result  // No valid end found
	}

	result.end_x = end_x
	result.end_y = end_y

	// Calculate distance (Manhattan)
	result.distance = abs(end_x - start_x) + abs(end_y - start_y)

	// Valid only if:
	//   1. Both are on floor (checked above)
	//   2. Far enough apart
	result.valid = (result.distance >= config.min_distance)

	return result
}

// find_best_start_point locates a good starting position
// Prefers center area, looks for open floor tiles
// Falls back to spiral search if center is blocked
find_best_start_point :: proc(dungeon: ^Dungeon_Map) -> (int, int) {
	center_x := dungeon.width / 2
	center_y := dungeon.height / 2

	// Try center first
	if dungeon.tiles[center_y][center_x] == .Floor {
		return center_x, center_y
	}

	// Spiral search from center
	for radius in 1..<max(dungeon.width, dungeon.height) {
		for dy in -radius..=radius {
			for dx in -radius..=radius {
				if max(abs(dx), abs(dy)) != radius {
					continue  // Only check outer ring
				}
				x := center_x + dx
				y := center_y + dy
				if x >= 0 && x < dungeon.width && y >= 0 && y < dungeon.height {
					if dungeon.tiles[y][x] == .Floor {
						return x, y
					}
				}
			}
		}
	}

	// Fallback: brute force first floor tile
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
				if dungeon.tiles[ny][nx] == .Floor && dist[ny][nx] == -1 {
					dist[ny][nx] = d + 1
					if dist[ny][nx] > max_dist {
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

package dungeon_visualizer

// =============================================================================
// DUNGEON VALIDATION & CONNECTIVITY CHECKING
// =============================================================================
// Tools to validate dungeons before gameplay. Critical for roguelikes:
// ensures all floor tiles are reachable from a starting point,
// no isolated regions block progression.
//
// Usage:
//   - Call validate_connectivity() after generation
//   - Returns ValidationResult with stats and whether dungeon is valid
//   - Optionally removes isolated regions automatically
// =============================================================================

ValidationResult :: struct {
	is_valid: bool,           // True if all floors are connected
	total_floor_tiles: int,   // Total floor tiles in dungeon
	reachable_tiles: int,     // Floor tiles reachable from start
	isolated_regions: int,    // Number of disconnected floor regions
	largest_region_size: int, // Biggest connected region
}

// validate_connectivity checks if dungeon is fully connected
// Starting from (start_x, start_y), performs flood-fill to find reachable floors
// Compares reachable count to total floors
//
// Parameters:
//   dungeon:      Dungeon to validate
//   start_x/y:    Starting position for reachability check
//   remove_isolated: If true, fill isolated regions with walls
//
// Returns ValidationResult with connectivity statistics
// is_valid=true means: all floor tiles are reachable from start position
validate_connectivity :: proc(
	dungeon: ^Dungeon_Map,
	start_x, start_y: int,
	remove_isolated: bool = true,
) -> ValidationResult {
	// Use local variables for start position (can't reassign parameters)
	check_x := start_x
	check_y := start_y

	if dungeon.tiles[check_y][check_x] == .Wall {
		// Start point is in a wall; find nearest floor instead
		check_x, check_y = find_nearest_floor(dungeon)
	}

	// Count total floor tiles in dungeon
	total_floors := 0
	for y in 0..<dungeon.height {
		for x in 0..<dungeon.width {
			if dungeon.tiles[y][x] == .Floor {
				total_floors += 1
			}
		}
	}

	// Allocate visited array for flood fill
	visited := make([][]bool, dungeon.height)
	for y in 0..<dungeon.height {
		visited[y] = make([]bool, dungeon.width)
	}
	defer {
		for y in 0..<dungeon.height { delete(visited[y]) }
		delete(visited)
	}

	// Flood-fill from start to find reachable region
	reachable_count := 0
	flood_fill_count(dungeon, visited, check_x, check_y, &reachable_count)

	result := ValidationResult{
		is_valid = (reachable_count == total_floors),
		total_floor_tiles = total_floors,
		reachable_tiles = reachable_count,
		largest_region_size = reachable_count,
	}

	// If requested, remove isolated regions
	if remove_isolated && !result.is_valid {
		remove_isolated_regions(dungeon, visited)
		// Recount after removal
		result.total_floor_tiles = 0
		result.reachable_tiles = 0
		for y in 0..<dungeon.height {
			for x in 0..<dungeon.width {
				if dungeon.tiles[y][x] == .Floor {
					result.total_floor_tiles += 1
				}
			}
		}
		result.is_valid = true  // After removal, all are connected
	}

	return result
}

// find_nearest_floor locates the closest floor tile from center
// Used as fallback if start position is in a wall
find_nearest_floor :: proc(dungeon: ^Dungeon_Map) -> (int, int) {
	center_x := dungeon.width / 2
	center_y := dungeon.height / 2

	// Spiral outward from center
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

	// Fallback: brute-force search
	for y in 0..<dungeon.height {
		for x in 0..<dungeon.width {
			if dungeon.tiles[y][x] == .Floor {
				return x, y
			}
		}
	}

	return 0, 0  // No floors found (degenerate case)
}

// flood_fill_count performs 4-connected flood-fill from (x,y)
// Counts all reachable floor tiles and marks them visited
// Used by validate_connectivity to find reachable region size
flood_fill_count :: proc(
	dungeon: ^Dungeon_Map,
	visited: [][]bool,
	x, y: int,
	count: ^int,
) {
	// Bounds check
	if x < 0 || x >= dungeon.width || y < 0 || y >= dungeon.height {
		return
	}

	// Already visited or it's a wall
	if visited[y][x] || dungeon.tiles[y][x] == .Wall {
		return
	}

	// Mark visited and increment count
	visited[y][x] = true
	count^ += 1

	// Recurse to 4 neighbors (up, down, left, right)
	flood_fill_count(dungeon, visited, x + 1, y, count)
	flood_fill_count(dungeon, visited, x - 1, y, count)
	flood_fill_count(dungeon, visited, x, y + 1, count)
	flood_fill_count(dungeon, visited, x, y - 1, count)
}

// remove_isolated_regions fills unreachable floor tiles with walls
// Assumes visited array from a prior flood-fill; marks all unvisited
// floors as walls, making only the main region remain
remove_isolated_regions :: proc(dungeon: ^Dungeon_Map, visited: [][]bool) {
	for y in 0..<dungeon.height {
		for x in 0..<dungeon.width {
			// If it's a floor but not visited, fill it with wall
			if dungeon.tiles[y][x] == .Floor && !visited[y][x] {
				dungeon.tiles[y][x] = .Wall
			}
		}
	}
}

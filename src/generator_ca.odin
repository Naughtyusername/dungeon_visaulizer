package dungeon_visualizer

// =============================================================================
// CELLULAR AUTOMATA CAVE GENERATION
// =============================================================================
// Uses Conway's Game of Life-style rules to generate organic caves.
// Algorithm:
//   1. Random wall initialization (~45% walls, 55% floor)
//   2. Iterate N times: apply neighbor rules (if 4+ wall neighbors → wall)
//   3. Remove isolated regions via flood-fill, keep largest cave
//
// Pros: Organic, connected, natural-looking caves, tuneable parameters
// Cons: Takes multiple iterations, less structured than BSP, may be isolated
// Best for: Natural caves, monster lairs, organic level variety
// =============================================================================

import "core:math/rand"
import "core:time"

// CA_Config controls cellular automata generation behavior
// initial_fill:  Probability [0.0, 1.0] that a tile starts as wall (~0.45)
// generations:   Number of iterations to apply rules (4-6 is typical)
// wall_threshold: If neighbor wall count >= this, tile becomes wall (usually 4)
//
// Tuning tips:
//   - Higher initial_fill → denser caves, slower generation
//   - More generations → smoother, more carved out caves
//   - Higher wall_threshold → more walls, fewer caves
CA_Config :: struct {
	initial_fill: f32,     // 0.4 = 40% walls initially
	generations: int,      // How many iterations to run
	wall_threshold: int,   // Walls if neighbors >= this
}

// CA_DEFAULT_CONFIG: reasonable defaults for cave generation
// ~45% walls initially, 4 generations, 4 neighbor threshold
// Results in interconnected cave system with natural-looking patterns
CA_DEFAULT_CONFIG :: CA_Config{
	initial_fill = 0.45,
	generations = 4,
	wall_threshold = 4,
}

// make_dungeon_ca is the public entry point for CA cave generation
// Coordinates the full CA pipeline:
//   1. Random wall/floor initialization
//   2. Iterative rule application (smooth the map)
//   3. Isolation removal (keep only largest connected region)
// Returns a complete Dungeon_Map ready for rendering/gameplay
make_dungeon_ca :: proc(config := CA_DEFAULT_CONFIG) -> Dungeon_Map {
	// Seed RNG with nanosecond timestamp
	t := time.now()._nsec
	rand.reset(u64(t))

	// Initialize dungeon and allocate tile grid
	dungeon := Dungeon_Map{
		width  = MAP_WIDTH,
		height = MAP_HEIGHT,
		rooms  = make([dynamic]Room),  // Not used by CA generation
	}
	dungeon.tiles = make([][]Tile_Type, MAP_HEIGHT)
	for y in 0..<MAP_HEIGHT {
		dungeon.tiles[y] = make([]Tile_Type, MAP_WIDTH)
		// All tiles start as .Wall (zero-initialized)
	}

	// Phase 1: Random wall/floor distribution
	// Creates noisy starting state (~45% walls, 55% floors)
	ca_initialize(&dungeon, config)

	// Phase 2: Smooth via cellular automata
	// Repeatedly apply neighbor rules to create coherent regions
	// "If 4+ neighbors are walls, become a wall" creates solid cave walls
	for _ in 0..<config.generations {
		ca_iterate(&dungeon, config)
	}

	// Phase 3: Isolation removal
	// Find largest connected floor region, fill isolated areas with walls
	// Guarantees all remaining floors are mutually reachable
	ca_flood_fill(&dungeon)

	return dungeon
}

ca_initialize :: proc(dungeon: ^Dungeon_Map, config: CA_Config) {
	for y in 0..<dungeon.height {
		for x in 0..<dungeon.width {
			// Border always wall
			if x == 0 || x == dungeon.width - 1 || y == 0 || y == dungeon.height - 1 {
				dungeon.tiles[y][x] = .Wall
			} else {
				// Random fill
				dungeon.tiles[y][x] = rand.float32() < config.initial_fill ? .Wall : .Floor
			}
		}
	}
}

ca_iterate :: proc(dungeon: ^Dungeon_Map, config: CA_Config) {
	temp := make([][]Tile_Type, dungeon.height)
	for y in 0..<dungeon.height {
		temp[y] = make([]Tile_Type, dungeon.width)
		for x in 0..<dungeon.width {
			temp[y][x] = dungeon.tiles[y][x]
		}
	}

	for y in 0..<dungeon.height {
		for x in 0..<dungeon.width {
			if x == 0 || x == dungeon.width - 1 || y == 0 || y == dungeon.height - 1 {
				temp[y][x] = .Wall
			} else {
				neighbors := ca_count_wall_neighbors(dungeon, x, y)
				// If 4+ wall neighbors, become wall; otherwise floor
				temp[y][x] = neighbors >= config.wall_threshold ? .Wall : .Floor
			}
		}
	}

	// Copy back
	for y in 0..<dungeon.height {
		for x in 0..<dungeon.width {
			dungeon.tiles[y][x] = temp[y][x]
		}
		delete(temp[y])
	}
	delete(temp)
}

ca_count_wall_neighbors :: proc(dungeon: ^Dungeon_Map, x, y: int) -> int {
	count := 0
	for dy in -1..=1 {
		for dx in -1..=1 {
			if dx == 0 && dy == 0 {
				continue
			}
			nx, ny := x + dx, y + dy
			if nx >= 0 && nx < dungeon.width && ny >= 0 && ny < dungeon.height {
				if dungeon.tiles[ny][nx] == .Wall {
					count += 1
				}
			}
		}
	}
	return count
}

ca_flood_fill :: proc(dungeon: ^Dungeon_Map) {
	visited := make([][]bool, dungeon.height)
	for y in 0..<dungeon.height {
		visited[y] = make([]bool, dungeon.width)
	}
	defer {
		for y in 0..<dungeon.height { delete(visited[y]) }
		delete(visited)
	}

	// Find all floor regions
	largest_size := 0
	largest_region := make([dynamic][2]int)
	defer delete(largest_region)

	for y in 0..<dungeon.height {
		for x in 0..<dungeon.width {
			if dungeon.tiles[y][x] == .Floor && !visited[y][x] {
				region := make([dynamic][2]int)
				ca_fill_region(dungeon, visited, x, y, &region)

				if len(region) > largest_size {
					// Replace largest region
					delete(largest_region)
					largest_region = region
					largest_size = len(region)
				} else {
					delete(region)
				}
			}
		}
	}

	// Turn all non-largest regions into walls
	for y in 0..<dungeon.height {
		for x in 0..<dungeon.width {
			dungeon.tiles[y][x] = .Wall
		}
	}

	// Restore largest region as floor
	for pos in largest_region {
		dungeon.tiles[pos.y][pos.x] = .Floor
	}
}

ca_fill_region :: proc(dungeon: ^Dungeon_Map, visited: [][]bool, x, y: int, region: ^[dynamic][2]int) {
	if x < 0 || x >= dungeon.width || y < 0 || y >= dungeon.height {
		return
	}
	if visited[y][x] || dungeon.tiles[y][x] == .Wall {
		return
	}

	visited[y][x] = true
	append(region, [2]int{x, y})

	// 4-connectivity flood fill
	ca_fill_region(dungeon, visited, x + 1, y, region)
	ca_fill_region(dungeon, visited, x - 1, y, region)
	ca_fill_region(dungeon, visited, x, y + 1, region)
	ca_fill_region(dungeon, visited, x, y - 1, region)
}

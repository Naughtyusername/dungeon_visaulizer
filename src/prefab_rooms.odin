package dungeon_visualizer

import "core:math/rand"

// =============================================================================
// PREFAB ROOM TEMPLATES
// =============================================================================
// Hand-crafted, reusable room designs for dungeon generation.
// Each prefab is a template: name, dimensions, and tile layout.
//
// Strategy:
//   1. Define PrefabTemplate struct (name, width, height, tile data)
//   2. Hand-craft interesting rooms as ASCII, convert to tile arrays
//   3. Provide functions to place prefabs in dungeons
//   4. Algorithm can randomly select and position prefabs
//
// Future: Interactive editor (in actual game project)
// Current: Code-based design, easy to iterate and test
// =============================================================================

PrefabTemplate :: struct {
	name: cstring,
	width, height: int,
	tiles: []Tile_Type,  // Linear array; access as tiles[y * width + x]
}

// Helper: Create tile array from row-major data
// Pass as: ...make_prefab(name, width, height, wall, wall, floor, ...)
make_prefab :: proc(name: cstring, width, height: int, args: ..Tile_Type) -> PrefabTemplate {
	tiles := make([]Tile_Type, width * height)
	for i in 0..<min(len(args), width * height) {
		tiles[i] = args[i]
	}
	return PrefabTemplate{name = name, width = width, height = height, tiles = tiles}
}

// =============================================================================
// PREFAB CATALOG
// =============================================================================
// Each prefab shows ASCII art first, then tile definition
// ASCII: # = Wall, . = Floor
// =============================================================================

// BOSS_ROOM: Grand circular chamber
// Layout:
//   #########
//   #.......#
//   #.......#
//   #...@...#  (@=boss spawn)
//   #.......#
//   #.......#
//   #########
PREFAB_BOSS_ROOM := PrefabTemplate{
	name = "Boss Room",
	width = 9, height = 7,
	tiles = []Tile_Type{
		.Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall,
		.Wall, .Floor, .Floor, .Floor, .Floor, .Floor, .Floor, .Floor, .Wall,
		.Wall, .Floor, .Floor, .Floor, .Floor, .Floor, .Floor, .Floor, .Wall,
		.Wall, .Floor, .Floor, .Floor, .Floor, .Floor, .Floor, .Floor, .Wall,
		.Wall, .Floor, .Floor, .Floor, .Floor, .Floor, .Floor, .Floor, .Wall,
		.Wall, .Floor, .Floor, .Floor, .Floor, .Floor, .Floor, .Floor, .Wall,
		.Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall,
	},
}

// TREASURE_VAULT: Small, protected chamber
// Layout:
//   #########
//   #.......#
//   #.......#
//   #...T...#  (T=treasure)
//   #.......#
//   #########
PREFAB_TREASURE_VAULT := PrefabTemplate{
	name = "Treasure Vault",
	width = 9, height = 6,
	tiles = []Tile_Type{
		.Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall,
		.Wall, .Floor, .Floor, .Floor, .Floor, .Floor, .Floor, .Floor, .Wall,
		.Wall, .Floor, .Floor, .Floor, .Floor, .Floor, .Floor, .Floor, .Wall,
		.Wall, .Floor, .Floor, .Floor, .Floor, .Floor, .Floor, .Floor, .Wall,
		.Wall, .Floor, .Floor, .Floor, .Floor, .Floor, .Floor, .Floor, .Wall,
		.Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall,
	},
}

// GUARD_CHAMBER: Structured room with alcoves
// Layout:
//   ###########
//   #...#...#.#
//   #...#...#.#
//   #.........#
//   #...#...#.#
//   #...#...#.#
//   ###########
PREFAB_GUARD_CHAMBER := PrefabTemplate{
	name = "Guard Chamber",
	width = 11, height = 7,
	tiles = []Tile_Type{
		.Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall,
		.Wall, .Floor, .Floor, .Floor, .Wall, .Floor, .Floor, .Floor, .Wall, .Floor, .Wall,
		.Wall, .Floor, .Floor, .Floor, .Wall, .Floor, .Floor, .Floor, .Wall, .Floor, .Wall,
		.Wall, .Floor, .Floor, .Floor, .Floor, .Floor, .Floor, .Floor, .Floor, .Floor, .Wall,
		.Wall, .Floor, .Floor, .Floor, .Wall, .Floor, .Floor, .Floor, .Wall, .Floor, .Wall,
		.Wall, .Floor, .Floor, .Floor, .Wall, .Floor, .Floor, .Floor, .Wall, .Floor, .Wall,
		.Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall,
	},
}

// THRONE_ROOM: Long grand chamber with elevated center
// Layout:
//   #############
//   #.....#.....#
//   #.....#.....#
//   #.....#.....#
//   #.###.....###
//   #.###.....###
//   #############
PREFAB_THRONE_ROOM := PrefabTemplate{
	name = "Throne Room",
	width = 13, height = 7,
	tiles = []Tile_Type{
		.Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall,
		.Wall, .Floor, .Floor, .Floor, .Floor, .Floor, .Wall, .Floor, .Floor, .Floor, .Floor, .Floor, .Wall,
		.Wall, .Floor, .Floor, .Floor, .Floor, .Floor, .Wall, .Floor, .Floor, .Floor, .Floor, .Floor, .Wall,
		.Wall, .Floor, .Floor, .Floor, .Floor, .Floor, .Wall, .Floor, .Floor, .Floor, .Floor, .Floor, .Wall,
		.Wall, .Floor, .Wall, .Wall, .Wall, .Floor, .Floor, .Floor, .Floor, .Wall, .Wall, .Wall, .Wall,
		.Wall, .Floor, .Wall, .Wall, .Wall, .Floor, .Floor, .Floor, .Floor, .Wall, .Wall, .Wall, .Wall,
		.Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall,
	},
}

// LIBRARY: Study with shelving
// Layout:
//   #########
//   #.#.#.#.#
//   #.#.#.#.#
//   #.......#
//   #.#.#.#.#
//   #.#.#.#.#
//   #########
PREFAB_LIBRARY := PrefabTemplate{
	name = "Library",
	width = 9, height = 7,
	tiles = []Tile_Type{
		.Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall,
		.Wall, .Floor, .Wall, .Floor, .Wall, .Floor, .Wall, .Floor, .Wall,
		.Wall, .Floor, .Wall, .Floor, .Wall, .Floor, .Wall, .Floor, .Wall,
		.Wall, .Floor, .Floor, .Floor, .Floor, .Floor, .Floor, .Floor, .Wall,
		.Wall, .Floor, .Wall, .Floor, .Wall, .Floor, .Wall, .Floor, .Wall,
		.Wall, .Floor, .Wall, .Floor, .Wall, .Floor, .Wall, .Floor, .Wall,
		.Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall,
	},
}

// ARMORY: Weapon storage with racks
// Layout:
//   #########
//   #.......#
//   ###.###.#
//   #.......#
//   #.###.###
//   #.......#
//   #########
PREFAB_ARMORY := PrefabTemplate{
	name = "Armory",
	width = 9, height = 7,
	tiles = []Tile_Type{
		.Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall,
		.Wall, .Floor, .Floor, .Floor, .Floor, .Floor, .Floor, .Floor, .Wall,
		.Wall, .Wall, .Wall, .Floor, .Wall, .Wall, .Wall, .Floor, .Wall,
		.Wall, .Floor, .Floor, .Floor, .Floor, .Floor, .Floor, .Floor, .Wall,
		.Wall, .Floor, .Wall, .Wall, .Wall, .Floor, .Wall, .Wall, .Wall,
		.Wall, .Floor, .Floor, .Floor, .Floor, .Floor, .Floor, .Floor, .Wall,
		.Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall,
	},
}

// SLEEPING_QUARTERS: Dormitory with beds
// Layout:
//   ###########
//   #..#..#..#
//   #..#..#..#
//   #.........#
//   #..#..#..#
//   #..#..#..#
//   ###########
PREFAB_SLEEPING_QUARTERS := PrefabTemplate{
	name = "Sleeping Quarters",
	width = 11, height = 7,
	tiles = []Tile_Type{
		.Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall,
		.Wall, .Floor, .Floor, .Wall, .Floor, .Floor, .Wall, .Floor, .Floor, .Wall, .Wall,
		.Wall, .Floor, .Floor, .Wall, .Floor, .Floor, .Wall, .Floor, .Floor, .Wall, .Wall,
		.Wall, .Floor, .Floor, .Floor, .Floor, .Floor, .Floor, .Floor, .Floor, .Floor, .Wall,
		.Wall, .Floor, .Floor, .Wall, .Floor, .Floor, .Wall, .Floor, .Floor, .Wall, .Wall,
		.Wall, .Floor, .Floor, .Wall, .Floor, .Floor, .Wall, .Floor, .Floor, .Wall, .Wall,
		.Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall, .Wall,
	},
}

// PREFAB REGISTRY: All available prefabs
// Add new prefabs here to make them available for placement
get_all_prefabs :: proc() -> [dynamic]PrefabTemplate {
	prefabs := make([dynamic]PrefabTemplate)
	append(&prefabs, PREFAB_BOSS_ROOM)
	append(&prefabs, PREFAB_TREASURE_VAULT)
	append(&prefabs, PREFAB_GUARD_CHAMBER)
	append(&prefabs, PREFAB_THRONE_ROOM)
	append(&prefabs, PREFAB_LIBRARY)
	append(&prefabs, PREFAB_ARMORY)
	append(&prefabs, PREFAB_SLEEPING_QUARTERS)
	return prefabs
}

// place_prefab carves a prefab into the dungeon at (x, y)
// Overwrites tiles; doesn't check for conflicts (that's caller's job)
//
// Parameters:
//   dungeon: Dungeon to carve into
//   prefab: PrefabTemplate to place
//   x, y: Top-left corner position
//
// Returns success: true if fully placed, false if out of bounds
place_prefab :: proc(dungeon: ^Dungeon_Map, prefab: PrefabTemplate, x, y: int) -> bool {
	// Check bounds
	if x + prefab.width > dungeon.width || y + prefab.height > dungeon.height {
		return false  // Doesn't fit
	}

	// Copy prefab tiles into dungeon
	for py in 0..<prefab.height {
		for px in 0..<prefab.width {
			src_idx := py * prefab.width + px
			dungeon.tiles[y + py][x + px] = prefab.tiles[src_idx]
		}
	}

	return true
}

// place_random_prefabs scatters N random prefabs into the dungeon
// Simple placement: tries random positions, skips if doesn't fit
// No overlap checking (advanced feature for later)
//
// Parameters:
//   dungeon: Dungeon to fill
//   count: How many prefabs to place (may place fewer if space constrained)
//
// Returns number of prefabs actually placed
place_random_prefabs :: proc(dungeon: ^Dungeon_Map, count: int) -> int {
	prefabs := get_all_prefabs()
	defer delete(prefabs)

	placed := 0
	attempts := 0
	max_attempts := count * 10  // Try harder to place them

	for placed < count && attempts < max_attempts {
		attempts += 1

		// Pick random prefab
		prefab_idx := rand.int_max(len(prefabs))
		prefab := prefabs[prefab_idx]

		// Pick random position
		px := rand.int_max(dungeon.width - prefab.width)
		py := rand.int_max(dungeon.height - prefab.height)

		// Try to place
		if place_prefab(dungeon, prefab, px, py) {
			placed += 1
		}
	}

	return placed
}

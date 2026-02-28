package dungeon_visualizer

import "core:math/rand"
import "core:os"
import "core:fmt"
import "core:strings"

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
// Custom prefabs can be created with the interactive editor (E key) and are
// saved to prefabs/*.prefab files. get_all_prefabs() loads both hardcoded
// and disk-based prefabs into a single catalog.
// =============================================================================

PrefabTemplate :: struct {
	name: cstring,
	width, height: int,
	tiles: []Tile_Type,  // Linear array; access as tiles[y * width + x]
}

// make_prefab allocates a heap-owned PrefabTemplate from row-major tile data.
// All templates returned by get_all_prefabs() are heap-owned and must be
// freed via free_prefab_catalog().
make_prefab :: proc(name: cstring, width, height: int, args: ..Tile_Type) -> PrefabTemplate {
	tiles := make([]Tile_Type, width * height)
	for i in 0..<min(len(args), width * height) {
		tiles[i] = args[i]
	}
	return PrefabTemplate{name = name, width = width, height = height, tiles = tiles}
}

// free_prefab_catalog frees all tile slices and the catalog array itself.
// Call this wherever get_all_prefabs() result goes out of scope.
// Do NOT call delete() on the catalog directly — that leaks the tile slices.
free_prefab_catalog :: proc(prefabs: [dynamic]PrefabTemplate) {
	for p in prefabs {
		delete(p.tiles)
	}
	delete(prefabs)
}

// =============================================================================
// PREFAB CATALOG
// =============================================================================
// Each prefab shows ASCII art first, then tile definition.
// ASCII: # = Wall, . = Floor
//
// These are the hardcoded built-in prefabs. Custom prefabs from the editor
// are loaded from prefabs/*.prefab files at generation time.
// =============================================================================

// BOSS_ROOM: Grand open chamber
// Layout:
//   #########
//   #.......#
//   #.......#
//   #...@...#  (@=boss spawn)
//   #.......#
//   #.......#
//   #########
W :: Tile_Type.Wall
F :: Tile_Type.Floor

// get_all_prefabs returns the full prefab catalog: hardcoded built-ins plus
// any .prefab files found in the prefabs/ directory.
//
// All returned PrefabTemplate.tiles slices are heap-allocated.
// Caller MUST free with free_prefab_catalog() to avoid leaking tile memory.
get_all_prefabs :: proc() -> [dynamic]PrefabTemplate {
	prefabs := make([dynamic]PrefabTemplate)

	// Built-in prefabs — constructed via make_prefab() so tiles are heap-owned
	// and uniformly freeable alongside disk-loaded prefabs.

	// Boss Room: 9×7 open grand chamber
	append(&prefabs, make_prefab("Boss Room", 9, 7,
		W, W, W, W, W, W, W, W, W,
		W, F, F, F, F, F, F, F, W,
		W, F, F, F, F, F, F, F, W,
		W, F, F, F, F, F, F, F, W,
		W, F, F, F, F, F, F, F, W,
		W, F, F, F, F, F, F, F, W,
		W, W, W, W, W, W, W, W, W,
	))

	// Treasure Vault: 9×6 compact protected chamber
	append(&prefabs, make_prefab("Treasure Vault", 9, 6,
		W, W, W, W, W, W, W, W, W,
		W, F, F, F, F, F, F, F, W,
		W, F, F, F, F, F, F, F, W,
		W, F, F, F, F, F, F, F, W,
		W, F, F, F, F, F, F, F, W,
		W, W, W, W, W, W, W, W, W,
	))

	// Guard Chamber: 11×7 room with alcoves
	//   ###########
	//   #...#...#.#
	//   #...#...#.#
	//   #.........#
	//   #...#...#.#
	//   #...#...#.#
	//   ###########
	append(&prefabs, make_prefab("Guard Chamber", 11, 7,
		W, W, W, W, W, W, W, W, W, W, W,
		W, F, F, F, W, F, F, F, W, F, W,
		W, F, F, F, W, F, F, F, W, F, W,
		W, F, F, F, F, F, F, F, F, F, W,
		W, F, F, F, W, F, F, F, W, F, W,
		W, F, F, F, W, F, F, F, W, F, W,
		W, W, W, W, W, W, W, W, W, W, W,
	))

	// Throne Room: 13×7 long chamber with raised dais
	//   #############
	//   #.....#.....#
	//   #.....#.....#
	//   #.....#.....#
	//   #.###.....###
	//   #.###.....###
	//   #############
	append(&prefabs, make_prefab("Throne Room", 13, 7,
		W, W, W, W, W, W, W, W, W, W, W, W, W,
		W, F, F, F, F, F, W, F, F, F, F, F, W,
		W, F, F, F, F, F, W, F, F, F, F, F, W,
		W, F, F, F, F, F, W, F, F, F, F, F, W,
		W, F, W, W, W, F, F, F, F, W, W, W, W,
		W, F, W, W, W, F, F, F, F, W, W, W, W,
		W, W, W, W, W, W, W, W, W, W, W, W, W,
	))

	// Library: 9×7 with reading alcoves (pillar pattern)
	//   #########
	//   #.#.#.#.#
	//   #.#.#.#.#
	//   #.......#
	//   #.#.#.#.#
	//   #.#.#.#.#
	//   #########
	append(&prefabs, make_prefab("Library", 9, 7,
		W, W, W, W, W, W, W, W, W,
		W, F, W, F, W, F, W, F, W,
		W, F, W, F, W, F, W, F, W,
		W, F, F, F, F, F, F, F, W,
		W, F, W, F, W, F, W, F, W,
		W, F, W, F, W, F, W, F, W,
		W, W, W, W, W, W, W, W, W,
	))

	// Armory: 9×7 with weapon racks (horizontal barriers)
	//   #########
	//   #.......#
	//   ###.###.#
	//   #.......#
	//   #.###.###
	//   #.......#
	//   #########
	append(&prefabs, make_prefab("Armory", 9, 7,
		W, W, W, W, W, W, W, W, W,
		W, F, F, F, F, F, F, F, W,
		W, W, W, F, W, W, W, F, W,
		W, F, F, F, F, F, F, F, W,
		W, F, W, W, W, F, W, W, W,
		W, F, F, F, F, F, F, F, W,
		W, W, W, W, W, W, W, W, W,
	))

	// Sleeping Quarters: 11×7 dormitory with bunk alcoves
	//   ###########
	//   #..#..#..##
	//   #..#..#..##
	//   #.........#
	//   #..#..#..##
	//   #..#..#..##
	//   ###########
	append(&prefabs, make_prefab("Sleeping Quarters", 11, 7,
		W, W, W, W, W, W, W, W, W, W, W,
		W, F, F, W, F, F, W, F, F, W, W,
		W, F, F, W, F, F, W, F, F, W, W,
		W, F, F, F, F, F, F, F, F, F, W,
		W, F, F, W, F, F, W, F, F, W, W,
		W, F, F, W, F, F, W, F, F, W, W,
		W, W, W, W, W, W, W, W, W, W, W,
	))

	// Disk-loaded custom prefabs from prefabs/*.prefab
	disk := load_prefabs_from_disk()
	for p in disk { append(&prefabs, p) }
	delete(disk)  // array only; tiles now owned by prefabs entries

	return prefabs
}

// load_prefabs_from_disk scans the prefabs/ directory for *.prefab files
// and returns them as heap-allocated PrefabTemplates.
// Returns an empty array (not nil) if the directory doesn't exist or is empty.
//
// .prefab file format:
//   { "name": "...", "width": N, "height": N, "tiles": "WWFF..." }
load_prefabs_from_disk :: proc() -> [dynamic]PrefabTemplate {
	result := make([dynamic]PrefabTemplate)

	handle, err := os.open("prefabs")
	if err != nil { return result }
	defer os.close(handle)

	entries, read_err := os.read_dir(handle, -1, context.allocator)
	if read_err != nil { return result }
	defer os.file_info_slice_delete(entries, context.allocator)

	for entry in entries {
		if !strings.has_suffix(entry.name, ".prefab") { continue }

		path := fmt.tprintf("prefabs/%s", entry.name)
		data, file_err := os.read_entire_file_from_path(path, context.allocator)
		if file_err != nil { continue }
		defer delete(data)

		content := string(data)
		name    := extract_string_field(content, "name")
		w       := extract_int_field(content, "width")
		h       := extract_int_field(content, "height")
		tiles_s := extract_string_field(content, "tiles")

		if w <= 0 || h <= 0 || len(tiles_s) < w * h { continue }

		// Decode tile string into a temporary slice, then copy via make_prefab
		tile_args := make([]Tile_Type, w * h)
		defer delete(tile_args)
		for i in 0..<w*h {
			tile_args[i] = tiles_s[i] == 'F' ? .Floor : .Wall
		}

		// Clone the name string — it points into `data` which is deferred-freed
		name_c := strings.clone_to_cstring(name)
		append(&result, make_prefab(name_c, w, h, ..tile_args))
	}

	return result
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

// place_random_prefabs scatters N random prefabs into the dungeon.
// Simple placement: tries random positions, skips if doesn't fit.
// No overlap checking (prefabs can overlap, creating interesting merged shapes).
//
// Parameters:
//   dungeon: Dungeon to fill
//   count: How many prefabs to place (may place fewer if space constrained)
//
// Returns number of prefabs actually placed
place_random_prefabs :: proc(dungeon: ^Dungeon_Map, count: int) -> int {
	prefabs := get_all_prefabs()
	defer free_prefab_catalog(prefabs)  // frees tile slices + array

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

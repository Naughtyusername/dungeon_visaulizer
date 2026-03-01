package dungeon_visualizer

import "core:math/rand"

// =============================================================================
// HYBRID DUNGEON GENERATION
// =============================================================================
// Combines multiple algorithms in creative ways for richer dungeons.
//
// Current Strategy: CA Caves + BSP Rooms + Explicit Corridors
//   1. Generate organic CA caves as base
//   2. Place BSP-structured rooms inside the cave system
//   3. Connect rooms with explicit corridors using corridor carver
//   4. Validate connectivity to ensure playability
//
// Result: Natural cave aesthetics with structured, organized rooms.
// Great for: Underground bases, hybrid outdoor/indoor locations
//
// Extensible: Can mix any algorithms (DW + BSP, CA + DW, etc.)
// =============================================================================

HybridConfig :: struct {
	ca_config: CA_Config,           // Cave generation settings
	bsp_config: BSP_Config,         // Room placement settings
	corridor_config: CorridorConfig, // Corridor carving style
	room_density: f32,              // 0.0-1.0: how many CA tiles become rooms
	validate: bool,                 // Check connectivity after generation
}

HYBRID_DEFAULT_CONFIG :: HybridConfig{
	ca_config = CA_DEFAULT_CONFIG,
	bsp_config = BSP_DEFAULT_CONFIG,
	corridor_config = CORRIDOR_DEFAULT_CONFIG,
	room_density = 0.3,  // Use ~30% of cave space for structured rooms
	validate = true,     // Ensure playable
}

// make_dungeon_hybrid creates a hybrid CA+BSP+Corridor dungeon
// Strategy:
//   1. Generate CA cave system (organic base)
//   2. Build BSP tree for room placement
//   3. Create rooms only in cave areas (filtered by room_density)
//   4. Connect rooms with explicit corridors
//   5. Validate connectivity if requested
//
// Returns Dungeon_Map with hybrid algorithm characteristics
make_dungeon_hybrid :: proc(config := HYBRID_DEFAULT_CONFIG) -> Dungeon_Map {
	// Phase 1: Generate CA cave system as foundation
	dungeon := make_dungeon_ca(config.ca_config)

	// Save the cave system (we'll merge rooms into it)
	cave_backup := make([][]Tile_Type, dungeon.height)
	for y in 0..<dungeon.height {
		cave_backup[y] = make([]Tile_Type, dungeon.width)
		for x in 0..<dungeon.width {
			cave_backup[y][x] = dungeon.tiles[y][x]
		}
	}
	defer {
		for y in 0..<dungeon.height { delete(cave_backup[y]) }
		delete(cave_backup)
	}

	// Phase 2: Generate BSP room structure
	root := bsp_build(1, 1, MAP_WIDTH - 2, MAP_HEIGHT - 2, config.bsp_config)
	defer bsp_free(root)

	// Phase 3: Create rooms, but only if they fit in cave areas
	hybrid_create_rooms_in_caves(root, &dungeon, cave_backup, config.room_density)

	// Phase 4: Connect rooms with explicit corridors
	if len(dungeon.rooms) >= 2 {
		carve_corridors_between_rooms(&dungeon, dungeon.rooms, config.corridor_config)
	}

	// Phase 5: Validate connectivity
	if config.validate {
		val_result := validate_connectivity(&dungeon, MAP_WIDTH / 2, MAP_HEIGHT / 2, true)
		// Result unused but validation cleans up isolated regions
		_ = val_result
	}

	// Place doors at corridor-room chokepoints
	place_doors(&dungeon)

	return dungeon
}

// hybrid_create_rooms_in_caves places BSP rooms only in cave areas
// Walks the BSP tree, creates rooms in leaf nodes, but only carves
// if the room center is in a cave floor tile (from CA backup)
//
// This merges structured rooms into organic caves naturally.
// room_density controls how many potential rooms are actually placed.
hybrid_create_rooms_in_caves :: proc(
	node: ^BSP_Node,
	dungeon: ^Dungeon_Map,
	cave_backup: [][]Tile_Type,
	room_density: f32,
) {
	if node == nil {
		return
	}

	if node.left != nil || node.right != nil {
		// Interior node: recurse
		hybrid_create_rooms_in_caves(node.left, dungeon, cave_backup, room_density)
		hybrid_create_rooms_in_caves(node.right, dungeon, cave_backup, room_density)
	} else {
		// Leaf node: maybe create a room

		// Room sizing (same as BSP)
		room_w := clamp(node.w - 2, 4, node.w)
		room_h := clamp(node.h - 2, 4, node.h)
		room_x := node.x + (node.w > room_w ? rand.int_max(node.w - room_w) : 0)
		room_y := node.y + (node.h > room_h ? rand.int_max(node.h - room_h) : 0)

		// Check if room center is in a cave area
		room_center_x := room_x + room_w / 2
		room_center_y := room_y + room_h / 2

		// Skip room if:
		//   1. Center isn't in a cave
		//   2. Random density check fails
		if cave_backup[room_center_y][room_center_x] == .Wall {
			return  // Not in cave system
		}
		if rand.float32() > room_density {
			return  // Random density rejection
		}

		// Carve the room (overwrite cave if needed)
		room := Room{x = room_x, y = room_y, w = room_w, h = room_h}
		append(&dungeon.rooms, room)
		node.room = room

		// Carve room tiles to floor
		for ry in room_y..<room_y + room_h {
			for rx in room_x..<room_x + room_w {
				dungeon.tiles[ry][rx] = .Floor
			}
		}
	}
}

// Hybrid variants (extensible for future combinations):
// make_dungeon_hybrid_dw_bsp() could do: Drunkard's Walk cave + BSP rooms
// make_dungeon_hybrid_ca_dw() could do: CA cave + Drunkard's Walk carving
// etc.

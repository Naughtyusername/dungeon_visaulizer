package dungeon_visualizer

// =============================================================================
// DUNGEON CORE TYPES & CONSTANTS
// =============================================================================
// This file defines all shared dungeon structures and grid constants.
// All other generator modules depend on these definitions.
// =============================================================================

// Grid dimensions in tiles (80x45 grid)
MAP_WIDTH  :: 80
MAP_HEIGHT :: 45

// Pixel size per tile (16x16 pixels)
TILE_SIZE  :: 16

// Screen dimensions in pixels (1280x720)
SCREEN_W   :: MAP_WIDTH  * TILE_SIZE   // 1280
SCREEN_H   :: MAP_HEIGHT * TILE_SIZE   // 720

// For Drunkard's Walk: target floor coverage = 35% of all tiles
// Calculated as integer to match generation logic
FLOOR_TARGET :: int(f32(MAP_WIDTH * MAP_HEIGHT) * 0.35)

// Tile_Type enum defines dungeon cell states
// Wall=0 (zero-initialized), Floor=1
// Critical: zero-initialization means freshly allocated grids are all Walls
// Do NOT reorder enum — breaks assumptions throughout generators
Tile_Type :: enum { Wall, Floor }

// Room_Type gives semantic meaning to BSP rooms for game design purposes.
// Critical: Normal MUST be the zero value (first entry) so all Room{} literals
// default to .Normal without explicit initialization — same invariant as Tile_Type.Wall.
// Do NOT reorder.
Room_Type :: enum {
	Normal,   // Zero value — untagged default
	Boss,     // One per dungeon, the largest room
	Treasure, // Mid-sized rooms, configurable count
	Safe,     // Randomly selected from remaining rooms
}

// Room represents a rectangular area (e.g., BSP leaf nodes, prefab placements)
// x, y = top-left corner
// w, h = width and height in tiles
// kind: semantic type assigned by tag_rooms() — defaults to .Normal
Room :: struct { x, y, w, h: int, kind: Room_Type }

// Dungeon_Map is the main state container for a complete dungeon
// tiles:        2D grid of Tile_Type (height × width) — row-major order
// width/height: map dimensions in tiles (always MAP_WIDTH, MAP_HEIGHT for now)
// rooms:        dynamic array of Room structs placed during generation
//               (BSP stores rooms here, CA doesn't use it, Drunkard's Walk doesn't use it)
//
// Memory layout: tiles[y][x] where y=row, x=column
// Critical: always use [y][x] ordering, never [x][y]
Dungeon_Map :: struct {
	tiles:         [][]Tile_Type,  // 2D array: [height][width]
	width, height: int,            // Dimensions (80, 45)
	rooms:         [dynamic]Room,  // Algorithm-specific room data
}

package dungeon_visualizer

import rl "vendor:raylib"
import "core:math/rand"
import "core:slice"

// =============================================================================
// ROOM TYPE TAGGING SYSTEM
// =============================================================================
// Assigns semantic Room_Type values (Boss, Treasure, Safe) to BSP room geometry.
// This is a post-generation semantic pass — BSP stays pure geometry, tagging
// is a separate concern applied on top of already-generated room data.
//
// Only meaningful for BSP dungeons (the only algorithm that populates dungeon.rooms).
// Non-BSP dungeons have zero rooms: tag_rooms() detects this and returns valid=false,
// and draw_room_tags() silently skips rendering. No special-casing needed at call sites.
//
// Usage:
//   - Call tag_rooms() after dungeon generation (and after bsp_free, rooms persist)
//   - Call draw_room_tags() in render loop, right after draw_dungeon()
//   - Call free_room_tags() at cleanup (lifecycle consistency; no heap currently)
// =============================================================================

// Room_Tags is the result handle for a tagging pass.
// valid=false means tagging was skipped (non-BSP dungeon with no rooms).
Room_Tags :: struct {
	valid: bool,
}

// Room_Tags_Config controls how many rooms of each secondary type to assign.
// Boss is always exactly 1 (the largest room), so it is not configurable.
Room_Tags_Config :: struct {
	treasure_count: int, // Number of mid-sized rooms to tag as Treasure
	safe_count:     int, // Number of random remaining rooms to tag as Safe
}

ROOM_TAGS_DEFAULT_CONFIG :: Room_Tags_Config{
	treasure_count = 2,
	safe_count     = 1,
}

// tag_rooms assigns Room_Type values to rooms in dungeon.rooms in-place.
// Strategy:
//   1. Build scratch index pairs {area, original_index} — preserves dungeon.rooms order
//   2. Sort descending by area (largest first)
//   3. Largest room → Boss; next treasure_count → Treasure
//   4. Fisher-Yates shuffle remainder; pick safe_count → Safe
//   5. All others remain .Normal (zero value, no explicit assignment needed)
//
// Parameters:
//   dungeon: BSP-generated dungeon with rooms populated
//   config:  Counts for Treasure and Safe room types
//
// Returns Room_Tags with valid=true if tagging succeeded, valid=false if no rooms
tag_rooms :: proc(dungeon: ^Dungeon_Map, config := ROOM_TAGS_DEFAULT_CONFIG) -> Room_Tags {
	if len(dungeon.rooms) == 0 {
		return Room_Tags{valid = false}
	}

	// Reset all rooms to Normal before tagging (important on re-generation)
	for i in 0..<len(dungeon.rooms) {
		dungeon.rooms[i].kind = .Normal
	}

	// Build scratch pairs: {area, original_index}
	// We sort the scratch, not dungeon.rooms, to preserve canonical room order
	pairs := make([dynamic][2]int, len(dungeon.rooms))
	defer delete(pairs)

	for i in 0..<len(dungeon.rooms) {
		room := dungeon.rooms[i]
		pairs[i] = {room.w * room.h, i}
	}

	// Sort descending by area (largest first) using core:slice
	slice.sort_by(pairs[:], proc(a, b: [2]int) -> bool {
		return a[0] > b[0]
	})

	// Assign Boss to the largest room
	dungeon.rooms[pairs[0][1]].kind = .Boss

	// Assign Treasure to next N rooms (clamped so we don't exceed available rooms)
	treasure_end := min(1 + config.treasure_count, len(pairs))
	for i in 1..<treasure_end {
		dungeon.rooms[pairs[i][1]].kind = .Treasure
	}

	// Collect remaining indices into a pool for Safe assignment
	remaining := make([dynamic]int)
	defer delete(remaining)
	for i in treasure_end..<len(pairs) {
		append(&remaining, pairs[i][1])
	}

	// Fisher-Yates shuffle remaining pool
	for i := len(remaining) - 1; i > 0; i -= 1 {
		j := rand.int_max(i + 1)
		remaining[i], remaining[j] = remaining[j], remaining[i]
	}

	// Assign Safe from shuffled remainder (clamped)
	safe_end := min(config.safe_count, len(remaining))
	for i in 0..<safe_end {
		dungeon.rooms[remaining[i]].kind = .Safe
	}

	return Room_Tags{valid = true}
}

// draw_room_tags renders colored outlines on tagged rooms (Boss/Treasure/Safe).
// Normal rooms are skipped entirely — no visual noise on untagged geometry.
// Outlines use semi-transparent colors (alpha 200) so tile detail remains visible.
//
// Visual language:
//   - Boss:     Red outline    + "B" label — danger, final encounter
//   - Treasure: Gold outline   + "T" label — reward
//   - Safe:     Green outline  + "S" label — rest point
//
// Parameters:
//   dungeon: Dungeon with rooms tagged by tag_rooms()
//   tags:    Result from tag_rooms(); draw is skipped if valid=false
draw_room_tags :: proc(dungeon: ^Dungeon_Map, tags: Room_Tags) {
	if !tags.valid {
		return
	}

	OUTLINE_THICKNESS :: f32(3)

	BOSS_COLOR     :: rl.Color{220,  50,  50, 200}
	TREASURE_COLOR :: rl.Color{200, 180,   0, 200}
	SAFE_COLOR     :: rl.Color{ 50, 200,  50, 200}

	for room in dungeon.rooms {
		color: rl.Color
		label: cstring
		switch room.kind {
		case .Normal:
			continue  // Skip — no annotation for untagged rooms
		case .Boss:
			color = BOSS_COLOR
			label = "B"
		case .Treasure:
			color = TREASURE_COLOR
			label = "T"
		case .Safe:
			color = SAFE_COLOR
			label = "S"
		}

		// Convert tile coordinates to pixel rectangle
		rect := rl.Rectangle{
			x      = f32(room.x * TILE_SIZE),
			y      = f32(room.y * TILE_SIZE),
			width  = f32(room.w * TILE_SIZE),
			height = f32(room.h * TILE_SIZE),
		}

		// Draw colored outline only (tiles remain visible through the overlay)
		rl.DrawRectangleLinesEx(rect, OUTLINE_THICKNESS, color)

		// Draw single-character label at top-left corner of room, inset by 4px
		label_x := i32(room.x * TILE_SIZE) + 4
		label_y := i32(room.y * TILE_SIZE) + 4
		rl.DrawText(label, label_x, label_y, 14, color)
	}
}

// free_room_tags releases room tag state.
// No heap memory currently, but the proc exists for lifecycle consistency —
// every system that has a "place/tag" proc has a matching "free" proc.
// If Room_Tags grows heap fields later, this is the right place to free them.
free_room_tags :: proc(tags: ^Room_Tags) {
	tags.valid = false
}

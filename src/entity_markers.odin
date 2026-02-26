package dungeon_visualizer

import rl "vendor:raylib"
import "core:math/rand"

// =============================================================================
// ENTITY MARKERS (ENEMIES & TREASURE)
// =============================================================================
// Marks strategic gameplay locations for game design:
// - Enemy encounter zones: where enemies spawn/patrol
// - Treasure chests: where loot is hidden
//
// Placement ensures markers don't overlap spawn points (player start/goal),
// giving designers clear safe zones vs danger zones.
//
// Usage:
//   - Call place_entity_markers() after dungeon generation
//   - Call draw_entity_markers() in render loop
//   - Call free_entity_markers() at cleanup
//   - Export with dungeon via export_dungeon()
// =============================================================================

EntityType :: enum {
	Enemy,
	Treasure,
}

EntityMarker :: struct {
	x, y: int,
	kind: EntityType,
}

EntityMarkers :: struct {
	markers: [dynamic]EntityMarker,
	valid:   bool,
}

EntityConfig :: struct {
	enemy_count:    int,  // Number of enemy markers to place
	treasure_count: int,  // Number of treasure markers to place
}

ENTITY_DEFAULT_CONFIG :: EntityConfig{
	enemy_count = 5,
	treasure_count = 3,
}

// place_entity_markers distributes enemy and treasure markers across the dungeon
// Strategy:
//   1. Collect all floor tiles into a candidate pool
//   2. Exclude tiles within 3-tile radius of start AND end spawn points
//   3. Shuffle candidates using Fisher-Yates
//   4. Assign first N tiles as enemies, next M as treasure
//   5. Return EntityMarkers with valid=true if placement succeeded
//
// Parameters:
//   dungeon: Generated dungeon to mark
//   spawn:   Spawn points (to avoid overlapping markers with player start/goal)
//   config:  EntityConfig with enemy_count and treasure_count
//
// Returns EntityMarkers with all markers placed or valid=false if insufficient space
place_entity_markers :: proc(
	dungeon: ^Dungeon_Map,
	spawn: SpawnPoints,
	config := ENTITY_DEFAULT_CONFIG,
) -> EntityMarkers {
	result := EntityMarkers{valid = false}

	// Collect floor tiles that are safe (not near spawn points)
	candidates := make([dynamic][2]int)
	defer delete(candidates)

	SAFE_RADIUS :: 3  // Don't place markers within this distance of start/end

	for y in 0..<dungeon.height {
		for x in 0..<dungeon.width {
			if dungeon.tiles[y][x] == .Floor {
				// Check distance to start point
				dist_to_start := abs(x - spawn.start_x) + abs(y - spawn.start_y)
				// Check distance to end point
				dist_to_end := abs(x - spawn.end_x) + abs(y - spawn.end_y)

				// Mark as candidate only if far from both spawn points
				if dist_to_start >= SAFE_RADIUS && dist_to_end >= SAFE_RADIUS {
					append(&candidates, [2]int{x, y})
				}
			}
		}
	}

	// Need enough space for requested markers
	total_needed := config.enemy_count + config.treasure_count
	if len(candidates) < total_needed {
		return result  // Not enough safe floor space
	}

	// Shuffle candidates (Fisher-Yates)
	for i := len(candidates) - 1; i > 0; i -= 1 {
		j := rand.int_max(i + 1)
		candidates[i], candidates[j] = candidates[j], candidates[i]
	}

	// Assign enemies from first N candidates
	for i in 0..<config.enemy_count {
		pos := candidates[i]
		append(&result.markers, EntityMarker{x = pos.x, y = pos.y, kind = .Enemy})
	}

	// Assign treasure from next M candidates
	for i in 0..<config.treasure_count {
		pos := candidates[config.enemy_count + i]
		append(&result.markers, EntityMarker{x = pos.x, y = pos.y, kind = .Treasure})
	}

	result.valid = true
	return result
}

// draw_entity_markers renders enemy and treasure markers on the dungeon
// Draws centered squares with appropriate colors and labels
// Uses same coordinate centering as spawn points from renderer.odin
//
// Markers:
//   - Enemy:   Orange fill + dark orange border + "E" text label
//   - Treasure: Gold fill + yellow border + "T" text label
//
// Parameters:
//   markers: EntityMarkers result from place_entity_markers()
draw_entity_markers :: proc(markers: EntityMarkers) {
	if !markers.valid {
		return
	}

	MARKER_SIZE :: 16  // Entity marker size (larger than spawn points for visibility)
	ENEMY_COLOR :: rl.Color{255, 165, 0, 255}    // Orange
	ENEMY_OUTLINE :: rl.Color{200, 100, 0, 255}  // Dark orange
	TREASURE_COLOR :: rl.GOLD                     // Gold
	TREASURE_OUTLINE :: rl.YELLOW                 // Yellow

	for marker in markers.markers {
		// Center marker on tile like spawn points do
		px := i32(marker.x * TILE_SIZE + TILE_SIZE / 2 - MARKER_SIZE / 2)
		py := i32(marker.y * TILE_SIZE + TILE_SIZE / 2 - MARKER_SIZE / 2)

		switch marker.kind {
		case .Enemy:
			rl.DrawRectangle(px, py, i32(MARKER_SIZE), i32(MARKER_SIZE), ENEMY_COLOR)
			rl.DrawRectangleLines(px - 2, py - 2, i32(MARKER_SIZE + 4), i32(MARKER_SIZE + 4), ENEMY_OUTLINE)
			// Label above marker
			label_x := px + i32(MARKER_SIZE / 2) - 6
			label_y := py - 18
			rl.DrawText("E", label_x, label_y, 14, rl.WHITE)

		case .Treasure:
			rl.DrawRectangle(px, py, i32(MARKER_SIZE), i32(MARKER_SIZE), TREASURE_COLOR)
			rl.DrawRectangleLines(px - 2, py - 2, i32(MARKER_SIZE + 4), i32(MARKER_SIZE + 4), TREASURE_OUTLINE)
			// Label above marker
			label_x := px + i32(MARKER_SIZE / 2) - 6
			label_y := py - 18
			rl.DrawText("T", label_x, label_y, 14, rl.WHITE)
		}
	}
}

// free_entity_markers releases dynamically allocated marker storage
// Call during cleanup phase
free_entity_markers :: proc(markers: ^EntityMarkers) {
	delete(markers.markers)
	markers.valid = false
}

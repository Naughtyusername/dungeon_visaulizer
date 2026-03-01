package dungeon_visualizer

// =============================================================================
// DOOR PLACEMENT
// =============================================================================
// Automatically detects corridor chokepoints and places doors there.
// A chokepoint is a floor tile with passable tiles on exactly two opposite
// sides (N+S or E+W) and walls on the other two sides — the classic
// "single-tile corridor" entry to a room.
//
// Only called for structured algorithms (BSP, Hybrid, Prefab) where corridors
// and rooms are distinct. Organic cave algorithms (DW, CA) are left door-free.
//
// Candidates are collected in a scratch array before any tiles are written,
// so scan order doesn't affect which tiles qualify (no cascade effects where
// one placed door changes a neighbor's eligibility mid-scan).
//
// Usage:
//   place_doors(&dungeon)  // call after corridors are carved, before return
// =============================================================================

// place_doors scans the dungeon for corridor chokepoints and converts them
// to Door tiles in-place.
//
// A tile qualifies if:
//   1. It is currently .Floor
//   2. Exactly two of its cardinal neighbors are passable (Floor or Door)
//   3. Those two passable neighbors are on the same axis (both N+S or both E+W)
//   4. The remaining two cardinal neighbors are .Wall
//
// Parameters:
//   dungeon: Dungeon to process (BSP/Hybrid/Prefab — not DW/CA)
place_doors :: proc(dungeon: ^Dungeon_Map) {
	// Collect first, then apply — prevents a placed door from disqualifying
	// an adjacent tile that would also be a valid door
	candidates := make([dynamic][2]int)
	defer delete(candidates)

	// Skip the outer border row/column (always wall, never a door)
	for y in 1..<dungeon.height - 1 {
		for x in 1..<dungeon.width - 1 {
			if is_door_location(dungeon, x, y) {
				append(&candidates, [2]int{x, y})
			}
		}
	}

	for pos in candidates {
		dungeon.tiles[pos[1]][pos[0]] = .Door
	}
}

// is_door_location returns true if (x, y) is a valid chokepoint door location.
// Checks for the classic corridor pinch: passable on N+S xor E+W, wall on the other pair.
is_door_location :: proc(dungeon: ^Dungeon_Map, x, y: int) -> bool {
	if dungeon.tiles[y][x] != .Floor {
		return false
	}

	// A tile is "passable" if it's floor or door (not wall)
	n := dungeon.tiles[y-1][x] != .Wall
	s := dungeon.tiles[y+1][x] != .Wall
	e := dungeon.tiles[y][x+1] != .Wall
	w := dungeon.tiles[y][x-1] != .Wall

	// Vertical chokepoint: open north and south, walled east and west
	if n && s && !e && !w { return true }
	// Horizontal chokepoint: open east and west, walled north and south
	if e && w && !n && !s { return true }

	return false
}

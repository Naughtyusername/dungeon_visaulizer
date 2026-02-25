package dungeon_visualizer

import "core:math/rand"
import "core:time"

Walker :: struct { x, y: int }

make_dungeon :: proc() -> Dungeon_Map {
	t := time.now()._nsec
	rand.reset(u64(t))

	dungeon := Dungeon_Map{
		width  = MAP_WIDTH,
		height = MAP_HEIGHT,
		rooms  = make([dynamic]Room),
	}
	dungeon.tiles = make([][]Tile_Type, MAP_HEIGHT)
	for y in 0..<MAP_HEIGHT {
		dungeon.tiles[y] = make([]Tile_Type, MAP_WIDTH)
		// zero-initialized = all .Wall
	}
	drunkards_walk(&dungeon)
	return dungeon
}

free_dungeon :: proc(d: ^Dungeon_Map) {
	for y in 0..<d.height { delete(d.tiles[y]) }
	delete(d.tiles)
	delete(d.rooms)
}

drunkards_walk :: proc(d: ^Dungeon_Map) {
	walker := Walker{ x = d.width / 2, y = d.height / 2 }
	floor_count := 0

	for floor_count < FLOOR_TARGET {
		if d.tiles[walker.y][walker.x] == .Wall {
			d.tiles[walker.y][walker.x] = .Floor
			floor_count += 1
		}
		dir := rand.int_max(4)  // 0=N 1=E 2=S 3=W
		dx, dy: int
		switch dir {
		case 0: dy = -1
		case 1: dx =  1
		case 2: dy =  1
		case 3: dx = -1
		}
		walker.x = clamp(walker.x + dx, 1, d.width  - 2)
		walker.y = clamp(walker.y + dy, 1, d.height - 2)
	}
}

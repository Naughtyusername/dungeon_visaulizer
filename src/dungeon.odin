package dungeon_visualizer

MAP_WIDTH  :: 80
MAP_HEIGHT :: 45
TILE_SIZE  :: 16
SCREEN_W   :: MAP_WIDTH  * TILE_SIZE   // 1280
SCREEN_H   :: MAP_HEIGHT * TILE_SIZE   // 720
FLOOR_TARGET :: int(f32(MAP_WIDTH * MAP_HEIGHT) * 0.35)

Tile_Type :: enum { Wall, Floor }  // Wall=0, Floor=1

Room :: struct { x, y, w, h: int }

Dungeon_Map :: struct {
	tiles:         [][]Tile_Type,
	width, height: int,
	rooms:         [dynamic]Room,
}

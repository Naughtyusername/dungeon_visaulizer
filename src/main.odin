package dungeon_visualizer

import rl "vendor:raylib"
import "core:fmt"

Algorithm :: enum {
	Drunkards_Walk,
	BSP,
}

main :: proc() {
	rl.InitWindow(SCREEN_W, SCREEN_H, "Dungeon Visualizer")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)

	algorithm := Algorithm.Drunkards_Walk
	dungeon := make_dungeon()
	defer free_dungeon(&dungeon)

	for !rl.WindowShouldClose() {
		if rl.IsKeyPressed(.SPACE) {
			free_dungeon(&dungeon)
			dungeon = make_dungeon_by_algorithm(algorithm)
		}
		if rl.IsKeyPressed(.ONE) {
			free_dungeon(&dungeon)
			algorithm = .Drunkards_Walk
			dungeon = make_dungeon()
		}
		if rl.IsKeyPressed(.TWO) {
			free_dungeon(&dungeon)
			algorithm = .BSP
			dungeon = make_dungeon_bsp()
		}

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		draw_dungeon(&dungeon)

		// Draw mode label
		mode_text := algorithm == .Drunkards_Walk ? "Drunkard's Walk" : "BSP"
		rl.DrawText(
			fmt.ctprintf("%s - Space: Regen | 1: Drunkards | 2: BSP", mode_text),
			10, 10, 20, rl.WHITE,
		)

		rl.EndDrawing()
	}
}

make_dungeon_by_algorithm :: proc(algo: Algorithm) -> Dungeon_Map {
	switch algo {
	case .Drunkards_Walk:
		return make_dungeon()
	case .BSP:
		return make_dungeon_bsp()
	}
	return make_dungeon()
}

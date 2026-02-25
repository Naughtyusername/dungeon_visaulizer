package dungeon_visualizer

import rl "vendor:raylib"
import "core:fmt"

Algorithm :: enum {
	Drunkards_Walk,
	BSP,
	Cellular_Automata,
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
		if rl.IsKeyPressed(.THREE) {
			free_dungeon(&dungeon)
			algorithm = .Cellular_Automata
			dungeon = make_dungeon_ca()
		}

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		draw_dungeon(&dungeon)

		// Draw mode label
		mode_text := algorithm == .Drunkards_Walk ? "Drunkard's Walk" : algorithm == .BSP ? "BSP" : "Cellular Automata"
		rl.DrawText(
			fmt.ctprintf("%s - Space: Regen | 1: DW | 2: BSP | 3: CA", mode_text),
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
	case .Cellular_Automata:
		return make_dungeon_ca()
	}
	return make_dungeon()
}

package dungeon_visualizer

import rl "vendor:raylib"
import "core:fmt"

Algorithm :: enum {
	Drunkards_Walk,      // 1: Classic cave carver
	BSP,                 // 2: Structured room-based
	Cellular_Automata,   // 3: Organic cave generation
	Hybrid,              // 4: CA caves + BSP rooms + explicit corridors
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
		if rl.IsKeyPressed(.FOUR) {
			free_dungeon(&dungeon)
			algorithm = .Hybrid
			dungeon = make_dungeon_hybrid()
		}

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		draw_dungeon(&dungeon)

		// Draw mode label
		mode_text: cstring
		switch algorithm {
		case .Drunkards_Walk:
			mode_text = "Drunkard's Walk"
		case .BSP:
			mode_text = "BSP"
		case .Cellular_Automata:
			mode_text = "Cellular Automata"
		case .Hybrid:
			mode_text = "Hybrid (CA+BSP+Corridors)"
		}

		rl.DrawText(
			fmt.ctprintf("%s - Space: Regen | 1: DW | 2: BSP | 3: CA | 4: Hybrid", mode_text),
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
	case .Hybrid:
		return make_dungeon_hybrid()
	}
	return make_dungeon()
}

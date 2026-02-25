package dungeon_visualizer

import rl "vendor:raylib"

main :: proc() {
	rl.InitWindow(SCREEN_W, SCREEN_H, "Dungeon Visualizer")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)

	dungeon := make_dungeon()
	defer free_dungeon(&dungeon)

	for !rl.WindowShouldClose() {
		if rl.IsKeyPressed(.SPACE) {
			free_dungeon(&dungeon)
			dungeon = make_dungeon()
		}
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		draw_dungeon(&dungeon)
		rl.EndDrawing()
	}
}

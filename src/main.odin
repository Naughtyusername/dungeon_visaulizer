package dungeon_visualizer

import rl "vendor:raylib"
import "core:fmt"
import "core:math/rand"

Algorithm :: enum {
	Drunkards_Walk,      // 1: Classic cave carver
	BSP,                 // 2: Structured room-based
	Cellular_Automata,   // 3: Organic cave generation
	Hybrid,              // 4: CA caves + BSP rooms + explicit corridors
	Prefab,              // 5: Hand-designed room templates scattered
}

main :: proc() {
	rl.InitWindow(SCREEN_W, SCREEN_H, "Dungeon Visualizer")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)

	algorithm := Algorithm.Drunkards_Walk
	dungeon := make_dungeon()
	defer free_dungeon(&dungeon)

	// Gameplay helpers
	spawn := place_spawn_points(&dungeon)
	val_result := validate_connectivity(&dungeon, MAP_WIDTH / 2, MAP_HEIGHT / 2, false)

	// Seed system: manual seed control for reproducible dungeons
	// User can adjust with arrow keys
	seed: u64 = 12345  // Default seed
	use_seed := false  // If true, use manual seed instead of time-based

	// Parameter tuning UI
	// IMPORTANT: Create on heap and initialize in-place so pointers stay valid
	param_panel := new(ParameterPanel)
	defer free(param_panel)
	initialize_parameter_panel(param_panel)

	// Save counter for exported dungeons
	save_count := 0

	for !rl.WindowShouldClose() {
		// Helper: regenerate and update gameplay data
		do_regenerate :: proc(algo: Algorithm, d: ^Dungeon_Map, s: ^SpawnPoints, v: ^ValidationResult, seed_val: u64, use_seed: bool) {
			// Seed RNG if using manual seed
			if use_seed {
				rand.reset(seed_val)
			}
			free_dungeon(d)
			d^ = make_dungeon_by_algorithm(algo)
			s^ = place_spawn_points(d)
			v^ = validate_connectivity(d, MAP_WIDTH / 2, MAP_HEIGHT / 2, false)
		}

		if rl.IsKeyPressed(.SPACE) {
			do_regenerate(algorithm, &dungeon, &spawn, &val_result, seed, use_seed)
		}
		if rl.IsKeyPressed(.ONE) {
			algorithm = .Drunkards_Walk
			do_regenerate(algorithm, &dungeon, &spawn, &val_result, seed, use_seed)
		}
		if rl.IsKeyPressed(.TWO) {
			algorithm = .BSP
			do_regenerate(algorithm, &dungeon, &spawn, &val_result, seed, use_seed)
		}
		if rl.IsKeyPressed(.THREE) {
			algorithm = .Cellular_Automata
			do_regenerate(algorithm, &dungeon, &spawn, &val_result, seed, use_seed)
		}
		if rl.IsKeyPressed(.FOUR) {
			algorithm = .Hybrid
			do_regenerate(algorithm, &dungeon, &spawn, &val_result, seed, use_seed)
		}
		if rl.IsKeyPressed(.FIVE) {
			algorithm = .Prefab
			do_regenerate(algorithm, &dungeon, &spawn, &val_result, seed, use_seed)
		}

		// Export current dungeon to file (S key)
		if rl.IsKeyPressed(.S) {
			save_count += 1
			filename := fmt.ctprintf("dungeon_%02d.dun", save_count)
			success := export_dungeon(&dungeon, filename)
			if success {
				fmt.println("Saved:", filename)
			} else {
				fmt.println("Failed to save:", filename)
			}
		}

		// Seed control: UP/DOWN arrow keys to adjust seed
		if rl.IsKeyPressed(.UP) {
			seed += 1
			use_seed = true
			// Regenerate with new seed
			do_regenerate(algorithm, &dungeon, &spawn, &val_result, seed, use_seed)
		}
		if rl.IsKeyPressed(.DOWN) {
			if seed > 0 {
				seed -= 1
			}
			use_seed = true
			// Regenerate with new seed
			do_regenerate(algorithm, &dungeon, &spawn, &val_result, seed, use_seed)
		}

		// R: Toggle random vs fixed seed mode
		if rl.IsKeyPressed(.R) {
			use_seed = !use_seed
			do_regenerate(algorithm, &dungeon, &spawn, &val_result, seed, use_seed)
		}

		// P: Toggle parameter panel
		if rl.IsKeyPressed(.P) {
			param_panel.enabled = !param_panel.enabled
		}

		// Parameter panel: update and regenerate if changed
		if param_panel.enabled {
			params_changed := update_parameter_panel(param_panel)
			if params_changed {
				// Regenerate with new parameters
				ca_cfg, bsp_cfg, _, hybrid_cfg := get_configs_from_panel(param_panel)

				if use_seed {
					rand.reset(seed)
				}
				free_dungeon(&dungeon)

				// Regenerate with custom configs
				switch algorithm {
				case .Drunkards_Walk:
					dungeon = make_dungeon()
				case .BSP:
					dungeon = make_dungeon_bsp(bsp_cfg)
				case .Cellular_Automata:
					dungeon = make_dungeon_ca(ca_cfg)
				case .Hybrid:
					dungeon = make_dungeon_hybrid(hybrid_cfg)
				case .Prefab:
					// Prefab count is controlled via panel
					prefab_cfg := PREFAB_DEFAULT_CONFIG
					prefab_cfg.prefab_count = param_panel.prefab_count
					dungeon = make_dungeon_prefab(prefab_cfg)
				}

				spawn = place_spawn_points(&dungeon)
				val_result = validate_connectivity(&dungeon, MAP_WIDTH / 2, MAP_HEIGHT / 2, false)
			}
		}

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		draw_dungeon(&dungeon)
		draw_spawn_points(spawn)
		draw_dungeon_stats(&dungeon, spawn, val_result)
		draw_parameter_panel(param_panel)

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
		case .Prefab:
			mode_text = "Prefab Rooms"
		}

		rl.DrawText(
			fmt.ctprintf("%s - Space: Regen | 1-5: Algos | S: Save | P: Parameters", mode_text),
			10, 10, 20, rl.WHITE,
		)

		// Legend for spawn points
		rl.DrawText("🟩 Start 🟥 End | Connectivity auto-checked", 10, 35, 14, rl.GRAY)

		// Seed display
		seed_mode_text := use_seed ? "FIXED" : "RANDOM"
		rl.DrawText(
			fmt.ctprintf("Seed: %d (%s) | ↑↓: Adjust | R: Toggle", seed, seed_mode_text),
			10, 55, 14, use_seed ? rl.YELLOW : rl.GRAY,
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
	case .Prefab:
		return make_dungeon_prefab()
	}
	return make_dungeon()
}

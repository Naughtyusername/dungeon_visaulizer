package dungeon_visualizer

import rl "vendor:raylib"
import "core:fmt"
import "core:math/rand"
import "core:strconv"
import "core:strings"

Algorithm :: enum {
	Drunkards_Walk,      // 1: Classic cave carver
	BSP,                 // 2: Structured room-based
	Cellular_Automata,   // 3: Organic cave generation
	Hybrid,              // 4: CA caves + BSP rooms + explicit corridors
	Prefab,              // 5: Hand-designed room templates scattered
}

main :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.InitWindow(SCREEN_W, SCREEN_H, "Dungeon Visualizer")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)

	algorithm := Algorithm.Drunkards_Walk
	dungeon := make_dungeon()
	defer free_dungeon(&dungeon)

	// Gameplay helpers
	spawn := place_spawn_points(&dungeon)
	val_result := validate_connectivity(&dungeon, MAP_WIDTH / 2, MAP_HEIGHT / 2, false)
	room_tags := tag_rooms(&dungeon)
	defer free_room_tags(&room_tags)
	entity_markers := place_entity_markers(&dungeon, spawn, ENTITY_DEFAULT_CONFIG)
	defer free_entity_markers(&entity_markers)

	// Seed system: manual seed control for reproducible dungeons
	// User can adjust with arrow keys
	seed: u64 = 12345  // Default seed
	use_seed := false  // If true, use manual seed instead of time-based

	// Parameter tuning UI
	// IMPORTANT: Create on heap and initialize in-place so pointers stay valid
	param_panel := new(ParameterPanel)
	defer free(param_panel)
	initialize_parameter_panel(param_panel)

	// =============================================================================
	// FULLSCREEN & COMPARISON MODE
	// =============================================================================
	// Fullscreen toggle: F key, independent of comparison mode
	// Comparison mode: C key, shows 4 algorithms (DW, BSP, CA, Hybrid) side-by-side
	// Cached dungeons strategy: Generate once per seed change, not every frame (60 FPS)
	// to avoid "seed cycling" bug where RNG resets continuously
	fullscreen := false
	comparison_mode := false

	// Cached dungeons for comparison mode (only regenerate when needed, not every frame!)
	// Pre-generated to avoid expensive regeneration in draw loop
	comparison_dungeons := make([dynamic]Dungeon_Map, 4)
	comparison_spawns := make([dynamic]SpawnPoints, 4)
	comparison_markers := make([dynamic]EntityMarkers, 4)
	comparison_tags := make([dynamic]Room_Tags, 4)
	defer {
		for i in 0..<len(comparison_dungeons) {
			free_dungeon(&comparison_dungeons[i])
		}
		delete(comparison_dungeons)
		for i in 0..<len(comparison_markers) {
			free_entity_markers(&comparison_markers[i])
		}
		delete(comparison_markers)
		delete(comparison_spawns)
		for i in 0..<len(comparison_tags) {
			free_room_tags(&comparison_tags[i])
		}
		delete(comparison_tags)
	}

	// Flag to regenerate comparison dungeons only when needed
	regenerate_comparison := true

	// Prefab editor
	editor: PrefabEditor
	init_prefab_editor(&editor)
	defer free_prefab_editor(&editor)

	// Save counter for exported dungeons
	save_count := 0

	for !rl.WindowShouldClose() {
		// Helper: regenerate and update gameplay data
		do_regenerate :: proc(algo: Algorithm, d: ^Dungeon_Map, s: ^SpawnPoints, v: ^ValidationResult, t: ^Room_Tags, e: ^EntityMarkers, seed_val: u64, use_seed: bool) {
			// Seed RNG if using manual seed
			if use_seed {
				rand.reset(seed_val)
			}
			free_dungeon(d)
			d^ = make_dungeon_by_algorithm(algo)
			// Tag rooms before spawn points — tagging is pure geometry,
			// spawn placement does not depend on room types
			free_room_tags(t)
			t^ = tag_rooms(d)
			s^ = place_spawn_points(d)
			v^ = validate_connectivity(d, MAP_WIDTH / 2, MAP_HEIGHT / 2, false)
			free_entity_markers(e)
			e^ = place_entity_markers(d, s^, ENTITY_DEFAULT_CONFIG)
		}

		if rl.IsKeyPressed(.SPACE) {
			do_regenerate(algorithm, &dungeon, &spawn, &val_result, &room_tags, &entity_markers, seed, use_seed)
			regenerate_comparison = true
		}
		if rl.IsKeyPressed(.ONE) {
			algorithm = .Drunkards_Walk
			do_regenerate(algorithm, &dungeon, &spawn, &val_result, &room_tags, &entity_markers, seed, use_seed)
		}
		if rl.IsKeyPressed(.TWO) {
			algorithm = .BSP
			do_regenerate(algorithm, &dungeon, &spawn, &val_result, &room_tags, &entity_markers, seed, use_seed)
		}
		if rl.IsKeyPressed(.THREE) {
			algorithm = .Cellular_Automata
			do_regenerate(algorithm, &dungeon, &spawn, &val_result, &room_tags, &entity_markers, seed, use_seed)
		}
		if rl.IsKeyPressed(.FOUR) {
			algorithm = .Hybrid
			do_regenerate(algorithm, &dungeon, &spawn, &val_result, &room_tags, &entity_markers, seed, use_seed)
		}
		if rl.IsKeyPressed(.FIVE) {
			algorithm = .Prefab
			do_regenerate(algorithm, &dungeon, &spawn, &val_result, &room_tags, &entity_markers, seed, use_seed)
		}

		// Export current dungeon to file (S key)
		if rl.IsKeyPressed(.S) {
			save_count += 1
			filename := fmt.ctprintf("dungeon_%02d.dun", save_count)
			success := export_dungeon(&dungeon, filename, entity_markers)
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
			do_regenerate(algorithm, &dungeon, &spawn, &val_result, &room_tags, &entity_markers, seed, use_seed)
			regenerate_comparison = true
		}
		if rl.IsKeyPressed(.DOWN) {
			if seed > 0 {
				seed -= 1
			}
			use_seed = true
			// Regenerate with new seed
			do_regenerate(algorithm, &dungeon, &spawn, &val_result, &room_tags, &entity_markers, seed, use_seed)
			regenerate_comparison = true
		}

		// R: Toggle random vs fixed seed mode
		if rl.IsKeyPressed(.R) {
			use_seed = !use_seed
			do_regenerate(algorithm, &dungeon, &spawn, &val_result, &room_tags, &entity_markers, seed, use_seed)
			regenerate_comparison = true
		}

		// F: Toggle fullscreen
		if rl.IsKeyPressed(.F) {
			fullscreen = !fullscreen
			rl.ToggleFullscreen()
		}

		// C: Toggle comparison mode (guard against Ctrl+C which is seed copy)
		ctrl_held := rl.IsKeyDown(.LEFT_CONTROL) || rl.IsKeyDown(.RIGHT_CONTROL)
		if rl.IsKeyPressed(.C) && !ctrl_held {
			comparison_mode = !comparison_mode
			regenerate_comparison = true
		}

		// Ctrl+C: Copy current seed to clipboard (X11 clipboard — works within app
		// and with X11 apps; Wayland-native apps use a separate clipboard)
		if ctrl_held && rl.IsKeyPressed(.C) {
			rl.SetClipboardText(fmt.ctprintf("%d", seed))
		}

		// Ctrl+V: Paste seed from clipboard
		if ctrl_held && rl.IsKeyPressed(.V) {
			clipboard := rl.GetClipboardText()
			if clipboard != nil {
				seed_str := strings.trim_space(string(clipboard))
				if parsed, ok := strconv.parse_u64(seed_str); ok {
					seed = parsed
					use_seed = true
					do_regenerate(algorithm, &dungeon, &spawn, &val_result, &room_tags, &entity_markers, seed, use_seed)
					regenerate_comparison = true
				}
			}
		}

		// E: Toggle prefab editor
		if rl.IsKeyPressed(.E) {
			editor.active = !editor.active
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

				free_room_tags(&room_tags)
				room_tags = tag_rooms(&dungeon)
				spawn = place_spawn_points(&dungeon)
				val_result = validate_connectivity(&dungeon, MAP_WIDTH / 2, MAP_HEIGHT / 2, false)
				free_entity_markers(&entity_markers)
				entity_markers = place_entity_markers(&dungeon, spawn, {})
			}
		}

		// Regenerate comparison mode dungeons only when needed (not every frame!)
		if comparison_mode && regenerate_comparison {
			regenerate_comparison = false

			// Free old dungeons
			for i in 0..<len(comparison_dungeons) {
				free_dungeon(&comparison_dungeons[i])
			}
			for i in 0..<len(comparison_markers) {
				free_entity_markers(&comparison_markers[i])
			}
			for i in 0..<len(comparison_tags) {
				free_room_tags(&comparison_tags[i])
			}
			clear(&comparison_dungeons)
			clear(&comparison_spawns)
			clear(&comparison_markers)
			clear(&comparison_tags)

			// Generate new dungeons for all 4 algorithms with current seed
			comparison_algos := []Algorithm{.Drunkards_Walk, .BSP, .Cellular_Automata, .Hybrid}
			for algo in comparison_algos {
				if use_seed {
					rand.reset(seed)
				}
				d := make_dungeon_by_algorithm(algo)
				t := tag_rooms(&d)
				s := place_spawn_points(&d)
				m := place_entity_markers(&d, s, ENTITY_DEFAULT_CONFIG)

				append(&comparison_dungeons, d)
				append(&comparison_spawns, s)
				append(&comparison_tags, t)
				append(&comparison_markers, m)
			}
		}

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)

		if editor.active {
			// Prefab editor takes over the full screen
			if update_prefab_editor(&editor) {
				editor.active = false
			}
			draw_prefab_editor(&editor)
		} else {
			// Set up scaling camera for fullscreen
			// Calculate scale to fill window while maintaining aspect ratio
			if !comparison_mode {
				window_w := f32(rl.GetScreenWidth())
				window_h := f32(rl.GetScreenHeight())
				scale := min(window_w / f32(SCREEN_W), window_h / f32(SCREEN_H))

				camera := rl.Camera2D{
					offset = {window_w / 2, window_h / 2},
					target = {f32(SCREEN_W) / 2, f32(SCREEN_H) / 2},
					rotation = 0,
					zoom = scale,
				}
				rl.BeginMode2D(camera)
				draw_single_view(&dungeon, spawn, room_tags, entity_markers, val_result, algorithm)
				rl.EndMode2D()
			} else {
				draw_comparison_mode_cached(comparison_dungeons, comparison_spawns, comparison_tags, comparison_markers)
			}

			// Draw parameter panel OUTSIDE camera so mouse hit detection is in screen space
			draw_parameter_panel(param_panel)

			// Shared UI elements
			help_text := comparison_mode ? "C: Single View | F: Fullscreen | Space: Regen" : "Space: Regen | 1-5: Algos | S: Save | P: Params | C: Compare | F: Fullscreen | E: Prefab Editor"
			rl.DrawText(fmt.ctprintf("%s", help_text), 10, 10, 14, rl.GRAY)

			// Legend for spawn, entity, room type, and door markers
			rl.DrawText("< Up Stairs  > Down Stairs | Enemy Treasure | [B]oss [T]reasure [S]afe (BSP) | Doors: BSP/Hybrid/Prefab | Ctrl+C/V: copy/paste seed", 10, 30, 14, rl.GRAY)

			// Seed display
			seed_mode_text := use_seed ? "FIXED" : "RANDOM"
			rl.DrawText(
				fmt.ctprintf("Seed: %d (%s) | ↑↓: Adjust | R: Toggle", seed, seed_mode_text),
				10, 50, 14, use_seed ? rl.YELLOW : rl.GRAY,
			)

			if comparison_mode {
				rl.DrawText("COMPARISON MODE (4 algorithms)", 10, 70, 16, rl.YELLOW)
			}
		}

		rl.EndDrawing()
	}
}

// draw_single_view renders the current dungeon in single-algorithm mode
// Called at default zoom (no camera scaling in this proc)
// Camera scaling is applied in main loop for fullscreen support
//
// Parameters:
//   dungeon: Current generated dungeon
//   spawn: Spawn point locations (start/end)
//   entity_markers: Enemy and treasure marker locations
//   val_result: Connectivity validation result
//   algorithm: Current algorithm being displayed
draw_single_view :: proc(dungeon: ^Dungeon_Map, spawn: SpawnPoints, tags: Room_Tags, entity_markers: EntityMarkers, val_result: ValidationResult, algorithm: Algorithm) {
	draw_dungeon(dungeon)
	draw_room_tags(dungeon, tags)
	draw_spawn_points(spawn)
	draw_entity_markers(entity_markers)
	draw_dungeon_stats(dungeon, spawn, val_result)

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

	rl.DrawText(fmt.ctprintf("%s", mode_text), 10, 70, 16, rl.WHITE)
}

// draw_comparison_mode_cached renders 4 pre-generated algorithms side-by-side in a 2x2 grid
// Uses cached dungeons to avoid regenerating every frame (critical for performance)
//
// Layout:
//   960×540 per panel at 1920×1080 fullscreen
//   Shows complete 80×45 map per panel (scaled to 12px tiles via camera zoom 0.75)
//   Panels: [Top-Left: DW] [Top-Right: BSP] [Bottom-Left: CA] [Bottom-Right: Hybrid]
//
// Parameters:
//   dungeons: Pre-generated 4 dungeons (DW, BSP, CA, Hybrid) from comparison cache
//   spawns: Spawn points for each cached dungeon
//   markers: Entity markers (enemies/treasure) for each cached dungeon
//
// Note: Uses Raylib 2D camera for clean viewport offsets per panel (no manual coordinate adjustments needed)
draw_comparison_mode_cached :: proc(dungeons: [dynamic]Dungeon_Map, spawns: [dynamic]SpawnPoints, tags: [dynamic]Room_Tags, markers: [dynamic]EntityMarkers) {
	PANEL_W :: 960
	PANEL_H :: 540
	TILE_SCALE :: 0.75  // 12px tiles (16 * 0.75 = 12) to fit full 80×45 in 960×540

	positions := [][2]i32{{0, 0}, {PANEL_W, 0}, {0, PANEL_H}, {PANEL_W, PANEL_H}}
	algo_names := []cstring{"DW", "BSP", "CA", "Hybrid"}

	for idx in 0..<4 {
		if idx >= len(dungeons) {
			continue
		}

		offset := positions[idx]
		offset_x := offset.x
		offset_y := offset.y

		// Set up 2D camera for this panel with zoom to fit full map
		camera := rl.Camera2D{
			offset = {f32(offset_x), f32(offset_y)},
			target = {0, 0},
			rotation = 0,
			zoom = TILE_SCALE,
		}

		// Draw this panel with cached data (scaled to see full map)
		rl.BeginMode2D(camera)
		draw_dungeon(&dungeons[idx])
		if idx < len(tags) {
			draw_room_tags(&dungeons[idx], tags[idx])
		}
		draw_spawn_points(spawns[idx])
		draw_entity_markers(markers[idx])
		rl.EndMode2D()

		// Draw panel border and label
		border_color := rl.Color{100, 100, 100, 255}
		rl.DrawRectangleLines(offset_x, offset_y, i32(PANEL_W), i32(PANEL_H), border_color)

		label_x := offset_x + 10
		label_y := offset_y + i32(PANEL_H) - 25
		rl.DrawText(algo_names[idx], label_x, label_y, 14, rl.WHITE)
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

package dungeon_visualizer

import rl "vendor:raylib"
import "core:os"
import "core:fmt"
import "core:strings"
import "core:mem"

// =============================================================================
// INTERACTIVE PREFAB EDITOR
// =============================================================================
// A tile-painting canvas for designing custom prefab room templates.
// Saves designs as .prefab files in the prefabs/ directory, which are then
// loaded by get_all_prefabs() and used in Prefab dungeon generation.
//
// Controls:
//   E / ESC    : exit editor
//   Left click : paint floor
//   Right click: paint wall
//   Arrow keys : resize canvas (←→ width, ↑↓ height)
//   C          : clear canvas (all walls)
//   S          : save to prefabs/prefab_NN.prefab
//
// File format: simple JSON matching the .dun format conventions
//   { "name": "Custom Room 1", "width": 9, "height": 7, "tiles": "WWWFF..." }
//
// Usage:
//   var editor: PrefabEditor
//   init_prefab_editor(&editor)
//   // in loop: if editor.active { update/draw }
//   // E key:   editor.active = !editor.active
// =============================================================================

// Maximum canvas dimension in either axis (24×24 = 576 tiles max)
MAX_EDITOR_SIZE  :: 24
// Tile size in the editor view (2× normal 16px for comfortable mouse painting)
EDITOR_TILE_SIZE :: 32

// PrefabEditor holds all editor state.
// canvas is a fixed-size value array — no heap allocation needed.
// Active dimensions (canvas_w, canvas_h) define the usable region.
PrefabEditor :: struct {
	active:       bool,
	canvas:       [MAX_EDITOR_SIZE][MAX_EDITOR_SIZE]Tile_Type, // [y][x], zero = .Wall
	canvas_w:     int,
	canvas_h:     int,
	save_count:   int,    // Auto-increments for sequential filenames
	status_msg:   cstring,
	status_timer: f32,    // Seconds remaining to display status_msg
}

// init_prefab_editor sets up the editor with a sensible default canvas size
// and counts existing .prefab files so save_count starts after them.
init_prefab_editor :: proc(e: ^PrefabEditor) {
	e.canvas_w   = 9
	e.canvas_h   = 7
	e.save_count = count_existing_prefabs()
	// canvas is zero-initialized (.Wall) by default — no explicit init needed
}

// free_prefab_editor cleans up editor state.
// No heap to free (canvas is a value array), but exists for lifecycle consistency.
free_prefab_editor :: proc(e: ^PrefabEditor) {
	e.active = false
}

// count_existing_prefabs scans the prefabs/ directory and returns the number
// of .prefab files found, so save_count starts after existing files.
count_existing_prefabs :: proc() -> int {
	handle, err := os.open("prefabs")
	if err != nil { return 0 }
	defer os.close(handle)

	entries, read_err := os.read_dir(handle, -1, context.allocator)
	if read_err != nil { return 0 }
	defer os.file_info_slice_delete(entries, context.allocator)

	count := 0
	for entry in entries {
		if strings.has_suffix(entry.name, ".prefab") {
			count += 1
		}
	}
	return count
}

// update_prefab_editor handles all input for the editor.
// Returns true when the user wants to exit (E or ESC pressed).
//
// Input handled:
//   Mouse left/right held : paint floor/wall
//   Arrow keys            : resize canvas
//   C                     : clear all tiles to wall
//   S                     : save to disk
//   E / ESC               : exit
update_prefab_editor :: proc(e: ^PrefabEditor) -> bool {
	offset_x := (SCREEN_W - e.canvas_w * EDITOR_TILE_SIZE) / 2
	offset_y := (SCREEN_H - e.canvas_h * EDITOR_TILE_SIZE) / 2

	// Mouse painting — use IsMouseButtonDown so dragging paints continuously
	mouse := rl.GetMousePosition()
	tile_x := (int(mouse.x) - offset_x) / EDITOR_TILE_SIZE
	tile_y := (int(mouse.y) - offset_y) / EDITOR_TILE_SIZE
	in_bounds := tile_x >= 0 && tile_x < e.canvas_w && tile_y >= 0 && tile_y < e.canvas_h

	if in_bounds {
		if rl.IsMouseButtonDown(.LEFT)  { e.canvas[tile_y][tile_x] = .Floor }
		if rl.IsMouseButtonDown(.RIGHT) { e.canvas[tile_y][tile_x] = .Wall  }
	}

	// Canvas resize — arrow keys (min 3 to keep rooms meaningful)
	if rl.IsKeyPressed(.RIGHT) { e.canvas_w = min(e.canvas_w + 1, MAX_EDITOR_SIZE) }
	if rl.IsKeyPressed(.LEFT)  { e.canvas_w = max(e.canvas_w - 1, 3)               }
	if rl.IsKeyPressed(.DOWN)  { e.canvas_h = min(e.canvas_h + 1, MAX_EDITOR_SIZE) }
	if rl.IsKeyPressed(.UP)    { e.canvas_h = max(e.canvas_h - 1, 3)               }

	// Clear — zero entire canvas array (enum .Wall = 0)
	if rl.IsKeyPressed(.C) {
		mem.zero_slice(e.canvas[:])
	}

	// Save
	if rl.IsKeyPressed(.S) {
		if save_prefab_to_file(e) {
			e.status_msg   = fmt.ctprintf("Saved: prefabs/prefab_%02d.prefab", e.save_count)
			e.status_timer = 3.0
		} else {
			e.status_msg   = "Save failed!"
			e.status_timer = 3.0
		}
	}

	// Tick status timer
	if e.status_timer > 0 {
		e.status_timer -= rl.GetFrameTime()
		if e.status_timer <= 0 {
			e.status_msg   = ""
			e.status_timer = 0
		}
	}

	// Exit — ESC only; E is handled by the main loop toggle so we don't
	// double-consume the keypress on the same frame the editor opens
	if rl.IsKeyPressed(.ESCAPE) {
		return true
	}

	return false
}

// draw_prefab_editor renders the tile canvas, grid, cursor highlight, and UI.
// Draws in screen space — no camera transform applied.
draw_prefab_editor :: proc(e: ^PrefabEditor) {
	WALL_COLOR   :: rl.Color{50,  50,  55,  255}
	FLOOR_COLOR  :: rl.Color{180, 175, 155, 255}
	GRID_COLOR   :: rl.Color{80,  80,  85,  255}
	CURSOR_COLOR :: rl.YELLOW

	offset_x := (SCREEN_W - e.canvas_w * EDITOR_TILE_SIZE) / 2
	offset_y := (SCREEN_H - e.canvas_h * EDITOR_TILE_SIZE) / 2

	// Tiles
	for y in 0..<e.canvas_h {
		for x in 0..<e.canvas_w {
			px    := i32(offset_x + x * EDITOR_TILE_SIZE)
			py    := i32(offset_y + y * EDITOR_TILE_SIZE)
			color := e.canvas[y][x] == .Floor ? FLOOR_COLOR : WALL_COLOR
			rl.DrawRectangle(px, py, EDITOR_TILE_SIZE, EDITOR_TILE_SIZE, color)
		}
	}

	// Grid lines — N+1 lines for N columns/rows
	for x in 0..=e.canvas_w {
		lx := i32(offset_x + x * EDITOR_TILE_SIZE)
		rl.DrawLine(lx, i32(offset_y), lx, i32(offset_y + e.canvas_h * EDITOR_TILE_SIZE), GRID_COLOR)
	}
	for y in 0..=e.canvas_h {
		ly := i32(offset_y + y * EDITOR_TILE_SIZE)
		rl.DrawLine(i32(offset_x), ly, i32(offset_x + e.canvas_w * EDITOR_TILE_SIZE), ly, GRID_COLOR)
	}

	// Cursor highlight on hovered tile
	mouse := rl.GetMousePosition()
	tile_x := (int(mouse.x) - offset_x) / EDITOR_TILE_SIZE
	tile_y := (int(mouse.y) - offset_y) / EDITOR_TILE_SIZE
	if tile_x >= 0 && tile_x < e.canvas_w && tile_y >= 0 && tile_y < e.canvas_h {
		rl.DrawRectangleLines(
			i32(offset_x + tile_x * EDITOR_TILE_SIZE),
			i32(offset_y + tile_y * EDITOR_TILE_SIZE),
			EDITOR_TILE_SIZE, EDITOR_TILE_SIZE,
			CURSOR_COLOR,
		)
	}

	// UI text
	rl.DrawText("PREFAB EDITOR", 10, 10, 18, rl.WHITE)
	rl.DrawText(
		"Left: floor  |  Right: wall  |  ←→: width  |  ↑↓: height  |  C: clear  |  S: save  |  E/ESC: exit",
		10, 32, 14, rl.GRAY,
	)
	rl.DrawText(fmt.ctprintf("Canvas: %d x %d", e.canvas_w, e.canvas_h), 10, 50, 14, rl.LIGHTGRAY)

	// Status message (save confirmation or error)
	if e.status_timer > 0 && e.status_msg != "" {
		rl.DrawText(e.status_msg, 10, i32(SCREEN_H) - 30, 16, rl.GREEN)
	}
}

// save_prefab_to_file writes the current canvas to prefabs/prefab_NN.prefab.
// Creates the prefabs/ directory if it doesn't exist.
// Increments e.save_count on success.
//
// File format:
//   { "name": "Custom Room N", "width": W, "height": H, "tiles": "WWFF..." }
//
// Returns true on success.
save_prefab_to_file :: proc(e: ^PrefabEditor) -> bool {
	os.make_directory("prefabs") // no-op if already exists

	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)

	e.save_count += 1

	fmt.sbprint(&sb, "{\n")
	fmt.sbprintf(&sb, "  \"name\": \"Custom Room %d\",\n", e.save_count)
	fmt.sbprintf(&sb, "  \"width\": %d,\n", e.canvas_w)
	fmt.sbprintf(&sb, "  \"height\": %d,\n", e.canvas_h)
	fmt.sbprint(&sb, "  \"tiles\": \"")
	for y in 0..<e.canvas_h {
		for x in 0..<e.canvas_w {
			fmt.sbprintf(&sb, "%c", e.canvas[y][x] == .Floor ? 'F' : 'W')
		}
	}
	fmt.sbprint(&sb, "\"\n}\n")

	filename := fmt.tprintf("prefabs/prefab_%02d.prefab", e.save_count)
	content  := strings.to_string(sb)
	err      := os.write_entire_file_from_string(filename, content)
	return err == nil
}

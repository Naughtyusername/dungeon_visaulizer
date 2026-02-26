package dungeon_visualizer

// =============================================================================
// PARAMETER TUNING UI
// =============================================================================
// Live sliders to tweak dungeon generation in real-time.
// Completely modular: can be toggled on/off, disabled doesn't affect generation.
//
// Supported Parameters:
//   - CA Iterations (1-8)
//   - CA Initial Fill (10-90%)
//   - BSP Min Room Size (5-20)
//   - Corridor Width (1-3)
//   - Prefab Count (1-10)
//   - Hybrid Room Density (10-50%)
//
// Usage:
//   - Press 'P' to toggle parameter panel
//   - Click/drag sliders to adjust
//   - Press Enter to confirm and regenerate
//   - Press ESC to cancel changes
// =============================================================================

import rl "vendor:raylib"
import "core:fmt"

// Slider represents a single tuneable parameter
Slider :: struct {
	label: cstring,
	value: ^int,           // Pointer to value to modify
	min, max: int,         // Range
	x, y: i32,             // Position on screen
	width: i32,            // Width in pixels
	dragging: bool,        // Currently being dragged
	changed: bool,         // Changed this frame
	drag_start_x: i32,     // Mouse X when drag started
	drag_start_value: int, // Value when drag started
}

// ParameterPanel manages all sliders
ParameterPanel :: struct {
	enabled: bool,
	sliders: [dynamic]Slider,

	// Current values (before confirm)
	ca_iterations: int,
	ca_fill: int,          // As percentage (45 = 45%)
	bsp_min_size: int,
	corridor_width: int,
	prefab_count: int,
	hybrid_density: int,   // As percentage (30 = 30%)
}

// Initialize parameter panel with default values (in-place to keep pointers valid)
initialize_parameter_panel :: proc(panel: ^ParameterPanel) {
	panel.enabled = false
	panel.sliders = make([dynamic]Slider)
	panel.ca_iterations = CA_DEFAULT_CONFIG.generations
	panel.ca_fill = 45
	panel.bsp_min_size = BSP_DEFAULT_CONFIG.min_size
	panel.corridor_width = 1
	panel.prefab_count = 6
	panel.hybrid_density = 30

	// Layout: 6 sliders, vertical stack, left side of screen
	start_x: i32 = 20
	start_y: i32 = 100
	spacing: i32 = 50

	// Slider 1: CA Iterations (1-8)
	append(&panel.sliders, Slider{
		label = "CA Iterations",
		value = &panel.ca_iterations,
		min = 1, max = 8,
		x = start_x, y = start_y + spacing * 0,
		width = 200,
	})

	// Slider 2: CA Initial Fill % (10-90)
	append(&panel.sliders, Slider{
		label = "CA Initial Fill %",
		value = &panel.ca_fill,
		min = 10, max = 90,
		x = start_x, y = start_y + spacing * 1,
		width = 200,
	})

	// Slider 3: BSP Min Room Size (5-20)
	append(&panel.sliders, Slider{
		label = "BSP Min Room Size",
		value = &panel.bsp_min_size,
		min = 5, max = 20,
		x = start_x, y = start_y + spacing * 2,
		width = 200,
	})

	// Slider 4: Corridor Width (1-3)
	append(&panel.sliders, Slider{
		label = "Corridor Width",
		value = &panel.corridor_width,
		min = 1, max = 3,
		x = start_x, y = start_y + spacing * 3,
		width = 200,
	})

	// Slider 5: Prefab Count (1-10)
	append(&panel.sliders, Slider{
		label = "Prefab Count",
		value = &panel.prefab_count,
		min = 1, max = 10,
		x = start_x, y = start_y + spacing * 4,
		width = 200,
	})

	// Slider 6: Hybrid Room Density % (10-50)
	append(&panel.sliders, Slider{
		label = "Hybrid Density %",
		value = &panel.hybrid_density,
		min = 10, max = 50,
		x = start_x, y = start_y + spacing * 5,
		width = 200,
	})
}

// update_parameter_panel handles mouse input and slider dragging
// Returns true if any parameter changed this frame
update_parameter_panel :: proc(panel: ^ParameterPanel) -> bool {
	if !panel.enabled {
		return false
	}

	any_changed := false
	mouse_x := rl.GetMouseX()
	mouse_y := rl.GetMouseY()
	mouse_down := rl.IsMouseButtonDown(.LEFT)
	mouse_released := rl.IsMouseButtonReleased(.LEFT)

	for &slider in panel.sliders {
		slider.changed = false

		// Check if mouse is over slider handle
		slider_y := slider.y + 20  // Center of slider
		handle_x := slider.x + i32(f32(slider.width) * f32(slider.value^ - slider.min) / f32(slider.max - slider.min))
		// Clamp to stay within slider bounds
		handle_x = clamp(handle_x, slider.x, slider.x + slider.width)
		handle_size: i32 = 20

		// Hit detection must match the drawn handle position and size
		// Handle is drawn at (slider_y - handle_size/2 + 3) to center it on the track
		is_over := mouse_x >= handle_x - handle_size/2 && mouse_x <= handle_x + handle_size/2 &&
		           mouse_y >= slider_y - handle_size/2 + 3 && mouse_y <= slider_y + handle_size/2 + 3

		// Start dragging
		if is_over && mouse_down && !slider.dragging {
			slider.dragging = true
			slider.drag_start_x = mouse_x
			slider.drag_start_value = slider.value^
		}

		// Update value while dragging using relative mouse movement
		if slider.dragging && mouse_down {
			// Calculate how far the mouse has moved from the drag start
			distance_dragged := f32(mouse_x - slider.drag_start_x)

			// Calculate how many pixels = 1 unit of value
			value_range := f32(slider.max - slider.min)
			pixels_per_unit := f32(slider.width) / value_range

			// Convert pixel distance to value change
			value_delta := distance_dragged / pixels_per_unit
			new_value := slider.drag_start_value + int(value_delta)

			// Clamp to valid range
			new_value = clamp(new_value, slider.min, slider.max)

			if new_value != slider.value^ {
				slider.value^ = new_value
				slider.changed = true
				any_changed = true
			}
		}

		// Stop dragging
		if mouse_released {
			slider.dragging = false
		}
	}

	return any_changed
}

// draw_parameter_panel renders the parameter tuning UI
// Shows all sliders with values and labels
draw_parameter_panel :: proc(panel: ^ParameterPanel) {
	if !panel.enabled {
		return
	}

	// Semi-transparent background panel
	panel_width: i32 = 300
	panel_height: i32 = 350
	rl.DrawRectangle(0, 70, panel_width, panel_height, rl.Color{20, 20, 30, 200})
	rl.DrawRectangleLines(0, 70, panel_width, panel_height, rl.GRAY)

	// Title
	rl.DrawText("PARAMETER TUNING (P to toggle)", 10, 75, 16, rl.YELLOW)
	rl.DrawText("Drag sliders | Enter: Apply | ESC: Cancel", 10, 95, 12, rl.GRAY)

	// Draw each slider
	for slider in panel.sliders {
		draw_slider(slider)
	}
}

// draw_slider renders a single slider with label and value
draw_slider :: proc(slider: Slider) {
	label_y := slider.y
	slider_y := slider.y + 20

	// Label
	rl.DrawText(slider.label, slider.x, label_y, 14, rl.WHITE)

	// Value display
	value_text := fmt.ctprintf("%d", slider.value^)
	rl.DrawText(value_text, slider.x + slider.width + 10, label_y, 14, rl.LIME)

	// Slider background (track) - make it VERY visible for debugging
	rl.DrawRectangle(slider.x, slider_y, slider.width, 12, rl.Color{0, 255, 255, 255})  // CYAN
	rl.DrawRectangleLines(slider.x, slider_y, slider.width, 12, rl.Color{255, 255, 0, 255})  // YELLOW outline

	// Slider handle (thumb) - position based on current value
	handle_x := slider.x + i32(f32(slider.width) * f32(slider.value^ - slider.min) / f32(slider.max - slider.min))
	// Clamp to stay within slider bounds
	handle_x = clamp(handle_x, slider.x, slider.x + slider.width)
	handle_size: i32 = 20
	handle_color := slider.dragging ? rl.RED : rl.MAGENTA  // Bright colors
	rl.DrawRectangle(handle_x - handle_size/2, slider_y - handle_size/2 + 3, handle_size, handle_size, handle_color)
	rl.DrawRectangleLines(handle_x - handle_size/2, slider_y - handle_size/2 + 3, handle_size, handle_size, rl.WHITE)

	// Min/Max labels (subtle)
	min_text := fmt.ctprintf("%d", slider.min)
	max_text := fmt.ctprintf("%d", slider.max)
	rl.DrawText(min_text, slider.x - 20, slider_y + 8, 10, rl.LIGHTGRAY)
	rl.DrawText(max_text, slider.x + slider.width, slider_y + 8, 10, rl.LIGHTGRAY)
}

// get_current_configs builds algorithm configs from parameter panel
// Returns updated CA_Config, BSP_Config, CorridorConfig, HybridConfig
get_configs_from_panel :: proc(panel: ^ParameterPanel) -> (CA_Config, BSP_Config, CorridorConfig, HybridConfig) {
	ca_cfg := CA_DEFAULT_CONFIG
	ca_cfg.generations = panel.ca_iterations
	ca_cfg.initial_fill = f32(panel.ca_fill) / 100.0

	bsp_cfg := BSP_DEFAULT_CONFIG
	bsp_cfg.min_size = panel.bsp_min_size

	corridor_cfg := CORRIDOR_DEFAULT_CONFIG
	corridor_cfg.width = panel.corridor_width

	hybrid_cfg := HYBRID_DEFAULT_CONFIG
	hybrid_cfg.ca_config = ca_cfg
	hybrid_cfg.bsp_config = bsp_cfg
	hybrid_cfg.corridor_config = corridor_cfg
	hybrid_cfg.room_density = f32(panel.hybrid_density) / 100.0

	return ca_cfg, bsp_cfg, corridor_cfg, hybrid_cfg
}

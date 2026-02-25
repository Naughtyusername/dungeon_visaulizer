package dungeon_visualizer

// =============================================================================
// DUNGEON EXPORT & IMPORT
// =============================================================================
// Save generated dungeons to disk for use in actual game projects.
//
// Format: Simple JSON-like text format
//   - Human-readable
//   - Easy to parse in other languages/engines
//   - Includes dungeon metadata, tile grid, and room list
//
// Usage:
//   - export_dungeon(dungeon, "dungeon_01.dun")
//   - dungeon := import_dungeon("dungeon_01.dun")
// =============================================================================

import "core:os"
import "core:fmt"
import "core:strings"

// Export dungeon to file in simple JSON-like format
// Format example:
//   {
//     "width": 80,
//     "height": 45,
//     "tiles": "WWWWWW....",
//     "rooms": [
//       {"x": 10, "y": 15, "w": 8, "h": 6},
//       ...
//     ]
//   }
//
// Parameters:
//   dungeon: Dungeon to save
//   filename: Output file path (e.g., "dungeon.dun" or "exports/level_01.dun")
//
// Returns: true if export succeeded, false on error
export_dungeon :: proc(dungeon: ^Dungeon_Map, filename: cstring) -> bool {
	// Build file content
	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)

	// Header with metadata
	fmt.sbprint(&sb, "{\n")
	fmt.sbprintf(&sb, "  \"width\": %d,\n", dungeon.width)
	fmt.sbprintf(&sb, "  \"height\": %d,\n", dungeon.height)

	// Tile grid: encode as string (W=wall, F=floor) for compactness
	fmt.sbprint(&sb, "  \"tiles\": \"")
	for y in 0..<dungeon.height {
		for x in 0..<dungeon.width {
			tile_char := dungeon.tiles[y][x] == .Wall ? 'W' : 'F'
			fmt.sbprintf(&sb, "%c", tile_char)
		}
		// Add newline in tile string for readability (optional)
		if y < dungeon.height - 1 {
			fmt.sbprint(&sb, "\n")
		}
	}
	fmt.sbprint(&sb, "\",\n")

	// Room list
	fmt.sbprint(&sb, "  \"rooms\": [\n")
	for i in 0..<len(dungeon.rooms) {
		room := dungeon.rooms[i]
		fmt.sbprintf(&sb, "    {{\"x\": %d, \"y\": %d, \"w\": %d, \"h\": %d}}",
			room.x, room.y, room.w, room.h)
		if i < len(dungeon.rooms) - 1 {
			fmt.sbprint(&sb, ",")
		}
		fmt.sbprint(&sb, "\n")
	}
	fmt.sbprint(&sb, "  ]\n")
	fmt.sbprint(&sb, "}\n")

	// Write to file
	content := strings.to_string(sb)
	err := os.write_entire_file_from_string(string(filename), content)

	return err == nil
}

// Import dungeon from file
// Reads a previously exported dungeon and reconstructs it
//
// Parameters:
//   filename: Input file path
//
// Returns: Reconstructed Dungeon_Map, or empty dungeon if load fails
//
// Note: This is a simplified parser. Real-world usage might need
// more robust JSON parsing. For now, this handles the export format.
import_dungeon :: proc(filename: cstring) -> Dungeon_Map {
	dungeon := Dungeon_Map{
		width = MAP_WIDTH,
		height = MAP_HEIGHT,
		rooms = make([dynamic]Room),
	}

	// Read file
	data, err := os.read_entire_file_from_path(string(filename), context.allocator)
	if err != nil {
		return dungeon  // Return empty on read failure
	}
	defer delete(data)

	content := string(data)

	// Simple parser: extract width, height, tiles
	width := extract_int_field(content, "width")
	height := extract_int_field(content, "height")

	if width <= 0 || height <= 0 {
		return dungeon
	}

	dungeon.width = width
	dungeon.height = height

	// Allocate tile grid
	dungeon.tiles = make([][]Tile_Type, height)
	for y in 0..<height {
		dungeon.tiles[y] = make([]Tile_Type, width)
	}

	// Extract and decode tiles
	tiles_str := extract_string_field(content, "tiles")
	tiles_idx := 0
	for y in 0..<height {
		for x in 0..<width {
			if tiles_idx < len(tiles_str) {
				char := tiles_str[tiles_idx]
				dungeon.tiles[y][x] = char == 'W' ? .Wall : .Floor
				tiles_idx += 1
			}
			// Skip newlines in tile string
			if tiles_idx < len(tiles_str) && tiles_str[tiles_idx] == '\n' {
				tiles_idx += 1
			}
		}
	}

	// Extract room list (simple parsing)
	extract_rooms(content, &dungeon.rooms)

	return dungeon
}

// Helper: Extract integer field from JSON-like string
// Looks for: "fieldname": NUMBER
extract_int_field :: proc(content: string, field_name: cstring) -> int {
	target := fmt.tprintf("\"%s\":", field_name)

	pos := strings.index(content, target)
	if pos < 0 {
		return -1
	}

	// Skip past the field name and colon
	start := pos + len(target)

	// Skip whitespace
	for start < len(content) && (content[start] == ' ' || content[start] == '\t') {
		start += 1
	}

	// Parse number
	end := start
	for end < len(content) && content[end] >= '0' && content[end] <= '9' {
		end += 1
	}

	if start >= end {
		return -1
	}

	num_str := content[start:end]
	// Simple atoi
	result := 0
	for char in num_str {
		result = result * 10 + int(char - '0')
	}

	return result
}

// Helper: Extract string field from JSON-like string
// Looks for: "fieldname": "VALUE"
extract_string_field :: proc(content: string, field_name: cstring) -> string {
	target := fmt.tprintf("\"%s\":", field_name)

	pos := strings.index(content, target)
	if pos < 0 {
		return ""
	}

	// Skip to opening quote
	start := pos + len(target)
	for start < len(content) && content[start] != '"' {
		start += 1
	}
	start += 1  // Skip opening quote

	// Find closing quote
	end := start
	for end < len(content) && content[end] != '"' {
		end += 1
	}

	if start >= end {
		return ""
	}

	return content[start:end]
}

// Helper: Extract room list from JSON-like string
// Parses: "rooms": [{...}, {...}, ...]
extract_rooms :: proc(content: string, rooms: ^[dynamic]Room) {
	rooms_start := strings.index(content, "\"rooms\":")
	if rooms_start < 0 {
		return
	}

	// Find opening bracket
	bracket_start := strings.index(content[rooms_start:], "[")
	if bracket_start < 0 {
		return
	}
	bracket_start += rooms_start

	// Find closing bracket
	bracket_end := strings.index(content[bracket_start:], "]")
	if bracket_end < 0 {
		return
	}
	bracket_end += bracket_start

	rooms_str := content[bracket_start + 1:bracket_end]

	// Parse each room object {...}
	pos := 0
	for pos < len(rooms_str) {
		// Find next room object
		obj_start := strings.index(rooms_str[pos:], "{")
		if obj_start < 0 {
			break
		}
		obj_start += pos

		obj_end := strings.index(rooms_str[obj_start:], "}")
		if obj_end < 0 {
			break
		}
		obj_end += obj_start

		obj_str := rooms_str[obj_start:obj_end + 1]

		// Parse x, y, w, h from object
		room_x := extract_object_int(obj_str, "x")
		room_y := extract_object_int(obj_str, "y")
		room_w := extract_object_int(obj_str, "w")
		room_h := extract_object_int(obj_str, "h")

		if room_x >= 0 && room_y >= 0 && room_w > 0 && room_h > 0 {
			append(rooms, Room{x = room_x, y = room_y, w = room_w, h = room_h})
		}

		pos = obj_end + 1
	}
}

// Helper: Extract integer from object field (not quoted)
// Looks for: "fieldname": NUMBER
extract_object_int :: proc(obj_str: string, field_name: cstring) -> int {
	target := fmt.tprintf("\"%s\":", field_name)

	pos := strings.index(obj_str, target)
	if pos < 0 {
		return -1
	}

	start := pos + len(target)
	for start < len(obj_str) && (obj_str[start] == ' ' || obj_str[start] == '\t') {
		start += 1
	}

	end := start
	// Handle negative numbers
	if end < len(obj_str) && obj_str[end] == '-' {
		end += 1
	}
	for end < len(obj_str) && obj_str[end] >= '0' && obj_str[end] <= '9' {
		end += 1
	}

	if start >= end {
		return -1
	}

	num_str := obj_str[start:end]
	result := 0
	is_negative := num_str[0] == '-'
	start_idx := is_negative ? 1 : 0

	for i in start_idx..<len(num_str) {
		result = result * 10 + int(num_str[i] - '0')
	}

	return is_negative ? -result : result
}

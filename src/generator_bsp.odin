package dungeon_visualizer

import "core:math/rand"
import "core:time"

BSP_Node :: struct {
	x, y, w, h: int,
	left, right: ^BSP_Node,
	room: Maybe(Room),
}

BSP_Config :: struct {
	min_size: int,
	max_iterations: int,
}

BSP_DEFAULT_CONFIG :: BSP_Config{
	min_size = 10,
	max_iterations = 8,
}

make_dungeon_bsp :: proc(config := BSP_DEFAULT_CONFIG) -> Dungeon_Map {
	t := time.now()._nsec
	rand.reset(u64(t))

	dungeon := Dungeon_Map{
		width  = MAP_WIDTH,
		height = MAP_HEIGHT,
		rooms  = make([dynamic]Room),
	}
	dungeon.tiles = make([][]Tile_Type, MAP_HEIGHT)
	for y in 0..<MAP_HEIGHT {
		dungeon.tiles[y] = make([]Tile_Type, MAP_WIDTH)
	}

	root := bsp_build(1, 1, MAP_WIDTH - 2, MAP_HEIGHT - 2, config)
	bsp_create_rooms(root, &dungeon)
	bsp_connect_rooms(root, &dungeon)
	bsp_free(root)

	return dungeon
}

bsp_build :: proc(x, y, w, h: int, config: BSP_Config) -> ^BSP_Node {
	node := new(BSP_Node)
	node.x = x
	node.y = y
	node.w = w
	node.h = h
	node.left = nil
	node.right = nil
	node.room = nil

	// Stop splitting if too small
	if w <= config.min_size * 2 || h <= config.min_size * 2 {
		return node
	}

	// Random split direction
	if rand.float32() < 0.5 {
		// Vertical split
		split_range := w - config.min_size * 2
		if split_range > 1 {
			split := x + config.min_size + int(rand.float32() * f32(split_range))
			node.left = bsp_build(x, y, split - x, h, config)
			node.right = bsp_build(split, y, x + w - split, h, config)
		}
	} else {
		// Horizontal split
		split_range := h - config.min_size * 2
		if split_range > 1 {
			split := y + config.min_size + int(rand.float32() * f32(split_range))
			node.left = bsp_build(x, y, w, split - y, config)
			node.right = bsp_build(x, split, w, y + h - split, config)
		}
	}

	return node
}

bsp_create_rooms :: proc(node: ^BSP_Node, dungeon: ^Dungeon_Map) {
	if node == nil {
		return
	}

	if node.left != nil || node.right != nil {
		// Interior node — recurse
		bsp_create_rooms(node.left, dungeon)
		bsp_create_rooms(node.right, dungeon)
	} else {
		// Leaf node — create a room
		room_w := clamp(node.w - 2, 4, node.w)
		room_h := clamp(node.h - 2, 4, node.h)
		room_x := node.x + (node.w > room_w ? rand.int_max(node.w - room_w) : 0)
		room_y := node.y + (node.h > room_h ? rand.int_max(node.h - room_h) : 0)

		room := Room{x = room_x, y = room_y, w = room_w, h = room_h}
		append(&dungeon.rooms, room)
		node.room = room

		// Carve room into dungeon
		for ry in room_y..<room_y + room_h {
			for rx in room_x..<room_x + room_w {
				dungeon.tiles[ry][rx] = .Floor
			}
		}
	}
}

bsp_connect_rooms :: proc(node: ^BSP_Node, dungeon: ^Dungeon_Map) {
	if node == nil || (node.left == nil && node.right == nil) {
		return
	}

	if node.left != nil && node.right != nil {
		// Get rightmost room from left subtree and leftmost room from right subtree
		left_room := bsp_get_room(node.left)
		right_room := bsp_get_room(node.right)

		if left_room != nil && right_room != nil {
			left, _ := left_room.(Room)
			right, _ := right_room.(Room)
			bsp_carve_corridor(left.x + left.w / 2, left.y + left.h / 2,
				right.x + right.w / 2, right.y + right.h / 2, dungeon)
		}

		bsp_connect_rooms(node.left, dungeon)
		bsp_connect_rooms(node.right, dungeon)
	}
}

bsp_get_room :: proc(node: ^BSP_Node) -> Maybe(Room) {
	if node == nil {
		return nil
	}
	if room, ok := node.room.(Room); ok {
		return room
	}
	if node.left != nil {
		if room := bsp_get_room(node.left); room != nil {
			return room
		}
	}
	if node.right != nil {
		if room := bsp_get_room(node.right); room != nil {
			return room
		}
	}
	return nil
}

bsp_carve_corridor :: proc(x1, y1, x2, y2: int, dungeon: ^Dungeon_Map) {
	// Simple L-shaped corridor
	x, y := x1, y1

	// Horizontal first
	for x != x2 {
		if x < x2 {
			x += 1
		} else {
			x -= 1
		}
		if y >= 0 && y < dungeon.height && x >= 0 && x < dungeon.width {
			dungeon.tiles[y][x] = .Floor
		}
	}

	// Then vertical
	for y != y2 {
		if y < y2 {
			y += 1
		} else {
			y -= 1
		}
		if y >= 0 && y < dungeon.height && x >= 0 && x < dungeon.width {
			dungeon.tiles[y][x] = .Floor
		}
	}
}

bsp_free :: proc(node: ^BSP_Node) {
	if node == nil {
		return
	}
	bsp_free(node.left)
	bsp_free(node.right)
	free(node)
}

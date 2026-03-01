package dungeon_visualizer

// =============================================================================
// BINARY SPACE PARTITIONING (BSP) ALGORITHM
// =============================================================================
// Recursively divides the map into rectangular regions, creates a room in
// each leaf node, then connects them with L-shaped corridors. Produces
// structured, room-based dungeons with clear organization.
//
// Algorithm phases:
//   1. bsp_build:       Recursively partition space (depth-first tree)
//   2. bsp_create_rooms: Place rooms in leaf nodes, carve them to floor
//   3. bsp_connect_rooms: Connect rooms with corridors, use tree structure
//   4. bsp_free:         Deallocate tree (prevents memory leaks)
//
// Pros: Structured rooms, good for handcrafted feel, rooms are discrete
// Cons: Regular/predictable, less organic, requires connectivity logic
// Best for: Dungeons, castles, structured locations
// =============================================================================

import "core:math/rand"
import "core:time"

// BSP_Node represents a node in the binary space partition tree
// Interior nodes: have left/right children, represent a split region
// Leaf nodes: no children, contain a room
//
// Fields:
//   x, y:     Top-left corner of this node's region
//   w, h:     Width and height of this node's region
//   left:     Child node from left/top split (or nil if leaf)
//   right:    Child node from right/bottom split (or nil if leaf)
//   room:     Only set on leaf nodes; the room carved into this space
BSP_Node :: struct {
	x, y, w, h: int,
	left, right: ^BSP_Node,
	room: Maybe(Room),
}

// BSP_Config controls generation behavior
// min_size:      Minimum width/height before stopping recursion (10)
// max_iterations: Unused currently; kept for future parameters
BSP_Config :: struct {
	min_size: int,
	max_iterations: int,
}

// BSP_DEFAULT_CONFIG: reasonable defaults for BSP generation
// min_size=10 means leaves are at least 20x20, rooms are 4-18 tiles
BSP_DEFAULT_CONFIG :: BSP_Config{
	min_size = 10,
	max_iterations = 8,
}

// make_dungeon_bsp is the public entry point for BSP generation
// Coordinates the full BSP pipeline:
//   1. Tree building (recursive partitioning)
//   2. Room placement (carve out leaf node rooms)
//   3. Corridor carving (connect adjacent rooms via L-corridors)
//   4. Memory cleanup (free tree nodes)
// Returns a complete Dungeon_Map ready for rendering/gameplay
make_dungeon_bsp :: proc(config := BSP_DEFAULT_CONFIG) -> Dungeon_Map {
	// Seed RNG with nanosecond timestamp
	t := time.now()._nsec
	rand.reset(u64(t))

	// Initialize dungeon and allocate tile grid
	dungeon := Dungeon_Map{
		width  = MAP_WIDTH,
		height = MAP_HEIGHT,
		rooms  = make([dynamic]Room),  // Will be populated by bsp_create_rooms
	}
	dungeon.tiles = make([][]Tile_Type, MAP_HEIGHT)
	for y in 0..<MAP_HEIGHT {
		dungeon.tiles[y] = make([]Tile_Type, MAP_WIDTH)
		// All tiles start as .Wall
	}

	// Build BSP tree: recursive binary space partitioning
	// Start with entire playable area (1..MAP_WIDTH-2, 1..MAP_HEIGHT-2)
	// excludes outer 1-tile border to keep walls intact
	root := bsp_build(1, 1, MAP_WIDTH - 2, MAP_HEIGHT - 2, config)

	// Carve rooms into leaf nodes
	bsp_create_rooms(root, &dungeon)

	// Connect rooms with corridors (post-order tree traversal)
	bsp_connect_rooms(root, &dungeon)

	// Free BSP tree (no longer needed after generation)
	bsp_free(root)

	// Place doors at corridor-room chokepoints
	place_doors(&dungeon)

	return dungeon
}

// bsp_build recursively partitions space into a binary tree of regions
// Uses random splits (vertical/horizontal) to divide rectangles until min_size
// Returns the root of a tree; leaf nodes represent final room placement areas
//
// Parameters:
//   x, y, w, h: Rectangle bounds to partition
//   config:     BSP_Config with min_size (minimum dimension before stopping)
//
// Recursion stops when width or height <= min_size*2
// This ensures leaf regions are large enough to fit a room with padding
//
// Example: min_size=10 → leaves are at least 21x21 → rooms are ~4-18 tiles
bsp_build :: proc(x, y, w, h: int, config: BSP_Config) -> ^BSP_Node {
	// Create a new node for this region
	node := new(BSP_Node)
	node.x = x
	node.y = y
	node.w = w
	node.h = h
	node.left = nil
	node.right = nil
	node.room = nil

	// Base case: region too small to split further
	// Region becomes a leaf node where a room will be placed
	if w <= config.min_size * 2 || h <= config.min_size * 2 {
		return node
	}

	// Recursive case: pick a random split direction
	// 50/50 chance of vertical vs horizontal split
	if rand.float32() < 0.5 {
		// VERTICAL SPLIT: divide along vertical line, creating left/right children
		split_range := w - config.min_size * 2  // Valid split positions
		if split_range > 1 {
			// Choose a split position with min_size gap on both sides
			split := x + config.min_size + int(rand.float32() * f32(split_range))

			// Recurse on left (west) and right (east) regions
			node.left = bsp_build(x, y, split - x, h, config)  // [x..split, y..y+h]
			node.right = bsp_build(split, y, x + w - split, h, config)  // [split..x+w, y..y+h]
		}
	} else {
		// HORIZONTAL SPLIT: divide along horizontal line, creating top/bottom children
		split_range := h - config.min_size * 2  // Valid split positions
		if split_range > 1 {
			// Choose a split position with min_size gap on both sides
			split := y + config.min_size + int(rand.float32() * f32(split_range))

			// Recurse on top (north) and bottom (south) regions
			node.left = bsp_build(x, y, w, split - y, config)  // [x..x+w, y..split]
			node.right = bsp_build(x, split, w, y + h - split, config)  // [x..x+w, split..y+h]
		}
	}

	return node
}

// bsp_create_rooms performs a depth-first tree traversal to carve out rooms
// For interior nodes (with children): recurse into children
// For leaf nodes: create a room, store it, and carve to floor tiles
//
// Room sizing: slightly smaller than the node to create a border of walls,
// and randomly offset within the node to vary layout
bsp_create_rooms :: proc(node: ^BSP_Node, dungeon: ^Dungeon_Map) {
	if node == nil {
		return
	}

	if node.left != nil || node.right != nil {
		// Interior node: recurse into children
		// This is DFS pre-order for the tree structure
		bsp_create_rooms(node.left, dungeon)
		bsp_create_rooms(node.right, dungeon)
	} else {
		// Leaf node: place a room here
		// Reduce room size by ~2 to create padding/walls around the room
		room_w := clamp(node.w - 2, 4, node.w)  // Min 4 wide
		room_h := clamp(node.h - 2, 4, node.h)  // Min 4 tall

		// Randomly position the room within the node
		// Only randomize if there's space; otherwise stick to offset 0
		room_x := node.x + (node.w > room_w ? rand.int_max(node.w - room_w) : 0)
		room_y := node.y + (node.h > room_h ? rand.int_max(node.h - room_h) : 0)

		// Record this room for later connectivity checks
		room := Room{x = room_x, y = room_y, w = room_w, h = room_h}
		append(&dungeon.rooms, room)  // Add to dungeon.rooms list
		node.room = room  // Also store in node for tree traversal

		// Carve the room into the dungeon: set all tiles in room to floor
		for ry in room_y..<room_y + room_h {
			for rx in room_x..<room_x + room_w {
				dungeon.tiles[ry][rx] = .Floor
			}
		}
	}
}

// bsp_connect_rooms recursively connects rooms throughout the tree
// Uses post-order traversal: connect children first, then connect child subtrees
//
// For each interior node with children:
//   - Get a representative room from left and right subtrees
//   - Carve an L-shaped corridor between them
//   - Recurse on both children to connect their subtrees
//
// This ensures all rooms are connected transitively
bsp_connect_rooms :: proc(node: ^BSP_Node, dungeon: ^Dungeon_Map) {
	if node == nil || (node.left == nil && node.right == nil) {
		// Stop at leaf nodes; they have no children to connect
		return
	}

	if node.left != nil && node.right != nil {
		// Get a room from each subtree to connect
		// bsp_get_room does DFS to find any room in the subtree
		left_room := bsp_get_room(node.left)
		right_room := bsp_get_room(node.right)

		// Only carve if both subtrees have rooms
		if left_room != nil && right_room != nil {
			left, _ := left_room.(Room)
			right, _ := right_room.(Room)

			// Carve corridor from left room center to right room center
			// Uses L-shaped path: horizontal first, then vertical
			bsp_carve_corridor(
				left.x + left.w / 2, left.y + left.h / 2,
				right.x + right.w / 2, right.y + right.h / 2,
				dungeon,
			)
		}

		// Recursively connect child subtrees (post-order)
		bsp_connect_rooms(node.left, dungeon)
		bsp_connect_rooms(node.right, dungeon)
	}
}

// bsp_get_room performs DFS to find any room in the subtree rooted at node
// Returns the first room found (pre-order traversal)
// Used by bsp_connect_rooms to find representative rooms for corridor carving
//
// Returns Maybe(Room): either a Room struct or nil if no rooms in subtree
bsp_get_room :: proc(node: ^BSP_Node) -> Maybe(Room) {
	if node == nil {
		return nil
	}

	// If this node has a room, return it
	if room, ok := node.room.(Room); ok {
		return room
	}

	// Otherwise, search left and right subtrees
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

	return nil  // No rooms found in this subtree
}

// bsp_carve_corridor creates an L-shaped corridor from (x1,y1) to (x2,y2)
// First carves horizontally from x1 to x2, then vertically from y1 to y2
// Converts floor tiles along the path, connecting two rooms
//
// L-shaped corridors feel natural and are simple to implement.
// Alternatives: straight corridors, jiggled corridors, wider corridors
//
// Bounds checking: only carves tiles within the dungeon grid
// (Prevents out-of-bounds writes, though well-formed inputs shouldn't hit this)
bsp_carve_corridor :: proc(x1, y1, x2, y2: int, dungeon: ^Dungeon_Map) {
	x, y := x1, y1

	// HORIZONTAL SEGMENT: move from x1 to x2
	for x != x2 {
		// Step one pixel toward target x
		if x < x2 {
			x += 1
		} else {
			x -= 1
		}
		// Carve this tile (with bounds check)
		if y >= 0 && y < dungeon.height && x >= 0 && x < dungeon.width {
			dungeon.tiles[y][x] = .Floor
		}
	}

	// VERTICAL SEGMENT: move from y1 to y2
	for y != y2 {
		// Step one pixel toward target y
		if y < y2 {
			y += 1
		} else {
			y -= 1
		}
		// Carve this tile (with bounds check)
		if y >= 0 && y < dungeon.height && x >= 0 && x < dungeon.width {
			dungeon.tiles[y][x] = .Floor
		}
	}
	// After loop: we've drawn an L from (x1,y1) → (x2,y1) → (x2,y2)
}

// bsp_free recursively deallocates the entire BSP tree
// Uses post-order traversal: free children first, then the node
// Critical: must call this after generation to prevent memory leaks
// The tree is no longer needed after rooms are carved and connected
//
// Post-order is important: freeing parents first would orphan children
bsp_free :: proc(node: ^BSP_Node) {
	if node == nil {
		return
	}

	// Recursively free children
	bsp_free(node.left)
	bsp_free(node.right)

	// Free this node
	free(node)
}

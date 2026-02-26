# Dungeon Visualizer Roadmap

## Completed (Milestones 1 & 2)

### Generation Algorithms
- ✅ Drunkard's Walk (organic caves)
- ✅ BSP (Binary Space Partitioning)
- ✅ Cellular Automata (evolved caves)
- ✅ Hybrid (CA + BSP + explicit corridors)
- ✅ Prefab Rooms (6 hand-crafted templates)

### Core Gameplay Features
- ✅ Flood fill connectivity validation (ensure reachability)
- ✅ Spawn point placement (start/goal with distance constraints)
- ✅ Corridor carvers (L-shaped, straight, waypoint styles)
- ✅ Real-time algorithm switching
- ✅ Raylib visualization with markers

### Tooling & Polish
- ✅ Dungeon statistics display (floor %, rooms, reachability)
- ✅ Reproducible seeding system (FIXED/RANDOM modes)
- ✅ JSON export for game integration
- ✅ Configurable build system (`build.sh`/`build.bat`)
- ✅ Comprehensive code documentation
- ✅ Modular architecture (separate .odin files per feature)

### Game Integration
- ✅ Enemy & Treasure Spawn Point markers (gameplay design aid)
- ✅ Entity export in `.dun` files

## Completed (Milestone 3)

### User Interface
- ✅ **Parameter Tuning UI**
  - Live sliders for generation tweaking
  - CA iterations (1-8), BSP room size (5-20), corridor width (1-3), prefab count (1-10)
  - Real-time regeneration as you adjust
  - Slider hit detection fixed for reliable dragging

- ✅ **Algorithm Comparison Mode (C key)**
  - Side-by-side 4-panel view: same seed, all algorithms
  - Shows complete 80×45 maps (12px tiles) in 960×540 panels
  - Cached regeneration for stable performance
  - Educational tool for algorithm comparison

- ✅ **Fullscreen Toggle (F key)**
  - Independent of comparison mode
  - Scales dungeon to fill screen
  - Works at any resolution

## High-Value Next (Milestone 4)

### User Interface
- **Interactive Prefab Editor**
  - Visual room designer within the visualizer
  - Paint tiles, save as prefab template
  - Export prefabs to code
  - **Impact:** Remove manual code editing for room design
  - **Effort:** 2-3 hours

### Game Integration
- **Room Type System**
  - Tag rooms as boss, treasure, safe zone, etc.
  - Export room metadata with dungeon
  - Helps game engine place entities
  - **Effort:** 1-2 hours

## Nice-to-Have (Future)
- Multi-floor dungeon generation (vertical connectivity)
- Door placement logic
- Destructible walls / dynamic generation
- Performance profiling & optimization
- Settings file (persist preferences without recompiling)
- Keyboard seed input (type seed directly)

---

## Getting Started with Features

**For game integration right now:**
- Export dungeons with `S` key → `.dun` files
- Parse tiles and rooms in your game engine
- Use spawn points for player placement
- Dungeons are saved in simple JSON-like format (tiles as string, rooms as array)

**To extend this tool:**
- All code is modular: pick what you need from `src/`
- Each algorithm is independent (separate `.odin` files)
- No external dependencies beyond Raylib vendor bindings
- Add new algorithms by creating `generator_*.odin` files

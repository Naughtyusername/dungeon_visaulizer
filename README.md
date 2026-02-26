# Dungeon Visualizer

A procedural dungeon generator and visualizer built with Odin and Raylib.

## Description

A complete procedural dungeon generation toolkit for game development and research.
Built in Odin with Raylib visualization.

**Five independent algorithms** with real-time rendering:
- Drunkard's Walk (organic caves)
- Binary Space Partitioning (structured rooms)
- Cellular Automata (evolved caves)
- Hybrid (CA + BSP + explicit corridors)
- Prefab Rooms (hand-designed templates)

**Game-ready features:**
- Connectivity validation (ensures playability)
- Spawn point placement (start/goal)
- Enemy & treasure spawn markers (gameplay design)
- Reproducible seeds (same layout every time)
- JSON export (use in your game)
- Dungeon statistics (coverage, room count, reachability)

## Build and Run

Requires [Odin](https://odin-lang.org/) installed.

### Quick Start (Recommended)

Use the build script (auto-detects Odin):

**Linux/macOS:**
```sh
./build.sh              # Run with optimizations
./build.sh -debug       # Debug build
./build.sh -check       # Check syntax only
```

**Windows:**
```cmd
build.bat              # Run with optimizations
build.bat -debug       # Debug build
build.bat -check       # Check syntax only
```

### Custom Odin Path

If Odin is installed elsewhere, set `ODIN_PATH`:

**Linux/macOS:**
```sh
export ODIN_PATH=/custom/path/to/Odin
./build.sh
```

**Windows:**
```cmd
set ODIN_PATH=C:\custom\path\Odin
build.bat
```

### Manual Build (if scripts don't work)

```sh
/path/to/Odin/odin run src/              # Run
/path/to/Odin/odin run src/ -debug       # Debug
/path/to/Odin/odin check src/            # Check
```

## Controls

| Key       | Action                              |
|-----------|-------------------------------------|
| **1-5**   | Switch algorithms (DW, BSP, CA, Hybrid, Prefab) |
| **Space** | Regenerate current algorithm        |
| **↑/↓**   | Adjust seed (enables fixed mode)    |
| **R**     | Toggle RANDOM/FIXED seed mode       |
| **P**     | Toggle parameter tuning panel       |
| **S**     | Save current dungeon to `.dun` file |
| **Escape** | Quit                                |

**On-Screen Display:**
- Algorithm name and status
- Start (🟩 green) and end (🟥 red) spawn markers
- Dungeon stats: floor %, rooms, reachability, connectivity
- Current seed and mode (FIXED/RANDOM)

## Algorithms

### Completed (Milestone 1 & 2)

1. **Drunkard's Walk** — Random walker carves caves from center outward until 35% floor
   - Simple, organic, fast
   - Best for: cave networks, wandering paths

2. **BSP (Binary Space Partitioning)** — Recursive space splitting creates structured rooms
   - Clean layout, explicit room placement
   - Connections via L-shaped corridors
   - Best for: dungeons, castles, organized layouts

3. **Cellular Automata** — Random initialization + neighbor-rule evolution
   - Natural-looking caves with smooth walls
   - Isolated region removal guarantees connectivity
   - Best for: organic caves, lairs, natural formations

4. **Hybrid (CA + BSP + Corridors)** — Combines CA cave base with BSP rooms inside
   - Organic cave aesthetic + structured rooms
   - Explicit corridor carving between regions
   - Best for: underground bases, mixed indoor/outdoor

5. **Prefab Rooms** — Hand-designed room templates scattered procedurally
   - 7 built-in templates: Boss Room, Treasure Vault, Guard Chamber, Throne Room, Library, Armory, Sleeping Quarters
   - Connectivity validated, corridors auto-carved
   - Best for: showcasing designed spaces, room libraries

## Features Implemented

✅ Five generation algorithms (DW, BSP, CA, Hybrid, Prefab)
✅ Real-time Raylib visualization
✅ Flood fill connectivity validation
✅ Spawn point placement (start/goal)
✅ Dungeon statistics display
✅ Reproducible seeding system
✅ JSON export for game integration
✅ Modular architecture (pick & mix features)
✅ Configurable build system (`build.sh`/`build.bat`)
✅ Comprehensive code documentation

## Planned Features

See [ROADMAP.md](ROADMAP.md) for future work:
- Parameter tuning UI (live sliders for generation tweaking)
- Algorithm comparison mode (4-panel side-by-side view)
- Multi-floor dungeon generation (vertical connectivity)
- Interactive prefab editor (visual room design)
- Enemy/treasure spawn point markers

## Technology

- [Odin](https://odin-lang.org/) programming language
- [Raylib](https://www.raylib.com/) via Odin vendor bindings

## AI Collaboration Disclosure

This project was **vibe-coded with AI assistance** ([Claude](https://claude.ai/)).
Architecture, algorithms, and implementation were developed collaboratively
between a human developer and an AI. Treat the code accordingly.

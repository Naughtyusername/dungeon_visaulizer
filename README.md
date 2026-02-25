# Dungeon Visualizer

A procedural dungeon generator and visualizer built with Odin and Raylib.

## Description

A toolkit for procedural dungeon generation research and game development.
Three independent algorithms render in real-time: Drunkard's Walk, Binary Space
Partitioning (BSP), and Cellular Automata. Switch between them to compare
generation styles, tune parameters, and understand roguelike level design
fundamentals.

## Build and Run

Requires [Odin](https://odin-lang.org/) installed at `~/tools/Odin`.

```sh
~/tools/Odin/odin run src/
```

Debug build:
```sh
~/tools/Odin/odin run src/ -debug
```

## Controls

| Key      | Action                    |
|----------|---------------------------|
| Spacebar | Regenerate current algo   |
| 1        | Drunkard's Walk algorithm |
| 2        | BSP algorithm             |
| 3        | Cellular Automata caves   |
| Escape   | Quit                      |

## Implemented Algorithms

- **Drunkard's Walk** — A walker starts at center and stumbles in random
  cardinal directions, carving floor tiles until 35% of the map is open.
  Produces organic, winding caves.

- **BSP (Binary Space Partitioning)** — Recursively splits space, creates rooms
  in leaf nodes, connects them with corridors. Produces structured dungeons
  with clear rooms and corridors.

- **Cellular Automata** — Random wall initialization + iterative evolution using
  neighbor rules (4+ wall neighbors → become wall). Isolated regions are removed,
  keeping only the largest cave system. Produces organic, connected cave networks.

## Roadmap

See [ROADMAP.md](ROADMAP.md) for planned features:
- Flood fill connectivity validation (ensure all floors are reachable)
- Prefab room placement (hand-designed rooms)
- Hybrid generation (combine algorithms)
- Parameter tuning UI (live sliders)
- Export functionality (JSON/binary)

## Technology

- [Odin](https://odin-lang.org/) programming language
- [Raylib](https://www.raylib.com/) via Odin vendor bindings

## AI Collaboration Disclosure

This project was **vibe-coded with AI assistance** ([Claude](https://claude.ai/)).
Architecture, algorithms, and implementation were developed collaboratively
between a human developer and an AI. Treat the code accordingly.

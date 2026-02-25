# Dungeon Visualizer

A procedural dungeon generator and visualizer built with Odin and Raylib.

## Description

Generates dungeons using the Drunkard's Walk algorithm and renders them as
a colored tile grid. Press spacebar to regenerate.

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

| Key      | Action             |
|----------|--------------------|
| Spacebar | Regenerate dungeon |
| Escape   | Quit               |

## Algorithms

- **Drunkard's Walk** — A walker starts at center and stumbles in random
  cardinal directions, carving floor tiles until 35% of the map is open.

## Planned Algorithms

- BSP (binary space partitioning)
- Cellular automata (cave generation)
- Prefab room placement

## Technology

- [Odin](https://odin-lang.org/) programming language
- [Raylib](https://www.raylib.com/) via Odin vendor bindings

## AI Collaboration Disclosure

This project was **vibe-coded with AI assistance** ([Claude](https://claude.ai/)).
Architecture, algorithms, and implementation were developed collaboratively
between a human developer and an AI. Treat the code accordingly.

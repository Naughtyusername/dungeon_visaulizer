# Dungeon Visualizer Roadmap

## Completed (Milestone 1)
- ✅ Drunkard's Walk algorithm
- ✅ BSP (Binary Space Partitioning) algorithm
- ✅ Cellular Automata caves algorithm
- ✅ Real-time algorithm switching
- ✅ Raylib visualization

## High-Value Next (Milestone 2)

### Core Algorithms
- **Flood Fill Connectivity Check** (PRIORITY)
  - Ensure every floor tile is reachable from every other floor tile
  - Remove isolated regions or connect them
  - Fundamental technique for roguelikes, critical before shipping
  - Use case: guarantee playable dungeons

- **Prefab Room Placement**
  - Hand-designed rooms stored as templates
  - Place and connect procedurally
  - Great for landmarks, boss rooms, special areas
  - High value for 7DRL and narrative-driven games

- **Corridor Carvers**
  - Explicit L-shaped and straight corridor logic
  - Connect distant regions intentionally
  - Currently implicit in BSP; explicit version for CA and Drunkard's Walk

- **Hybrid Generation**
  - Combine algorithms in one dungeon (e.g., BSP rooms + Drunkard's Walk corridors)
  - CA caves with prefab rooms stamped in
  - Where procedural generation gets really interesting

### Spawn & Navigation
- **Spawn Point Logic**
  - Place guaranteed start/end points on valid floor
  - Enforce minimum distance between them
  - Critical for game integration

### Tooling & Polish
- **Parameter Tuning UI**
  - Live sliders for CA iterations, BSP min room size, walk density
  - Real-time feedback on generation changes
  - Makes the tool much more explorable

- **Export Functionality**
  - Save generated dungeons (JSON/binary)
  - Format your actual game can consume
  - Bridge from visualizer to game engine

- **Algorithm Comparison Mode**
  - Same seed, four panels, all algorithms side-by-side
  - Educational + helps pick best algo for each game

## Nice-to-Have (Later)
- Multi-floor dungeon generation (vertical connectivity)
- Enemy/treasure spawn point markers
- Door placement logic
- Destructible walls / dynamic generation
- Performance profiling & optimization
- Seed input/display (reproducible dungeons)

---

**Next focus:** What's calling to you from the high-value list?

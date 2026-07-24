**PROJECT CONTEXT**  
I am working on the Godot project `BlockForge` (branch `complexity`). The main scene is `scenes/GameScene/game_scene.tscn` with scripts like `world_generator.gd`, `TopDown_WorldGen.gd`, `manual_camera_mover.gd`, etc. The project already has `classes/yaml.gd` for parsing YAML. World generation already handles seeded 1D noise for biomes and mountains.

**TASK**  
Refactor and implement a scalable chunk-based world system in a new `scenes/GameScene/mapping/` folder. All new logic must be modular for team collaboration.

**IMPORTANT GODOT EDITOR BEST PRACTICES**  
- Prefer Godot Editor workflows over code where customary (e.g. TileSet atlases, texture imports, scene instancing, CollisionShape2D setup, AnimationPlayer, etc.).  
- Do **not** generate code that creates TileSets, atlases, or import settings at runtime unless absolutely necessary. Assume these are set up in the editor and reference them by resource path.  
- Use `@export` variables, `preload()`, and `load()` for resources created in the editor.  
- For TileMaps: Assume a proper TileSet with atlases has already been created in the Godot editor. Only write code that assigns the TileSet and sets cells.  
- Generate scenes (.tscn) structure suggestions only when needed; prefer attaching scripts to existing or new nodes in the editor.  
- Follow Godot 4 conventions and editor-first design. If something is normally done in the IDE (inspector, TileSet editor, etc.), note it and provide the minimal script code that uses the editor-created assets.

**CODE STYLE GUIDELINES**  
Match the existing code style in the project as closely as possible:
- Use the same naming conventions (e.g. snake_case for variables/functions, PascalCase for classes).
- Follow the commenting style and code organization seen in `world_generator.gd` and other scripts.
- Prefer similar patterns for signals, exports, and node handling.
- Keep scripts concise and modular like the rest of the codebase.

## REQUIREMENTS (implement exactly)

### INITIAL world_config.yaml
Create this file with the following content (expandable later):

```
# World Configuration
chunk_size: 64
world_chunks_wide_max: 256
world_chunks_tall_max: 16
tile_size_px: 16
preload_margin_blocks: 2

# Zoom and performance limits (tune during playtesting)
max_zoom: 4.0
min_zoom: 0.125
safe_min_zoom: 0.5
max_active_tilemaps: 4096

default_viewport_width_px: 2096
default_viewport_height_px: 1024

# World seed (can be overridden by save file)
world_seed: 42
```

### Configuration
- Create `data/world_config.yaml` and load it using the existing `classes/yaml.gd`.
- Support world sizes up to 16,384 tiles wide × 1,024 tiles tall (256×16 chunks of 64×64).
- Include in YAML: `chunk_size`, `world_chunks_wide_max`, `world_chunks_tall_max`, `tile_size_px`, `preload_margin_blocks`, `max_zoom` (default 4.0), `min_zoom`, `safe_min_zoom`, `max_active_tilemaps` (default 128), default viewport sizes, world seed.

### Data & Persistence
- Chunks are 64×64 `PackedInt64Array` (terrain + item + data packed per tile).
- Create `ChunkData.gd` for chunk struct and helpers (including bit packing).
- `ChunkManager.gd` for in-memory active chunks.
- `ChunkPersistence.gd`: Use one file per column (`user://world_columns/column_XXX.dat`). Save on generation and when dropping TileMaps. Support RLE + compression. Include extra functions to save/load currently mapped (active) TileMaps state.

### TileMap Handling
- `TileMapPopulator.gd`: Convert chunk array → set cells on per-chunk `TileMap` nodes using `set_cell()`. Create/destroy TileMap nodes per chunk as they stream in/out. Use editor-created TileSet.

### Streaming & Memory Management
- `VisibilityManager.gd`: Calculate visible chunks based on player position, camera zoom, and viewport size. Preload when player is within `preload_margin_blocks` of edge. Drop/unload TileMaps (queue_free or pool) when far off-screen.
- Generate full vertical columns when needed (for layer height continuity).

### Cross-Chunk Features
- Currently only trees. Implement them on empty “neighbor” chunks. If another feature covers them, it’s okay (no special conflict resolution needed now).

### TileMap Handling
- `TileMapPopulator.gd`: Convert chunk array → set cells on per-chunk TileMap nodes. Create/destroy TileMap nodes per chunk as they stream in/out.

### Camera, Zoom & Display (`CameraController.gd` + `WorldBoundsFiller.gd`)
- Camera follows player **exactly**.
- Dynamic zoom with limits from YAML.
- At high zoom (4×), use **pixel-perfect filtering** (`texture_filter = TEXTURE_FILTER_NEAREST`).
- If camera view shows above world top → fill with sky. Below bottom → fill with lava.

### UI Preservation
- Preserve the existing inventory display on the right side of the screen.
- Ensure the inventory UI stays "in front" of the world (use proper CanvasLayer or Control node layering).
- Do not break or hide the current hotbar/inventory UI when implementing the new chunk system and camera.
- The world should render behind the UI elements.

### Generation Integration
- Extend `world_generator.gd` with `fill_chunk_array(chunk_x, chunk_y, out_array)` that reuses existing noise/layer height/caves/trees logic.
- Add `TODO: Async/threaded generation` comment in the column generation path.
- Add `TODO: Procedural objects placement` comment where special objects (from spatial hash system) would integrate.

### Initialization
- `WorldInitializer.gd`: Generate center column(s), place player at ground level in the exact center of the map (query surface Y from chunk data), set initial camera and zoom.

### World Edge Handling
- The world is finite but should feel seamless at the edges.
- When the player approaches the left/right edge of the world, wrap column loading/generation so movement feels continuous (toroidal-style column indexing for loading purposes).
- Camera and visibility should handle wrapping gracefully so the player doesn't see hard stops unless intended.
- Add comments for future non-wrapping hard bounds if needed.

### Modular Files to Create (in mapping/)
1. WorldConfig.gd
2. ChunkData.gd
3. ChunkManager.gd
4. ChunkPersistence.gd
5. TileMapPopulator.gd
6. VisibilityManager.gd
7. WorldInitializer.gd
8. CameraController.gd
9. WorldBoundsFiller.gd
10. MappedTilesSaver.gd (for extra active tilemap save/load)

### Debugging & Timing
- Use Godot's built-in `print_verbose()` for all debug output and timing information.
- Enable "Debug > Stdout Verbose" in Project Settings for this development phase.
- Prefix messages clearly, e.g.:
  - `[Chunk] Loaded column 45 in 23 ms`
  - `[Visibility] Updated 12 chunks`
  - `[Expiration] Processed 8 items in 4 ms`
- Use `Time.get_ticks_msec()` to measure and report elapsed time for key operations (column load, generation, save, visibility update, etc.).

### Output Style (Interactive-Friendly)
- Start by listing the exact backup steps you will perform.
- Proceed in logical order: Config → ChunkData → Persistence → etc.).
- Provide each new file with full, well-commented GDScript code.
- After each major file, include a short "How to integrate / test this" note.
- Use Godot 4 best practices and match the project's existing style.
- Be ready to iterate: I will likely ask for adjustments, the next file, or fixes after testing.

Use Godot 4 best practices for performance on large worlds.

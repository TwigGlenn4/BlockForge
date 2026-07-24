PROMPT NEXT

### Recommended Next Steps (After Core Chunk System)

After the chunk system is working, implement the following in this priority order for a fast playable vertical slice:

1. **Background Layer**  
   - Add a background `TileMap` layer for walls that remain visible after digging.  
   - Reveal this layer when foreground tiles are removed.

2. **Basic Lighting & Shading**  
   - Underground darkness that increases with depth.  
   - Simple point lights (torches) and fake orthogonal shading on dug edges.

3. **Player Digging**  
   - Left-click (or tool use) to dig foreground blocks.  
   - Update the chunk's `PackedInt64Array`, mark chunk dirty, and spawn particles/items.

4. **Item Collection**  
   - Dug materials drop as pickups and go into player inventory.

5. **Pathfinding**  
   - Improve surface point-and-click movement.  
   - Add per-chunk cached pathfinding for general navigation (rebuild cache when chunk changes).

6. **Advanced Features** (Phase 2)  
   - Autodigging mechanics.  
   - Full complex object support (monsters, workbenches, moving entities).  
   - Expiration system for static items (torches going out, fruit falling, etc.).

Focus first on making digging + collection feel good with the new chunk system.

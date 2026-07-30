Legacy worldgen quarantine
==========================

Tracked under `legacy/` (repo root) so these stay in git.
`utilities_glenn/` is locally excluded and must not hold archived game code.

Files
-----
- chunk.gd — old Chunk class (WIDTH=128, HEIGHT=512). Live code uses WorldConfig + ChunkData.
- world_generator.gd — old full-world / threaded Chunk[] generator (class_name removed)
- WorldGenTimer.gd — timer helper for deleted WorldGenV2 gentimer_* signals
- TopDown_WorldGen.gd — unused experimental TileMap generator
- manual_camera_mover.gd — unused camera script (legacy chunk-queue hooks already removed)

Live generation / sizes
-----------------------
- Gen: WorldGenV2.fill_column → VisibilityManager → ChunkManager / ChunkData
- Width: WorldConfig.chunk_size() / world_width_tiles() / world_height_tiles()

Do not re-attach these to GameScene without restoring World.chunks[] and the
deleted queue_chunk / generate_chunk pipeline.

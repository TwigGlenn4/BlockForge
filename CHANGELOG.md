
# CHANGELOG

# Early Logs

## 1-28-24

 - Loads of helper functions
 - Funcs to help with global coordinates instead of chunk local coordinates
 - Tree generation seperated from large generate_chunk function
 - Add non-functional spawn portal
 - Prevent trees from spawning over blocks
 - Add some checks for undefined tiles
 - Add keybind to regenerate with random seed. (first seed constant for testing)
 - Create python scripts with PIL to overlay texture on existing textures
 - Generate texture atlases with PIL 

## 1-29-24

 - Add leaf tile
 - Add leaves to trees
 - Pull out chunk and some helpers to seperate file for modularity
 - Make generation non-blocking using physics process
 - Add progress bar for world generation
 - Add growable tiles list
 - Trees only generate on growable tiles (no more desert humidity cutoff)
 - Keep portal to center half of world
 - Tree generation uses similar noise to humidity.

## 2-3-24

 - Chunk generation moved to Chunk class
 - Threaded chunk generation, need to fix blocking again
 - Use classes instead of preload for Tiles, Helpers, Chunk, WG_Settings
 - Add minimum height for trees
 - Add look_at_portal keybind (P, KeyPad_0)
 - Add keybind (M) to print mouse global coordinates
 - Setup Trello for project management [https://trello.com/b/nR7499xf/blockheadsrenewedg](https://trello.com/b/nR7499xf/blockheadsrenewedg)

## 2-4-24

 - generation step trees now takes seed as parameter instead of entire noise class.
 - Start cave generation

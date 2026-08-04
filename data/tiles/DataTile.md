# DataTiles
A DataTile contains the definition of a tile (block) in the world

## Location
* `data/tiles/[namespace]/[tile_group_name].yaml`
* `[namespace]` and `[tile_group_name]` are not enforced to any value and only exist for organization

## Format

```yaml
format-version: 1
tiles:
  "blockforge:grass":
    texture:
      atlas: "terrain.png"
      x: 7
      y: 0
    name: "Grass"
    drops: "blockforge:dirt"
    background: "blockforge:dirt"
  "blockforge:workbench":
    texture:
      atlas: "workstations.png"
      x: 0
      y: 0
    drops: ""
    background: "blockforge:wood_planks"
    interaction: "craft"
    deco-layer: true
```

The `tile_id` and `texture` items must be included. The other items are optional and will use defaults if not set.

`name`: Name to be shown in UI

* `""` (Empty string): Default to `tile_id`. (default)
* String: User friendly name

`drops`: What should be dropped/given to the character that breaks this tile

* `""` (Empty string): Drops itself. (default)
* ItemStackString: Drops a number of items of a given type. An ItemStackString is an item_id and optionally a count. ex. `"blockforge:dirt 2"` or `"blockforge:grass"`.
* `none`: Drops nothing.

`background`: What tile is remains in the background layer when this tile is destroyed

* `""` (Empty string): Uses itself as the background. (default)
* Tile ID: Use a different tile as the background. ex. `"blockforge:dirt"`.
* `none`: No background (air).

`interaction`: What should happen when this block is interacted with

* `""` (Empty string): No special interaction. A break job will be created on interaction. (default)
* `craft`: A recipe selector will be opened using this tile's `tile_id`.
* More will be implemented in the future for storage, fueled crafting, etc.

`deco-layer`: Does this tile exist in the decoration layer

* `false`: This tile exists in the foreground layer and blocks movement. (default)
* `true`: This tile exists in the decoration layer and does not block movement.

### YAML notes

* Tile and item IDs should always be inside quotes because the colon character `:` that we use as a namespace seperator has meaning in YAML.
* Quotes are optional for strings that don't contain special characters.
* Empty strings should not be removed or the parser may assume it indicates a new indent.

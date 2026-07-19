#!/usr/bin/python3
# Quick script to stitch underground sprites into an atlas

from PIL import Image
from os import path

script_path = path.dirname(path.realpath(__file__))
atlas_path = script_path + "/../../atlas"

print("Generating underground atlas...")

tiles = [
    "limestone",
    "marble",
    "ore_coal",
    "ore_tin",
    "ore_copper",
    "ore_iron",
    "ore_gold",
    "ore_titanium",
    "ore_platinum",
    "black_sand",
    "flint",
    "clay",
    "oil",
    "sandstone",
    "red_marble",
    "lapis_lazuli",
]

TILE_SIZE = 16
ATLAS_X = 16

atlas = Image.new("RGBA", (TILE_SIZE * ATLAS_X, TILE_SIZE), (0, 0, 0, 0))

print("Looping through tiles...")

for i, name in enumerate(tiles):
    sprite_path = script_path + "/" + name + ".png"
    print(sprite_path)

    if not path.isfile(sprite_path):
        print("Leaving sprite " + str(i) + " (" + name + ") blank due to nonexistent sprite...")
        continue

    sprite = Image.open(sprite_path)
    if sprite.size != (TILE_SIZE, TILE_SIZE):
        sprite = sprite.resize((TILE_SIZE, TILE_SIZE), Image.LANCZOS)
    atlas.paste(sprite, (i * TILE_SIZE, 0))

print("Atlas generated with " + str(len(tiles)) + " tile slots, saving...")

atlas.save(atlas_path + "/underground.png")

print("Done!")

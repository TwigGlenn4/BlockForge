#!/usr/bin/python3
# Twig Griffin (TwigGlenn4)
# 01-28-24
# Quick, customizable script to stitch multiple sprites into an atlas

from PIL import Image
from math import ceil
from os import path

project_root = "/home/twig/GodotProjects/BlockheadsRenewedG"
textures = project_root + "/assets/textures"

print("Generating terrain atlas...")

tiles = [
  "undefined",
  "dirt",
  "stone",
  "cobble",
  "water",
  "sand",
  "snow",
  "grass",
  "log",
  "leaves",
  "ore_tin"
]

TILE_SIZE = 16 # edge length of a sprite
ATLAS_X = 16   # number of sprites per row

ATLAS_Y = ceil(len(tiles) / ATLAS_X)


atlas = Image.new('RGBA', (TILE_SIZE * ATLAS_X, TILE_SIZE * ATLAS_Y), (0,0,0,0) )

print("Looping through tiles...")

i = 0
for x in range(ATLAS_X):
  if i >= len(tiles):
    break

  for y in range(ATLAS_Y):
    if i >= len(tiles):
      break
    
    sprite_path = textures + "/raw/terrain/"+tiles[i]+".png"

    if not path.isfile(sprite_path):
      print("Leaving sprite "+str(i)+" ("+tiles[i]+") blank due to nonexistent sprite...")
      i += 1
      continue

    sprite = Image.open(sprite_path)
    atlas.paste(sprite, (x * TILE_SIZE, y * TILE_SIZE))

    i += 1

print("Atlas generated with "+str(i)+" tiles, saving...")

atlas.save(textures + "/atlas/terrain.png")

print("Done!")

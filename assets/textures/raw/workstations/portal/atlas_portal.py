#!/usr/bin/python3
# Twig Griffin (TwigGlenn4)
# 01-28-24
# Stitches the portal textures into an atlas containing the base sprites followed by frames of an animated portal

from PIL import Image

project_root = "/media/DATA/Godot/Projects/BlockheadsRenewedG"
textures = project_root + "/assets/textures"

TILE_SIZE = 16
NUM_FRAMES = 1


atlas = Image.new('RGBA', (TILE_SIZE * (NUM_FRAMES + 1), 2*TILE_SIZE), (0,0,0,0) )

# Add bases
base_stone = Image.open(textures + "/raw/workstations/portal/portal_base_stone.png")
base_cobble = Image.open(textures + "/raw/workstations/portal/portal_base_cobble.png")
atlas.paste(base_stone, (0,0))
atlas.paste(base_cobble, (0, TILE_SIZE))

for i in range( NUM_FRAMES ):
  frame = Image.open(textures + "/raw/workstations/portal/portal_"+str(i+1)+".png")
  atlas.paste( frame, ((i+1)*TILE_SIZE, 0) )

atlas.save(textures + "/atlas/portal.png")

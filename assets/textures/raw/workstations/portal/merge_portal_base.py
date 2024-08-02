#!/usr/bin/python3
# Twig Griffin (TwigGlenn4)
# 01-28-24
# Adds an overlay with transparency on top of another texture.

from PIL import Image

project_root = "/media/DATA/Godot/Projects/BlockheadsRenewedG"
textures_raw = project_root + "/assets/textures/raw"


stone = Image.open(textures_raw + "/terrain/stone.png")
cobble = Image.open(textures_raw + "/terrain/cobble.png")
portal_base_overlay = Image.open( textures_raw + "/workstations/portal/portal_base_overlay.png")

print("Opened textures, combining...")

Image.alpha_composite(stone, portal_base_overlay).save(textures_raw + "/workstations/portal/portal_base_stone.png")
Image.alpha_composite(cobble, portal_base_overlay).save(textures_raw + "/workstations/portal/portal_base_cobble.png")
print("Done!")

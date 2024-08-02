class_name Helpers

const TILES = preload("res://classes/tiles.gd")

### NOISE FUNCTIONS


# create_noise(): return a new noise generator.
static func create_noise( nseed, freq, oct ):
  var noise_gen = FastNoiseLite.new()
  noise_gen.seed = nseed             # Seed defines the contents of the noise
  noise_gen.frequency = freq        # Frequency defines how jagged the noise is
  noise_gen.fractal_octaves = oct   # Octaves defines how many layers are used
  noise_gen.noise_type = FastNoiseLite.TYPE_SIMPLEX
  return noise_gen


# noise_array_1d(): Returns an array of length containing values from 0.0 to 1.0 according to noise
static func noise_array_1d( generator, length, offset=0):
  var array = []
  array.resize(length)
  for i in range(length):
    array[i] = generator.get_noise_1d(offset + i) + 0.5
  return array


# noise_array_2d(): Returns a 2d array containing values from 0.0 to 1.0 according to noise
static func noise_array_2d( generator, size: Vector2i, ridged=false):
  var array = {}
  for x in size.x:
    for y in size.y:
      array[Vector2i(x, y)] = generator.get_noise_2d( x, y )
      if ridged:
        array[Vector2i(x, y)] = absf( array[Vector2i(x, y)] )
      else:
        array[Vector2i(x, y)] += 0.5
  return array

# noise_array_2d_offset(): Returns a 2d array containing values from 0.0 to 1.0 according to noise
static func noise_array_2d_offset( generator, size: Vector2i, offset: Vector2i, ridged=false):
  var array = {}
  for x in size.x:
    for y in size.y:
      array[Vector2i(x, y)] = generator.get_noise_2d( x+offset.x, y+offset.y )
      if ridged:
        array[Vector2i(x, y)] = absf( array[Vector2i(x, y)] )
      else:
        array[Vector2i(x, y)] += 0.5
  return array

### ARRAY FUNCTIOINS

# Each value will be pre-incremented, multiplied, and post-incremented
static func array_scale( array, multiplier = 1.0, constant = 0.0 ):
  for i in len(array):
    array[i] = array[i] * multiplier + constant
  return array


# local_max_array(): returns an array of 0's and 1's where 1 corresponds to a local maximum.
static func array_local_max( array ):
  var result = []
  result.resize( len(array) )

  for i in range(1, len(array)-1):
    if array[i] > array[i-1] && array[i] > array[i+1]:
      result[i] = 1
    else:
      result[i] = 0
  
  result[0] = 0
  result[len(array)-1] = 0

  return result


static func array_local_max_vec2i( array_vec2i, size:Vector2i ):
  var result = {}

  # check peaks
  for x in range(1, size.x-1):
    for y in range(1, size.y-1):
      var pos: Vector2i = Vector2i(x, y)
      if array_vec2i[pos] < array_vec2i[Vector2i(x+1, y)]: # right
        result[pos] = 0
        continue
      if array_vec2i[pos] < array_vec2i[Vector2i(x-1, y)]: # left
        result[pos] = 0
        continue
      if array_vec2i[pos] < array_vec2i[Vector2i(x, y+1)]: # up
        result[pos] = 0
        continue
      if array_vec2i[pos] < array_vec2i[Vector2i(x, y-1)]: # down
        result[pos] = 0
        continue
      result[pos] = 1
  
  # zero borders
  for x in size.x:
    result[Vector2i(x,0)] = 0
    result[Vector2i(x,size.y)] = 0
  for y in size.y:
    result[Vector2i(0,y)] = 0
    result[Vector2i(size.x,y)] = 0

  return result



# is_growable(): returns true if given tile is in TILES.GROWABLE
static func is_growable( tile ):
  if TILES.GROWABLE.find(tile) == -1:
    return false
  return true


# coord_string(): format given coordinates as (x, y)
static func coord_string( x:int, y:int ):
  return "("+str(x)+", "+str(y)+")"

# Convert between block coordinates and godot pixel units
static func pos_block_to_pixel( block_pos: Vector2 ):
  return Vector2(block_pos.x*16 + 8, -block_pos.y*16 - 8)
static func pos_pixel_to_block( block_pos: Vector2 ):
  return Vector2((block_pos.x-8)/16.0, (-block_pos.x+8)/16.0)

# camera_to(): centers the camera on the given position at given zoom
static func camera_to( cam: Camera2D, pos: Vector2, zoom=null ):
  cam.position = pos_block_to_pixel(pos)
  if zoom != null and typeof(zoom) == Variant.Type.TYPE_VECTOR2:
    cam.zoom = zoom

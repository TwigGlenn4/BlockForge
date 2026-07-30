## Stores points along a path and handles the array management.
class_name Path

## Front of array is start, end of array is destination
var _points: Array[Vector2i]
## Points to the first Vector2i in the path
var _start_idx: int
## Points to the index of where a new point will reside
var _end_idx: int

func _init() -> void:
    _points.resize(10)
    _start_idx = 0
    _end_idx = 0

## Get the number of points in the path
func size() -> int:
    return _end_idx - _start_idx

## Get the next point in the path
func next() -> Vector2i:
    return _points.get(_start_idx)

## Get and remove the next point in the path. This does not actually rearrange the array and therefore does not have a significant performance hit.
func pop_next() -> Vector2i:
    var next_point: Vector2i = _points.get(_start_idx)
    _start_idx += 1
    return next_point

func destination() -> Vector2i:
    return _points.get(_end_idx-1)

func add_point(new_point: Vector2i) -> void:
    if _points.size() <= _end_idx: # extend _points array in increments of 10
        _points.resize(_points.size()+10)
    _points.set(_end_idx, new_point)
    _end_idx += 1

func as_array() -> Array[Vector2i]:
    return _points.slice(_start_idx, _end_idx)

func _to_string() -> String:
    return "Path: " + str(as_array())

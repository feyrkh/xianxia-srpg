extends Object
class_name Array2D

var arr:Array = []
var width:int = 0
var height:int = 0

func s(x:int, y:int, val:Variant):
	if arr.size() <= y:
		arr.resize(y+1)
		height = y+1
	if !arr[y]:
		arr[y] = []
	if arr[y].size() <= x:
		arr[y].resize(x+1)
		width = max(width, x+1)
	arr[y][x] = val

func g(x:int, y:int, default=null):
	if x < 0 or y < 0:
		return default
	if arr.size() <= y:
		return default
	if !arr[y] || arr[y].size() <= x:
		return default
	if arr[y][x] == null:
		return default
	return arr[y][x]

## If the cell at x/y is an array, this appends the given value to it
## If the cell at x/y is not an array, this creates an array and appends the given value to it
func append(x:int, y:int, val) -> void:
	var orig_val = g(x, y)
	if orig_val is Array:
		orig_val.append(val)
	elif orig_val == null:
		s(x, y, [val])
	else:
		s(x, y, [orig_val, val])

func resize(x:int, y:int):
	arr.resize(y)
	for i in range(y):
		var row = arr[i]
		if row == null:
			row = []
			row.resize(x)
			arr[i] = row
		else:
			arr[i].resize(x)

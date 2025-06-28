extends Object
class_name TacticalMapSerializer

const MAGIC = "TMAP"
const VERSION: int = 1

static func save_map(filename: String, tile_map:Array2D) -> void:
	var save_dir = "user://maps"
	if not DirAccess.dir_exists_absolute(save_dir):
		DirAccess.make_dir_recursive_absolute(save_dir)
	var file := FileAccess.open(save_dir+"/"+filename+".map", FileAccess.WRITE)
	file.store_buffer(MAGIC.to_ascii_buffer())
	file.store_8(VERSION)
	print("Map is %d x %d tiles" % [tile_map.width, tile_map.height])
	for y in tile_map.height:
		for x in tile_map.width:
			var stack = tile_map.g(x, y).filter(func(entry): return entry != null and is_instance_valid(entry))
			if !stack or stack.is_empty():
				continue
			print("Writing %d,%d = %d" % [x, y, stack.size()])
			file.store_16(x)
			file.store_16(y)
			file.store_8(stack.size())
			for tile in stack:
				file.store_float(tile.h)
				file.store_float(tile.base)
				file.store_8(tile.terrain_type)
	file.close()

static func load_map(file_path: String) -> Array:
	var file := FileAccess.open(file_path, FileAccess.READ)
	var result:Array = []

	var header = file.get_buffer(4)
	if header.get_string_from_ascii() != MAGIC:
		push_error("Invalid tile map file header.")
		return result

	var version = file.get_8()
	if version != VERSION:
		push_warning("Tile map version mismatch: got %d, expected %d" % [version, VERSION])
		# Optional: fallback to compatibility loader here

	while not file.eof_reached():
		if file.get_length() - file.get_position() < 5:
			break  # Prevent reading beyond file size

		var x = file.get_16()
		var y = file.get_16()
		var count = file.get_8()
		for i in count:
			if file.get_position() + 9 > file.get_length():
				push_warning("Unexpected EOF while reading tile stack.")
				break
			var h = file.get_float()
			var base = file.get_float()
			var terrain = file.get_8()
			var tile := TileInfo.new()
			tile.x = x
			tile.y = y
			tile.h = h
			tile.base = base
			tile.terrain_type = terrain as TerrainInfo.TypeNames
			result.append(tile)
	file.close()
	return result

extends Object
class_name TacticalMapSerializer

const MAGIC = "TMAP"
const VERSION: int = 2

class LoadMapData:
	var tile_data:Array = []
	var unit_placement_data:Array[MapUnitPosition] = []

static func save_map(filename: String, map:TacticalMap) -> void:
	var save_dir = "user://maps"
	if not DirAccess.dir_exists_absolute(save_dir):
		DirAccess.make_dir_recursive_absolute(save_dir)
	var file := FileAccess.open(save_dir+"/"+filename+".map", FileAccess.WRITE)
	file.store_buffer(MAGIC.to_ascii_buffer())
	file.store_8(VERSION)
	# Save map unit positions
	MapUnitPosition.serialize(file, map.unit_placements_node.get_children())
	
	# Save tile map
	var tile_map := map.tile_map
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

static func load_map(file_path: String) -> LoadMapData:
	var file := FileAccess.open(file_path, FileAccess.READ)

	var header = file.get_buffer(4)
	if header.get_string_from_ascii() != MAGIC:
		push_error("Invalid tile map file header.")
		return null

	var version = file.get_8()
	if version != VERSION:
		push_warning("Tile map version mismatch: got %d, expected %d" % [version, VERSION])
		if version == 1:
			return load_map_v1(file)
		else:
			return null
	return load_map_v2(file)

static func load_map_v2(file:FileAccess) -> LoadMapData:
	var result := LoadMapData.new()
	result.unit_placement_data = MapUnitPosition.deserialize(file)
	var map_tiles:Array = []
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
			map_tiles.append(tile)
	file.close()
	result.tile_data = map_tiles
	return result

static func load_map_v1(file:FileAccess) -> LoadMapData:
	var map_tiles:Array = []
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
			map_tiles.append(tile)
	file.close()
	var result := LoadMapData.new()
	result.tile_data = map_tiles
	return result

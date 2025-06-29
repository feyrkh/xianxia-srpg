extends Node3D
class_name TacticalMap

@export var tile_size: float = 1.0

@export var side_overlay_material:BaseMaterial3D

@onready var tiles_node = $Tiles
@onready var walls_node = $Walls

const directions = {
	Vector2(0, -1): Vector3(0, 0, -1), # north
	Vector2(0, 1): Vector3(0, 0, 1),   # south
	Vector2(-1, 0): Vector3(-1, 0, 0), # west
	Vector2(1, 0): Vector3(1, 0, 0)    # east
}

const rotations = {
	Vector3(0, 0, -1): PI,
	Vector3(0, 0, 1): 0,
	Vector3(-1, 0, 0): -PI/2,
	Vector3(1, 0, 0): PI/2,
}

var default_tile_type:TerrainInfo = TerrainInfo.Types[TerrainInfo.TypeNames.Grass]
var wall_nodes:Array = [[]]
var tile_map:Array2D = Array2D.new() # 2d array, each cell is an array of all the MapTile objects in that position (which may be stacked)

var meshes := {}

func get_tiles(x:int, y:int) -> Array[MapTile]:
	return tile_map.g(x, y)

func clear() -> void:
	tile_map = Array2D.new()
	for c in walls_node.get_children():
		c.queue_free()
	for c in tiles_node.get_children():
		c.queue_free()

func save(filename:String) -> void:
	TacticalMapSerializer.save_map(filename, tile_map)

func load(filename: String) -> void:
	clear()
	var tile_info_list:Array =  TacticalMapSerializer.load_map(filename)
	for tile_info in tile_info_list:
		#print("Loading tile %d,%d" % [tile_info.x, tile_info.y])
		create_tile_from_info(tile_info)
	print("Loaded %d x %d map" % [tile_map.width, tile_map.height])
	update_wall_meshes(0, 0, tile_map.width+1, tile_map.height+1)

func render(height_map:Array):
	clear()
	tile_map.height = height_map.size()
	tile_map.width = height_map[0].size()
	for y in range(tile_map.height):
		for x in range(tile_map.width):
			var cell = height_map[y][x]
			if cell is Array:
				for c in cell:
					_render_cell_entry(c, x, y)
			else:
				_render_cell_entry(cell, x, y)
	update_wall_meshes(0, 0, tile_map.width, tile_map.height)
	sort_tiles_by_height(0, 0, tile_map.width, tile_map.height)

func erase_tile(tile:MapTile) -> void:
	var tiles = tile_map.g(tile.x, tile.y)
	if tiles is MapTile and tiles == tile:
		tile_map.s(tile.x, tile.y, null)
	elif tiles is Array:
		tiles.erase(tile)
	tile.delete_wall_meshes()
	tile.queue_free()
	update_wall_meshes(tile.x-1, tile.y-1, tile.x+1, tile.y+1)

## Given a position on the board, a starting height, the size of the gap we want to find, and the direction to look,
## find the next gap that will fit. The gap is returned as a MapTile that the gap sits on top of.
## If null, then the gap is at the floor of the world.
func find_next_tile_gap(x:int, y:int, start_tile:MapTile, gap_size:float, look_up:bool = true) -> MapTile:
	var tiles_to_examine = tile_map.g(x, y)
	if tiles_to_examine == null:
		#print("No tiles found at ", x, ",", y, "!")
		return null
	if tiles_to_examine is not Array:
		tiles_to_examine = [tiles_to_examine]
	var prev_tile:MapTile = start_tile
	var prev_top
	if prev_tile == null:
		prev_top = 0
	else:
		prev_top = prev_tile.tile_info.h
	if look_up:
		for tile:MapTile in tiles_to_examine:
			var info:TileInfo = tile.tile_info
			if info.h < prev_top: continue # We're looking upward, and this is below us
			var gap = info.base - prev_top # how much space there is between the top of the last tile and the bottom of the next
			if gap >= gap_size:
				return prev_tile
			prev_tile = tile
			prev_top = info.h
		return prev_tile
	else:
		prev_top = start_tile.h
		for i in range(tiles_to_examine.size() - 1, -1, -1):
			var tile:MapTile = tiles_to_examine[i]
			var info:TileInfo = tile.tile_info
			if info.h > prev_top: continue # We're looking down, and this is above us
			var gap = info.h - prev_top
			if abs(gap) >= gap_size:
				return tile
			prev_tile = tile
			prev_top = info.base
		if prev_top < gap_size: # we reached the bottom of the stack, and there's not enough room to fit the gap
			return null
		else:
			return MapTile.FLOOR
		

func update_wall_meshes(sx:int=0, sy:int=0, ex:int=tile_map.width-1, ey:int=tile_map.height-1) -> void:
	print("Updating wall meshes from (",sx,",",sy,") to (",ex,",",ey,")")
	for y in range(sy, ey+1):
		for x in range(sx, ex+1):
			var entries = tile_map.g(x, y)
			if entries == null:
				continue
			#print("Wall mesh update: ", x, ", ", y)
			for entry:MapTile in entries:
				entry.delete_wall_meshes()
				_create_walls(entry)

func sort_tiles_by_height(sx:int=0, sy:int=0, ex:int=tile_map.width, ey:int=tile_map.height) -> void:
	for y in range(sy, ey):
		for x in range(sx, ex):
			var entries:Array = tile_map.g(x, y)
			if entries == null:
				return
			entries.sort_custom(MapTile._cmp)

func _render_cell_entry(cell:Variant, x:int, y:int) -> void:
	var tile_info:TileInfo
	if cell is float or cell is int:
		if cell <= 0:
			return
		tile_info = TileInfo.new()
		tile_info.x = x
		tile_info.y = y
		tile_info.h = cell
		tile_info.terrain_type = default_tile_type.id
	elif cell is TileInfo:
		tile_info = cell as TileInfo
		tile_info.x = x
		tile_info.y = y
		if tile_info.h <= 0:
			return
	_create_tile(tile_info)

func create_tile(tile_info:TileInfo):
	_create_tile(tile_info)
	update_wall_meshes(tile_info.x-1, tile_info.y-1, tile_info.x+1, tile_info.y+1)

func create_outline_mesh(original_mesh: Mesh, outline_thickness: float) -> MeshInstance3D:
	var outline_instance := MeshInstance3D.new()
	outline_instance.mesh = original_mesh
	outline_instance.scale = Vector3.ONE * (1.0 + outline_thickness)

	var outline_material := StandardMaterial3D.new()
	outline_material.cull_mode = BaseMaterial3D.CULL_FRONT
	outline_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline_material.albedo_color = Color.BLACK
	outline_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS

	outline_instance.material_override = outline_material
	return outline_instance

func get_cached_mesh(t:TileInfo, material:Material, size:float=0) -> Mesh:	
	var terrain_name := "{0}-{1}".format([t.terrain_type, size])
	var mesh:QuadMesh
	if !meshes.has(terrain_name):
		mesh = QuadMesh.new()
		mesh.material = material
		meshes[terrain_name] = mesh
		if size == 0:
			mesh.size = Vector2(tile_size, tile_size)
		else:
			mesh.size = Vector2(tile_size, size)
	return meshes[terrain_name]

## At the given x/y coordinates, delete any non-empty entries in the column that overlap with the
## given base / height range. This might shorten blocks below, trim the bottom from blocks above,
## cut blocks in two if they encompass the deletion area, or entirely delete entries
func carve_hole_in_tile(x:int, y:int, base:float, h:float) -> bool:
	var blocks_modified := false
	var cur_cell_blocks = tile_map.g(x, y, [])
	for block in cur_cell_blocks.duplicate():
		var maybe_new_block = block.split(base, h)
		if maybe_new_block != null:
			blocks_modified = true
			block.delete_wall_meshes()
			if maybe_new_block is TileInfo:
				maybe_new_block = create_tile_from_info(maybe_new_block as TileInfo)
		if maybe_new_block != null and maybe_new_block != block:
			# a new block was created, add it to the map
			cur_cell_blocks.append(maybe_new_block)
		elif maybe_new_block == block and block.base >= block.h:
			# The new block is size zero, delete it
			cur_cell_blocks.erase(block)
			block.queue_free()
	return blocks_modified

func create_tile_block(tile_info:TileInfo, sx:int, sy:int, ex:int, ey:int) -> void:
	print("Creating ", tile_info, " in block at (", sx, ",", sy, ") - (", ex, ", ", ey, ")")
	for y in range(sy, ey+1):
		for x in range(sx, ex+1):
			var t = tile_info.copy()
			t.x = x
			t.y = y
			_create_tile(t, false)
	update_wall_meshes(sx-1, sy-1, ex+1, ey+1)

func _create_tile(t:TileInfo, update_walls := true) -> MapTile:
	carve_hole_in_tile(t.x, t.y, t.base, t.h)
	if merge_with_stacked_block(t):
		if update_walls:
			update_wall_meshes(t.x-1, t.y-1, t.x+1, t.y+1)
		return null
	else:
		return create_tile_from_info(t)

func merge_with_stacked_block(t:TileInfo) -> bool:
	## Assumes the tile map entries are sorteds
	var tiles = tile_map.g(t.x, t.y, [])
	var first_updated_tile:MapTile = null
	for o in tiles:
		if t.terrain_type == o.terrain_type:
			if t.base == o.h: # new tile is sitting on top of the old
				if !first_updated_tile:
					o.h = t.h
					first_updated_tile = o
				else:
					return true
			if t.h == o.base: # new tile is sitting under the old
				if !first_updated_tile:
					o.base = t.base
					first_updated_tile = o
				else: 
					# We previously merged with a different tile - the new tile sits in the gap between two tiles
					# Now we have to delete one of the tiles and extend the other. We'll delete the bottom tile.
					o.base = first_updated_tile.base
					first_updated_tile.delete(self)
					return true
	return first_updated_tile != null

func create_tile_from_info(t:TileInfo) -> MapTile:
	var instance := _create_tile_mesh(t)
	tile_map.append(t.x, t.y, instance)
	tile_map.g(t.x, t.y).sort_custom(MapTile._cmp)
	return instance

func _create_tile_mesh(t:TileInfo) -> MapTile:
	var mesh:Mesh = get_cached_mesh(t, t.get_top_material())
	var instance = MeshInstance3D.new()
	instance.set_script(preload("res://map/MapTile.gd"))
	instance.tile_info = t
	instance.mesh = mesh
	tiles_node.add_child(instance)
	instance.position = Vector3(t.x * tile_size, t.h, t.y * tile_size)
	instance.rotation_degrees = Vector3(-90, 0, 0)

	# Add outline
	var outline := create_outline_mesh(mesh, 0.02)
	instance.add_child(outline)
	outline.global_position = instance.global_position - Vector3(0, 0.001, 0)
	outline.global_rotation_degrees = -instance.global_rotation_degrees
	return instance

func _find_lowest_tile_gap_start(map_tile_array:Array, gap_size:float) -> float:
	## Assumes that the map_tile_array is sorted
	var last_tile_end := 0.0
	for tile in map_tile_array:
		if tile == null or !is_instance_valid(tile):
			continue
		var gap = tile.base - last_tile_end
		if gap >= gap_size:
			return last_tile_end
		last_tile_end = tile.h
	return last_tile_end

func _create_walls(map_tile:MapTile) -> void:
	var t := map_tile.tile_info
	var new_nodes:Array[Node3D] = []
	for dir2d in directions.keys():
		var nx = t.x + int(dir2d.x)
		var ny = t.y + int(dir2d.y)
		var neighbor_h = t.base
		if nx < 0 or ny < 0 or nx >= tile_map.width or ny >= tile_map.height:
			neighbor_h = t.base  # Edge of map
		else:
			var neighbor_cell = tile_map.g(nx, ny, [])
			neighbor_h = max(t.base, _find_lowest_tile_gap_start(neighbor_cell, 0.01))

		if is_equal_approx(t.h, neighbor_h) or t.h < neighbor_h:
			continue

		var dh = t.h - neighbor_h
		var wall_mesh := _create_wall(
			Vector3(t.x * tile_size, neighbor_h, t.y * tile_size),
			directions[dir2d],
			dh,
			walls_node,
			t
		)
		if wall_mesh:
			new_nodes.append(wall_mesh)
			#print("created wall mesh ", wall_mesh)
	map_tile.add_wall_meshes(new_nodes)

func _get_new_base_from_neighbor(h:float, base:float, neighbor_cell:Variant) -> float:
	if neighbor_cell is float or neighbor_cell is int:	
		if neighbor_cell < h and neighbor_cell > base:
			base = neighbor_cell
	elif neighbor_cell is MapTile:
		if neighbor_cell.h <= h and neighbor_cell.h > base:
			base = neighbor_cell.h
	elif neighbor_cell is Array:
		for c in neighbor_cell:
			base = _get_new_base_from_neighbor(h, base, c)
	return base

func _create_wall(base_pos: Vector3, dir: Vector3, height_diff: float, parent: Node3D, tile_info:TileInfo) -> Node3D:
	if height_diff <= 0:
		return null
	var mesh:Mesh = get_cached_mesh(tile_info, tile_info.get_side_material(), height_diff)

	mesh.material = tile_info.get_side_material()

	var instance := MeshInstance3D.new()
	parent.add_child(instance)
	instance.mesh = mesh
	instance.material_overlay = side_overlay_material
	instance.rotation_degrees = Vector3(0, 0, 0)
	instance.rotate_y(rotations[dir])
	instance.position = base_pos + dir/2.0 + Vector3(0, height_diff / 2.0, 0)
	return instance

extends MeshInstance3D
class_name MapTile

static var FLOOR = MapTile.new()

var tile_info:TileInfo:
	set(v):
		if tile_info:
			tile_info.h_changed.disconnect(on_height_change)
		tile_info = v
		tile_info.h_changed.connect(on_height_change)
		
var collision_body:StaticBody3D
var wall_meshes:Array[Node3D] = []

var x:int:
	get: return tile_info.x
var y:int:
	get: return tile_info.y
var h:float:
	get: return tile_info.h
	set(v):
		tile_info.h = v
		position.y = tile_info.h
var base:float:
	get: return tile_info.base
	set(v):
		tile_info.base = v
var terrain_type:TerrainInfo.TypeNames:
	get: return tile_info.terrain_type
	set(v):
		tile_info.terrain_type = v
	
func _ready() -> void:
	create_convex_collision(false)
	collision_body = get_child(-1)
	collision_body.mouse_entered.connect(on_mouse_entered)
	collision_body.mouse_exited.connect(on_mouse_exited)
	collision_body.input_event.connect(on_input_event)
	collision_body.collision_layer = 0
	collision_body.set_collision_layer_value(MapUtil.PhysicsLayer.Tiles, true)

func on_height_change() -> void:
	position.y = tile_info.h

static func _cmp(a:MapTile, b:MapTile) -> int:
	return a.tile_info.h < b.tile_info.h

## Attempt to split the current tile in two by cutting at the given base and height
## Returns a new block if one is formed
## May result in this block having a zero height
func split(cut_base:float, cut_height:float):
	if cut_base >= h or cut_height <= base: # not overlapping
		return null
	var bb := minf(base, cut_height)
	var bh := minf(h, cut_base)
	var tb := maxf(base, cut_height)
	var th := maxf(h, cut_base)
	var bs := bh - bb
	var ts := th - tb
	if bs <= 0 and ts <= 0: # the whole block is destroyed, set the size to 0
		tile_info.h = tile_info.base
		return self
	elif bs <= 0: # the bottom part of this block is destroyed, modify to match the top block
		tile_info.base = tb
		tile_info.h = th
		return self
	elif ts <= 0: # the top part of this block is destroyed, modify to match the bottom block
		tile_info.base = bb
		tile_info.h = bh
		position.y = tile_info.h
		return self
	else: # the block is cut in two, modify this one to match the bottom and return a new one for the top
		tile_info.base = bb
		tile_info.h = bh
		var new_tile_info := tile_info.copy()
		new_tile_info.base = tb
		new_tile_info.h = th
		return new_tile_info

func delete(map:TacticalMap):
	map.tile_map.g(tile_info.x, tile_info.y, []).erase(self)
	delete_wall_meshes()
	queue_free()

func delete_wall_meshes():
	for m in wall_meshes:
		m.queue_free()
	wall_meshes = []

func add_wall_meshes(meshes:Array[Node3D]):
	wall_meshes.append_array(meshes)

func on_mouse_entered() -> void:
	#seeprint("Mouse entered: ", tile_info)
	material_overlay = preload("res://assets/tiles/hover_material.tres")
	EventBus.tile_hovered.emit(self)

func on_mouse_exited() -> void:
	#print("Mouse exited: ", tile_info)
	material_overlay = null
	EventBus.tile_unhovered.emit(self)

func on_input_event(_camera:Node, event:InputEvent, _event_position:Vector3, _normal:Vector3, _shape_idx:int) -> void:
	if event.is_action_pressed("left_click"):
		EventBus.tile_left_clicked.emit(self)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("right_click"):
		EventBus.tile_right_clicked.emit(self)
		get_viewport().set_input_as_handled()

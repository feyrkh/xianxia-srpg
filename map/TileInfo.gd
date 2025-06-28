extends Resource
class_name TileInfo

signal h_changed()

var x:int
var y:int
var h:float:
	set(v):
		h = v
		h_changed.emit()
var base:float = 0
var terrain_type:TerrainInfo.TypeNames

static func build(_h:float, _base:float, _terrain_type:TerrainInfo.TypeNames, _x:int=0, _y:int=0) -> TileInfo:
	var r := TileInfo.new()
	r.h = _h
	r.base = _base
	r.terrain_type = _terrain_type
	r.x = _x
	r.y = _y
	return r

func copy() -> TileInfo:
	return TileInfo.build(h, base, terrain_type, x, y)

func get_top_material() -> BaseMaterial3D:
	if TerrainInfo.Types.has(terrain_type):
		return TerrainInfo.Types[terrain_type].top_material
	else:
		return TerrainInfo.Types[0].top_material

func get_side_material() -> BaseMaterial3D:
	if TerrainInfo.Types.has(terrain_type):
		return TerrainInfo.Types[terrain_type].side_material
	else:
		return TerrainInfo.Types[0].side_material

extends RefCounted
class_name TerrainInfo

enum TypeNames {
	Grass = 0,
	Desert = 1,
	Rock = 2,
}

static var Types:Dictionary[int, TerrainInfo] = {
	TypeNames.Grass: TerrainInfo.new(TypeNames.Grass, "grass", preload("res://assets/tiles/grass_material.tres"), preload("res://assets/tiles/desert_ground_material.tres")),
	TypeNames.Desert: TerrainInfo.new(TypeNames.Desert, "desert_ground", preload("res://assets/tiles/desert_ground_material.tres"), preload("res://assets/tiles/desert_ground_material.tres")),
	TypeNames.Rock: TerrainInfo.new(TypeNames.Rock, "cliff_rocks", preload("res://assets/tiles/cliff_rocks_material.tres"), preload("res://assets/tiles/cliff_rocks_material.tres")),
}

var id:TypeNames
var terrain_name:String
var top_material:BaseMaterial3D
var side_material:BaseMaterial3D

func _init(_id:TypeNames, _terrain_name:String, top_mat:BaseMaterial3D, side_mat:BaseMaterial3D):
	self.id = _id
	self.terrain_name = _terrain_name
	self.top_material = top_mat
	self.side_material = side_mat

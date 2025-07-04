extends Node3D
class_name MapUnitPosition

const VERSION := 1

enum PositionType {
	None = 0,
	Player = 1,
	Ally = 2,
	EnemyBoss = 3,
	EnemyMelee = 4,
	EnemyArcher = 5,
	EnemyStrong = 6,
	EnemyWeak = 7,
}

var allowed_positions:int
var squad_number:int
var show_label:bool = false
var x:int:
	get(): return int(position.x)
	set(v): position.x = int(v)
var y:int:
	get(): return int(position.z)
	set(v): position.z = int(v)
var height:float:
	get(): return position.y
	set(v): position.y = v

static func serialize(file:FileAccess, map_unit_entries:Array) -> void:
	file.store_8(VERSION)
	file.store_16(map_unit_entries.size())
	for entry in map_unit_entries:
		file.store_16(entry.x)
		file.store_16(entry.y)
		file.store_float(entry.height)
		file.store_16(entry.allowed_positions)
		file.store_8(entry.squad_number)

static func deserialize(file:FileAccess) -> Array[MapUnitPosition]:
	var version = file.get_8()
	if version != VERSION:
		push_error("Invalid version number when deserializing MapUnitPosition list: ", version)
		return []
	var count = file.get_16()
	var result:Array[MapUnitPosition] = []
	for i in range(count):
		var node := preload("res://map/unit/MapUnitPosition.tscn").instantiate()
		node.x = file.get_16()
		node.y = file.get_16()
		node.height = file.get_float()
		node.allowed_positions = file.get_16()
		node.squad_number = file.get_8()
		result.append(node)
	return result

static func get_position_bitmap(positions: Array) -> int:
	var result = 0
	for p in positions:
		if p > 0:
			result |= 1 << (p - 1)
	return result

static func get_matching_positions(position_bitmap:int) -> Array[PositionType]:
	var result:Array[PositionType] = []
	for v in PositionType.values():
		if v > 0 and (1 << (v-1) & position_bitmap):
			result.append(v)
	return result

## If exact_match == true, then returns true if the desired position bitmap exactly equals the allowed positions
## Otherwise, returns true if any of the desired_positions in the bitmap are allowed
func position_matches(desired_positions:int, exact_match:bool) -> bool:
	if exact_match:
		return desired_positions == allowed_positions
	else:
		return desired_positions & allowed_positions

func _ready() -> void:
	if allowed_positions & PositionType.Player:
		$MeshInstance3D.material_override = preload("res://assets/tiles/player_position_marker.tres")
	elif allowed_positions & PositionType.Ally:
		$MeshInstance3D.material_override = preload("res://assets/tiles/ally_position_marker.tres")
	else:
		$MeshInstance3D.material_override = preload("res://assets/tiles/enemy_position_marker.tres")
	if !show_label:
		$Label3D.queue_free()
	else:
		var txt = get_matching_positions(allowed_positions).map(func(i): return PositionType.keys()[i])
		$Label3D.text = ", ".join(txt)
		if squad_number > 0:
			$Label3D.text += "\nSquad " + str(squad_number)
		
	

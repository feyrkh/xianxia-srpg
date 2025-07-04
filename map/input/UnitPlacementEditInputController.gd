extends TileBasedInputController
class_name UnitPlacementEditInputController

signal add_unit_position(node:MapUnitPosition)
signal remove_unit_position(x:int, y:int, height:float)

@onready var squad_number:SpinBox = owner.find_child("UnitPlacementSquadNumber")
@onready var unit_type_list:ItemList = owner.find_child("UnitPlacementTypeList")

func on_input_event_key(_event:InputEventKey) -> void: pass
func on_input_event_mouse_button(_event:InputEventMouseButton) -> void: pass
func on_tile_hovered(_tile:MapTile) -> void: pass
func on_tile_unhovered(_tile:MapTile) -> void: pass
func on_cell_hovered(_x:int, _y:int) -> void: pass
func on_cell_unhovered(_x:int, _y:int) -> void: pass
func on_tile_left_click(tile:MapTile) -> void: 
	var allowed_positions := get_allowed_positions()
	if allowed_positions == 0:
		remove_unit_position.emit(tile.x, tile.y, tile.h)
		return
	print("Placing position with bitmap ", allowed_positions)
	var node := preload("res://map/unit/MapUnitPosition.tscn").instantiate()
	node.allowed_positions = allowed_positions
	node.height = tile.h
	node.x = tile.x
	node.y = tile.y
	node.squad_number = squad_number.value
	node.show_label = true
	add_unit_position.emit(node)
	
func on_tile_right_click(tile:MapTile) -> void: 
	remove_unit_position.emit(tile.x, tile.y, tile.h)

func on_cell_left_click(_x:int, _y:int) -> void: pass
func on_cell_right_click(_x:int, _y:int) -> void: pass

func get_allowed_positions() -> int:
	var selected := unit_type_list.get_selected_items()
	var positions = []
	for entry in selected:
		positions.append(unit_type_list.get_item_metadata(entry))
	return MapUnitPosition.get_position_bitmap(positions)

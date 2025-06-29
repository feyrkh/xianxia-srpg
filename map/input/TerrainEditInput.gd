extends TileBasedInputController
class_name TerrainEditInput

signal selected_terrain_updated(selected_terrain:TerrainInfo)
signal cursor_base_updated(new_base:float)
signal cursor_height_updated(new_height:float)
signal cursor_mode_updated(mode:Mode)
signal cursor_drag_area_updated(start:Vector2i, end:Vector2i, base:float, height:float)

const INCREMENT := 0.25
const MIN_HEIGHT := 0
const MAX_HEIGHT := 100

enum Mode {
	Static = 0,
	StackTop = 1,
}
enum DragMode {
	None,
	CreateTile,
	DeleteTile,
}
var cur_mode := Mode.StackTop:
	set(v):
		if v != cur_mode:
			cur_mode = v
			cursor_mode_updated.emit(cur_mode)

var cursor_position:Vector2i = Vector2i.ZERO:
	set(v):
		if v != cursor_position:
			cursor_position = v
			on_cursor_position_updated.emit(cursor_position)
			if cursor_drag_start:
				update_cursor_drag_area()
var cursor_drag_start:
	set(v):
		if cursor_drag_start != v:
			cursor_drag_start = v
			update_cursor_drag_area()
var cursor_drag_mode:DragMode = DragMode.None:
	set(v):
		if cursor_drag_mode != v:
			cursor_drag_mode = v
			mouse_mode_updated.emit()
		#if v == DragMode.None and cursor_box_label:
		#	cursor_box_label.text = ""
var cursor_base:float = 0:
	set(v):
		if cursor_base != v:
			cursor_base = v
			cursor_base_updated.emit(v)
var cursor_height:float = 1:
	set(v):
		if cursor_height != v:
			cursor_height = v
			cursor_height_updated.emit(v)
var cur_hovered_tile:MapTile
var last_stack_check:Vector2i

var selected_terrain_idx := 1
var selected_terrain:TerrainInfo = TerrainInfo.Types.get(selected_terrain_idx)
var move_cooldown := 0.1

func process_frame(delta:float) -> void:
	if move_cooldown > 0:
		move_cooldown -= delta
		return
	if Input.is_action_pressed("editor_cursor_up"):
		var moved := move_edit_ceiling(0.25)
		move_edit_floor(moved)
	elif Input.is_action_pressed("editor_cursor_down"):
		var moved := move_edit_floor(-0.25)
		move_edit_ceiling(moved)
	elif Input.is_action_pressed("editor_floor_up"):
		move_edit_floor(0.25)
	elif Input.is_action_pressed("editor_floor_down"):
		move_edit_floor(-0.25)
	elif Input.is_action_pressed("editor_ceiling_up"):
		move_edit_ceiling(0.25)
	elif Input.is_action_pressed("editor_ceiling_down"):
		move_edit_ceiling(-0.25)
	elif Input.is_action_pressed("ui_left"):
		update_selected_terrain(-1)
	elif Input.is_action_pressed("ui_right"):
		update_selected_terrain(1)

func on_input_event_key(event:InputEventKey) -> void:
	if cursor_drag_start != null:
		if  event.is_released() and event.keycode == KEY_SHIFT:
			# Cancelled a area drag/release
			cursor_drag_start = null
			cursor_drag_mode = DragMode.None
			get_viewport().set_input_as_handled()

func on_input_event_mouse_button(event:InputEventMouseButton) -> void:
	if cursor_drag_start != null:
		if cursor_drag_mode == DragMode.CreateTile and event.is_action_released("left_click"): 
			# completed area drag/release with left mouse button
			owner.create_tile_block_from_selection(cursor_drag_start, cursor_position, cursor_base, cursor_height, selected_terrain.id)
			last_stack_check = Vector2i(-1, -1)
			cursor_drag_start = null
			cursor_drag_mode = DragMode.None
		elif cursor_drag_mode == DragMode.DeleteTile and event.is_action_released("right_click"):
			# completed area drag/release with right mouse button
			owner.delete_tile_block_from_selection(cursor_drag_start, cursor_position, cursor_base, cursor_height)
			cursor_drag_start = null
			cursor_drag_mode = DragMode.None

func on_tile_hovered(tile:MapTile) -> void:
	cursor_position = Vector2i(tile.x, tile.y)
	cur_hovered_tile = tile
	print("hovered tile ", tile)
	last_stack_check = Vector2i(-1, -1)
	update_cursor_height(tile.tile_info.x, tile.tile_info.y)

func on_tile_unhovered(tile:MapTile) -> void:
	if tile == cur_hovered_tile:
		cur_hovered_tile = null
		print("unhovered tile")

func on_cell_hovered(x:int, y:int) -> void:
	cursor_position = Vector2i(x, y)

	if !cur_hovered_tile:
		update_cursor_height(x, y)

func on_cell_unhovered(_x:int, _y:int) -> void:
	pass

func on_tile_left_click(tile:MapTile) -> void:
	cursor_position = Vector2i(tile.x, tile.y)
	if Input.is_key_pressed(KEY_SHIFT):
		# start dragging a rectangle of tiles
		cursor_drag_start = Vector2i(tile.x, tile.y)
		cursor_drag_mode = DragMode.CreateTile
		print("Tile drag started: ", cursor_drag_start)
	else:
		print("Tile clicked: ", tile.tile_info.x, ", ", tile.tile_info.y)
		owner.create_tile_on_cursor(tile.tile_info.x, tile.tile_info.y, cursor_base, cursor_height, selected_terrain.id)
		last_stack_check = Vector2i(-1, -1)
		update_cursor_height(tile.tile_info.x, tile.tile_info.y)

func on_tile_right_click(tile:MapTile) -> void:
	print("Tile right-clicked: ", tile.tile_info.x, ", ", tile.tile_info.y)
	if Input.is_key_pressed(KEY_SHIFT):
		cursor_drag_start = Vector2i(tile.x, tile.y)
		cursor_drag_mode = DragMode.DeleteTile
		print("Tile drag started: ", cursor_drag_start)
	else:
		tile.h -= 0.25
		if tile.h <= tile.base:
			tile.delete(owner.map)
		else:
			owner.map.update_wall_meshes(tile.x-1, tile.y-1, tile.x+1, tile.y+1)
	last_stack_check = Vector2i(-1, -1)
	update_cursor_height(tile.x, tile.y)

func on_cell_left_click(x:int, y:int) -> void:
	if Input.is_key_pressed(KEY_SHIFT):
		# start dragging a rectangle of tiles
		cursor_drag_start = Vector2i(x, y)
		cursor_drag_mode = DragMode.CreateTile
		print("Tile drag started: ", cursor_drag_start)
	else:
		print("Cell clicked: ", x, ", ", y)
		owner.create_tile_on_cursor(x, y, cursor_base, cursor_height, selected_terrain.id)
		last_stack_check = Vector2i(-1, -1)
		update_cursor_height(x, y)

func on_cell_right_click(x:int, y:int) -> void:
	print("Cell right clicked: ", x, ", ", y)
	if Input.is_key_pressed(KEY_SHIFT):
		cursor_drag_start = Vector2i(x, y)
		cursor_drag_mode = DragMode.DeleteTile
		print("Tile drag started: ", cursor_drag_start)

func update_cursor_height(x:int, y:int) -> void:
	if cur_mode == Mode.Static or cursor_drag_mode != DragMode.None:
		return
	elif cur_mode == Mode.StackTop:
		var cur_stack_check = cursor_position
		if cur_stack_check == last_stack_check:
			return
		last_stack_check = cur_stack_check
		var tile_to_stack_on := cur_hovered_tile
		var size := cursor_height - cursor_base
		if !tile_to_stack_on:
			tile_to_stack_on = owner.map.find_next_tile_gap(x, y, null, size, true)
		else:
			print("Already on a tile h=", tile_to_stack_on.h, ", xy=", tile_to_stack_on.x, ", ", tile_to_stack_on.y)
			tile_to_stack_on = owner.map.find_next_tile_gap(x, y, tile_to_stack_on, size, true)
			print("Next gap is at ", tile_to_stack_on.h)
		if tile_to_stack_on:
			cursor_base = tile_to_stack_on.tile_info.h
			cursor_height = cursor_base + size
		else:
			cursor_base = 0
			cursor_height = cursor_base + size
		move_edit_floor(0)

func update_selected_terrain(i:int) -> void:
	var terrains := TerrainInfo.TypeNames.values()
	terrains.sort()
	selected_terrain_idx += i
	while selected_terrain_idx < 0:
		selected_terrain_idx += terrains.size()
	selected_terrain_idx %= terrains.size()
	selected_terrain = TerrainInfo.Types[terrains[selected_terrain_idx]]
	selected_terrain_updated.emit(selected_terrain)

func move_edit_ceiling(amt:float) -> float:
	move_cooldown = 0.1
	var old_height := cursor_height
	cursor_height = clamp(cursor_height + amt, INCREMENT, MAX_HEIGHT)
	cursor_base = clamp(cursor_base, MIN_HEIGHT, cursor_height - INCREMENT)
	return cursor_height - old_height
	
func move_edit_floor(amt:float) -> float:
	move_cooldown = 0.1
	var old_base := cursor_base
	cursor_base = clamp(cursor_base + amt, MIN_HEIGHT, MAX_HEIGHT - INCREMENT)
	cursor_height = clamp(cursor_height, cursor_base + INCREMENT, MAX_HEIGHT)
	return cursor_base - old_base

func update_selected_mode(i:int) -> void:
	cur_mode = (cur_mode + i) as Mode
	if cur_mode < 0:
		cur_mode = Mode.size() - 1  as Mode
	elif cur_mode >= Mode.size():
		cur_mode = 0 as Mode

func update_cursor_drag_area() -> void:
	if !cursor_drag_start:
		cursor_drag_area_updated.emit(null, null, cursor_base, cursor_height)
		return
	var start = Vector2i(mini(cursor_drag_start.x, cursor_position.x), mini(cursor_drag_start.y, cursor_position.y))
	var end = Vector2i(maxi(cursor_drag_start.x, cursor_position.x), maxi(cursor_drag_start.y, cursor_position.y))
	print("Updating drag area: %s x %s, %.2f - %.2f" % [start, end, cursor_base, cursor_height])
	cursor_drag_area_updated.emit(start, end, cursor_base, cursor_height)

func _on_prev_terrain_pressed() -> void:
	update_selected_terrain(-1)

func _on_next_terrain_pressed() -> void:
	update_selected_terrain(1)

func _on_next_mode_pressed() -> void:
	update_selected_mode(1)

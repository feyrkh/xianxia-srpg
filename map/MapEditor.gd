extends Node3D
class_name MapEditor

const INCREMENT := 0.25
const MIN_HEIGHT := 0
const MAX_HEIGHT := 100
const ZFIGHT_OFFSET := 0.001

enum Mode {
	Static = 0,
	StackTop = 1,
}

@onready var map: TacticalMap = find_child("Map")
@onready var edit_floor: Node3D = find_child("EditFloor")
@onready var edit_ceiling: Node3D = find_child("EditCeiling")
@onready var edit_tracer: Node3D = find_child("EditTracer")
@onready var cursor_details: Label = find_child("CursorDetails")
@onready var terrain_details: Label = find_child("TerrainDetails")
@onready var terrain_texture_preview: TextureRect = find_child("TerrainTexturePreview")
@onready var terrain_texture_preview2: TextureRect = find_child("TerrainTexturePreview2")
@onready var mode_label: Label = find_child("ModeLabel")
@onready var cursor_box: MeshInstance3D = find_child("CursorBox")
@onready var cursor_box_label: Label3D = find_child("CursorBoxLabel")
@onready var save_file_name: LineEdit = find_child("SaveFileName")
@onready var load_file_name: OptionButton = find_child("LoadFileName")

var move_cooldown := 0.1
var selected_terrain_idx := 1
var selected_terrain:TerrainInfo = TerrainInfo.Types.get(selected_terrain_idx)
var cur_mode := Mode.StackTop
var cur_hovered_tile:MapTile
var cur_hovered_cell:Vector2i
var last_stack_check:Vector2i
var lock_clicks = 0

enum DragMode {
	None,
	CreateTile,
	DeleteTile,
}
var cursor_drag_start
var cursor_drag_mode:DragMode = DragMode.None:
	set(v):
		cursor_drag_mode = v
		if v == DragMode.None and cursor_box_label:
			cursor_box_label.text = ""

func _ready() -> void:
	map.render([[1]])
	update_cursor_text()
	update_selected_terrain(0)
	update_selected_mode(0)
	var origin_plane := (find_child("EditOrigin") as MeshInstance3D)
	origin_plane.cell_highlighted.connect(on_cell_highlighted)
	EventBus.tile_left_clicked.connect(on_tile_left_click)
	EventBus.tile_right_clicked.connect(on_tile_right_click)
	EventBus.tile_hovered.connect(on_tile_hovered)
	EventBus.tile_unhovered.connect(on_tile_unhovered)
	origin_plane.cell_left_clicked.connect(on_cell_left_click)
	origin_plane.cell_right_clicked.connect(on_cell_right_click)

func _notification(what: int):
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		lock_clicks = 0
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		print("Window focus returned")
		lock_clicks = Time.get_unix_time_from_system() + 1

func allow_clicks() -> bool:
	if lock_clicks == 0: return true
	if lock_clicks < Time.get_unix_time_from_system():
		lock_clicks = 0
		return true
	else:
		return false
	
func _input(event:InputEvent) -> void:
	if event is InputEventKey:
		if cursor_drag_start != null:
			if  event.is_released() and event.keycode == KEY_SHIFT:
				# Cancelled a area drag/release
				cursor_drag_start = null
				cursor_drag_mode = DragMode.None
	elif event is InputEventMouseButton:
		if cursor_drag_start != null:
			if cursor_drag_mode == DragMode.CreateTile and event.is_action_released("left_click"): 
				# completed area drag/release with left mouse button
				create_tile_block_from_selection()
			elif cursor_drag_mode == DragMode.DeleteTile and event.is_action_released("right_click"):
				# completed area drag/release with right mouse button
				delete_tile_block_from_selection()

func create_tile_block_from_selection() -> void:
	print("Creating tiles")
	var tile_info:TileInfo = TileInfo.build(get_cursor_height(), get_cursor_base(), selected_terrain.id)
	map.create_tile_block(tile_info, min(cursor_drag_start.x, edit_ceiling.position.x), min(cursor_drag_start.y, edit_ceiling.position.z), max(cursor_drag_start.x, edit_ceiling.position.x), max(cursor_drag_start.y, edit_ceiling.position.z))
	cursor_drag_start = null
	cursor_drag_mode = DragMode.None
	last_stack_check = Vector2i(-1, -1)
	#handle_cursor_mode(int(edit_ceiling.position.x), int(edit_ceiling.position.y))


func delete_tile_block_from_selection() -> void:
	print("Deleting tiles")
	var sx:int = mini(cursor_drag_start.x, get_cursor_tile_coords().x)
	var sy:int = mini(cursor_drag_start.y, get_cursor_tile_coords().y)
	var ex:int = maxi(cursor_drag_start.x, get_cursor_tile_coords().x)
	var ey:int = maxi(cursor_drag_start.y, get_cursor_tile_coords().y)
	var base = get_cursor_base()
	var h = get_cursor_height()
	for y in range(sy, ey+1):
		for x in range(sx, ex+1):
			map.carve_hole_in_tile(x, y, base, h)
	map.update_wall_meshes(sx-1, sy-1, ex+1, ey+1)
	cursor_drag_start = null
	cursor_drag_mode = DragMode.None

func on_tile_hovered(tile:MapTile) -> void:
	cur_hovered_tile = tile
	print("hovered tile ", tile)
	last_stack_check = Vector2i(-1, -1)
	handle_cursor_mode(tile.tile_info.x, tile.tile_info.y)

func on_tile_unhovered(tile:MapTile) -> void:
	if tile == cur_hovered_tile:
		cur_hovered_tile = null
		print("unhovered tile")

func on_cell_highlighted(x:int, y:int) -> void:
	edit_floor.position.x = x
	edit_floor.position.z = y
	edit_ceiling.position.x = x
	edit_ceiling.position.z = y
	edit_tracer.position.x = x
	edit_tracer.position.z = y
	cur_hovered_cell = Vector2i(x, y)
	update_cursor_text()
	if !cur_hovered_tile:
		handle_cursor_mode(x, y)

func handle_cursor_mode(x:int, y:int) -> void:
	if cur_mode == Mode.Static or cursor_drag_mode != DragMode.None:
		return
	elif cur_mode == Mode.StackTop:
		var cur_stack_check = get_cursor_tile_coords()
		if cur_stack_check == last_stack_check:
			return
		last_stack_check = cur_stack_check
		var tile_to_stack_on := cur_hovered_tile
		var size := edit_ceiling.position.y - edit_floor.position.y
		if !tile_to_stack_on:
			tile_to_stack_on = map.find_next_tile_gap(x, y, null, size, true)
		else:
			print("Already on a tile h=", tile_to_stack_on.h, ", xy=", tile_to_stack_on.x, ", ", tile_to_stack_on.y)
			tile_to_stack_on = map.find_next_tile_gap(x, y, tile_to_stack_on, size, true)
			print("Next gap is at ", tile_to_stack_on.h)
		if tile_to_stack_on:
			edit_floor.position.y = tile_to_stack_on.tile_info.h + ZFIGHT_OFFSET
			edit_ceiling.position.y = edit_floor.position.y + size
		else:
			edit_floor.position.y = 0 + ZFIGHT_OFFSET
			edit_ceiling.position.y = edit_floor.position.y + size
		move_edit_floor(0)

func create_tile_on_cursor(x:int, y:int):
	var tile_info:TileInfo = TileInfo.build(get_cursor_height(), get_cursor_base(), selected_terrain.id, x, y)
	map.create_tile(tile_info)
	last_stack_check = Vector2i(-1, -1)
	handle_cursor_mode(x, y)

func on_tile_left_click(tile:MapTile) -> void:
	if !allow_clicks():
		return
	if Input.is_key_pressed(KEY_SHIFT):
		# start dragging a rectangle of tiles
		cursor_drag_start = Vector2i(tile.x, tile.y)
		cursor_drag_mode = DragMode.CreateTile
		print("Tile drag started: ", cursor_drag_start)
	else:
		print("Tile clicked: ", tile.tile_info.x, ", ", tile.tile_info.y)
		create_tile_on_cursor(tile.tile_info.x, tile.tile_info.y)

func on_tile_right_click(tile:MapTile) -> void:
	if !allow_clicks():
		return
	print("Tile right-clicked: ", tile.tile_info.x, ", ", tile.tile_info.y)
	if Input.is_key_pressed(KEY_SHIFT):
		cursor_drag_start = Vector2i(tile.x, tile.y)
		cursor_drag_mode = DragMode.DeleteTile
		print("Tile drag started: ", cursor_drag_start)
	else:
		tile.h -= 0.25
		if tile.h <= tile.base:
			tile.delete(map)
		else:
			map.update_wall_meshes(tile.x-1, tile.y-1, tile.x+1, tile.y+1)
	last_stack_check = Vector2i(-1, -1)
	handle_cursor_mode(tile.x, tile.y)

func on_cell_left_click(x:int, y:int) -> void:
	if !allow_clicks():
		return
	if Input.is_key_pressed(KEY_SHIFT):
		# start dragging a rectangle of tiles
		cursor_drag_start = Vector2i(x, y)
		cursor_drag_mode = DragMode.CreateTile
		print("Tile drag started: ", cursor_drag_start)
	else:
		print("Cell clicked: ", x, ", ", y)
		create_tile_on_cursor(x, y)
		last_stack_check = Vector2i(-1, -1)
		handle_cursor_mode(x, y)

func on_cell_right_click(x:int, y:int) -> void:
	print("Cell right clicked: ", x, ", ", y)
	if Input.is_key_pressed(KEY_SHIFT):
		cursor_drag_start = Vector2i(x, y)
		cursor_drag_mode = DragMode.DeleteTile
		print("Tile drag started: ", cursor_drag_start)

func _process(delta:float) -> void:
	update_cursor_movement(delta)

func update_cursor_movement(delta:float) -> void:
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

func update_selected_terrain(i:int) -> void:
	var terrains := TerrainInfo.TypeNames.values()
	terrains.sort()
	selected_terrain_idx += i
	while selected_terrain_idx < 0:
		selected_terrain_idx += terrains.size()
	selected_terrain_idx %= terrains.size()
	selected_terrain = TerrainInfo.Types[terrains[selected_terrain_idx]]
	terrain_details.text = "%2d - %s" % [selected_terrain.id, selected_terrain.terrain_name]
	terrain_texture_preview.texture = selected_terrain.top_material.albedo_texture
	terrain_texture_preview2.texture = selected_terrain.side_material.albedo_texture

func update_selected_mode(i:int) -> void:
	cur_mode = (cur_mode + i) as Mode
	if cur_mode < 0:
		cur_mode = Mode.size() - 1  as Mode
	elif cur_mode >= Mode.size():
		cur_mode = 0 as Mode
	mode_label.text = "(%d) %s" % [cur_mode, Mode.find_key(cur_mode)]

func get_cursor_height() -> float:
	return snapped(edit_ceiling.position.y, INCREMENT)
	
func get_cursor_base() -> float:
	return snapped(edit_floor.position.y, INCREMENT)

func get_cursor_tile_coords() -> Vector2i:
	return Vector2i(int(edit_floor.position.x), int(edit_floor.position.z))

func move_edit_ceiling(amt:float) -> float:
	move_cooldown = 0.1
	var old_pos := edit_ceiling.position.y
	edit_ceiling.position.y = clamp(edit_ceiling.position.y + amt, INCREMENT + ZFIGHT_OFFSET, MAX_HEIGHT + ZFIGHT_OFFSET)
	edit_floor.position.y = clamp(edit_floor.position.y, MIN_HEIGHT + ZFIGHT_OFFSET, edit_ceiling.position.y - INCREMENT + ZFIGHT_OFFSET)
	update_cursor_text()
	return edit_ceiling.position.y - old_pos
	
func move_edit_floor(amt:float) -> float:
	move_cooldown = 0.1
	var old_pos := edit_floor.position.y
	edit_floor.position.y = clamp(edit_floor.position.y + amt, MIN_HEIGHT + ZFIGHT_OFFSET, MAX_HEIGHT - INCREMENT + ZFIGHT_OFFSET)
	edit_ceiling.position.y = clamp(edit_ceiling.position.y, edit_floor.position.y + INCREMENT, MAX_HEIGHT + ZFIGHT_OFFSET)
	update_cursor_text()
	return edit_floor.position.y - old_pos

func update_cursor_text():
	var cursor_height := edit_ceiling.position.y - edit_floor.position.y
	edit_ceiling.set_text("c: %.2f, s: %.2f\n(%d,%d)" % [edit_ceiling.position.y, cursor_height, edit_floor.position.x, edit_floor.position.z])
	edit_floor.set_text("f: %.2f, xy: %d,%d" % [edit_floor.position.y, edit_floor.position.x, edit_floor.position.z])
	cursor_details.set_text("pos: (%d, %d)\nheight: %.2f\nbase: %.2f\nsize: %.2f" % [
		edit_floor.position.x, edit_floor.position.z,
		edit_ceiling.position.y, edit_floor.position.y,
		cursor_height,
	])
	if cursor_drag_start == null:
		cursor_box.mesh.size = Vector3(1, cursor_height, 1)
		cursor_box.position = (edit_ceiling.position + edit_floor.position) / 2.0 
	else:
		var box_width:int = abs(cursor_drag_start.x - edit_ceiling.position.x) + 1
		var box_length:int = abs(cursor_drag_start.y - edit_ceiling.position.z) + 1
		cursor_box.mesh.size = Vector3(box_width, cursor_height, box_length)
		cursor_box.position = Vector3((edit_ceiling.position.x - cursor_drag_start.x)/2.0 + cursor_drag_start.x, (edit_ceiling.position.y + edit_floor.position.y) / 2.0, (edit_ceiling.position.z - cursor_drag_start.y)/2.0 + cursor_drag_start.y)
		cursor_box_label.text = "%d x %d x %.2f" % [box_width, box_length, cursor_height]
		

func _on_prev_terrain_pressed() -> void:
	update_selected_terrain(-1)

func _on_next_terrain_pressed() -> void:
	update_selected_terrain(1)

func _on_next_mode_pressed() -> void:
	update_selected_mode(1)

func _on_load_file_name_focus_entered() -> void:
	var dir := DirAccess.open("user://maps")
	if dir == null:
		push_warning("Save directory doesn't exist.")
		return

	var map_files := []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".map"):
			map_files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	map_files.sort()  # Optional: sort alphabetically

	# Clear and repopulate the OptionButton
	load_file_name.clear()
	for f in map_files:
		f = f.trim_suffix(".map")
		load_file_name.add_item(f)
		load_file_name.set_item_metadata(-1, "user://maps/"+f+".map")

func _on_load_pressed() -> void:
	var filename = load_file_name.get_selected_metadata()
	if !filename:
		return
	map.load(filename)
	save_file_name.text = load_file_name.get_item_text(load_file_name.selected)

func _on_save_pressed() -> void:
	var filename := save_file_name.text
	if !filename:
		filename = 'tmp'
	filename.replace_chars(':/,.\\', ' '.unicode_at(0))
	filename = filename.trim_suffix(".map")
	map.save(filename)


func _on_generate_button_pressed() -> void:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.fractal_octaves = int(find_child("GenOctaves").value)
	noise.frequency = float(find_child("GenFrequency").text)
	noise.fractal_lacunarity = float(find_child("GenLacuna").text)
	noise.seed = find_child("GenSeed").text.hash()
	var height_map := MapGenerator.generate_height_map(int(find_child("GenWidth").text), int(find_child("GenHeight").text), noise)
	map.render(height_map)
	

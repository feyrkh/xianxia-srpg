extends Node3D
class_name MapEditor


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

@onready var terrain_edit_input: TerrainEditInput = find_child("TerrainEditInput")

var all_input_controllers:Array[TileBasedInputController]
var cur_input_controller:TileBasedInputController:
	set(v):
		if cur_input_controller != v:
			if cur_input_controller != null:
				cur_input_controller.on_leave_mode()
			cur_input_controller = v
			cur_input_controller.on_enter_mode()

var lock_clicks = 0

func _ready() -> void:
	all_input_controllers = [terrain_edit_input]
	cur_input_controller = terrain_edit_input
	terrain_edit_input.on_cursor_position_updated.connect(on_terrain_edit_cursor_position_updated)
	terrain_edit_input.selected_terrain_updated.connect(on_selected_terrain_updated)
	terrain_edit_input.cursor_base_updated.connect(on_cursor_base_updated)
	terrain_edit_input.cursor_height_updated.connect(on_cursor_height_updated)
	terrain_edit_input.cursor_mode_updated.connect(on_terrain_edit_cursor_mode_updated)
	terrain_edit_input.cursor_drag_area_updated.connect(on_cursor_drag_area_updated)
	map.render([[1]])
	update_cursor_text()
	on_selected_terrain_updated(terrain_edit_input.selected_terrain)
	on_terrain_edit_cursor_mode_updated(TerrainEditInput.Mode.StackTop)
	var origin_plane := (find_child("EditOrigin") as MeshInstance3D)
	origin_plane.cell_highlighted.connect(on_cell_hovered)
	EventBus.tile_left_clicked.connect(on_tile_left_click)
	EventBus.tile_right_clicked.connect(on_tile_right_click)
	EventBus.tile_hovered.connect(on_tile_hovered)
	EventBus.tile_unhovered.connect(on_tile_unhovered)
	origin_plane.cell_left_clicked.connect(on_cell_left_click)
	origin_plane.cell_right_clicked.connect(on_cell_right_click)

func on_terrain_edit_cursor_position_updated(pos:Vector2i) -> void:
	edit_floor.position.x = pos.x
	edit_floor.position.z = pos.y
	edit_ceiling.position.x = pos.x
	edit_ceiling.position.z = pos.y
	edit_tracer.position.x = pos.x
	edit_tracer.position.z = pos.y
	update_cursor_text()

func on_terrain_edit_cursor_mode_updated(mode:TerrainEditInput.Mode) -> void:
	mode_label.text = "(%d) %s" % [mode, TerrainEditInput.Mode.find_key(mode)]

func on_cursor_base_updated(new_base:float) -> void:
	edit_floor.position.y = new_base
	update_cursor_text()

func on_cursor_height_updated(new_height:float) -> void:
	edit_ceiling.position.y = new_height
	update_cursor_text()

func on_selected_terrain_updated(selected_terrain:TerrainInfo) -> void:
	terrain_details.text = "%2d - %s" % [selected_terrain.id, selected_terrain.terrain_name]
	terrain_texture_preview.texture = selected_terrain.top_material.albedo_texture
	terrain_texture_preview2.texture = selected_terrain.side_material.albedo_texture

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
		cur_input_controller.on_input_event_key(event)
	elif event is InputEventMouseButton:
		cur_input_controller.on_input_event_mouse_button(event)

func create_tile_block_from_selection(drag_start:Vector2i, drag_end:Vector2i, cursor_base:float, cursor_height:float, terrain_id:TerrainInfo.TypeNames) -> void:
	print("Creating tiles")
	var tile_info:TileInfo = TileInfo.build(cursor_height, cursor_base, terrain_id)
	map.create_tile_block(tile_info, min(drag_start.x, drag_end.x), min(drag_start.y, drag_end.y), max(drag_start.x, drag_end.x), max(drag_start.y, drag_end.y))

func delete_tile_block_from_selection(drag_start:Vector2i, drag_end:Vector2i, cursor_base:float, cursor_height:float) -> void:
	print("Deleting tiles")
	var sx:int = mini(drag_start.x, drag_end.x)
	var sy:int = mini(drag_start.y, drag_end.y)
	var ex:int = maxi(drag_start.x, drag_end.x)
	var ey:int = maxi(drag_start.y, drag_end.y)
	var base = cursor_base
	var h = cursor_height
	for y in range(sy, ey+1):
		for x in range(sx, ex+1):
			map.carve_hole_in_tile(x, y, base, h)
	map.update_wall_meshes(sx-1, sy-1, ex+1, ey+1)

func create_tile_on_cursor(x:int, y:int, cursor_base:float, cursor_height:float, terrain_id:TerrainInfo.TypeNames):
	var tile_info:TileInfo = TileInfo.build(cursor_height, cursor_base, terrain_id, x, y)
	map.create_tile(tile_info)

func _process(delta:float) -> void:
	cur_input_controller.process_frame(delta)


func get_cursor_tile_coords() -> Vector2i:
	return Vector2i(int(edit_floor.position.x), int(edit_floor.position.z))

func update_cursor_text():
	var cursor_height := edit_ceiling.position.y - edit_floor.position.y
	edit_ceiling.set_text("c: %.2f, s: %.2f\n(%d,%d)" % [edit_ceiling.position.y, cursor_height, edit_floor.position.x, edit_floor.position.z])
	edit_floor.set_text("f: %.2f, xy: %d,%d" % [edit_floor.position.y, edit_floor.position.x, edit_floor.position.z])
	cursor_details.set_text("pos: (%d, %d)\nheight: %.2f\nbase: %.2f\nsize: %.2f" % [
		edit_floor.position.x, edit_floor.position.z,
		edit_ceiling.position.y, edit_floor.position.y,
		cursor_height,
	])

func on_cursor_drag_area_updated(start, end, cursor_base:float, cursor_height:float) -> void:
	if start == null:
		cursor_box.visible = false
		#cursor_box.mesh.size = Vector3(1, cursor_height, 1)
		#cursor_box.position = (edit_ceiling.position + edit_floor.position) / 2.0 
	else:
		var box_width:int = abs(end.x - start.x) + 1
		var box_length:int = abs(end.y - start.y) + 1
		cursor_box.mesh.size = Vector3(box_width, cursor_height, box_length)
		cursor_box.position = Vector3(box_width/2.0 + start.x - 0.5, (cursor_height + cursor_base) / 2.0, box_length/2.0 + start.y - 0.5)
		cursor_box_label.text = "%d x %d x %.2f" % [box_width, box_length, cursor_height]
		cursor_box.visible = true
		
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
	

func on_cell_hovered(x:int, y:int) -> void:
	cur_input_controller.on_cell_hovered(x, y)

func on_cell_left_click(x:int, y:int) -> void:
	if !allow_clicks():
		return
	cur_input_controller.on_cell_left_click(x, y)
	
func on_cell_right_click(x:int, y:int) -> void:
	if !allow_clicks():
		return
	cur_input_controller.on_cell_right_click(x, y)

func on_tile_left_click(t:MapTile) -> void:
	if !allow_clicks():
		return
	cur_input_controller.on_tile_left_click(t)

func on_tile_right_click(t:MapTile) -> void:
	if !allow_clicks():
		return
	cur_input_controller.on_tile_right_click(t)

func on_tile_hovered(t:MapTile) -> void:
	cur_input_controller.on_tile_hovered(t)

func on_tile_unhovered(t:MapTile) -> void:
	cur_input_controller.on_tile_unhovered(t)

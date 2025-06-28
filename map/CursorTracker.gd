extends MeshInstance3D

signal cell_highlighted(x:int, y:int)
signal cell_left_clicked(x:int, y:int)
signal cell_right_clicked(x:int, y:int)

func _ready() -> void:
	create_convex_collision()
	var body:StaticBody3D = get_child(-1)
	body.input_event.connect(on_input_event)

func _input(event:InputEvent) -> void:
	if event is InputEventMouse or event is InputEventKey:
		var raycast_result := Utils.raycast_to_mouse(self, MapUtil.get_layer_mask(MapUtil.PhysicsLayer.Tiles))
		if raycast_result.has("collider"):
			var pos := raycast_result.position as Vector3
			cell_highlighted.emit(int(pos.x+0.5), int(pos.z+0.5))

func on_input_event(_camera:Node, event:InputEvent, _event_position:Vector3, _normal:Vector3, _shape_idx:int) -> void:
	if event.is_action_pressed("left_click"):
		cell_left_clicked.emit(int(_event_position.x+0.5), int(_event_position.z+0.5))
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("right_click"):
		cell_right_clicked.emit(int(_event_position.x+0.5), int(_event_position.z+0.5))
		get_viewport().set_input_as_handled()

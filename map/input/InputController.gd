abstract class_name InputController extends Node

signal mouse_mode_updated()

func on_leave_mode() -> void:
	pass
	
func on_enter_mode() -> void:
	pass

abstract func on_input_event_key(event:InputEventKey) -> void
abstract func on_input_event_mouse_button(event:InputEventMouseButton) -> void

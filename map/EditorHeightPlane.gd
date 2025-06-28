extends Node3D

func set_text(s:String) -> void:
	find_child("Label3D").text = s

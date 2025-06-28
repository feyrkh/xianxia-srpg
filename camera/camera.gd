extends Node3D

@export var rotation_pivot_path: NodePath
@export var tilt_pivot_path: NodePath
@export var camera_path: NodePath

@export var move_speed := 20.0
@export var rotate_speed := 1.5  # radians per second
@export var zoom_speed := 5.0
@export var min_zoom := 5.0
@export var max_zoom := 50.0

var rotation_pivot: Node3D
var tilt_pivot: Node3D
var camera: Camera3D

func _ready():
	rotation_pivot = get_node(rotation_pivot_path)
	tilt_pivot = get_node(tilt_pivot_path)
	camera = get_node(camera_path)

	tilt_pivot.rotation_degrees.x = -65 
	camera.position = Vector3(0, 0, 20) 

func _physics_process(delta):
	_handle_pan(delta)
	_handle_rotation(delta)
	_handle_zoom()

func _handle_pan(delta):
	var input := Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		input.z -= 1
	if Input.is_action_pressed("move_back"):
		input.z += 1
	if Input.is_action_pressed("move_left"):
		input.x -= 1
	if Input.is_action_pressed("move_right"):
		input.x += 1

	if input != Vector3.ZERO:
		input = input.normalized() * move_speed * delta
		# Move in local XZ plane relative to current rotation
		var movement := (rotation_pivot.transform.basis.x * input.x + rotation_pivot.transform.basis.z * input.z)
		translate(movement)

func _handle_rotation(delta):
	var dir := 0
	if Input.is_action_pressed("rotate_left"):
		dir += 1
	if Input.is_action_pressed("rotate_right"):
		dir -= 1
	if dir != 0:
		rotation_pivot.rotate_y(rotate_speed * dir * delta)
		
func orthogonal_zoom_camera(direction: int):
	var new_size = clamp(camera.size * (1.0 + direction * 0.1), 1.0, 50.0)
	camera.size = new_size

func perspective_zoom_camera(direction: int):
	var new_fov = clamp(camera.fov * (1.0 + direction * 0.1), 10.0, 90.0)
	camera.fov = new_fov

func _handle_zoom():
	var scroll := 0
	if Input.is_action_just_pressed("zoom_in"):
		scroll -= 1
	if Input.is_action_just_pressed("zoom_out"):
		scroll += 1
	if scroll != 0:
		perspective_zoom_camera(scroll)

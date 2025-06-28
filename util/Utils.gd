extends Node
class_name Utils

# The returned object is a dictionary with the following fields:
# collider: The colliding object.
# collider_id: The colliding object's ID.
# normal: The object's surface normal at the intersection point, or Vector3(0, 0, 0) if the ray starts inside the shape and PhysicsRayQueryParameters3D.hit_from_inside is true.
# position: The intersection point.
# face_index: The face index at the intersection point.
# 	Note: Returns a valid number only if the intersected shape is a ConcavePolygonShape3D. Otherwise, -1 is returned.
# rid: The intersecting object's RID.
# shape: The shape index of the colliding shape.
# If the ray did not intersect anything, then an empty dictionary is returned instead.
static func raycast_to_mouse(node:Node3D, collision_layers:int) -> Dictionary:
	var camera := node.get_viewport().get_camera_3d()
	var mouse_pos := node.get_viewport().get_mouse_position()
	var params := PhysicsRayQueryParameters3D.new()
	params.from = camera.project_ray_origin(mouse_pos)
	params.to = params.from + camera.project_ray_normal(mouse_pos) * 1000
	params.collision_mask = collision_layers
	var space_state := node.get_world_3d().direct_space_state
	return space_state.intersect_ray(params)

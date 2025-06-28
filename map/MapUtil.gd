extends Object
class_name MapUtil

enum PhysicsLayer {
	Tiles = 1,
	Units = 2,
}

static func get_layer_mask(...layers) -> int:
	var mask = 0
	for layer in layers:
		mask = mask | (1 << (layer - 1))
	return mask

extends Node
class_name MapGenerator

static func generate_height_map(width: int, height: int, noise: FastNoiseLite) -> Array:
	var min_height := 9999999
	var map := []
	for y in range(height):
		var row := []
		for x in range(width):
			var n = noise.get_noise_2d(x, y)
			n = (n + 1.0) / 2.0  # Normalize to 0.0 - 1.0
			var h = round(n * 20.0) / 2.0
			if h < min_height:
				min_height = h
			row.append(h)
		map.append(row)
	for y in range(height):
		for x in range(width):
			map[y][x] = map[y][x] - min_height + 1
	return map

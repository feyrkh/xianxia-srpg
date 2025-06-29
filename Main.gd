extends Node3D
@export var noise_frequency: float = 0.2
@export var noise_octaves: int = 3
@export var noise_lacunarity: float = 0.89

func _ready() -> void:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	
	noise.fractal_octaves = noise_octaves
	noise.frequency = noise_frequency
	noise.fractal_lacunarity = noise_lacunarity

	#var height_map := MapGenerator.generate_height_map(20, 20, noise)
	#$Map.render(height_map)
	var map:TacticalMap = $Map
	map.load("user://maps/gentle_hills_40x40_castle.map")
	var middle_tiles := map.get_tiles(20, 20)
	var bottom_tile := middle_tiles[0]
	

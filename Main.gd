extends Node3D
@export var noise_frequency: float = 0.2
@export var noise_octaves: int = 3
@export var noise_lacunarity: float = 0.89

func _ready() -> void:
	var height_map:Array = []
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	
	noise.fractal_octaves = noise_octaves
	noise.frequency = noise_frequency
	noise.fractal_lacunarity = noise_lacunarity

	height_map = MapGenerator.generate_height_map(20, 20, noise)
	$Map.render(height_map)

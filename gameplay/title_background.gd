extends Node3D

const NEON_CYAN := Color("72a6a0")
const DISPLAY_LAYER := 2
const COVERS := [Vector3(-10, 0, -8), Vector3(9, 0, -3), Vector3(-5, 0, 10), Vector3(10, 0, 12), Vector3(-14, 0, 6), Vector3(14, 0, 6)]

func _ready() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -35, 0)
	light.light_color = Color("b9d9f4")
	light.light_energy = 1.35
	light.light_cull_mask = DISPLAY_LAYER
	add_child(light)
	add_floor()
	for x in range(-24, 25, 6):
		for z in range(-24, 25, 6):
			if abs(x) == 24 or abs(z) == 24:
				add_block(Vector3(x, 2.2, z), Vector3(5.8, 4.5, 0.35), Color("4a555d"))
			else:
				add_neon_tile(Vector3(x, 0.01, z))
	for index in COVERS.size():
		var is_low := index >= 4
		add_block(COVERS[index] + Vector3(0, 0.6 if is_low else 2.0, 0), Vector3(4.8, 1.2, 4.8) if is_low else Vector3(3.0, 4.0, 3.0), Color("65716f") if is_low else Color("59646a"))

func add_floor() -> void:
	var floor := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(60, 0.5, 60)
	floor.mesh = mesh
	floor.position = Vector3(0, -0.3, 0)
	floor.layers = DISPLAY_LAYER
	floor.material_override = material(Color("34404a"))
	add_child(floor)

func add_block(position_value: Vector3, size: Vector3, color: Color) -> void:
	var block := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	block.mesh = mesh
	block.position = position_value
	block.layers = DISPLAY_LAYER
	block.material_override = material(color)
	add_child(block)

func add_neon_tile(position_value: Vector3) -> void:
	var tile := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.07, 0.03, 5.0)
	tile.mesh = mesh
	tile.position = position_value + Vector3(0, 0.01, 0)
	tile.layers = DISPLAY_LAYER
	tile.material_override = material(NEON_CYAN, 3.0)
	add_child(tile)

func material(color: Color, emission_strength := 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = 0.05
	result.roughness = 0.9
	result.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	if emission_strength > 0.0:
		result.emission_enabled = true
		result.emission = color.darkened(0.35)
		result.emission_energy_multiplier = minf(emission_strength * 0.12, 0.55)
	return result

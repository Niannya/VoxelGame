extends Node3D
signal absorbed(mineral_key: String, amount: int)
const Catalog = preload("res://scripts/items/mineral_catalog.gd")
var processed: Dictionary = {}
var total_absorbed: int = 0
var _light: OmniLight3D
var _pulse: Tween


func _ready() -> void:
	add_to_group("mineral_furnace")
	_light = OmniLight3D.new()
	_light.light_color = Color("ffb057")
	_light.light_energy = 0.45
	_light.omni_range = 3.0
	add_child(_light)
	var ember := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.11
	sphere.height = 0.22
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("ffc268")
	material.emission_enabled = true
	material.emission = material.albedo_color
	material.emission_energy_multiplier = 2.0
	sphere.material = material
	ember.mesh = sphere
	add_child(ember)


func accepts(key: String) -> bool:
	return Catalog.is_common(key)


func intake_position() -> Vector3:
	return global_position


func receive(key: String, amount: int) -> bool:
	if not accepts(key) or amount <= 0:
		return false
	processed[key] = int(processed.get(key, 0)) + amount
	total_absorbed += amount
	absorbed.emit(key, amount)
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	_light.light_energy = 2.5
	_pulse = create_tween()
	_pulse.tween_property(_light, "light_energy", 0.45, 0.35)
	return true

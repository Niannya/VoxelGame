extends Node3D
## Common stone goes to the furnace; rare ore is reserved atomically by the bag.
const Catalog = preload("res://scripts/items/mineral_catalog.gd")
signal collected(mineral_key: String, amount: int, collector: Node)
signal landed
var mineral_key: String = "stone_a"
var amount: int = 1
var world: Node3D
var landing_platform: Node3D
var furnace: Node3D
var launch_direction := Vector3.BACK
var velocity := Vector3.ZERO
var is_landed := false
var _taken := false
var _visual: Node3D
var _spin := Vector3.ZERO
var _age := 0.0
var _bounces := 0
var transfer_kind: String = ""
var _destination: Node3D
var _flight_start := Vector3.ZERO
var _flight_time := 0.0
var _flight_duration := 0.5
var _completed := false
var _spawn_tween: Tween
const RADIUS := 0.18


func _ready() -> void:
	add_to_group("mineral_drop")
	_visual = Node3D.new()
	add_child(_visual)
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.34
	var material := StandardMaterial3D.new()
	var colors := {"gold": Color("e8b542"), "quartz": Color("e3e0e8"), "diamond": Color("57d4ea"), "emerald": Color("49c389")}
	material.albedo_color = colors.get(mineral_key, Color("8c8798"))
	material.emission_enabled = true
	material.emission = material.albedo_color
	material.emission_energy_multiplier = 0.55
	mesh.material = material
	for i in 3:
		var piece := MeshInstance3D.new()
		piece.mesh = mesh
		if i > 0:
			piece.scale = Vector3.ONE * 0.55
			piece.position = Vector3(-0.13 if i == 1 else 0.12, 0.06, -0.08 if i == 1 else 0.07)
		_visual.add_child(piece)
	_visual.rotation_degrees = Vector3(20, 35, 20)
	var direction := launch_direction
	direction.y = 0.0
	if direction.length_squared() < 0.01:
		direction = Vector3.BACK
	direction = direction.normalized()
	var side := direction.cross(Vector3.UP)
	velocity = direction * randf_range(2.0, 3.0) + side * randf_range(-0.7, 0.7) + Vector3.UP * randf_range(3.8, 5.2)
	_spin = Vector3(randf_range(-5.0, 5.0), randf_range(3.0, 7.0), randf_range(-5.0, 5.0))
	_visual.scale = Vector3.ONE * 0.25
	_spawn_tween = create_tween()
	_spawn_tween.tween_property(_visual, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_spawn_debris(material.albedo_color)


func _physics_process(delta: float) -> void:
	_age += delta
	if not transfer_kind.is_empty():
		_update_transfer(delta)
		return
	if not _taken and _age >= 0.12 and Catalog.is_common(mineral_key) and is_instance_valid(furnace):
		if absorb_into(furnace):
			return
	if is_landed:
		_visual.rotation.y += delta * 0.7
		_visual.position.y = sin(_age * 2.5) * 0.025
		return
	velocity.y -= 18.0 * delta
	var previous := global_position
	var next := previous + velocity * delta
	_visual.rotation += _spin * delta
	# Test the moving platform before the lower grid floor.
	if is_instance_valid(landing_platform) and velocity.y < 0.0:
		var top: float = landing_platform.global_position.y + RADIUS
		if previous.y >= top and next.y <= top:
			var fraction: float = (previous.y - top) / maxf(previous.y - next.y, 0.0001)
			var crossing := previous.lerp(next, fraction)
			var local := landing_platform.to_local(crossing)
			if absf(local.x) <= landing_platform.deck_half_width - RADIUS and absf(local.z) <= landing_platform.deck_half_depth - RADIUS:
				global_position = Vector3(crossing.x, top, crossing.z)
				_touch_floor(landing_platform)
				return
	if is_instance_valid(world):
		var from := world.to_local(previous)
		var to := world.to_local(next)
		var movement := to - from
		var hit: Dictionary = world.raycast_block(from, movement, movement.length())
		if hit.get("hit", false):
			var normal := Vector3(hit.normal)
			if normal.length_squared() > 0.5:
				global_position = world.to_global(hit.point + normal * RADIUS)
				if normal.y > 0.7:
					_touch_floor(null)
				else:
					velocity = velocity.bounce(normal) * 0.42
				return
	global_position = next
	# An outer boundary safeguard retains the collectible rather than deleting it.
	if global_position.y < -3.0:
		global_position.y = -0.32
		_settle(null)


func _touch_floor(support: Node3D) -> void:
	_bounces += 1
	if _bounces == 1 and absf(velocity.y) > 1.5:
		velocity = Vector3(velocity.x * 0.35, absf(velocity.y) * 0.25, velocity.z * 0.35)
	else:
		_settle(support)


func _settle(support: Node3D) -> void:
	is_landed = true
	velocity = Vector3.ZERO
	_visual.rotation.x = 0.0
	_visual.rotation.z = 0.0
	if is_instance_valid(support) and get_parent() != support:
		reparent(support, true)
	landed.emit()


func _spawn_debris(color: Color) -> void:
	var particles := CPUParticles3D.new()
	particles.one_shot = true
	particles.local_coords = false
	particles.amount = 8
	particles.lifetime = 0.5
	particles.explosiveness = 1.0
	particles.direction = launch_direction.normalized() + Vector3.UP
	particles.spread = 60.0
	particles.initial_velocity_min = 1.0
	particles.initial_velocity_max = 3.0
	particles.gravity = Vector3(0, -14, 0)
	particles.scale_amount_min = 0.06
	particles.scale_amount_max = 0.12
	var mesh := BoxMesh.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material = material
	particles.mesh = mesh
	add_child(particles)
	particles.emitting = true
	get_tree().create_timer(0.7).timeout.connect(particles.queue_free)


func collect(collector: Node) -> bool:
	if collector is not Node3D or not can_pick_up(collector):
		return false
	var inventory := collector.get_node_or_null("Inventory")
	if inventory == null or not inventory.try_add(mineral_key, amount):
		return false
	_start_transfer(collector, "backpack", 0.32)
	collected.emit(mineral_key, amount, collector)
	return true


func can_pick_up(collector: Node3D) -> bool:
	if _taken or not is_instance_valid(collector) or not Catalog.is_rare(mineral_key):
		return false
	if collector.get("is_down") == true:
		return false
	return global_position.distance_to(collector.global_position + Vector3.UP * 0.7) <= 2.0


func absorb_into(target: Node3D) -> bool:
	if _taken or not Catalog.is_common(mineral_key) or not is_instance_valid(target) or not target.accepts(mineral_key):
		return false
	var duration := clampf(global_position.distance_to(target.intake_position()) / 9.0, 0.35, 1.2)
	_start_transfer(target, "furnace", duration)
	return true


func _start_transfer(target: Node3D, kind: String, duration: float) -> void:
	if _spawn_tween != null and _spawn_tween.is_valid():
		_spawn_tween.kill()
	_taken = true
	transfer_kind = kind
	_destination = target
	_flight_start = global_position
	_flight_time = 0.0
	_flight_duration = duration
	velocity = Vector3.ZERO
	_visual.position = Vector3.ZERO


func _update_transfer(delta: float) -> void:
	if _completed:
		return
	if not is_instance_valid(_destination):
		if transfer_kind == "backpack":
			# Inventory committed before animation; the visual can safely disappear.
			queue_free()
		else:
			transfer_kind = ""
			_taken = false
			is_landed = false
			_visual.scale = Vector3.ONE
		return
	_flight_time += delta
	var t := clampf(_flight_time / _flight_duration, 0.0, 1.0)
	var eased := t * t * (3.0 - 2.0 * t)
	var target: Vector3 = _destination.intake_position() if transfer_kind == "furnace" else _destination.global_position + Vector3.UP
	global_position = _flight_start.lerp(target, eased) + Vector3.UP * sin(t * PI) * (0.8 if transfer_kind == "furnace" else 0.35)
	_visual.rotation += _spin * delta * 1.5
	_visual.scale = Vector3.ONE * lerpf(1.0, 0.08, t * t)
	if t >= 1.0:
		if transfer_kind == "furnace":
			if not _destination.receive(mineral_key, amount):
				transfer_kind = ""
				_taken = false
				_visual.scale = Vector3.ONE
				return
			collected.emit(mineral_key, amount, _destination)
		_completed = true
		queue_free()

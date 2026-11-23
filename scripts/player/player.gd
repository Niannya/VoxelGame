extends CharacterBody3D
## 矿工角色。支持本地双人：用 action_prefix 区分按键（p1_* / p2_*）。
## 移动按矿车轴向解释：车头方向为「前」，跟相机无关。
## 本节点自身不旋转，只有 Visual 子节点转向。

@export var action_prefix: String = "p1"
@export var max_hp: int = 3

@export var move_speed: float = 6.0
@export var ground_acceleration: float = 55.0
@export var ground_friction: float = 45.0
@export var turn_speed: float = 14.0
@export var gravity: float = 24.0
## 绑定移动平台后，玩家只能在平台顶面范围内活动
@export var platform_path: NodePath
@export var platform_margin: float = 0.6

signal damaged(player: Node, hp: int)
signal downed(player: Node)

var hp: int
var is_down := false

@onready var visual: Node3D = $Visual

var _platform: Node3D
var _tool_pivot: Node3D
var _swing: Tween
const OreBag = preload("res://scripts/items/ore_inventory.gd")
const Collector = preload("res://scripts/items/loot_collector.gd")


func _ready() -> void:
	hp = max_hp
	var inventory := Node.new()
	inventory.name = "Inventory"
	inventory.set_script(OreBag)
	add_child(inventory)
	var collector := Node.new()
	collector.name = "LootCollector"
	collector.set_script(Collector)
	collector.miner = self
	collector.inventory = inventory
	add_child(collector)
	if not platform_path.is_empty():
		_platform = get_node_or_null(platform_path)


# ---------------------------------------------------------------- 受伤

func take_hit(amount: int = 1) -> void:
	if is_down:
		return
	hp = maxi(0, hp - amount)
	damaged.emit(self, hp)
	if hp == 0:
		_go_down()


func _go_down() -> void:
	is_down = true
	velocity = Vector3.ZERO
	# 注意：不要关 _physics_process。倒地只是不响应输入，
	# 但还得继续被矿车带着走（_clamp_to_platform 必须照常跑）。
	visual.rotation.z = PI * 0.5
	visual.position.y = 0.5
	downed.emit(self)


# ---------------------------------------------------------------- 角色模型

func set_character_model(packed: PackedScene) -> void:
	if packed == null:
		return
	var model := packed.instantiate() as Node3D
	if model == null:
		return
	model.name = "SelectedCharacter"
	visual.add_child(model)
	var box := _model_bounds(model)
	if box.size.y > 0.0:
		var scale_factor := 2.0 / box.size.y   # 角色规格 1×1×2，模型按 2 高归一
		model.scale = Vector3.ONE * scale_factor
		model.position = Vector3(
			-(box.position.x + box.size.x * 0.5) * scale_factor,
			-box.position.y * scale_factor,
			-(box.position.z + box.size.z * 0.5) * scale_factor
		)
	model.rotation.y = PI
	_set_vertex_material(model)
	for child_name in ["Body", "Visor", "Helmet", "Lamp"]:
		visual.get_node(child_name).visible = false


func _set_vertex_material(node: Node) -> void:
	if node is MeshInstance3D:
		var material := ShaderMaterial.new()
		var shader := Shader.new()
		shader.code = "shader_type spatial; render_mode unshaded, cull_disabled; void fragment() { ALBEDO = COLOR.rgb * (0.72 + 0.28 * max(dot(normalize(NORMAL), normalize(vec3(-0.3, 0.6, 1.0))), 0.0)); }"
		material.shader = shader
		node.material_override = material
		node.lod_bias = 128.0
	for child in node.get_children():
		_set_vertex_material(child)


func _model_bounds(node: Node, xform := Transform3D.IDENTITY) -> AABB:
	var result := AABB()
	var found := false
	for child in node.get_children():
		var child_xform := xform
		if child is Node3D:
			child_xform = xform * (child as Node3D).transform
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			result = child_xform * (child as MeshInstance3D).get_aabb() if not found else result.merge(child_xform * (child as MeshInstance3D).get_aabb())
			found = true
		var sub := _model_bounds(child, child_xform)
		if sub.size != Vector3.ZERO:
			result = sub if not found else result.merge(sub)
			found = true
	return result


# ---------------------------------------------------------------- 移动

func _physics_process(delta: float) -> void:
	if is_down:
		# 倒地：不吃输入，但仍然受重力、仍然被平台带走
		velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, ground_friction * delta)
		if is_on_floor():
			velocity.y = 0.0
		else:
			velocity.y -= gravity * delta
		move_and_slide()
		_clamp_to_platform()
		return

	var input := Input.get_vector(
		action_prefix + "_left", action_prefix + "_right",
		action_prefix + "_forward", action_prefix + "_back")
	# 按屏幕轴向解释：W 往画面上方（远处那面墙），D 往画面右方（矿车前进方向）。
	# 相机是固定的侧视，所以要用相机 yaw 把输入转进世界。
	var dir := Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, _move_yaw())

	if dir.length_squared() > 0.001:
		dir = dir.normalized()
		velocity.x = move_toward(velocity.x, dir.x * move_speed, ground_acceleration * delta)
		velocity.z = move_toward(velocity.z, dir.z * move_speed, ground_acceleration * delta)
		# 模型正面朝 -Z，所以取反
		var target_yaw := atan2(-dir.x, -dir.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, minf(1.0, turn_speed * delta))
	else:
		velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, ground_friction * delta)

	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= gravity * delta

	move_and_slide()
	_clamp_to_platform()


func facing_dir() -> Vector3:
	## 模型正面朝 -Z，绕 Y 转 yaw 之后的正前方
	var yaw := visual.rotation.y
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func face_target(point: Vector3, delta: float) -> void:
	var direction := point - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		var yaw := atan2(-direction.x, -direction.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, yaw, minf(1.0, turn_speed * delta))


func show_tool_swing(definition: Resource) -> void:
	if _tool_pivot == null:
		_tool_pivot = Node3D.new()
		_tool_pivot.position = Vector3(0.6, 1.1, -0.3)
		visual.add_child(_tool_pivot)
		var grip := MeshInstance3D.new()
		var handle := BoxMesh.new()
		handle.size = Vector3(0.09, 0.09, 0.9)
		grip.mesh = handle
		grip.position.z = -0.35
		_tool_pivot.add_child(grip)
		var head := MeshInstance3D.new()
		head.name = "Head"
		var metal := BoxMesh.new()
		metal.size = Vector3(0.65, 0.13, 0.15)
		head.mesh = metal
		head.position.z = -0.78
		_tool_pivot.add_child(head)
	if _swing != null and _swing.is_valid():
		_swing.kill()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = definition.tint
	(_tool_pivot.get_node("Head") as MeshInstance3D).material_override = mat
	_tool_pivot.visible = true
	_tool_pivot.rotation.x = -0.8
	_swing = create_tween()
	_swing.tween_property(_tool_pivot, "rotation:x", 0.85, minf(0.15, definition.interval * 0.25))
	_swing.tween_property(_tool_pivot, "rotation:x", 0.0, minf(0.2, definition.interval * 0.35))
	_swing.tween_callback(func() -> void: _tool_pivot.visible = false)


func _move_yaw() -> float:
	## 移动严格沿矿车的两条水平轴：W 正对远墙（-X），D 正对矿车前方（-Z）。
	## 相机是固定的侧视但带 83° 而非 90°，直接用相机 yaw 会带出 6.7° 的斜向分量，
	## 所以这里把 yaw 吸附到最近的 90°，保证走的是纯轴向。
	var cam := get_viewport().get_camera_3d()
	var yaw := cam.global_rotation.y if cam != null else 0.0
	return snappedf(yaw, PI * 0.5)


func _clamp_to_platform() -> void:
	## 把玩家夹在平台顶面内。平台自己会带着玩家走（移动平台速度传递），
	## 这里只负责不让玩家跑出平台边缘。
	if _platform == null:
		return

	var hw: float = _platform.deck_half_width - platform_margin
	var hd: float = _platform.deck_half_depth - platform_margin
	var local := _platform.to_local(global_position)
	local.x = clampf(local.x, -hw, hw)
	local.z = clampf(local.z, -hd, hd)
	global_position = _platform.to_global(local)

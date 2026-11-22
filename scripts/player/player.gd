extends CharacterBody3D
## 可移动的矿工占位单位。
## 移动方向按屏幕方向解释：按 W 往画面深处走，A/D 左右平移。
## 本节点自身不旋转（相机是它的子节点），只有 Visual 子节点转向。

@export var move_speed: float = 6.0
@export var ground_acceleration: float = 55.0
@export var ground_friction: float = 45.0
@export var turn_speed: float = 14.0
@export var gravity: float = 24.0
## 起跳速度按「至少能跳上一格方块」定：v²/(2g) = 7.5²/48 ≈ 1.17 格
@export var jump_velocity: float = 7.5
## 绑定移动平台后，玩家只能在平台顶面范围内活动
@export var platform_path: NodePath
@export var platform_margin: float = 0.5

@onready var visual: Node3D = $Visual
@onready var _cam: Camera3D = $Camera3D

var _platform: Node3D


func _ready() -> void:
	if not platform_path.is_empty():
		_platform = get_node_or_null(platform_path)


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
		var scale_factor := 1.5 / box.size.y
		model.scale = Vector3.ONE * scale_factor
		model.position = Vector3(
			-(box.position.x + box.size.x * 0.5) * scale_factor,
			-box.position.y * scale_factor,
			-(box.position.z + box.size.z * 0.5) * scale_factor
		)
	model.rotation.y = PI
	for child_name in ["Body", "Visor", "Helmet", "Lamp"]:
		visual.get_node(child_name).visible = false


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


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# 相机偏航后，屏幕上方不再等于世界 -Z，得把输入方向一起转过去
	var dir := Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, _cam.global_rotation.y)

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
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
	else:
		velocity.y -= gravity * delta

	move_and_slide()
	_clamp_to_platform()


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

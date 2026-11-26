class_name FxWallOccluder
extends Node3D
## FX033 墙体遮挡淡化。
##
## 每帧做一次"相机 → 玩家"的线段与墙块 AABB 求交（纯数学，不依赖碰撞体），
## 命中的墙块切到遮挡材质并抖动淡出；不再遮挡后 0.18s 内插值回不透明，
## 并把 material_override 还原成原材质（验收要求："离开后正确恢复"）。

const SHADER := preload("res://fx/shaders/wall_occlusion.gdshader")

@export var fade_amount := 0.78
@export var fade_speed := 6.0
@export var restore_speed := 5.5
@export var min_cover := 0.06   ## 线段被墙体覆盖比例超过该值才淡化，避免轻微擦边就闪

var camera: Camera3D
var target: Node3D

var _walls: Array[Node3D] = []
var _mats := {}      # MeshInstance3D -> ShaderMaterial
var _fades := {}     # MeshInstance3D -> float
var _stopped := false


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY


func set_walls(walls: Array) -> void:
	_walls.clear()
	for w in walls:
		if w is Node3D:
			_walls.append(w)


func track(cam: Camera3D, who: Node3D) -> void:
	camera = cam
	target = who


func _process(delta: float) -> void:
	if _stopped:
		return
	var cam := camera
	if cam == null or not is_instance_valid(cam):
		cam = get_viewport().get_camera_3d()
	if cam == null or not is_instance_valid(target):
		return

	var from := cam.global_position
	var to := target.global_position + Vector3(0, 0.5, 0)
	var seg_len := from.distance_to(to)
	if seg_len < 0.1:
		return

	for w in _walls:
		for mi in _wall_meshes(w):
			var cover := _cover_ratio(from, to, mi)
			var want := fade_amount if cover > min_cover else 0.0
			var cur: float = _fades.get(mi, 0.0)
			var speed := fade_speed if want > cur else restore_speed
			cur = move_toward(cur, want, delta * speed / 0.18)
			_fades[mi] = cur
			if cur > 0.002:
				var m := _mat_for(mi)
				if m:
					m.set_shader_parameter("fade", clampf(cur, 0.0, 1.0))
			elif _mats.has(mi):
				_restore(mi)


func _wall_meshes(root: Node) -> Array:
	var out := []
	var stack := [root]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is MeshInstance3D and n.mesh != null:
			out.append(n)
		for c in n.get_children():
			stack.append(c)
	return out


func _cover_ratio(from: Vector3, to: Vector3, mi: MeshInstance3D) -> float:
	## 线段被该网格 AABB 覆盖的比例（0–1）。用覆盖比例而不是"是否命中"，
	## 可以让墙体边缘擦过时不至于整体闪一下。
	var box: AABB = mi.global_transform * mi.mesh.get_aabb()
	box = box.grow(0.02)
	var hit := _clip_segment(from, to, box)
	return hit


func _clip_segment(a: Vector3, b: Vector3, box: AABB) -> float:
	var d := b - a
	var tmin := 0.0
	var tmax := 1.0
	for axis in 3:
		var o := a[axis]
		var dd := d[axis]
		var mn := box.position[axis]
		var mx := box.position[axis] + box.size[axis]
		if absf(dd) < 0.000001:
			if o < mn or o > mx:
				return 0.0
		else:
			var t1 := (mn - o) / dd
			var t2 := (mx - o) / dd
			if t1 > t2:
				var tmp := t1
				t1 = t2
				t2 = tmp
			tmin = maxf(tmin, t1)
			tmax = minf(tmax, t2)
			if tmin > tmax:
				return 0.0
	# 靠近相机的部分不算遮挡（相机贴在墙里时不该淡）
	return clampf(tmax - tmin, 0.0, 1.0)


func _mat_for(mi: MeshInstance3D) -> ShaderMaterial:
	if _mats.has(mi):
		return _mats[mi]
	var src := mi.material_override
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("fade", 0.0)
	if src is BaseMaterial3D:
		m.set_shader_parameter("color_mul", src.albedo_color)
		if src.albedo_texture:
			m.set_shader_parameter("albedo_tex", src.albedo_texture)
			m.set_shader_parameter("use_tex", true)
	elif src is ShaderMaterial and src.shader == SHADER:
		# 已经是遮挡材质（重复 set_walls 时），直接复用
		_mats[mi] = src
		return src
	mi.set_meta("_fx_prev_override", src)
	mi.material_override = m
	_mats[mi] = m
	return m


func _restore(mi: MeshInstance3D) -> void:
	if not is_instance_valid(mi):
		_mats.erase(mi)
		return
	var prev = mi.get_meta("_fx_prev_override", null)
	mi.material_override = prev
	mi.remove_meta("_fx_prev_override")
	_fades[mi] = 0.0
	_mats.erase(mi)


func stop() -> void:
	_stopped = true
	for mi in _mats.keys():
		_restore(mi)
	queue_free()

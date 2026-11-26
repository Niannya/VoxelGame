class_name FxRope
extends Node3D
## FX009 绳索松弛 / FX010 绳索绷紧（同一控制器，两种状态）。
##
## 几何：程序化生成的方形截面"绳"，4 段棱边 + 沿长度 16 段折线，
## 松弛时中点下垂 20% 长度，绷紧时压到 1.2% —— 俯视下一个弯一个直，1 秒能分辨。
## 状态切换只改 uniform + 重建折线，不重建节点、不换材质实例（避免闪材质）。

const SHADER := preload("res://fx/shaders/rope.gdshader")

## 截面半宽（米）。俯视小角色 1.6m 高，绳宽 6cm 在 1080p 下约 3px，够看。
@export var radius := 0.030
@export var segments := 16
## 松弛时中点下垂量 = 绳长 × 该值
@export var slack_ratio := 0.20
## 绷紧时中点下垂量 = 绳长 × 该值
@export var taut_ratio := 0.012
## 状态过渡时长（秒）
@export var transition := 0.12

var _a := Vector3.ZERO
var _b := Vector3(0, 0, 2)
var _track_a: Node3D = null
var _track_b: Node3D = null
var _taut_target := 0.0
var _taut_f := 0.0
var _built_taut := -1.0
var _built_a := Vector3.INF
var _built_b := Vector3.INF
var _mi: MeshInstance3D
var _mat: ShaderMaterial


func _ready() -> void:
	top_level = true
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("taut", 0.0)
	_mi = MeshInstance3D.new()
	_mi.name = "RopeMesh"
	_mi.material_override = _mat
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mi.set_meta("_fx_no_flash", true)
	add_child(_mi)
	_rebuild()


# ── 公共接口 ──────────────────────────────────────────────────
func set_endpoints(a: Vector3, b: Vector3) -> void:
	_track_a = null
	_track_b = null
	_a = a
	_b = b
	_rebuild()


func track(a: Node3D, b: Node3D) -> void:
	## 让绳索每帧跟随两个节点（玩家 / 矿车 / 锚点）。
	_track_a = a
	_track_b = b
	if is_instance_valid(a):
		_a = a.global_position
	if is_instance_valid(b):
		_b = b.global_position
	_rebuild()


func set_taut(flag: bool, immediate := false) -> void:
	_taut_target = 1.0 if flag else 0.0
	if immediate:
		_taut_f = _taut_target
		if _mat:
			_mat.set_shader_parameter("taut", _taut_f)
		_rebuild()


func is_taut() -> bool:
	return _taut_target > 0.5


func stop() -> void:
	queue_free()


# ── 内部 ──────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if _track_a and is_instance_valid(_track_a):
		_a = _track_a.global_position
	if _track_b and is_instance_valid(_track_b):
		_b = _track_b.global_position

	if not is_equal_approx(_taut_f, _taut_target):
		_taut_f = move_toward(_taut_f, _taut_target, delta / maxf(transition, 0.001))
		_mat.set_shader_parameter("taut", _taut_f)

	if _built_a.distance_to(_a) > 0.004 or _built_b.distance_to(_b) > 0.004 \
			or absf(_built_taut - _taut_f) > 0.012:
		_rebuild()


func _rebuild() -> void:
	if _mi == null:
		return
	var dir := _b - _a
	var len_v := dir.length()
	if len_v < 0.02:
		return
	_built_a = _a
	_built_b = _b
	_built_taut = _taut_f

	var sag := lerpf(slack_ratio, taut_ratio, _taut_f) * len_v
	var fwd := dir / len_v
	var up := Vector3.UP
	if absf(fwd.dot(up)) > 0.98:
		up = Vector3.FORWARD
	var side := fwd.cross(up).normalized()
	var up2 := side.cross(fwd).normalized()
	var rads := radius * lerpf(1.0, 0.82, _taut_f)

	# 折线：直线 + 抛物线垂度（两端固定）
	var pts: Array[Vector3] = []
	for i in segments + 1:
		var t := float(i) / float(segments)
		var p := _a.lerp(_b, t)
		p.y -= sag * 4.0 * t * (1.0 - t)
		pts.append(p)

	# 4 个方形棱角方向
	var corners := [side + up2, -side + up2, -side - up2, side - up2]

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segments:
		var t0 := float(i) / float(segments)
		var t1 := float(i + 1) / float(segments)
		var axis_mid := (pts[i] + pts[i + 1]) * 0.5
		for s in 4:
			var c0: Vector3 = corners[s] * rads
			var c1: Vector3 = corners[(s + 1) % 4] * rads
			var p00: Vector3 = pts[i] + c0
			var p01: Vector3 = pts[i] + c1
			var p10: Vector3 = pts[i + 1] + c0
			var p11: Vector3 = pts[i + 1] + c1
			# 面朝外法线：由该面中心指向管轴
			var n := ((p00 + p01 + p10 + p11) * 0.25 - axis_mid).normalized()
			var u0 := float(s) / 4.0
			var u1 := float(s + 1) / 4.0
			_v(st, p00, n, Vector2(u0, t0))
			_v(st, p10, n, Vector2(u0, t1))
			_v(st, p11, n, Vector2(u1, t1))
			_v(st, p00, n, Vector2(u0, t0))
			_v(st, p11, n, Vector2(u1, t1))
			_v(st, p01, n, Vector2(u1, t0))

	_mi.mesh = st.commit()


func _v(st: SurfaceTool, p: Vector3, n: Vector3, uv: Vector2) -> void:
	st.set_normal(n)
	st.set_uv(uv)
	st.set_color(Color.WHITE)
	st.add_vertex(p)

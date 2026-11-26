class_name FxRescue
extends Node3D
## FX024 救援进行反馈（持续型，进度由程序驱动）。
##
## 进度条与特效同一个数据源：玩法侧每次更新进度条就 set_progress()，
## 环形填充与光点密度一起变，天然"与进度条一致"（验收要求）。

const RING_SHADER := preload("res://fx/shaders/ring.gdshader")

var _fill_mat: ShaderMaterial
var _sweep_mat: ShaderMaterial
var _motes: CPUParticles3D
var _progress := 0.0
var _t := 0.0
var _color := FxPalette.SUCCESS


func _ready() -> void:
	# 进度环：贴地，半径固定，按角度填充
	var q := QuadMesh.new()
	q.size = Vector2(1.5, 1.5)
	q.orientation = PlaneMesh.FACE_Y
	_fill_mat = ShaderMaterial.new()
	_fill_mat.shader = RING_SHADER
	_fill_mat.set_shader_parameter("color", _color)
	_fill_mat.set_shader_parameter("progress", 1.0)
	_fill_mat.set_shader_parameter("thickness", 0.10)
	_fill_mat.set_shader_parameter("strength", 1.15)
	_fill_mat.set_shader_parameter("fill", 0.0)
	_fill_mat.set_shader_parameter("grit", 0.15)
	var fill := FxUtil.mesh_instance(q, _fill_mat, Vector3(0, 0.03, 0))
	fill.name = "ProgressRing"
	fill.set_meta("_fx_no_flash", true)
	add_child(fill)

	# 外扫环：一直向外扫，表示"正在处理中"
	var q2 := QuadMesh.new()
	q2.size = Vector2(1.15, 1.15)
	q2.orientation = PlaneMesh.FACE_Y
	_sweep_mat = ShaderMaterial.new()
	_sweep_mat.shader = RING_SHADER
	_sweep_mat.set_shader_parameter("color", _color)
	_sweep_mat.set_shader_parameter("thickness", 0.06)
	_sweep_mat.set_shader_parameter("strength", 0.55)
	var sweep := FxUtil.mesh_instance(q2, _sweep_mat, Vector3(0, 0.025, 0))
	sweep.name = "SweepRing"
	sweep.set_meta("_fx_no_flash", true)
	add_child(sweep)

	# 上浮光点：密度随进度升高
	_motes = FxUtil.particles({
		"amount": 26,
		"lifetime": 1.15,
		"one_shot": false,
		"explosiveness": 0.0,
		"randomness": 0.8,
		"mesh": FxUtil.quad(0.07, FxUtil.billboard_material(_color, true, FxUtil.dot_texture())),
		"shape": CPUParticles3D.EMISSION_SHAPE_SPHERE,
		"sphere_radius": 0.34,
		"direction": Vector3.UP,
		"spread": 24.0,
		"gravity": Vector3(0, 0.7, 0),
		"vmin": 0.5,
		"vmax": 1.1,
		"smin": 0.55,
		"smax": 1.1,
		"color_ramp": FxUtil.ramp([
			Color(_color.r, _color.g, _color.b, 0.0),
			Color(_color.r, _color.g, _color.b, 0.9),
			Color(_color.r, _color.g, _color.b, 0.0),
		], [0.0, 0.25, 1.0]),
	})
	_motes.name = "Motes"
	_motes.position.y = 0.12
	_motes.set_meta("_fx_no_flash", true)
	add_child(_motes)
	# 必须入树后再开启发射：CPUParticles3D 的 emitting setter 会读取全局变换
	_motes.emitting = true


func _process(delta: float) -> void:
	_t += delta
	# 扫描环 0→1 循环
	var sweep := fmod(_t * 0.85, 1.0)
	_sweep_mat.set_shader_parameter("progress", sweep)
	_sweep_mat.set_shader_parameter("strength", 0.55 * (1.0 - sweep))


func set_progress(p: float) -> void:
	_progress = clampf(p, 0.0, 1.0)
	_fill_mat.set_shader_parameter("fill", _progress)
	# 越接近完成，环越亮、光点越密
	_fill_mat.set_shader_parameter("strength", lerpf(0.75, 1.5, _progress))
	if is_instance_valid(_motes):
		_motes.speed_scale = lerpf(0.7, 1.6, _progress)
		_motes.scale = Vector3.ONE * lerpf(0.85, 1.15, _progress)


func get_progress() -> float:
	return _progress


func stop() -> void:
	queue_free()

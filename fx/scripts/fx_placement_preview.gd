class_name FxPlacementPreview
extends Node3D
## FX015 支撑可放置预览 / FX016 支撑不可放置预览（同一控制器，两种状态）。
##
## 验收关键："可放置位置与真实落点一致" —— 所以预览不做二次吸附，
## 直接用玩法侧算好的 Transform（set_target）绘制，显示在哪就落在哪。

const GHOST_SHADER := preload("res://fx/shaders/placement_ghost.gdshader")

@export var preview_size := Vector3(0.6, 1.0, 0.6)
@export var footprint := 1.3

var _valid := true
var _pulse := 0.0
var _phase := 0.0
var _ghost: MeshInstance3D
var _foot: MeshInstance3D
var _cross: Node3D
var _mat: ShaderMaterial
var _foot_mat: ShaderMaterial
var _cross_mat: StandardMaterial3D


func _ready() -> void:
	var box := BoxMesh.new()
	box.size = preview_size
	_mat = ShaderMaterial.new()
	_mat.shader = GHOST_SHADER
	_mat.set_shader_parameter("tint", FxPalette.VALID)
	_mat.set_shader_parameter("alpha", 0.26)
	_mat.set_shader_parameter("valid", 1.0)
	_ghost = MeshInstance3D.new()
	_ghost.name = "Ghost"
	_ghost.mesh = box
	_ghost.material_override = _mat
	_ghost.position.y = preview_size.y * 0.5
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.set_meta("_fx_no_flash", true)
	add_child(_ghost)

	# 地面占格
	var q := QuadMesh.new()
	q.size = Vector2(footprint, footprint)
	q.orientation = PlaneMesh.FACE_Y
	_foot_mat = ShaderMaterial.new()
	_foot_mat.shader = GHOST_SHADER
	_foot_mat.set_shader_parameter("tint", FxPalette.VALID)
	_foot_mat.set_shader_parameter("alpha", 0.16)
	_foot_mat.set_shader_parameter("valid", 1.0)
	_foot_mat.set_shader_parameter("stripe_density", 6.0)
	_foot = MeshInstance3D.new()
	_foot.name = "Footprint"
	_foot.mesh = q
	_foot.material_override = _foot_mat
	_foot.position.y = 0.02
	_foot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_foot.set_meta("_fx_no_flash", true)
	add_child(_foot)

	# 禁止标记：地面上一个红叉，只有不可放置时出现
	_cross = Node3D.new()
	_cross.name = "NoCross"
	_cross.position.y = 0.035
	_cross.visible = false
	_cross_mat = FxUtil.unshaded_alpha(FxPalette.DANGER, true)
	var bar_len := footprint * 0.82
	for i in 2:
		var bar := MeshInstance3D.new()
		bar.mesh = FxUtil.box(Vector3(bar_len, 0.012, 0.075), _cross_mat)
		bar.rotation_degrees.y = 45.0 if i == 0 else -45.0
		bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bar.set_meta("_fx_no_flash", true)
		_cross.add_child(bar)
	add_child(_cross)


func _process(delta: float) -> void:
	var rate := 4.0 if not _valid else 0.7
	_phase += delta * rate
	_pulse = 0.5 + 0.5 * sin(_phase * TAU)
	_mat.set_shader_parameter("pulse", _pulse)
	_foot_mat.set_shader_parameter("pulse", _pulse)

	# 不可放置时轻微抖动：即使看不清颜色也知道"这里不行"
	var jitter := 0.0
	if not _valid:
		jitter = sin(_phase * TAU * 2.0) * 0.012
	_ghost.position.x = jitter
	_foot.position.x = jitter * 0.5


func set_target(t: Transform3D) -> void:
	## 直接使用玩法侧计算的实际落点：不做二次吸附，避免"看着能放、实际放不上"。
	var b := t.basis.orthonormalized()
	global_transform = Transform3D(b, t.origin)


func set_valid(v: bool) -> void:
	_valid = v
	var tint := FxPalette.VALID if v else FxPalette.DANGER
	_mat.set_shader_parameter("tint", tint)
	_mat.set_shader_parameter("valid", 1.0 if v else 0.0)
	_mat.set_shader_parameter("stripe_speed", 1.6 if v else 3.2)
	_foot_mat.set_shader_parameter("tint", tint)
	_foot_mat.set_shader_parameter("valid", 1.0 if v else 0.0)
	_foot_mat.set_shader_parameter("stripe_speed", 1.6 if v else 3.2)
	_cross.visible = not v
	if not v:
		_phase = 0.0


func set_size(size: Vector3, foot := -1.0) -> void:
	preview_size = size
	var box := BoxMesh.new()
	box.size = size
	_ghost.mesh = box
	_ghost.position.y = size.y * 0.5
	if foot > 0.0:
		footprint = foot
		_foot.mesh.size = Vector2(foot, foot)


func stop() -> void:
	queue_free()

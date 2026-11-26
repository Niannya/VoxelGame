class_name FxScreenDanger
extends CanvasLayer
## FX020 临界危险屏幕提示（持续型，强度 0–1 连续变化）。
##
## 只染画面边缘、中央留空，所以"画面中央仍可操作"（验收要求）。
## ColorRect 设 IGNORE 鼠标事件，不会挡住 UI 点击。

const SHADER := preload("res://fx/shaders/screen_danger.gdshader")

var _rect: ColorRect
var _mat: ShaderMaterial
var _target := 0.0
var _current := 0.0
var _critical := 0.0
var _rise := 4.0


func _ready() -> void:
	layer = 8
	_rect = ColorRect.new()
	_rect.name = "DangerOverlay"
	_rect.color = Color(1, 1, 1, 1)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("intensity", 0.0)
	_mat.set_shader_parameter("danger_color", FxPalette.DANGER)
	_mat.set_shader_parameter("clearance", 0.52)
	_rect.material = _mat
	add_child(_rect)


func _process(delta: float) -> void:
	if not is_instance_valid(_rect):
		return
	_current = move_toward(_current, _target, delta * _rise)
	_mat.set_shader_parameter("intensity", _current)
	_mat.set_shader_parameter("critical", _critical)
	var vs := get_viewport().get_visible_rect().size
	if vs.y > 0.0:
		_mat.set_shader_parameter("aspect", vs.x / vs.y)


func set_intensity(v: float, immediate := false) -> void:
	_target = clampf(v, 0.0, 1.0)
	# 危险度越高，升得越快（临界的反馈要"追得上"）
	_rise = lerpf(2.5, 7.0, _target)
	if immediate:
		_current = _target


func set_critical(v: float) -> void:
	_critical = clampf(v, 0.0, 1.0)


func reset() -> void:
	## 重开时必须调用：强度归零，不留红边（FX020 清理条件）。
	_target = 0.0
	_current = 0.0
	_critical = 0.0
	if is_instance_valid(_mat):
		_mat.set_shader_parameter("intensity", 0.0)
		_mat.set_shader_parameter("critical", 0.0)


func stop() -> void:
	queue_free()

class_name FxScreenTransition
extends CanvasLayer
## FX023 失败画面转场（去饱和 → 暗红压边 → 全黑）。
##
## 三段式节奏：0–0.42 去饱和 / 0.22–0.62 压边 / 0.60–1.0 转黑，
## 结尾留 0.25s 纯黑给结算界面淡入（避免结算 UI 和黑场互相闪）。
## reset() 会把 progress 归零并立即刷新 uniform（验收要求"重开后正确复位"）。

signal transition_finished

const SHADER := preload("res://fx/shaders/screen_transition.gdshader")

var progress := 0.0
var _mat: ShaderMaterial
var _rect: ColorRect
var _tw: Tween


func _ready() -> void:
	layer = 20
	_rect = ColorRect.new()
	_rect.name = "TransitionOverlay"
	_rect.color = Color(1, 1, 1, 1)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("progress", 0.0)
	_mat.set_shader_parameter("tint_color", Color(0.07, 0.02, 0.02))
	_rect.material = _mat
	add_child(_rect)
	_apply()


func play(duration := 1.0, hold_black := 0.25) -> void:
	## 0 → 1 播放一次，结束时发 transition_finished 给玩法侧切结算界面。
	if _tw and _tw.is_valid():
		_tw.kill()
	progress = 0.0
	_apply()
	_tw = create_tween()
	_tw.tween_property(self, "progress", 1.0, maxf(duration, 0.1)) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tw.tween_interval(maxf(hold_black, 0.0))
	_tw.tween_callback(func(): transition_finished.emit())


func set_progress(v: float) -> void:
	progress = clampf(v, 0.0, 1.0)
	_apply()


func reset() -> void:
	## 重开清场：杀掉补间、progress 归零、uniform 立即刷新。
	if _tw and _tw.is_valid():
		_tw.kill()
	_tw = null
	progress = 0.0
	_apply()


func _process(_delta: float) -> void:
	_apply()


func _apply() -> void:
	if is_instance_valid(_mat):
		_mat.set_shader_parameter("progress", progress)
	if is_instance_valid(_rect):
		_rect.visible = progress > 0.001


func stop() -> void:
	reset()
	queue_free()

class_name FxDustField
extends Node3D
## FX018 矿洞危险落尘（持续型，强度分级）。
##
## 用 3 层粒子叠加代表 轻 / 中 / 重 三档，靠"开关层"改强度而不是重启发射器，
## 所以强度变化是渐进的、不会整片闪掉。尘条压在 0.02×0.30m，alpha ≠ 0.35 上限，
## 落点在画面边缘时也几乎不挡交互（验收要求"不遮挡交互"）。

## 三层对应的开启阈值（0–1），强度越过阈值就点亮该层
const THRESHOLDS := [0.04, 0.38, 0.70]
const AMOUNTS := [14, 30, 52]

var ceiling_height := 3.0
var area_radius := 2.6
var dust_color := FxPalette.DUST

var _layers: Array[CPUParticles3D] = []
var _intensity := 0.0


func _ready() -> void:
	var mat := FxUtil.unshaded_alpha(dust_color, false)
	mat.vertex_color_use_as_albedo = true
	var mesh := FxUtil.box(Vector3(0.014, 0.30, 0.014), mat)

	for i in 3:
		var p := FxUtil.particles({
			"amount": AMOUNTS[i],
			"lifetime": 1.9,
			"one_shot": false,
			"explosiveness": 0.0,
			"randomness": 0.75,
			"mesh": mesh,
			"shape": CPUParticles3D.EMISSION_SHAPE_BOX,
			"box_extents": Vector3(area_radius, 0.15, area_radius),
			"direction": Vector3(0, -1, 0),
			"spread": 6.0,
			"gravity": Vector3(0, -0.9, 0),
			"vmin": 1.1,
			"vmax": 1.9,
			"smin": 0.7,
			"smax": 1.25,
			"align_y": true,
			"color_ramp": FxUtil.ramp([
				Color(dust_color.r, dust_color.g, dust_color.b, 0.0),
				Color(dust_color.r, dust_color.g, dust_color.b, 0.34),
				Color(dust_color.r, dust_color.g, dust_color.b, 0.26),
				Color(dust_color.r, dust_color.g, dust_color.b, 0.0),
			], [0.0, 0.18, 0.7, 1.0]),
		})
		p.name = "DustLayer%d" % i
		p.position = Vector3(0, ceiling_height, 0)
		p.set_meta("_fx_no_flash", true)
		p.emitting = false
		add_child(p)
		_layers.append(p)

	set_intensity(0.45)


func set_intensity(v: float) -> void:
	_intensity = clampf(v, 0.0, 1.0)
	for i in _layers.size():
		var on: bool = _intensity > float(THRESHOLDS[i])
		if _layers[i].emitting != on:
			_layers[i].emitting = on
		_layers[i].speed_scale = lerpf(0.75, 1.3, _intensity)


func get_intensity() -> float:
	return _intensity


func stop() -> void:
	queue_free()

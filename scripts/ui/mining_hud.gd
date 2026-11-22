extends CanvasLayer
## 右下角面板：推进距离 + 已挖总数 + 各类矿石分项。

const TYPE_NAMES := {
	"gold": "黄金",
	"quartz": "石英",
	"diamond": "钻石",
	"emerald": "绿宝石",
}

@onready var _head: Label = $Panel/VBox/Total
@onready var _detail: Label = $Panel/VBox/Detail

var _broken := 0
var _by_type: Dictionary = {}
var _distance := 0.0


func update_counts(total: int, by_type: Dictionary) -> void:
	_broken = total
	_by_type = by_type
	_render()


func set_distance(metres: float) -> void:
	_distance = metres
	_render()


func _render() -> void:
	if _head == null:
		return
	_head.text = "%.0f 米 · 已挖 %d" % [_distance, _broken]

	var parts: Array[String] = []
	for key in ["gold", "quartz", "diamond", "emerald"]:
		var n: int = _by_type.get(key, 0)
		if n > 0:
			parts.append("%s %d" % [TYPE_NAMES[key], n])

	if parts.is_empty():
		_detail.text = "P1: WASD + 空格     P2: 方向键 + 小键盘0"
	else:
		_detail.text = "  ".join(parts)

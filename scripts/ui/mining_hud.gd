extends CanvasLayer
## 右下角计数面板：总数 + 各类矿石分项。

const TYPE_NAMES := {
	"gold": "黄金",
	"quartz": "石英",
	"diamond": "钻石",
	"emerald": "绿宝石",
}

@onready var _total: Label = $Panel/VBox/Total
@onready var _detail: Label = $Panel/VBox/Detail


func update_counts(total: int, by_type: Dictionary) -> void:
	_total.text = "已挖 %d" % total

	var parts: Array[String] = []
	for key in ["gold", "quartz", "diamond", "emerald"]:
		var n: int = by_type.get(key, 0)
		if n > 0:
			parts.append("%s %d" % [TYPE_NAMES[key], n])

	if parts.is_empty():
		_detail.text = "对着方块长按左键开挖"
	else:
		_detail.text = "  ".join(parts)

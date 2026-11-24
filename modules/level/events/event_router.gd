## L07 随机事件路由：只做"登记 + 判定入口 + 本局状态"，具体效果分发出去。
##
## 已实现：事件编号表、触发记录、本局状态容器（钱包/押运/借料/尸潮标记）。
## 未实现：16 项事件的判定条件与效果（见 Docs/Dev/关卡缺口清单.md）——
## 每接一个事件，在这里加一个 `_on_<id>()` 并在 `_evaluate()` 里挂上触发源。
##
## 给其他模块的约定：
## - 别的模块只调 `trigger(id, payload)` 上报"我这边发生了什么"，
##   由本节点决定要不要真的发事件；状态用 `set_state/get_state` 存。
## - 金币/天赋/掉落的实际结算不在这里，分别调 EconomyService / P09 / L01。
class_name LevelEventRouter
extends Node

signal event_triggered(event_id: int, payload: Dictionary)

## 事件编号 → 名称（保留原表编号，方便和策划案对照）。
const EVENT_NAMES := {
	1: "商人的报恩",
	2: "借两根枕木，下次还",
	4: "商人的货物押运",
	5: "熔炉厌食",
	6: "熔炉评上自助餐",
	7: "绳结说它累了",
	8: "全队突然走出了队形",
	9: "丧尸自觉排队",
	10: "丧尸医药箱写着“随便拿”",
	11: "手推补给车刹不住",
	12: "安全帽抽中模范员工",
	13: "商人把摊摆在轨道上",
	14: "方块吐出一张“全队请签收”",
	15: "熔炉点菜",
	16: "矿物房",
	18: "尸潮",
}

## 本局事件状态（钱包是否归还、押运进度、借料次数、尸潮是否已触发…）。
var _state: Dictionary = {}
## 每个事件本局触发过的次数（用于"每层最多一次""每个名额只触发一次"）。
var _fired: Dictionary = {}


func trigger(event_id: int, payload: Dictionary = {}) -> bool:
	if not EVENT_NAMES.has(event_id):
		push_warning("未知事件编号: %d" % event_id)
		return false
	_fired[event_id] = int(_fired.get(event_id, 0)) + 1
	event_triggered.emit(event_id, payload)
	return true


func fired_count(event_id: int) -> int:
	return int(_fired.get(event_id, 0))


func event_name(event_id: int) -> String:
	return String(EVENT_NAMES.get(event_id, "未知事件"))


func set_state(key: String, value: Variant) -> void:
	_state[key] = value


func get_state(key: String, fallback: Variant = null) -> Variant:
	return _state.get(key, fallback)


## 本局重开时清空。
func reset() -> void:
	_state.clear()
	_fired.clear()

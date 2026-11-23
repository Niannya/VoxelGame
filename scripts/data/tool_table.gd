class_name ToolTable
extends RefCounted
## 起始工具表：6 把，角色选择界面与局内共用。
##
## 词条按策划案 §10 走：攻击力 / 攻击范围 / 攻击间隔 / 挖矿效率 / 爆炸半径 / 友伤。
## 本表只放当前实现用得上的：`atk`（攻击力，0~100 面板值）、`dig`（挖矿效率倍率，0 = 不能挖矿）、
## `dur`（耐久面板值，占位）、`clip`（骨骼动画 clip 名，必须与 character_animation.gd 的 TOOL_CLIPS 一致）。
##
## 互斥规则：攻击力和挖矿效率只能一高一低，禁止双高；双低可作为垃圾道具存在。
## 非爆炸的远程工具挖矿效率 = 0（木弓）。

const TOOLS := [
	{
		"name": "采集镐", "type": "采集", "desc": "敲击矿石与晶簇，产出基础材料。挖矿效率最高，打怪很吃力。",
		"atk": 12, "dur": 80, "dig": 1.8, "clip": &"Pick",
	},
	{
		"name": "建造锤", "type": "建造", "desc": "放置与加固体素方块，修筑工事；也能敲开矿壁，但不快。",
		"atk": 25, "dur": 95, "dig": 1.0, "clip": &"Hammer",
	},
	{
		"name": "木弓", "type": "战斗", "desc": "远程射击，消耗箭矢。攻击力最高，但挖不动矿。",
		"atk": 45, "dur": 55, "dig": 0.0, "clip": &"Bow",
	},
	{
		"name": "火把", "type": "照明", "desc": "照亮黑暗区域，驱散部分敌怪。挖矿和打架都一般。",
		"atk": 5, "dur": 40, "dig": 0.5, "clip": &"Torch",
	},
	{
		"name": "背包", "type": "功能", "desc": "扩容携带格，提升负重上限。几乎不能挖矿，也不会打架。",
		"atk": 0, "dur": 70, "dig": 0.5, "clip": &"Backpack",
	},
	{
		"name": "水壶", "type": "功能", "desc": "储存饮水，缓解口渴值消耗。几乎不能挖矿，也不会打架。",
		"atk": 0, "dur": 60, "dig": 0.5, "clip": &"Canteen",
	},
]


static func count() -> int:
	return TOOLS.size()


static func clamp_index(index: int) -> int:
	return clampi(index, 0, TOOLS.size() - 1)


static func by_index(index: int) -> Dictionary:
	return TOOLS[clamp_index(index)]


static func dig_of(index: int) -> float:
	return float(by_index(index).get("dig", 0.0))


static func name_of(index: int) -> String:
	return str(by_index(index).get("name", ""))


## 单格挖掘耗时（秒）= 基础 0.4 s × 矿石硬度 ÷ 工具挖矿效率。
## 挖矿效率为 0 的工具（木弓）返回 -1，表示"挖不动"。
static func break_seconds(index: int, ore_key: String, base_seconds: float = 0.4) -> float:
	var dig := dig_of(index)
	if dig <= 0.0:
		return -1.0
	return maxf(0.05, base_seconds * OreTable.dig_of(ore_key) / dig)

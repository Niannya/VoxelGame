## 首测默认数据（方块表 / 掉落表 / 生成器）。
##
## 存在的意义：让场景不需要手工拖一堆 .tres 也能跑起来，
## 同时保留"从检查器覆盖"的能力——场景里填了就用场景的，没填就用这里。
##
## 换数值流程：改这里（或改成 .tres 后挂上去）→ 跑 tests/level/level_selftest → 看断言。
class_name LevelDefaults
extends RefCounted


static func block_types() -> Array[LevelBlockType]:
	var out: Array[LevelBlockType] = []
	out.append(_bt(&"stone_a", "岩石（亮）", &"stone", 1.0, false, &"stone_a"))
	out.append(_bt(&"stone_b", "岩石（暗）", &"stone", 1.0, false, &"stone_b"))
	out.append(_bt(&"bedrock", "矿壁边界", &"boundary", 1.0, true, &"bedrock"))
	return out


static func _bt(id: StringName, name: String, category: StringName, hardness: float,
		boundary: bool, art_key: StringName) -> LevelBlockType:
	var bt := LevelBlockType.new()
	bt.id = id
	bt.display_name = name
	bt.category = category
	bt.hardness = hardness
	bt.is_boundary = boundary
	bt.art_key = art_key
	return bt


static func loot_table() -> LevelLootTable:
	return LevelLootDataL01.build()


static func generator() -> LevelMineGenerator:
	return LevelMineGenerator.new()

## 分层掉落表（L01 数据层）。
##
## 设计口径（对应需求案 L01 第 4、5 节）：
## - 每一层独立一套权重，单层权重总和应为 per_depth_total（首测 100000）。
## - 抽一次是 `randi() % total`，落在谁的区间出谁。多格挥击逐格独立抽。
## - 每格只抽 1 件基础掉落；额外产物（富矿、事件）走 L07，不在这里。
##
## 给其他模块的约定：
## - 只有 LevelVoxelGrid 会调用 roll()，其他模块请通过 `block_broken` 信号拿结果。
## - 想改数值请改 LevelLootDataL01 或换成编辑器里编辑的本资源，不要改这个类。
@tool
class_name LevelLootTable
extends Resource

## 单层权重总量。100000 表示 0.001% = 1 单位。
@export var per_depth_total: int = 100000

## 表覆盖到第几层；更深的层沿用最后一层。
@export var max_depth: int = 8

@export var entries: Array[LevelLootEntry] = []


## 某物品在某一层的权重。
func weight_of(entry: LevelLootEntry, depth: int) -> int:
	return entry.weight_at(depth)


## 某层所有物品的权重总和。
func total_weight(depth: int) -> int:
	var sum := 0
	for e in entries:
		sum += weight_of(e, depth)
	return sum


## 抽一件基础掉落。表为空或权重为 0 时返回 null（由调用方兜底，不要崩）。
func roll(depth: int, rng: RandomNumberGenerator) -> LevelLootEntry:
	var total := total_weight(depth)
	if total <= 0:
		return null
	var pick := rng.randi_range(0, total - 1)
	var cursor := 0
	for e in entries:
		cursor += weight_of(e, depth)
		if pick < cursor:
			return e
	return entries[entries.size() - 1]


## 某层每格基础掉落的平均售价，用于经济校验（需求案：第 1 层 ≈ 8.455）。
func expected_value(depth: int) -> float:
	var total := total_weight(depth)
	if total <= 0:
		return 0.0
	var acc := 0.0
	for e in entries:
		acc += float(weight_of(e, depth)) * float(e.price)
	return acc / float(total)


## 自检：返回问题列表，空数组表示表是干净的。
## 供 tests/level/level_selftest.gd 和编辑器工具调用。
func validate() -> Array[String]:
	var problems: Array[String] = []
	if entries.is_empty():
		problems.append("掉落表为空")
		return problems

	var seen := {}
	for e in entries:
		if e.item_id == &"":
			problems.append("有条目缺少 item_id")
		if seen.has(e.item_id):
			problems.append("item_id 重复: %s" % e.item_id)
		seen[e.item_id] = true
		if e.weights.is_empty():
			problems.append("%s 没有权重" % e.item_id)

	for depth in range(1, max_depth + 1):
		var total := total_weight(depth)
		if total != per_depth_total:
			problems.append("第 %d 层权重合计 %d，应为 %d" % [depth, total, per_depth_total])
	return problems

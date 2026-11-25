## 掉落表的一行（L01 数据层）。
##
## `weights[i]` 是第 i+1 层的整数权重，基准总量由 LevelLootTable.per_depth_total 决定
## （首测 100000，即 0.001% = 1 个权重单位）。层数超出数组长度时沿用最后一层。
@tool
class_name LevelLootEntry
extends Resource

## 物品 ID，**不要改名**（存档与押运任务会引用）。
@export var item_id: StringName = &""

@export var display_name: String = ""

## 基础售价（金币/件），不随深度变化。
@export var price: int = 1

## 类别：junk / mineral / antique。熔炉事件与押运都按类别判定。
@export var tier: StringName = &"junk"

## 是否参与"天然矿物"标签（富矿发现、熔炉点菜、厌食解除等）。
@export var is_natural_mineral: bool = false

## 每层权重，下标 0 = 第 1 层。
@export var weights: PackedInt32Array = PackedInt32Array()

## 取第 depth 层（1 起）的权重。
func weight_at(depth: int) -> int:
	if weights.is_empty():
		return 0
	var idx := clampi(depth, 1, weights.size()) - 1
	return weights[idx]

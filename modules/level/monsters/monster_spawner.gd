## L05 丧尸刷怪：抽怪逻辑已按需求案实现，追赶 AI 与场景实体还没接。
##
## 已实现（纯函数，可单测）：两路独立抽怪、层尾工头保底名额、保底起点。
## 未实现：丧尸场景预制体、寻路追击、接触伤害、尸潮计时（见 Docs/Dev/关卡缺口清单.md）。
##
## 给其他模块的约定：P08 只接收 `contact` 事件；击杀结果通过 L07 记录，不要直接改这里的状态。
class_name LevelMonsterSpawner
extends Node

signal spawned(kind: StringName)
signal wave_started(count: int)

## 四种普通怪的 id（与美术/预制体命名一致）。
const WANDERER := &"zombie_wanderer"
const RUNNER := &"zombie_runner"
const BRUTE := &"zombie_brute"
const LUNGE := &"zombie_lunge"
const FOREMAN := &"zombie_foreman"

## 常规刷怪概率表（需求案 L05 §2）。同一档内每层数值相同。
## "none" 表示这一轮不出普通怪。
const NORMAL_BANDS := [
	{
		"max_depth": 1,
		"weights": {&"zombie_wanderer": 70, &"zombie_runner": 14, &"zombie_brute": 10,
			&"zombie_lunge": 5, &"none": 1},
		"foreman": 5,
	},
	{
		"max_depth": 2,
		"weights": {&"zombie_wanderer": 60, &"zombie_runner": 16, &"zombie_brute": 15,
			&"zombie_lunge": 7, &"none": 2},
		"foreman": 6,
	},
	{
		"max_depth": 4,
		"weights": {&"zombie_wanderer": 48, &"zombie_runner": 17, &"zombie_brute": 20,
			&"zombie_lunge": 11, &"none": 4},
		"foreman": 8,
	},
	{
		"max_depth": 6,
		"weights": {&"zombie_wanderer": 38, &"zombie_runner": 18, &"zombie_brute": 23,
			&"zombie_lunge": 15, &"none": 6},
		"foreman": 10,
	},
	{
		"max_depth": 999,
		"weights": {&"zombie_wanderer": 31, &"zombie_runner": 18, &"zombie_brute": 25,
			&"zombie_lunge": 18, &"none": 8},
		"foreman": 12,
	},
]


static func band_for(depth: int) -> Dictionary:
	for band in NORMAL_BANDS:
		if depth <= int(band["max_depth"]):
			return band
	return NORMAL_BANDS[NORMAL_BANDS.size() - 1]


## 普通怪路线：返回怪 id，或 &"none" 表示本轮不出。
static func pick_normal(depth: int, rng: RandomNumberGenerator) -> StringName:
	var weights: Dictionary = band_for(depth)["weights"]
	var total := 0
	for key in weights:
		total += int(weights[key])
	var pick := rng.randi_range(0, total - 1)
	var cursor := 0
	for key in weights:
		cursor += int(weights[key])
		if pick < cursor:
			return key
	return &"none"


## 工头路线：与普通怪独立判定，同轮可能两路都出。
static func roll_foreman(depth: int, rng: RandomNumberGenerator) -> bool:
	var chance: int = int(band_for(depth)["foreman"])
	return rng.randi_range(0, 99) < chance


## 层尾保底数量：2 × 层数。
static func foreman_quota(depth: int) -> int:
	return 2 * depth


## 保底起点（本层已走格数）：本层长度 − 10。
static func foreman_start_floor_progress(depth: int) -> int:
	return maxi(0, 50 * depth - 10)

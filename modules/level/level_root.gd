## 关卡根节点：把 L01～L07 的部件装配起来，并对外提供一个稳定的门面。
##
## 为什么需要它：玩家侧的 mining_controller.gd 是别人的文件，它现在按老接口调用
## `raycast_block / break_block / block_broken 信号`。这里保留这些方法做**兼容层**，
## 让关卡重构不会打断队友，等他们迁到新接口再删（迁移说明见模块 AGENTS.md）。
##
## 子节点约定（不要改名，队友的 NodePath 依赖它们）：
##   Grid       LevelVoxelGrid
##   Renderer   LevelVoxelRenderer
##   LevelState LevelState
##   Track      LevelTrackService
##   Stability  LevelStabilityService
##   MineCart   LevelCartController
class_name LevelRoot
extends Node3D

## 兼容旧 mining_controller 的两参数信号（新代码请用 grid.block_broken）。
signal block_broken(pos: Vector3i, key: String)

@onready var grid: LevelVoxelGrid = get_node_or_null("Grid") as LevelVoxelGrid
@onready var renderer: LevelVoxelRenderer = get_node_or_null("Renderer") as LevelVoxelRenderer
@onready var state: LevelState = get_node_or_null("LevelState") as LevelState
@onready var track: LevelTrackService = get_node_or_null("Track") as LevelTrackService
@onready var stability: LevelStabilityService = get_node_or_null("Stability") as LevelStabilityService
@onready var cart: LevelCartController = get_node_or_null("MineCart") as LevelCartController


func _ready() -> void:
	if grid != null:
		grid.block_broken.connect(_on_grid_block_broken)


func _on_grid_block_broken(cell: Vector3i, block_id: StringName, _drops: Array) -> void:
	block_broken.emit(cell, String(block_id))


# ---------------------------------------------------------------- 兼容层（给 P03/P04）
# 这些方法在"队友迁到新接口"之后就可以删，删之前请确认 mining_controller.gd 已不调用。

## 兼容：P03 瞄准。
func raycast_block(origin: Vector3, dir: Vector3, max_dist: float = 60.0) -> Dictionary:
	if grid == null:
		return {"hit": false}
	return grid.raycast_block(origin, dir, max_dist)


## 兼容：P04 一键破坏单格（旧写法，不带进度）。
## 新代码请用 `grid.apply_mining([cell], power, miner)`。
func break_block(pos: Vector3i) -> bool:
	if grid == null:
		return false
	grid.apply_mining([pos], {&"default": 9999.0})
	return not grid.has_block(pos)


## 兼容：L04 旧的通行判定。
func is_blocked_at(center: Vector3, half_w: float, half_d: float,
		y_min: float, y_max: float) -> bool:
	if grid == null:
		return false
	return grid.is_blocked_at(center, half_w, half_d, y_min, y_max)


## 兼容：旧矿车会调它做剖面隐藏。现在剖面由渲染层处理，这里保留空实现避免报错。
func update_cutaway(_center: Vector3, _half_depth: float) -> void:
	pass


## 兼容：旧测试读它。
func hidden_count() -> int:
	return 0

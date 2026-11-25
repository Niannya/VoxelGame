## L04 矿车：自动沿 -Z 前进，被挡住就停，并**说明原因**。
##
## 与旧版 mine_cart.gd 的区别：不直接摸世界内部，只查两个接口
## （L01 的 solid_cells_in、L03 的 is_track_ready），所以接 L03/L05 时不用改这里。
##
## 给其他模块的约定：
## - 只读 `stop_reason`；变化听 `cart_blocked` / `cart_resumed`。
## - 里程只通过 LevelState.advance_to() 上报，别的模块不要自己算进度。
## - `deck_half_width` / `deck_half_depth` 是玩家侧 player.gd 依赖的平台尺寸，改名会断。
class_name LevelCartController
extends AnimatableBody3D

enum StopReason { NONE, ROCK, RAIL, DEBRIS, DESCEND }

signal cart_blocked(reason: StopReason)
signal cart_resumed()
signal cart_moved(z: float)

@export var grid_path: NodePath
@export var track_path: NodePath
@export var state_path: NodePath

## 行进速度（格/秒）。需求案首测 1 格/秒。
@export var speed: float = 1.0
## 车体半宽 / 半深（格），玩家侧站台判定也读它。
@export var deck_half_width: float = 1.4
@export var deck_half_depth: float = 1.8
## 通行高度（格）：车身扫过的高度范围。
@export var clearance_height: float = 1.45
## 是否要求轨道就绪（接入 L03 后开）。
@export var require_track: bool = true
## 是否把 LevelState 的里程原点绑到自己的出生位置（开局调一次）。
@export var bind_progress_origin: bool = true

var stop_reason: StopReason = StopReason.NONE

var _grid: LevelVoxelGrid
var _track: LevelTrackService
var _state: LevelState
var _blocking: Array = []


func _ready() -> void:
	_grid = get_node_or_null(grid_path) as LevelVoxelGrid
	_track = get_node_or_null(track_path) as LevelTrackService
	_state = get_node_or_null(state_path) as LevelState
	if _grid == null:
		push_warning("LevelCartController: 找不到 grid_path")
	# 需求案"每局从累计推进 0 格开始"：把里程原点绑在矿车出生点
	if bind_progress_origin and _state != null:
		_state.set_origin(global_position.z)


## 当前挡路的方块（UI 标红用）。
func blocking_cells() -> Array:
	return _blocking.duplicate()


func current_reason_text() -> String:
	match stop_reason:
		StopReason.ROCK:
			return "前方有岩块"
		StopReason.RAIL:
			return "轨道未就绪"
		StopReason.DEBRIS:
			return "落石堵路"
		StopReason.DESCEND:
			return "等待下潜"
		_:
			return ""


func _physics_process(delta: float) -> void:
	if _grid == null:
		return

	var step := speed * delta
	var next := global_position + Vector3(0, 0, -step)
	var reason := _check_ahead(next)

	if reason != StopReason.NONE:
		_blocking = _grid.solid_cells_in(next, deck_half_width, deck_half_depth,
			next.y + 0.05, next.y + clearance_height)
		if reason != stop_reason:
			stop_reason = reason
			cart_blocked.emit(reason)
		return

	if stop_reason != StopReason.NONE:
		stop_reason = StopReason.NONE
		_blocking = []
		cart_resumed.emit()

	global_position = next
	_register_progress()


func _check_ahead(next: Vector3) -> StopReason:
	var solid := _grid.solid_cells_in(next, deck_half_width, deck_half_depth,
		next.y + 0.05, next.y + clearance_height)
	if not solid.is_empty():
		return StopReason.ROCK

	if require_track and _track != null:
		if not _track.is_track_ready(next, deck_half_width, deck_half_depth):
			return StopReason.RAIL
	return StopReason.NONE


func _register_progress() -> void:
	if _state == null:
		return
	_state.advance_to(global_position.z)
	cart_moved.emit(global_position.z)

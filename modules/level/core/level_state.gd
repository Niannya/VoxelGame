## L02 深度与推进：本局深度/里程的唯一事实来源。
##
## 需求案口径：
## - 第 d 层长度 = 50 × d 格；下潜点（累计推进）= 25 × d × (d + 1)。
## - 推进只看矿车沿主路到达的**最远**位置；倒车、离车探索不算。
## - 跨过门槛才算下潜一次，停在边界反复穿越不重复下潜。
##
## 给其他模块的约定：
## - 只读：`depth`、`progress`、`depth_at_z()`、`depth_at_progress()`。
## - 写入只有一个入口：`advance_to(z)`，**只有 L04 矿车可以调**。
## - 别的模块不许直接改 depth / progress，需要知道变化就听信号。
class_name LevelState
extends Node

## 深度变了（下潜完成）。
signal depth_changed(depth: int, progress: int)
## 累计推进变了（每前进一格发一次）。
signal progress_changed(progress: int, total: int)
## 即将下潜（过渡动画/加载用）。
signal descend_started(from_depth: int, to_depth: int)

## 每层基础长度；第 d 层长度 = STEP × d。
const FLOOR_LENGTH_STEP := 50

## progress = 0 对应的世界 z。矿车往 -Z 开，所以 progress = origin_z - z。
@export var route_origin_z: float = 6.0

var depth: int = 1
var progress: int = 0
var farthest_z: float = 1e9


func _ready() -> void:
	farthest_z = route_origin_z


## 第 d 层的主路长度。
func floor_length(d: int = -1) -> int:
	var layer := depth if d < 0 else d
	return FLOOR_LENGTH_STEP * layer


## 进入第 d+1 层所需的累计推进。
func descent_point(d: int = -1) -> int:
	var layer := depth if d < 0 else d
	return FLOOR_LENGTH_STEP * layer * (layer + 1) / 2


## 本层已走的格数（UI 显示 "37 / 100"）。
func floor_progress() -> int:
	var base := descent_point(depth - 1) if depth > 1 else 0
	return progress - base


## 某段累计推进属于第几层。
func depth_at_progress(p: int) -> int:
	var layer := 1
	while p >= descent_point(layer):
		layer += 1
	return layer


## 世界 z 属于第几层（生成时给格子打深度标）。
func depth_at_z(z: float) -> int:
	return depth_at_progress(progress_from_z(z))


func progress_from_z(z: float) -> int:
	return maxi(0, floori(route_origin_z - z))


## 唯一的写入入口：报告矿车当前 z。
## 只有比历史最远位置更靠前才累计；倒退不扣里程。
func advance_to(z: float) -> void:
	if z >= farthest_z - 0.0001:
		return
	farthest_z = z
	var new_progress := progress_from_z(z)
	if new_progress <= progress:
		return
	progress = new_progress
	progress_changed.emit(progress, floor_length())
	_check_descend()


## 绑定"0 格"对应的世界 z（矿车出生点）。只由 L04 在开局调一次。
## 需求案：每局从累计推进 0 格开始，所以原点必须跟着矿车走，不能写死。
func set_origin(z: float) -> void:
	route_origin_z = z
	farthest_z = z
	progress = 0
	progress_changed.emit(progress, floor_length())


func _check_descend() -> void:
	while progress >= descent_point():
		var from := depth
		descend_started.emit(from, from + 1)
		depth += 1
		depth_changed.emit(depth, progress)


## 存档 / 读档 / 测试用。
func reset(to_depth: int = 1, to_progress: int = 0) -> void:
	depth = maxi(1, to_depth)
	progress = maxi(0, to_progress)
	farthest_z = route_origin_z - float(progress)
	depth_changed.emit(depth, progress)
	progress_changed.emit(progress, floor_length())

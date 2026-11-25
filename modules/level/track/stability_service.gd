## L03 稳定度（骨架版：数值与衰减已按需求案，柱子覆盖只做朴素的方形标记）。
##
## 已实现：按主路每 5 格分段、开挖后按深度衰减、柱子加 20 点、30 点预警、归零坍塌信号。
## 未实现（见 Docs/Dev/关卡缺口清单.md）：未覆盖比例按"已开挖且需保护格"精确计算、
## 丧尸聚集扣减、热武器开火扣减、落石实体与清理流程。
##
## 给其他模块的约定：只读 `value_of()` 和听信号；改数值只能通过 `add_pillar()`。
class_name LevelStabilityService
extends Node

signal segment_activated(segment: int)
signal segment_critical(segment: int, value: float)
signal segment_collapsed(segment: int)

@export var grid_path: NodePath
@export var state_path: NodePath
## 每个结算段的长度（主路格数）。
@export var segment_length: int = 5
@export var max_value: float = 100.0
@export var critical_threshold: float = 30.0

var _grid: LevelVoxelGrid
var _state: LevelState
var _segments: Dictionary = {}  # int -> {value, active, cleared, covered, collapsed}


func _ready() -> void:
	_grid = get_node_or_null(grid_path) as LevelVoxelGrid
	_state = get_node_or_null(state_path) as LevelState
	if _grid == null:
		push_warning("LevelStabilityService: 找不到 grid_path")
		return
	_grid.cell_cleared.connect(_on_cell_cleared)


func segment_of_z(z: float) -> int:
	return floori(z / float(maxi(segment_length, 1)))


func value_of(segment: int) -> float:
	var s: Dictionary = _segments.get(segment, {})
	return float(s.get("value", max_value))


func is_active(segment: int) -> bool:
	var s: Dictionary = _segments.get(segment, {})
	return bool(s.get("active", false))


## 每秒基础衰减：第 d 层 = 2 + 0.5 × (d − 1)。
func decay_rate(depth: int) -> float:
	return 2.0 + 0.5 * float(depth - 1)


## 单根柱子的覆盖边长：每深两层减 1，最低 1。
func pillar_side(depth: int) -> int:
	return maxi(1, 6 - floori(float(depth - 1) / 2.0))


## 施工搭柱。返回是否带来了新的有效覆盖（重复覆盖不加分）。
func add_pillar(cell: Vector3i) -> bool:
	var segment := segment_of_z(float(cell.z))
	var s := _segment(segment)
	var side := pillar_side(_depth_now())
	var half := (side - 1) / 2
	var gained := 0
	for dx in range(-half, half + 1):
		for dz in range(-half, half + 1):
			var key := Vector2i(cell.x + dx, cell.z + dz)
			if s["covered"].has(key):
				continue
			s["covered"][key] = true
			gained += 1
	if gained == 0:
		return false
	s["value"] = minf(float(s["value"]) + 20.0, max_value + 20.0 * float(s["pillars"] + 1))
	s["pillars"] = int(s["pillars"]) + 1
	return true


## 未覆盖比例（0 = 全护住，1 = 完全没护）。
func coverage_ratio(segment: int) -> float:
	var s: Dictionary = _segments.get(segment, {})
	var cleared := int(s.get("cleared", 0))
	if cleared <= 0:
		return 0.0
	var covered := mini(int(s["covered"].size()), cleared)
	return clampf(1.0 - float(covered) / float(cleared), 0.0, 1.0)


func _process(delta: float) -> void:
	for segment in _segments:
		var s: Dictionary = _segments[segment]
		if not bool(s["active"]) or bool(s["collapsed"]):
			continue
		var depth: int = _depth_now()
		var drain: float = decay_rate(depth) * coverage_ratio(segment) * delta
		if drain <= 0.0:
			continue
		s["value"] = maxf(float(s["value"]) - drain, 0.0)
		var value := float(s["value"])
		if value <= critical_threshold and not bool(s["warned"]):
			s["warned"] = true
			segment_critical.emit(segment, value)
		if value <= 0.0:
			s["collapsed"] = true
			segment_collapsed.emit(segment)


func _on_cell_cleared(cell: Vector3i) -> void:
	var segment := segment_of_z(float(cell.z))
	var s := _segment(segment)
	s["cleared"] = int(s["cleared"]) + 1
	if not bool(s["active"]):
		s["active"] = true
		segment_activated.emit(segment)


func _segment(segment: int) -> Dictionary:
	if not _segments.has(segment):
		_segments[segment] = {
			"value": max_value,
			"active": false,
			"cleared": 0,
			"covered": {},
			"pillars": 0,
			"warned": false,
			"collapsed": false,
		}
	return _segments[segment]


func _depth_now() -> int:
	return 1 if _state == null else _state.depth

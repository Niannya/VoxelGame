## L03 轨道（简化版，接口是最终形态，规则后续补）。
##
## 已实现：主路清岩后自动铺轨（带一点施工延迟，让矿车出现"等轨"的停车原因）、
## 已铺轨道可回收、给 L04 提供 `is_track_ready()` 查询。
## 未实现（见 Docs/Dev/关卡缺口清单.md）：拆轨产木、自动合成柱、一次性回收记账。
##
## 给其他模块的约定：矿车**只查** is_track_ready()，不要读 _tracks。
class_name LevelTrackService
extends Node

signal track_placed(cell: Vector3i)
signal track_reclaimed(cell: Vector3i)

@export var grid_path: NodePath
## 主路半宽（格）：只有 |x| <= 该值的格子算"矿车线路"。
@export var route_half_width_cells: int = 1
## 清岩到铺好轨的施工延迟（秒）。
@export var build_delay: float = 0.25
## 开局是否给起始空腔铺好旧轨（L03 的"车尾预留可回收旧轨"）。
@export var seed_initial_route: bool = true
## 起始空腔的 z 范围（含端点）。
@export var initial_route_z_min: int = 0
@export var initial_route_z_max: int = 6

var _grid: LevelVoxelGrid
var _tracks: Dictionary = {}   # Vector3i -> true
var _pending: Dictionary = {}  # Vector3i -> 剩余秒数


func _ready() -> void:
	_grid = get_node_or_null(grid_path) as LevelVoxelGrid
	if _grid == null:
		push_warning("LevelTrackService: 找不到 grid_path")
		return
	_grid.cell_cleared.connect(_on_cell_cleared)
	if seed_initial_route:
		_seed_initial()


func _process(delta: float) -> void:
	if _pending.is_empty():
		return
	var ready_cells: Array = []
	for cell in _pending:
		_pending[cell] -= delta
		if _pending[cell] <= 0.0:
			ready_cells.append(cell)
	for cell in ready_cells:
		_pending.erase(cell)
		place_track(cell)


func is_on_route(cell: Vector3i) -> bool:
	return absi(cell.x) <= route_half_width_cells


func place_track(cell: Vector3i) -> void:
	if _tracks.has(cell):
		return
	_tracks[cell] = true
	track_placed.emit(cell)


## L04 通行判定：车身覆盖的每一列在 y≈0 都要有轨。
func is_track_ready(center: Vector3, half_w: float, half_d: float) -> bool:
	for i in _span(center.x - half_w, center.x + half_w):
		for k in _span(center.z - half_d, center.z + half_d):
			if not _tracks.has(Vector3i(i, 0, k)):
				return false
	return true


## 车尾整个通过后才能拆；返回是否成功。
func reclaim(cell: Vector3i) -> bool:
	if not _tracks.has(cell):
		return false
	_tracks.erase(cell)
	track_reclaimed.emit(cell)
	return true


func track_count() -> int:
	return _tracks.size()


func _seed_initial() -> void:
	for z in range(initial_route_z_min, initial_route_z_max + 1):
		for x in range(-route_half_width_cells, route_half_width_cells + 1):
			place_track(Vector3i(x, 0, z))


func _on_cell_cleared(cell: Vector3i) -> void:
	if not is_on_route(cell):
		return
	if _tracks.has(cell) or _pending.has(cell):
		return
	if build_delay <= 0.0:
		place_track(cell)
	else:
		_pending[cell] = build_delay


func _span(a: float, b: float) -> Array[int]:
	var out: Array[int] = []
	for v in range(floori(a + 0.5), floori(b - 0.0001 + 0.5) + 1):
		out.append(v)
	return out

## L01 表现层：只订阅 LevelVoxelGrid，不反过来改它。
##
## 换皮/换 Mesh 全走 LevelArtTheme，留空的槽位用程序占位，玩法不受影响。
## 这层可以整个删掉跑无头测试，网格逻辑照常工作——这就是拆开它的意义。
class_name LevelVoxelRenderer
extends Node3D

## 目标网格。
@export var grid_path: NodePath
## 美术主题，留空则全部用程序占位。
@export var art: LevelArtTheme = null
## 方块尺寸（1 格 = 1.0）。
@export var block_size: float = 1.0
## 没填美术时用的兜底颜色，按方块 id 取。
@export var fallback_colors: Dictionary = {
	&"stone_a": Color(0.335, 0.330, 0.355),
	&"stone_b": Color(0.272, 0.267, 0.296),
	&"bedrock": Color(0.16, 0.16, 0.19),
}

var _hidden := Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3(0, -9999, 0))

var _grid: LevelVoxelGrid
var _solid: Dictionary = {}     # id -> MultiMesh
var _instances: Dictionary = {} # id -> MultiMeshInstance3D
var _slots: Dictionary = {}     # Vector3i -> {"id": StringName, "index": int}
var _crack_root: Node3D
var _crack_layers: Dictionary = {} # stage -> MultiMeshInstance3D
var _damaged: Dictionary = {}      # Vector3i -> stage
## 每格当前的显示状态。MultiMesh 的实例变换在无头模式下不回读，
## 所以逻辑侧自己记一份，测试和 UI 都读这里（见 display_state）。
var _display: Dictionary = {}      # Vector3i -> {"visible": bool, "scale": float, "stage": int}
## 重建合并标记：批量新增格（例如换层重新生成）时只重建一次，避免 O(n²)。
var _rebuild_queued := false
## 已执行的完整重建次数（诊断 / 测试用）。
var rebuild_count: int = 0


func _ready() -> void:
	_grid = get_node_or_null(grid_path) as LevelVoxelGrid
	if _grid == null:
		push_warning("LevelVoxelRenderer: 找不到 grid_path")
		return
	_grid.cell_changed.connect(_on_cell_changed)
	_grid.block_damaged.connect(_on_block_damaged)
	_grid.block_broken.connect(_on_block_broken)
	rebuild()
	_report_missing_art()


## 查询某格当前显示状态（无头测试用；也方便 UI 判断"这格露着吗"）。
## 返回 {visible: bool, scale: float, stage: int}；未登记的格视为不可见。
func display_state(cell: Vector3i) -> Dictionary:
	return _display.get(cell, {"visible": false, "scale": 0.0, "stage": 0})


## 一次性重建全部实例（生成完、读档后、换主题后调用）。
func rebuild() -> void:
	_rebuild_queued = false
	rebuild_count += 1
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_solid.clear()
	_instances.clear()
	_slots.clear()
	_damaged.clear()
	_display.clear()
	_crack_layers.clear()
	if _grid == null:
		return

	_crack_root = Node3D.new()
	_crack_root.name = "Cracks"
	add_child(_crack_root)

	var groups: Dictionary = _grid.cells_by_id()
	for id in groups:
		var positions: Array = groups[id]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _mesh_for(id)
		mm.instance_count = positions.size()

		for idx in positions.size():
			var pos: Vector3i = positions[idx]
			mm.set_instance_transform(idx, _transform_for(pos))
			_slots[pos] = {"id": id, "index": idx}
			_display[pos] = {"visible": true, "scale": 1.0, "stage": 0}

		var node := MultiMeshInstance3D.new()
		node.name = "Solid_" + String(id)
		node.multimesh = mm
		# 美术给了材质就盖上去：方块 mesh 千差万别，逐实例 overrive 比改 mesh 可靠
		var theme_mat := _theme_material(id)
		if theme_mat != null:
			node.material_override = theme_mat
		add_child(node)
		_solid[id] = mm
		_instances[id] = node


# ---------------------------------------------------------------- 事件

func _on_cell_changed(cell: Vector3i) -> void:
	var slot: Dictionary = _slots.get(cell, {})
	if _grid.has_block(cell):
		var id := _grid.block_id_at(cell)
		if slot.is_empty():
			# 运行期新增格：合并成一次重建，避免批量生成时每个格子都全量重建
			_queue_rebuild()
			return
		var mm: MultiMesh = _solid.get(id)
		if mm == null:
			_queue_rebuild()
			return
		if slot["id"] != id:
			_queue_rebuild()
			return
		mm.set_instance_transform(slot["index"], _transform_for(cell))
		_display[cell] = {"visible": true, "scale": 1.0, "stage": int(_damaged.get(cell, 0))}
		return

	# 被挖掉：藏掉实例，清掉裂纹
	if not slot.is_empty():
		var mm: MultiMesh = _solid.get(slot["id"])
		if mm != null:
			mm.set_instance_transform(slot["index"], _hidden)
		_slots.erase(cell)
	_display[cell] = {"visible": false, "scale": 0.0, "stage": 0}
	_damaged.erase(cell)
	_refresh_cracks()


func _on_block_damaged(cell: Vector3i, ratio: float) -> void:
	var stages := 3
	if art != null and not art.crack_meshes.is_empty():
		stages = art.crack_meshes.size()
	var stage := clampi(ceili(ratio * float(stages)), 1, stages)
	if _damaged.get(cell, 0) == stage:
		return
	_damaged[cell] = stage

	if art != null and not art.crack_meshes.is_empty():
		_refresh_cracks()
		_display[cell] = {"visible": true, "scale": 1.0, "stage": stage}
		return

	# 没给裂纹资产：用轻微缩放做占位反馈
	var slot: Dictionary = _slots.get(cell, {})
	if slot.is_empty():
		return
	var mm: MultiMesh = _solid.get(slot["id"])
	if mm == null:
		return
	var shrink := 1.0 - 0.06 * float(stage)
	mm.set_instance_transform(slot["index"],
		Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * shrink), _cell_center(cell)))
	_display[cell] = {"visible": true, "scale": shrink, "stage": stage}


## 把全量重建合并到本帧末尾（同一帧内多次请求只做一次）。
func _queue_rebuild() -> void:
	if _rebuild_queued:
		return
	_rebuild_queued = true
	rebuild.call_deferred()


func _on_block_broken(cell: Vector3i, _block_id: StringName, _drops: Array) -> void:
	_damaged.erase(cell)
	if art != null and art.debris_scene != null:
		var fx: Node = art.debris_scene.instantiate()
		if fx is Node3D:
			(fx as Node3D).position = _cell_center(cell)
		add_child(fx)
	_refresh_cracks()


# ---------------------------------------------------------------- 裂纹叠层

func _refresh_cracks() -> void:
	if _crack_root == null:
		return
	for child in _crack_root.get_children():
		child.queue_free()
	_crack_layers.clear()
	if art == null or art.crack_meshes.is_empty():
		return

	var by_stage: Dictionary = {}
	for cell in _damaged:
		var stage: int = _damaged[cell]
		if not by_stage.has(stage):
			by_stage[stage] = []
		by_stage[stage].append(cell)

	for stage in by_stage:
		var mesh: Mesh = art.crack_meshes[mini(stage, art.crack_meshes.size()) - 1]
		if mesh == null:
			continue
		var cells: Array = by_stage[stage]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = cells.size()
		for idx in cells.size():
			mm.set_instance_transform(idx, _transform_for(cells[idx]))

		var node := MultiMeshInstance3D.new()
		node.name = "Crack_%d" % stage
		node.multimesh = mm
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_crack_root.add_child(node)
		_crack_layers[stage] = node


# ---------------------------------------------------------------- 资产解析

func _mesh_for(id: StringName) -> Mesh:
	if art != null and art.block_meshes.has(id) and art.block_meshes[id] != null:
		return art.block_meshes[id]
	var box := BoxMesh.new()
	box.size = Vector3(block_size, block_size, block_size)
	box.material = _material_for(id)
	return box


func _material_for(id: StringName) -> Material:
	var theme_mat := _theme_material(id)
	if theme_mat != null:
		return theme_mat
	var mat := StandardMaterial3D.new()
	mat.albedo_color = fallback_colors.get(id, Color(0.5, 0.5, 0.5))
	mat.roughness = 0.92
	mat.metallic = 0.05
	return mat


## 美术主题里给了这个方块的材质就返回，否则 null。
func _theme_material(id: StringName) -> Material:
	if art != null and art.block_materials.has(id):
		var mat: Material = art.block_materials[id]
		if mat != null:
			return mat
	return null


func _cell_center(cell: Vector3i) -> Vector3:
	return Vector3(cell) * block_size


func _transform_for(cell: Vector3i) -> Transform3D:
	return Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * block_size), _cell_center(cell))


func _report_missing_art() -> void:
	if art == null:
		return
	var missing := art.missing_block_slots()
	if not missing.is_empty():
		push_warning("美术槽位未填（先用占位）: %s" % str(missing))

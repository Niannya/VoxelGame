extends Node3D
## 挖矿交互：每个玩家各自高亮「前方一定距离内」的矿块，按自己的挖掘键挖掉。
## 鼠标不参与瞄准，只留给 UI。

const LINE_COLOR := Color(1.0, 0.88, 0.32, 0.95)
const FILL_COLOR := Color(1.0, 0.78, 0.20, 0.18)
## 每个玩家最多同时亮起几个（一列 = 通道高度）
const OUTLINES_PER_PLAYER := 6

@export var player_paths: Array[NodePath] = []
@export var world_path: NodePath
@export var hud_path: NodePath
## 朝前最多找几格。只够到眼前，想挖就得走到车头附近。
@export var reach_cells: int = 2

var total_broken: int = 0
var broken_by_type: Dictionary = {}

var _players: Array = []
var _world: Node3D
var _hud: CanvasLayer
var _block_size := Vector3.ONE
var _line_mat: StandardMaterial3D
var _fill_mat: StandardMaterial3D

var _outlines: Array = []     # [玩家下标] -> Array[Node3D]
var _targets: Array = []      # [玩家下标] -> Array[Vector3i]
var _was_pressed: Array = []  # [玩家下标] -> bool


func _ready() -> void:
	_world = get_node_or_null(world_path)
	_hud = get_node_or_null(hud_path)
	if _world and _world.has_signal("block_broken"):
		_world.block_broken.connect(_on_block_broken)
	if _world and _world.has_method("block_size"):
		_block_size = _world.block_size()

	for p in player_paths:
		var node := get_node_or_null(p)
		if node == null:
			continue
		_players.append(node)
		_targets.append([])
		_was_pressed.append(false)
		_outlines.append(_build_outline_set(_players.size() - 1))

	# HUD 的 @onready 变量此时可能还没赋值，延后一帧再刷新
	_refresh_hud.call_deferred()


func _process(_delta: float) -> void:
	for i in _players.size():
		_update_player(i)


func targets_of(index: int) -> Array:
	return _targets[index] if index < _targets.size() else []


# ---------------------------------------------------------------- 目标选取

func _update_player(index: int) -> void:
	var player: Node3D = _players[index]
	var mine_action: String = player.action_prefix + "_mine"
	var pressed := Input.is_action_pressed(mine_action)

	if player.is_down:
		_show(index, [])
		_was_pressed[index] = pressed
		return

	var facing := Vector3.FORWARD
	if player.has_method("facing_dir"):
		facing = player.facing_dir()

	var found: Array[Vector3i] = []
	if _world != null:
		found = _world.targets_in_front(player.global_position, facing, reach_cells)
	_targets[index] = found
	_show(index, found)

	# 自己记录上一帧状态：比 is_action_just_pressed 稳，不会因帧序漏掉一次按下
	if pressed and not _was_pressed[index]:
		_mine(index)
	_was_pressed[index] = pressed


func _mine(index: int) -> void:
	var list: Array = _targets[index]
	if list.is_empty():
		return
	for pos in list.duplicate():
		_world.break_block(pos)
	_update_player(index)


# ---------------------------------------------------------------- 视觉

func _show(index: int, list: Array) -> void:
	var holders: Array = _outlines[index]
	for n in holders.size():
		var holder: Node3D = holders[n]
		if n < list.size():
			holder.visible = true
			holder.global_position = Vector3(list[n]) * _block_size
		else:
			holder.visible = false


func _build_outline_set(index: int) -> Array:
	if _line_mat == null:
		_line_mat = StandardMaterial3D.new()
		_line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_line_mat.albedo_color = LINE_COLOR
		_line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_line_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD

		_fill_mat = StandardMaterial3D.new()
		_fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_fill_mat.albedo_color = FILL_COLOR
		_fill_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_fill_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_fill_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var wire := ImmediateMesh.new()
	wire.surface_begin(Mesh.PRIMITIVE_LINES, _line_mat)
	var h := 0.5
	var c := [
		Vector3(-h, -h, -h), Vector3(h, -h, -h), Vector3(h, -h, h), Vector3(-h, -h, h),
		Vector3(-h, h, -h), Vector3(h, h, -h), Vector3(h, h, h), Vector3(-h, h, h),
	]
	for e in [[0, 1], [1, 2], [2, 3], [3, 0], [4, 5], [5, 6], [6, 7], [7, 4], [0, 4], [1, 5], [2, 6], [3, 7]]:
		wire.surface_add_vertex(c[e[0]])
		wire.surface_add_vertex(c[e[1]])
	wire.surface_end()

	var holders: Array = []
	for n in OUTLINES_PER_PLAYER:
		var holder := Node3D.new()
		holder.name = "P%dOutline%d" % [index + 1, n]
		holder.scale = _block_size * 1.04
		holder.visible = false
		add_child(holder)

		var lines := MeshInstance3D.new()
		lines.mesh = wire
		lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(lines)

		var box := BoxMesh.new()
		box.size = Vector3.ONE
		box.material = _fill_mat
		var fill := MeshInstance3D.new()
		fill.mesh = box
		fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(fill)

		holders.append(holder)
	return holders


# ---------------------------------------------------------------- 计数

func _on_block_broken(pos: Vector3i, key: String) -> void:
	total_broken += 1
	broken_by_type[key] = broken_by_type.get(key, 0) + 1
	_spawn_burst(pos, key)
	_refresh_hud()


func _refresh_hud() -> void:
	if _hud and _hud.has_method("update_counts"):
		_hud.update_counts(total_broken, broken_by_type)


func _spawn_burst(pos: Vector3i, key: String) -> void:
	var p := CPUParticles3D.new()
	p.name = "Burst"
	p.one_shot = true
	p.emitting = true
	p.amount = 12
	p.lifetime = 0.55
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 4.5
	p.gravity = Vector3(0, -14.0, 0)
	p.scale_amount_min = 0.06
	p.scale_amount_max = 0.15

	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.12
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = _color_for(key)
	mesh.material = mat
	p.mesh = mesh

	add_child(p)
	p.global_position = Vector3(pos) * _block_size

	await get_tree().create_timer(1.2).timeout
	if is_instance_valid(p):
		p.queue_free()


func _color_for(key: String) -> Color:
	match key:
		"gold":
			return Color(0.95, 0.72, 0.20)
		"quartz":
			return Color(0.90, 0.91, 0.95)
		"diamond":
			return Color(0.45, 0.85, 0.95)
		"emerald":
			return Color(0.30, 0.78, 0.50)
		_:
			return Color(0.45, 0.44, 0.48)

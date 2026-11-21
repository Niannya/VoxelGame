extends Node3D
## 挖矿交互：鼠标射线拾取方块 → 描边高亮 → 按住左键蓄力 → 破坏并计数。
## 射线走体素 DDA，不依赖碰撞体，所以能精确选中方块本身。

const HOVER_LINE := Color(1.0, 0.88, 0.32, 0.95)
const CHARGE_LINE := Color(1.0, 0.32, 0.12, 1.0)
const HOVER_FILL := Color(1.0, 0.78, 0.20, 0.26)
const CHARGE_FILL := Color(1.0, 0.24, 0.09, 0.40)

@export var camera_path: NodePath
@export var world_path: NodePath
@export var hud_path: NodePath
@export var max_distance: float = 18.0
@export var break_time: float = 0.55

var total_broken: int = 0
var broken_by_type: Dictionary = {}

var _camera: Camera3D
var _world: Node3D
var _hud: CanvasLayer

var _outline: MeshInstance3D
var _outline_mat: StandardMaterial3D
var _fill: MeshInstance3D
var _fill_mat: StandardMaterial3D

var _has_hover := false
var _hovered := Vector3i.ZERO
var _charging := false
var _charge := 0.0

## 供自动化测试指定瞄准点；保持 (-1,-1) 表示跟随真实鼠标
var aim_override := Vector2(-1, -1)


func _ready() -> void:
	_camera = get_node_or_null(camera_path) as Camera3D
	_world = get_node_or_null(world_path)
	_hud = get_node_or_null(hud_path)

	if _world and _world.has_signal("block_broken"):
		_world.block_broken.connect(_on_block_broken)

	_build_outline()
	# HUD 的 @onready 变量此时可能还没赋值，延后一帧再刷新
	_refresh_hud.call_deferred()


func _process(delta: float) -> void:
	var aim := aim_override if aim_override.x >= 0.0 else get_viewport().get_mouse_position()
	update_hover_at(aim)
	_update_charge(delta)


# ---------------------------------------------------------------- 悬停

func update_hover_at(screen_pos: Vector2) -> void:
	if _camera == null or _world == null:
		return

	var origin := _camera.project_ray_origin(screen_pos)
	var dir := _camera.project_ray_normal(screen_pos)
	var res: Dictionary = _world.raycast_block(origin, dir, max_distance)

	if res.get("hit", false):
		var pos: Vector3i = res["pos"]
		if _charging and pos != _hovered:
			_reset_charge()
		_has_hover = true
		_hovered = pos
		_outline.global_position = Vector3(pos)
		_fill.global_position = Vector3(pos)
		_outline.visible = true
		_fill.visible = true
	else:
		_has_hover = false
		_outline.visible = false
		_fill.visible = false
		_reset_charge()


func hovered_block() -> Vector3i:
	return _hovered


func has_hover() -> bool:
	return _has_hover


# ---------------------------------------------------------------- 蓄力 / 破坏

func _update_charge(delta: float) -> void:
	if not Input.is_action_pressed("mine") or not _has_hover:
		_reset_charge()
		return

	_charging = true
	_charge += delta / maxf(break_time, 0.01)
	_apply_tint()

	if _charge >= 1.0:
		var pos := _hovered
		_reset_charge()
		if _world.break_block(pos):
			# 破完后立刻重算悬停，避免描边停在已消失的方块上
			var aim := aim_override if aim_override.x >= 0.0 else get_viewport().get_mouse_position()
			update_hover_at(aim)


func _reset_charge() -> void:
	_charging = false
	_charge = 0.0
	_apply_tint()


func _apply_tint() -> void:
	var t := clampf(_charge, 0.0, 1.0)
	_outline_mat.albedo_color = HOVER_LINE.lerp(CHARGE_LINE, t)
	_fill_mat.albedo_color = HOVER_FILL.lerp(CHARGE_FILL, t)


func _on_block_broken(pos: Vector3i, key: String) -> void:
	total_broken += 1
	broken_by_type[key] = broken_by_type.get(key, 0) + 1
	_spawn_burst(pos, key)
	_refresh_hud()


func _refresh_hud() -> void:
	if _hud and _hud.has_method("update_counts"):
		_hud.update_counts(total_broken, broken_by_type)


# ---------------------------------------------------------------- 视觉

func _build_outline() -> void:
	_outline_mat = StandardMaterial3D.new()
	_outline_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_outline_mat.albedo_color = HOVER_LINE
	_outline_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_outline_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD

	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES, _outline_mat)
	var h := 0.5
	var c := [
		Vector3(-h, -h, -h), Vector3(h, -h, -h), Vector3(h, -h, h), Vector3(-h, -h, h),
		Vector3(-h, h, -h), Vector3(h, h, -h), Vector3(h, h, h), Vector3(-h, h, h),
	]
	for e in [[0, 1], [1, 2], [2, 3], [3, 0], [4, 5], [5, 6], [6, 7], [7, 4], [0, 4], [1, 5], [2, 6], [3, 7]]:
		im.surface_add_vertex(c[e[0]])
		im.surface_add_vertex(c[e[1]])
	im.surface_end()

	_outline = MeshInstance3D.new()
	_outline.name = "HoverOutline"
	_outline.mesh = im
	_outline.scale = Vector3.ONE * 1.05
	_outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_outline.visible = false
	add_child(_outline)

	# 描边内侧再叠一层极淡的填充，俯视角下更容易看清选中了哪一格
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 1.0, 1.0)
	_fill_mat = StandardMaterial3D.new()
	_fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fill_mat.albedo_color = HOVER_FILL
	_fill_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fill_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_fill_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	box.material = _fill_mat

	_fill = MeshInstance3D.new()
	_fill.name = "HoverFill"
	_fill.mesh = box
	_fill.scale = Vector3.ONE * 1.015
	_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fill.visible = false
	add_child(_fill)


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
	p.global_position = Vector3(pos)

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

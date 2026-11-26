extends Node3D
## 单特效预览台：只展示一条特效，随提交包发给对应 reviewer。
## 持续型特效进场景即出现；一次性特效按自身时长自动循环。
## 运行：解压后用 Godot 打开本目录，F5 即可。

@export var fx_id := "FX001"

var _ore: MeshInstance3D
var _monster: Node3D
var _player: Node3D
var _posts := []
var _wall: Node3D
var _occ_target: Node3D
var _item: Node3D

# 一次性特效的重播间隔（秒）
var _intervals := {
	"FX001": 1.6, "FX002": 2.2, "FX006": 1.8, "FX007": 1.9,
	"FX008": 2.4, "FX011": 1.5, "FX012": 1.5, "FX013": 1.5,
	"FX014": 2.4, "FX017": 2.0, "FX019": 2.6, "FX021": 3.4,
	"FX022": 3.6, "FX023": 3.2, "FX025": 2.6,
}


func _ready() -> void:
	# 自检：--id=FXxxx 可临时覆盖要预览的编号（CI 冒烟用，不进提交包逻辑）
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--id="):
			fx_id = a.substr(5)
	_build_stage()
	_fire()
	if "--id=" in " ".join(OS.get_cmdline_user_args()):
		await get_tree().create_timer(3.0).timeout
		get_tree().quit(0)
		return
	if _intervals.has(fx_id):
		var t := Timer.new()
		t.wait_time = float(_intervals[fx_id])
		t.autostart = true
		t.timeout.connect(_fire)
		add_child(t)


# ── 舞台 ─────────────────────────────────────────────────────
func _build_stage() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.055, 0.062, 0.078)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.52, 0.58, 0.74)
	env.ambient_light_energy = 0.5
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 38, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)

	var cam := Camera3D.new()
	cam.position = Vector3(0, 7.4, 6.6)
	cam.fov = 42.0
	add_child(cam)
	cam.look_at(Vector3(0, 0.4, 0.3))
	cam.current = true

	for x in 7:
		for z in 7:
			var tone := Color("#3A3D44") if (x + z) % 2 == 0 else Color("#33363C")
			_voxel(Vector3(1, 0.5, 1), tone, Vector3(float(x) - 3.0, -0.25, float(z) - 3.0))

	# 矿块（FX001 / FX002 / FX005 的载体）
	_ore = _voxel(Vector3(0.9, 0.9, 0.9), Color("#7A7C80"), Vector3(-1.5, 0.5, -0.7))
	_nugget(_ore, FxPalette.ORE_COPPER)

	# 怪物（FX011 / FX013 / FX014 的载体）
	_monster = Node3D.new()
	_monster.name = "Monster"
	_monster.position = Vector3(1.5, 0.0, 0.0)
	add_child(_monster)
	_voxel(Vector3(0.52, 0.46, 0.5), Color("#8C6BC8"), Vector3(0, 0.28, 0), _monster)
	_voxel(Vector3(0.4, 0.34, 0.4), Color("#9D7DD8"), Vector3(0, 0.68, 0), _monster)

	# 玩家（FX012 / FX024 / FX025 的载体）
	_player = Node3D.new()
	_player.name = "Player"
	_player.position = Vector3(0.0, 0.0, 1.4)
	add_child(_player)
	_voxel(Vector3(0.46, 0.5, 0.32), Color("#3D7BEA"), Vector3(0, 0.55, 0), _player)
	_voxel(Vector3(0.34, 0.34, 0.34), Color("#F0C49B"), Vector3(0, 0.95, 0), _player)
	_voxel(Vector3(0.5, 0.14, 0.5), Color("#E0A63C"), Vector3(0, 1.16, 0), _player)

	# 绳桩（FX009 / FX010）
	for i in 2:
		var post := _voxel(Vector3(0.18, 1.2, 0.18), Color("#6B5A45"),
			Vector3(-1.4 + float(i) * 2.8, 0.6, 2.2))
		_posts.append(post)

	# 遮挡演示墙 + 射线靶点（FX033 专用）
	_wall = Node3D.new()
	add_child(_wall)
	for i in 2:
		for h in 2:
			_voxel(Vector3(1, 1, 0.5), Color("#4B4F58"),
				Vector3(float(i) - 0.5, 0.5 + float(h), 0.9), _wall)
	_occ_target = Node3D.new()
	_occ_target.position = Vector3(-0.2, 0.0, 0.2)
	add_child(_occ_target)

	# 投炉 / 拾取的小物件（FX006 / FX007）
	_item = Node3D.new()
	_item.position = Vector3(2.6, 0.0, 1.2)
	add_child(_item)
	_voxel(Vector3(0.3, 0.9, 0.9), Color("#5C4A3D"), Vector3(0.8, 0.45, -0.6), _item)  # 炉子
	_voxel(Vector3(0.26, 0.26, 0.26), FxPalette.ORE_IRON, Vector3(0.8, 1.2, -0.2), _item)

	# 顶部 ID 铭牌
	var lbl := Label3D.new()
	lbl.text = fx_id
	lbl.font_size = 220
	lbl.pixel_size = 0.004
	lbl.position = Vector3(0, 2.6, -1.2)
	lbl.outline_size = 24
	add_child(lbl)


func _voxel(size: Vector3, color: Color, pos: Vector3, parent: Node3D = null) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	mesh.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	(parent if parent else self).add_child(mi)
	return mi


func _nugget(ore: MeshInstance3D, color: Color) -> void:
	for i in 4:
		var s := 0.16 + 0.06 * float(i % 2)
		var n := MeshInstance3D.new()
		var nm := BoxMesh.new()
		nm.size = Vector3(s, s, 0.06)
		var mm := StandardMaterial3D.new()
		mm.albedo_color = color
		mm.emission_enabled = true
		mm.emission = color
		nm.material = mm
		n.mesh = nm
		n.position = Vector3(-0.28 + 0.2 * float(i % 2), 0.3 - 0.16 * float(i / 2), 0.46)
		ore.add_child(n)


# ── 触发 ─────────────────────────────────────────────────────
func _fire() -> void:
	var dur: float = FxSpecs.get_spec(fx_id).get("duration", 0.0)
	match fx_id:
		"FX001":
			FxManager.play("FX001", _ore.global_position, {"target": _ore, "ore_color": FxPalette.ORE_COPPER})
		"FX002":
			FxManager.play("FX002", _ore.global_position, {"ore_color": FxPalette.ORE_COPPER, "ground_y": -0.5})
		"FX005":
			FxManager.attach("FX005", _ore)
		"FX006":
			FxManager.play("FX006", _item.global_position + Vector3(0, 0.2, 0))
		"FX007":
			FxManager.play("FX007", Vector3(3.4, 0.0, 0.6), {"mouth_offset": Vector3(0, 1.05, 0.6)})
		"FX008":
			FxManager.play("FX008", _player.global_position + Vector3(0, 0.8, 0), {"amount": 12})
		"FX009":
			FxManager.rope(_posts[0], _posts[1], false)
		"FX010":
			FxManager.rope(_posts[0], _posts[1], true)
		"FX011":
			FxManager.play("FX011", _monster.global_position + Vector3(0, 0.6, 0), {"normal": Vector3(0, 0.6, 1)})
		"FX012":
			FxManager.flash(_player, 0.9)
		"FX013":
			FxManager.flash_monster(_monster, 0.8)
		"FX014":
			if not is_instance_valid(_monster) or _monster.get_child_count() == 0:
				_monster = null
				_monster = Node3D.new()
				_monster.position = Vector3(1.5, 0.0, 0.0)
				add_child(_monster)
				_voxel(Vector3(0.52, 0.46, 0.5), Color("#8C6BC8"), Vector3(0, 0.28, 0), _monster)
				_voxel(Vector3(0.4, 0.34, 0.4), Color("#9D7DD8"), Vector3(0, 0.68, 0), _monster)
			FxManager.play("FX014", _monster.global_position,
				{"body": _monster, "tint": Color("#8C6BC8"), "ground_y": 0.02})
		"FX015":
			var p15 := FxManager.placement_preview(true)
			p15.set_target(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -0.2)))
			p15.set_valid(true)
		"FX016":
			var p16 := FxManager.placement_preview(false)
			p16.set_target(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -0.2)))
			p16.set_valid(false)
		"FX017":
			FxManager.play("FX017", Vector3(0.0, 0.0, -0.2), {"footprint": 1.6})
		"FX018":
			var d := FxManager.play("FX018", Vector3.ZERO, {"ceiling_height": 3.4}) as FxDustField
			if d:
				d.set_intensity(0.65)
		"FX019":
			FxManager.play("FX019", _player.global_position + Vector3(0.8, 0, -0.2))
		"FX020":
			var d20 := FxManager.screen("FX020") as FxScreenDanger
			d20.set_intensity(0.7)
			d20.set_critical(0.75)
		"FX021":
			FxManager.play("FX021", Vector3(0, 0, 0.4))
		"FX022":
			FxManager.play("FX022", Vector3(0, 0, -0.4), {"area": 3.6})
		"FX023":
			var t := FxManager.screen("FX023") as FxScreenTransition
			t.reset()
			t.play(1.0)
		"FX024":
			var r := FxManager.attach("FX024", _player, {"offset": Vector3(0, 0.02, 0)}) as FxRescue
			if r:
				var tw := create_tween()
				tw.tween_method(func(v):
					if is_instance_valid(r):
						r.set_progress(v), 0.0, 1.0, 2.0)
		"FX025":
			FxManager.play("FX025", _player.global_position, {"player": _player})
		"FX033":
			FxManager.wall_occluder([_wall], _occ_target, get_viewport().get_camera_3d())
	if fx_id == "FX014":
		# 死亡消散会把怪物缩没：下一次循环前重建由 _fire 内部处理
		pass

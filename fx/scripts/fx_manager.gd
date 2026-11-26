extends Node
## FxManager —— 全库唯一入口（Autoload）。
##
## 一次性的走 play()，贴身上的走 attach()，全屏的走 screen()，
## 绳索 / 放置预览 / 墙体淡化这类"系统型"各有专属构造函数。
## 所有一次性特效按 spec 里的 duration 自动释放，调用方不用管回收。
##
## 验收口径（表格"特效"行）：
##   · 触发 → 每个 func 的注释 + FxSpecs.DATA.trigger
##   · 持续时间 → FxSpecs.DATA.duration
##   · 范围 → FxSpecs.DATA.radius
##   · 清理条件 → FxSpecs.DATA.cleanup + 这里的 _auto_free

signal fx_started(id: StringName, node: Node)
signal fx_finished(id: StringName)

const SPECS := preload("res://fx/core/fx_specs.gd")

var _mining := preload("res://fx/builders/fx_mining.gd").new()
var _combat := preload("res://fx/builders/fx_combat.gd").new()
var _structure := preload("res://fx/builders/fx_structure.gd").new()
var _hazard := preload("res://fx/builders/fx_hazard.gd").new()
var _rescue_b := preload("res://fx/builders/fx_rescue_build.gd").new()

var _registry := {}
var _root: Node3D = null
var _screens := {}


func _ready() -> void:
	_registry = {
		# 挖矿链
		"FX001": _mining.fx001,
		"FX002": _mining.fx002,
		"FX006": _mining.fx006,
		"FX007": _mining.fx007,
		"FX008": _mining.fx008,
		# 战斗链
		"FX011": _combat.fx011,
		"FX014": _combat.fx014,
		# 支撑
		"FX017": _structure.fx017,
		# 危险 / 坍塌
		"FX018": _make_dust_field,
		"FX019": _hazard.fx019,
		"FX021": _hazard.fx021,
		"FX022": _hazard.fx022,
		# 救援
		"FX025": _rescue_b.fx025,
	}


# ── 世界特效（一次性 / 持续型）────────────────────────────────
func play(id: String, pos := Vector3.ZERO, opts := {}) -> Node3D:
	var spec: Dictionary = SPECS.get_spec(id)
	if spec.is_empty():
		push_warning("[FxManager] 未登记的特效编号：%s" % id)
		return null
	if not _registry.has(id):
		push_warning("[FxManager] %s 不是世界特效（kind=%s），请用对应 API：%s"
			% [id, spec.get("kind", "?"), spec.get("api", "")])
		return null

	var node: Node3D = _registry[id].call(opts)
	if node == null:
		return null
	node.name = id
	_container().add_child(node)
	if opts.has("rotation_degrees"):
		node.rotation_degrees = opts["rotation_degrees"]
	node.global_position = pos
	# 全局体量倍数：改 FxPalette.FX_SCALE 一个数即可缩放所有世界特效（新手参数）
	if not is_equal_approx(FxPalette.FX_SCALE, 1.0):
		node.scale = Vector3.ONE * FxPalette.FX_SCALE

	FxUtil.run_start(node)

	var dur := float(opts.get("duration", spec.get("duration", 0.0)))
	if dur > 0.0:
		_auto_free(node, id, dur)
	fx_started.emit(id, node)
	return node


# ── 贴附型（跟着目标走）──────────────────────────────────────
func attach(id: String, target: Node3D, opts := {}) -> Node3D:
	if not is_instance_valid(target):
		push_warning("[FxManager] attach 需要有效的目标节点")
		return null
	var node: Node3D
	match id:
		"FX005":
			var h := FxPickupHighlight.new()
			h.setup(target)
			node = h
		"FX024":
			node = FxRescue.new()
		_:
			push_warning("[FxManager] %s 不是贴附型特效，请用 play()" % id)
			return null

	target.add_child(node)
	node.transform = Transform3D.IDENTITY
	if opts.has("offset"):
		node.position = opts["offset"]
	var dur := float(opts.get("duration", SPECS.get_spec(id).get("duration", 0.0)))
	if dur > 0.0:
		_auto_free(node, id, dur)
	fx_started.emit(id, node)
	return node


# ── 受击闪白（FX012 / FX013）─────────────────────────────────
func flash(target: Node, peak := 0.9) -> void:
	## 玩家受击：0.06s 冲到峰值、0.22s 回落。
	FxFlash.flash(target, peak, 0.06, 0.22)


func flash_monster(target: Node, peak := 0.8) -> void:
	## 怪物受击：复用同一材质方案，峰值更低、回落更快，多怪物同屏不糊屏。
	FxFlash.flash(target, peak, 0.05, 0.18)


# ── 系统型 ───────────────────────────────────────────────────
func rope(a, b, taut := false, opts := {}) -> FxRope:
	## FX009 / FX010：a、b 可传 Vector3（固定点）或 Node3D（跟随）。
	var r := FxRope.new()
	if opts.has("radius"):
		r.radius = float(opts["radius"])
	_container().add_child(r)
	if a is Vector3 and b is Vector3:
		r.set_endpoints(a, b)
	else:
		r.track(a, b)
	r.set_taut(taut, true)
	return r


func placement_preview(valid := true) -> FxPlacementPreview:
	## FX015 / FX016：先拿到控制器，之后每帧 set_target()、按合法性 set_valid()。
	var p := FxPlacementPreview.new()
	_container().add_child(p)
	p.set_valid(valid)
	return p


func wall_occluder(walls: Array, target: Node3D, cam: Camera3D = null) -> FxWallOccluder:
	## FX033：walls 传墙块节点数组（会自动收集其子树里的 MeshInstance3D）。
	var w := FxWallOccluder.new()
	_container().add_child(w)
	w.set_walls(walls)
	w.track(cam, target)
	return w


func screen(id: String) -> Node:
	## FX020 / FX023：全屏层，挂在当前场景上，跨 3D 场景切换不丢。
	if _screens.has(id) and is_instance_valid(_screens[id]):
		return _screens[id]
	var node: Node
	match id:
		"FX020":
			node = FxScreenDanger.new()
		"FX023":
			node = FxScreenTransition.new()
		_:
			push_warning("[FxManager] %s 不是全屏型特效" % id)
			return null
	var scene := get_tree().current_scene
	if scene:
		scene.add_child(node)
	else:
		add_child(node)
	_screens[id] = node
	return node


# ── 回收 ─────────────────────────────────────────────────────
func stop(node: Node) -> void:
	if not is_instance_valid(node):
		return
	if node.has_method("stop"):
		node.call("stop")
	else:
		node.queue_free()


func stop_all() -> void:
	if is_instance_valid(_root):
		for c in _root.get_children():
			c.queue_free()


func reset_all() -> void:
	## 重开一局时调用：全屏层归零，避免红边 / 黑场残留（FX020 / FX023 的清理条件）。
	for id in _screens.keys():
		var s = _screens[id]
		if is_instance_valid(s) and s.has_method("reset"):
			s.call("reset")
	stop_all()


# ── 内部 ─────────────────────────────────────────────────────
func _container() -> Node3D:
	if is_instance_valid(_root):
		return _root
	_root = Node3D.new()
	_root.name = "FxRuntime"
	var scene := get_tree().current_scene
	if scene:
		scene.add_child(_root)
	else:
		add_child(_root)
	return _root


func _make_dust_field(opts: Dictionary) -> Node3D:
	var d := FxDustField.new()
	if opts.has("ceiling_height"):
		d.ceiling_height = float(opts["ceiling_height"])
	if opts.has("area_radius"):
		d.area_radius = float(opts["area_radius"])
	if opts.has("color"):
		d.dust_color = opts["color"]
	return d


func _auto_free(node: Node, id: StringName, dur: float) -> void:
	## 用绑定在节点上的 Tween 做定时回收：节点被提前释放时补间随之销毁，
	## 不会出现"回调触发时目标已释放"的报错。
	var tw := node.create_tween()
	tw.tween_interval(dur)
	tw.tween_callback(func():
		node.queue_free()
		fx_finished.emit(id)
	)


# ── 元数据查询（demo 面板 / 接入文档用）──────────────────────
func spec(id: String) -> Dictionary:
	return SPECS.get_spec(id)


func ids() -> Array:
	return SPECS.ids()

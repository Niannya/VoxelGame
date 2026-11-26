class_name FxFlash
extends RefCounted
## FX012 玩家受击闪白 / FX013 怪物受击闪白（同方案，参数不同）。
##
## 实现要点：用 MeshInstance3D.material_overlay 叠加一层白色 additive，
## 不替换本体材质 —— 闪完原配色 100% 还原（表格验收项："短暂闪白后恢复原配色"）。
## 同一目标重复受击时杀掉上一条补间，不会出现亮度叠加残留。

const SHADER := preload("res://fx/shaders/flash_overlay.gdshader")
const META_TWEEN := "_fx_flash_tween"
const META_PREV := "_fx_flash_prev_overlay"


static func flash(target: Node, peak := 0.9, rise := 0.06, fall := 0.22, color := Color(1, 0.97, 0.92)) -> void:
	if not is_instance_valid(target):
		return
	var meshes := collect_meshes(target)
	if meshes.is_empty():
		return

	# 打断上一次闪白，避免重复受击时亮度累积
	if target.has_meta(META_TWEEN):
		var old = target.get_meta(META_TWEEN)
		if old is Tween and old.is_valid():
			old.kill()

	for mi in meshes:
		if not mi.has_meta(META_PREV):
			mi.set_meta(META_PREV, mi.material_overlay)
		var mat: ShaderMaterial = mi.material_overlay as ShaderMaterial
		if mat == null or mat.shader != SHADER:
			mat = ShaderMaterial.new()
			mat.shader = SHADER
			mi.material_overlay = mat
		mat.set_shader_parameter("flash_color", color)
		mat.set_shader_parameter("intensity", 0.0)

	var tw := target.create_tween()
	tw.tween_method(_apply.bind(meshes), 0.0, peak, rise).set_ease(Tween.EASE_OUT)
	tw.tween_method(_apply.bind(meshes), peak, 0.0, fall).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(_restore.bind(meshes))
	target.set_meta(META_TWEEN, tw)


static func _apply(v: float, meshes: Array) -> void:
	for mi in meshes:
		if not is_instance_valid(mi):
			continue
		var mat := mi.material_overlay as ShaderMaterial
		if mat:
			mat.set_shader_parameter("intensity", v)


static func _restore(meshes: Array) -> void:
	for mi in meshes:
		if not is_instance_valid(mi):
			continue
		var prev = mi.get_meta(META_PREV, null)
		mi.material_overlay = prev
		mi.remove_meta(META_PREV)


static func collect_meshes(root: Node) -> Array:
	## 收集子树下所有可闪的 MeshInstance3D；带 _fx_no_flash 标记的跳过（如特效自身的网格）。
	var out := []
	var stack := [root]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is MeshInstance3D and n.mesh != null and not n.has_meta("_fx_no_flash"):
			out.append(n)
		for c in n.get_children():
			stack.append(c)
	return out

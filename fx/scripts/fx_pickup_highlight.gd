class_name FxPickupHighlight
extends Node3D
## FX005 矿物可拾取高亮（持续型，靠近时挂上）。
##
## 验收要求："靠近时提示可拾取，不改变矿物身份色"。
## 所以这里**只加两样东西**：中性暖白的外描边 + 地面脉冲环，
## 一根手指都没碰矿物本体的 albedo —— 铜还是铜色、晶还是青色，只是"多了层光"。

const OUTLINE_SHADER := preload("res://fx/shaders/pickup_outline.gdshader")
const RING_SHADER := preload("res://fx/shaders/ring.gdshader")

@export var pulse_hz := 1.15
@export var outline_grow := 0.016
@export var ring_scale := 1.45

var target: Node3D
var _mat: ShaderMaterial
var _ring_mat: ShaderMaterial
var _ring: MeshInstance3D
var _t := 0.0


func setup(who: Node3D) -> void:
	target = who


func _ready() -> void:
	if target == null:
		target = get_parent() as Node3D
	_mat = ShaderMaterial.new()
	_mat.shader = OUTLINE_SHADER
	_mat.set_shader_parameter("glow", Color(1.0, 0.96, 0.86))
	_mat.set_shader_parameter("strength", 0.62)
	_mat.set_shader_parameter("grow", outline_grow)
	_mat.set_shader_parameter("pulse", 1.0)

	var aabb := AABB()
	var first := true
	if target:
		var inv := target.global_transform.affine_inverse()
		for mi in _meshes(target):
			# 复制一份同网格的副本，沿法线外扩，只渲染背面 → 干净描边
			var copy := MeshInstance3D.new()
			copy.mesh = mi.mesh
			copy.material_override = _mat
			copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			copy.transform = inv * mi.global_transform
			copy.set_meta("_fx_no_flash", true)
			add_child(copy)

			var wa: AABB = mi.global_transform * mi.mesh.get_aabb()
			if first:
				aabb = wa
				first = false
			else:
				aabb = aabb.merge(wa)

	if first:
		aabb = AABB(Vector3(-0.2, 0, -0.2), Vector3(0.4, 0.4, 0.4))

	# 地面脉冲环：把"可以捡"的本体之外再加一层地面读法
	var inv_t := target.global_transform.affine_inverse() if target else Transform3D.IDENTITY
	var base := inv_t * aabb.position
	var rsize := maxf(aabb.size.x, aabb.size.z) * ring_scale
	if rsize < 0.35:
		rsize = 0.35
	var q := QuadMesh.new()
	q.size = Vector2(rsize, rsize)
	q.orientation = PlaneMesh.FACE_Y
	_ring_mat = ShaderMaterial.new()
	_ring_mat.shader = RING_SHADER
	_ring_mat.set_shader_parameter("color", Color(1.0, 0.95, 0.82))
	_ring_mat.set_shader_parameter("progress", 1.0)
	_ring_mat.set_shader_parameter("thickness", 0.055)
	_ring_mat.set_shader_parameter("strength", 0.75)
	_ring_mat.set_shader_parameter("grit", 0.2)
	_ring = FxUtil.mesh_instance(q, _ring_mat, Vector3(0, base.y + 0.02, 0))
	_ring.name = "PickupRing"
	_ring.set_meta("_fx_no_flash", true)
	add_child(_ring)


func _process(delta: float) -> void:
	_t += delta
	var p := 0.5 + 0.5 * sin(_t * TAU * pulse_hz)
	_mat.set_shader_parameter("pulse", p)
	if is_instance_valid(_ring):
		_ring_mat.set_shader_parameter("strength", lerpf(0.35, 0.9, p))
		var s := lerpf(0.96, 1.06, p)
		_ring.scale = Vector3(s, 1.0, s)


func _meshes(root: Node) -> Array:
	var out := []
	var stack := [root]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is MeshInstance3D and n.mesh != null and n != self:
			out.append(n)
		for c in n.get_children():
			stack.append(c)
	return out


func stop() -> void:
	queue_free()

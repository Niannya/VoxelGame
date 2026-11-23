extends Node3D
## Scene-space adapters keep the delivered GLBs untouched.
const BODY = preload("res://assets/mine/cart_body.glb")
const WHEEL = preload("res://assets/mine/cart_wheel.glb")
const TRACK = preload("res://assets/mine/track.glb")
const FURNACE = preload("res://assets/mine/furnace.glb")
var _wheels: Array[Node3D] = []
var _cart: Node3D
var _last_z: float


func install(cart: Node3D, world: Node3D) -> void:
	_cart = cart
	_last_z = cart.global_position.z
	for child in cart.get_node("Visual").get_children():
		if child is GeometryInstance3D:
			child.visible = false
	# Low guardrails keep the three mine layers and launched loot readable.
	var body := _fitted(BODY, Vector3(6.0, 0.45, 9.0), PI * 0.5)
	# The body's highest points are its railings; its broad deck is at its base.
	body.position.y = 0.0
	cart.get_node("Visual").add_child(body)
	for x in [-1.69, 1.69]:
		for z in [-3.0, 3.0]:
			var axle := Node3D.new()
			axle.position = Vector3(x, -0.23, z)
			cart.get_node("Visual").add_child(axle)
			var wheel := _fitted(WHEEL, Vector3(0.15, 0.6, 0.6), PI * 0.5)
			wheel.position.y = -0.3
			axle.add_child(wheel)
			_wheels.append(axle)
	var furnace := _fitted(FURNACE, Vector3(1.6, 1.6, 0.5), 0.0, -PI * 0.5)
	furnace.position = Vector3(-1.7, 0.0, 3.0)
	cart.get_node("Visual").add_child(furnace)
	for z in range(-36, 9, 6):
		var track := _fitted(TRACK, Vector3(6.0, 0.469, 6.0), PI * 0.5)
		track.position = Vector3(0, -0.5, z)
		world.add_child(track)


func _physics_process(_delta: float) -> void:
	if _cart == null:
		return
	var distance := _last_z - _cart.global_position.z
	_last_z = _cart.global_position.z
	for wheel in _wheels:
		wheel.rotate_x(distance / 0.3)


func _fitted(packed: PackedScene, target: Vector3, yaw: float, pitch: float = 0.0) -> Node3D:
	var holder := Node3D.new()
	var orient := Node3D.new()
	orient.rotation = Vector3(pitch, yaw, 0.0)
	holder.add_child(orient)
	var model := packed.instantiate() as Node3D
	orient.add_child(model)
	_hide_export_helpers(model)
	var box := _bounds(orient, Transform3D.IDENTITY)
	var factor := target / box.size
	holder.scale = factor
	orient.position = Vector3(-box.get_center().x, -box.position.y, -box.get_center().z)
	return holder


func _hide_export_helpers(node: Node) -> void:
	if node is MeshInstance3D and node.name == "Cube" and node.get_aabb().size.is_equal_approx(Vector3.ONE * 2.0):
		node.visible = false
	for child in node.get_children():
		_hide_export_helpers(child)


func _bounds(node: Node3D, parent: Transform3D) -> AABB:
	if not node.visible:
		return AABB()
	var mesh_transform := parent * node.transform
	var box := AABB()
	var found := false
	if node is MeshInstance3D and node.mesh != null:
		box = mesh_transform * node.get_aabb()
		found = true
	for child in node.get_children():
		if child is not Node3D:
			continue
		var sub := _bounds(child, mesh_transform)
		if sub.size == Vector3.ZERO:
			continue
		box = box.merge(sub) if found else sub
		found = true
	return box

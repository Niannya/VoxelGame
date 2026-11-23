extends SceneTree

func _initialize() -> void:
	var path := "res://assets/characters/rigged/char_01_cuntou.glb"
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("Cannot load " + path)
		quit(1)
		return
	var scene := packed.instantiate()
	root.add_child.call_deferred(scene)
	_dump.call_deferred(scene)

func _dump(node: Node) -> void:
	print("NODE ", node.get_path(), " ", node.get_class())
	if node is Skeleton3D:
		var skel := node as Skeleton3D
		var bones: Array[String] = []
		for i in skel.get_bone_count():
			bones.append(skel.get_bone_name(i))
		print("BONES ", bones)
	if node is AnimationPlayer:
		var player := node as AnimationPlayer
		print("ANIMS ", player.get_animation_list())
		for name in player.get_animation_list():
			var clip := player.get_animation(name)
			var paths: Array[String] = []
			for i in clip.get_track_count():
				paths.append(str(clip.track_get_path(i)))
			print("CLIP ", name, " length=", clip.length, " tracks=", paths)
	for child in node.get_children():
		_dump(child)
	if node.get_parent() == root:
		quit()

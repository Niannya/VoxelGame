extends SceneTree
## 角色数据表体检：三张表长度一致、资源都在、模型确实带骨骼动画。
## 用法：godot --headless --path . --script res://tools/test_character_roster.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var n := CharacterRoster.count()
	if n != 6:
		_fail("角色数量应为 6，实际 %d" % n)
		return
	if CharacterRoster.PORTRAITS.size() != n or CharacterRoster.MODELS.size() != n:
		_fail("NAMES / PORTRAITS / MODELS 长度不一致")
		return
	if CharacterRoster.NAMES.size() != n:
		_fail("NAMES 长度不一致")
		return

	for i in n:
		var model_path := CharacterRoster.model_of(i)
		var portrait_path := CharacterRoster.portrait_of(i)
		if not ResourceLoader.exists(portrait_path):
			_fail("头像缺失：" + portrait_path)
			return
		if not ResourceLoader.exists(model_path):
			_fail("模型缺失：" + model_path)
			return
		if not model_path.contains("/rigged/"):
			_fail("%d 号角色没有指向 rigged 模型：%s" % [i, model_path])
			return
		var packed := load(model_path) as PackedScene
		if packed == null:
			_fail("模型无法加载：" + model_path)
			return
		var inst := packed.instantiate()
		root.add_child(inst)
		var player := inst.get_node_or_null("AnimationPlayer") as AnimationPlayer
		var skeleton := inst.find_child("Skeleton3D", true, false) as Skeleton3D
		if player == null or skeleton == null:
			_fail("%d 号角色缺少 AnimationPlayer / Skeleton3D" % i)
			return
		if skeleton.get_bone_count() != 8:
			_fail("%d 号角色骨骼数 %d，应为 8" % [i, skeleton.get_bone_count()])
			return
		for clip in [&"Idle", &"Select"]:
			if not player.has_animation(clip):
				_fail("%d 号角色缺少 %s" % [i, clip])
				return
		inst.queue_free()
		await process_frame

	# 下标越界时统一夹进合法范围（结算界面会拿对局数据来取）
	if CharacterRoster.model_of(99) != CharacterRoster.MODELS[n - 1]:
		_fail("clamp_index 没把越界下标夹住")
		return
	print("CHARACTER_ROSTER_OK %d characters, rigged models, 8 bones, Idle+Select" % n)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)

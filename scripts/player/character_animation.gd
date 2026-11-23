extends Node
## 角色骨骼动画：待机为底层，工具动作为上半身一次性通道。

const TOOL_CLIPS := [&"Pick", &"Hammer", &"Bow", &"Torch", &"Backpack", &"Canteen"]
const UPPER_BONES := [&"spine", &"head", &"arm.L", &"arm.R"]

var _tree: AnimationTree
var _tool_node: AnimationNodeAnimation
var _tool_index := 0


func configure(model: Node3D, tool_index: int) -> void:
	var player := model.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if player == null or not player.has_animation("Idle"):
		push_warning("角色缺少骨骼动画：" + model.name)
		return
	_tool_index = clampi(tool_index, 0, TOOL_CLIPS.size() - 1)
	player.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR

	var blend := AnimationNodeBlendTree.new()
	var idle := AnimationNodeAnimation.new()
	idle.animation = &"Idle"
	_tool_node = AnimationNodeAnimation.new()
	_tool_node.animation = TOOL_CLIPS[_tool_index]
	var shot := AnimationNodeOneShot.new()
	shot.fadein_time = 0.08
	shot.fadeout_time = 0.16
	shot.filter_enabled = true
	for clip_name in TOOL_CLIPS:
		if not player.has_animation(clip_name):
			continue
		var clip := player.get_animation(clip_name)
		for track in clip.get_track_count():
			var path := clip.track_get_path(track)
			for bone in UPPER_BONES:
				if str(path).ends_with(":" + str(bone)):
					shot.set_filter_path(path, true)
	blend.add_node(&"Idle", idle)
	blend.add_node(&"Tool", _tool_node)
	blend.add_node(&"ToolShot", shot)
	blend.connect_node(&"ToolShot", 0, &"Idle")
	blend.connect_node(&"ToolShot", 1, &"Tool")
	blend.connect_node(&"output", 0, &"ToolShot")

	_tree = AnimationTree.new()
	_tree.name = "CharacterAnimationTree"
	model.add_child(_tree)
	_tree.anim_player = _tree.get_path_to(player)
	_tree.tree_root = blend
	_tree.active = true


func set_tool(index: int) -> void:
	_tool_index = clampi(index, 0, TOOL_CLIPS.size() - 1)
	if _tool_node != null:
		_tool_node.animation = TOOL_CLIPS[_tool_index]


func play_tool_action() -> void:
	if _tree != null:
		_tree.set("parameters/ToolShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func current_tool_clip() -> StringName:
	return TOOL_CLIPS[_tool_index]

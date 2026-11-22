class_name CharacterRoster
extends RefCounted
## 角色数据唯一来源：名字 / 头像 / 模型路径。
##
## 角色选择、局内、失败结算三处都从这里取，换角色或换模型只改这一个文件；
## 新增角色记得同步 CHAR_PORTRAITS 与 CHAR_MODELS 的顺序（按下标一一对应）。
##
## 模型是 Blender 绑定过的 rigged 版（8 骨骼 + Idle/Select/工具 clip），
## 生成方式见 tools/rig_characters.py；无骨骼的旧模型已移出仓库。

const NAMES := ["寸头哥", "白毛男", "粉毛女", "蓝毛男", "黄毛女", "黑毛男"]

const PORTRAITS := [
	"res://assets/characters/portraits/char_01_cuntou.jpg",
	"res://assets/characters/portraits/char_02_baimao.jpg",
	"res://assets/characters/portraits/char_03_fenmao.jpg",
	"res://assets/characters/portraits/char_04_lanmao.png",
	"res://assets/characters/portraits/char_05_huangmao.jpg",
	"res://assets/characters/portraits/char_06_hemao.jpg",
]

const MODELS := [
	"res://assets/characters/rigged/char_01_cuntou.glb",
	"res://assets/characters/rigged/char_02_baimao.glb",
	"res://assets/characters/rigged/char_03_fenmao.glb",
	"res://assets/characters/rigged/char_04_lanmao.glb",
	"res://assets/characters/rigged/char_05_huangmao.glb",
	"res://assets/characters/rigged/char_06_hemao.glb",
]


static func count() -> int:
	return NAMES.size()


## 把任意下标夹进合法范围（结算界面拿到的对局数据可能是脏的）
static func clamp_index(index: int) -> int:
	return clampi(index, 0, NAMES.size() - 1)


static func name_of(index: int) -> String:
	return NAMES[clamp_index(index)]


static func portrait_of(index: int) -> String:
	return PORTRAITS[clamp_index(index)]


static func model_of(index: int) -> String:
	return MODELS[clamp_index(index)]

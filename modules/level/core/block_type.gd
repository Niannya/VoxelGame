## 方块类型定义（L01 数据层）。
##
## 一个 LevelBlockType 描述"这种方块是什么"，不描述"它在哪里"。
## 位置与进度由 LevelVoxelGrid 里的 Cell 保存，两者分开，方便策划改表、美术换皮。
##
## 给其他模块的约定：
## - 判定"能不能挖"只看 is_boundary；边界方块永远不会被破坏。
## - `category` 是破岩词条的查表键（见 LevelVoxelGrid.apply_mining 的 power 参数）。
## - `art_key` 是美术槽位键，见 Docs/Dev/美术资产空位清单.md。
@tool
class_name LevelBlockType
extends Resource

## 稳定标识，存档和掉落表都用它，**不要改名**（改名等于改档）。
@export var id: StringName = &"stone_a"

## 显示名，仅用于 UI / 调试。
@export var display_name: String = "岩石"

## 破岩词条键：工具提交的 power 按这个键取倍率。stone / ore / boundary。
@export var category: StringName = &"stone"

## 破岩总进度。工具每次攻击累加进度，累计到该值方块破碎。
## 1.0 = 基础矿镐一击（首测），数值越大越硬。
@export var hardness: float = 1.0

## 是否不可破坏的边界（矿道外壳）。true 时 apply_mining 直接跳过。
@export var is_boundary: bool = false

## 开裂表现分几档（1/3、2/3 阈值见 LevelVoxelGrid.progress_ratio）。
@export_range(1, 4, 1) var crack_stages: int = 3

## 美术槽位键，对应 LevelArtTheme.block_meshes / block_materials。
@export var art_key: StringName = &"stone_a"

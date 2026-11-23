class_name MineralCatalog
extends RefCounted

const COMMON := ["stone_a", "stone_b"]
const RARE := ["gold", "quartz", "diamond", "emerald"]
const NAMES := {"stone_a": "岩石", "stone_b": "岩石", "gold": "黄金", "quartz": "石英", "diamond": "钻石", "emerald": "绿宝石"}
const COLORS := {"gold": Color("e8b542"), "quartz": Color("e3e0e8"), "diamond": Color("57d4ea"), "emerald": Color("49c389")}


static func is_common(key: String) -> bool:
	return key in COMMON


static func is_rare(key: String) -> bool:
	return key in RARE

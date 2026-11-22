class_name OreTable
extends RefCounted
## 矿石表：8 种，按稀有度从低到高。
##
## 玩法（掉落权重 / 熔炉价值 / 挖掘耗时）与失败结算界面共用这一份，
## 换矿石只改这里；`stone_a` / `stone_b` 不是矿石，是普通石头（挖完自动进熔炉，不给金币）。

const ORES := [
	{
		"key": "coal", "name": "煤", "color": Color(0.52, 0.54, 0.58),
		"value": 2, "dig": 1.0, "tier": 1,
		"desc": "最常见的基础矿石，黑黢黢的但很可靠。矿道深处随处可见，是前期的主要收入来源。",
	},
	{
		"key": "iron", "name": "铁", "color": Color(0.74, 0.46, 0.32),
		"value": 4, "dig": 1.1, "tier": 2,
		"desc": "硬度不错的红棕色矿石，敲起来铛铛响。可以用来修补矿车，也能卖个好价钱。",
	},
	{
		"key": "copper", "name": "铜", "color": Color(0.88, 0.58, 0.28),
		"value": 6, "dig": 1.1, "tier": 2,
		"desc": "暖橙色的金属矿石，埋在中层矿脉里。数量多、价值适中，是探险队的支柱财源。",
	},
	{
		"key": "gold", "name": "黄金", "color": Color(0.96, 0.79, 0.32),
		"value": 10, "dig": 1.3, "tier": 3,
		"desc": "闪闪发光的稀有矿石！通常藏在矿脉深处，小心：金矿附近常常有塌方风险。",
	},
	{
		"key": "cyanite", "name": "青晶", "color": Color(0.42, 0.77, 0.86),
		"value": 16, "dig": 1.5, "tier": 4,
		"desc": "散发着淡淡蓝光的晶体矿石，摸起来冰凉。据说贴在脑门上能让人精神一振。",
	},
	{
		"key": "amethyst", "name": "紫晶", "color": Color(0.68, 0.48, 0.86),
		"value": 24, "dig": 1.7, "tier": 5,
		"desc": "神秘的紫色晶体，在黑暗中会微微发光。矿工们都相信它能带来好运。",
	},
	{
		"key": "emerald", "name": "绿宝石", "color": Color(0.40, 0.78, 0.50),
		"value": 40, "dig": 1.9, "tier": 6,
		"desc": "温润的绿色宝石，切割后光彩夺目。商人们抢着收的好货，一枚能换不少金币。",
	},
	{
		"key": "ruby", "name": "红宝石", "color": Color(0.86, 0.32, 0.34),
		"value": 60, "dig": 2.1, "tier": 7,
		"desc": "炽热的红色宝石，仿佛内部藏着火焰。是本局挖到的最珍贵矿石，值得炫耀！",
	},
]

## 普通石头（不是矿石，挖掉只清障，石头自动进熔炉但不产金币）
const STONES := ["stone_a", "stone_b"]

## 浅层权重：石头以外按稀有度快速衰减
const BASE_WEIGHTS := [30.0, 24.0, 20.0, 12.0, 6.0, 3.0, 0.8, 0.2]


static func count() -> int:
	return ORES.size()


static func keys() -> Array:
	return ORES.map(func(o: Dictionary) -> String: return o.key)


static func has_ore(key: String) -> bool:
	return _find(key) >= 0


static func by_key(key: String) -> Dictionary:
	var i := _find(key)
	return ORES[i] if i >= 0 else {}


static func value_of(key: String) -> int:
	var ore := by_key(key)
	return int(ore.get("value", 0))


static func dig_of(key: String) -> float:
	var ore := by_key(key)
	return float(ore.get("dig", 1.0)) if not ore.is_empty() else 1.0


static func name_of(key: String) -> String:
	var ore := by_key(key)
	return str(ore.get("name", key))


static func color_of(key: String) -> Color:
	var ore := by_key(key)
	return ore.get("color", Color(0.35, 0.35, 0.38)) if not ore.is_empty() else Color(0.35, 0.35, 0.38)


## 挖到这一格的掉落 key：普通石头或某种矿石。
## depth_tier 越大越偏稀有（每深一层调用方 +1）；ore_chance 是"这一格是不是矿"的概率。
static func roll(rng: RandomNumberGenerator, depth_tier: int = 0, ore_chance: float = 0.35) -> String:
	if rng.randf() > ore_chance:
		return "stone_a" if rng.randf() < 0.68 else "stone_b"

	var weights: Array[float] = []
	var total := 0.0
	for i in ORES.size():
		# 深层把稀有矿的权重往上抬：pow 的底数是正数，不会出 NaN
		var w: float = BASE_WEIGHTS[i] * pow(1.45, float(depth_tier) * float(i) / 4.0)
		weights.append(w)
		total += w

	var r := rng.randf() * total
	var acc := 0.0
	for i in ORES.size():
		acc += weights[i]
		if r <= acc:
			return ORES[i].key
	return ORES[ORES.size() - 1].key


static func _find(key: String) -> int:
	for i in ORES.size():
		if ORES[i].key == key:
			return i
	return -1

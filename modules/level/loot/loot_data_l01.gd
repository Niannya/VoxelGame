## L01 首测掉落表（18 件 × 第 1～8 层）。
##
## 数值全部来自《胡闹矿洞L01矿洞格子与掉落经济》第 4、5 节。
## 这里只做一件事：把表算成 LevelLootTable。策划改数值改这个文件即可，
## 逻辑一行都不用动；将来要搬到 .tres，用 build() 生成后另存就行。
##
## 权重口径：单层合计固定 per_depth_total = 100000。
## 高价档（永乐大典 / 比特币硬盘 / 清明上河图）随深度增长，缺口由西瓜皮让出。
class_name LevelLootDataL01
extends RefCounted

const DEPTHS := 8

## 高价档合计：第 1 层 600，每层 +100，第 7 层起 1200。
const HIGH_TIER_BASE := 600
const HIGH_TIER_STEP := 100
const HIGH_TIER_CAP := 1200

## 高价档内部固定比例。
const SHARE_YONGLE := 50
const SHARE_HDD := 35
const SHARE_QINGMING := 15

## 西瓜皮在第 1 层的权重，也是让出概率的来源。
const WATERMELON_BASE := 15400


static func high_tier_total(depth: int) -> int:
	return clampi(HIGH_TIER_BASE + HIGH_TIER_STEP * (depth - 1), HIGH_TIER_BASE, HIGH_TIER_CAP)


static func _row(value: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(DEPTHS)
	out.fill(value)
	return out


static func _make(item_id: StringName, name: String, price: int, tier: StringName,
		weights: PackedInt32Array, natural_mineral: bool = false) -> LevelLootEntry:
	var e := LevelLootEntry.new()
	e.item_id = item_id
	e.display_name = name
	e.price = price
	e.tier = tier
	e.weights = weights
	e.is_natural_mineral = natural_mineral
	return e


static func build() -> LevelLootTable:
	var yongle := PackedInt32Array()
	var hdd := PackedInt32Array()
	var qingming := PackedInt32Array()
	var watermelon := PackedInt32Array()
	yongle.resize(DEPTHS)
	hdd.resize(DEPTHS)
	qingming.resize(DEPTHS)
	watermelon.resize(DEPTHS)

	for depth in range(1, DEPTHS + 1):
		var high := high_tier_total(depth)
		var i := depth - 1
		yongle[i] = high * SHARE_YONGLE / 100
		hdd[i] = high * SHARE_HDD / 100
		qingming[i] = high * SHARE_QINGMING / 100
		watermelon[i] = WATERMELON_BASE - (high - HIGH_TIER_BASE)

	var table := LevelLootTable.new()
	table.per_depth_total = 100000
	table.max_depth = DEPTHS

	# ---- 垃圾类（9 件，合计 75.560% @ 第 1 层）
	table.entries.append(_make(&"junk_hdd", "存有大量比特币的硬盘", 110, &"junk", hdd))
	table.entries.append(_make(&"junk_server", "可以跑满血大模型的服务器单机", 60, &"junk", _row(650)))
	table.entries.append(_make(&"junk_powerbank", "鼓包充电宝", 8, &"junk", _row(7800)))
	table.entries.append(_make(&"junk_earphone", "只响一边的耳机", 7, &"junk", _row(8300)))
	table.entries.append(_make(&"junk_umbrella", "伞骨朝天的雨伞", 5, &"junk", _row(9000)))
	table.entries.append(_make(&"junk_potato", "长出刘海的土豆", 4, &"junk", _row(10500)))
	table.entries.append(_make(&"junk_hanger", "断腿衣架", 3, &"junk", _row(11100)))
	table.entries.append(_make(&"junk_sock", "单只袜子", 2, &"junk", _row(12600)))
	table.entries.append(_make(&"junk_watermelon", "啃成月牙的西瓜皮", 1, &"junk", watermelon))

	# ---- 矿物类（4 件，合计 20.800% @ 第 1 层）
	table.entries.append(_make(&"mineral_uranium", "铀-235 号样本", 42, &"mineral", _row(900)))
	table.entries.append(_make(&"mineral_diamond", "钻石", 24, &"mineral", _row(4800), true))
	table.entries.append(_make(&"mineral_gold", "黄金矿块", 16, &"mineral", _row(6800), true))
	table.entries.append(_make(&"mineral_moonstone", "月光石", 10, &"mineral", _row(8300), true))

	# ---- 古董类（5 件，合计 3.640% @ 第 1 层）
	table.entries.append(_make(&"antique_qingming", "《清明上河图》长卷", 140, &"antique", qingming))
	table.entries.append(_make(&"antique_yongle", "《永乐大典》", 85, &"antique", yongle))
	table.entries.append(_make(&"antique_napoleon", "盖着咖啡圈的拿破仑肖像", 50, &"antique", _row(750)))
	table.entries.append(_make(&"antique_hitler", "掉漆的希特勒画像", 36, &"antique", _row(1100)))
	table.entries.append(_make(&"antique_stalin", "印有斯大林头像的搪瓷杯", 30, &"antique", _row(1400)))

	return table


## 矿物房专用表：房内可采矿格只掉一种矿（随机房间表）。
## room 房型取值：uranium / diamond / gold / moonstone。
static func build_mineral_room(room: StringName) -> LevelLootTable:
	var table := LevelLootTable.new()
	table.per_depth_total = 100000
	table.max_depth = DEPTHS
	var item := {
		&"uranium": _make(&"mineral_uranium", "铀-235 号样本", 42, &"mineral", _row(100000)),
		&"diamond": _make(&"mineral_diamond", "钻石", 24, &"mineral", _row(100000), true),
		&"gold": _make(&"mineral_gold", "黄金矿块", 16, &"mineral", _row(100000), true),
		&"moonstone": _make(&"mineral_moonstone", "月光石", 10, &"mineral", _row(100000), true),
	}
	if not item.has(room):
		push_error("未知矿物房类型: %s" % room)
		return build()
	table.entries.append(item[room])
	return table

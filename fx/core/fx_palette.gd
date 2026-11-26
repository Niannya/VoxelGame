class_name FxPalette
extends RefCounted
## 胡闹矿洞 P0 特效统一美术口径。
##
## 三条硬约束（来自《美术资产逐项清单》与俯视体素镜头）：
## 1) 俯视 + 小角色（约 1.6m 高）：特效单点尺寸控制在 0.25–1.2m，靠"高频闪 + 短时长"读出来，不靠大面积遮挡。
## 2) 暗矿洞背景（亮度 0.07–0.12）：所有反馈色亮度 ≥ 0.62，保证在暗底上能辨认。
## 3) 矿物身份色只用于矿物本体与掉落物；提示类特效一律用中性暖白 / 青，不覆盖身份色（FX005 验收要求）。

# ── 矿物身份色（3 种矿物，禁止被特效改色）────────────────────────
const ORE_COPPER := Color("#E08B3C")   ## 铜矿
const ORE_IRON := Color("#AEB9C6")     ## 铁矿
const ORE_CRYSTAL := Color("#55E0D8")  ## 晶矿

# ── 岩石 / 地形 ────────────────────────────────────────────────
const ROCK := Color("#7A7C80")
const ROCK_DEEP := Color("#5A5C60")
const ROCK_CHIP := Color("#8E9095")

# ── 尘土 / 烟 ──────────────────────────────────────────────────
const DUST := Color("#B9A88C")
const DUST_DARK := Color("#8C7C64")
const SMOKE := Color("#6E6558")

# ── 反馈 ──────────────────────────────────────────────────────
const SPARK := Color("#FFE8A3")        ## 击打火花（暖白）
const FLASH := Color("#FFFFFF")        ## 闪白
const GOLD := Color("#FFC53D")         ## 金币
const SUCCESS := Color("#6BF0C8")      ## 成功 / 复苏（青绿）
const VALID := Color("#4FE3C1")        ## 可放置

# ── 危险 ──────────────────────────────────────────────────────
const WARN := Color("#FF9A3C")
const DANGER := Color("#FF4D4D")
const CRITICAL := Color("#FF2E2E")

# ── 绳索 ──────────────────────────────────────────────────────
const ROPE_SLACK := Color("#6B5A45")   ## 松弛：暗、哑、下垂
const ROPE_TAUT := Color("#E6D6A8")    ## 绷紧：亮、细、带高频张力条纹

# ── 全局体量倍数（新手最容易改的一个数）─────────────────────────
## 1.0 = 原始大小。想把"所有世界特效"整体放大/缩小，只改这一个数：
## 1.2 = 全部大 20%，0.8 = 全部小 20%。改完按 Ctrl+S，再按 F5 看效果。
const FX_SCALE := 1.0

# ── 通用体量（米）─────────────────────────────────────────────
const S_CHIP := 0.055      ## 碎石颗粒边长
const S_CHIP_BIG := 0.09   ## 破碎主碎片边长
const S_DUST := 0.34       ## 尘团贴片直径
const S_RING := 0.9        ## 地面环直径
const S_IMPACT := 0.32     ## 命中闪光直径

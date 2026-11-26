# P0 特效库接入说明（`fx/`，FX001–FX033 共 24 项）

> 引擎：本库在 Godot **4.7.2** 上开发与截图验收，已按 4.6.2 无头自检通过（CPUParticles3D + 基础 Tween/shader API，无版本特有依赖）。
> 遵守仓库 `AGENTS.md`：本库全部放在 `fx/` 与 `preview/`、`Docs/FX/`，**不改动** `modules/`、`scripts/`、`scenes/` 下任何现有文件。

## 一、接入步骤（2 步）

**1. 确认 `fx/` 在工程里**（合并后自然满足）：库根 = `res://fx/`。

**2. 注册 Autoload**（⚠️ 按 AGENTS.md 硬规则 5：**不要手改 project.godot 的 [autoload] 段**，用编辑器操作）：

- Godot 编辑器 →「项目」→「项目设置」→「Autoload」页签
- Path 选 `res://fx/scripts/fx_manager.gd`，节点名 `FxManager`，全局变量保持勾选 →「添加」
- 重启编辑器（新增 class_name 后需要让编辑器扫描一次）

## 二、调用方式

```gdscript
# 一次性特效（自动释放）
FxManager.play("FX002", block.global_position, {"ore_color": FxPalette.ORE_COPPER})

# 贴附型（跟着节点走，自己控制结束）
var r := FxManager.attach("FX024", downed_player) as FxRescue
r.set_progress(0.7)

# 全屏型
var d := FxManager.screen("FX020") as FxScreenDanger
d.set_intensity(0.6)

# 系统型（绳索 / 放置预览 / 墙体遮挡淡化）
FxManager.rope(post_a, post_b, false)
FxManager.placement_preview(true)
FxManager.wall_occluder(wall_blocks, player, camera)

# 重开一局
FxManager.reset_all()
```

## 三、24 项速查

| 编号 | 名称 | API | 持续 |
|---|---|---|---|
| FX001 | 矿块受击闪光 | `play("FX001", pos, {"target": 块, "ore_color": 色})` | 0.36s |
| FX002 | 石头破碎 | `play("FX002", pos, {"ore_color": 色})` | 0.75s |
| FX005 | 矿物可拾取高亮 | `attach("FX005", ore)`，`stop()` 结束 | 持续 |
| FX006 | 物品拾取反馈 | `play("FX006", pos)` | 0.45s |
| FX007 | 物品投炉反馈 | `play("FX007", 炉位, {"mouth_offset": 炉口, "item": 物品})`，结束发 `item_consumed` | 0.55s |
| FX008 | 金币获得反馈 | `play("FX008", pos, {"amount": N})` | 0.90s |
| FX009 | 绳索松弛 | `FxManager.rope(a, b, false)` | 持续 |
| FX010 | 绳索绷紧 | `FxManager.rope(a, b, true)` 或 `set_taut(true)` | 持续 |
| FX011 | 工具命中反馈 | `play("FX011", pos, {"normal": 法线})` | 0.20s |
| FX012 | 玩家受击闪白 | `FxManager.flash(player, 0.9)` | 0.28s |
| FX013 | 怪物受击闪白 | `FxManager.flash_monster(m, 0.8)` | 0.23s |
| FX014 | 怪物死亡消散 | `play("FX014", pos, {"body": 怪, "tint": 色})`，发 `body_gone` | 0.55s |
| FX015 | 支撑可放置预览 | `FxManager.placement_preview(true)`，每帧 `set_target()` | 持续 |
| FX016 | 支撑不可放置预览 | 同上 `set_valid(false)` | 持续 |
| FX017 | 支撑搭建完成 | `play("FX017", pos, {"footprint": 1.6})` | 0.70s |
| FX018 | 粉尘浓度警告 | `play("FX018", pos, {...})` 返回 `FxDustField`，`set_intensity(0~1)` | 持续 |
| FX019 | 小落石预警 | `play("FX019", pos, {"count": n, "area": r})` | ~1.1s |
| FX020 | 危险接近全屏警示 | `FxManager.screen("FX020")`，`set_intensity/set_critical` | 持续 |
| FX021 | 坍塌大落石 | `play("FX021", pos)`，发 `camera_shake` 信号 | 2.40s |
| FX022 | 矿洞结构坍塌 | `play("FX022", pos, {"area": 4.2})` | 2.2s |
| FX023 | 关卡过渡黑场 | `FxManager.screen("FX023")`，`play(dir)` | 1.2s |
| FX024 | 救援进行反馈 | `attach("FX024", 倒地者)`，`set_progress(0~1)` | 持续 |
| FX025 | 玩家倒地呼救 | `play("FX025", pos, {"player": 节点})` | 4.0s |
| FX033 | 墙体遮挡淡化 | `FxManager.wall_occluder(墙块数组, 玩家, 相机)` | 持续 |

- 配色统一在 `fx/core/fx_palette.gd`（含全局缩放 `FX_SCALE`）
- 触发/持续/范围/清理元数据在 `fx/core/fx_specs.gd`
- 每条详情与验收批注表：`cards/FXxxx.md`

## 四、验收

- 验收台：`preview/fx_preview.tscn`（F6 运行，左侧逐条触发、右侧显示规格；验收完可整个删除 `preview/`）
- 单条：`preview/fx_single.tscn`（检查器里改 `fx_id`）
- 无头自检：`Godot --headless --path . res://preview/fx_preview.tscn -- --selftest` → `[SELFTEST] ok`
- 截图：`Docs/FX/screenshots/FXxxx.png`

## 五、实现约定

- 全部 CPUParticles3D（数量 ≤ 40），兼容 GL Compatibility 与移动端，无 compute 依赖
- 一次性特效按 spec 的 duration 自动释放；持续型提供 `stop()`；`reset_all()` 清全屏层
- 受击闪白用 `material_overlay`，不替换本体材质；不覆盖场景对象的物理/逻辑
- 相机震动、数值文字等玩法信息只发信号，玩法侧自由消费

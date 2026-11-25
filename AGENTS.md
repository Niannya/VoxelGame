# AGENTS.md — 《胡闹矿洞》工程约定（给所有 AI agent）

Godot 4.6.2 / Forward+ / Jolt。主场景 `res://scenes/levels/mine_playground.tscn`（旧），
关卡新骨架在 `res://scenes/levels/level_sandbox.tscn`。

## 1. 目录即边界：只改自己那块

| 目录 | 归属 | 能不能动 |
| --- | --- | --- |
| `modules/level/**` | **关卡（本项目当前负责人）** | ✅ 只有关卡负责人和它的 agent 能改 |
| `modules/player/**` | 玩家模块 | ❌ 不要改，需要改就提接口需求 |
| `scripts/**` | 历史代码（玩家侧挖掘、HUD） | ❌ 不要改，见 `Docs/Dev/关卡接口契约.md` 的迁移说明 |
| `scenes/levels/level_sandbox.tscn` | 关卡装配 | ✅ 关卡可改；`mine_playground.tscn` 不要动 |
| `assets/level/**` | 美术 | ✅ 只能填资源，不要改结构 |
| `tests/level/**` | 关卡自检 | ✅ 关卡可改 |

跨目录改文件前，先在对话里说明原因，不要直接改完再讲。

## 2. 硬规则（踩过的坑）

1. **写完 `.gd` / `.tscn` / `.tres` 不能带 UTF-8 BOM**，否则 Godot 报
   `Parse Error: Expected '['` 或整段脚本失效。用无 BOM 的 UTF-8 写文件。
2. **新增或重命名 `class_name` 后，必须让编辑器扫描一次**，否则运行时报
   `Identifier "Xxx" not declared`：
   ```
   Godot_v4.6.2-stable_win64.exe --headless --editor --path . --quit
   ```
3. **改完关卡代码必须跑两套测试**，全绿才提交：
   ```
   Godot_v4.6.2-stable_win64.exe --headless --path . res://tests/level/level_selftest.tscn
   Godot_v4.6.2-stable_win64.exe --headless --path . res://tests/level/level_audit.tscn
   ```
   看到 `LEVEL SELFTEST: PASS` 和 `LEVEL AUDIT: PASS` 才算过。
   - `level_selftest`：实现了什么测什么（回归）。
   - `level_audit`：按需求案原文写的对抗性断言（找偏差），**改数值/改规则先跑它**。
4. **无头模式下 `MultiMesh.set_instance_transform` 不会回读**（引擎 dummy 渲染器），
   写渲染测试别去读 multimesh 的变换，用 `LevelVoxelRenderer.display_state(cell)`。
   视觉最终确认要开编辑器看。
5. `project.godot` 的 `[autoload]` / `[editor_plugins]` 段不要手改（MCP 插件、输入映射都在那儿）。
6. 数值不要散落在逻辑里：掉落/深度/怪物概率分别在
   `modules/level/loot/loot_data_l01.gd`、`modules/level/core/level_state.gd`、
   `modules/level/monsters/monster_spawner.gd` 的表里改。

## 3. 关卡模块的入口（先读这个再动手）

- 模块说明与 API：`modules/level/AGENTS.md`
- 对外接口契约（含给玩家/UI 模块的迁移表）：`Docs/Dev/关卡接口契约.md`
- 没实现的东西：`Docs/Dev/关卡缺口清单.md`
- 美术槽位：`Docs/Dev/美术资产空位清单.md`

## 4. 可以用工具链

本机已接 Godot Editor MCP（`mcp__godot__*`）：能读场景树、改场景、写脚本、跑游戏。
用它做验证比盲改快；但**改完仍要跑一次无头自检**，编辑器里看着对不代表测试过。

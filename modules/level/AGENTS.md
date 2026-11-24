# 关卡模块（modules/level）— agent 说明书

负责 L01～L07。对应《功能模块总述大纲》里的关卡七条线。

## 1. 节点装配（`scenes/levels/level_sandbox.tscn`）

节点名是**对外契约**，队友的 NodePath 指着它们，**不要改名**：

```
LevelSandbox      LevelRoot        门面 + 兼容层
├─ LevelState     LevelState       L02 深度/推进
├─ Grid           LevelVoxelGrid   L01 唯一数据源
├─ Renderer       LevelVoxelRenderer  L01 表现（可整层删掉）
├─ Track          LevelTrackService L03 轨道
├─ Stability      LevelStabilityService L03 稳定度
├─ MineCart       LevelCartController  L04
├─ Player / MiningHUD / Mining        玩家侧（别人的，别改）
```

## 2. 谁可以碰谁

```
Player(P04) --apply_mining--> Grid
Cart(L04)   --solid_cells_in--> Grid        （只查，不写）
Cart(L04)   --is_track_ready--> Track       （只查，不写）
Track(L03)  <--cell_cleared--- Grid
Stability   <--cell_cleared--- Grid
Renderer    <--信号---------- Grid          （只读订阅）
```

**禁止**：从 Cart/Track/UI 直接读写 `Grid._cells`；从 Grid 反向调 Cart；在 Renderer 里改数据。

## 3. 文件地图

| 文件 | 管什么 |
| --- | --- |
| `core/level_state.gd` | 深度、累计推进、下潜；唯一写入入口 `advance_to(z)` |
| `core/level_defaults.gd` | 方块表/掉落表/生成器的默认值（场景没填就用它） |
| `core/block_type.gd` | 方块类型数据（id、硬度、是否边界、美术键） |
| `grid/voxel_grid.gd` | 格子数据、挖掘结算、掉落、DDA 拾取、通行查询 |
| `grid/voxel_renderer.gd` | MultiMesh 铺格子、裂纹、碎屑；只订阅 |
| `gen/mine_generator.gd` | 矿道生成规则（换成 .tres 可复用） |
| `loot/loot_table.gd` / `loot_entry.gd` | 分层掉落表数据结构 |
| `loot/loot_data_l01.gd` | **L01 的 18 件 × 8 层数值**（改数值就改这里） |
| `track/track_service.gd` | 自动铺轨、回收、`is_track_ready()` |
| `track/stability_service.gd` | 每 5 格分段、衰减、柱子、预警、坍塌信号 |
| `cart/cart_controller.gd` | 矿车行进、四种停车原因 |
| `monsters/monster_spawner.gd` | L05 抽怪表与两路判定（AI 未接） |
| `economy/economy_service.gd` | L06 共享金币、卖矿、扣钱 |
| `events/event_router.gd` | L07 事件编号表、触发记录、本局状态 |
| `art/level_art_theme.gd` | 美术槽位定义 |

## 4. 关键约定

- **掉落只从 `block_broken` 信号拿**，别自己调 `loot_table.roll()`，否则以后加价/事件会漏。
- **里程只由 Cart 通过 `LevelState.advance_to()` 上报**，别的模块不要自己算进度。
- **停车原因用 `LevelCartController.StopReason`**，新增原因要同步 `Docs/Dev/关卡接口契约.md`。
- **改 `class_name`、改信号参数 = 破坏性变更**：必须同时更新本文档、`api.json`、
  接口契约文档，并在 PR/提交信息里写明。

## 5. 加东西的标准动作

| 想加 | 改哪里 | 顺手要做 |
| --- | --- | --- |
| 新方块类型 | `level_defaults.block_types()` 加一条 | 美术槽位补 `stone_x` 键 |
| 新掉落物 | `loot_data_l01.gd` 加一行 + 权重 | 跑自检（权重合计必须 10 万） |
| 新事件 | `event_router.gd` 的 `EVENT_NAMES` | 在 `_evaluate` 挂触发源（见缺口清单） |
| 新怪种 | `monster_spawner.gd` 的 `NORMAL_BANDS` | 概率合计必须 100 |
| 新美术 | 只填 `assets/level/level_art_theme.tres` | 不要改代码 |

## 6. 自检

```
Godot_v4.6.2-stable_win64.exe --headless --path . res://tests/level/level_selftest.tscn
Godot_v4.6.2-stable_win64.exe --headless --path . res://tests/level/level_audit.tscn
```

- `level_selftest`（回归）：掉落权重与分布、挖掘进度/破坏/多格/边界、深度推进与下潜、
  矿车停车原因、L05 概率表、L06 结算、整场景冒烟（生成→铺轨→被岩块挡住）。
- `level_audit`（对抗）：按需求案原文写断言，专找实现与需求的偏差
  （每层 100% 权重、高价档 600→1200、西瓜皮补差、柱子覆盖 6→1、衰减公式、
  开局里程为 0、矿车停在 z≈1.3、兼容层两参信号…）。**改数值先跑它。**

两个都要 PASS 才算过。新增机制请**加断言**，不要只手动点。

⚠️ 无头模式下 `MultiMesh.set_instance_transform` 不回读（引擎 dummy 渲染器），
渲染相关断言请用 `LevelVoxelRenderer.display_state(cell)`；视觉效果仍需开编辑器确认。

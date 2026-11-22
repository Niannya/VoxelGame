# VoxelGame 项目长期笔记

## 环境
- Godot 4.6.2：`D:/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64.exe`（console 版同目录，后缀 `_console.exe`）
- 系统 Node v24.12.0：`D:/nodejs/`
- 渲染器 Forward Plus，物理引擎 Jolt Physics，Windows 驱动 d3d12

## 仓库
- 本地 `D:/GodotProjects/voxel-game`，远端 https://github.com/Niannya/VoxelGame.git
- **日常开发都在 `develop` 分支**（2026-11-22 由 main 切出并推送），`main` 保持稳定
- 远端另有 `feature/character-select-ui`（他人在做角色选择界面）和 `vandawnlab-patch-1`（已废弃）

## Godot MCP
- 使用 `@satelliteoflove/godot-mcp` v4.3.0，配置在 `~/.workbuddy/mcp.json` 的 `godot-mcp` 条目
- 架构：MCP server ←stdio→ Node ←WebSocket `127.0.0.1:6550`→ Godot 编辑器 addon `addons/godot_mcp/`
- **前提：Godot 编辑器必须开着且插件已启用**，否则工具调用会报 ECONNREFUSED
- 该服务不认 `GODOT_PATH`；可用环境变量只有 GODOT_HOST/GODOT_PORT/GODOT_MCP_READ_ONLY/GODOT_MCP_VERBOSE/GODOT_MCP_USAGE_LOG
- 工具 21 个，全部 `godot_*` 前缀，`godot_*_read` 类为只读可自动放行

## 注意
- `.workbuddy/` 目前未纳入版本控制（用户尚未决定是否忽略或提交）

## 目录约定
- `Docs/Human/` 放人工撰写的文档（策划案、随机事件表、随机天赋表）
- `Docs/Agent/` 放 Agent 产出
- **不要把截图提交进仓库**，用户删过 `Docs/Screenshots/`；验证截图留在 `.workbuddy/`

## 场景与代码
- `scenes/levels/mine_playground.tscn`：唯一可玩场景，`run/main_scene` 指向它
- `scenes/world/mine_cart.tscn`：移动平台式矿车（自动前进 / 遇阻停车）
- `scenes/player/player.tscn`：矿工占位角色，相机挂在角色下（单人临时方案，2-4 人时必须换成队伍跟随相机）
  - **机位是侧视**：offset `(9.5, 14.5, 1)`，`rotation_degrees = (-55, 72, 0)` —— yaw 72° 让相机在 +X 侧往 -X 看、略带前倾；pitch -55° 是俯视分量
  - 相机偏航后**移动方向必须按相机 yaw 旋转**，否则 W 会跑到画面侧面
- `voxel_world.gd` 的世界是**不对称**的：只砌远侧（-X）矿壁，近侧敞开给相机看；地板仍铺满全宽，否则侧视会在近侧边缘露出虚空
- `scripts/world/voxel_world.gd`：运行时体素世界，**唯一的世界生成入口**（旧的烘焙链路已于 11-21 删除，不要再引入第二套生成器）
- `tools/` 下都是开发工具；`capture_cart.gd` / `capture_mining.gd` 用来跑自动化验证并截图

## 体素渲染注意事项
- MultiMesh 的 transform buffer **在 `--headless` 下不会分配**，烘焙/生成场景必须带真实渲染驱动跑
- **不要用半透明做「剖面」**：矿体 6 格高，俯视角要穿过好几层，alpha 累加后整屏糊成雾。正确做法是直接隐藏（零缩放 + 挪远），见 `update_cutaway()`
- GDScript 没有 12 参数的 `Transform3D` 构造（那是 .tscn 序列化格式），`const` 也不能调用 `Basis().scaled()`

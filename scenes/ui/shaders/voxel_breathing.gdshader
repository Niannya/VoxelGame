shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// ---- 待机呼吸 ----
// 两件事同时做：
//   1) 身体上下：脚踝以下位移为 0，往上平滑抬到满幅 → 脚不动，上身整体起落；
//   2) 胸腔扩张：只在胸口一段做极小的径向膨胀；腰以下和肩线以上权重都为 0，
//      所以既不会把肚子/胯撑大，也不会把脑袋和帽子撑大。
// breath 由脚本每帧写入 sin(时间)，取值 -1..1。

uniform float breath = 0.0;          // 呼吸相位 -1..1
uniform float base_y = 0.0;          // 模型空间里的脚底高度
uniform float model_height = 2.2;    // 模型空间里的身高
uniform float model_width = 1.1;     // 模型空间里的身宽（用于让扩张只发生在躯干，不推开手臂）

// --- 身体上下起伏 ---
uniform float amp_lift = 0.010;      // 上身起落幅度（模型单位，实测头顶上下约 5px）
uniform float lift_start = 0.02;     // 从这里开始抬（脚踝以上）
uniform float lift_full = 0.50;      // 到这里抬到满幅（腰以上整体平移，不再拉腿）

// --- 胸腔扩张 ---
uniform float amp_chest = 0.020;     // 胸腔径向外扩（占半径比例）
uniform float chest_center = 0.70;   // 扩张最强处（相对身高，胸口位置）
uniform float chest_width = 0.11;    // 影响范围（高斯宽度，窄一点更像胸腔）
uniform float chest_lo = 0.45;       // 低于此高度不扩张（保护肚子和胯）
uniform float chest_hi = 0.62;       // 到这个高度扩张到满权重（腰以上才开始）
uniform float chest_fade_from = 0.74;// 从这里开始衰减
uniform float chest_fade_to = 0.80;  // 到这里完全消失（下巴以上不再变形，保护头和帽子）
uniform float torso_edge_lo = 0.80;  // 横向衰减起点（占半身宽的比例）
uniform float torso_edge_hi = 1.05;  // 到这里完全不动（手臂位置，避免手臂被推开）

// --- 极轻侧摆（待机惯性，几乎看不出）---
uniform float amp_sway = 0.003;

void vertex() {
	float t = clamp((VERTEX.y - base_y) / max(model_height, 0.001), 0.0, 1.0);

	// 1) 身体上下：脚底 0，往上平滑升到满幅；脚掌/脚踝完全不动
	float lift_w = smoothstep(lift_start, lift_full, t);
	VERTEX.y += breath * amp_lift * lift_w;

	// 2) 胸腔扩张：上下各有一道门，只在胸口这一段鼓起。
	// 注意必须写 u*u：GLSL 的 pow 在底数为负时未定义，会返回 NaN 把顶点坐标污染成无效值
	// （表现为模型只剩半个脑袋）。
	float u = (t - chest_center) / chest_width;
	float band = smoothstep(chest_lo, chest_hi, t) * (1.0 - smoothstep(chest_fade_from, chest_fade_to, t));
	// 横向衰减：只让躯干正面/侧面的表面鼓起，手臂（更外侧）几乎不动
	float ax = abs(VERTEX.x) / max(model_width * 0.5, 0.001);
	float torso = 1.0 - smoothstep(torso_edge_lo, torso_edge_hi, ax);
	float chest = exp(-u * u) * band * torso;
	VERTEX.xz *= 1.0 + breath * amp_chest * chest;

	// 3) 极轻侧摆，权重随高度增加
	float sway_w = smoothstep(0.35, 1.0, t);
	VERTEX.x += breath * amp_sway * sway_w;
}

void fragment() {
	// 颜色全部来自顶点色（线性空间），与导入时的观感保持一致
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.9;
	METALLIC = 0.0;
}

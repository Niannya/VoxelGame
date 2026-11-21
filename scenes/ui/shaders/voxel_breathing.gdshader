shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// ---- 呼吸（待机）效果 ----
// 只让上半身动，脚踝以下位移恒为 0，所以角色永远踩在地台顶面。
// breath 由脚本每帧写入 sin(时间)，取值 -1..1。

uniform float breath = 0.0;          // 呼吸相位 -1..1
uniform float base_y = 0.0;          // 模型空间里的脚底高度
uniform float model_height = 2.2;    // 模型空间里的身高
uniform float band_low = 0.40;       // 开始受影响的相对高度（0=脚底，1=头顶）
uniform float amp_chest = 0.026;     // 胸腔径向外扩（占半径比例）
uniform float amp_lift = 0.014;      // 上半身抬升（模型单位）
uniform float amp_sway = 0.005;      // 左右轻晃（模型单位）
uniform float chest_center = 0.72;   // 胸腔最强处（相对身高）
uniform float chest_width = 0.17;    // 胸腔影响范围

void vertex() {
	float t = clamp((VERTEX.y - base_y) / max(model_height, 0.001), 0.0, 1.0);
	// 腰以下不参与，越往上权重越大
	float w = smoothstep(band_low, 1.0, t);
	// 胸腔附近的隆起，用高斯包络，避免全身一起“胀”。
	// 注意：这里必须用 u*u，不能写 pow(u, 2.0) —— GLSL 的 pow 在底数为负时未定义，
	// 会返回 NaN，导致该高度以下的顶点坐标全变 NaN 被丢弃（表现为模型只剩半个脑袋）。
	float u = (t - chest_center) / chest_width;
	float chest = exp(-u * u);

	// 绕自身中轴做极小的径向膨胀（0 次幂保证只影响胸腰一段）
	VERTEX.xz *= 1.0 + breath * amp_chest * chest;
	// 上半身随吸气微微抬高
	VERTEX.y += breath * amp_lift * w * w;
	// 极轻微的左右晃动，越靠上越明显
	VERTEX.x += breath * amp_sway * w * w;
}

void fragment() {
	// 颜色全部来自顶点色（线性空间），与导入时的观感保持一致
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.9;
	METALLIC = 0.0;
}

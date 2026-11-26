// FX009 / FX010：绳索松弛 / 绷紧。
// 几何本身由 FxRope 程序化生成（4 段方形截面，贴体素风格），本着色器负责：
//   松弛：低频摆动 + 暗哑土黄 + 毛边磨损
//   绷紧：几乎不摆 + 亮化 + 高频张力条纹自发光
// 状态切换走同一个 taut 参数插值，所以能在 0.12s 内平滑过渡，不重建节点。
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 slack_color : source_color = vec4(0.42, 0.35, 0.27, 1.0);
uniform vec4 taut_color : source_color = vec4(0.90, 0.84, 0.66, 1.0);
uniform float taut : hint_range(0.0, 1.0) = 0.0;
uniform float wobble_amp = 0.018;
uniform float wobble_freq = 4.0;
uniform float stripes = 9.0;
uniform float stripe_speed = 2.2;
uniform float emit_energy = 1.5;

varying float vlen;

void vertex() {
	vlen = UV.y;                       // 0 起点 → 1 终点
	float bend = sin(vlen * 3.14159);  // 两端固定、中间最松
	float phase = vlen * wobble_freq * 6.28318 - TIME * mix(1.6, 8.0, taut);
	float amp = wobble_amp * bend * mix(1.0, 0.3, taut);
	VERTEX.x += sin(phase) * amp;
	VERTEX.z += cos(phase * 0.8) * amp * 0.7;
}

void fragment() {
	// 螺旋麻绳纹：沿长度 + 圆周错位
	float twist = fract(vlen * stripes - UV.x * 2.0);
	float band = smoothstep(0.55, 0.62, twist) - smoothstep(0.85, 0.92, twist);

	vec3 col = mix(slack_color.rgb, taut_color.rgb, taut * 0.55);
	col = mix(col, taut_color.rgb * 1.3, band * taut * 0.6);

	ALBEDO = col;
	ROUGHNESS = mix(0.96, 0.6, taut);
	EMISSION = taut_color.rgb * band * taut * emit_energy;
}

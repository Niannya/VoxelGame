// FX020：临界危险屏幕提示。
// 只染画面边缘（中央 clearance 半径留空），中央仍可正常操作（验收要求）。
// 不采样屏幕纹理，零额外开销，Compatibility / 移动端都可跑。
shader_type canvas_item;
render_mode blend_mix;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float critical : hint_range(0.0, 1.0) = 0.0;   // 越高心跳越快越明显
uniform vec4 danger_color : source_color = vec4(1.0, 0.18, 0.18, 1.0);
uniform float clearance : hint_range(0.0, 0.9) = 0.52; // 中央留空半径
uniform float aspect = 1.7778;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 p = (UV - 0.5) * vec2(aspect, 1.0);
	float d = length(p) * 2.0;

	// 边缘暗角
	float edge = smoothstep(clearance, 1.18, d);

	// 边缘碎土：往下滚的颗粒感，暗示"洞顶在掉东西"
	float grain = hash(floor(UV * vec2(190.0, 110.0) + vec2(0.0, floor(TIME * 26.0))));
	float spec = smoothstep(0.74, 1.0, grain) * smoothstep(clearance + 0.24, 1.05, d);

	// 心跳：临界时脉动，非临界时只做极缓呼吸
	float beat_rate = mix(0.85, 1.45, critical);
	float beat = 0.55 + 0.45 * sin(TIME * 6.28318 * beat_rate);

	float a = edge * (0.20 + 0.48 * intensity) * mix(1.0, beat, critical * 0.85);
	a += spec * 0.10 * intensity;

	COLOR = vec4(danger_color.rgb, clamp(a, 0.0, 0.9));
}

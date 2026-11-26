// FX011 / FX017 / FX024 / FX025：贴地扩散环 / 进度环 / 光柱底座。
// 一张朝上的四边形 + 纯程序化环形，零贴图。
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.0;   // 0 收紧 → 1 扩散到边
uniform vec4 color : source_color = vec4(1.0);
uniform float thickness : hint_range(0.01, 0.6) = 0.13;
uniform float strength : hint_range(0.0, 3.0) = 1.0;
uniform float fill : hint_range(0.0, 1.0) = 0.0;       // 进度环用：按角度填充
uniform float grit : hint_range(0.0, 1.0) = 0.35;      // 边缘碎点，避免死板

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float d = length(uv);
	float r = mix(0.10, 0.94, progress);
	float ring = 1.0 - smoothstep(0.0, thickness, abs(d - r));
	float fade = 1.0 - smoothstep(0.55, 1.0, progress) * 0.9;

	float ang = atan(uv.y, uv.x) / 6.28318530718 + 0.5;
	float mask = clamp(step(ang, fill) + step(fill, 0.001), 0.0, 1.0);

	float n = fract(sin(dot(floor(UV * 40.0), vec2(12.9898, 78.233))) * 43758.5453);
	float mottled = mix(1.0, 0.62 + 0.38 * n, grit);

	ALBEDO = color.rgb;
	ALPHA = clamp(ring * fade * strength * mask * mottled, 0.0, 1.0);
}

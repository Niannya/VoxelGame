// FX015 / FX016：支撑放置预览幽灵体。
// 可放置：青绿 + 条纹正向流动 + 呼吸 0.7Hz；不可放置：红 + 条纹反向 + 4Hz 急呼吸，
// 不只靠颜色区分（色弱 / 小屏也能读出"禁止"）。
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.31, 0.89, 0.76, 1.0);
uniform float alpha : hint_range(0.0, 1.0) = 0.3;
uniform float valid : hint_range(0.0, 1.0) = 1.0;
uniform float stripe_speed = 1.6;
uniform float stripe_density = 4.0;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;   // 代码驱动
uniform float rim : hint_range(0.0, 1.5) = 0.85;

void fragment() {
	vec3 n = normalize(NORMAL);
	float dir = mix(-1.0, 1.0, valid);

	// 斜条纹
	float s = fract((UV.x + UV.y) * stripe_density - TIME * stripe_speed * dir);
	float stripe = smoothstep(0.40, 0.48, s) - smoothstep(0.54, 0.62, s);

	// 顶面格线：让"占了几格"一眼可数
	float topness = step(0.55, n.y);
	float gx = smoothstep(0.90, 0.99, abs(sin(UV.x * 31.4159)));
	float gy = smoothstep(0.90, 0.99, abs(sin(UV.y * 31.4159)));
	float grid = topness * clamp(gx + gy, 0.0, 1.0);

	// 菲涅尔描边
	float fres = pow(1.0 - clamp(abs(dot(n, normalize(VIEW))), 0.0, 1.0), 2.0);

	float a = alpha + stripe * 0.34 + fres * rim + grid * 0.22;
	a *= mix(1.0, 0.40 + 0.60 * pulse, 1.0 - valid);

	ALBEDO = tint.rgb * (0.72 + stripe * 0.55 + grid * 0.45 + fres * 0.3);
	ALPHA = clamp(a, 0.0, 1.0);
}

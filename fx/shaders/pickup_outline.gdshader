// FX005：矿物可拾取高亮的外描边。
// 做法：复制一份同网格的副本，沿法线外扩 + 只渲染背面（cull_front），
// 得到一个干净的"呼吸描边"，完全不写矿物本体的 albedo —— 身份色不变（验收要求）。
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_front, shadows_disabled;

uniform vec4 glow : source_color = vec4(1.0, 0.96, 0.86, 1.0);
uniform float strength : hint_range(0.0, 2.0) = 0.7;
uniform float grow : hint_range(0.0, 0.12) = 0.018;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	VERTEX += NORMAL * grow;
}

void fragment() {
	ALBEDO = glow.rgb;
	ALPHA = strength * (0.45 + 0.55 * pulse);
}

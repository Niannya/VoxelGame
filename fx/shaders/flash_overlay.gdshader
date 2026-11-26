// FX001 / FX012 / FX013：叠加式闪白。
// 关键点：作为 material_overlay 叠加，不替换本体材质，因此原配色不会被冲掉。
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.97, 0.92, 1.0);
uniform float rim_boost : hint_range(0.0, 2.0) = 0.55;

void fragment() {
	if (intensity <= 0.004) {
		discard;
	}
	// 边缘更亮一点，闪的时候轮廓还在，俯视小角色才不会糊成一团白
	float rim = pow(1.0 - clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), 1.6);
	ALBEDO = flash_color.rgb;
	ALPHA = clamp(intensity * (0.82 + rim * rim_boost), 0.0, 1.0);
}

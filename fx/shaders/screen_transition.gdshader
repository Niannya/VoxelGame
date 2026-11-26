// FX023：失败画面转场。
// 三段式：去饱和 → 暗红压边 → 全黑。结尾留 0.25s 纯黑给结算界面淡入，避免闪跳。
// progress 由代码 tween，重开时 reset() 归零（验收要求"重开后正确复位"）。
shader_type canvas_item;
render_mode blend_mix;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint_color : source_color = vec4(0.07, 0.02, 0.02, 1.0);
uniform float desat : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec3 src = texture(screen_tex, SCREEN_UV).rgb;
	float luma = dot(src, vec3(0.299, 0.587, 0.114));

	vec3 col = mix(src, vec3(luma), desat * smoothstep(0.0, 0.42, progress));

	vec2 p = (SCREEN_UV - 0.5) * vec2(1.7778, 1.0);
	float vig = smoothstep(0.22, 0.62, progress) * smoothstep(0.15, 0.95, length(p) * 2.0) * 0.7;
	col = mix(col, tint_color.rgb * 1.6, vig);

	col = mix(col, tint_color.rgb, smoothstep(0.60, 1.0, progress));

	COLOR = vec4(col, smoothstep(0.0, 0.06, progress));
}

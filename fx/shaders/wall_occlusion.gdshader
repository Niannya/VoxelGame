// FX033：墙体遮挡淡化。
// 用 Bayer 4×4 屏幕门抖动淡出，而不是整体半透明：
//   · 不产生透明排序问题（矿洞里墙块层层叠叠，半透明会互相打架）
//   · 抖落后的墙仍有完整轮廓，角色位置依旧可读（验收要求"角色进入墙后仍可定位"）
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform float fade : hint_range(0.0, 1.0) = 0.0;        // 0 完全不透明，1 全淡出
uniform vec4 color_mul : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_nearest;
uniform bool use_tex = false;
uniform float ghost_tint : hint_range(0.0, 1.0) = 0.3;  // 淡化时偏向冷白，提示"这是被淡化的墙"

varying vec3 vcol;

float bayer2(vec2 a) { a = floor(a); return fract(a.x / 2.0 + a.y * a.y * 0.75); }
float bayer4(vec2 a) { return bayer2(0.5 * a) * 0.25 + bayer2(a); }

void vertex() {
	vcol = COLOR.rgb;
}

void fragment() {
	vec3 base = color_mul.rgb * vcol;
	if (use_tex) {
		base *= texture(albedo_tex, UV).rgb;
	}
	if (fade > 0.002) {
		float d = bayer4(FRAGCOORD.xy);
		if (d < fade * 0.96) {
			discard;
		}
		base = mix(base, vec3(0.88, 0.93, 1.0), fade * ghost_tint);
	}
	ALBEDO = base;
	ROUGHNESS = 0.95;
	SPECULAR = 0.12;
}

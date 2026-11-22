shader_type canvas_item;
// 透视贴合：把一张矩形纹理（通常是 SubViewport 的画面）贴到一个任意四边形上。
//
// 原理：CPU 端算出「屏幕像素 -> 纹理 uv」的单应矩阵（homography），
// 三行系数分别打包成 vec3 uniform，像素着色器里做一次投影除法就得到 uv。
// 因为整个 TextureRect 铺满屏幕，UV 就是屏幕归一化坐标，乘法用设计分辨率还原成像素。
//
// 四角以外的片元直接输出全透明，所以覆盖层不会挡住下面的内容。
//
// 可选的前后遮挡：use_occluder 打开后，再用一张遮罩（白色 = 被前景挡住）采样一次，
// 遮罩里是白色的地方就把字丢掉 —— 准备间用这个让角色站在 MINE 字样的上面。
// occlude_rect = 遮罩对应的贴图在屏幕上的摆放位置和尺寸（x, y, w, h），
// 所以遮罩按底图原始像素画就行，底图怎么挪都不用改遮罩。

uniform vec2 rect_size = vec2(1920.0, 1080.0);
uniform vec3 h0 = vec3(1.0, 0.0, 0.0);
uniform vec3 h1 = vec3(0.0, 1.0, 0.0);
uniform vec3 h2 = vec3(0.0, 0.0, 1.0);
uniform bool use_occluder = false;
uniform vec4 occlude_rect = vec4(0.0, 0.0, 1920.0, 1080.0);
uniform sampler2D occlude_tex : hint_default_transparent, filter_linear;

void fragment() {
	vec2 p = UV * rect_size;
	vec3 q = vec3(dot(h0, vec3(p, 1.0)), dot(h1, vec3(p, 1.0)), dot(h2, vec3(p, 1.0)));
	vec2 uv = q.xy / q.z;
	vec4 col = vec4(0.0);
	if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0) {
		bool hidden = false;
		if (use_occluder) {
			vec2 mp = (p - occlude_rect.xy) / occlude_rect.zw;
			if (mp.x >= 0.0 && mp.x <= 1.0 && mp.y >= 0.0 && mp.y <= 1.0) {
				hidden = texture(occlude_tex, mp).a > 0.5;
			}
		}
		if (!hidden) {
			col = texture(TEXTURE, uv);
		}
	}
	COLOR = col;
}

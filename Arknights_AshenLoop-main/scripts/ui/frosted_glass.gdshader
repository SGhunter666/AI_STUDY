shader_type canvas_item;

// 真毛玻璃着色器：读取屏幕背景纹理，做高斯模糊，
// 再叠加半透明色调，营造毛玻璃质感。
// Godot 4 推荐使用 hint_screen_texture uniform 声明屏幕纹理，
// 引擎会自动处理 BackBufferCopy。

uniform sampler2D screen_texture : hint_screen_texture;

uniform float blur_amount : hint_range(0.0, 8.0) = 2.4;
uniform vec4 tint_color : source_color = vec4(0.08, 0.11, 0.15, 0.42);
uniform float brightness : hint_range(0.5, 1.5) = 1.05;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 texel = blur_amount / SCREEN_PIXEL_SIZE;

	// 5x5 的高斯权重（简化为 13 点采样，兼顾性能与质量）
	float w0 = 0.227027;
	float w1 = 0.1945946;
	float w2 = 0.1216216;
	float w3 = 0.054054;
	float w4 = 0.016216;
	float total_weight = w0 + 2.0 * (w1 + w2 + w3 + w4);

	// 水平方向模糊
	vec4 col_h = texture(screen_texture, uv) * w0;
	col_h += texture(screen_texture, uv + vec2(texel.x * 1.0, 0.0)) * w1;
	col_h += texture(screen_texture, uv + vec2(texel.x * 2.0, 0.0)) * w2;
	col_h += texture(screen_texture, uv + vec2(texel.x * 3.0, 0.0)) * w3;
	col_h += texture(screen_texture, uv + vec2(texel.x * 4.0, 0.0)) * w4;
	col_h += texture(screen_texture, uv - vec2(texel.x * 1.0, 0.0)) * w1;
	col_h += texture(screen_texture, uv - vec2(texel.x * 2.0, 0.0)) * w2;
	col_h += texture(screen_texture, uv - vec2(texel.x * 3.0, 0.0)) * w3;
	col_h += texture(screen_texture, uv - vec2(texel.x * 4.0, 0.0)) * w4;
	col_h /= total_weight;

	// 垂直方向模糊
	vec4 col_v = texture(screen_texture, uv) * w0;
	col_v += texture(screen_texture, uv + vec2(0.0, texel.y * 1.0)) * w1;
	col_v += texture(screen_texture, uv + vec2(0.0, texel.y * 2.0)) * w2;
	col_v += texture(screen_texture, uv + vec2(0.0, texel.y * 3.0)) * w3;
	col_v += texture(screen_texture, uv + vec2(0.0, texel.y * 4.0)) * w4;
	col_v += texture(screen_texture, uv - vec2(0.0, texel.y * 1.0)) * w1;
	col_v += texture(screen_texture, uv - vec2(0.0, texel.y * 2.0)) * w2;
	col_v += texture(screen_texture, uv - vec2(0.0, texel.y * 3.0)) * w3;
	col_v += texture(screen_texture, uv - vec2(0.0, texel.y * 4.0)) * w4;
	col_v /= total_weight;

	// 混合水平+垂直模糊结果
	vec3 blurred = mix(col_h.rgb, col_v.rgb, 0.5) * brightness;

	// 叠加半透明色调
	COLOR = vec4(mix(blurred, tint_color.rgb, tint_color.a), 1.0);
}

shader_type canvas_item;

uniform vec3 color_top : source_color = vec3(0.027, 0.043, 0.086);
uniform vec3 color_bottom : source_color = vec3(0.09, 0.05, 0.16);
uniform vec3 glow_color : source_color = vec3(0.96, 0.77, 0.26);
uniform float glow_strength = 0.2;
uniform float time_scale = 0.12;

void fragment() {
	float shade = smoothstep(0.0, 1.0, UV.y);
	vec3 col = mix(color_top, color_bottom, shade);
	vec2 glow_a = UV - vec2(0.5 + sin(TIME * time_scale) * 0.06, 0.38);
	vec2 glow_b = UV - vec2(0.22 + cos(TIME * time_scale * 0.7) * 0.04, 0.78);
	float glow = exp(-dot(glow_a, glow_a) * 7.0) * glow_strength;
	float wash = exp(-dot(glow_b, glow_b) * 5.0) * glow_strength * 0.45;
	float streak = smoothstep(0.018, 0.0, abs(UV.y - 0.22 - sin(TIME * 0.08) * 0.03)) * 0.07;
	vec3 cool = vec3(0.45, 0.55, 0.95);
	COLOR = vec4(col + glow_color * (glow + wash) + cool * streak, 1.0);
}

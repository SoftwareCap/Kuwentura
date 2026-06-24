shader_type canvas_item;

// Avatar position as screen UV (0,0 = top-left, 1,1 = bottom-right)
uniform vec2 spotlight_uv = vec2(0.5, 0.5);
uniform float spotlight_radius   : hint_range(50.0, 800.0) = 200.0;
uniform float spotlight_softness : hint_range(10.0, 300.0) = 120.0;

void fragment() {
	vec2 screen_size = vec2(1.0) / SCREEN_PIXEL_SIZE;
	float dist = length((UV - spotlight_uv) * screen_size);
	float darkness = smoothstep(spotlight_radius, spotlight_radius + spotlight_softness, dist);
	COLOR = vec4(0.0, 0.0, 0.0, darkness);
}
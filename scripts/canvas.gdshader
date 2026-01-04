shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float infection_level : hint_range(0.0, 100.0) = 0.0;

void fragment() {
	vec2 fixed_uv = SCREEN_UV;
	
	// 1. Calculate Intensity (0.0 to 1.0) based on Infection
	// We only start glitching if infection is > 50.
	// (infection - 50) / 50 converts the range 50-100 into 0.0-1.0
	float intensity = max(0.0, (infection_level - 50.0) / 50.0);
	
	// If below 50% infection, just draw the normal screen and exit
	if (intensity <= 0.0) {
		COLOR = texture(screen_texture, fixed_uv);
	} else {
		// 2. Glitch Logic
		// 'shake_power' determines how far pixels move (stronger at higher infection)
		float shake_power = 0.05 * intensity; 
		
		// 'glitch_frequency' determines how often it happens (constant chaos at 100%)
		// We use TIME to make it animate
		float activation = sin(TIME * (10.0 + intensity * 20.0));
		
		// Only trigger the glitch during the "peaks" of the sine wave
		if (activation > (1.0 - (0.5 * intensity))) {
			
			// Create a jagged offset using a high-frequency sine wave
			float random_offset = sin(TIME * 100.0) * shake_power;
			
			// Separate the Color Channels (Chromatic Aberration)
			float r = texture(screen_texture, fixed_uv + vec2(random_offset, 0.0)).r;
			float g = texture(screen_texture, fixed_uv).g; // Green stays still
			float b = texture(screen_texture, fixed_uv - vec2(random_offset, 0.0)).b;
			
			COLOR = vec4(r, g, b, 1.0);
		} else {
			// In between glitches, draw normal screen
			COLOR = texture(screen_texture, fixed_uv);
		}
	}
}
shader_type canvas_item;

// Wall LOS map: R=1 receive PointLight2D, R=0 block light (invisible — no overpaint).
// Sample in layer-local pixels (MODEL_MATRIX × VERTEX − chunk_origin); TileMap VERTEX is tile-local.
// Defining light() replaces the built-in: must write LIGHT (LIGHT starts empty).
uniform sampler2D los_map : hint_default_white, filter_nearest, repeat_disable;
uniform vec2 chunk_origin_px = vec2(0.0);
uniform float tile_size_px = 16.0;
uniform float chunk_tiles = 64.0;

varying vec2 v_local_px;

void vertex() {
	vec2 world_px = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	v_local_px = world_px - chunk_origin_px;
}

void light() {
	float lx = floor(v_local_px.x / tile_size_px);
	float cell_y = floor(v_local_px.y / tile_size_px);
	float ly = chunk_tiles - 1.0 - cell_y;
	vec2 uv = (vec2(lx, ly) + vec2(0.5)) / chunk_tiles;
	float los = texture(los_map, uv).r;
	LIGHT = vec4(LIGHT_COLOR.rgb * COLOR.rgb * LIGHT_ENERGY * los, LIGHT_COLOR.a);
}

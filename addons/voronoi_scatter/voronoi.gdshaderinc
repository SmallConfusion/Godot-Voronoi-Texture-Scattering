#ifndef BASE_SCALE
	#define BASE_SCALE 1.0
#endif

#ifndef VORONOI_SCALE
	#define VORONOI_SCALE 1.0
#endif

#define VORONOI_INIT VoronoiSample __voronoi_sample = voronoi_sample(UV * BASE_SCALE);

#ifdef VORONOI_SCALE_RANDOM
	#define VORONOI_TEXTURE_SAMPLE(t) textureGrad(t, __voronoi_sample.uv, dFdx(UV.xy * __voronoi_sample.random_scale * (BASE_SCALE * VORONOI_SCALE)), dFdy(UV.xy * __voronoi_sample.random_scale * (BASE_SCALE * VORONOI_SCALE)))
#else
	#define VORONOI_TEXTURE_SAMPLE(t) textureGrad(t, __voronoi_sample.uv, dFdx(UV.xy * (BASE_SCALE * VORONOI_SCALE)), dFdy(UV.xy * (BASE_SCALE * VORONOI_SCALE)))
#endif

#ifdef VORONOI_ROTATION
	#define VORONOI_NORMAL_TEXTURE_SAMPLE(t) vec3(normal_rotate(__voronoi_sample.rotation_matrix, VORONOI_TEXTURE_SAMPLE(t).xy), 0.0)
#else
	#define VORONOI_NORMAL_TEXTURE_SAMPLE(t) VORONOI_TEXTURE_SAMPLE(t).xyz
#endif


struct VoronoiSample {
	vec2 uv;
#ifdef VORONOI_SCALE_RANDOM
	float random_scale;
#endif
#ifdef VORONOI_ROTATION
	mat2 rotation_matrix;
#endif
};

// https://github.com/skeeto/hash-prospector/issues/19
uint hash(uint x) {
	x ^= x >> 16u;
	x *= 0x21f0aaadu;
	x ^= x >> 15u;
	x *= 0x735a2d97u;
	x *= x >> 15u;
	return x;
}

float scale_uint(uint input) {
	return float(input) / float(0xffffffffu);
}

vec2 hashvec2(vec2 input) {
	uint hash1 = hash(hash(floatBitsToUint(input.y)) ^ floatBitsToUint(input.x));
	uint hash2 = hash(hash1);
	return vec2(scale_uint(hash1), scale_uint(hash2));
}

float hashvec2f(vec2 input) {
	return scale_uint(hash(hash(floatBitsToUint(input.x)) * floatBitsToUint(input.y)));
}

vec2 voronoi(vec2 point) {
	vec2 base_cell = floor(point);
	vec2 sample_offset = fract(point);

	float min_dist = 9999999.0;
	vec2 min_pos;

	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 cell = base_cell + vec2(float(i), float(j));
			vec2 cell_pos = cell + hashvec2(cell);
			vec2 to_cell = cell_pos - point;
			float dist = length(to_cell);

			float less = step(dist, min_dist);
			min_pos = cell_pos * less + min_pos * (1.0 - less);
			min_dist = min(dist, min_dist);
		}
	}

	return min_pos;
}

mat2 create_rotation_matrix(float a) {
	float csin = sin(a);
	float ccos = cos(a);

	return mat2(vec2(ccos, csin), vec2(-csin, ccos));
}

VoronoiSample voronoi_sample(vec2 uv) {
	vec2 vpos = voronoi(uv);
	vec2 uvpos = uv - vpos;

	uvpos *= VORONOI_SCALE;

#ifdef VORONOI_SCALE_RANDOM
	float random_scale = (hashvec2f(vpos + 1.618) - 0.5) * VORONOI_SCALE_RANDOM + 1.0;
	uvpos *= random_scale;
#endif

#ifdef VORONOI_ROTATION
	float rotation_amt = hashvec2f(vpos) * VORONOI_ROTATION;
	mat2 rotation_matrix = create_rotation_matrix(rotation_amt);
	uvpos = rotation_matrix * uvpos;

	#ifdef VORONOI_SCALE_RANDOM
		return VoronoiSample(uvpos, random_scale, rotation_matrix);
	#else
		return VoronoiSample(uvpos, rotation_matrix);
	#endif
#else
	#ifdef VORONOI_SCALE_RANDOM
		return VoronoiSample(uvpos, random_scale);
	#else
		return VoronoiSample(uvpos);
	#endif
#endif
}

vec2 normal_rotate(mat2 rotation_matrix, vec2 normal) {
	return (rotation_matrix * (normal * 2.0 - 1.0)) * 0.5 + 0.5;
}

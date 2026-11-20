// Céu de tempestade: degradê roxo/azul, nuvens em manchas com poucos tons e clarões de relâmpago.
shader_type sky;
uniform vec3 alto : source_color = vec3(0.14, 0.13, 0.3);
uniform vec3 meio : source_color = vec3(0.34, 0.34, 0.58);
uniform vec3 horizonte : source_color = vec3(0.62, 0.6, 0.72);
uniform vec3 nuvem_clara : source_color = vec3(0.7, 0.68, 0.82);
uniform vec3 nuvem_escura : source_color = vec3(0.26, 0.25, 0.42);
global uniform float relampago;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y); }
float fbm(vec2 p) { float a = 0.5, s = 0.0; for (int i = 0; i < 5; i++) { s += noise(p) * a; p *= 2.03; a *= 0.5; } return s; }
void sky() {
  float y = EYEDIR.y;
  vec3 c = mix(horizonte, meio, smoothstep(0.0, 0.25, y));
  c = mix(c, alto, smoothstep(0.25, 0.8, y));
  if (y > 0.0) {
    vec2 p = EYEDIR.xz / (y + 0.35) * 2.2 + vec2(TIME * 0.015, TIME * 0.008);
    float n = fbm(p);
    float d = fbm(p * 1.9 + 4.0);
    float k = n + (1.0 - y) * 0.12;
    // nuvens de tempestade em três tons chapados (claro na borda de cima, escuro embaixo)
    vec3 nv = mix(nuvem_escura, nuvem_clara, step(0.52, d));
    nv = mix(nv, mix(nuvem_escura, alto, 0.5), step(0.62, n));
    c = mix(c, nv, step(0.5, k));
  }
  c = mix(c, vec3(0.9, 0.9, 1.0), relampago * 0.6);
  COLOR = c;
}

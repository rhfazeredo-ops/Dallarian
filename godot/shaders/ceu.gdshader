// Céu limpo: degradê azul, sol em anéis e poucas nuvens brancas em manchas chapadas.
// O clarão de relâmpago continua disponível para um clima de tempestade (parâmetro global "relampago").
shader_type sky;
uniform vec3 alto : source_color = vec3(0.2, 0.42, 0.82);
uniform vec3 meio : source_color = vec3(0.42, 0.64, 0.94);
uniform vec3 horizonte : source_color = vec3(0.76, 0.86, 0.96);
uniform vec3 nuvem_clara : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 nuvem_base : source_color = vec3(0.82, 0.87, 0.96);
uniform vec3 dir_sol = vec3(0.45, 0.6, 0.35);
global uniform float relampago;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y); }
float fbm(vec2 p) { float a = 0.5, s = 0.0; for (int i = 0; i < 5; i++) { s += noise(p) * a; p *= 2.03; a *= 0.5; } return s; }
void sky() {
  float y = EYEDIR.y;
  vec3 c = mix(horizonte, meio, smoothstep(0.0, 0.25, y));
  c = mix(c, alto, smoothstep(0.25, 0.85, y));
  if (y > 0.0) {
    vec2 p = EYEDIR.xz / (y + 0.3) * 1.8 + vec2(TIME * 0.01, TIME * 0.004);
    float n = fbm(p);
    float d = fbm(p * 2.1 + 7.0);
    float k = step(0.6, n) * smoothstep(0.02, 0.1, y);
    vec3 nv = mix(nuvem_base, nuvem_clara, step(0.5, d + (n - 0.6) * 2.0));
    c = mix(c, nv, k);
  }
  float s = dot(EYEDIR, normalize(dir_sol));
  c = mix(c, mix(c, vec3(1.0, 0.95, 0.8), 0.35), step(0.992, s));
  c = mix(c, vec3(1.0, 0.98, 0.88), step(0.9985, s));
  c = mix(c, vec3(0.9, 0.9, 1.0), relampago * 0.6);
  COLOR = c;
}

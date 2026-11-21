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
global uniform float chuva;         // 0 = tempo bom, 1 = chovendo
global uniform float noite;          // 0 = dia, 1 = noite
global uniform vec3 luz_ambiente;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y); }
float fbm(vec2 p) { float a = 0.5, s = 0.0; for (int i = 0; i < 5; i++) { s += noise(p) * a; p *= 2.03; a *= 0.5; } return s; }
void sky() {
  float y = EYEDIR.y;
  vec3 c = mix(horizonte, meio, smoothstep(0.0, 0.25, y));
  c = mix(c, alto, smoothstep(0.25, 0.85, y));
  c = mix(c, vec3(0.5, 0.54, 0.6), chuva * 0.75);
  if (y > 0.0) {
    vec2 p = EYEDIR.xz / (y + 0.3) * 1.8 + vec2(TIME * 0.01, TIME * 0.004);
    float n = fbm(p);
    float d = fbm(p * 2.1 + 7.0);
    float k = step(0.6 - chuva * 0.32, n) * smoothstep(0.02, 0.1, y);
    vec3 nv = mix(nuvem_base, nuvem_clara, step(0.5, d + (n - 0.6) * 2.0));
    nv = mix(nv, mix(vec3(0.3, 0.32, 0.36), vec3(0.45, 0.47, 0.52), step(0.5, d)), chuva);
    c = mix(c, nv, k);
  }
  // noite: céu azul-marinho, nuvens escuras, estrelas em pixels e a lua; pôr do sol alaranjado no horizonte
  vec3 cn = mix(vec3(0.05, 0.07, 0.16), vec3(0.01, 0.015, 0.05), smoothstep(0.0, 0.7, y));
  float crep = clamp(1.0 - abs(noite - 0.5) * 2.0, 0.0, 1.0);
  vec3 cd = c * luz_ambiente;
  cd = mix(cd, vec3(1.0, 0.55, 0.3), crep * 0.65 * (1.0 - smoothstep(0.0, 0.35, abs(y))));
  c = mix(cd, cn, smoothstep(0.35, 0.95, noite));
  c = mix(c, vec3(0.08, 0.09, 0.11), chuva * smoothstep(0.35, 0.95, noite) * 0.8);   // noite chuvosa: céu fechado
  if (y > 0.0 && noite > 0.5 && chuva < 0.5) {
    vec2 g = floor(vec2(atan(EYEDIR.x, EYEDIR.z) * 260.0, asin(y) * 260.0));
    float h = hash(g);
    c += vec3(0.9, 0.92, 1.0) * step(0.9965, h) * (0.6 + 0.4 * sin(TIME * 2.0 + h * 90.0)) * smoothstep(0.5, 1.0, noite) * smoothstep(0.05, 0.2, y);
    float sl = dot(EYEDIR, normalize(vec3(-0.5, 0.55, -0.4)));
    c = mix(c, vec3(0.92, 0.94, 1.0), step(0.9975, sl) * smoothstep(0.5, 1.0, noite));
  }
  float s = dot(EYEDIR, normalize(dir_sol)) - noite - chuva;
  c = mix(c, mix(c, vec3(1.0, 0.95, 0.8), 0.35), step(0.992, s));
  c = mix(c, vec3(1.0, 0.98, 0.88), step(0.9985, s));
  c = mix(c, vec3(0.9, 0.9, 1.0), relampago * 0.6);
  COLOR = c;
}

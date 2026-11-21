// Chão em pixel splats: manchinhas gaussianas DEITADAS sobre o terreno (instâncias de MultiMesh), como
// pinceladas. Cor por instância, luz do sol pela inclinação do chão, neblina. Corte duro = opaco, sem ordenar.
// Tipo 1 (INSTANCE_CUSTOM.r) = água de poça: reflete o céu e as nuvens pela direção do olhar.
shader_type spatial;
render_mode unshaded, cull_disabled;
#include "res://shaders/noite.gdshaderinc"
uniform vec3 sol = vec3(0.45, 0.6, 0.35);
uniform vec3 luz_sol : source_color = vec3(0.95, 0.88, 0.72);
uniform vec3 luz_amb : source_color = vec3(0.5, 0.54, 0.64);
uniform vec3 neblina : source_color = vec3(0.74, 0.83, 0.94);
uniform float neb_ini = 40.0;
uniform float neb_fim = 270.0;
uniform float corte = 0.32;
// mesmas cores do céu (shaders/ceu.gdshader), para o reflexo das poças
uniform vec3 ceu_alto : source_color = vec3(0.2, 0.42, 0.82);
uniform vec3 ceu_meio : source_color = vec3(0.42, 0.64, 0.94);
uniform vec3 ceu_horiz : source_color = vec3(0.76, 0.86, 0.96);
global uniform float relampago;
varying vec3 cor;
varying float nb;
varying float agua;
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y); }
float fbm(vec2 p) { float a = 0.5, s = 0.0; for (int i = 0; i < 5; i++) { s += noise(p) * a; p *= 2.03; a *= 0.5; } return s; }
void vertex() {
  vec3 n = normalize(MODEL_MATRIX[1].xyz);
  agua = INSTANCE_CUSTOM.r;
  vec3 luz = luz_amb + luz_sol * max(dot(n, normalize(sol)), 0.0);
  cor = COLOR.rgb * mix(luz, vec3(1.0), agua) * (1.0 + relampago * 0.7);
  // perto da câmera as manchas encolhem (senão a perspectiva as deixa enormes perto dos pés)
  vec3 centro = MODEL_MATRIX[3].xyz;
  float dc = length(centro - CAMERA_POSITION_WORLD);
  float encolhe = agua > 0.5 ? 1.0 : mix(0.35, 1.0, smoothstep(1.2, 7.0, dc));
  wpos = (MODEL_MATRIX * vec4(VERTEX * vec3(encolhe, 1.0, encolhe), 1.0)).xyz;
  vec4 vp = VIEW_MATRIX * vec4(wpos, 1.0);
  POSITION = PROJECTION_MATRIX * vp;
  nb = clamp((length(vp.xyz) - neb_ini) / (neb_fim - neb_ini), 0.0, 1.0);
}
vec3 ceu(vec3 d) {
  float y = max(d.y, 0.0);
  vec3 c = mix(ceu_horiz, ceu_meio, smoothstep(0.0, 0.25, y));
  c = mix(c, ceu_alto, smoothstep(0.25, 0.85, y));
  vec2 p = d.xz / (y + 0.3) * 1.8 + vec2(TIME * 0.01, TIME * 0.004);
  float k = step(0.6, fbm(p)) * smoothstep(0.02, 0.1, y);
  return mix(c, vec3(0.95, 0.97, 1.0), k);
}
void fragment() {
  vec2 q = UV * 2.0 - 1.0;
  float g = exp(-dot(q, q) * 2.0);
  if (g < corte) discard;
  vec3 c = cor * (0.9 + 0.12 * step(0.66, g));          // miolo um pouco mais claro (pincelada)
  if (agua > 0.5) {
    vec3 olhar = normalize(wpos - CAMERA_POSITION_WORLD);
    vec3 r = reflect(olhar, vec3(0.0, 1.0, 0.0));
    r.xz += (vec2(noise(wpos.xz * 3.0 + TIME * 0.6), noise(wpos.zx * 3.0 - TIME * 0.5)) - 0.5) * 0.06;   // marolinha
    c = ceu(normalize(r)) * 0.82 + vec3(0.02, 0.03, 0.05);
  }
  ALBEDO = mix(noite_cor(c, (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz), noite_nevoa(neblina * (1.0 + relampago * 0.8)), nb);
}

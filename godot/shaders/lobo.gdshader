// Lobo (modelo do Tripo sem esqueleto): as partes são marcadas nas cores dos vértices pelo script lobo.gd
//   COLOR.r = perna (0 nenhuma, 0.25 dianteira esq., 0.5 dianteira dir., 0.75 traseira esq., 1 traseira dir.)
//   COLOR.g = peso do ombro/quadril, COLOR.b = peso do joelho, COLOR.a = 0.5 + cabeça(+) / cauda(-)
// e dobradas aqui no vertex shader (giros em volta de pivôs, no espaço do modelo: frente = +X, cima = +Y).
// Mesmo visual PS1 do resto: luz por vértice, vértices tremidos, neblina, dia e noite.
shader_type spatial;
render_mode unshaded, cull_disabled;
#include "res://shaders/noite.gdshaderinc"
uniform sampler2D tex : source_color, filter_nearest;
uniform vec3 neblina : source_color = vec3(0.74, 0.83, 0.94);
uniform vec2 grade = vec2(320.0, 180.0);
uniform vec3 sol = vec3(0.45, 0.6, 0.35);
uniform vec3 luz_sol : source_color = vec3(0.95, 0.88, 0.72);
uniform vec3 luz_amb : source_color = vec3(0.5, 0.54, 0.64);
global uniform float neb_ini;
global uniform float neb_fim;
uniform vec4 pivo_x;          // x do ombro/quadril de cada perna
uniform vec4 pivo_z;
uniform float y_quadril;
uniform float y_joelho;
uniform vec4 quadril;         // giro de cada perna (radianos; + = perna para a frente)
uniform vec4 joelho;          // dobra do joelho
uniform vec3 pivo_cab;
uniform vec2 cabeca;          // levantar (+) / virar
uniform vec3 pivo_cauda;
uniform vec2 cauda;           // levantar (-) / balançar
uniform float flash = 0.0;    // clarão quando apanha
global uniform float relampago;
global uniform float tremor_ps1;
varying vec3 luz;
varying float nb;
vec3 rotz(vec3 p, vec3 c, float a) { p -= c; float s = sin(a), k = cos(a); return vec3(p.x * k - p.y * s, p.x * s + p.y * k, p.z) + c; }
vec3 roty(vec3 p, vec3 c, float a) { p -= c; float s = sin(a), k = cos(a); return vec3(p.x * k + p.z * s, p.y, -p.x * s + p.z * k) + c; }
void vertex() {
  vec3 v = VERTEX;
  int id = int(round(COLOR.r * 4.0));
  if (id > 0) {
    int i = id - 1;
    vec3 q = vec3(pivo_x[i], y_quadril, pivo_z[i]);
    vec3 j = vec3(pivo_x[i], y_joelho, pivo_z[i]);
    v = rotz(v, j, joelho[i] * COLOR.b);
    v = rotz(v, q, quadril[i] * COLOR.g);
  }
  float h = COLOR.a * 2.0 - 1.0;
  if (h > 0.0) { v = roty(rotz(v, pivo_cab, cabeca.x * h), pivo_cab, cabeca.y * h); }
  else if (h < 0.0) { v = roty(rotz(v, pivo_cauda, cauda.x * -h), pivo_cauda, cauda.y * -h); }
  VERTEX = v;
  vec3 n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
  luz = luz_amb + luz_sol * max(dot(n, normalize(sol)), 0.0) + vec3(0.6, 0.65, 0.9) * relampago;
  vec4 vp = MODELVIEW_MATRIX * vec4(v, 1.0);
  nb = clamp((length(vp.xyz) - neb_ini) / (neb_fim - neb_ini), 0.0, 1.0);
  vec4 c = PROJECTION_MATRIX * vp;
  vec2 g = grade * 0.5;
  if (tremor_ps1 > 0.5) c.xy = round(c.xy / c.w * g) / g * c.w;   // tremido PS1 (opção no menu, desligado por padrão)
  POSITION = c;
}
void fragment() {
  vec3 c = texture(tex, UV).rgb * luz;
  c = mix(c, vec3(1.0, 0.85, 0.8), flash);
  ALBEDO = mix(noite_cor(c, (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz), noite_nevoa(neblina), nb);
}

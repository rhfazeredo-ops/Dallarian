#ifdef CONTORNO
#include "res://shaders/contorno.gdshaderinc"
#endif
#include "res://shaders/noite.gdshaderinc"
uniform sampler2D tex : source_color, filter_nearest;
uniform vec3 neblina : source_color = vec3(0.74, 0.83, 0.94);
uniform vec2 grade = vec2(320.0, 180.0);
uniform vec3 sol = vec3(0.45, 0.6, 0.35);
uniform vec3 luz_sol : source_color = vec3(0.95, 0.88, 0.72);
uniform vec3 luz_amb : source_color = vec3(0.5, 0.54, 0.64);
global uniform float neb_ini;
global uniform float neb_fim;
uniform float fase = 0.0;          // passo
uniform float anda = 0.0;          // 0..1
uniform float ataque = 0.0;        // 0..1: patas da frente levantadas
uniform float encolhe = 0.0;       // morte: patas dobram para dentro
uniform float flash = 0.0;
uniform vec3 pivo_e;               // raiz das patas (lado +Z)
global uniform float relampago;
global uniform float tremor_ps1;
varying vec3 luz;
varying float nb;
vec3 roty(vec3 p, vec3 c, float a) { p -= c; float s = sin(a), k = cos(a); return vec3(p.x * k + p.z * s, p.y, -p.x * s + p.z * k) + c; }
void vertex() {
  vec3 v = VERTEX;
  int id = int(round(COLOR.r * 8.0));
  float w = COLOR.g;
  if (id > 0) {
    int i = id - 1;                          // 0..3 lado +Z (de trás para a frente), 4..7 lado -Z
    float lado = i < 4 ? 1.0 : -1.0;
    int n = i % 4;
    vec3 piv = vec3(pivo_e.x, pivo_e.y, pivo_e.z * lado);
    float grupo = float((n + (i < 4 ? 0 : 1)) % 2);
    float ph = fase + grupo * 3.14159;
    v = roty(v, piv, sin(ph) * 0.32 * anda * lado * w);
    v.y += max(0.0, cos(ph)) * 0.09 * anda * w;
    if (n == 3) { v.y += ataque * 0.32 * w; v.x += ataque * 0.08 * w; }            // patas da frente sobem
    v = mix(v, piv + (v - piv) * 0.35 + vec3(0.0, 0.12, 0.0), encolhe * w);   // morte: encolhe
  }
  VERTEX = v;
  vec3 nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
  luz = luz_amb + luz_sol * max(dot(nrm, normalize(sol)), 0.0) + vec3(0.6, 0.65, 0.9) * relampago;
  vec4 vp = MODELVIEW_MATRIX * vec4(v, 1.0);
  nb = clamp((length(vp.xyz) - neb_ini) / (neb_fim - neb_ini), 0.0, 1.0);
#ifdef CONTORNO
  vp.xyz += normalize(vp.xyz) * 0.25;   // casca um pouco atrás: só aparece na borda, não por dentro
#endif
  vec4 c = PROJECTION_MATRIX * vp;
  vec2 g = grade * 0.5;
  if (tremor_ps1 > 0.5) c.xy = round(c.xy / c.w * g) / g * c.w;   // tremido PS1 (opção no menu, desligado por padrão)
#ifdef CONTORNO
  c = contorno_pos(c, NORMAL, MODELVIEW_MATRIX, PROJECTION_MATRIX, VIEWPORT_SIZE);
#endif
  POSITION = c;
}
void fragment() {
#ifdef CONTORNO
  ALBEDO = vec3(1.0);
#else
  vec3 c = texture(tex, UV).rgb * luz;
  c = mix(c, vec3(1.0, 0.85, 0.8), flash);
  ALBEDO = mix(noite_cor(c, (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz), noite_nevoa(neblina), nb);
#endif
}

// Visual de PlayStation 1: vértices presos a uma grade de tela baixa (tremem), luz calculada nos vértices,
// textura pequena sem suavização e neblina por distância. Sem sombras em tempo real (leve no celular).
shader_type spatial;
render_mode unshaded, cull_disabled;
#include "res://shaders/noite.gdshaderinc"
uniform sampler2D tex : source_color, filter_nearest, repeat_enable;
uniform bool usa_tex = true;
uniform vec4 cor : source_color = vec4(1.0);
uniform vec2 grade = vec2(320.0, 180.0);          // resolução da "grade" dos vértices
uniform vec3 sol = vec3(0.45, 0.6, 0.35);        // direção da luz (mundo)
uniform vec3 luz_sol : source_color = vec3(0.95, 0.88, 0.72);
uniform vec3 luz_amb : source_color = vec3(0.5, 0.54, 0.64);
uniform vec3 neblina : source_color = vec3(0.52, 0.54, 0.7);
global uniform float neb_ini;
global uniform float neb_fim;
uniform float escala_uv = 1.0;
global uniform float relampago;
varying vec3 luz;
varying float nb;
void vertex() {
  vec3 n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
  luz = luz_amb + luz_sol * max(dot(n, normalize(sol)), 0.0) + vec3(0.6, 0.65, 0.9) * relampago;
  luz *= COLOR.rgb;
  vec4 vp = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
  nb = clamp((length(vp.xyz) - neb_ini) / (neb_fim - neb_ini), 0.0, 1.0);
  // montanhas altas aparecem através da névoa (silhueta dos limites)
  nb *= 1.0 - smoothstep(14.0, 70.0, (MODEL_MATRIX * vec4(VERTEX, 1.0)).y) * 0.5;
  vec4 c = PROJECTION_MATRIX * vp;
  vec2 g = grade * 0.5;
  c.xy = round(c.xy / c.w * g) / g * c.w;            // "tremida" dos vértices
  POSITION = c;
  UV *= escala_uv;
}
void fragment() {
  vec3 base = cor.rgb * (usa_tex ? texture(tex, UV).rgb : vec3(1.0));
  vec3 c = base * luz;
  ALBEDO = mix(noite_cor(c, (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz), noite_nevoa(neblina * (1.0 + relampago * 0.8)), nb);
}

// Vegetação em "cartões" (alpha cards): retângulos planos com o desenho de um galho folhoso (fundo
// transparente), cruzados em volta do tronco. Corte duro do alfa (sem transparência = sem ordenar, leve),
// textura sem suavização (pixel), luz pela face do cartão em dois tons, cor por árvore, vento.
shader_type spatial;
render_mode unshaded, cull_disabled;
#include "res://shaders/noite.gdshaderinc"
uniform sampler2D tex : source_color, filter_nearest_mipmap, repeat_disable;
uniform vec3 sol = vec3(0.45, 0.6, 0.35);
uniform vec3 neblina : source_color = vec3(0.74, 0.83, 0.94);
uniform float neb_ini = 40.0;
uniform float neb_fim = 330.0;
uniform float vento = 1.0;
global uniform float relampago;
varying vec3 cor;
varying float nb;
void vertex() {
  vec3 raiz = MODEL_MATRIX[3].xyz;
  float alto = max(VERTEX.y, 0.0);
  // balanço: a copa toda devagar + cada cartão um pouco (pela posição do vértice)
  float b = sin(TIME * 1.1 + raiz.x * 0.21 + raiz.z * 0.17) * 0.012 * alto
          + sin(TIME * 3.2 + VERTEX.x * 2.0 + VERTEX.z * 1.7 + raiz.x) * 0.04 * smoothstep(1.0, 4.0, alto);
  vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz + vec3(b, 0.0, b * 0.7) * vento;
  vec3 n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
  float luz = abs(dot(n, normalize(sol)));
  cor = COLOR.rgb * mix(0.72, 1.12, step(0.42, luz)) * (1.0 + relampago * 0.7);
  vec4 vp = VIEW_MATRIX * vec4(w, 1.0);
  POSITION = PROJECTION_MATRIX * vp;
  nb = clamp((length(vp.xyz) - neb_ini) / (neb_fim - neb_ini), 0.0, 1.0);
}
void fragment() {
  vec4 t = texture(tex, UV);
  if (t.a < 0.5) discard;
  ALBEDO = mix(noite_cor(t.rgb * cor, (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz), noite_nevoa(neblina * (1.0 + relampago * 0.8)), nb);
}

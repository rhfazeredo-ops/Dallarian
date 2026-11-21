// Folhas de verdade: cada instância é um quadradinho fino (dupla face) virado para um lado qualquer,
// agrupado em tufos. Luz pela direção da face (dois tons), mais escura por dentro do tufo, balanço do vento.
shader_type spatial;
render_mode unshaded, cull_disabled;
#include "res://shaders/noite.gdshaderinc"
uniform vec3 sol = vec3(0.45, 0.6, 0.35);
uniform vec3 neblina : source_color = vec3(0.74, 0.83, 0.94);
uniform float neb_ini = 40.0;
uniform float neb_fim = 330.0;
global uniform float relampago;
varying vec3 cor;
varying float nb;
void vertex() {
  vec3 centro = MODEL_MATRIX[3].xyz;
  // vento: o tufo inteiro balança devagar (INSTANCE_CUSTOM.xyz = centro do tufo), cada folha treme
  vec3 tufo = INSTANCE_CUSTOM.xyz;
  float b = sin(TIME * 1.3 + tufo.x * 0.3 + tufo.z * 0.25) * 0.06 + sin(TIME * 5.0 + centro.x * 7.0 + centro.z * 5.0) * 0.015;
  vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz + vec3(b, 0.0, b * 0.6);
  vec3 n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
  float luz = abs(dot(n, normalize(sol)));            // as duas faces recebem luz
  float dentro = INSTANCE_CUSTOM.w;                   // 0 = borda do tufo, 1 = miolo
  cor = COLOR.rgb * mix(0.62, 1.12, step(0.45, luz)) * mix(1.0, 0.72, dentro) * (1.0 + relampago * 0.7);
  vec4 vp = VIEW_MATRIX * vec4(w, 1.0);
  POSITION = PROJECTION_MATRIX * vp;
  nb = clamp((length(vp.xyz) - neb_ini) / (neb_fim - neb_ini), 0.0, 1.0);
}
void fragment() {
  ALBEDO = mix(noite_cor(cor, (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz), noite_nevoa(neblina * (1.0 + relampago * 0.8)), nb);
}

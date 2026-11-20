// Pixel splats: manchinhas gaussianas voltadas para a câmera (instâncias de MultiMesh), cor por instância.
// Corte duro da gaussiana = opaco com profundidade: não precisa ordenar (leve, até com a câmera girando).
// "em_pe" = gira só em volta do eixo vertical (grama); senão, encara a câmera de todo jeito (folhas, nuvens).
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform bool em_pe = false;
uniform float corte = 0.3;
uniform vec3 neblina : source_color = vec3(0.52, 0.54, 0.7);
uniform float neb_ini = 40.0;
uniform float neb_fim = 330.0;
uniform float balanco = 0.0;      // vento (grama/folhas)
global uniform float relampago;
varying float nb;
varying vec3 cor;
void vertex() {
  vec3 centro = MODEL_MATRIX[3].xyz;
  float sx = length(MODEL_MATRIX[0].xyz), sy = length(MODEL_MATRIX[1].xyz);
  vec3 dir = INV_VIEW_MATRIX[0].xyz;
  vec3 cima = em_pe ? vec3(0.0, 1.0, 0.0) : INV_VIEW_MATRIX[1].xyz;
  if (em_pe) dir = normalize(vec3(dir.x, 0.0, dir.z));
  float vento = sin(TIME * 1.7 + centro.x * 0.31 + centro.z * 0.27) * balanco * (UV.y < 0.5 ? 1.0 : 0.0);
  vec3 w = centro + dir * (VERTEX.x * sx + vento) + cima * (VERTEX.y * sy);
  vec4 vp = VIEW_MATRIX * vec4(w, 1.0);
  nb = clamp((length(vp.xyz) - neb_ini) / (neb_fim - neb_ini), 0.0, 1.0);
  POSITION = PROJECTION_MATRIX * vp;
  cor = COLOR.rgb * (1.0 + relampago * 0.7);
}
void fragment() {
  vec2 q = UV * 2.0 - 1.0;
  float g = exp(-dot(q, q) * 2.0);
  if (g < corte) discard;
  vec3 c = cor * (0.82 + 0.18 * step(0.62, g));        // miolo um pouco mais claro, em dois tons
  ALBEDO = mix(c, neblina * (1.0 + relampago * 0.8), nb);
}

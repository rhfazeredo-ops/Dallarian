// Silhueta de peixe embaixo d'água: desenhada no próprio quadrado (corpo oval + cauda), em pixels grandes,
// escura e meio transparente. A cauda balança (INSTANCE_CUSTOM: x = fase, y = rapidez do nado, z = opacidade).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
global uniform vec3 luz_ambiente;
uniform vec3 cor : source_color = vec3(0.04, 0.07, 0.09);
varying vec3 cust;
void vertex() {
  cust = INSTANCE_CUSTOM.xyz;
  // visto de lado (da beira do rio) o quadrado deitado fica fininho: alarga a silhueta conforme o ângulo
  vec3 w = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
  vec3 v = normalize(w - INV_VIEW_MATRIX[3].xyz);
  VERTEX.z *= clamp(0.7 / max(abs(v.y), 0.05), 1.0, 4.0);
}
void fragment() {
  vec2 p = floor((UV * 2.0 - 1.0) * 9.0 + 0.5) / 9.0;         // pixels grandes
  p.y += sin(TIME * cust.y + cust.x + p.x * 2.6) * 0.16 * (0.6 - p.x * 0.5);
  float corpo = step(pow(p.x - 0.12, 2.0) / 0.42 + p.y * p.y / 0.09, 1.0);
  float cauda = step(-0.98, p.x) * step(p.x, -0.42) * step(abs(p.y), (-0.42 - p.x) * 0.75 + 0.04);
  float a = max(corpo, cauda);
  if (a < 0.5) discard;
  ALBEDO = cor * luz_ambiente;
  ALPHA = cust.z;
}

// Fogo: labaredas desenhadas no shader (sem textura), em quadrados que giram para a câmera em volta do eixo
// vertical. Ruído subindo deforma a chama (forma de gota que afina e balança), cores em faixas do miolo
// branco-amarelado até a ponta vermelha, em pixels grandes. Não escurece de noite (é a luz).
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform vec3 neblina : source_color = vec3(0.74, 0.83, 0.94);
uniform float neb_ini = 40.0;
uniform float neb_fim = 270.0;
uniform float pixels = 16.0;
varying float nb;
varying float fase;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y); }
void vertex() {
  vec3 centro = MODEL_MATRIX[3].xyz;
  float sx = length(MODEL_MATRIX[0].xyz), sy = length(MODEL_MATRIX[1].xyz);
  vec3 dir = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
  vec3 w = centro + dir * VERTEX.x * sx + vec3(0.0, 1.0, 0.0) * VERTEX.y * sy;
  fase = hash(centro.xz) * 20.0;
  vec4 vp = VIEW_MATRIX * vec4(w, 1.0);
  nb = clamp((length(vp.xyz) - neb_ini) / (neb_fim - neb_ini), 0.0, 1.0);
  POSITION = PROJECTION_MATRIX * vp;
}
void fragment() {
  vec2 g = vec2(pixels, pixels * 1.4);
  vec2 uv = floor(UV * g) / g;
  float y = 1.0 - uv.y;                       // 0 = base, 1 = ponta
  float x = uv.x * 2.0 - 1.0;
  float t = TIME;
  float n1 = noise(vec2(uv.x * 3.0 + fase, y * 2.6 - t * 2.4 - fase));
  float n2 = noise(vec2(uv.x * 7.0 - fase, y * 6.0 - t * 4.2));
  float balanco = (noise(vec2(fase, t * 1.3)) - 0.5) * 0.5 * y;
  float largura = pow(1.0 - y, 0.85) * (0.7 + 0.55 * n1);
  float forma = largura - abs(x + balanco + (n2 - 0.5) * 0.4 * y);
  float calor = forma * 2.2 + (1.0 - y) * 0.55 - n2 * 0.25;
  if (forma < 0.0 || calor < 0.12) discard;
  vec3 c = vec3(0.72, 0.16, 0.05);
  if (calor > 0.32) c = vec3(0.98, 0.42, 0.08);
  if (calor > 0.6) c = vec3(1.0, 0.74, 0.22);
  if (calor > 0.92) c = vec3(1.0, 0.95, 0.72);
  ALBEDO = mix(c, neblina, nb * 0.6);
}

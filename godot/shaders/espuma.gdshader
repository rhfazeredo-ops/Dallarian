// Espuma das beiradas d'água, em pixels grandes (UV.x = metros ao longo da margem, UV.y = 0 na água → 1 na margem):
//  modo 0 = ondas: cristas brancas que chegam até a margem e quebram em espuma (praia do mar, lago);
//  modo 1 = correnteza: riscos brancos que descem o rio, mais fortes perto da margem.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform int modo = 0;
uniform float velocidade = 1.0;
uniform float forca = 1.0;
uniform vec3 neblina : source_color = vec3(0.74, 0.83, 0.94);
uniform float neb_ini = 40.0;
uniform float neb_fim = 270.0;
global uniform vec3 luz_ambiente;
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y); }
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
  vec2 px = vec2(floor(UV.x * 4.0) / 4.0, floor(UV.y * 12.0) / 12.0);
  float t = TIME * velocidade;
  float a = 0.0;
  if (modo == 0) {
    float n = noise(vec2(px.x * 0.12, t * 0.05));
    float onda = fract(px.y * 1.1 - t * 0.2 + n * 0.7);              // a crista anda para a margem
    float crista = step(0.84, onda) * step(onda, 0.96) * step(0.3, noise(vec2(px.x * 0.35 + t * 0.2, floor(t * 0.2 + px.y))));
    float beira = step(0.8, px.y) * step(0.42, noise(vec2(px.x * 0.7, t * 0.7 + px.y * 2.0)));   // espuma na beira
    a = max(crista * (0.3 + 0.7 * smoothstep(0.3, 1.0, px.y)), beira);
  } else {
    // riscos finos e curtos que descem o rio, em "trilhas" estreitas; mais perto da margem
    float trilha = floor(UV.y * 9.0);
    float s = noise(vec2(px.x * 0.9 - t * 1.5 + trilha * 7.3, trilha * 1.9));
    a = step(0.66, s) * step(0.45, fract(UV.y * 9.0)) * (0.45 + 0.55 * px.y);
  }
  a *= forca;
  if (a < 0.3) discard;
  float nb = clamp((length(wpos - CAMERA_POSITION_WORLD) - neb_ini) / (neb_fim - neb_ini), 0.0, 1.0);
  ALBEDO = mix(vec3(0.93, 0.97, 1.0) * luz_ambiente, neblina * luz_ambiente, nb);
  ALPHA = (modo == 0 ? 0.8 : 0.6) * (1.0 - nb);
}

// Grama: tufos de folhas retangulares de ponta quadrada (malha), escuras na base e claras na ponta em degraus, balançando com o vento (mais na ponta) e se abrindo quando o jogador passa.
shader_type spatial;
render_mode unshaded, cull_disabled;
#include "res://shaders/noite.gdshaderinc"
uniform vec3 neblina : source_color = vec3(0.74, 0.83, 0.94);
uniform float neb_ini = 40.0;
uniform float neb_fim = 330.0;
uniform vec3 jogador = vec3(0.0, -100.0, 0.0);
uniform float vento = 1.0;
global uniform float relampago;
varying vec3 cor;
varying float nb;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y); }
void vertex() {
  vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
  vec3 raiz = MODEL_MATRIX[3].xyz;
  float h = UV.y;                       // 0 na base, 1 na ponta
  float k = h * h;
  // vento: rajadas que atravessam o campo + tremida rápida
  float raj = noise(raiz.xz * 0.12 + vec2(TIME * 0.35, TIME * 0.2));
  float tre = sin(TIME * 4.0 + raiz.x * 3.1 + raiz.z * 2.7 + UV.x * 2.0);
  w.xz += vec2(0.8, 0.45) * (raj * 0.32 + tre * 0.03) * k * vento * length(MODEL_MATRIX[1].xyz);
  // abre caminho para o jogador
  vec2 d = raiz.xz - jogador.xz;
  float dist = length(d);
  float empurra = (1.0 - smoothstep(0.2, 0.9, dist)) * step(abs(raiz.y - jogador.y), 1.5);
  w.xz += normalize(d + vec2(0.001)) * empurra * 0.4 * k * length(MODEL_MATRIX[1].xyz);
  w.y -= empurra * 0.25 * k * length(MODEL_MATRIX[1].xyz);
  vec4 vp = VIEW_MATRIX * vec4(w, 1.0);
  POSITION = PROJECTION_MATRIX * vp;
  nb = clamp((length(vp.xyz) - neb_ini) / (neb_fim - neb_ini), 0.0, 1.0);
  // cor: base escura (sombra entre as folhas), ponta clara e quente
  float hq = floor(h * 4.0 + 0.5) / 4.0;            // tons em degraus, sem degradê
  vec3 c = COLOR.rgb * mix(0.5, 1.18, hq);
  c = mix(c, c * vec3(1.08, 1.06, 0.86), smoothstep(0.75, 1.0, h));
  cor = c * (1.0 + raj * 0.12) * (1.0 + relampago * 0.7);
}
void fragment() {
  ALBEDO = mix(noite_cor(cor, (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz), noite_nevoa(neblina * (1.0 + relampago * 0.8)), nb);
}

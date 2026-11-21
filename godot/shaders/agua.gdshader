// Água (mar, pântano, rio e lago): reflete o céu e as nuvens pela direção do olhar, com marolas em pixels.
// No pântano (sul) fica verde-escura e turva.
shader_type spatial;
render_mode unshaded, cull_disabled;
#include "res://shaders/noite.gdshaderinc"
uniform vec3 neblina : source_color = vec3(0.74, 0.83, 0.94);
global uniform float neb_ini;
global uniform float neb_fim;
uniform vec3 ceu_alto : source_color = vec3(0.2, 0.42, 0.82);
uniform vec3 ceu_meio : source_color = vec3(0.42, 0.64, 0.94);
uniform vec3 ceu_horiz : source_color = vec3(0.76, 0.86, 0.96);
uniform vec3 fundo : source_color = vec3(0.12, 0.3, 0.42);
uniform vec3 pantano : source_color = vec3(0.2, 0.25, 0.14);
global uniform float relampago;
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y); }
float fbm(vec2 p) { float a = 0.5, s = 0.0; for (int i = 0; i < 4; i++) { s += noise(p) * a; p *= 2.03; a *= 0.5; } return s; }
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
vec3 ceu(vec3 d) {
  float y = max(d.y, 0.0);
  vec3 c = mix(ceu_horiz, ceu_meio, smoothstep(0.0, 0.25, y));
  c = mix(c, ceu_alto, smoothstep(0.25, 0.85, y));
  vec2 p = d.xz / (y + 0.3) * 1.8 + vec2(TIME * 0.01, TIME * 0.004);
  return mix(c, vec3(0.95, 0.97, 1.0), step(0.6, fbm(p)) * smoothstep(0.02, 0.1, y));
}
void fragment() {
  vec3 olhar = normalize(wpos - CAMERA_POSITION_WORLD);
  vec2 m = (vec2(noise(wpos.xz * 0.9 + TIME * 0.5), noise(wpos.zx * 0.9 - TIME * 0.4)) - 0.5);
  vec3 r = reflect(olhar, normalize(vec3(m.x * 0.25, 1.0, m.y * 0.25)));
  float fres = 0.35 + 0.65 * pow(1.0 - max(-olhar.y, 0.0), 3.0);      // olhando de cima vê mais o fundo
  vec3 c = mix(fundo, ceu(normalize(r)), fres);
  float pnt = smoothstep(380.0, 430.0, wpos.z);
  c = mix(c, mix(pantano, ceu(normalize(r)) * 0.45, fres * 0.5), pnt);
  c += step(0.78, noise(wpos.xz * 2.0 + TIME * 0.8)) * 0.06 * (1.0 - pnt);  // brilhos
  float nb = clamp((length(wpos - CAMERA_POSITION_WORLD) - neb_ini) / (neb_fim - neb_ini), 0.0, 1.0);
  ALBEDO = mix(noite_cor(c * (1.0 + relampago * 0.6), (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz), noite_nevoa(neblina), nb);
}

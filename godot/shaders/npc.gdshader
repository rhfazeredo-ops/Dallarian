// Morador (NPC) com skins por cor: a textura do modelo base é dividida em áreas pela cor de cada pixel
// (pele laranja, túnica bege, calça cinza, couro/cabelo marrom-escuro) e cada área ganha a cor sorteada do
// morador, mantendo o sombreado pintado. Visual PS1: vértices tremendo, luz por vértice, textura sem
// suavização, neblina.
shader_type spatial;
render_mode unshaded, cull_back;
uniform sampler2D tex : source_color, filter_nearest_mipmap;
uniform vec3 cor_pele : source_color = vec3(0.93, 0.62, 0.42);
uniform vec3 cor_tunica : source_color = vec3(0.86, 0.72, 0.52);
uniform vec3 cor_calca : source_color = vec3(0.45, 0.44, 0.47);
uniform vec3 cor_couro : source_color = vec3(0.42, 0.26, 0.15);
uniform vec3 cor_cabelo : source_color = vec3(0.4, 0.24, 0.12);
uniform vec2 grade = vec2(320.0, 180.0);
uniform vec3 sol = vec3(0.45, 0.6, 0.35);
uniform vec3 luz_sol : source_color = vec3(0.95, 0.88, 0.72);
uniform vec3 luz_amb : source_color = vec3(0.5, 0.54, 0.64);
uniform vec3 neblina : source_color = vec3(0.74, 0.83, 0.94);
uniform float neb_ini = 40.0;
uniform float neb_fim = 330.0;
varying vec3 luz;
varying vec2 regiao;     // COLOR.r = cabeça, COLOR.g = mãos (pelo peso dos ossos)
varying float nb;
vec3 hsv(vec3 c) {
  vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
  vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
  vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
  float d = q.x - min(q.w, q.y);
  return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}
void vertex() {
  regiao = COLOR.rg;
  vec3 n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
  luz = luz_amb + luz_sol * max(dot(n, normalize(sol)), 0.0);
  vec4 vp = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
  nb = clamp((length(vp.xyz) - neb_ini) / (neb_fim - neb_ini), 0.0, 1.0);
  vec4 c = PROJECTION_MATRIX * vp;
  vec2 g = grade * 0.5;
  c.xy = round(c.xy / c.w * g) / g * c.w;
  POSITION = c;
}
void fragment() {
  vec3 t = texture(tex, UV).rgb;
  vec3 h = hsv(t);
  // áreas: pela cor do pixel + pela parte do corpo (cabeça e mãos vêm do peso dos ossos)
  float cabeca = smoothstep(0.3, 0.7, regiao.x); float maos = smoothstep(0.3, 0.7, regiao.y);
  float cinza = 1.0 - smoothstep(0.38, 0.48, h.y);                    // calça (cinza-quente, pouco saturado)
  float escuro = (1.0 - smoothstep(0.44, 0.56, h.z)) * (1.0 - cinza);  // couro (cinto/botas) ou cabelo
  float claro = clamp(1.0 - cinza - escuro, 0.0, 1.0);                 // laranja-claro: pele ou túnica
  float pele = claro * max(cabeca, maos);
  float tunica = claro * (1.0 - max(cabeca, maos));
  float cabelo = escuro * cabeca; float couro = escuro * (1.0 - cabeca);
  float l = h.z;
  vec3 c = cor_calca * (l / 0.4) * cinza + cor_couro * (l / 0.38) * couro + cor_cabelo * (l / 0.38) * cabelo
         + cor_pele * (l / 0.88) * pele + cor_tunica * (l / 0.85) * tunica;
  ALBEDO = mix(c * luz, neblina, nb);
}

// TERRENO: o mesmo visual PS1, e nas partes íngremes (encostas e montanhas) a textura de ROCHA tirada do modelo
// da entrada da gruta (rocha clara com musgo), projetada de lado pela posição no mundo; neve por cima no alto.
// Visual de PlayStation 1: vértices presos a uma grade de tela baixa (tremem), luz calculada nos vértices,
// textura pequena sem suavização e neblina por distância. Sem sombras em tempo real (leve no celular).
shader_type spatial;
render_mode unshaded, cull_disabled;
#include "res://shaders/noite.gdshaderinc"
uniform sampler2D tex : source_color, filter_nearest_mipmap, repeat_enable;   // mipmap: longe não cintila
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
uniform sampler2D tex_rocha : source_color, filter_nearest_mipmap, repeat_enable;
uniform float tam_rocha = 7.0;                    // metros por repetição da rocha
varying vec3 luz0;                                // luz sem a cor do vértice (a rocha usa a cor da textura)
varying vec3 pmundo;
varying vec3 nmundo;
varying vec3 corv;
global uniform float relampago;
global uniform float tremor_ps1;
varying vec3 luz;
varying float nb;
void vertex() {
  vec3 n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
  luz = luz_amb + luz_sol * max(dot(n, normalize(sol)), 0.0) + vec3(0.6, 0.65, 0.9) * relampago;
  luz0 = luz; corv = COLOR.rgb;
  luz *= COLOR.rgb;
  pmundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; nmundo = n;
  vec4 vp = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
  nb = clamp((length(vp.xyz) - neb_ini) / (neb_fim - neb_ini), 0.0, 1.0);
  // montanhas altas aparecem através da névoa (silhueta dos limites)
  nb *= 1.0 - smoothstep(14.0, 70.0, (MODEL_MATRIX * vec4(VERTEX, 1.0)).y) * 0.5;
  vec4 c = PROJECTION_MATRIX * vp;
  vec2 g = grade * 0.5;
  if (tremor_ps1 > 0.5) c.xy = round(c.xy / c.w * g) / g * c.w;   // tremido PS1 (opção no menu, desligado por padrão)            // "tremida" dos vértices
  POSITION = c;
  UV *= escala_uv;
}
void fragment() {
  vec3 base = cor.rgb * (usa_tex ? texture(tex, UV).rgb : vec3(1.0));
  vec3 c = base * luz;
  vec3 nn = normalize(nmundo);
  float pedra = 1.0 - smoothstep(0.62, 0.8, nn.y);                              // íngreme → rocha
  if (pedra > 0.0) {
    vec2 uvr = (abs(nn.x) > abs(nn.z) ? pmundo.zy : pmundo.xy) / tam_rocha;
    vec3 r = texture(tex_rocha, uvr).rgb * 1.05;
    r = mix(r, vec3(0.92, 0.94, 0.98), smoothstep(42.0, 52.0, pmundo.y) * 0.85);  // neve no alto
    c = mix(c, r * luz0, pedra);
  }
  ALBEDO = mix(noite_cor(c, (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz), noite_nevoa(neblina * (1.0 + relampago * 0.8)), nb);
}

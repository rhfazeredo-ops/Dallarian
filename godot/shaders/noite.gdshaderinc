// Dia e noite: luz ambiente (branca de dia, alaranjada no pôr do sol, azul-escura de noite) e a luz quente
// das lanternas/fogueiras mais perto da câmera (até 6, xyz = posição, w = força). Tudo vem do script mundo.gd.
global uniform vec3 luz_ambiente;
global uniform vec4 lanterna0;
global uniform vec4 lanterna1;
global uniform vec4 lanterna2;
global uniform vec4 lanterna3;
global uniform vec4 lanterna4;
global uniform vec4 lanterna5;
float _lant(vec4 l, vec3 p) { float d = length(p - l.xyz) / 9.0; float k = max(0.0, 1.0 - d); return l.w * k * k; }
vec3 noite_cor(vec3 c, vec3 p) {
  float q = _lant(lanterna0, p) + _lant(lanterna1, p) + _lant(lanterna2, p) + _lant(lanterna3, p) + _lant(lanterna4, p) + _lant(lanterna5, p);
  q = floor(min(q, 1.2) * 6.0 + 0.5) / 6.0;          // luz em faixas (cara de pixel art)
  return c * (luz_ambiente + vec3(1.0, 0.62, 0.3) * q * 1.3);
}
vec3 noite_nevoa(vec3 n) { return n * luz_ambiente; }

// Contorno branco de "selecionado" (corpo de monstro com saque na mira). Passe extra (next_pass) com a mesma
// deformação do corpo: a casca cresce alguns pixels na direção da normal e só as faces de trás são desenhadas.
uniform float espessura_contorno = 2.0;      // em pixels da imagem 3D
vec4 contorno_pos(vec4 c, vec3 n, mat4 mv, mat4 pr, vec2 tela) {
  vec3 nv = normalize((mv * vec4(n, 0.0)).xyz);
  vec2 d = (pr * vec4(nv, 0.0)).xy;
  float l = length(d);
  if (l > 1e-5) c.xy += d / l * espessura_contorno * 2.0 / tela * c.w;
  return c;
}

// Filtro final (sobre a imagem 3D em resolução baixa): paleta reduzida com pontilhado Bayer 4x4.
shader_type canvas_item;
uniform float niveis = 9.0;
uniform float forca_pontilhado = 0.7;
float bayer4(vec2 p) {
  ivec2 q = ivec2(mod(p, 4.0));
  int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
  return (float(m[q.y * 4 + q.x]) + 0.5) / 16.0 - 0.5;
}
void fragment() {
  vec3 c = texture(TEXTURE, UV).rgb;
  vec2 px = floor(UV / TEXTURE_PIXEL_SIZE);
  c += bayer4(px) * forca_pontilhado / niveis;
  c = floor(c * niveis + 0.5) / niveis;
  COLOR = vec4(c, 1.0);
}

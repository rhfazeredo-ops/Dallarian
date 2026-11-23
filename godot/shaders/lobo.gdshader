// Lobo (modelo do Tripo sem esqueleto): as partes são marcadas nas cores dos vértices pelo script lobo.gd
//   COLOR.r = perna (0 nenhuma, 0.25 dianteira esq., 0.5 dianteira dir., 0.75 traseira esq., 1 traseira dir.)
//   COLOR.g = peso do ombro/quadril, COLOR.b = peso do joelho, COLOR.a = 0.5 + cabeça(+) / cauda(-)
// e dobradas aqui no vertex shader (giros em volta de pivôs, no espaço do modelo: frente = +X, cima = +Y).
// Mesmo visual PS1 do resto: luz por vértice, vértices tremidos, neblina, dia e noite.
shader_type spatial;
render_mode unshaded, cull_disabled;
#include "res://shaders/lobo_corpo.gdshaderinc"

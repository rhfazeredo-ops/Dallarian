// Aranha (modelo do Tripo sem esqueleto): as 8 patas são marcadas nas cores dos vértices pelo script aranha.gd
//   COLOR.r = pata (0 corpo, 1..8), COLOR.g = peso (0 na raiz da pata → 1 na ponta).
// Andar em dois grupos alternados (L1 R2 L3 R4 / R1 L2 R3 L4): a pata gira para a frente levantada e volta no chão.
shader_type spatial;
render_mode unshaded, cull_disabled;
#include "res://shaders/aranha_corpo.gdshaderinc"

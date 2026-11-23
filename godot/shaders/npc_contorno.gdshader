// Passe do contorno branco (ver contorno.gdshaderinc)
shader_type spatial;
render_mode unshaded, cull_front;
#define CONTORNO
#include "res://shaders/npc_corpo.gdshaderinc"

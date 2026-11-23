// Morador (NPC) com skins por cor: a textura do modelo base é dividida em áreas pela cor de cada pixel
// (pele laranja, túnica bege, calça cinza, couro/cabelo marrom-escuro) e cada área ganha a cor sorteada do
// morador, mantendo o sombreado pintado. Visual PS1: vértices tremendo, luz por vértice, textura sem
// suavização, neblina.
shader_type spatial;
render_mode unshaded, cull_back;
#include "res://shaders/npc_corpo.gdshaderinc"

# animação do cavalo de blocos: parado (respira, mexe a cabeça e a cauda) ou andando/galopando conforme "vel"
extends Node
var vel := 0.0
var inclinar := 0.0          # montado: cabeça um pouco mais baixa (a Rachel enxerga por cima)
var _t := 0.0
func _process(delta: float) -> void:
	var c: Node3D = get_parent()
	if not c.is_visible_in_tree(): return
	_t += delta
	var f := _t * (2.0 + vel * 0.9)
	var a := clampf(vel / 5.0, 0.0, 1.0)
	for i in 4:
		var p: Node3D = c.get_node("Perna%d" % i)
		var fase := 0.0 if (i == 0 or i == 3) else PI            # trote: pares em diagonal
		p.rotation.x = sin(f + fase) * 0.55 * a
	var pes: Node3D = c.get_node("Pescoco")
	pes.rotation.x = inclinar + sin(f * 2.0) * 0.06 * a + (sin(_t * 0.7) * 0.12 - 0.1) * (1.0 - a)
	c.get_node("Cauda").rotation.z = sin(_t * 1.6) * 0.25
	c.get_node("Cauda").rotation.x = 0.35 + 0.3 * a

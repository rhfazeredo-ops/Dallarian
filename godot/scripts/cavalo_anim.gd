# animação do cavalo: parado (respira, mexe a cabeça e a cauda) ou andando/galopando conforme "vel".
# Cavalo de blocos: mexe patas, pescoço e cauda. Modelo do Tripo (ainda sem rig): o corpo todo balança no ritmo
# do passo (sobe e desce, inclina para a frente e para trás) e respira devagar quando parado.
extends Node
var vel := 0.0
var inclinar := 0.0          # montado: cabeça um pouco mais baixa (a Rachel enxerga por cima)
var _t := 0.0
var _base := Vector3.ZERO
var _modelo: Node3D
func _ready() -> void:
	_modelo = get_parent().get_node_or_null("Modelo")
	if _modelo: _base = _modelo.position
func _process(delta: float) -> void:
	var c: Node3D = get_parent()
	if not c.is_visible_in_tree(): return
	_t += delta
	var a := clampf(vel / 5.0, 0.0, 1.0)
	if _modelo:
		var f := _t * (1.0 + vel * 0.75)
		var galope := clampf((vel - 6.0) / 4.0, 0.0, 1.0)
		var sobe := absf(sin(f * PI)) * lerpf(0.05, 0.12, galope) * a + sin(_t * 1.3) * 0.006 * (1.0 - a)
		_modelo.position = _base + Vector3(0, sobe, 0)
		_modelo.rotation.z = sin(f * PI) * lerpf(0.015, 0.05, galope) * a     # balanço para a frente e para trás
		_modelo.rotation.x = sin(f * PI * 0.5) * 0.012 * a                    # um pouco de lado a lado
		return
	var f2 := _t * (2.0 + vel * 0.9)
	for i in 4:
		var p: Node3D = c.get_node("Perna%d" % i)
		var fase := 0.0 if (i == 0 or i == 3) else PI            # trote: pares em diagonal
		p.rotation.x = sin(f2 + fase) * 0.55 * a
	var pes: Node3D = c.get_node("Pescoco")
	pes.rotation.x = inclinar + sin(f2 * 2.0) * 0.06 * a + (sin(_t * 0.7) * 0.12 - 0.1) * (1.0 - a)
	c.get_node("Cauda").rotation.z = sin(_t * 1.6) * 0.25
	c.get_node("Cauda").rotation.x = 0.35 + 0.3 * a

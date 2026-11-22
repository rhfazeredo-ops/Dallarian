# animação do cavalo, conforme "vel" (m/s):
#  - modelo do Tripo com o rig automático (RigCavalo): patas em trote (pares em diagonal), canela dobra ao levantar
#    a pata, pescoço balança no passo e o rabo mexe; parado respira, mexe a cabeça e o rabo devagar;
#  - cavalo de blocos (provisório): mexe os nós das patas, do pescoço e da cauda.
extends Node
var vel := 0.0
var inclinar := 0.0          # montado: cabeça um pouco mais baixa (a Rachel enxerga por cima)
var _t := 0.0
var _fase := 0.0
var _base := Vector3.ZERO
var _modelo: Node3D
var _esq: Skeleton3D
const FASES := [0.0, PI, PI, 0.0]          # frente-esq, frente-dir, trás-esq, trás-dir (trote em diagonal)
func _ready() -> void:
	_modelo = get_parent().get_node_or_null("Modelo")
	if _modelo:
		_base = _modelo.position
		var l := _modelo.find_children("Esqueleto", "Skeleton3D", true, false)
		if not l.is_empty(): _esq = l[0]
func _q(eixo: Vector3, ang: float) -> Quaternion: return Quaternion(eixo, ang)
func _process(delta: float) -> void:
	var c: Node3D = get_parent()
	if not c.is_visible_in_tree(): return
	_t += delta
	var a := clampf(vel / 4.0, 0.0, 1.0)
	_fase = fmod(_fase + delta * TAU * maxf(vel, 0.0) / 2.6, TAU * 100.0)     # ~2,6 m por passada
	if _modelo:
		var galope := clampf((vel - 7.0) / 4.0, 0.0, 1.0)
		var sobe := absf(sin(_fase)) * lerpf(0.02, 0.06, galope) * a + sin(_t * 1.3) * 0.004 * (1.0 - a)
		_modelo.position = _base + Vector3(0, sobe, 0)
		_modelo.rotation.z = sin(_fase * 2.0) * 0.01 * a
		if _esq == null: return
		var amp := lerpf(0.42, 0.55, galope) * a
		for k in 4:
			var ph: float = _fase + FASES[k]
			_esq.set_bone_pose_rotation(RigCavalo.COXA[k], _q(Vector3(0, 0, 1), sin(ph) * amp))
			var dobra := maxf(0.0, cos(ph)) * a * (1.0 if k < 2 else 0.7)       # dobra o joelho quando a pata vai à frente
			_esq.set_bone_pose_rotation(RigCavalo.CANELA[k], _q(Vector3(0, 0, 1), -dobra * lerpf(0.9, 1.3, galope)))
		var cab := inclinar * 0.25 + sin(_fase * 2.0) * 0.05 * a + (sin(_t * 0.6) * 0.07 - 0.02) * (1.0 - a)
		_esq.set_bone_pose_rotation(RigCavalo.PESCOCO, _q(Vector3(0, 0, 1), cab) * _q(Vector3(0, 1, 0), sin(_t * 0.37) * 0.12 * (1.0 - a)))
		_esq.set_bone_pose_rotation(RigCavalo.CAUDA, _q(Vector3(1, 0, 0), sin(_t * 1.7) * lerpf(0.18, 0.08, a)) * _q(Vector3(0, 0, 1), -0.35 * a))
		return
	var f2 := _t * (2.0 + vel * 0.9)
	for i in 4:
		var p: Node3D = c.get_node("Perna%d" % i)
		var fase := 0.0 if (i == 0 or i == 3) else PI
		p.rotation.x = sin(f2 + fase) * 0.55 * a
	var pes: Node3D = c.get_node("Pescoco")
	pes.rotation.x = inclinar + sin(f2 * 2.0) * 0.06 * a + (sin(_t * 0.7) * 0.12 - 0.1) * (1.0 - a)
	c.get_node("Cauda").rotation.z = sin(_t * 1.6) * 0.25
	c.get_node("Cauda").rotation.x = 0.35 + 0.3 * a

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
const GALOPE := [0.0, 0.6, PI, PI + 0.6]   # galope: frente juntas, depois trás juntas
# passo em 4 tempos: trás-esq, frente-esq, trás-dir, frente-dir (cada uma 1/4 de passada depois da anterior)
const PASSO := [-TAU * 0.25, -TAU * 0.75, 0.0, -TAU * 0.5]
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
	# andaduras (como num cavalo de verdade): PASSO em 4 tempos (uma pata de cada vez) até ~4 m/s, TROTE (diagonais)
	# por volta de 6–8 m/s e GALOPE (frente juntas, depois trás) correndo. A passada cresce com a velocidade, então o
	# ritmo fica calmo: no passo ~0,9 passadas/s, no galope ~1,7.
	var trote := smoothstep(3.0, 5.5, vel) * (1.0 - smoothstep(8.5, 10.5, vel))
	var galope := smoothstep(8.5, 10.5, vel)
	var passada := lerpf(lerpf(3.4, 4.6, smoothstep(3.0, 6.0, vel)), 6.8, galope)
	_fase = fmod(_fase + delta * TAU * maxf(vel, 0.0) / passada, TAU * 100.0)
	if _modelo:
		var balanco := sin(_fase * 2.0)                                  # passo/trote: dois apoios por passada
		var sobe := (absf(balanco) * lerpf(0.012, 0.03, trote) * (1.0 - galope) + (0.5 + 0.5 * sin(_fase)) * 0.06 * galope) * a
		sobe += sin(_t * 1.3) * 0.004 * (1.0 - a)
		_modelo.position = _base + Vector3(0, sobe, 0)
		_modelo.rotation.z = (balanco * 0.006 * (1.0 - galope) + sin(_fase) * 0.035 * galope) * a
		_modelo.rotation.x = sin(_fase) * 0.012 * (1.0 - trote - galope) * a         # no passo o corpo gira de leve
		if _esq == null: return
		var amp := lerpf(lerpf(0.36, 0.42, trote), 0.55, galope) * a
		for k in 4:
			var off: float = lerpf(lerpf(PASSO[k], FASES[k], trote), GALOPE[k], galope)
			var u := fposmod((_fase + off) / TAU, 1.0)
			var apoio := lerpf(lerpf(0.64, 0.5, trote), 0.42, galope)       # parte da passada com a pata no chão
			var ang: float; var dobra: float
			if u < apoio:                                                    # no chão: vai da frente para trás, reta
				var v := u / apoio
				ang = lerpf(1.0, -1.0, v); dobra = 0.05
			else:                                                            # no ar: levanta dobrando e volta rápido
				var v := (u - apoio) / (1.0 - apoio)
				ang = lerpf(-1.0, 1.0, smoothstep(0.0, 1.0, v)); dobra = sin(v * PI)
			var forca_dobra := (1.25 if k < 2 else 0.8) * lerpf(1.0, 1.15, galope)
			_esq.set_bone_pose_rotation(RigCavalo.COXA[k], _q(Vector3(0, 0, 1), ang * amp + (0.18 if k >= 2 else 0.0) * dobra * a))
			_esq.set_bone_pose_rotation(RigCavalo.CANELA[k], _q(Vector3(0, 0, 1), -dobra * forca_dobra * a))
		var cab := inclinar * 0.25 + lerpf(sin(_fase * 2.0 + 0.8) * lerpf(0.06, 0.03, trote), sin(_fase + 0.6) * 0.07, galope) * a   # a cabeça acompanha cada passo + (sin(_t * 0.6) * 0.07 - 0.02) * (1.0 - a)
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

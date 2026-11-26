# animação do cavalo da Synty (o pacote não traz animação): mexe os ossos do esqueleto conforme "vel" (m/s).
# Andaduras como num cavalo de verdade: PASSO em 4 tempos até ~4 m/s, TROTE (diagonais) por volta de 6–8 m/s e
# GALOPE (trás juntas, depois frente) correndo; parado respira, mexe a cabeça e o rabo devagar.
# Cada pata: osso de cima (coxa/braço), o do meio (canela) e o de baixo (quartela). Os giros são em volta do eixo
# do lado do cavalo (no espaço do modelo), convertidos para o espaço de cada osso.
extends Node
var vel := 0.0
var inclinar := 0.0          # montado: cabeça um pouco mais baixa (a Rachel enxerga por cima)
var _t := 0.0
var _fase := 0.0
var _base := Vector3.ZERO
var _modelo: Node3D
var _esq: Skeleton3D
const FASES := [0.0, PI, PI, 0.0]          # frente-esq, frente-dir, trás-esq, trás-dir (trote em diagonal)
# galope (pelo vídeo de referência, quadro a quadro): trás-esq e trás-dir apoiam primeiro, uma logo depois da outra,
# e em seguida frente-esq e frente-dir; entre a frente sair do chão e as de trás chegarem, o cavalo "voa"
const GALOPE := [0.0, -TAU * 0.1, -TAU * 0.55, -TAU * 0.65]
# passo em 4 tempos: trás-esq, frente-esq, trás-dir, frente-dir (cada uma 1/4 de passada depois da anterior)
const PASSO := [-TAU * 0.25, -TAU * 0.75, 0.0, -TAU * 0.5]
const OSSOS := [["Horsi_ L UpperArm", "Horsi_ L Forearm", "Horsi_ L Hand"], ["Horsi_ R UpperArm", "Horsi_ R Forearm", "Horsi_ R Hand"],
	["Horsi_ L Thigh", "Horsi_ L Calf", "Horsi_ L HorseLink"], ["Horsi_ R Thigh", "Horsi_ R Calf", "Horsi_ R HorseLink"]]
var _pata := []              # [osso, rotação de descanso, eixo do lado no espaço do osso] × 3, por pata
var _pescoco := []
var _cabeca := []
var _rabo := []              # [osso, descanso, eixo do lado, eixo da frente]

func _ready() -> void:
	_modelo = get_parent().get_node_or_null("Modelo")
	if _modelo == null: return
	_base = _modelo.position
	var l := _modelo.find_children("*", "Skeleton3D", true, false)
	if l.is_empty(): return
	_esq = l[0]
	for p in OSSOS:
		var lista := []
		for n in p: lista.append(_osso(n))
		_pata.append(lista)
	_pescoco = _osso("Horsi_ Neck"); _cabeca = _osso("Horsi_ Head"); _rabo = _osso("Horsi_ Tail")

# eixo do lado (-X do modelo: girar positivo leva a pata para a frente, +Z) e da frente, no espaço local do osso
func _osso(nome: String) -> Array:
	var i := _esq.find_bone(nome)
	var g := _esq.get_bone_global_rest(i).basis.orthonormalized().inverse()
	return [i, _esq.get_bone_rest(i).basis.get_rotation_quaternion(), (g * Vector3(-1, 0, 0)).normalized(), (g * Vector3(0, 0, 1)).normalized()]

func _girar(o: Array, ang: float, ang_frente := 0.0) -> void:
	if o.is_empty() or o[0] < 0: return
	_esq.set_bone_pose_rotation(o[0], o[1] * Quaternion(o[2], ang) * Quaternion(o[3], ang_frente))

func _physics_process(delta: float) -> void:     # no ritmo da física (a interpolação suaviza)
	var c: Node3D = get_parent()
	if not c.is_visible_in_tree() or _modelo == null: return
	_t += delta
	var a := clampf(vel / 4.0, 0.0, 1.0)
	var trote := smoothstep(3.0, 5.5, vel) * (1.0 - smoothstep(8.5, 10.5, vel))
	var galope := smoothstep(8.5, 10.5, vel)
	var passada := lerpf(lerpf(3.4, 4.6, smoothstep(3.0, 6.0, vel)), 5.8, galope)
	_fase = fmod(_fase + delta * TAU * maxf(vel, 0.0) / passada, TAU * 100.0)
	var balanco := sin(_fase * 2.0)                                  # passo/trote: dois apoios por passada
	var ug := fposmod(_fase / TAU, 1.0)                              # momento da passada (0 = frente apoiando)
	var voo := 0.5 + 0.5 * cos(TAU * (ug - 0.47))                    # 1 no recolhido (mais alto), 0 apoiando
	var sobe := (absf(balanco) * lerpf(0.012, 0.03, trote) * (1.0 - galope) + voo * 0.08 * galope) * a
	sobe += sin(_t * 1.3) * 0.004 * (1.0 - a)
	_modelo.position = _base + Vector3(0, sobe, 0)
	# galope: nariz para cima quando as de trás empurram, para baixo quando a frente apoia
	_modelo.rotation.x = -(balanco * 0.006 * (1.0 - galope) + sin(TAU * (ug - 0.5)) * 0.055 * galope) * a
	_modelo.rotation.z = sin(_fase) * 0.012 * (1.0 - trote - galope) * a        # no passo o corpo gira de leve
	if _esq == null or _pata.size() < 4: return
	var amp := lerpf(lerpf(0.36, 0.42, trote), 0.62, galope) * a
	for k in 4:
		var off: float = lerpf(lerpf(PASSO[k], FASES[k], trote), GALOPE[k], galope)
		var u := fposmod((_fase + off) / TAU, 1.0)
		var apoio := lerpf(lerpf(0.64, 0.5, trote), 0.3, galope)        # parte da passada com a pata no chão
		var ang: float; var dobra: float
		if u < apoio:                                                    # no chão: vai da frente para trás, reta
			ang = lerpf(1.0, -1.0, u / apoio); dobra = 0.05
		else:                                                            # no ar: levanta dobrando e volta rápido
			var v := (u - apoio) / (1.0 - apoio)
			ang = lerpf(-1.0, 1.0, smoothstep(0.0, 1.0, v)); dobra = sin(v * PI)
		var forca := lerpf(1.1 if k < 2 else 0.7, 1.4 if k < 2 else 1.0, galope) * a
		var p: Array = _pata[k]
		if k < 2:      # frente: o "joelho" (carpo) dobra para trás e o casco recolhe
			_girar(p[0], ang * amp + 0.15 * dobra * a); _girar(p[1], -dobra * forca); _girar(p[2], -dobra * forca * 0.6)
		else:          # trás: a coxa vai para a frente, o jarrete dobra ao contrário e o casco recolhe
			_girar(p[0], ang * amp * 0.8 + 0.25 * dobra * a); _girar(p[1], -dobra * forca * 0.5); _girar(p[2], dobra * forca * 0.9)
	# cabeça e pescoço: acompanham cada passo; parado, olham em volta devagar
	var cab := inclinar * 0.25 + lerpf(sin(_fase * 2.0 + 0.8) * lerpf(0.06, 0.03, trote), cos(TAU * (ug - 0.47)) * 0.09, galope) * a
	_girar(_pescoco, -cab, sin(_t * 0.37) * 0.12 * (1.0 - a))
	_girar(_cabeca, -cab * 0.5 + sin(_t * 0.6) * 0.05 * (1.0 - a))
	_girar(_rabo, -0.35 * a, sin(_t * 1.7) * lerpf(0.18, 0.08, a))

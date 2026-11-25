# Corpo do herói em terceira pessoa: o modelo (humana.glb / humano.glb, com o esqueleto do NPC base) animado por
# código, osso a osso, lendo o estado do jogador a cada passo da física: parado (respirando, em guarda), andando,
# correndo, andando para trás, no ar, bloqueando (escudo na frente), os golpes da espada (os mesmos tempos dos
# golpes do jogador: preparação → corte → seguir → volta), empurrão com o escudo, montado e caindo morto.
# Braços: cada osso recebe uma DIREÇÃO alvo (espaço do esqueleto: +X frente, +Y cima, +Z direita); pernas, coluna
# e cabeça recebem rotações. A espada e o escudo ficam em "mao_d"/"mao_e", presos aos ossos das mãos.
extends Node3D
class_name CorpoHeroi

var j                               # o jogador
var mod: Node3D
var esq: Skeleton3D
var k := 1.0                        # escala do modelo (o arquivo tem 0,98 de altura)
var mao_d: Node3D                   # espada (cabo na origem, lâmina em +Y)
var mao_e: Node3D                   # escudo (frente em +Y)
var _ids := {}
var _resto := {}
var _filho := {}                    # osso → osso filho (para a direção do osso)
var _dir := {}                      # direção atual de cada braço (suavizada)
var _rot := {}                      # rotação atual de pernas/coluna/cabeça (suavizada)
var _fase := 0.0
var _anda := 0.0
var _corre := 0.0
var _hip := 0.0
var _yaw := 0.0
var _queda := 0.0
var giro_teste := 0.0               # teste: vira o corpo para a câmera ver de frente/lado
const BRACOS := {"R_Upperarm": "R_Forearm", "R_Forearm": "R_Hand", "L_Upperarm": "L_Forearm", "L_Forearm": "L_Hand"}
const GIROS := ["Hip", "Spine01", "Spine02", "Head", "L_Thigh", "R_Thigh", "L_Calf", "R_Calf", "L_Foot", "R_Foot"]
const ORDEM := ["Hip", "L_Thigh", "L_Calf", "L_Foot", "R_Thigh", "R_Calf", "R_Foot", "Spine01", "Spine02", "Head",
	"R_Upperarm", "R_Forearm", "L_Upperarm", "L_Forearm"]

# poses dos braços: [R_Upperarm, R_Forearm, L_Upperarm, L_Forearm] e torção do tronco (Ry: + vira para a esquerda)
const GUARDA := [Vector3(0.12, -1, 0.3), Vector3(0.8, -0.45, 0.12), Vector3(0.1, -1, -0.32), Vector3(0.65, -0.55, -0.05)]
const BLOQ_E := [Vector3(0.6, -0.65, -0.3), Vector3(0.15, 0.1, 1.0)]
const GOLPES := {        # [preparação, fim do corte, torção na preparação, torção no fim, inclinação (Rz: - frente)]
	"leve1": [[Vector3(-0.25, 0.65, 0.75), Vector3(-0.35, 0.85, 0.2)], [Vector3(0.8, -0.35, -0.35), Vector3(0.55, -0.65, -0.6)], -0.45, 0.45, -0.15],
	"leve2": [[Vector3(0.05, 0.95, 0.3), Vector3(-0.65, 0.6, 0.05)], [Vector3(0.9, -0.25, 0.08), Vector3(0.85, -0.55, 0.0)], -0.1, 0.1, -0.35],
	"leve3": [[Vector3(0.0, 0.1, 1.0), Vector3(-0.45, 0.15, 0.9)], [Vector3(0.55, 0.05, -0.85), Vector3(0.15, 0.0, -1.0)], -0.7, 0.75, -0.1],
	"forte": [[Vector3(-0.1, 1.0, 0.2), Vector3(-0.85, 0.45, 0.0)], [Vector3(0.9, -0.35, 0.0), Vector3(0.75, -0.65, 0.0)], -0.2, 0.15, -0.5],
}

# boneco parado para as telas de seleção/criação (sem jogador): em guarda, respirando
class Manequim:
	var velocity := Vector3.ZERO; var rotation := Vector3.ZERO; var _acao := ""; var bloqueando := false; var alvo = null
	var montado := false; var morta := false; var _t_morte := 0.0; var _tempo := 0.0; var congelar := -1.0
	var _fase := 0; var _t_acao := 0.0; var _passo_acao := 0; var GOLPES := {}
	func is_on_floor() -> bool: return true

func montar(jogador, arq: String, no_mundo := true) -> void:
	j = jogador if jogador != null else Manequim.new()
	_montar_ap.call_deferred()
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	mod = load(arq).instantiate(); add_child(mod)
	k = 1.68 / 0.98
	mod.scale = Vector3.ONE * k; mod.rotation_degrees.y = 90           # o modelo olha para +X → -Z
	esq = mod.find_children("*", "Skeleton3D", true, false)[0]
	var m: Node = get_tree().current_scene
	for n in mod.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n
		var orig: BaseMaterial3D = mi.mesh.surface_get_material(0)
		if not no_mundo:                    # telas de menu: o material do próprio modelo (sem a noite/neblina do mundo)
			if orig:
				var mt := orig.duplicate() as BaseMaterial3D; mt.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST; mi.material_override = mt
			continue
		var sm := ShaderMaterial.new(); sm.shader = load("res://shaders/npc.gdshader")
		if orig: sm.set_shader_parameter("tex", orig.albedo_texture)
		sm.set_shader_parameter("original", true)
		if m and "NEBLINA" in m: sm.set_shader_parameter("neblina", m.NEBLINA)
		mi.material_override = sm
	for b in ORDEM:
		var i := esq.find_bone(b)
		if i >= 0: _ids[b] = i; _resto[b] = esq.get_bone_global_rest(i)
	for b in BRACOS.keys():
		var f := esq.find_bone(BRACOS[b])
		if f >= 0: _filho[b] = esq.get_bone_global_rest(f).origin
	# espada na mão direita: lâmina para a frente (+X), face para fora (+Z) no repouso
	mao_d = _presa("R_Hand", "R_Mid1", Basis(Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)), 0.85)
	# escudo no antebraço esquerdo: frente para fora (-Z)
	mao_e = _presa("L_Hand", "L_Mid1", Basis(Vector3(0, 1, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0)), 1.0)

func _presa(osso: String, dedo: String, b: Basis, esc: float) -> Node3D:
	var i := esq.find_bone(osso)
	var at := BoneAttachment3D.new(); at.bone_name = osso; esq.add_child(at)
	var rh := esq.get_bone_global_rest(i)
	var di := esq.find_bone(dedo)
	var pega: Vector3 = rh.origin.lerp(esq.get_bone_global_rest(di).origin, 0.6) if di >= 0 else rh.origin
	var no := Node3D.new(); no.transform = rh.affine_inverse() * Transform3D(b.orthonormalized(), pega); at.add_child(no)
	var h := Node3D.new(); h.scale = Vector3.ONE * esc / k; no.add_child(h)
	return h

# ---------- animação ----------
static func _e(x: float) -> float: return x * x * (3.0 - 2.0 * x)

func animar(delta: float) -> void:
	if esq == null: return
	var vh := Vector2(j.velocity.x, j.velocity.z)
	var vel := vh.length()
	var no_chao: bool = j.is_on_floor()
	# para onde o corpo olha: o rumo do movimento; atacando, bloqueando, de mira travada ou andando para trás,
	# olha para onde a câmera olha
	var frente: float = j.rotation.y
	var vira := true
	var luta: bool = j.GOLPES.has(j._acao) or j._acao == "bash" or j.bloqueando or j.alvo != null
	var para_tras := false
	if vel > 0.6 and not luta and not j.montado:
		var local := vh.rotated(j.rotation.y)                          # no espaço da câmera (−y = frente)
		if local.y > 0.4 * vel: para_tras = true
		else: frente = atan2(-vh.x, -vh.y)
	if j.montado: frente = j.rotation.y
	_yaw = lerp_angle(_yaw, frente, 1.0 - exp(-(16.0 if luta else 10.0) * delta)) if vira else _yaw
	rotation.y = _yaw - j.rotation.y + giro_teste                       # o corpo é filho do jogador
	# animações de verdade (pacote Sword and Shield, convertidas para o nosso esqueleto); montado: as de código
	if _ap and not j.montado:
		rotation.x = 0.0; position.y = 0.0
		_clipes(vel, vh, no_chao, para_tras, luta)
		return
	if _ap and _ap.is_playing(): _ap.stop(); esq.reset_bone_poses()
	var a := clampf(vel / 4.4, 0.0, 1.2) if no_chao and not j.montado else 0.0
	_anda = lerpf(_anda, minf(a, 1.0), 1.0 - exp(-10.0 * delta))
	_corre = lerpf(_corre, clampf((vel - 5.0) / 2.0, 0.0, 1.0) if no_chao and not j.montado else 0.0, 1.0 - exp(-8.0 * delta))
	_fase += delta * TAU * (0.6 + vel * 0.24) * (-1.0 if para_tras else 1.0) * (1.0 if no_chao else 0.0)
	var s := sin(_fase); var c := cos(_fase)
	var t: float = j._tempo
	var dir := {}; var rot := {}
	var guarda := GUARDA
	dir["R_Upperarm"] = guarda[0]; dir["R_Forearm"] = guarda[1]; dir["L_Upperarm"] = guarda[2]; dir["L_Forearm"] = guarda[3]
	var torcao := 0.0; var incl := -0.05 + sin(t * 1.5) * 0.015; var hip := 0.0
	# ---- pernas e balanço dos braços ao andar/correr
	if _anda > 0.02:
		var pe := 0.45 + 0.35 * _corre
		rot["L_Thigh"] = Quaternion(Vector3(0, 0, 1), pe * s * _anda); rot["R_Thigh"] = Quaternion(Vector3(0, 0, 1), -pe * s * _anda)
		rot["L_Calf"] = Quaternion(Vector3(0, 0, 1), -(0.55 + 0.75 * _corre) * maxf(0.0, -c) * _anda)
		rot["R_Calf"] = Quaternion(Vector3(0, 0, 1), -(0.55 + 0.75 * _corre) * maxf(0.0, c) * _anda)
		hip = -absf(s) * (0.015 + 0.04 * _corre) * _anda
		incl -= 0.22 * _corre
		var bal := (0.35 + 0.45 * _corre) * _anda
		dir["R_Upperarm"] = (guarda[0] + Vector3(bal * s, 0.2 * _corre, 0)).normalized()
		dir["L_Upperarm"] = (guarda[2] + Vector3(-bal * s, 0.2 * _corre, 0)).normalized()
		dir["R_Forearm"] = (guarda[1] + Vector3(0.3 * _corre, 0.5 * _corre, 0)).normalized()
		dir["L_Forearm"] = (guarda[3] + Vector3(0.3 * _corre, 0.5 * _corre, 0)).normalized()
		torcao = -s * 0.12 * _anda
	# ---- no ar: pernas dobradas, braços um pouco abertos
	if not no_chao and not j.montado:
		rot["L_Thigh"] = Quaternion(Vector3(0, 0, 1), 0.7); rot["R_Thigh"] = Quaternion(Vector3(0, 0, 1), 0.25)
		rot["L_Calf"] = Quaternion(Vector3(0, 0, 1), -1.0); rot["R_Calf"] = Quaternion(Vector3(0, 0, 1), -0.6)
		dir["L_Upperarm"] = Vector3(0.2, -0.7, -0.7); dir["R_Upperarm"] = Vector3(0.2, -0.7, 0.7)
	# ---- bloqueio: escudo atravessado na frente do peito
	if j.bloqueando or j._acao == "bash":
		dir["L_Upperarm"] = BLOQ_E[0]; dir["L_Forearm"] = BLOQ_E[1]
		if j._acao == "bash":                                         # empurra o escudo para a frente
			var u := clampf(float(j._passo_acao) / 2.0 + j._t_acao * 3.0, 0.0, 1.0)
			var e := sin(u * PI)
			dir["L_Upperarm"] = BLOQ_E[0].lerp(Vector3(0.95, -0.25, -0.15), e).normalized()
			dir["L_Forearm"] = BLOQ_E[1].lerp(Vector3(0.5, 0.0, 0.85), e).normalized()
			incl -= 0.2 * e
	# ---- golpes da espada (mesmas fases do jogador)
	if GOLPES.has(j._acao):
		var g: Array = GOLPES[j._acao]; var tempos: Array = j.GOLPES[j._acao].t
		var f: int = j._fase; var u := clampf(j._t_acao / maxf(float(tempos[mini(f, 3)]), 0.001), 0.0, 1.0)
		if j.congelar >= 0.0: u = j.congelar
		var pre: Array = g[0]; var fim: Array = g[1]
		var base := [guarda[0], guarda[1]]
		var r0: Vector3; var r1: Vector3; var tw := 0.0; var lean := 0.0
		match f:
			0:
				var e := 1.0 - pow(1.0 - u, 2.4)
				r0 = base[0].slerp(pre[0].normalized(), e); r1 = base[1].slerp(pre[1].normalized(), e); tw = g[2] * e; lean = 0.08 * e
			1:
				var e := pow(u, 2.0)
				r0 = pre[0].normalized().slerp(fim[0].normalized(), e); r1 = pre[1].normalized().slerp(fim[1].normalized(), e)
				tw = lerpf(g[2], g[3], e); lean = lerpf(0.08, g[4], e)
			2:
				r0 = fim[0].normalized(); r1 = fim[1].normalized(); tw = g[3]; lean = g[4]
			_:
				var e := _e(u)
				r0 = fim[0].normalized().slerp(base[0], e); r1 = fim[1].normalized().slerp(base[1], e); tw = g[3] * (1.0 - e); lean = g[4] * (1.0 - e)
		dir["R_Upperarm"] = r0; dir["R_Forearm"] = r1; torcao += tw; incl += lean
		# o passo do golpe: pé esquerdo à frente
		var p := 1.0 if f in [1, 2] else (0.5 if f == 0 else 0.0)
		rot["L_Thigh"] = Quaternion(Vector3(0, 0, 1), 0.35 * p); rot["L_Calf"] = Quaternion(Vector3(0, 0, 1), -0.25 * p)
		rot["R_Thigh"] = Quaternion(Vector3(0, 0, 1), -0.2 * p); hip = -0.05 * p
	# ---- montado: pernas abertas no lombo do cavalo
	if j.montado:
		rot["L_Thigh"] = Quaternion(Vector3(0, 0, 1), 1.25) * Quaternion(Vector3(1, 0, 0), 0.45)
		rot["R_Thigh"] = Quaternion(Vector3(0, 0, 1), 1.25) * Quaternion(Vector3(1, 0, 0), -0.45)
		rot["L_Calf"] = Quaternion(Vector3(0, 0, 1), -1.35); rot["R_Calf"] = Quaternion(Vector3(0, 0, 1), -1.35)
		dir["R_Upperarm"] = Vector3(0.45, -0.85, 0.2); dir["R_Forearm"] = Vector3(0.95, -0.2, -0.1)
		dir["L_Upperarm"] = Vector3(0.45, -0.85, -0.2); dir["L_Forearm"] = Vector3(0.95, -0.2, 0.1)
		incl = 0.05 + sin(t * 3.0) * 0.02
	# ---- morta: cai de costas
	var cair := 0.0
	if j.morta:
		cair = _e(clampf(j._t_morte / 0.9, 0.0, 1.0))
		dir["R_Upperarm"] = Vector3(0.2, -0.4, 0.9); dir["L_Upperarm"] = Vector3(0.2, -0.4, -0.9)
		rot["L_Thigh"] = Quaternion(Vector3(0, 0, 1), 0.3 * cair); rot["R_Calf"] = Quaternion(Vector3(0, 0, 1), -0.5 * cair)
		rot["Head"] = Quaternion(Vector3(0, 0, 1), 0.35 * cair)
	rot["Spine01"] = Quaternion(Vector3(0, 1, 0), torcao * 0.5) * Quaternion(Vector3(0, 0, 1), incl)
	rot["Spine02"] = Quaternion(Vector3(0, 1, 0), torcao * 0.5)
	if not rot.has("Head"): rot["Head"] = Quaternion(Vector3(0, 1, 0), -torcao * 0.6 + sin(t * 0.4) * 0.08)
	# ---- suaviza e aplica
	var fs := 1.0 - exp(-(22.0 if GOLPES.has(j._acao) else 12.0) * delta)
	for b in GIROS:
		var q0: Quaternion = _rot.get(b, Quaternion()); var q1: Quaternion = rot.get(b, Quaternion())
		_rot[b] = q0.slerp(q1, fs)
	for b in BRACOS.keys():
		var d0: Vector3 = _dir.get(b, dir[b].normalized())
		_dir[b] = d0.slerp(dir[b].normalized(), fs) if d0.dot(dir[b].normalized()) > -0.99 else dir[b].normalized()
	_hip = lerpf(_hip, hip, fs)
	for b in ORDEM:
		if not _ids.has(b): continue
		var i: int = _ids[b]
		var pai := esq.get_bone_parent(i)
		var pg: Transform3D = esq.get_bone_global_pose(pai) if pai >= 0 else Transform3D.IDENTITY
		var pai_resto: Transform3D = esq.get_bone_global_rest(pai) if pai >= 0 else Transform3D.IDENTITY
		var g: Transform3D = pg * pai_resto.affine_inverse() * _resto[b]
		if _dir.has(b):                     # braço: gira até a direção alvo
			var ponta: Vector3 = g * ((_resto[b] as Transform3D).affine_inverse() * _filho[b])
			var atual := (ponta - g.origin).normalized()
			if atual.length() > 0.5: g.basis = Basis(Quaternion(atual, _dir[b])) * g.basis
		else:
			g.basis = Basis(_rot.get(b, Quaternion())) * g.basis
		if b == "Hip": g.origin += Vector3(0, _hip / k, 0)
		var loc := pg.affine_inverse() * g
		esq.set_bone_pose_position(i, loc.origin); esq.set_bone_pose_rotation(i, loc.basis.get_rotation_quaternion())
	# corpo inteiro: cai de costas morta; sobe na sela montada
	rotation.x = 1.45 * cair
	position.y = 0.15 * cair + (0.95 if j.montado else 0.0)

# ---------- animações do pacote ----------
var _ap: AnimationPlayer
var _atual := ""
var _acao_ant := ""
func _montar_ap() -> void:
	if not ResourceLoader.exists("res://assets/animacoes/heroi.res") or mod == null: return
	_ap = AnimationPlayer.new(); mod.add_child(_ap); _ap.root_node = NodePath("..")
	_ap.add_animation_library("", load("res://assets/animacoes/heroi.res"))
	_ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS if j is Node else AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	_ap.play("parado")

const GOLPE_CLIPE := {"leve1": "golpe1", "leve2": "golpe2", "leve3": "golpe3", "forte": "golpe_forte"}
func _tocar(nome: String, velo := 1.0, mistura := 0.18, do_comeco := false) -> void:
	if nome != _atual or do_comeco:
		_ap.play(nome, mistura); _atual = nome
		if do_comeco: _ap.seek(0.0, true)
	_ap.speed_scale = velo

func _clipes(vel: float, vh: Vector2, no_chao: bool, para_tras: bool, luta: bool) -> void:
	if j.morta: _tocar("morte", 1.0, 0.25); return
	var acao: String = j._acao
	if GOLPE_CLIPE.has(acao):
		var clipe: String = GOLPE_CLIPE[acao]
		var nova: bool = acao != _acao_ant
		var t: Array = j.GOLPES[acao].t
		var len: float = _ap.get_animation(clipe).length
		# o clipe segue o relógio do golpe do jogador: preparo+corte = 0..IMPACTO do clipe (o impacto), o resto = volta
		var dec := 0.0
		for k in j._fase: dec += float(t[k])
		dec += (float(j.congelar) if j.congelar >= 0.0 else j._t_acao / maxf(float(t[j._fase]), 0.001)) * float(t[j._fase]) if j._fase < t.size() else 0.0
		var ida := float(t[0]) + float(t[1]); var volta := 0.0
		for k in range(2, t.size()): volta += float(t[k])
		var im: float = 0.5 if acao == "forte" else 0.3
		var pos := im * len * dec / ida if dec < ida else (im + (1.0 - im) * (dec - ida) / maxf(volta, 0.01)) * len
		_tocar(clipe, 1.0, 0.08, nova); _ap.seek(minf(pos, len), true)   # velocidade 1: a mistura com o clipe anterior anda
		_acao_ant = acao
		return
	_acao_ant = acao
	if acao == "bash": _tocar("escudada", 1.6, 0.08); return
	if j.bloqueando: _tocar("bloqueio", 1.0, 0.12); return
	if not no_chao: _tocar("no_ar", 1.0, 0.15); return
	if vel < 0.4: _tocar("parado", 1.0, 0.2); return
	# para onde anda em relação ao corpo: frente, trás ou de lado (de lado só lutando, quando o corpo olha a câmera)
	var local := vh.rotated(j.rotation.y + rotation.y)               # no espaço do corpo (−y = frente)
	var lado := ""
	if luta and absf(local.x) > absf(local.y): lado = "_dir" if local.x > 0.0 else "_esq"
	elif para_tras or local.y > 0.3 * vel: lado = "_tras"
	if vel < 2.4: _tocar("andar" + lado, clampf(vel / 1.5, 0.6, 1.6))
	elif vel < 6.5 or lado != "": _tocar("correr" + lado, clampf(vel / 4.6, 0.7, 1.6))
	else: _tocar("disparada", clampf(vel / 7.0, 0.8, 1.5))

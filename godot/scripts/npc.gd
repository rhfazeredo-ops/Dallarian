# Morador da vila: o mesmo modelo base (assets/modelos/npc.glb, 2.200 triângulos) com cores sorteadas
# (pele, cabelo/couro, túnica, calça) e altura/corpo variados. Anda pela vila de um ponto a outro, para,
# olha em volta e segue. Animação de andar e de respirar feita nos ossos (procedural).
extends CharacterBody3D
class_name Morador

const VEL := 1.25
var m                     # o mundo
var area_centro := Vector2.ZERO
var area_raio := 40.0
var esq: Skeleton3D
var visual: Node3D
var _t := 0.0
var _fase := 0.0
var _resto := {}          # osso → pose de repouso global (no espaço do esqueleto)
var _ids := {}
var rng := RandomNumberGenerator.new()

const PELES := [Color(0.95, 0.72, 0.55), Color(0.9, 0.62, 0.42), Color(0.76, 0.5, 0.32), Color(0.55, 0.36, 0.22), Color(0.98, 0.8, 0.66)]
const COUROS := [Color(0.38, 0.24, 0.14), Color(0.2, 0.15, 0.12), Color(0.55, 0.38, 0.2), Color(0.6, 0.3, 0.15), Color(0.48, 0.46, 0.44)]
const CABELOS := [Color(0.4, 0.24, 0.12), Color(0.12, 0.1, 0.09), Color(0.78, 0.6, 0.3), Color(0.62, 0.26, 0.12), Color(0.55, 0.52, 0.5), Color(0.3, 0.2, 0.14)]
const TUNICAS := [Color(0.86, 0.72, 0.52), Color(0.3, 0.4, 0.62), Color(0.55, 0.2, 0.2), Color(0.35, 0.5, 0.3), Color(0.55, 0.42, 0.3), Color(0.62, 0.6, 0.55), Color(0.72, 0.6, 0.25)]
const CALCAS := [Color(0.45, 0.44, 0.47), Color(0.35, 0.28, 0.2), Color(0.28, 0.32, 0.25), Color(0.25, 0.26, 0.32), Color(0.5, 0.42, 0.32)]

# skins: 1 = modelo base com cores sorteadas; 2 e 3 = skins desenhadas no Tripo (mesmo corpo, textura própria)
const SKINS := ["res://assets/modelos/npc.glb", "res://assets/modelos/npc2.glb", "res://assets/modelos/npc3.glb"]
var skin := 0
# tipos de corpo (modelos próprios do Tripo, com o esqueleto do npc.glb transferido): [arquivo, altura mín, máx, ritmo]
const TIPOS := {
	"fem": ["res://assets/modelos/npc_fem.glb", 1.6, 1.7, 1.0],
	"gorda": ["res://assets/modelos/npc_gorda.glb", 1.5, 1.58, 0.85],
	"velha": ["res://assets/modelos/npc_velha.glb", 1.42, 1.5, 0.65],
	"forte": ["res://assets/modelos/npc_forte.glb", 1.88, 1.96, 1.0],
	"velho": ["res://assets/modelos/npc_velho.glb", 1.64, 1.72, 0.7],
	"menino": ["res://assets/modelos/npc_menino.glb", 1.22, 1.28, 1.0],
	"menina": ["res://assets/modelos/npc_menina.glb", 1.17, 1.23, 1.0],
}
var tipo := ""                    # "" = sorteia entre as skins e os tipos acima
var ritmo := 1.0                  # velhos andam mais devagar
var _corre := 0.0                 # 0..1: quanto a animação é de corrida (crianças brincando)
# profissão: "" (morador comum), "ferreiro", "lenhador", "fazendeiro" — fica no posto trabalhando
var profissao := ""
var roupa := {}                   # cores fixas da roupa (ex.: hábito da freira) no lugar das sorteadas
var posto := Vector2.ZERO
var olhar_posto := Vector2.ZERO
var campo: Array = []             # fazendeiro: o campo (centro x, z, largura, comprimento, ângulo°, tipo)
var gesticula := true              # enquanto conversa: true = ele fala (gesticula), false = escuta
var falando_com: Node3D = null    # o jogador, quando está conversando com ele
var ao_bater: Callable            # chamado no instante do golpe (faíscas/lascas)
const MODELOS_PROF := { "ferreiro": "res://assets/modelos/ferreiro.glb", "lenhador": "res://assets/modelos/lenhador.glb", "fazendeiro": "res://assets/modelos/fazendeiro.glb",
	"freira": "res://assets/modelos/freira.glb" }
# a freira do Tripo veio de frente para +Z (os outros olham para +X): as poses (pensadas para +X) giram 90° para ela
const GIRO_FREIRA := Quaternion(Vector3.UP, -PI / 2.0)
# e veio em pose de T (braços na horizontal); os moradores descansam com os braços ~58° para baixo (pose em A)
const A_FREIRA := {"L_Upperarm": Quaternion(Vector3(0, 0, 1), -1.0), "R_Upperarm": Quaternion(Vector3(0, 0, 1), 1.0)}
# ferramentas: [arquivo, eixo do cabo no arquivo (para a cabeça), ponto de pegada, direção da lâmina/face, comprimento no arquivo, comprimento real (m)]
const FERRAMENTAS := {
	"martelo": ["res://assets/modelos/martelo.glb", Vector3(-0.856, 0.508, 0.093), Vector3(-0.13, 0.071, 0.033) + Vector3(0.856, -0.508, -0.093) * 0.56, Vector3(0.085, -0.039, 0.996), 1.073, 0.38],   # face: o lado grosso (oposto à ponta fina)
	"machado": ["res://assets/modelos/machado.glb", Vector3(-0.433, 0.694, 0.575), Vector3(-0.023, 0.026, -0.024) + Vector3(-0.433, 0.694, 0.575) * -0.56, Vector3(0.228, -0.533, 0.815), 1.29, 0.85],
}

static var _n_med := 0
func montar(mundo, semente: int, centro: Vector2, raio: float) -> void:
	var _t0 := Time.get_ticks_usec()
	m = mundo; rng.seed = semente; area_centro = centro; area_raio = raio
	var sorteio := rng.randf()
	skin = 0 if sorteio < 0.2 else (1 if sorteio < 0.32 else 2)
	if tipo == "" and profissao == "" and sorteio >= 0.44:
		tipo = ["fem", "fem", "gorda", "velha", "forte", "velho"][int((sorteio - 0.44) / 0.56 * 6.0) % 6]
	if tipo != "": skin = 20 + TIPOS.keys().find(tipo)
	if MODELOS_PROF.has(profissao): skin = {"ferreiro": 11, "lenhador": 12, "fazendeiro": 13, "freira": 14}[profissao]
	if not roupa.is_empty() and not MODELOS_PROF.has(profissao): skin = 0; tipo = ""    # cores próprias: modelo base   # modelo e textura próprios
	var alt := rng.randf_range(1.62, 1.86); var larg := rng.randf_range(0.92, 1.12)
	if tipo != "":
		var tp: Array = TIPOS[tipo]; alt = rng.randf_range(tp[1], tp[2]); larg = rng.randf_range(0.97, 1.03); ritmo = tp[3]
	var cs := CollisionShape3D.new(); var cap := CapsuleShape3D.new(); cap.radius = 0.3 if alt > 1.4 else 0.24
	cap.height = alt - 0.1; cs.shape = cap; cs.position = Vector3(0, cap.height * 0.5, 0); add_child(cs)
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING      # anda no plano; a altura vem do terreno
	# modelo: 0,98 m no arquivo, de frente para -X → girado para frente = -Z e escalado
	visual = Node3D.new(); add_child(visual)
	if Cidadao.existe():                       # personagens do pacote Fantasy Kingdom, pelo papel de cada um
		_montar_pacote(alt)
		return
	var arq: String = MODELOS_PROF[profissao] if MODELOS_PROF.has(profissao) else (TIPOS[tipo][0] if tipo != "" else SKINS[skin])
	var mod: Node3D = load(arq).instantiate(); visual.add_child(mod)
	var k := alt / 0.981
	mod.scale = Vector3(k * larg, k, k * larg); mod.rotation_degrees.y = 180.0 if profissao == "freira" else 90.0     # o modelo olha para +X (a freira, +Z)
	esq = mod.find_children("*", "Skeleton3D", true, false)[0]
	var sm := ShaderMaterial.new(); sm.shader = load("res://shaders/npc.gdshader")
	for n in mod.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n
		var orig: BaseMaterial3D = mi.mesh.surface_get_material(0)
		if orig: sm.set_shader_parameter("tex", orig.albedo_texture)
		_regioes(mi)
		mi.material_override = sm
		mi.visibility_range_end = 90.0
	sm.set_shader_parameter("neblina", m.NEBLINA)
	sm.set_shader_parameter("original", skin > 0)
	sm.set_shader_parameter("cor_pele", PELES[rng.randi() % PELES.size()])
	sm.set_shader_parameter("cor_couro", COUROS[rng.randi() % COUROS.size()])
	sm.set_shader_parameter("cor_cabelo", CABELOS[rng.randi() % CABELOS.size()])
	sm.set_shader_parameter("cor_tunica", TUNICAS[rng.randi() % TUNICAS.size()] * rng.randf_range(0.9, 1.1))
	sm.set_shader_parameter("cor_calca", CALCAS[rng.randi() % CALCAS.size()])
	for kr in roupa: sm.set_shader_parameter(kr, roupa[kr])
	for b in ["Hip", "Pelvis", "Waist", "Spine01", "Spine02", "L_Thigh", "R_Thigh", "L_Calf", "R_Calf", "L_Upperarm", "R_Upperarm", "L_Forearm", "R_Forearm", "NeckTwist01", "Head"]:
		var i := esq.find_bone(b)
		if i >= 0: _ids[b] = i; _resto[b] = esq.get_bone_global_rest(i)
	_fase = rng.randf() * TAU
	if m.args.has("carga") and _n_med < 6: _n_med += 1; print("NPC montar ", (Time.get_ticks_usec() - _t0) / 1000.0, " ms skin=", skin)
	if profissao != "":
		if profissao == "ferreiro": _segurar("martelo")
		if profissao == "lenhador": _segurar("machado")
		estado = "trabalho"; _alvo = posto
		if profissao == "fazendeiro": _proximo_canteiro()
	elif tipo == "menino" or tipo == "menina":
		estado = "brincar"; _tempo_estado = rng.randf_range(20.0, 35.0)
	else:
		_proxima_coisa()

# ---------- personagem do pacote (Synty) com as animações da Synty (parado/andar) ----------
const PAPEIS := {"ferreiro": "SM_Chr_Blacksmith_Male_01", "lenhador": "SM_Chr_Hermit_01", "fazendeiro": "SM_Chr_Peasant_Male_01",
	"freira": "SM_Chr_Nun_01", "cavalarico": "SM_Chr_Peasant_Male_01"}
const TIPOS_PACOTE := {"fem": "SM_Chr_Peasant_Female_01", "gorda": "SM_Chr_Bartender_01", "velha": "SM_Chr_FortuneTeller_01",
	"forte": "SM_Chr_Blacksmith_Male_01", "velho": "SM_Chr_Monk_01", "menino": "SM_Chr_Peasant_Male_01", "menina": "SM_Chr_Peasant_Female_01"}
var _ap: AnimationPlayer
func _montar_pacote(alt: float) -> void:
	var nome: String = PAPEIS.get(profissao, TIPOS_PACOTE.get(tipo, ""))
	if has_meta("modelo"): nome = String(get_meta("modelo"))           # vendedores: o personagem escolhido
	if nome == "": nome = ["SM_Chr_Peasant_Male_01", "SM_Chr_Peasant_Female_01", "SM_Chr_Merchant_01", "SM_Chr_Peasant_Male_01", "SM_Chr_Hermit_01"][rng.randi() % 5]
	if profissao == "fazendeiro" and rng.randf() < 0.4: nome = "SM_Chr_Peasant_Female_01"
	var n: Node3D = load(Cidadao.ARQ).instantiate(); visual.add_child(n)
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = c
		if mi.name != nome: mi.queue_free()
		else:
			mi.material_override = Synty.material(m.NEBLINA, "personagem"); mi.visibility_range_end = 90.0
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var k := 0.72 if (tipo == "menino" or tipo == "menina") else 1.0          # crianças: o mesmo modelo menor
	n.scale = Vector3.ONE * k
	esq = n.find_children("*", "Skeleton3D", true, false)[0]
	_ap = AnimationPlayer.new(); n.add_child(_ap); _ap.root_node = NodePath("..")
	_ap.add_animation_library("", Cidadao._lib("Femn" if nome in Cidadao.MULHERES else "Masc"))
	if _ap.has_animation("parado"): _ap.play("parado"); _ap.seek(rng.randf() * 1.5, true)
	_fase = rng.randf() * TAU
	if profissao != "":
		estado = "trabalho"; _alvo = posto
		if profissao == "fazendeiro": _proximo_canteiro()
	elif tipo == "menino" or tipo == "menina":
		estado = "brincar"; _tempo_estado = rng.randf_range(20.0, 35.0)
	else:
		_proxima_coisa()

# marca no vértice quanto ele pertence à cabeça (r) e às mãos (g), pelo peso dos ossos — para separar pele
# de túnica e cabelo de couro, que têm a mesma cor na textura. Feito uma vez e reaproveitado.
static var _malhas_prontas := {}
func _regioes(mi: MeshInstance3D) -> void:
	if _malhas_prontas.has(skin): mi.mesh = _malhas_prontas[skin]; return
	var arr := mi.mesh.surface_get_arrays(0)
	var ossos = arr[Mesh.ARRAY_BONES]; var pesos = arr[Mesh.ARRAY_WEIGHTS]
	var nomes := []
	for i in mi.skin.get_bind_count():
		var nm := String(mi.skin.get_bind_name(i))
		if nm == "": nm = esq.get_bone_name(mi.skin.get_bind_bone(i))
		nomes.append(nm)
	var n: int = arr[Mesh.ARRAY_VERTEX].size(); var por: int = ossos.size() / n
	var cores := PackedColorArray(); cores.resize(n)
	for v in n:
		var cab := 0.0; var mao := 0.0
		for j in por:
			var b := int(ossos[v * por + j]); var w: float = pesos[v * por + j]
			if b < 0 or b >= nomes.size(): continue
			var nm: String = nomes[b]
			if "Head" in nm or "Neck" in nm or "Facial" in nm or "Eye" in nm: cab += w
			elif "Hand" in nm or "Thumb" in nm or "Index" in nm or "Mid" in nm or "Ring" in nm or "Pinky" in nm: mao += w
		cores[v] = Color(cab, mao, 0, 1)
	arr[Mesh.ARRAY_COLOR] = cores
	var nova := ArrayMesh.new()
	var flags := 0
	if por == 8: flags = Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
	nova.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, flags)
	nova.surface_set_material(0, mi.mesh.surface_get_material(0))
	_malhas_prontas[skin] = nova; mi.mesh = nova

# ---------- comportamento ----------
# estados: "andar" (até um lugar), "atividade" (parado fazendo algo), "conversa" (com outro morador)
var estado := "atividade"
var atividade := "olhar"          # olhar, cruzados, debrucar (no poço), agachar, cintura, cocar
var _alvo := Vector2.ZERO
var _olhar_para := Vector2.ZERO   # para onde virar quando parado
var _tempo_estado := 3.0
var _travado := 0.0
var par: Morador = null           # com quem conversa
var falando := false
var _troca_fala := 0.0
var _depois_andar := ""           # o que fazer ao chegar: "atividade" ou "conversa"
var _prox_conversa := 0.0

# lugares de interesse perto da área do morador: [posição, para onde olhar, atividades possíveis]
func _lugares_de_interesse() -> Array:
	var l := []
	for c in m.casas:
		var p: Vector3 = c[0]
		var porta := Vector2(p.x, p.z) + Vector2(0, c[3] * 0.5 + 1.3).rotated(-c[1])
		if porta.distance_to(area_centro) < area_raio:
			l.append([porta, Vector2(p.x, p.z) + (porta - Vector2(p.x, p.z)) * 3.0, ["olhar", "cruzados", "cintura", "cocar"]])
	if area_centro.length() < 1.0:
		for k in 5:
			var a := TAU * k / 5.0; var q := Vector2(cos(a), sin(a)) * 1.9
			l.append([q, Vector2.ZERO, ["debrucar"]])
		var f: Vector2 = m.ferraria_pos
		if f != Vector2.ZERO: l.append([f + (Vector2.ZERO - f).normalized() * 5.5, f, ["olhar", "cruzados", "cintura"]])
	for k in 6:                                          # alguns cantos de chão livre
		var a := rng.randf() * TAU; var q := area_centro + Vector2(cos(a), sin(a)) * rng.randf_range(4.0, area_raio * 0.8)
		if not m.perto_de_casa(q.x, q.y, 1.5): l.append([q, q + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)), ["olhar", "agachar", "cruzados"]])
	return l

func _proxima_coisa() -> void:
	par = null; falando = false
	if rng.randf() < 0.75:
		var l := _lugares_de_interesse()
		if not l.is_empty():
			var e: Array = l[rng.randi() % l.size()]
			_alvo = e[0]; _olhar_para = e[1]
			var ats: Array = e[2]; atividade = ats[rng.randi() % ats.size()]
			estado = "andar"; _depois_andar = "atividade"; return
	estado = "atividade"; atividade = ["olhar", "cruzados", "cintura"][rng.randi() % 3]
	_olhar_para = Vector2(global_position.x, global_position.z) + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1))
	_tempo_estado = rng.randf_range(4.0, 9.0)

# convite para conversar: os dois vão para um ponto entre eles e ficam de frente
func convidar(outro: Morador) -> void:
	var a := Vector2(global_position.x, global_position.z); var b := Vector2(outro.global_position.x, outro.global_position.z)
	var meio := (a + b) * 0.5; var d := (b - a).normalized()
	if d.length() < 0.1: d = Vector2(1, 0)
	var dur := rng.randf_range(10.0, 22.0)
	_ir_conversar(outro, meio - d * 0.65, meio, dur, true)
	outro._ir_conversar(self, meio + d * 0.65, meio, dur, false)

func _ir_conversar(outro: Morador, ponto: Vector2, meio: Vector2, dur: float, comeca: bool) -> void:
	par = outro; _alvo = ponto; _olhar_para = meio; estado = "andar"; _depois_andar = "conversa"
	_tempo_estado = dur; falando = comeca; _troca_fala = rng.randf_range(2.0, 4.0)

func livre_para_conversar() -> bool:
	return profissao == "" and estado != "brincar" and par == null and (estado == "atividade" or estado == "andar") and _prox_conversa <= 0.0

func _physics_process(delta: float) -> void:
	if m == null: return
	_dist_j = global_position.distance_to(m.jogador.global_position) if m.jogador else 0.0
	if _dist_j > 95.0 and falando_com == null: return          # longe e fora de vista: nem pensa
	_t += delta; _prox_conversa -= delta
	var p := Vector2(global_position.x, global_position.z)
	var quer_andar := false
	match estado:
		"andar":
			var d := _alvo - p
			if d.length() < 0.35:
				if _depois_andar == "conversa":
					estado = "conversa"
				else:
					estado = "atividade"; _tempo_estado = rng.randf_range(6.0, 15.0)
			else:
				var dir := d.normalized()
				velocity = Vector3(dir.x, 0, dir.y) * VEL * ritmo
				_virar_para(p + dir, delta, 6.0)
				quer_andar = true
		"trabalho" when falando_com != null:
			velocity = Vector3.ZERO
			_virar_para(Vector2(falando_com.global_position.x, falando_com.global_position.z), delta, 5.0)
		"trabalho":
			var d := _alvo - p
			if d.length() > 0.3:
				var dir := d.normalized(); velocity = Vector3(dir.x, 0, dir.y) * VEL * 0.8
				_virar_para(p + dir, delta, 6.0); quer_andar = true
			else:
				velocity = Vector3.ZERO
				_virar_para(olhar_posto, delta, 4.0)
				if profissao == "fazendeiro":
					_tempo_estado -= delta
					if _tempo_estado <= 0.0: _proximo_canteiro()
		"brincar":
			quer_andar = _brincar(p, delta)
		"atividade":
			velocity = Vector3.ZERO
			_virar_para(_olhar_para, delta, 2.5)
			_tempo_estado -= delta
			if _tempo_estado <= 0.0: _proxima_coisa()
			elif _prox_conversa <= 0.0 and rng.randf() < delta * 0.12: _procurar_conversa()
		"conversa":
			velocity = Vector3.ZERO
			if par == null or not is_instance_valid(par) or par.par != self:
				_prox_conversa = 8.0; _proxima_coisa()
			else:
				if par.estado == "conversa": _virar_para(Vector2(par.global_position.x, par.global_position.z), delta, 4.0)
				else: _virar_para(_olhar_para, delta, 4.0)
				_troca_fala -= delta
				if _troca_fala <= 0.0 and falando and par.estado == "conversa":
					falando = false; par.falando = true; _troca_fala = rng.randf_range(2.5, 5.0); par._troca_fala = _troca_fala
				_tempo_estado -= delta
				if _tempo_estado <= 0.0:
					var o := par; _prox_conversa = rng.randf_range(15.0, 30.0); _proxima_coisa()
					if is_instance_valid(o) and o.par == self: o._prox_conversa = rng.randf_range(15.0, 30.0); o._proxima_coisa()
	move_and_slide()
	global_position.y = float(get_meta("y_fixo")) if has_meta("y_fixo") else m.altura_malha(global_position.x, global_position.z)
	# travou (andando sem sair do lugar): desiste e escolhe outra coisa — nunca "anda parado"
	var vel_real := Vector2(get_real_velocity().x, get_real_velocity().z).length()
	_corre = lerp(_corre, clampf((vel_real - 1.6) / 1.2, 0.0, 1.0), 1.0 - exp(-6.0 * delta))
	if estado == "brincar": _travado = 0.0; quer_andar = false
	if quer_andar and vel_real < 0.3: _travado += delta
	else: _travado = 0.0
	if _travado > 0.8:
		_travado = 0.0
		if estado == "trabalho": _alvo = p; return
		if _depois_andar == "conversa" and par: estado = "conversa"          # já está perto o bastante
		else: estado = "atividade"; atividade = "olhar"; _tempo_estado = rng.randf_range(2.0, 4.0); _olhar_para = _alvo
	# animação nos ossos é cara: de longe atualiza menos vezes (o tempo acumulado vai junto)
	_anim_acum += delta; _anim_quadro += 1
	var passo := 1 if _dist_j < 22.0 else (3 if _dist_j < 45.0 else 5)
	if _anim_quadro % passo == 0:
		_animar(_anim_acum, clampf(vel_real / (VEL * ritmo), 0.0, 1.0)); _anim_acum = 0.0

# crianças: pega-pega. Uma é o pegador e corre atrás da outra, que foge dando voltas pela área; quando pega,
# os papéis trocam (o novo pegador conta um pouco antes de correr). De vez em quando param para tomar fôlego.
var pegador := false
var _contar := 0.0
var _giro_fuga := 1.0
func _brincar(p: Vector2, delta: float) -> bool:
	_tempo_estado -= delta
	if par == null or not is_instance_valid(par):
		velocity = Vector3.ZERO; return false
	var q := Vector2(par.global_position.x, par.global_position.z)
	if _tempo_estado < 0.0:                          # descanso: param, mãos na cintura, olham um para o outro
		velocity = Vector3.ZERO; _virar_para(q, delta, 4.0); atividade = "cintura"
		if _tempo_estado < -5.0: _tempo_estado = rng.randf_range(20.0, 35.0); par._tempo_estado = _tempo_estado
		return false
	var vel := 0.0; var dir := Vector2.ZERO
	if pegador:
		if _contar > 0.0:
			_contar -= delta; velocity = Vector3.ZERO; _virar_para(q, delta, 3.0); return false
		dir = (q - p).normalized(); vel = 2.9
		if p.distance_to(q) < 0.8:                   # pegou!
			pegador = false; par.pegador = true; par._contar = 1.3; _giro_fuga = -_giro_fuga
	else:
		var fora := (p - q)
		if fora.length() > 9.0 or par._contar > 0.0: vel = 1.2 + 0.2 * sin(_t)        # longe: trota
		else: vel = 2.75
		dir = fora.normalized().rotated(_giro_fuga * 0.9)       # foge fazendo curva
		var dc := area_centro - p
		if dc.length() > area_raio * 0.6: dir = (dir + dc.normalized() * (dc.length() / area_raio) * 2.0).normalized()
	# desvia de casas, cercas e do poço
	for tent in 6:
		var prox := p + dir * 1.6
		if not m.perto_de_casa(prox.x, prox.y, 0.8) and prox.length() > 2.8: break
		dir = dir.rotated(0.6 * _giro_fuga)
	velocity = Vector3(dir.x, 0, dir.y) * vel
	_virar_para(p + dir, delta, 9.0)
	return true

# prende uma ferramenta na mão direita: cabo para a frente e a cabeça/lâmina para baixo, na pose de repouso
func _segurar(nome: String) -> void:
	var f: Array = FERRAMENTAS[nome]
	var mao := esq.find_bone("R_Hand"); var dedo := esq.find_bone("R_Mid1")
	if mao < 0: return
	var rh := esq.get_bone_global_rest(mao)
	var pega: Vector3 = rh.origin
	if dedo >= 0: pega = rh.origin.lerp(esq.get_bone_global_rest(dedo).origin, 0.9)
	var at := BoneAttachment3D.new(); at.bone_name = "R_Hand"; esq.add_child(at)
	# desejado (espaço do esqueleto): cabo +X (frente), face -Y; escala: comprimento real / altura do corpo
	var k: float = esq.get_parent().scale.y if esq.get_parent() is Node3D else 1.0
	var y_cabo := Vector3(1, 0, 0); var z_face := Vector3(0, -1, 0)
	var desejado := Transform3D(Basis(y_cabo.cross(z_face), y_cabo, z_face), pega)
	var no := Node3D.new(); no.transform = rh.affine_inverse() * desejado; at.add_child(no)
	var mod: Node3D = m.modelo_ps1(f[0])
	var eixo: Vector3 = f[1].normalized(); var face: Vector3 = (f[3] - eixo * f[3].dot(eixo)).normalized()
	var base_ferr := Transform3D(Basis(eixo.cross(face), eixo, face), f[2])
	var esc: float = f[5] / f[4] / (k * 1.0) * (0.981 / 1.0) / 0.981
	mod.transform = Transform3D(Basis().scaled(Vector3.ONE * esc)) * base_ferr.affine_inverse()
	no.add_child(mod)
	# a escala do pai (modelo) também atua: compensa para ficar no tamanho real
	mod.transform = Transform3D(Basis().scaled(Vector3.ONE * (f[5] / f[4]) / esq.get_parent().scale.y)) * base_ferr.affine_inverse()

# fazendeiro: escolhe outro canteiro dentro do campo cercado e vai até ele
func _proximo_canteiro() -> void:
	if campo.is_empty(): return
	var c := Vector2(campo[0], campo[1]); var ang := deg_to_rad(campo[4])
	var q := c + Vector2(rng.randf_range(-0.4, 0.4) * campo[2], rng.randf_range(-0.4, 0.4) * campo[3]).rotated(ang)
	_alvo = q; olhar_posto = q + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1))
	_tempo_estado = rng.randf_range(10.0, 20.0)

func _virar_para(alvo: Vector2, delta: float, vel: float) -> void:
	var d := alvo - Vector2(global_position.x, global_position.z)
	if d.length() < 0.05: return
	rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.y), 1.0 - exp(-vel * delta))

func _procurar_conversa() -> void:
	var melhor: Morador = null; var dm := 14.0
	for o in get_parent().get_children():
		if o is Morador and o != self and o.livre_para_conversar():
			var dd := global_position.distance_to(o.global_position)
			if dd < dm: dm = dd; melhor = o
	if melhor: convidar(melhor)

# ---------- animação nos ossos ----------
# no espaço do esqueleto: frente = +X, cima = +Y. Giro +Z leva um membro que aponta para baixo para a frente
# (e inclina o tronco/cabeça para trás); braços: giro em X fecha o braço junto ao corpo (L: -, R: +).
const OSSOS := ["Hip", "Pelvis", "Waist", "Spine01", "Spine02", "L_Thigh", "R_Thigh", "L_Calf", "R_Calf", "L_Upperarm", "R_Upperarm", "L_Forearm", "R_Forearm", "NeckTwist01", "Head"]
var _pose := {}            # osso → Quaternion atual (suavizado)
var _hip_y := 0.0
var _anda_suave := 0.0
var _anim_acum := 0.0
var _anim_quadro := 0
var _dist_j := 0.0

func _q(eixo: Vector3, ang: float) -> Quaternion: return Quaternion(eixo, ang)
func _zx(z: float, x: float) -> Quaternion: return _q(Vector3(0, 0, 1), z) * _q(Vector3(1, 0, 0), x)

func _animar(delta: float, anda: float) -> void:
	if _ap:
		var clipe := "andar" if anda > 0.15 else "parado"
		if _ap.has_animation(clipe) and _ap.current_animation != clipe: _ap.play(clipe, 0.25)
		_ap.speed_scale = clampf(anda * (1.6 if _corre > 0.5 else 1.0), 0.6, 1.8) if clipe == "andar" else 1.0
		_t += delta
		if estado == "trabalho" and anda < 0.1 and ao_bater.is_valid():         # martelada / machadada a cada ~1,1 s
			var b := int(_t / 1.1)
			if b != _anim_quadro: _anim_quadro = b; ao_bater.call()
		return
	_anda_suave = lerp(_anda_suave, anda, 1.0 - exp(-8.0 * delta))
	var a := _anda_suave
	_fase += delta * TAU * 0.95 * a * (ritmo if ritmo < 1.0 else 1.0) * (1.0 + 0.85 * _corre)
	var s := sin(_fase); var c := cos(_fase)
	var resp := sin(_t * 1.4 + _fase * 0.1)
	var alvo := {}
	var hip := 0.0
	# base: em pé, braços soltos junto ao corpo
	alvo["L_Upperarm"] = _zx(0.0, -0.32 + resp * 0.015); alvo["R_Upperarm"] = _zx(0.0, 0.32 - resp * 0.015)
	alvo["L_Forearm"] = _q(Vector3(0, 0, 1), 0.15); alvo["R_Forearm"] = _q(Vector3(0, 0, 1), 0.15)
	alvo["Spine01"] = _q(Vector3(0, 0, 1), 0.02 * resp)
	if estado == "conversa" and par and par.estado == "conversa":
		if falando:      # gesticula: uma mão sobe e mexe, a outra acompanha um pouco; cabeça balança
			var g := sin(_t * 3.1) * 0.5 + 0.5; var g2 := sin(_t * 2.3 + 1.0)
			alvo["R_Upperarm"] = _zx(0.55 + 0.15 * g2, 0.2)
			alvo["R_Forearm"] = _q(Vector3(0, 0, 1), 1.2 + 0.35 * g)
			alvo["L_Upperarm"] = _zx(0.25 + 0.1 * sin(_t * 1.7), -0.25)
			alvo["L_Forearm"] = _q(Vector3(0, 0, 1), 0.7 + 0.2 * sin(_t * 2.0))
			alvo["Head"] = _q(Vector3(0, 1, 0), sin(_t * 0.9) * 0.12) * _q(Vector3(0, 0, 1), sin(_t * 4.0) * 0.05)
		else:            # escuta: braços cruzados ou na cintura e balança a cabeça concordando de vez em quando
			_pose_cruzados(alvo, resp)
			alvo["Head"] = _q(Vector3(0, 0, 1), -0.06 + (sin(_t * 5.0) * 0.08 if sin(_t * 0.7) > 0.6 else 0.0))
	elif falando_com != null and profissao == "ferreiro":
		# segura o martelo abaixado ao lado do corpo (parado) e fala com a mão esquerda
		alvo["R_Upperarm"] = _zx(0.08, 0.3); alvo["R_Forearm"] = _q(Vector3(0, 0, 1), 0.3)
		if gesticula:
			var g := sin(_t * 3.1) * 0.5 + 0.5
			alvo["L_Upperarm"] = _zx(0.55 + 0.12 * sin(_t * 2.3), -0.2); alvo["L_Forearm"] = _q(Vector3(0, 0, 1), 1.15 + 0.3 * g)
			alvo["Head"] = _q(Vector3(0, 0, 1), 0.06 + sin(_t * 4.0) * 0.04)
		else:
			alvo["L_Upperarm"] = _zx(0.0, -0.32); alvo["L_Forearm"] = _q(Vector3(0, 0, 1), 0.2)
			alvo["Head"] = _q(Vector3(0, 0, 1), -0.04 + (sin(_t * 5.0) * 0.07 if sin(_t * 0.9) > 0.5 else 0.0))
	elif falando_com != null and not gesticula:   # escutando a Dallarian: braços cruzados, concorda com a cabeça
		_pose_cruzados(alvo, resp)
		alvo["Head"] = _q(Vector3(0, 0, 1), -0.04 + (sin(_t * 5.0) * 0.07 if sin(_t * 0.9) > 0.5 else 0.0))
	elif falando_com != null:      # conversando com a Dallarian: gesticula e olha para ela
		var g := sin(_t * 3.1) * 0.5 + 0.5
		alvo["R_Upperarm"] = _zx(0.55 + 0.15 * sin(_t * 2.3), 0.2); alvo["R_Forearm"] = _q(Vector3(0, 0, 1), 1.2 + 0.35 * g)
		alvo["L_Upperarm"] = _zx(0.25, -0.25); alvo["L_Forearm"] = _q(Vector3(0, 0, 1), 0.7)
		alvo["Head"] = _q(Vector3(0, 0, 1), 0.08 + sin(_t * 4.0) * 0.04)
	elif estado == "trabalho" and a < 0.3:
		match profissao:
			"ferreiro": _anim_ferreiro(alvo)
			"lenhador": hip = _anim_lenhador(alvo)
			"fazendeiro": hip = _anim_fazendeiro(alvo)
			"freira":                                         # parada orando: mãos juntas na frente do peito
				_pose_orar(alvo, resp)
				alvo["Head"] = _q(Vector3(0, 0, 1), -0.18) * _q(Vector3(0, 1, 0), sin(_t * 0.2) * 0.12)
			"cavalarico":                                     # parado de braços cruzados
				_pose_cruzados(alvo, resp)
				alvo["Head"] = _q(Vector3(0, 1, 0), sin(_t * 0.25) * 0.35)
	elif estado == "atividade" or (estado == "brincar" and a < 0.2 and _tempo_estado < 0.0):
		match atividade:
			"olhar":
				alvo["Head"] = _q(Vector3(0, 1, 0), sin(_t * 0.35) * 0.55) * _q(Vector3(0, 0, 1), sin(_t * 0.23) * 0.06)
				alvo["Spine01"] = _q(Vector3(0, 1, 0), sin(_t * 0.35) * 0.12)
			"cruzados":
				_pose_cruzados(alvo, resp)
				alvo["Head"] = _q(Vector3(0, 1, 0), sin(_t * 0.25) * 0.3)
			"cintura":       # mãos atrás das costas, peso numa perna
				alvo["L_Upperarm"] = _zx(-0.35, -0.42); alvo["R_Upperarm"] = _zx(-0.35, 0.42)
				alvo["L_Forearm"] = _q(Vector3(0, 0, 1), 0.5) * _q(Vector3(1, 0, 0), -0.6)
				alvo["R_Forearm"] = _q(Vector3(0, 0, 1), 0.5) * _q(Vector3(1, 0, 0), 0.6)
				alvo["Pelvis"] = _q(Vector3(1, 0, 0), 0.05)
				alvo["Head"] = _q(Vector3(0, 1, 0), sin(_t * 0.3) * 0.4)
			"cocar":         # coça a cabeça com uma mão
				alvo["R_Upperarm"] = _zx(1.9, 0.45); alvo["R_Forearm"] = _q(Vector3(0, 0, 1), 1.9 + sin(_t * 9.0) * 0.12)
				alvo["Head"] = _q(Vector3(0, 0, 1), -0.08) * _q(Vector3(0, 1, 0), 0.15)
			"debrucar":      # apoiado na beira do poço, olhando para dentro
				alvo["Spine01"] = _q(Vector3(0, 0, 1), -0.45); alvo["Spine02"] = _q(Vector3(0, 0, 1), -0.15)
				alvo["L_Upperarm"] = _zx(0.9, -0.15); alvo["R_Upperarm"] = _zx(0.9, 0.15)
				alvo["L_Forearm"] = _q(Vector3(0, 0, 1), 0.2); alvo["R_Forearm"] = _q(Vector3(0, 0, 1), 0.2)
				alvo["Head"] = _q(Vector3(0, 0, 1), -0.3)
			"agachar":       # agachado mexendo em algo no chão
				hip = -0.32
				alvo["L_Thigh"] = _q(Vector3(0, 0, 1), 1.25); alvo["R_Thigh"] = _q(Vector3(0, 0, 1), 0.95)
				alvo["L_Calf"] = _q(Vector3(0, 0, 1), -2.0); alvo["R_Calf"] = _q(Vector3(0, 0, 1), -1.5)
				alvo["Spine01"] = _q(Vector3(0, 0, 1), -0.35)
				alvo["R_Upperarm"] = _zx(0.9 + sin(_t * 2.5) * 0.15, 0.1); alvo["R_Forearm"] = _q(Vector3(0, 0, 1), 0.4)
				alvo["L_Upperarm"] = _zx(0.5, -0.1); alvo["L_Forearm"] = _q(Vector3(0, 0, 1), 0.9)
				alvo["Head"] = _q(Vector3(0, 0, 1), -0.35)
	# caminhada por cima (pesa conforme a velocidade de verdade)
	if a > 0.01:
		var sw := {}
		var co := _corre; var pe := 0.42 + 0.3 * co; var br := 0.35 + 0.45 * co
		sw["L_Thigh"] = _q(Vector3(0, 0, 1), pe * s + 0.15 * co); sw["R_Thigh"] = _q(Vector3(0, 0, 1), -pe * s + 0.15 * co)
		sw["L_Calf"] = _q(Vector3(0, 0, 1), -(0.6 + 0.8 * co) * max(0.0, -c)); sw["R_Calf"] = _q(Vector3(0, 0, 1), -(0.6 + 0.8 * co) * max(0.0, c))
		sw["L_Upperarm"] = _zx(-br * s, -0.32); sw["R_Upperarm"] = _zx(br * s, 0.32)
		sw["L_Forearm"] = _q(Vector3(0, 0, 1), 0.35 + 0.9 * co); sw["R_Forearm"] = _q(Vector3(0, 0, 1), 0.35 + 0.9 * co)
		sw["Spine01"] = _q(Vector3(0, 1, 0), 0.08 * s) * _q(Vector3(0, 0, 1), -0.18 * co); sw["Head"] = _q(Vector3(0, 0, 1), 0.1 * co)
		for k in sw.keys():
			alvo[k] = (alvo[k] if alvo.has(k) else Quaternion()).slerp(sw[k], a)
		hip = lerp(hip, abs(s) * (0.012 + 0.03 * _corre) - 0.006, a)
	# suaviza a troca de poses e aplica
	var f := 1.0 - exp(-7.0 * delta)
	for b in OSSOS:
		var q0: Quaternion = _pose.get(b, Quaternion())
		var q1: Quaternion = alvo.get(b, Quaternion())
		_pose[b] = q0.slerp(q1, f)
	_hip_y = lerp(_hip_y, hip, f)
	for b in OSSOS:
		if not _ids.has(b): continue
		var i: int = _ids[b]
		var pai := esq.get_bone_parent(i)
		var pg: Transform3D = esq.get_bone_global_pose(pai) if pai >= 0 else Transform3D.IDENTITY
		var pai_resto: Transform3D = esq.get_bone_global_rest(pai) if pai >= 0 else Transform3D.IDENTITY
		var g: Transform3D = pg * pai_resto.affine_inverse() * _resto[b]
		var qp: Quaternion = _pose[b]
		if profissao == "freira":
			qp = GIRO_FREIRA * qp * GIRO_FREIRA.inverse()
			if A_FREIRA.has(b): qp = qp * A_FREIRA[b]
		g.basis = Basis(qp) * g.basis
		if b == "Hip": g.origin += Vector3(0, _hip_y, 0)
		var loc := pg.affine_inverse() * g
		esq.set_bone_pose_position(i, loc.origin); esq.set_bone_pose_rotation(i, loc.basis.get_rotation_quaternion())

func _pose_orar(alvo: Dictionary, resp: float) -> void:
	alvo["L_Upperarm"] = _zx(PO[0], -PO[1] + resp * 0.015); alvo["R_Upperarm"] = _zx(PO[0], PO[1] - resp * 0.015)
	alvo["L_Forearm"] = _q(Vector3(0, 0, 1), PO[2]) * _q(Vector3(1, 0, 0), -PO[3])
	alvo["R_Forearm"] = _q(Vector3(0, 0, 1), PO[2]) * _q(Vector3(1, 0, 0), PO[3])
const PO := [0.4, 0.62, 1.3, 0.2]       # braço para a frente/dentro, antebraço dobrado, mãos se encontrando

func _pose_cruzados(alvo: Dictionary, resp: float) -> void:
	alvo["L_Upperarm"] = _zx(0.45, -0.55 + resp * 0.02); alvo["R_Upperarm"] = _zx(0.45, 0.55 - resp * 0.02)
	alvo["L_Forearm"] = _q(Vector3(0, 0, 1), 1.75) * _q(Vector3(1, 0, 0), -0.5)
	alvo["R_Forearm"] = _q(Vector3(0, 0, 1), 1.75) * _q(Vector3(1, 0, 0), 0.5)

# ---------- trabalho ----------
var _bateu := false
func _golpe_ciclo(periodo: float) -> float:
	# 0..1: sobe devagar (0–0,62), desce rápido (0,62–0,78), segura (0,78–1)
	var u := fmod(_t / periodo + rng.seed % 7 * 0.13, 1.0)
	var bate := u > 0.7 and u < 0.78
	if bate and not _bateu and ao_bater.is_valid(): ao_bater.call()
	_bateu = bate
	return u

func _anim_ferreiro(alvo: Dictionary) -> void:
	var u := _golpe_ciclo(1.15)
	var sobe := smoothstep(0.0, 0.62, u) * (1.0 - smoothstep(0.62, 0.74, u))
	alvo["R_Upperarm"] = _zx(0.55 + 1.15 * sobe, 0.35)
	alvo["R_Forearm"] = _q(Vector3(0, 0, 1), 0.55 + 1.0 * sobe)
	alvo["L_Upperarm"] = _zx(0.75, -0.2); alvo["L_Forearm"] = _q(Vector3(0, 0, 1), 0.9)      # segura a peça na bigorna
	alvo["Spine01"] = _q(Vector3(0, 0, 1), -0.18 - 0.08 * (1.0 - sobe))
	alvo["Head"] = _q(Vector3(0, 0, 1), -0.3)

func _anim_lenhador(alvo: Dictionary) -> float:
	var u := _golpe_ciclo(1.6)
	var sobe := smoothstep(0.0, 0.62, u) * (1.0 - smoothstep(0.62, 0.76, u))
	alvo["R_Upperarm"] = _zx(0.7 + 1.9 * sobe, 0.4)
	alvo["L_Upperarm"] = _zx(0.7 + 1.9 * sobe, -0.4)
	alvo["R_Forearm"] = _q(Vector3(0, 0, 1), 0.35 + 0.6 * sobe); alvo["L_Forearm"] = _q(Vector3(0, 0, 1), 0.35 + 0.6 * sobe)
	alvo["Spine01"] = _q(Vector3(0, 0, 1), -0.55 * (1.0 - sobe) + 0.1 * sobe)
	alvo["L_Thigh"] = _q(Vector3(0, 0, 1), 0.25); alvo["R_Thigh"] = _q(Vector3(0, 0, 1), -0.15)
	alvo["L_Calf"] = _q(Vector3(0, 0, 1), -0.3)
	alvo["Head"] = _q(Vector3(0, 0, 1), -0.25)
	return -0.05 * (1.0 - sobe)

func _anim_fazendeiro(alvo: Dictionary) -> float:
	if not campo.is_empty() and campo[5] == 0:
		# trigo: em pé, inclinado, colhendo — junta um feixe com a esquerda e corta com a direita
		var g := sin(_t * 2.0)
		alvo["Spine01"] = _q(Vector3(0, 0, 1), -0.5) * _q(Vector3(0, 1, 0), 0.25 * g)
		alvo["L_Thigh"] = _q(Vector3(0, 0, 1), 0.25); alvo["L_Calf"] = _q(Vector3(0, 0, 1), -0.35)
		alvo["L_Upperarm"] = _zx(1.0, -0.1); alvo["L_Forearm"] = _q(Vector3(0, 0, 1), 0.5)
		alvo["R_Upperarm"] = _zx(0.8 + 0.35 * g, 0.4 - 0.3 * g); alvo["R_Forearm"] = _q(Vector3(0, 0, 1), 0.4)
		alvo["Head"] = _q(Vector3(0, 0, 1), -0.25)
		return -0.04
	# terra arada: agachado cavando/arrancando mato com as duas mãos, alternando
	alvo["L_Thigh"] = _q(Vector3(0, 0, 1), 1.25); alvo["R_Thigh"] = _q(Vector3(0, 0, 1), 0.95)
	alvo["L_Calf"] = _q(Vector3(0, 0, 1), -2.0); alvo["R_Calf"] = _q(Vector3(0, 0, 1), -1.5)
	alvo["Spine01"] = _q(Vector3(0, 0, 1), -0.45)
	var a1 := sin(_t * 2.6); var a2 := sin(_t * 2.6 + PI)
	alvo["R_Upperarm"] = _zx(0.95 + 0.3 * a1, 0.15); alvo["R_Forearm"] = _q(Vector3(0, 0, 1), 0.35 + 0.35 * max(a1, 0.0))
	alvo["L_Upperarm"] = _zx(0.95 + 0.3 * a2, -0.15); alvo["L_Forearm"] = _q(Vector3(0, 0, 1), 0.35 + 0.35 * max(a2, 0.0))
	alvo["Head"] = _q(Vector3(0, 0, 1), -0.35) * _q(Vector3(0, 1, 0), sin(_t * 0.4) * 0.2)
	return -0.32

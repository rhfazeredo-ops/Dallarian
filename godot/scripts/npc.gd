# Morador: personagem do pacote Fantasy Kingdom (pelo papel ou pelo tipo), com as animações da Synty. Anda de
# um ponto a outro, para, olha em volta, conversa com outros; profissões ficam no posto (ferreiro, freira,
# vendedor...).
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
var rng := RandomNumberGenerator.new()


# tipos de corpo: ["", altura mín, máx, ritmo] (o modelo vem de TIPOS_PACOTE)
const TIPOS := {
	"fem": ["", 1.6, 1.7, 1.0],
	"gorda": ["", 1.5, 1.58, 0.85],
	"velha": ["", 1.42, 1.5, 0.65],
	"forte": ["", 1.88, 1.96, 1.0],
	"velho": ["", 1.64, 1.72, 0.7],
	"menino": ["", 1.22, 1.28, 1.0],
	"menina": ["", 1.17, 1.23, 1.0],
}
var tipo := ""                    # "" = sorteia entre as skins e os tipos acima
var ritmo := 1.0                  # velhos andam mais devagar
var _corre := 0.0                 # 0..1: quanto a animação é de corrida (crianças brincando)
# profissão: "" (morador comum), "ferreiro", "lenhador", "fazendeiro" — fica no posto trabalhando
var profissao := ""
var posto := Vector2.ZERO
var olhar_posto := Vector2.ZERO
var campo: Array = []             # fazendeiro: o campo (centro x, z, largura, comprimento, ângulo°, tipo)
var gesticula := true              # enquanto conversa: true = ele fala (gesticula), false = escuta
var falando_com: Node3D = null    # o jogador, quando está conversando com ele
var ao_bater: Callable            # chamado no instante do golpe (faíscas/lascas)
# a freira do Tripo veio de frente para +Z (os outros olham para +X): as poses (pensadas para +X) giram 90° para ela
# e veio em pose de T (braços na horizontal); os moradores descansam com os braços ~58° para baixo (pose em A)
# ferramentas: [arquivo, eixo do cabo no arquivo (para a cabeça), ponto de pegada, direção da lâmina/face, comprimento no arquivo, comprimento real (m)]

func montar(mundo, semente: int, centro: Vector2, raio: float) -> void:
	var _t0 := Time.get_ticks_usec()
	m = mundo; rng.seed = semente; area_centro = centro; area_raio = raio
	var sorteio := rng.randf()
	if tipo == "" and profissao == "" and sorteio >= 0.44:
		tipo = ["fem", "fem", "gorda", "velha", "forte", "velho"][int((sorteio - 0.44) / 0.56 * 6.0) % 6]
	var alt := rng.randf_range(1.62, 1.86); var larg := rng.randf_range(0.92, 1.12)
	if tipo != "":
		var tp: Array = TIPOS[tipo]; alt = rng.randf_range(tp[1], tp[2]); larg = rng.randf_range(0.97, 1.03); ritmo = tp[3]
	var cs := CollisionShape3D.new(); var cap := CapsuleShape3D.new(); cap.radius = 0.3 if alt > 1.4 else 0.24
	cap.height = alt - 0.1; cs.shape = cap; cs.position = Vector3(0, cap.height * 0.5, 0); add_child(cs)
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING      # anda no plano; a altura vem do terreno
	# modelo: 0,98 m no arquivo, de frente para -X → girado para frente = -Z e escalado
	visual = Node3D.new(); add_child(visual)
	_montar_pacote(alt)                        # personagens do pacote Fantasy Kingdom, pelo papel de cada um

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

# ---------- animação (AnimationPlayer com as animações da Synty) ----------
var _anim_acum := 0.0
var _anim_quadro := 0
var _dist_j := 0.0


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


# ---------- trabalho ----------
var _bateu := false

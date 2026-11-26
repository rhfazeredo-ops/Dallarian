# Corpo do herói em terceira pessoa: o personagem do pacote Fantasy Kingdom (a Cavaleira ou o Príncipe) com as
# animações do Sword and Shield (combate) e da Synty (fora de combate), escolhidas pelo estado do jogador a cada
# passo da física. Espada e escudo presos às mãos (mao_d/mao_e) ou guardados na cintura e nas costas.
extends Node3D
class_name CorpoHeroi

var j                               # o jogador
var mod: Node3D
var esq: Skeleton3D
var k := 1.0                        # escala do modelo (o arquivo tem 0,98 de altura)
var mao_d: Node3D                   # espada (cabo na origem, lâmina em +Y)
var mao_e: Node3D                   # escudo (frente em +Y)
var _yaw := 0.0
var giro_teste := 0.0               # teste: vira o corpo para a câmera ver de frente/lado


# boneco parado para as telas de seleção/criação (sem jogador): em guarda, respirando
class Manequim:
	var velocity := Vector3.ZERO; var rotation := Vector3.ZERO; var _acao := ""; var bloqueando := false; var alvo = null
	var montado := false; var morta := false; var _t_morte := 0.0; var _tempo := 0.0; var congelar := -1.0
	var _fase := 0; var _t_acao := 0.0; var _passo_acao := 0; var GOLPES := {}
	var armado := false; var _sacando := 0.0; var _guardando := 0.0; const SACAR_T := 1.0; const GUARDAR_T := 1.0
	func is_on_floor() -> bool: return true

func montar(jogador, arq: String, no_mundo := true) -> void:
	j = jogador if jogador != null else Manequim.new()
	_arq = arq
	_montar_ap.call_deferred()
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_montar_mh(arq.trim_prefix("fk:"), no_mundo)

# ---------- heróis do pacote Fantasy Kingdom (esqueleto da Synty; olha para +Z) ----------
const FK_TEX := "res://arte/fk/texturas/PolygonFantasyKingdom_Texture_01_A.png"
var mh := false
# direção no espaço do esqueleto do Tripo (+X frente, +Y cima, +Z direita) → no da Synty (+Z frente, +Y cima, -X direita)
func _cv(v: Vector3) -> Vector3: return Vector3(-v.z, v.y, v.x) if mh else v
func _osso(n: String) -> String:
	if not mh: return n
	return {"R_Hand": "Hand_R", "R_Mid1": "Finger_01_2", "L_Hand": "Hand_L", "L_Mid1": "Finger_01", "Hip": "Hips", "Spine02": "Spine_03",
		"R_Upperarm": "Shoulder_R", "R_Forearm": "Elbow_R"}.get(n, n)
# fk = nome de um personagem do Fantasy Kingdom (ex.: SM_Chr_Nun_01): mesmo esqueleto da Synty, outra textura
func _montar_mh(fk: String, no_mundo: bool) -> void:
	mh = true; k = 1.0
	mod = load(Cidadao.ARQ).instantiate(); add_child(mod); mod.rotation_degrees.y = 180
	esq = mod.find_children("*", "Skeleton3D", true, false)[0]
	var partes := [fk]
	var tex: Texture2D = load(FK_TEX)
	var mt: Material
	if no_mundo:
		var sm := ShaderMaterial.new(); sm.shader = load("res://shaders/ps1.gdshader"); sm.set_shader_parameter("tex", tex)
		sm.set_shader_parameter("sem_cor_vertice", true)
		var cena: Node = get_tree().current_scene
		if cena and "NEBLINA" in cena: sm.set_shader_parameter("neblina", cena.NEBLINA)
		mt = sm
	else:
		var st := StandardMaterial3D.new(); st.albedo_texture = tex; st.albedo_color = Color(0.85, 0.83, 0.83); mt = st
	for c in mod.find_children("*", "MeshInstance3D", true, false):
		if not c.name in partes: c.queue_free()
		else: (c as MeshInstance3D).material_override = mt
	var B := func(a: Vector3, b: Vector3, c: Vector3) -> Basis: return Basis(_cv(a), _cv(b), _cv(c))
	mao_d = _presa("R_Hand", "R_Mid1", B.call(Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)), 0.85)
	mao_e = _presa("L_Hand", "L_Mid1", B.call(Vector3(0, 1, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0)), 1.0)
	var lam := Vector3(-0.4, -0.92, 0.0).normalized(); var face := Vector3(0, 0, -1)
	costas_d = _no_osso("Hip", _cv(Vector3(0.03, -0.01, -0.115)), B.call(lam.cross(face), lam, face), 0.85)
	costas_e = _no_osso("Spine02", _cv(Vector3(-0.2, 0.0, 0.0)), B.call(Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1)), 1.0)   # frente do escudo para fora das costas
	_braco = BracoSacar.new(); _braco.c = self; esq.add_child(_braco)
	_sentar = Sentar.new(); esq.add_child(_sentar)
var _sentar: Sentar

# montado (herói da Synty): coxas para a frente e abertas, canelas para baixo (direções no espaço do esqueleto, +Z frente)
class Sentar extends SkeletonModifier3D:
	var peso := 0.0
	const ALVO := [["UpperLeg_L", "LowerLeg_L", Vector3(0.45, -0.3, 0.85)], ["UpperLeg_R", "LowerLeg_R", Vector3(-0.45, -0.3, 0.85)],
		["LowerLeg_L", "Ankle_L", Vector3(0.25, -1.0, -0.1)], ["LowerLeg_R", "Ankle_R", Vector3(-0.25, -1.0, -0.1)]]
	func _process_modification() -> void:
		var sk := get_skeleton()
		if sk == null or peso <= 0.001: return
		for a in ALVO:
			var i := sk.find_bone(a[0]); var f := sk.find_bone(a[1])
			if i < 0 or f < 0: continue
			var g := sk.get_bone_global_pose(i)
			var atual := (sk.get_bone_global_pose(f).origin - g.origin).normalized()
			var q := Quaternion.IDENTITY.slerp(Quaternion(atual, (a[2] as Vector3).normalized()), peso)
			var pg := sk.get_bone_global_pose(sk.get_bone_parent(i))
			sk.set_bone_pose_rotation(i, (pg.basis.inverse() * (Basis(q) * g.basis)).get_rotation_quaternion())

var costas_d: Node3D               # espada guardada (na cintura)
var costas_e: Node3D               # escudo guardado (nas costas)
var _braco: BracoSacar
func _no_osso(osso: String, desvio: Vector3, b: Basis, esc: float) -> Node3D:
	osso = _osso(osso)
	var i := esq.find_bone(osso)
	var at := BoneAttachment3D.new(); at.bone_name = osso; esq.add_child(at)
	var r := esq.get_bone_global_rest(i)
	var no := Node3D.new(); no.transform = r.affine_inverse() * Transform3D(b.orthonormalized(), r.origin + desvio); at.add_child(no)
	var h := Node3D.new(); h.scale = Vector3.ONE * esc / k; no.add_child(h)
	return h

# passa os modelos da espada e do escudo entre as mãos e as costas
func armas_na_mao(sim: bool) -> void:
	for par in [[mao_d, costas_d], [mao_e, costas_e]]:
		var de: Node3D = par[1] if sim else par[0]; var para: Node3D = par[0] if sim else par[1]
		if de == null or para == null: continue
		for c in de.get_children(): c.reparent(para, false)

func _presa(osso: String, dedo: String, b: Basis, esc: float) -> Node3D:
	osso = _osso(osso); dedo = _osso(dedo)
	var i := esq.find_bone(osso)
	var at := BoneAttachment3D.new(); at.bone_name = osso; esq.add_child(at)
	var rh := esq.get_bone_global_rest(i)
	var di := esq.find_bone(dedo)
	var pega: Vector3 = rh.origin.lerp(esq.get_bone_global_rest(di).origin, 0.6) if di >= 0 else rh.origin
	var no := Node3D.new(); no.transform = rh.affine_inverse() * Transform3D(b.orthonormalized(), pega); at.add_child(no)
	var h := Node3D.new(); h.scale = Vector3.ONE * esc / k; no.add_child(h)
	return h

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
	# animações do pacote (Sword and Shield e Synty, convertidas para o esqueleto do herói)
	if _ap == null: return
	if j.montado:                                                        # no cavalo: parado, pernas abertas no lombo
		rotation.x = 0.0; position.y = 0.95; _braco.peso = 0.0; _sentar.peso = 1.0
		_tocar("calmo_parado", 1.0, 0.25); return
	_sentar.peso = 0.0
	rotation.x = 0.0; position.y = 0.0
	_clipes(vel, vh, no_chao, para_tras, luta)
# ---------- animações do pacote ----------
var _ap: AnimationPlayer
var _arq := ""
var _atual := ""
var _acao_ant := ""
func _montar_ap() -> void:
	var lib := "res://arte/animacoes/heroi_fk_%s.res" % ("Femn" if _arq.trim_prefix("fk:") in Cidadao.MULHERES else "Masc")
	if not ResourceLoader.exists(lib) or mod == null: return
	_ap = AnimationPlayer.new(); mod.add_child(_ap); _ap.root_node = NodePath("..")
	_ap.add_animation_library("", load(lib))
	_ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS if j is Node else AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	_ap.play("parado" if j.armado else "calmo_parado")

const GOLPE_CLIPE := {"leve1": "golpe1", "leve2": "golpe2", "leve3": "golpe3", "forte": "golpe_forte"}
func _tocar(nome: String, velo := 1.0, mistura := 0.18, do_comeco := false) -> void:
	if nome != _atual or do_comeco:
		_ap.play(nome, mistura); _atual = nome
		if do_comeco: _ap.seek(0.0, true)
	_ap.speed_scale = velo

func _clipes(vel: float, vh: Vector2, no_chao: bool, para_tras: bool, luta: bool) -> void:
	if j.morta: _tocar("morte", 1.0, 0.25); return
	# sacar/guardar: a guarda (ou o parado calmo) por baixo e o braço levado à cintura por cima (BracoSacar)
	_braco.peso = 0.0
	if j._sacando > 0.0:
		var u: float = 1.0 - j._sacando / j.SACAR_T
		_braco.peso = smoothstep(0.0, 0.3, u) * (1.0 - smoothstep(0.45, 0.85, u))
		_tocar("parado", 1.0, 0.4); return
	if j._guardando > 0.0:
		var u: float = 1.0 - j._guardando / j.GUARDAR_T
		_braco.peso = smoothstep(0.1, 0.4, u) * (1.0 - smoothstep(0.6, 0.95, u))
		_tocar("calmo_parado" if u > 0.5 else "parado", 1.0, 0.4); return
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
	var bash_nova: bool = acao == "bash" and _acao_ant != "bash"
	_acao_ant = acao
	if acao == "bash": _tocar("escudada", 1.5 / 0.7, 0.06, bash_nova); return
	if j.bloqueando: _tocar("bloqueio", 1.0, 0.12); return
	# lutando (armas na mão): os movimentos do pacote Sword and Shield
	if j.armado:
		_ar_estado(no_chao)
		if not no_chao: _tocar("no_ar", 1.0, 0.15); return
		if vel < 0.4: _tocar("parado", 1.0, 0.3); return
		var local := vh.rotated(j.rotation.y + rotation.y)               # no espaço do corpo (−y = frente)
		var lado := ""
		if luta and absf(local.x) > absf(local.y): lado = "_dir" if local.x > 0.0 else "_esq"
		elif para_tras or local.y > 0.3 * vel: lado = "_tras"
		if vel < 2.4: _tocar("andar" + lado, clampf(vel / 1.5, 0.6, 1.6))
		elif vel < 6.5 or lado != "": _tocar("correr" + lado, clampf(vel / 4.6, 0.7, 1.6))
		else: _tocar("disparada", clampf(vel / 7.0, 0.8, 1.5))
		return
	_calmo(vel, vh, no_chao, para_tras)

# ---------- fora de combate: só animações da Synty (Base Locomotion) ----------
# Pulo: os clipes da Synty são o pulo inteiro (agacha, sobe, cai, aterrissa) e duram 2–3 s; o nosso fica ~0,75 s no
# ar. Então o clipe começa no instante em que os pés saem do chão e o trecho no ar acompanha a velocidade vertical.
# [clipe, saída do chão (s), chegada ao chão (s)] — medidos na altura do quadril de cada clipe
const PULOS := {"parado": ["calmo_pulo", 0.6, 1.35], "andando": ["calmo_pulo_andando", 1.05, 1.75],
	"correndo": ["calmo_pulo_correndo", 0.5, 1.25], "disparada": ["calmo_pulo_disparada", 0.45, 1.0]}
var _pulo := ""                  # pulo em andamento (chave de PULOS) ou "" (caindo sem ter pulado)
var _no_ar := 0.0                # tempo no ar
var _vy_min := 0.0               # a maior velocidade de queda (para a força da aterrissagem)
var _aterr := 0.0                # tempo que falta da aterrissagem
var _transicao := 0.0            # começar a andar/correr ou parar: tempo que falta
var _vel_ant := 0.0
var _chao_ant := true
func _ar_estado(no_chao: bool) -> void:
	if not no_chao: _no_ar += get_physics_process_delta_time(); _vy_min = minf(_vy_min, j.velocity.y)
	else: _no_ar = 0.0
	_chao_ant = no_chao

func _calmo(vel: float, vh: Vector2, no_chao: bool, para_tras: bool) -> void:
	var dt := get_physics_process_delta_time()
	_aterr = maxf(_aterr - dt, 0.0); _transicao = maxf(_transicao - dt, 0.0)
	# --- no ar ---
	if not no_chao:
		if _chao_ant:                                   # acabou de sair do chão
			_vy_min = 0.0; _no_ar = 0.0
			_pulo = ""
			if j.velocity.y > 2.0:                      # foi pulo (não só escorregou de um degrau)
				_pulo = "parado" if _vel_ant < 0.8 else ("andando" if _vel_ant < 2.4 else ("correndo" if _vel_ant < 6.5 else "disparada"))
		_no_ar += dt; _vy_min = minf(_vy_min, j.velocity.y); _chao_ant = false
		if _pulo != "":
			var p: Array = PULOS[_pulo]
			var subida := 4.8                           # a velocidade do pulo (jogador.PULO)
			var u := clampf((subida - j.velocity.y) / (2.0 * subida), 0.0, 1.0)
			if j.velocity.y < -subida * 1.4: _tocar("calmo_queda", 1.0, 0.3); return    # caiu de muito alto
			_tocar(p[0], 1.0, 0.06, _no_ar <= dt * 1.5)
			_ap.seek(lerpf(float(p[1]), float(p[2]) - 0.05, u), true)
			return
		_tocar("calmo_queda" if _no_ar > 0.6 else "calmo_no_ar", 1.0, 0.25); return
	# --- chegou no chão ---
	if not _chao_ant:
		_chao_ant = true
		if _pulo != "" and vel >= 0.4 and _vy_min > -7.0:   # pulo correndo: o fim do próprio clipe emenda na corrida
			_pulo = ""
		elif _no_ar > 0.25:
			var forca := "leve" if _vy_min > -6.0 else ("media" if _vy_min > -10.0 else "forte")
			var nome := "calmo_aterrissa_" + forca
			if vel < 0.4 or forca == "forte":
				_tocar(nome, 1.2, 0.08, true); _aterr = _ap.get_animation(nome).length / 1.2 * (0.6 if forca == "leve" else 0.8)
		_pulo = ""
	_vel_ant = vel
	if _aterr > 0.0 and vel < 0.4: return
	# --- parado / parando ---
	if vel < 0.4:
		if _atual in ["calmo_correr", "calmo_disparada", "calmo_correr_sobe", "calmo_correr_desce", "calmo_disparada_sobe", "calmo_disparada_desce"]:
			_tocar("calmo_parar_correndo", 1.3, 0.12, true); _transicao = 0.9 / 1.3; return
		if _atual in ["calmo_andar", "calmo_andar_sobe", "calmo_andar_desce"]:
			_tocar("calmo_parar_andando", 1.4, 0.15, true); _transicao = 0.9 / 1.4; return
		if _transicao > 0.0 and _atual.begins_with("calmo_parar"): return
		_tocar("calmo_parado", 1.0, 0.3); return
	# --- começando a andar/correr (do parado) ---
	if _atual in ["calmo_parado", "calmo_parar_andando", "calmo_parar_correndo"] or _atual.begins_with("calmo_aterrissa"):
		_tocar("calmo_comecar_correr" if j.velocity.length() > 3.0 or vel > 1.0 else "calmo_comecar_andar", 1.6, 0.1, true); _transicao = 0.3
		return
	if _transicao > 0.0 and _atual.begins_with("calmo_comecar"): return
	# --- andando / correndo, de frente ou para trás, subindo ou descendo morro ---
	var local := vh.rotated(j.rotation.y + rotation.y)
	if para_tras or local.y > 0.3 * vel:
		if vel < 2.4: _tocar("calmo_andar_tras", clampf(vel / 1.5, 0.6, 1.6))
		else: _tocar("calmo_correr_tras", clampf(vel / 4.6, 0.7, 1.6))
		return
	var rampa := ""
	var n: Vector3 = j.get_floor_normal() if j is Node else Vector3.UP
	if n.y > 0.3:
		var d := vh.normalized()
		var incl := -(n.x * d.x + n.z * d.y) / n.y     # quanto sobe por metro andado
		if incl > 0.22: rampa = "_sobe"
		elif incl < -0.22: rampa = "_desce"
	if vel < 2.4: _tocar("calmo_andar" + rampa, clampf(vel / 1.5, 0.6, 1.6))
	else: _tocar("calmo_correr" + rampa, clampf(vel / 4.6, 0.7, 1.6))       # (o sprint da Synty é curvado demais: a corrida acelerada fica melhor)

# Sacar/guardar da cintura: depois das animações, leva a mão direita até o lado esquerdo do quadril (onde está a
# espada) e devolve; "peso" 0..1 vem do tempo do sacar/guardar. Direções no espaço do esqueleto (+X frente, +Z direita).
class BracoSacar extends SkeletonModifier3D:
	var c: CorpoHeroi
	var peso := 0.0
	const ALVO := {"R_Upperarm": Vector3(0.5, -0.8, -0.3), "R_Forearm": Vector3(0.3, -0.3, -0.9)}
	func _process_modification() -> void:
		var sk := get_skeleton()
		if sk == null or peso <= 0.001: return
		var e := sk.find_bone(c._osso("Spine02"))
		if e >= 0:                         # o tronco vira um pouco para a esquerda, junto com o braço
			sk.set_bone_pose_rotation(e, sk.get_bone_pose_rotation(e) * Quaternion(Vector3.UP, 0.3 * peso))
		for b in ["R_Upperarm", "R_Forearm"]:
			var i := sk.find_bone(c._osso(b)); var f := sk.find_bone(c._osso({"R_Upperarm": "R_Forearm", "R_Forearm": "R_Hand"}[b]))
			if i < 0 or f < 0: continue
			var g := sk.get_bone_global_pose(i)
			var atual := (sk.get_bone_global_pose(f).origin - g.origin).normalized()
			var q := Quaternion.IDENTITY.slerp(Quaternion(atual, c._cv(ALVO[b] as Vector3).normalized()), peso)
			var pg := sk.get_bone_global_pose(sk.get_bone_parent(i))
			sk.set_bone_pose_rotation(i, (pg.basis.inverse() * (Basis(q) * g.basis)).get_rotation_quaternion())

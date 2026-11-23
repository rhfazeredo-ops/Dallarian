# Monstros com esqueleto de humanoide (o mesmo esqueleto do NPC base): Lodosos (grande e jovem, com lança de osso)
# e o chefe Grumo, o golem de terra. Animação procedural nos ossos, como a dos moradores:
#  andar, correr, atacar (Lodoso: estocada de lança; golem: soco e PANCADA com as duas mãos no chão, dano em área)
#  e morrer (cai de costas). Mesmo "contrato" dos lobos para a espada da Rachel (grupo "lobos").
extends CharacterBody3D
class_name Monstro

const TIPOS := {
	# arquivo, altura (m), vida base, por nível, dano mín/máx base, por nível, vel. andar, vel. correr, alcance, xp ×
	# Lodosos (peixe-sapo): a arma vem no próprio modelo, presa na mão direita (tools/arma-na-mao.mjs)
	"lodoso_j": {"arq": "res://assets/modelos/lodoso_n1.glb", "alt": 0.95, "vida": 24.0, "vida_nv": 10.0,       # Jovem
		"dano": Vector2(1.5, 3.0), "dano_nv": 1.2, "andar": 1.5, "correr": 5.0, "alcance": 2.3, "xp": 0.8, "lanca": true},
	"lodoso_g": {"arq": "res://assets/modelos/lodoso_n2.glb", "alt": 1.25, "vida": 34.0, "vida_nv": 13.0,       # Pescador
		"dano": Vector2(2.5, 4.5), "dano_nv": 1.5, "andar": 1.3, "correr": 4.6, "alcance": 2.6, "xp": 1.0, "lanca": true},
	"lodoso_x": {"arq": "res://assets/modelos/lodoso_n3.glb", "alt": 1.15, "vida": 28.0, "vida_nv": 11.0,       # Xamã da Lama
		"dano": Vector2(3.0, 5.0), "dano_nv": 1.6, "andar": 1.2, "correr": 4.2, "alcance": 2.5, "xp": 1.3, "lanca": true},
	"lodoso_c": {"arq": "res://assets/modelos/lodoso_boss.glb", "alt": 1.8, "vida": 90.0, "vida_nv": 22.0,      # Grão-Lodoso
		"dano": Vector2(5.0, 8.0), "dano_nv": 2.0, "andar": 1.2, "correr": 4.4, "alcance": 3.0, "xp": 2.5, "lanca": true},
	"golem": {"arq": "res://assets/modelos/golem.glb", "alt": 9.0, "vida": 520.0, "vida_nv": 70.0,
		"dano": Vector2(14.0, 20.0), "dano_nv": 2.0, "andar": 2.2, "correr": 4.4, "alcance": 6.0, "xp": 4.0, "lanca": false},
}
const OSSOS := ["Hip", "Spine01", "Spine02", "L_Thigh", "R_Thigh", "L_Calf", "R_Calf", "L_Upperarm", "R_Upperarm",
	"L_Forearm", "R_Forearm", "Head"]
var tipo := "lodoso_j"
var cfg: Dictionary
var nivel := 2
var nome := ""
var m
var grupo: Dictionary              # casa, membros, alerta (o golem tem um grupo só dele)
var rota: Array = []               # golem: pontos da volta pelo mapa
var _rota_i := 0
var vida := 50.0
var vida_max := 50.0
var estado := "vagar"              # vagar, parado, cacar, atacar, ferido, morto
var rng := RandomNumberGenerator.new()
var visual: Node3D
var esq: Skeleton3D
var k := 1.0
var _t := 0.0
var _fase := 0.0
var _alvo := Vector2.ZERO
var _espera := 2.0
var _recarga := 0.0
var _golpe := ""                   # soco, pancada, estocada
var _acertou := false
var _flash := 0.0
var _mats: Array[ShaderMaterial] = []
var _pose := {}
var _resto := {}
var _ids := {}
var _hip_y := 0.0
var _anda := 0.0
var _anim_acum := 0.0
var _anim_q := 0
var anim_fixa := ""                # teste: "andar", "correr", "soco:u", "pancada:u", "estocada:u", "morto:u"

func montar(mundo, t: String, nv: int, semente: int) -> void:
	m = mundo; tipo = t; nivel = nv; rng.seed = semente; cfg = TIPOS[tipo]
	add_to_group("lobos")
	vida_max = cfg.vida + cfg.vida_nv * nivel; vida = vida_max
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	visual = Node3D.new(); add_child(visual)
	var mod: Node3D = load(cfg.arq).instantiate(); visual.add_child(mod); _mod = mod
	var alt: float = cfg.alt * (rng.randf_range(0.94, 1.06) if tipo != "golem" else 1.0)
	k = alt / 0.97
	mod.scale = Vector3(k, k, k); mod.rotation_degrees.y = 90          # o modelo olha para +X → -Z
	esq = mod.find_children("*", "Skeleton3D", true, false)[0]
	for n in mod.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n
		var orig: BaseMaterial3D = mi.mesh.surface_get_material(0)
		var sm := ShaderMaterial.new(); sm.shader = load("res://shaders/npc.gdshader")
		if orig: sm.set_shader_parameter("tex", orig.albedo_texture)
		sm.set_shader_parameter("original", true); sm.set_shader_parameter("neblina", m.NEBLINA)
		mi.material_override = sm; _mats.append(sm)
		mi.visibility_range_end = 200.0 if tipo == "golem" else 95.0
	for b in OSSOS:
		var i := esq.find_bone(b)
		if i >= 0: _ids[b] = i; _resto[b] = esq.get_bone_global_rest(i)
	if cfg.lanca: _montar_arma()
	var cs := CollisionShape3D.new(); var cap := CapsuleShape3D.new()
	cap.radius = alt * (0.22 if tipo == "golem" else 0.28); cap.height = alt * 0.95
	cs.shape = cap; cs.position = Vector3(0, cap.height * 0.5, 0); add_child(cs)
	_fase = rng.randf() * TAU
	_alvo = Vector2(global_position.x, global_position.z)

# arma (lança, cajado, tridente) num pivô que segue a POSIÇÃO da mão direita, com a inclinação controlada à parte:
# em pé andando, deitada para a frente na estocada (tools/separar-arma.mjs tira a arma do corpo do Tripo)
var _mod: Node3D
var _arma: Node3D
var _mao := -1
var _esq_no_mod := Transform3D.IDENTITY     # esqueleto no espaço do modelo
var _incl := 0.0
func _montar_arma() -> void:
	var arq: String = String(cfg.arq).replace(".glb", "_arma.glb")
	_mao = esq.find_bone("R_Hand")
	if _mao < 0 or not ResourceLoader.exists(arq): return
	var n: Node = esq
	while n != _mod: _esq_no_mod = (n as Node3D).transform * _esq_no_mod; n = n.get_parent()
	var pega: Vector3 = _esq_no_mod * esq.get_bone_global_rest(_mao).origin
	_arma = Node3D.new(); _mod.add_child(_arma)
	var malha: Node3D = m.modelo_ps1(arq); malha.position = -pega; _arma.add_child(malha)
	for mi in malha.find_children("*", "MeshInstance3D", true, false): mi.visibility_range_end = 95.0
	_pos_arma()

func _pos_arma() -> void:
	if _arma == null: return
	var mao: Vector3 = _esq_no_mod * esq.get_bone_global_pose(_mao).origin
	_arma.transform = Transform3D(Basis(Vector3(0, 0, 1), -_incl), mao)     # +incl = ponta para a frente

# ---------- voz dos Lodosos (gritos gravados pelo dono, cortados em vários; em 3D) ----------
static var _vozes := {}
var _voz: AudioStreamPlayer3D
var _prox_grito := 0.0
func _gritar(forte: bool) -> void:
	if not tipo.begins_with("lodoso"): return
	var agora := Time.get_ticks_msec() / 1000.0
	if agora < _prox_grito: return
	var grupo_voz := "boss" if tipo == "lodoso_c" else ("pequeno" if tipo == "lodoso_j" else "normal")
	if not _vozes.has(grupo_voz):
		var l := []
		for i in range(1, 6):
			var arq := "res://assets/som/lodoso/lodoso_%s_%d.ogg" % [grupo_voz, i]
			if ResourceLoader.exists(arq): l.append(load(arq))
		_vozes[grupo_voz] = l
	var lista: Array = _vozes[grupo_voz]
	if lista.is_empty(): return
	if _voz == null:
		_voz = AudioStreamPlayer3D.new(); _voz.bus = "Efeitos"; _voz.position = Vector3(0, k * 0.85, 0)
		_voz.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE; _voz.unit_size = 6.0 if tipo == "lodoso_c" else 4.5
		_voz.max_distance = 50.0; _voz.volume_db = -2.0 if forte else -5.0; add_child(_voz)
	_voz.stream = lista[rng.randi() % lista.size()]
	_voz.pitch_scale = rng.randf_range(0.86, 0.94) if tipo == "lodoso_x" else rng.randf_range(0.95, 1.08)
	_voz.play()
	_prox_grito = agora + rng.randf_range(3.0, 6.0)

# ---------- comportamento ----------
func _mudar(e: String) -> void:
	estado = e; _t = 0.0

func _physics_process(delta: float) -> void:
	if m == null or m.jogador == null: return
	_t += delta; _recarga -= delta; _flash = maxf(0.0, _flash - delta * 4.0)
	if anim_fixa != "": _animar(delta, _vel_teste()); return
	var pj: Vector3 = m.jogador.global_position
	var p := Vector2(global_position.x, global_position.z); var ppj := Vector2(pj.x, pj.z)
	var dist := p.distance_to(ppj)
	if dist > 120.0 and tipo != "golem" and not grupo.alerta: return
	var dir := Vector2.ZERO; var vel := 0.0; var olhar := Vector2.ZERO
	match estado:
		"vagar":
			if tipo == "golem":                       # dá a volta no mapa sem parar
				var alvo: Vector2 = rota[_rota_i]
				if p.distance_to(alvo) < 3.0: _rota_i = (_rota_i + 1) % rota.size()
				dir = (alvo - p).normalized(); vel = cfg.andar
			else:
				var d := _alvo - p
				if d.length() < 0.5:
					_mudar("parado"); _espera = rng.randf_range(2.0, 6.0)
				else: dir = d.normalized(); vel = cfg.andar
				if _t > 10.0: _mudar("parado"); _espera = 2.0
		"parado":
			if _t > _espera:
				var a := rng.randf() * TAU
				_alvo = grupo.casa + Vector2(cos(a), sin(a)) * rng.randf_range(1.5, 7.0); _mudar("vagar")
		"cacar":
			var longe := 40.0 if tipo != "golem" else 55.0
			if dist > longe or m.heroina_desmaiada or (tipo != "golem" and p.distance_to(grupo.casa) > 60.0):
				grupo.alerta = false; _mudar("vagar")
			else:
				olhar = ppj
				if dist > cfg.alcance * 0.8: dir = (ppj - p).normalized(); vel = cfg.correr * (0.6 if dist < 5.0 else 1.0)
				if dist < cfg.alcance and _recarga <= 0.0: _atacar(dist)
		"atacar":
			olhar = ppj
			_tocar_golpe(ppj, dist)
		"ferido":
			olhar = ppj
			if _t > 0.3: _mudar("cacar")
		"morto":
			velocity = Vector3.ZERO
			if _t < 3.0: _animar(delta, 0.0)      # depois fica no chão (o saque.gd tira em 3 min)
			return
	var raio_ver := 18.0 if tipo != "golem" else 30.0
	if not grupo.alerta and (estado == "vagar" or estado == "parado") and dist < raio_ver and not m.heroina_desmaiada:
		grupo.alerta = true
		if tipo != "golem": m.hud.numero(global_position + Vector3(0, k * 1.1, 0), "!", Color(1, 0.3, 0.2), 60)
		_gritar(true)
	if grupo.alerta and (estado == "vagar" or estado == "parado"): _mudar("cacar")
	# espaço entre os do grupo
	var sep := Vector2.ZERO
	for o in grupo.membros:
		if o != self and is_instance_valid(o) and o.estado != "morto":
			var dd := p - Vector2(o.global_position.x, o.global_position.z)
			if dd.length() < 1.8 and dd.length() > 0.01: sep += dd.normalized() * (1.8 - dd.length())
	var v2 := dir * vel + sep * 1.5
	velocity = Vector3(v2.x, 0, v2.y)
	if tipo == "golem" and estado == "vagar": global_position += velocity * delta     # o chefe passa por cima de tudo
	else: move_and_slide()
	if m.na_agua(global_position.x, global_position.z) and not m.na_agua(p.x, p.y):   # não entra na água
		global_position.x = p.x; global_position.z = p.y
	global_position.y = m.altura_malha(global_position.x, global_position.z)
	var foco := olhar if olhar != Vector2.ZERO else p + v2
	if (foco - p).length() > 0.05:
		var dl := foco - p
		rotation.y = lerp_angle(rotation.y, atan2(-dl.x, -dl.y), 1.0 - exp(-(3.0 if tipo == "golem" else 8.0) * delta))
	if tipo == "golem" and estado == "vagar" and dist < 45.0:      # o chão treme com os passos
		m.jogador._tranco += Vector3(sin(_fase * 2.0) * 0.25 * (1.0 - dist / 45.0), 0, 0)
	_anim_acum += delta; _anim_q += 1
	var passo := 1 if dist < 30.0 else (2 if dist < 60.0 else 4)
	if _anim_q % passo == 0:
		_animar(_anim_acum, Vector2(get_real_velocity().x, get_real_velocity().z).length() if not (tipo == "golem" and estado == "vagar") else vel)
		_anim_acum = 0.0

func _atacar(dist: float) -> void:
	_acertou = false
	if tipo == "golem": _golpe = "pancada" if (rng.randf() < 0.4 or dist < 3.5) else "soco"
	else: _golpe = "estocada"
	_mudar("atacar")
	if rng.randf() < 0.4: _gritar(false)

# tempos dos golpes: [preparar, bater (instante do dano), terminar]
func _tempos() -> Vector3:
	match _golpe:
		"soco": return Vector3(0.55, 0.75, 1.3)
		"pancada": return Vector3(1.1, 1.35, 2.2)      # levanta os braços 1,1 s antes: dá tempo de sair
		_: return Vector3(0.35, 0.5, 0.95)

func _tocar_golpe(ppj: Vector2, dist: float) -> void:
	var tt := _tempos()
	if _t >= tt.y and not _acertou:
		_acertou = true
		var p := Vector2(global_position.x, global_position.z)
		var fr := Vector2(-sin(rotation.y), -cos(rotation.y))
		if _golpe == "pancada":
			m.pancada_no_chao(global_position + Vector3(fr.x, 0, fr.y) * k * 0.4, 9.0)
			if dist < 9.0:
				var dano := _dano() * (2.2 - dist / 9.0)
				m.ferir_heroina(dano, global_position, nivel)
		else:
			var ok: bool = dist < cfg.alcance + 0.4 and fr.dot((ppj - p).normalized()) > 0.4
			if ok: m.ferir_heroina(_dano(), global_position, nivel)
	if _t >= tt.z:
		_recarga = rng.randf_range(2.0, 3.2) if tipo != "golem" else rng.randf_range(1.0, 1.8)
		_mudar("cacar")

func _dano() -> float:
	return rng.randf_range(cfg.dano.x + cfg.dano_nv * nivel, cfg.dano.y + cfg.dano_nv * nivel)

func heroina_atacou(_pos: Vector3, _frente: Vector3) -> void:
	pass

func golpe_da_heroina(pos: Vector3, frente: Vector3, mult: float) -> bool:
	if estado == "morto": return false
	var d := Vector3(global_position.x - pos.x, 0, global_position.z - pos.z)
	var alcance := 2.5 + (3.2 if tipo == "golem" else 0.0)
	if d.length() > alcance or frente.dot(d.normalized()) < 0.3: return false
	var r: Array = m.rolar_dano(mult)
	vida -= r[0]; _flash = 1.0
	m.hud.numero(global_position + Vector3(0, k * 0.8, 0), str(int(r[0])) + ("!" if r[1] else ""),
		Color(1.0, 0.85, 0.2) if r[1] else Color(1, 1, 1), 76 if r[1] else 54)
	grupo.alerta = true
	if vida <= 0.0:
		_mudar("morto"); remove_from_group("lobos"); _prox_grito = 0.0; _gritar(false)
		for c in get_children(): if c is CollisionShape3D: c.disabled = true
		m.monstro_morreu(self)
	elif tipo == "lodoso_j" and estado != "atacar" and rng.randf() < 0.35:
		_mudar("ferido")
		if rng.randf() < 0.5: _gritar(false)
	elif estado != "atacar": _mudar("cacar")
	return true

# ---------- animação nos ossos (espaço do esqueleto: frente = +X; giro +Z leva o membro para a frente) ----------
func _q(e: Vector3, a: float) -> Quaternion: return Quaternion(e, a)
func _zx(z: float, x: float) -> Quaternion: return _q(Vector3(0, 0, 1), z) * _q(Vector3(1, 0, 0), x)
static func _r(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0); return t * t * (3.0 - 2.0 * t)

func _vel_teste() -> float:
	var pa := anim_fixa.split(":")
	if pa[0] == "andar": return cfg.andar
	if pa[0] == "correr": return cfg.correr
	if pa[0] == "morto":
		estado = "morto"; _t = float(pa[1]) * 1.4 if pa.size() > 1 else fmod(_t, 2.0); return 0.0
	estado = "atacar"; _golpe = pa[0]
	var tt := _tempos()
	_t = float(pa[1]) * tt.z if pa.size() > 1 else fmod(_t, tt.z + 0.5)
	return 0.0

func _animar(delta: float, spd: float) -> void:
	var a := clampf(spd / cfg.andar, 0.0, 1.0)
	var corre := clampf((spd - cfg.andar * 1.3) / (cfg.correr - cfg.andar * 1.3), 0.0, 1.0)
	_anda = lerpf(_anda, a, 1.0 - exp(-8.0 * delta))
	var pesado := 0.75 if tipo == "golem" else 1.0
	_fase += delta * TAU * (0.9 + spd * 0.32) * pesado
	var s := sin(_fase); var c := cos(_fase)
	var alvo := {}; var hip := 0.0
	var gingado := 0.18 if tipo != "golem" else 0.06            # Lodoso anda gingando (de lado a lado)
	# parado: corcunda, braços soltos (golem: braços pendurados à frente)
	var br := 0.3 if tipo == "golem" else 0.38
	alvo["L_Upperarm"] = _zx(0.15, -br); alvo["R_Upperarm"] = _zx(0.15, br)
	alvo["L_Forearm"] = _q(Vector3(0, 0, 1), 0.25); alvo["R_Forearm"] = _q(Vector3(0, 0, 1), 0.25)
	if cfg.lanca: alvo["R_Upperarm"] = _zx(0.55, 0.45); alvo["R_Forearm"] = _q(Vector3(0, 0, 1), 1.0)   # lança à frente
	alvo["Spine01"] = _q(Vector3(0, 0, 1), -0.12 + sin(_t * 1.6) * 0.03)
	alvo["Head"] = _q(Vector3(0, 1, 0), sin(_t * 0.5) * 0.25)
	if _anda > 0.02:
		var pe := 0.45 + 0.3 * corre
		alvo["L_Thigh"] = _q(Vector3(0, 0, 1), pe * s * _anda); alvo["R_Thigh"] = _q(Vector3(0, 0, 1), -pe * s * _anda)
		alvo["L_Calf"] = _q(Vector3(0, 0, 1), -(0.6 + 0.6 * corre) * maxf(0.0, -c) * _anda)
		alvo["R_Calf"] = _q(Vector3(0, 0, 1), -(0.6 + 0.6 * corre) * maxf(0.0, c) * _anda)
		alvo["L_Upperarm"] = _zx(0.15 - 0.4 * s * _anda, -br - 0.1 * corre)
		if not cfg.lanca: alvo["R_Upperarm"] = _zx(0.15 + 0.4 * s * _anda, br + 0.1 * corre)
		alvo["Spine01"] = _q(Vector3(0, 0, 1), -0.12 - 0.25 * corre) * _q(Vector3(1, 0, 0), s * gingado * _anda)
		hip = absf(s) * (0.02 + 0.04 * corre) * _anda
	var incl := 0.15 + 0.05 * corre                    # em pé, um pouco para a frente
	match estado:
		"atacar":
			var tt := _tempos(); var t := _t
			incl = lerpf(lerpf(0.15, -0.25, _r(0.0, tt.x, t)), 1.5, _r(tt.x, tt.y, t)) * (1.0 - _r(tt.y + 0.1, tt.z, t)) + 0.15 * _r(tt.y + 0.1, tt.z, t)
			var prep := _r(0.0, tt.x, t); var bate := _r(tt.x, tt.y, t); var volta := _r(tt.y + 0.1, tt.z, t)
			match _golpe:
				"soco":           # puxa o braço direito para trás e solta um soco reto
					alvo["R_Upperarm"] = _zx(lerpf(lerpf(0.15, -0.6, prep), 1.5, bate) * (1.0 - volta) + 0.15 * volta, 0.25)
					alvo["R_Forearm"] = _q(Vector3(0, 0, 1), lerpf(lerpf(0.25, 1.6, prep), 0.1, bate))
					alvo["Spine01"] = _q(Vector3(0, 1, 0), lerpf(lerpf(0.0, 0.45, prep), -0.4, bate) * (1.0 - volta)) * _q(Vector3(0, 0, 1), -0.25 * bate * (1.0 - volta))
				"pancada":        # levanta os dois braços bem alto e bate com tudo no chão
					var cima := lerpf(0.15, 2.9, prep); var baixo := lerpf(cima, 0.9, bate)
					var braco := lerpf(baixo, 0.15, volta)
					alvo["L_Upperarm"] = _zx(braco, -0.2); alvo["R_Upperarm"] = _zx(braco, 0.2)
					alvo["L_Forearm"] = _q(Vector3(0, 0, 1), 0.6 * (1.0 - bate) + 0.2); alvo["R_Forearm"] = _q(Vector3(0, 0, 1), 0.6 * (1.0 - bate) + 0.2)
					alvo["Spine01"] = _q(Vector3(0, 0, 1), (0.25 * prep - 0.7 * bate) * (1.0 - volta))
					alvo["Head"] = _q(Vector3(0, 0, 1), 0.3 * prep - 0.2 * bate)
					hip = (-0.06 * bate + 0.03 * prep) * (1.0 - volta)
				_:                # estocada de lança: recolhe e espeta para a frente
					alvo["R_Upperarm"] = _zx(lerpf(lerpf(0.55, 0.2, prep), 1.35, bate) * (1.0 - volta) + 0.55 * volta, 0.45 - 0.3 * bate)
					alvo["R_Forearm"] = _q(Vector3(0, 0, 1), lerpf(lerpf(1.0, 1.9, prep), 0.15, bate) * (1.0 - volta) + 1.0 * volta)
					alvo["L_Upperarm"] = _zx(0.5 * bate * (1.0 - volta), -0.4)
					alvo["Spine01"] = _q(Vector3(0, 0, 1), (0.15 * prep - 0.35 * bate) * (1.0 - volta)) * _q(Vector3(0, 1, 0), 0.3 * prep - 0.3 * bate)
		"ferido":
			alvo["Spine01"] = _q(Vector3(0, 0, 1), 0.3); alvo["Head"] = _q(Vector3(0, 0, 1), 0.3)
		"morto":          # tomba para trás, braços abertos
			var e := _r(0.0, 0.7, _t)
			incl = 0.15 + 0.6 * e
			alvo["L_Upperarm"] = _zx(0.6 * e, -1.2 * e - 0.2); alvo["R_Upperarm"] = _zx(0.6 * e, 1.2 * e + 0.2)
			alvo["L_Thigh"] = _q(Vector3(0, 0, 1), 0.5 * e); alvo["R_Thigh"] = _q(Vector3(0, 0, 1), 0.3 * e)
			alvo["Head"] = _q(Vector3(0, 0, 1), 0.4 * e)
			visual.rotation.z = 0.0
			visual.rotation.x = 1.45 * _r(0.15, 0.9, _t)                  # cai de costas
			visual.position.y = 0.12 * k * _r(0.15, 0.9, _t) if _t < 7.0 else visual.position.y
	var f := 1.0 - exp(-12.0 * delta)
	for b in OSSOS:
		var q0: Quaternion = _pose.get(b, Quaternion()); var q1: Quaternion = alvo.get(b, Quaternion())
		_pose[b] = q0.slerp(q1, f)
	_hip_y = lerpf(_hip_y, hip, f)
	for b in OSSOS:
		if not _ids.has(b): continue
		var i: int = _ids[b]
		var pai := esq.get_bone_parent(i)
		var pg: Transform3D = esq.get_bone_global_pose(pai) if pai >= 0 else Transform3D.IDENTITY
		var pai_resto: Transform3D = esq.get_bone_global_rest(pai) if pai >= 0 else Transform3D.IDENTITY
		var g: Transform3D = pg * pai_resto.affine_inverse() * _resto[b]
		g.basis = Basis(_pose[b]) * g.basis
		if b == "Hip": g.origin += Vector3(0, _hip_y / k, 0)
		var loc := pg.affine_inverse() * g
		esq.set_bone_pose_position(i, loc.origin); esq.set_bone_pose_rotation(i, loc.basis.get_rotation_quaternion())
	_incl = lerpf(_incl, incl, f); _pos_arma()

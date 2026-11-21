# Lobo: primeiro inimigo. Modelos do Tripo sem esqueleto — as pernas, a cabeça e a cauda são marcadas nas cores
# dos vértices (uma vez por tipo) e dobradas no shader lobo.gdshader. O corpo inteiro (pulo, agachar, rolar)
# mexe no nó "visual". Animações: andar/correr (trote e galope), atacar (agacha, salta e morde) e esquivar
# (pulo para o lado). Vivem em matilhas de 4 a 6: o líder é o preto (maior); branco só nas montanhas, marrom
# só nas florestas. Na caça cercam a Rachel em roda, com espaço entre eles, e só um ataca de cada vez.
extends CharacterBody3D
class_name Lobo

const ARQ := {"branco": "res://assets/modelos/lobo_branco.glb", "preto": "res://assets/modelos/lobo_preto.glb", "marrom": "res://assets/modelos/lobo_marrom.glb"}
const VEL_ANDAR := 1.7
const VEL_CORRER := 6.6
var tipo := "marrom"
var lider := false
var m                              # o mundo
var grupo: Dictionary              # compartilhado pela matilha: casa, membros, alerta, atacante
var vaga := 0.0                    # ângulo do lugar dele na roda em volta da Rachel
var vida := 3.0
var estado := "vagar"              # vagar, parado, cacar, atacar, esquivar, ferido, morto
var visual: Node3D
var mod: Node3D
var sm: ShaderMaterial
var k := 1.0                       # escala do modelo
var _comp := 1.9                   # comprimento real (m)
var _espera := 4.0
var rng := RandomNumberGenerator.new()
var _t := 0.0                      # tempo no estado
var _alvo := Vector2.ZERO
var _fase := 0.0
var _recarga := 0.0
var _dir_salto := Vector2.ZERO
var _dist_salto := 0.0
var _lado := 1.0
var _mordeu := false
var furioso := false               # em fúria: não volta para a roda, fica atacando a Rachel
var _flash := 0.0
var anim_fixa := ""               # teste: prende uma animação (correr, atacar, esquivar) para print
var u_fixo := -1.0
# pose atual (suavizada) e alvo
var _q := Vector4.ZERO; var _j := Vector4.ZERO; var _cab := Vector2.ZERO; var _cau := Vector2.ZERO
var _vy := 0.0; var _pitch := 0.0; var _roll := 0.0

static var _malhas := {}           # tipo → [ArrayMesh, pivôs]

func montar(mundo, t: String, e_lider: bool, semente: int) -> void:
	m = mundo; tipo = t; lider = e_lider; rng.seed = semente
	add_to_group("lobos")
	var comp := rng.randf_range(1.75, 1.95) if not lider else 2.45      # do focinho à ponta da cauda (m)
	_comp = comp
	vida = 3.0 if not lider else 6.0
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	visual = Node3D.new(); add_child(visual)
	mod = load(ARQ[tipo]).instantiate(); visual.add_child(mod)
	var mi: MeshInstance3D = mod.find_children("*", "MeshInstance3D", true, false)[0]
	var prep: Array = _preparar(mi, tipo)
	mi.mesh = prep[0]
	var pv: Dictionary = prep[1]
	k = comp / pv.L
	mod.scale = Vector3(k, k, k); mod.rotation.y = PI / 2.0           # frente do modelo (+X) → -Z
	mod.position.y = -pv.ymin * k
	sm = ShaderMaterial.new(); sm.shader = load("res://shaders/lobo.gdshader")
	var orig: BaseMaterial3D = mi.mesh.surface_get_material(0)
	if orig: sm.set_shader_parameter("tex", orig.albedo_texture)
	sm.set_shader_parameter("neblina", m.NEBLINA)
	for nome in ["pivo_x", "pivo_z", "y_quadril", "y_joelho", "pivo_cab", "pivo_cauda"]: sm.set_shader_parameter(nome, pv[nome])
	mi.material_override = sm
	mi.visibility_range_end = 170.0
	# corpo: cápsula deitada ao longo do lobo
	var cs := CollisionShape3D.new(); var cap := CapsuleShape3D.new()
	cap.radius = comp * 0.15; cap.height = comp * 0.62
	cs.shape = cap; cs.rotation.x = PI / 2.0; cs.position = Vector3(0, pv.H * k * 0.55, -comp * 0.08); add_child(cs)
	_fase = rng.randf() * TAU
	_novo_passeio()

static func _rampa(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

# marca as partes nas cores dos vértices e acha os pivôs (pés, ombros, cabeça, cauda) pela forma do modelo
static func _preparar(mi: MeshInstance3D, t: String) -> Array:
	if _malhas.has(t): return _malhas[t]
	var arr := mi.mesh.surface_get_arrays(0)
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var mn := Vector3(9, 9, 9); var mx := Vector3(-9, -9, -9)
	for v in vs: mn = mn.min(v); mx = mx.max(v)
	var L := mx.x - mn.x; var H := mx.y - mn.y
	var xm := 0.0; var cnt := 0
	for v in vs:
		if v.y < mn.y + 0.12 * H: xm += v.x; cnt += 1
	xm /= maxf(cnt, 1)
	var soma := [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]; var n := [0, 0, 0, 0]
	for v in vs:
		if v.y < mn.y + 0.12 * H:
			var i := (0 if v.x > xm else 2) + (0 if v.z > 0.0 else 1)
			soma[i] += v; n[i] += 1
	var pes := []
	for i in 4: pes.append(soma[i] / maxf(n[i], 1))
	var cores := PackedColorArray(); cores.resize(vs.size())
	for idx in vs.size():
		var v := vs[idx]
		var r := 0.0; var g := 0.0; var b := 0.0
		var i := (0 if v.x > xm else 2) + (0 if v.z > 0.0 else 1)
		var f: Vector3 = pes[i]
		if absf(v.x - f.x) < 0.11 * L and v.y < mn.y + 0.52 * H:
			r = (i + 1) / 4.0
			g = _rampa(mn.y + 0.52 * H, mn.y + 0.40 * H, v.y)
			b = _rampa(mn.y + 0.30 * H, mn.y + 0.22 * H, v.y)
		var a := 0.5 + 0.5 * _rampa(mn.x + 0.76 * L, mn.x + 0.84 * L, v.x) - 0.5 * _rampa(mn.x + 0.235 * L, mn.x + 0.16 * L, v.x)
		cores[idx] = Color(r, g, b, a)
	arr[Mesh.ARRAY_COLOR] = cores
	var nova := ArrayMesh.new()
	nova.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	nova.surface_set_material(0, mi.mesh.surface_get_material(0))
	var pv := {
		"L": L, "H": H, "ymin": mn.y,
		"pivo_x": Vector4(pes[0].x, pes[1].x, pes[2].x, pes[3].x), "pivo_z": Vector4(pes[0].z, pes[1].z, pes[2].z, pes[3].z),
		"y_quadril": mn.y + 0.55 * H, "y_joelho": mn.y + 0.27 * H,
		"pivo_cab": Vector3(mn.x + 0.78 * L, mn.y + 0.68 * H, 0.0), "pivo_cauda": Vector3(mn.x + 0.235 * L, mn.y + 0.72 * H, 0.0),
	}
	_malhas[t] = [nova, pv]
	return _malhas[t]

# ---------- comportamento ----------
func _novo_passeio() -> void:
	var casa: Vector2 = grupo.get("casa", Vector2(global_position.x, global_position.z)) if grupo else Vector2(global_position.x, global_position.z)
	var a := rng.randf() * TAU
	_alvo = casa + Vector2(cos(a), sin(a)) * rng.randf_range(2.0, 12.0)
	if lider: _alvo = casa + Vector2(cos(a), sin(a)) * rng.randf_range(0.0, 5.0)
	estado = "vagar"; _t = 0.0

func _mudar(e: String) -> void:
	estado = e; _t = 0.0

func _physics_process(delta: float) -> void:
	if m == null or m.jogador == null: return
	_t += delta; _recarga -= delta; _flash = maxf(0.0, _flash - delta * 4.0)
	if anim_fixa != "": _animar(delta, _vel_teste()); return
	var pj: Vector3 = m.jogador.global_position
	var p := Vector2(global_position.x, global_position.z)
	var ppj := Vector2(pj.x, pj.z)
	var dist := p.distance_to(ppj)
	var casa: Vector2 = grupo.casa
	if dist > 110.0 and not grupo.alerta:
		return                                        # longe: nem pensa (economia no celular)
	var dir := Vector2.ZERO; var vel := 0.0; var olhar := Vector2.ZERO
	match estado:
		"vagar":
			var d := _alvo - p
			if d.length() < 0.6: _mudar("parado"); _alvo = p; _espera = rng.randf_range(3.0, 7.0)
			else: dir = d.normalized(); vel = VEL_ANDAR
			if _t > 12.0: _mudar("parado"); _espera = 3.0
		"parado":
			if _t > _espera: _novo_passeio()
		"cacar":
			if dist > 48.0 or p.distance_to(casa) > 75.0 or m.heroina_desmaiada:
				grupo.alerta = false; grupo.atacante = null
				for o in grupo.membros: if is_instance_valid(o): o.furioso = false
			elif furioso:
				# enfurecido (apanhou ou já mordeu): fica colado na Rachel e ataca de novo assim que puder
				var dd := (ppj - p)
				olhar = ppj
				if dist > 2.6: dir = dd.normalized(); vel = VEL_CORRER * (0.7 if dist < 5.0 else 1.0)
				if dist < 3.3 and _recarga <= 0.0 and _atacando_agora() < 2: _iniciar_ataque(ppj)
			elif grupo.atacante == self:
				dir = (ppj - p).normalized(); vel = VEL_CORRER * (0.75 if dist < 6.0 else 1.0)
				if dist < 3.3: _iniciar_ataque(ppj)
				elif _t > 6.0: grupo.atacante = null
			else:
				if grupo.atacante == null and _recarga <= 0.0 and _relogio() > grupo.get("pausa", 0.0) and dist < 10.0 and rng.randf() < delta * 0.8:
					grupo.atacante = self; _t = 0.0
				# lugar na roda em volta da Rachel (cada um no seu ângulo, girando devagar)
				var raio := 5.5 if not lider else 6.5
				var a: float = vaga + _relogio() * 0.18
				var slot := ppj + Vector2(cos(a), sin(a)) * raio
				var ds := slot - p
				if dist < raio - 0.8:                 # a Rachel chegou perto: não recua, encara e ataca
					ds = Vector2.ZERO
					if dist < 3.3 and _recarga <= 0.0 and _atacando_agora() < 2: furioso = true; _iniciar_ataque(ppj)
				if ds.length() > 0.5:
					dir = ds.normalized(); vel = clampf(ds.length() * 1.6, 1.2, VEL_CORRER)
				olhar = ppj
		"atacar":
			_tocar_ataque(delta, ppj)
			if _t >= 0.3 and _t < 0.6: dir = _dir_salto; vel = _dist_salto / 0.3
		"esquivar":
			var u := _t / 0.5
			if u < 0.85: dir = _dir_salto; vel = _dist_salto / 0.42
			olhar = ppj
			if _t >= 0.5: _mudar("cacar" if grupo.alerta else "parado")
		"ferido":
			if _t < 0.15: dir = _dir_salto; vel = 3.0
			olhar = ppj
			if _t >= 0.35: _mudar("cacar")
		"morto":
			velocity = Vector3.ZERO
			if _t > 6.0: visual.position.y -= delta * 0.25
			if _t > 9.0: queue_free()
			_animar(delta, 0.0); return
	# viu a Rachel: a matilha toda entra na caça
	if not grupo.alerta and (estado == "vagar" or estado == "parado") and dist < 20.0 and not m.heroina_desmaiada:
		grupo.alerta = true
		_rosnar(true)                                     # quem viu primeiro solta o rosnado longo
	if grupo.alerta and (estado == "vagar" or estado == "parado"): _mudar("cacar")
	if not grupo.alerta and estado == "cacar": _novo_passeio()
	# espaço entre os lobos (a luta fica legível)
	var sep := Vector2.ZERO
	for o in grupo.membros:
		if o != self and is_instance_valid(o) and o.estado != "morto":
			var dd := p - Vector2(o.global_position.x, o.global_position.z)
			if dd.length() < 2.6 and dd.length() > 0.01: sep += dd.normalized() * (2.6 - dd.length())
	var v2 := dir * vel
	if estado != "atacar" and estado != "esquivar": v2 += sep * 2.0
	velocity = Vector3(v2.x, 0, v2.y)
	move_and_slide()
	global_position.y = m.altura_malha(global_position.x, global_position.z)
	# para onde olha: para onde anda (ou para a Rachel, cercando)
	var foco := olhar if olhar != Vector2.ZERO and v2.length() < 3.0 else p + v2
	if estado == "atacar": foco = p + _dir_salto
	if (foco - p).length() > 0.05:
		var dl := foco - p
		rotation.y = lerp_angle(rotation.y, atan2(-dl.x, -dl.y), 1.0 - exp(-8.0 * delta))
	_animar(delta, Vector2(get_real_velocity().x, get_real_velocity().z).length())

func _iniciar_ataque(alvo: Vector2) -> void:
	var p := Vector2(global_position.x, global_position.z)
	_dir_salto = (alvo - p).normalized(); _dist_salto = clampf(p.distance_to(alvo) - 0.6, 1.2, 3.0)
	_mordeu = false; _mudar("atacar")
	if rng.randf() < 0.6: _rosnar(false)

# ataque: agacha (0–0,3 s), salta mordendo (0,3–0,6 s), cai e se recompõe (0,6–0,9 s)
func _tocar_ataque(_delta: float, ppj: Vector2) -> void:
	var p := Vector2(global_position.x, global_position.z)
	if _t < 0.3: _dir_salto = _dir_salto.slerp((ppj - p).normalized(), 0.2)
	if _t >= 0.48 and not _mordeu:
		_mordeu = true
		var boca := p + _dir_salto * _comp * 0.4
		if boca.distance_to(ppj) < 1.5:
			var bloqueou: bool = m.ferir_heroina(7.0 if not lider else 12.0, global_position)
			if bloqueou: _ser_empurrado(ppj, 1.0)
	if _t >= 0.9:
		if grupo.atacante == self: grupo.atacante = null
		_recarga = rng.randf_range(1.6, 2.6); furioso = true          # mordeu: fica no ataque (não foge)
		grupo.pausa = _relogio() + rng.randf_range(1.2, 2.2)
		_mudar("cacar")

# rosnado em 3D (o líder mais grave); cada lobo espera um pouco entre um rosnado e outro
static var _sons := []
var _voz: AudioStreamPlayer3D
var _prox_rosnado := 0.0
func _rosnar(longo: bool) -> void:
	if _relogio() < _prox_rosnado or estado == "morto": return
	if _sons.is_empty(): _sons = [load("res://assets/som/rosnado_longo.ogg"), load("res://assets/som/rosnado_1.ogg"), load("res://assets/som/rosnado_2.ogg")]
	if _voz == null:
		_voz = AudioStreamPlayer3D.new(); _voz.bus = "Efeitos"; _voz.position = Vector3(0, 0.6, -_comp * 0.35)
		_voz.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE; _voz.unit_size = 5.0; _voz.max_distance = 45.0
		_voz.volume_db = -3.0; add_child(_voz)
	_voz.stream = _sons[0] if longo else _sons[1 + rng.randi() % 2]
	_voz.pitch_scale = rng.randf_range(0.78, 0.86) if lider else rng.randf_range(0.95, 1.12)
	_voz.play()
	_prox_rosnado = _relogio() + (5.0 if longo else rng.randf_range(2.5, 4.0))

func _atacando_agora() -> int:
	var n := 0
	for o in grupo.membros: if is_instance_valid(o) and o.estado == "atacar": n += 1
	return n

func _esquivar(de: Vector2) -> void:
	var p := Vector2(global_position.x, global_position.z)
	var fora := (p - de).normalized()
	_lado = 1.0 if rng.randf() < 0.5 else -1.0
	_dir_salto = (Vector2(-fora.y, fora.x) * _lado - fora * 0.15).normalized(); _dist_salto = 2.0   # de lado, sem se afastar
	_recarga = 0.0; furioso = true                                  # e volta atacando
	_mudar("esquivar")

func _ser_empurrado(de: Vector2, forca: float) -> void:
	var p := Vector2(global_position.x, global_position.z)
	_dir_salto = (p - de).normalized() * forca
	if grupo.atacante == self: grupo.atacante = null
	_recarga = 0.7; furioso = true; _mudar("ferido")

# chamado pela Rachel ao começar um golpe: alguns lobos na frente dela pulam para o lado
func heroina_atacou(pos: Vector3, frente: Vector3) -> void:
	if estado == "morto" or estado == "atacar" or estado == "esquivar" or estado == "ferido": return
	var d := Vector3(global_position.x - pos.x, 0, global_position.z - pos.z)
	if d.length() < 3.6 and frente.dot(d.normalized()) > 0.4 and rng.randf() < (0.35 if lider else 0.25):
		_esquivar(Vector2(pos.x, pos.z))

# chamado no instante do corte da espada
func golpe_da_heroina(pos: Vector3, frente: Vector3, dano: float) -> bool:
	if estado == "morto" or estado == "esquivar": return false
	var d := Vector3(global_position.x - pos.x, 0, global_position.z - pos.z)
	if d.length() > 2.5 + (0.4 if lider else 0.0) or frente.dot(d.normalized()) < 0.3: return false
	vida -= dano; _flash = 1.0
	grupo.alerta = true
	if vida <= 0.0:
		_mudar("morto"); remove_from_group("lobos")
		if grupo.atacante == self: grupo.atacante = null
		for c in get_children(): if c is CollisionShape3D: c.disabled = true
		m.lobo_morreu(self)
	else:
		_ser_empurrado(Vector2(pos.x, pos.z), 1.0)
	return true

# ---------- animação ----------
func _vel_teste() -> float:
	if anim_fixa == "correr": return VEL_CORRER
	if anim_fixa == "andar": return VEL_ANDAR
	if anim_fixa == "atacar" or anim_fixa == "esquivar":
		estado = anim_fixa
		var dur := 0.9 if anim_fixa == "atacar" else 0.5
		_t = u_fixo * dur if u_fixo >= 0.0 else fmod(_t, dur + 0.6)
	return 0.0

func _animar(delta: float, spd: float) -> void:
	var anda := clampf(spd / 2.0, 0.0, 1.0)
	var corre := clampf((spd - 2.5) / 3.0, 0.0, 1.0)
	_fase += delta * TAU * (0.8 + spd * 0.27)
	var f := _fase
	# trote (pares em diagonal) e galope (dianteiras juntas, traseiras juntas, defasadas)
	var s := sin(f); var c := cos(f)
	var tq := Vector4(s, -s, -s, s) * 0.38
	var tj := Vector4(-maxf(0.0, c), -maxf(0.0, -c), maxf(0.0, -c), maxf(0.0, c)) * 0.55
	var gq := Vector4(sin(f), sin(f + 0.45), sin(f + PI), sin(f + PI + 0.45)) * Vector4(0.75, 0.75, 0.7, 0.7)
	var gj := Vector4(-maxf(0.0, cos(f)), -maxf(0.0, cos(f + 0.45)), maxf(0.0, cos(f + PI)), maxf(0.0, cos(f + PI + 0.45))) * 1.0
	var q := tq.lerp(gq, corre) * anda
	var j := tj.lerp(gj, corre) * anda
	var resp := sin(_t * 2.2 + _fase * 0.0)
	var cab := Vector2(-sin(f) * 0.12 * corre + resp * 0.02, 0.0)
	var cau := Vector2(-0.25 * corre - 0.1 * anda, sin(f * 0.5) * 0.25 * (1.0 - corre) + sin(_t * 1.3) * 0.15 * (1.0 - anda))
	var vy := absf(sin(f)) * 0.07 * corre + absf(s) * 0.015 * anda * (1.0 - corre)
	var pitch := sin(f + PI * 0.5) * 0.1 * corre
	var roll := 0.0
	match estado:
		"parado":                    # fareja o chão
			cab = Vector2(-0.45 + sin(_t * 4.0) * 0.06 * float(int(_t) % 3 == 0), sin(_t * 0.7) * 0.3)
		"cacar":
			if spd < 1.0:              # rosnando, agachado na frente da Rachel
				cab = Vector2(-0.18 + sin(_t * 18.0) * 0.015, 0.0)
				q = Vector4(0.12, 0.12, -0.15, -0.15); j = Vector4(-0.35, -0.35, 0.4, 0.4); vy = -0.05
				cau = Vector2(0.25, sin(_t * 2.0) * 0.08)
		"atacar":
			var t := _t
			if t < 0.3:                # agacha e prepara
				var e := _rampa(0.0, 0.3, t)
				q = Vector4(0.2, 0.2, -0.35, -0.35) * e; j = Vector4(-0.6, -0.6, 0.8, 0.8) * e
				vy = -0.12 * e; pitch = -0.08 * e; cab = Vector2(-0.15 * e, 0.0); cau = Vector2(0.3 * e, 0.0)
			elif t < 0.6:              # salto: patas da frente esticadas, de trás para trás, morde no meio
				var u := (t - 0.3) / 0.3
				q = Vector4(1.0, 1.0, -1.0, -1.0); j = Vector4(-0.25, -0.25, 0.2, 0.2)
				vy = sin(u * PI) * 0.45; pitch = 0.25 * (1.0 - u) - 0.15 * u
				cab = Vector2(0.4 - 0.75 * _rampa(0.45, 0.65, u), 0.0); cau = Vector2(-0.4, 0.0)
			else:                      # cai e se recompõe
				var u := (t - 0.6) / 0.3
				q = Vector4(0.3, 0.3, -0.2, -0.2) * (1.0 - u); j = Vector4(-0.5, -0.5, 0.6, 0.6) * (1.0 - u)
				vy = -0.08 * (1.0 - u); pitch = -0.1 * (1.0 - u); cab = Vector2(-0.2 * (1.0 - u), 0.0)
		"esquivar":                  # pulo para o lado: patas encolhidas, corpo inclinado para o lado
			var u := clampf(_t / 0.45, 0.0, 1.0)
			var e := sin(u * PI)
			q = Vector4(0.45, 0.45, -0.45, -0.45) * e; j = Vector4(-1.0, -1.0, 1.0, 1.0) * e
			vy = e * 0.4 - (0.06 if u < 0.15 else 0.0); roll = -_lado * 0.35 * e
			cab = Vector2(0.1 * e, _lado * 0.3 * e); cau = Vector2(-0.2, -_lado * 0.5 * e)
		"ferido":
			cab = Vector2(0.3, 0.2); pitch = 0.12; q = Vector4(0.3, 0.3, 0.0, 0.0)
		"morto":                     # cai de lado com as patas duras
			var e := _rampa(0.0, 0.45, _t)
			roll = 1.45 * e; q = Vector4(0.35, 0.25, -0.3, -0.2) * e; j = Vector4(-0.2, -0.1, 0.2, 0.1) * e
			cab = Vector2(-0.1 * e, 0.0); cau = Vector2(0.4 * e, 0.0); vy = -0.12 * e
	var fq := 1.0 - exp(-26.0 * delta)
	_q = _q.lerp(q, fq); _j = _j.lerp(j, fq); _cab = _cab.lerp(cab, fq); _cau = _cau.lerp(cau, fq)
	_vy = lerpf(_vy, vy, fq); _pitch = lerpf(_pitch, pitch, fq); _roll = lerpf(_roll, roll, 1.0 - exp(-12.0 * delta))
	sm.set_shader_parameter("quadril", _q); sm.set_shader_parameter("joelho", _j)
	sm.set_shader_parameter("cabeca", _cab); sm.set_shader_parameter("cauda", _cau)
	sm.set_shader_parameter("flash", _flash * 0.6)
	if estado != "morto" or _t < 6.0: visual.position.y = _vy * _comp / 1.9
	visual.rotation = Vector3(_pitch, 0.0, _roll)

# relógio da física (não do sistema): com o jogo lento, as pausas da matilha continuam do mesmo tamanho
static func _relogio() -> float: return Engine.get_physics_frames() / float(Engine.physics_ticks_per_second)

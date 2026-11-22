# Aranha-musgo: inimiga da floresta, sozinha e longe das outras (um pouco forte). Modelo do Tripo sem esqueleto:
# as patas são marcadas nas cores dos vértices e animadas no shader aranha.gdshader. Anda, corre rasteira,
# pica (às vezes envenena), dá um bote de longe e morre virando de barriga para cima com as patas encolhidas.
extends CharacterBody3D
class_name Aranha

const VEL_ANDAR := 1.2
const VEL_CORRER := 4.8
var m
var grupo: Dictionary
var nivel := 4
var vida := 80.0
var vida_max := 80.0
var estado := "vagar"
var rng := RandomNumberGenerator.new()
var visual: Node3D
var sm: ShaderMaterial
var k := 1.0
var _t := 0.0
var _fase := 0.0
var _alvo := Vector2.ZERO
var _espera := 3.0
var _recarga := 0.0
var _golpe := ""                   # picada, bote
var _acertou := false
var _dir_bote := Vector2.ZERO
var _flash := 0.0
var _anda := 0.0
var _atq := 0.0
var _pitch := 0.0
var _vy := 0.0
var anim_fixa := ""
static var _malha: ArrayMesh

func montar(mundo, nv: int, semente: int) -> void:
	m = mundo; nivel = nv; rng.seed = semente
	add_to_group("lobos")
	vida_max = 50.0 + 16.0 * nivel; vida = vida_max
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	visual = Node3D.new(); add_child(visual)
	var mod: Node3D = load("res://assets/modelos/aranha.glb").instantiate(); visual.add_child(mod)
	var mi: MeshInstance3D = mod.find_children("*", "MeshInstance3D", true, false)[0]
	var orig: BaseMaterial3D = mi.mesh.surface_get_material(0)
	mi.mesh = _preparar(mi)
	k = 1.8 / 0.97
	mod.scale = Vector3(k, k, k); mod.rotation.y = PI / 2.0; mod.position.y = 0.337 * k - 0.04
	sm = ShaderMaterial.new(); sm.shader = load("res://shaders/aranha.gdshader")
	if orig: sm.set_shader_parameter("tex", orig.albedo_texture)
	sm.set_shader_parameter("neblina", m.NEBLINA); sm.set_shader_parameter("pivo_e", Vector3(0.1, 0.05, 0.1))
	mi.material_override = sm; mi.visibility_range_end = 100.0
	var cs := CollisionShape3D.new(); var sh := SphereShape3D.new(); sh.radius = 0.55
	cs.shape = sh; cs.position = Vector3(0, 0.55, 0); add_child(cs)
	_fase = rng.randf() * TAU
	_alvo = Vector2(global_position.x, global_position.z)

# patas: tudo que fica fora do corpo (abdômen atrás e cefalotórax na frente); qual pata = pela direção a partir
# da raiz, comparada com as pontas medidas (de trás para a frente: -1,24 / -0,5 / 0,29 / 1,17 rad)
static func _preparar(mi: MeshInstance3D) -> ArrayMesh:
	if _malha: return _malha
	var arr := mi.mesh.surface_get_arrays(0)
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var cores := PackedColorArray(); cores.resize(vs.size())
	for idx in vs.size():
		var v := vs[idx]
		var abd := pow((v.x + 0.27) / 0.25, 2.0) + pow(v.z / 0.22, 2.0) + pow((v.y - 0.06) / 0.3, 2.0)
		var cab := pow((v.x - 0.2) / 0.24, 2.0) + pow(v.z / 0.15, 2.0) + pow((v.y - 0.0) / 0.25, 2.0)
		var r := 0.0; var g := 0.0
		if abd > 1.0 and cab > 1.0:
			var lado := 1.0 if v.z >= 0.0 else -1.0
			var dx := v.x - 0.1; var dz := absf(v.z) - 0.1
			var a := atan2(dx, maxf(dz, 0.02))
			var n := 0 if a < -0.87 else (1 if a < -0.1 else (2 if a < 0.73 else 3))
			r = float(n + 1 + (0 if lado > 0.0 else 4)) / 8.0
			g = clampf((Vector2(dx, dz).length() - 0.05) / 0.4, 0.0, 1.0)
		cores[idx] = Color(r, g, 0, 1)
	arr[Mesh.ARRAY_COLOR] = cores
	_malha = ArrayMesh.new(); _malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_malha.surface_set_material(0, mi.mesh.surface_get_material(0))
	return _malha

func _mudar(e: String) -> void:
	estado = e; _t = 0.0

func _physics_process(delta: float) -> void:
	if m == null or m.jogador == null: return
	_t += delta; _recarga -= delta; _flash = maxf(0.0, _flash - delta * 4.0)
	if anim_fixa != "": _animar(delta, _vel_teste()); return
	var pj: Vector3 = m.jogador.global_position
	var p := Vector2(global_position.x, global_position.z); var ppj := Vector2(pj.x, pj.z)
	var dist := p.distance_to(ppj)
	if dist > 110.0 and not grupo.alerta: return
	var dir := Vector2.ZERO; var vel := 0.0; var olhar := Vector2.ZERO
	match estado:
		"vagar":
			var d := _alvo - p
			if d.length() < 0.5: _mudar("parado"); _espera = rng.randf_range(3.0, 8.0)
			else: dir = d.normalized(); vel = VEL_ANDAR
			if _t > 10.0: _mudar("parado"); _espera = 3.0
		"parado":
			if _t > _espera:
				var a := rng.randf() * TAU
				_alvo = grupo.casa + Vector2(cos(a), sin(a)) * rng.randf_range(2.0, 9.0); _mudar("vagar")
		"cacar":
			if dist > 38.0 or p.distance_to(grupo.casa) > 55.0 or m.heroina_desmaiada:
				grupo.alerta = false; _mudar("vagar")
			else:
				olhar = ppj
				if dist > 1.9: dir = (ppj - p).normalized(); vel = VEL_CORRER * (0.6 if dist < 4.0 else 1.0)
				if _recarga <= 0.0:
					if dist < 2.4: _atacar("picada", ppj)
					elif dist > 4.5 and dist < 7.0 and rng.randf() < delta * 1.2: _atacar("bote", ppj)
		"atacar":
			olhar = ppj
			if _golpe == "bote" and _t > 0.35 and _t < 0.75: dir = _dir_bote; vel = 11.0
			_tocar(ppj, dist)
		"ferido":
			olhar = ppj
			if _t > 0.25: _mudar("cacar")
		"morto":
			velocity = Vector3.ZERO
			if _t > 7.0: visual.position.y -= delta * 0.2
			if _t > 10.0: queue_free()
			_animar(delta, 0.0); return
	if not grupo.alerta and (estado == "vagar" or estado == "parado") and dist < 15.0 and not m.heroina_desmaiada:
		grupo.alerta = true
	if grupo.alerta and (estado == "vagar" or estado == "parado"): _mudar("cacar")
	var v2 := dir * vel
	velocity = Vector3(v2.x, 0, v2.y)
	move_and_slide()
	if m.na_agua(global_position.x, global_position.z) and not m.na_agua(p.x, p.y):   # não entra na água
		global_position.x = p.x; global_position.z = p.y
	global_position.y = m.altura_malha(global_position.x, global_position.z)
	var foco := olhar if olhar != Vector2.ZERO else p + v2
	if estado == "atacar" and _golpe == "bote": foco = p + _dir_bote
	if (foco - p).length() > 0.05:
		var dl := foco - p
		rotation.y = lerp_angle(rotation.y, atan2(-dl.x, -dl.y), 1.0 - exp(-10.0 * delta))
	_animar(delta, Vector2(get_real_velocity().x, get_real_velocity().z).length())

func _atacar(g: String, ppj: Vector2) -> void:
	_golpe = g; _acertou = false
	_dir_bote = (ppj - Vector2(global_position.x, global_position.z)).normalized()
	_mudar("atacar")

func _tocar(ppj: Vector2, dist: float) -> void:
	var bate := 0.45 if _golpe == "picada" else 0.7
	var fim := 0.95 if _golpe == "picada" else 1.3
	if _t >= bate and not _acertou:
		_acertou = true
		if dist < (2.6 if _golpe == "picada" else 2.4):
			var dano := rng.randf_range(3.0 + 1.6 * nivel, 5.0 + 2.0 * nivel) * (1.25 if _golpe == "bote" else 1.0)
			var bloq: bool = m.ferir_heroina(dano, global_position, nivel)
			if not bloq and rng.randf() < 0.3: m.envenenar(2.0 + nivel * 0.5, 6.0)
	if _t >= fim:
		_recarga = rng.randf_range(1.3, 2.3); _mudar("cacar")

func heroina_atacou(_pos: Vector3, _frente: Vector3) -> void:
	pass

func golpe_da_heroina(pos: Vector3, frente: Vector3, mult: float) -> bool:
	if estado == "morto": return false
	var d := Vector3(global_position.x - pos.x, 0, global_position.z - pos.z)
	if d.length() > 2.7 or frente.dot(d.normalized()) < 0.3: return false
	var r: Array = m.rolar_dano(mult)
	vida -= r[0]; _flash = 1.0
	m.hud.numero(global_position + Vector3(0, 0.9, 0), str(int(r[0])) + ("!" if r[1] else ""),
		Color(1.0, 0.85, 0.2) if r[1] else Color(1, 1, 1), 76 if r[1] else 54)
	grupo.alerta = true
	if vida <= 0.0:
		_mudar("morto"); remove_from_group("lobos")
		for c in get_children(): if c is CollisionShape3D: c.disabled = true
		m.monstro_morreu(self)
	return true

static func _r(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0); return t * t * (3.0 - 2.0 * t)

func _vel_teste() -> float:
	var pa := anim_fixa.split(":")
	if pa[0] == "andar": return VEL_ANDAR
	if pa[0] == "correr": return VEL_CORRER
	if pa[0] == "morto": estado = "morto"; _t = float(pa[1]) * 1.2 if pa.size() > 1 else fmod(_t, 2.0); return 0.0
	estado = "atacar"; _golpe = pa[0]
	_t = float(pa[1]) * (0.95 if _golpe == "picada" else 1.3) if pa.size() > 1 else fmod(_t, 1.6)
	return 0.0

func _animar(delta: float, spd: float) -> void:
	var a := clampf(spd / VEL_ANDAR, 0.0, 1.0)
	_anda = lerpf(_anda, a, 1.0 - exp(-10.0 * delta))
	_fase += delta * TAU * (1.0 + spd * 0.55)
	var atq := 0.0; var pitch := 0.0; var vy := absf(sin(_fase)) * 0.02 * _anda; var roll := 0.0; var enc := 0.0
	match estado:
		"atacar":
			if _golpe == "picada":
				atq = _r(0.0, 0.3, _t) * (1.0 - _r(0.55, 0.9, _t)); pitch = 0.25 * atq - 0.35 * _r(0.35, 0.5, _t) * (1.0 - _r(0.6, 0.9, _t))
			else:
				atq = _r(0.0, 0.3, _t) * (1.0 - _r(0.7, 1.1, _t))
				vy = sin(clampf((_t - 0.35) / 0.4, 0.0, 1.0) * PI) * 0.5; pitch = 0.2 * atq
		"ferido": pitch = -0.15
		"morto":
			var e := _r(0.0, 0.6, _t); enc = _r(0.3, 1.0, _t)
			roll = PI * e; vy = 0.35 * sin(e * PI) + 0.6 * e
	_atq = lerpf(_atq, atq, 1.0 - exp(-16.0 * delta)); _pitch = lerpf(_pitch, pitch, 1.0 - exp(-14.0 * delta)); _vy = lerpf(_vy, vy, 1.0 - exp(-16.0 * delta))
	sm.set_shader_parameter("fase", _fase); sm.set_shader_parameter("anda", _anda)
	sm.set_shader_parameter("ataque", _atq); sm.set_shader_parameter("encolhe", enc)
	sm.set_shader_parameter("flash", _flash * 0.6)
	visual.position.y = _vy if estado != "morto" or _t < 7.0 else visual.position.y
	visual.rotation = Vector3(_pitch, 0.0, roll)

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
var _alvo := Vector2.ZERO
var _espera := 0.0
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

func montar(mundo, semente: int, centro: Vector2, raio: float) -> void:
	m = mundo; rng.seed = semente; area_centro = centro; area_raio = raio
	var sorteio := rng.randf()
	skin = 0 if sorteio < 0.4 else (1 if sorteio < 0.7 else 2)
	var cs := CollisionShape3D.new(); var cap := CapsuleShape3D.new(); cap.radius = 0.3; cap.height = 1.7
	cs.shape = cap; cs.position = Vector3(0, 0.85, 0); add_child(cs)
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING      # anda no plano; a altura vem do terreno
	# modelo: 0,98 m no arquivo, de frente para -X → girado para frente = -Z e escalado
	visual = Node3D.new(); add_child(visual)
	var mod: Node3D = load(SKINS[skin]).instantiate(); visual.add_child(mod)
	var alt := rng.randf_range(1.62, 1.86); var larg := rng.randf_range(0.92, 1.12)
	var k := alt / 0.981
	mod.scale = Vector3(k * larg, k, k * larg); mod.rotation_degrees.y = 90     # o modelo olha para +X
	esq = mod.find_children("*", "Skeleton3D", true, false)[0]
	var sm := ShaderMaterial.new(); sm.shader = load("res://shaders/npc.gdshader")
	for n in mod.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n
		var orig: BaseMaterial3D = mi.mesh.surface_get_material(0)
		if orig: sm.set_shader_parameter("tex", orig.albedo_texture)
		_regioes(mi)
		mi.material_override = sm
	sm.set_shader_parameter("neblina", m.NEBLINA)
	sm.set_shader_parameter("original", skin > 0)
	sm.set_shader_parameter("cor_pele", PELES[rng.randi() % PELES.size()])
	sm.set_shader_parameter("cor_couro", COUROS[rng.randi() % COUROS.size()])
	sm.set_shader_parameter("cor_cabelo", CABELOS[rng.randi() % CABELOS.size()])
	sm.set_shader_parameter("cor_tunica", TUNICAS[rng.randi() % TUNICAS.size()] * rng.randf_range(0.9, 1.1))
	sm.set_shader_parameter("cor_calca", CALCAS[rng.randi() % CALCAS.size()])
	for b in ["Hip", "Pelvis", "Waist", "Spine01", "Spine02", "L_Thigh", "R_Thigh", "L_Calf", "R_Calf", "L_Upperarm", "R_Upperarm", "L_Forearm", "R_Forearm", "NeckTwist01", "Head"]:
		var i := esq.find_bone(b)
		if i >= 0: _ids[b] = i; _resto[b] = esq.get_bone_global_rest(i)
	_fase = rng.randf() * TAU
	_novo_alvo()

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

func _novo_alvo() -> void:
	for t in 30:
		var a := rng.randf() * TAU; var d := sqrt(rng.randf()) * area_raio
		var p := area_centro + Vector2(cos(a), sin(a)) * d
		if not m.perto_de_casa(p.x, p.y, 1.2): _alvo = p; return
	_alvo = area_centro

func _physics_process(delta: float) -> void:
	if m == null: return
	_t += delta
	var p := Vector2(global_position.x, global_position.z)
	var anda := 0.0
	if _espera > 0.0:
		_espera -= delta
		velocity.x = 0; velocity.z = 0
	else:
		var d := _alvo - p
		if d.length() < 0.6:
			_espera = rng.randf_range(2.0, 7.0); _novo_alvo()
		else:
			var dir := d.normalized()
			velocity.x = dir.x * VEL; velocity.z = dir.y * VEL
			var alvo_ang := atan2(-dir.x, -dir.y)
			rotation.y = lerp_angle(rotation.y, alvo_ang, 1.0 - exp(-5.0 * delta))
			anda = 1.0
	velocity.y = 0.0
	move_and_slide()
	global_position.y = m.altura_malha(global_position.x, global_position.z)   # pés sempre no chão
	if anda > 0.0 and get_real_velocity().length() < 0.2 and _t > 1.0:
		_novo_alvo()                                   # travou em algo: escolhe outro lugar
	_animar(delta, anda)

# ---------- animação nos ossos ----------
# no espaço do esqueleto (antes do giro do modelo): frente = +X, cima = +Y; giro em Z positivo leva para a frente
var _anda_suave := 0.0
func _animar(delta: float, anda: float) -> void:
	_anda_suave = lerp(_anda_suave, anda, 1.0 - exp(-6.0 * delta))
	var a := _anda_suave
	_fase += delta * TAU * 0.95 * a
	var s := sin(_fase); var c := cos(_fase)
	var resp := sin(_t * 1.4 + _fase)
	var rots := {}
	rots["L_Thigh"] = Basis(Vector3(0, 0, 1), 0.42 * s * a)
	rots["R_Thigh"] = Basis(Vector3(0, 0, 1), -0.42 * s * a)
	rots["L_Calf"] = Basis(Vector3(0, 0, 1), -0.6 * max(0.0, -c) * a)      # joelho dobra para trás
	rots["R_Calf"] = Basis(Vector3(0, 0, 1), -0.6 * max(0.0, c) * a)
	# braços (já em pose A no modelo): descem um pouco mais, colados ao corpo, e balançam ao contrário das pernas
	rots["L_Upperarm"] = Basis(Vector3(0, 0, 1), -0.35 * s * a) * Basis(Vector3(1, 0, 0), -0.32 + resp * 0.015)
	rots["R_Upperarm"] = Basis(Vector3(0, 0, 1), 0.35 * s * a) * Basis(Vector3(1, 0, 0), 0.32 - resp * 0.015)
	rots["L_Forearm"] = Basis(Vector3(0, 0, 1), 0.15 + 0.2 * a)            # cotovelo dobra para a frente
	rots["R_Forearm"] = Basis(Vector3(0, 0, 1), 0.15 + 0.2 * a)
	rots["Spine01"] = Basis(Vector3(0, 1, 0), 0.08 * s * a) * Basis(Vector3(0, 0, 1), 0.02 * resp)
	rots["Head"] = Basis(Vector3(0, 1, 0), sin(_t * 0.3 + _fase) * 0.35 * (1.0 - a))   # olha em volta parado
	# aplica: pose global = rotação (no ponto do osso) * repouso; local = global do pai⁻¹ * global
	var glob := {}
	for b in ["Hip", "Pelvis", "Waist", "Spine01", "Spine02", "L_Thigh", "R_Thigh", "L_Calf", "R_Calf", "L_Upperarm", "R_Upperarm", "L_Forearm", "R_Forearm", "NeckTwist01", "Head"]:
		if not _ids.has(b): continue
		var i: int = _ids[b]
		var pai := esq.get_bone_parent(i)
		var pg: Transform3D = esq.get_bone_global_pose(pai) if pai >= 0 else Transform3D.IDENTITY
		var resto: Transform3D = _resto[b]
		var pai_resto: Transform3D = esq.get_bone_global_rest(pai) if pai >= 0 else Transform3D.IDENTITY
		# repouso levado pelo pai já animado
		var g: Transform3D = pg * pai_resto.affine_inverse() * resto
		if rots.has(b): g.basis = rots[b] * g.basis
		var loc := pg.affine_inverse() * g
		esq.set_bone_pose_position(i, loc.origin); esq.set_bone_pose_rotation(i, loc.basis.get_rotation_quaternion())
	# bob do quadril ao andar
	if _ids.has("Hip"):
		var i: int = _ids["Hip"]
		esq.set_bone_pose_position(i, esq.get_bone_rest(i).origin + Vector3(0, abs(s) * 0.012 * a - 0.006 * a, 0))

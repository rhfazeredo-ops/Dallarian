# Rig automático dos cavalos do Tripo (que vêm sem esqueleto): mede a malha, acha as 4 patas, o pescoço e o rabo
# e monta um Skeleton3D com 11 ossos (corpo, coxa e canela de cada pata, pescoço, rabo). Cada vértice recebe pesos
# de até 2 ossos com transição suave (pata→corpo perto da barriga, canela→coxa no joelho).
# No espaço do modelo: X = frente (cabeça em +X), Y = cima, Z = lado. A malha com pesos é guardada por arquivo
# (os cavalos da mesma cor dividem a malha e o Skin; cada um tem o próprio esqueleto).
class_name RigCavalo

const CORPO := 0
const COXA := [1, 2, 3, 4]        # frente-esquerda, frente-direita, trás-esquerda, trás-direita
const CANELA := [5, 6, 7, 8]
const PESCOCO := 9
const CAUDA := 10
static var _cache := {}           # caminho → [ArrayMesh, Skin, posições dos ossos, pais]

static func _ss(a: float, b: float, x: float) -> float:
	return smoothstep(a, b, x) if a < b else 1.0 - smoothstep(b, a, x)

# troca a malha do MeshInstance do modelo pela versão com pesos e devolve o esqueleto (ou null se não deu)
static func montar(mod: Node3D, caminho: String) -> Skeleton3D:
	var lista := mod.find_children("*", "MeshInstance3D", true, false)
	if lista.is_empty(): return null
	var mi: MeshInstance3D = lista[0]
	if not _cache.has(caminho): _cache[caminho] = _preparar(mi.mesh)
	var c: Array = _cache[caminho]
	if c.is_empty(): return null
	var mats := []
	for i in mi.mesh.get_surface_count(): mats.append(mi.get_surface_override_material(i))
	mi.mesh = c[0]
	for i in mats.size(): mi.set_surface_override_material(i, mats[i])
	var esq := Skeleton3D.new(); esq.name = "Esqueleto"
	mi.get_parent().add_child(esq); esq.transform = mi.transform
	var pos: Array = c[2]; var pais: Array = c[3]
	for i in pos.size():
		esq.add_bone("b%d" % i)
		if pais[i] >= 0: esq.set_bone_parent(i, pais[i])
		var local: Vector3 = pos[i] - (pos[pais[i]] if pais[i] >= 0 else Vector3.ZERO)
		esq.set_bone_rest(i, Transform3D(Basis(), local)); esq.set_bone_pose_position(i, local)
	mi.transform = Transform3D()
	mi.get_parent().remove_child(mi); esq.add_child(mi)
	mi.skin = c[1]; mi.skeleton = NodePath("..")
	return esq

static func _preparar(malha: Mesh) -> Array:
	var arr: Array = malha.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n := v.size()
	if n == 0: return []
	var mn := Vector3(1e9, 1e9, 1e9); var mx := -mn
	for p in v: mn = mn.min(p); mx = mx.max(p)
	var alt := mx.y - mn.y; var comp := mx.x - mn.x
	# patas: o que está no quarto de baixo da altura, separado em frente/trás pelo meio do comprimento e
	# esquerda/direita pelo lado; o rabo (bem atrás) fica de fora
	var meio_x := mn.x + comp * 0.5
	var lim_cauda := mn.x + comp * 0.13
	var soma := [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]; var cont := [0, 0, 0, 0]
	for p in v:
		if p.y > mn.y + alt * 0.25 or p.x < lim_cauda: continue
		var k := (0 if p.x > meio_x else 2) + (0 if p.z < 0.0 else 1)
		soma[k] += p; cont[k] += 1
	for k in 4:
		if cont[k] == 0: return []
	var pata_c := []
	for k in 4: pata_c.append(soma[k] / cont[k])
	var topo := mn.y + alt * 0.49           # ombro/quadril (dentro do corpo, um pouco acima da barriga)
	var joelho := mn.y + alt * 0.22
	var pos := [Vector3(0, mn.y + alt * 0.6, 0)]
	var pais := [-1]
	for k in 4: pos.append(Vector3(pata_c[k].x, topo, pata_c[k].z)); pais.append(CORPO)
	for k in 4: pos.append(Vector3(pata_c[k].x, joelho, pata_c[k].z)); pais.append(COXA[k])
	var x_pesc := mn.x + comp * 0.7
	pos.append(Vector3(x_pesc, mn.y + alt * 0.62, 0)); pais.append(CORPO)
	pos.append(Vector3(mn.x + comp * 0.07, mn.y + alt * 0.62, 0)); pais.append(CORPO)
	var meia_pata := comp * 0.11
	var ossos := PackedInt32Array(); ossos.resize(n * 4)
	var pesos := PackedFloat32Array(); pesos.resize(n * 4)
	for i in n:
		var p := v[i]
		var a := CORPO; var b := CORPO; var w := 0.0      # peso w no osso b, (1 - w) no osso a
		var k := (0 if p.x > meio_x else 2) + (0 if p.z < 0.0 else 1)
		var pc: Vector3 = pata_c[k]
		# perto do chão (abaixo do joelho) quase tudo é pata, com faixa mais larga para os pelos dos cascos;
		# só o fiozinho do rabo (bem no meio e bem atrás) fica de fora. Mais em cima, faixa estreita e nada do rabo.
		var rabo := (absf(p.z) < comp * 0.045 and p.x < lim_cauda) or p.x < mn.x + comp * 0.065
		var na_pata: bool
		if p.y < joelho: na_pata = absf(p.x - pc.x) < comp * 0.17 and not rabo
		else: na_pata = absf(p.x - pc.x) < meia_pata and p.y < topo + alt * 0.06 and p.x > lim_cauda
		if na_pata:
			var w_pata := _ss(topo + alt * 0.04, topo - alt * 0.14, p.y)    # 0 na barriga → 1 na pata
			var w_can := _ss(joelho + alt * 0.05, joelho - alt * 0.05, p.y)  # 0 na coxa → 1 na canela
			if w_can > 0.0: a = COXA[k]; b = CANELA[k]; w = w_can
			else: a = CORPO; b = COXA[k]; w = w_pata
		elif p.x > x_pesc - comp * 0.06 and p.y > topo:
			b = PESCOCO; w = _ss(x_pesc - comp * 0.06, x_pesc + comp * 0.08, p.x)
		elif p.x < mn.x + comp * 0.13 and (p.y >= joelho or rabo):
			b = CAUDA; w = _ss(mn.x + comp * 0.13, mn.x + comp * 0.05, p.x)
		ossos[i * 4] = a; ossos[i * 4 + 1] = b; ossos[i * 4 + 2] = 0; ossos[i * 4 + 3] = 0
		pesos[i * 4] = 1.0 - w; pesos[i * 4 + 1] = w; pesos[i * 4 + 2] = 0.0; pesos[i * 4 + 3] = 0.0
	arr[Mesh.ARRAY_BONES] = ossos; arr[Mesh.ARRAY_WEIGHTS] = pesos
	var nova := ArrayMesh.new()
	nova.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	nova.surface_set_material(0, malha.surface_get_material(0))
	var skin := Skin.new()
	for i in pos.size(): skin.add_bind(i, Transform3D(Basis(), -pos[i]))
	return [nova, skin, pos, pais]

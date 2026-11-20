# Floresta da região: árvores em pedaços de 64 m (MultiMesh), distribuídas pela "mata" da Regiao.
#  - carvalhos e bétulas: tronco low poly + copa em pixel splats (verde de verão, algumas de outono)
#  - pinheiros: tronco + 3 cones (perto das montanhas e no alto)
#  - árvores mortas: no pântano
# Desenho até ~300 m (somem na neblina). Colisão só nos pedaços perto do jogador.
extends Node3D
class_name Floresta

const PED := 64.0
const VISTA := 300.0
const COLIDE := 70.0
var m
var reg: Regiao
var mats := {}
var malhas := {}
var arvores := {}        # Vector2i → [[pos, raio], ...]
var corpos := {}

func montar(mundo) -> void:
	m = mundo; reg = mundo.reg
	malhas = { "pinho": _malha_pinho(), "tronco": _malha_tronco(false), "morta": _malha_tronco(true) }
	var sm := ShaderMaterial.new(); sm.shader = load("res://shaders/splat.gdshader")
	sm.set_shader_parameter("balanco", 0.25); sm.set_shader_parameter("neblina", m.NEBLINA)
	mats["copa"] = sm
	var n := int(ceil(2.0 * Regiao.LIM / PED))
	for j in n: for i in n: _pedaco(Vector2i(i, j))

func _malha_pinho() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	m.cilindro(st, Vector3.ZERO, 0.24, 0.14, 1.8, 5); st.set_material(m.mat("casca")); st.commit(mesh)
	st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3: m.cilindro(st, Vector3(0, 1.3 + k * 1.6, 0), 2.2 - k * 0.55, 0.0, 2.8, 6)
	st.set_material(m.mat("pinho")); st.commit(mesh)
	return mesh

func _malha_tronco(morta: bool) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	m.cilindro(st, Vector3.ZERO, 0.32, 0.18, 4.0, 6)
	# galhos
	for g in [[Vector3(0, 2.6, 0), Vector3(1.4, 1.6, 0.3)], [Vector3(0, 3.0, 0), Vector3(-1.2, 1.7, -0.5)], [Vector3(0, 3.4, 0), Vector3(0.2, 1.5, 1.2)]]:
		var a: Vector3 = g[0]; var d: Vector3 = g[1]
		var x := d.normalized().cross(Vector3(0, 0, 1)).normalized() * 0.09
		var z := d.normalized().cross(x).normalized() * 0.09
		m._quad(st, a - x, a + x, a + d + x * 0.4, a + d - x * 0.4, 0.3, 1.0)
		m._quad(st, a - z, a + z, a + d + z * 0.4, a + d - z * 0.4, 0.3, 1.0)
	st.set_material(m.mat("casca", 1.0, Color(0.55, 0.52, 0.48) if morta else Color.WHITE)); st.commit(mesh)
	return mesh

func _pedaco(k: Vector2i) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = hash([k.x, k.y, 99])
	var o := Vector2(k.x * PED - Regiao.LIM, k.y * PED - Regiao.LIM)
	var pinhos := []; var troncos := []; var mortas := []; var copas := []; var lista := []
	var passo := 6.5
	for jj in int(PED / passo):
		for ii in int(PED / passo):
			var x := o.x + (ii + rng.randf()) * passo; var z := o.y + (jj + rng.randf()) * passo
			var f := reg.floresta(x, z); var pnt := reg.zona_pantano(z)
			var prob := f * 0.85 + 0.025
			if pnt > 0.5: prob = 0.06
			if rng.randf() > prob: continue
			if not reg.dentro(x, z) or reg.dist_estrada(x, z) < 5.0 or Vector2(x, z).length() < 45.0: continue
			if reg.campo_em(x, z) >= 0 or reg.dist_rio(x, z) < 12.0: continue
			if Vector2(x - Regiao.LAGO.x, z - Regiao.LAGO.y).length() < Regiao.LAGO.z + 6.0: continue
			var h := reg.altura(x, z)
			if h > 36.0 or h < 0.6 or (x > 380.0 and h < 2.5): continue
			if m.perto_de_lugar(x, z, 8.0): continue
			var s := rng.randf_range(0.8, 1.35)
			var base := Vector3(x, h - 0.2, z)
			var giro := Basis(Vector3.UP, rng.randf() * TAU)
			if pnt > 0.5:
				mortas.append(Transform3D(giro.scaled(Vector3(s, s * 0.9, s)), base)); lista.append([base, 0.3 * s])
			elif h > 18.0 or reg.ruido.get_noise_2d(x * 0.9, z * 0.9) > 0.25:
				pinhos.append(Transform3D(giro.scaled(Vector3(s, s * rng.randf_range(1.0, 1.4), s)), base)); lista.append([base, 0.28 * s])
			else:
				troncos.append(Transform3D(giro.scaled(Vector3(s, s, s)), base)); lista.append([base, 0.32 * s])
				# copa: verde de verão; algumas douradas/avermelhadas
				var outono := reg.ruido_grande.get_noise_2d(x * 3.0, z * 3.0) > 0.38
				var tom: Color = [Color(0.36, 0.55, 0.22), Color(0.45, 0.62, 0.25), Color(0.3, 0.48, 0.2), Color(0.5, 0.6, 0.24)][rng.randi() % 4]
				if outono: tom = [Color(0.9, 0.6, 0.22), Color(0.82, 0.4, 0.18), Color(0.92, 0.75, 0.3)][rng.randi() % 3]
				var copa := base + Vector3(0, 4.6 * s, 0)
				for c in 42:
					var dv := Vector3(rng.randfn(0, 1), rng.randfn(0, 0.7), rng.randfn(0, 1)).normalized() * pow(rng.randf(), 0.6) * 2.2 * s
					var luz: float = 0.6 + 0.45 * clamp(dv.y / (2.4 * s) * 0.5 + 0.5, 0.0, 1.0)
					copas.append([copa + dv, tom * luz * rng.randf_range(0.88, 1.12), rng.randf_range(1.0, 1.45) * s])
	arvores[k] = lista
	var no := Node3D.new(); add_child(no)
	for par in [["pinho", pinhos], ["tronco", troncos], ["morta", mortas]]:
		if par[1].is_empty(): continue
		var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = malhas[par[0]]
		mm.instance_count = par[1].size()
		for i in par[1].size(): mm.set_instance_transform(i, par[1][i])
		var mi := MultiMeshInstance3D.new(); mi.multimesh = mm; mi.visibility_range_end = VISTA; no.add_child(mi)
	if not copas.is_empty():
		var q := QuadMesh.new(); q.size = Vector2(1, 1)
		var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_colors = true; mm.mesh = q
		mm.instance_count = copas.size()
		for i in copas.size():
			var it: Array = copas[i]; var e: float = it[2]
			mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(e, e, 1)), it[0])); mm.set_instance_color(i, it[1])
		var mi := MultiMeshInstance3D.new(); mi.multimesh = mm; mi.material_override = mats["copa"]
		mi.visibility_range_end = VISTA; no.add_child(mi)

func _process(_d: float) -> void:
	if m.jogador == null: return
	var jp: Vector3 = m.jogador.global_position; var p := Vector2(jp.x, jp.z)
	for k in arvores.keys():
		var centro := Vector2(k.x * PED - Regiao.LIM + PED * 0.5, k.y * PED - Regiao.LIM + PED * 0.5)
		var perto := centro.distance_to(p) < COLIDE
		if perto and not corpos.has(k):
			var corpo := StaticBody3D.new()
			for a in arvores[k]:
				var cs := CollisionShape3D.new(); var c := CylinderShape3D.new(); c.radius = a[1]; c.height = 4.0
				cs.shape = c; cs.position = a[0] + Vector3(0, 2.0, 0); corpo.add_child(cs)
			add_child(corpo); corpos[k] = corpo
		elif not perto and corpos.has(k) and centro.distance_to(p) > COLIDE + 30.0:
			corpos[k].queue_free(); corpos.erase(k)

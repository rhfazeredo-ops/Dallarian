# Grama: tufos de folhas retangulares de ponta quadrada (estilo pixel, leves) (shaders/grama.gdshader), montados em volta do jogador
# enquanto ele anda (blocos com sorteio fixo, poucos por quadro), como o chão de splats.
#  - perto (até ~24 m): tufos densos e finos
#  - longe (até ~55 m): tufos mais espaçados e um pouco maiores (de longe parecem iguais)
# Trigo: tufos mais altos, dourados, com espiga mais grossa na ponta.
extends Node3D
class_name Grama

var m
var mat: ShaderMaterial
var malhas := {}
var camadas := [
	{ "bloco": 8, "raio": 20.0, "dens": 5.0, "esc": 1.0, "malha": "perto", "ativos": {} },
	{ "bloco": 16, "raio": 50.0, "dens": 0.8, "esc": 1.4, "malha": "longe", "ativos": {} },
]

func montar(mundo) -> void:
	m = mundo
	mat = ShaderMaterial.new(); mat.shader = load("res://shaders/grama.gdshader")
	mat.set_shader_parameter("neblina", m.NEBLINA)
	# folhas por tufo: perto mais folhas finas; longe menos folhas, um pouco mais largas
	malhas = { "perto": [_malha_tufo(7, 0.022, false, 1), _malha_tufo(5, 0.016, true, 2)],
		"longe": [_malha_tufo(4, 0.032, false, 3), _malha_tufo(4, 0.024, true, 4)] }

# um tufo: folhas retangulares de ponta quadrada (estilo pixel), cada uma um retângulo só (2 triângulos),
# inclinado para um lado. Bem mais leve que folha curva.
func _malha_tufo(n: int, larg: float, trigo: bool, seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new(); rng.seed = seed
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		var ang := TAU * i / n + rng.randf_range(-0.4, 0.4)
		var dirc := Vector3(cos(ang), 0, sin(ang))
		var lado := Vector3(-dirc.z, 0, dirc.x)
		var alt := rng.randf_range(0.6, 1.0)
		var incl := rng.randf_range(0.08, 0.28) * (0.4 if trigo else 1.0)
		var base := dirc * rng.randf_range(0.0, 0.06)
		var topo := base + dirc * incl * alt + Vector3(0, alt, 0)
		var w := larg * rng.randf_range(0.85, 1.2)
		var q := [base - lado * w, base + lado * w, topo + lado * w, topo - lado * w]
		var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP); st.set_uv(uvs[k]); st.set_color(Color.WHITE); st.add_vertex(q[k])
		if trigo:                                  # espiga: um retângulo mais largo na ponta
			var e0 := topo - Vector3(0, alt * 0.22, 0)
			var qe := [e0 - lado * w * 1.8, e0 + lado * w * 1.8, topo + lado * w * 1.8, topo - lado * w * 1.8]
			var ue := [Vector2(0, 0.95), Vector2(1, 0.95), Vector2(1, 1), Vector2(0, 1)]
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_normal(Vector3.UP); st.set_uv(ue[k]); st.set_color(Color.WHITE); st.add_vertex(qe[k])
	return st.commit()

var _primeira := true
func _process(_d: float) -> void:
	if m == null or m.jogador == null: return
	var jp: Vector3 = m.jogador.global_position
	mat.set_shader_parameter("jogador", jp)
	var p := Vector2(jp.x, jp.z)
	var orcamento := 1000000 if _primeira else 2
	_primeira = false
	for c in camadas:
		var b: int = c.bloco; var r: float = c.raio
		var faltam := []
		for j in range(int(floor((p.y - r) / b)), int(floor((p.y + r) / b)) + 1):
			for i in range(int(floor((p.x - r) / b)), int(floor((p.x + r) / b)) + 1):
				var centro := Vector2((i + 0.5) * b, (j + 0.5) * b)
				if centro.distance_to(p) > r + b * 0.7: continue
				var k := Vector2i(i, j)
				if not c.ativos.has(k): faltam.append([centro.distance_to(p), k])
		faltam.sort_custom(func(a, bb): return a[0] < bb[0])
		for f in faltam:
			if orcamento <= 0: break
			c.ativos[f[1]] = _bloco(c, f[1]); orcamento -= 1
		for k in c.ativos.keys():
			var centro := Vector2((k.x + 0.5) * b, (k.y + 0.5) * b)
			if centro.distance_to(p) > r + b * 1.5:
				for n in c.ativos[k]: n.queue_free()
				c.ativos.erase(k)

func _bloco(c: Dictionary, k: Vector2i) -> Array:
	var rng := RandomNumberGenerator.new(); rng.seed = hash([k.x, k.y, c.bloco, 5])
	var b: int = c.bloco
	var verde := []; var trigo := []
	for n in int(b * b * c.dens):
		var x := k.x * b + rng.randf() * b; var z := k.y * b + rng.randf() * b
		var p := Vector2(x, z)
		if not m.reg.dentro(x, z): continue
		var de: float = m._dist_estrada(p)
		if de < 2.2 + rng.randf() * 0.8: continue                 # beira da estrada irregular
		var h: float = m.altura_malha(x, z)
		var nrm: Vector3 = m.normal_malha(x, z)
		if rng.randf() > m.reg.grama(x, z, h, nrm.y): continue
		var cor: Color = m.cor_chao(x, z, h, nrm.y)
		var eh_trigo := cor.r > 0.66
		# falhas: em alguns lugares a grama some (manchas de terra)
		if not eh_trigo and m.reg.ruido.get_noise_2d(x * 2.3, z * 2.3) < -0.35: continue
		var alt: float = rng.randf_range(0.28, 0.5) * c.esc
		var larg: float = rng.randf_range(0.8, 1.25) * c.esc
		if eh_trigo: alt = rng.randf_range(0.75, 1.0) * c.esc
		var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(larg, alt, larg)), Vector3(x, h - 0.03, z))
		var tons := [Color(1.0, 1.0, 1.0), Color(0.9, 1.05, 0.85), Color(1.1, 1.05, 0.8), Color(0.85, 0.95, 1.0)]
		var tom: Color = tons[rng.randi() % tons.size()]
		var cc := Color(cor.r * tom.r, cor.g * tom.g, cor.b * tom.b) * rng.randf_range(0.9, 1.1)
		if not eh_trigo: cc = cc.lerp(Color(0.42, 0.6, 0.24), 0.35)    # grama um pouco mais verde e viva
		(trigo if eh_trigo else verde).append([t, cc])
	var nos := []
	var ms: Array = malhas[c.malha]
	if not verde.is_empty(): nos.append(_multimesh(ms[0], verde))
	if not trigo.is_empty(): nos.append(_multimesh(ms[1], trigo))
	return nos

func _multimesh(malha: ArrayMesh, itens: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_colors = true; mm.mesh = malha
	mm.instance_count = itens.size()
	for i in itens.size():
		mm.set_instance_transform(i, itens[i][0]); mm.set_instance_color(i, itens[i][1])
	var mi := MultiMeshInstance3D.new(); mi.multimesh = mm; mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi); return mi

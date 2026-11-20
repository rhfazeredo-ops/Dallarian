# Chão pintado em pixel splats (shaders/splat_chao.gdshader): milhares de manchinhas deitadas sobre o
# terreno, como pinceladas. Cada uma pega a cor do lugar onde está (grama, trigo, terra, pedra) com uma
# variação de tom, então as bordas entre os terrenos ficam "pinceladas", sem degradê.
#  - camada fina: manchas pequenas e densas, só perto do jogador (blocos de 16 m, somem a ~55 m)
#  - camada grossa: manchas grandes no mapa todo (vista de longe)
#  - flores: pontinhos coloridos na grama
#  - poças: água que reflete o céu, com borda de lama
extends Node3D
class_name ChaoSplat

var m        # o mundo (altura, normal e cor do chão)
var mat: ShaderMaterial
var rng := RandomNumberGenerator.new()
var _luz := FastNoiseLite.new()

func montar(mundo) -> void:
	m = mundo; rng.seed = 77
	_luz.seed = 3; _luz.frequency = 0.03
	mat = ShaderMaterial.new(); mat.shader = load("res://shaders/splat_chao.gdshader")
	mat.set_shader_parameter("neblina", m.NEBLINA)
	_camada(32, 135.0, 0.22, Vector2(1.4, 3.0), 0.012, 0.0)        # grossa
	_camada(16, 110.0, 1.5, Vector2(0.45, 1.1), 0.035, 55.0)       # fina
	_pocas()

# cor de uma pincelada: cor do chão no lugar + variação de tom + manchas grandes de luz e sombra
func pincel(x: float, z: float, h: float, ny: float) -> Color:
	var c: Color = m.cor_chao(x, z, h, ny)
	# tons de pincel: claro e quente, escuro e frio, neutro, ocre, verde-amarelado
	var tons := [Color(1.2, 1.12, 0.9), Color(0.74, 0.84, 0.8), Color(1.0, 1.0, 1.0), Color(1.0, 0.86, 0.66), Color(1.08, 1.16, 0.8), Color(0.84, 0.8, 0.72)]
	var t: Color = tons[rng.randi() % tons.size()]
	c = Color(c.r * t.r, c.g * t.g, c.b * t.b)
	var l := _luz.get_noise_2d(x, z)                          # zonas mais claras/escuras (como no vídeo)
	c *= 1.0 + clamp(l * 0.8, -0.22, 0.16)
	return c * rng.randf_range(0.93, 1.06)

func _base(x: float, z: float) -> Array:
	var h: float = m.altura_malha(x, z)
	var n: Vector3 = m.normal_malha(x, z)
	return [h, n]

func _transf(p: Vector3, n: Vector3, sx: float, sz: float, ang: float) -> Transform3D:
	var t := Vector3(cos(ang), 0, sin(ang)); t = (t - n * t.dot(n)).normalized()
	var z := t.cross(n)
	return Transform3D(Basis(t * sx, n, z * sz), p)

func _camada(bloco: int, raio: float, dens: float, tam: Vector2, alt: float, ate: float) -> void:
	var meio := int(raio)
	for bz in range(-meio, meio, bloco):
		for bx in range(-meio, meio, bloco):
			var itens := []   # [Transform3D, cor, tipo]
			var n_tent := int(bloco * bloco * dens)
			for k in n_tent:
				var x := bx + rng.randf() * bloco; var z := bz + rng.randf() * bloco
				if Vector2(x, z).length() > raio: continue
				var b := _base(x, z); var h: float = b[0]; var nrm: Vector3 = b[1]
				var s := rng.randf_range(tam.x, tam.y)
				var p := Vector3(x, h, z) + nrm * (alt + rng.randf() * alt)
				itens.append([_transf(p, nrm, s, s * rng.randf_range(0.45, 1.0), rng.randf() * TAU), pincel(x, z, h, nrm.y), 0.0])
				# flores na grama (só na camada fina)
				if ate > 0.0 and rng.randf() < 0.035:
					var cor: Color = m.cor_chao(x, z, h, nrm.y)
					if cor.g > cor.r and m._dist_estrada(Vector2(x, z)) > 3.0 and Vector2(x, z).length() > 18.0:
						var fl: Color = [Color(0.92, 0.3, 0.25), Color(0.96, 0.94, 0.88), Color(0.62, 0.42, 0.85), Color(0.98, 0.84, 0.3)][rng.randi() % 4]
						var fx := x + rng.randf_range(-0.3, 0.3); var fz := z + rng.randf_range(-0.3, 0.3)
						for j in rng.randi_range(2, 5):
							var q := Vector3(fx + rng.randf_range(-0.35, 0.35), 0, fz + rng.randf_range(-0.35, 0.35))
							q.y = m.altura_malha(q.x, q.z) + 0.11
							itens.append([_transf(q, nrm, 0.13, 0.13, 0.0), fl * rng.randf_range(0.9, 1.1), 0.0])
			if itens.is_empty(): continue
			var mi := _multimesh(itens)
			if ate > 0.0: mi.visibility_range_end = ate; mi.visibility_range_end_margin = 6.0

func _multimesh(itens: Array) -> MultiMeshInstance3D:
	var pm := PlaneMesh.new(); pm.size = Vector2(1, 1)
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true; mm.use_custom_data = true; mm.mesh = pm
	mm.instance_count = itens.size()
	for i in itens.size():
		var it: Array = itens[i]
		mm.set_instance_transform(i, it[0]); mm.set_instance_color(i, it[1])
		mm.set_instance_custom_data(i, Color(it[2], rng.randf(), 0, 0))
	var mi := MultiMeshInstance3D.new(); mi.multimesh = mm; mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi); return mi

# poças na estrada e na praça: água (reflete o céu) com borda de lama escura
func _pocas() -> void:
	var itens := []
	var lugares := []
	var est: PackedVector2Array = m.estrada
	for k in 26:
		var i := rng.randi() % (est.size() - 1)
		var p := est[i].lerp(est[i + 1], rng.randf()) + Vector2(rng.randf_range(-1.2, 1.2), rng.randf_range(-1.2, 1.2))
		lugares.append(p)
	for k in 8: lugares.append(Vector2(rng.randf_range(-12, 12), rng.randf_range(-12, 12)))
	for p in lugares:
		if p.length() < 2.5: continue          # não no poço
		var r := rng.randf_range(0.6, 1.5)
		var ang := rng.randf() * TAU; var alonga := rng.randf_range(0.5, 0.9)
		var b := _base(p.x, p.y); var nrm: Vector3 = b[1]
		for j in 7:                             # borda de lama
			var a := TAU * j / 7.0 + rng.randf() * 0.4
			var o := Vector2(cos(a) * r, sin(a) * r * alonga).rotated(ang) * 0.9
			var q := Vector3(p.x + o.x, 0, p.y + o.y); q.y = m.altura_malha(q.x, q.z) + 0.07
			itens.append([_transf(q, nrm, r * 0.9, r * 0.6, a), Color(0.3, 0.21, 0.14) * rng.randf_range(0.85, 1.1), 0.0])
		for j in 4:                             # água
			var o := Vector2(rng.randf_range(-0.35, 0.35) * r, rng.randf_range(-0.35, 0.35) * r * alonga).rotated(ang)
			var q := Vector3(p.x + o.x, 0, p.y + o.y); q.y = m.altura_malha(q.x, q.z) + 0.1
			itens.append([_transf(q, nrm, r * 1.5, r * 1.5 * alonga, ang), Color.WHITE, 1.0])
	_multimesh(itens)

# Chão pintado em pixel splats (shaders/splat_chao.gdshader): manchinhas deitadas sobre o terreno, como
# pinceladas. Cada uma pega a cor do lugar (grama, trigo, terra, pedra) com uma variação de tom, então as
# bordas entre terrenos ficam "pinceladas", sem degradê.
# Três camadas, da menor para a maior:
#  - miúda: manchas bem pequenas e muito densas, só até ~18 m do jogador
#  - média: manchas médias, até ~55 m (flores ficam na miúda)
#  - grossa: manchas grandes até ~150 m (paisagem)
# As camadas são montadas EM VOLTA do jogador enquanto ele anda (blocos criados perto e
# apagados longe, poucos por quadro). Cada bloco tem sorteio fixo (semente pela posição): volta igual.
extends Node3D
class_name ChaoSplat

var m        # o mundo (altura, normal e cor do chão, jogador)
var mat: ShaderMaterial
var _luz := FastNoiseLite.new()
# bloco (m), alcance (m), splats por m², tamanho mín/máx (m), altura acima do chão (m), flores?
var camadas := [
	{ "bloco": 8, "raio": 15.0, "dens": 13.0, "tam": Vector2(0.18, 0.38), "alt": 0.06, "flores": true, "ativos": {} },
	{ "bloco": 24, "raio": 42.0, "dens": 1.6, "tam": Vector2(0.28, 0.55), "alt": 0.035, "flores": false, "ativos": {} },
	{ "bloco": 64, "raio": 120.0, "dens": 0.16, "tam": Vector2(1.4, 3.0), "alt": 0.012, "flores": false, "ativos": {} },
]

func montar(mundo) -> void:
	m = mundo
	if m.celular:
		camadas[0].raio = 12.0; camadas[0].dens = 10.0; camadas[1].raio = 34.0; camadas[1].dens = 1.2; camadas[2].raio = 95.0
	_luz.seed = 3; _luz.frequency = 0.03
	mat = ShaderMaterial.new(); mat.shader = load("res://shaders/splat_chao.gdshader")
	mat.set_shader_parameter("neblina", m.NEBLINA)
	_pocas()

var _primeira := true
var obras := Obras.new()
func _process(_d: float) -> void:
	if m == null or m.jogador == null: return
	var p: Vector2 = Vector2(m.jogador.global_position.x, m.jogador.global_position.z)
	_receber()
	var orcamento := 1000000 if _primeira else 2         # no começo monta tudo de uma vez
	_primeira = false
	for c in camadas:
		var b: int = c.bloco; var r: float = c.raio
		var i0 := int(floor((p.x - r) / b)); var i1 := int(floor((p.x + r) / b))
		var j0 := int(floor((p.y - r) / b)); var j1 := int(floor((p.y + r) / b))
		var faltam := []
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				var centro := Vector2((i + 0.5) * b, (j + 0.5) * b)
				if centro.distance_to(p) > r + b * 0.7: continue
				var k := Vector2i(i, j)
				if not c.ativos.has(k): faltam.append([centro.distance_to(p), k])
		faltam.sort_custom(func(a, bb): return a[0] < bb[0])     # os mais perto primeiro
		var ci: int = camadas.find(c)
		for f in faltam:
			if orcamento > 100:                                    # começo do jogo: monta tudo na hora
				c.ativos[f[1]] = _bloco(c, f[1]); continue
			var ch := [ci, f[1]]
			if obras.pendente(ch) or obras.cheio(): continue
			var cc: Dictionary = c; var kk: Vector2i = f[1]
			obras.pedir(ch, func(): return Obras.empacotar(_itens(cc, kk), true))   # monta em segundo plano
		for k in c.ativos.keys():                                  # apaga os que ficaram longe
			var centro := Vector2((k.x + 0.5) * b, (k.y + 0.5) * b)
			if centro.distance_to(p) > r + b * 1.5:
				if c.ativos[k]: c.ativos[k].queue_free()
				c.ativos.erase(k)

# cor de uma pincelada: cor do chão no lugar + tom de pincel + zonas grandes de luz e sombra
func pincel(rng: RandomNumberGenerator, x: float, z: float, h: float, ny: float) -> Color:
	var c: Color = m.cor_chao(x, z, h, ny)
	# tons: claro e quente, escuro e frio, neutro, ocre, verde-amarelado, terra
	var tons := [Color(1.2, 1.12, 0.9), Color(0.74, 0.84, 0.8), Color(1.0, 1.0, 1.0), Color(1.0, 0.86, 0.66), Color(1.08, 1.16, 0.8), Color(0.84, 0.8, 0.72)]
	var t: Color = tons[rng.randi() % tons.size()]
	c = Color(c.r * t.r, c.g * t.g, c.b * t.b)
	c *= 1.0 + clamp(_luz.get_noise_2d(x, z) * 0.8, -0.22, 0.16)
	# mata fechada: o chão é coberto de folhas caídas (marrons, ocres, laranjas e algumas verdes)
	var f: float = m.reg.floresta(x, z)
	if f > 0.4 and rng.randf() < smoothstep(0.4, 0.8, f) * 0.9:
		var folhas := [Color(0.5, 0.32, 0.16), Color(0.62, 0.42, 0.18), Color(0.72, 0.5, 0.2), Color(0.78, 0.38, 0.16), Color(0.42, 0.28, 0.16), Color(0.46, 0.5, 0.22)]
		c = folhas[rng.randi() % folhas.size()] * (1.0 + clamp(_luz.get_noise_2d(x, z) * 0.8, -0.22, 0.16))
	return c * rng.randf_range(0.93, 1.06)

func _transf(p: Vector3, n: Vector3, sx: float, sz: float, ang: float) -> Transform3D:
	var t := Vector3(cos(ang), 0, sin(ang)); t = (t - n * t.dot(n)).normalized()
	return Transform3D(Basis(t * sx, n, t.cross(n) * sz), p)

func _bloco(c: Dictionary, k: Vector2i) -> MultiMeshInstance3D:
	var itens := _itens(c, k)
	return _multimesh(itens) if not itens.is_empty() else null

# as manchas de um bloco (roda fora do quadro principal: só lê o mapa)
func _itens(c: Dictionary, k: Vector2i) -> Array:
	var rng := RandomNumberGenerator.new(); rng.seed = hash([k.x, k.y, c.bloco])
	var b: int = c.bloco; var itens := []
	for n in int(b * b * c.dens):
		var x := k.x * b + rng.randf() * b; var z := k.y * b + rng.randf() * b
		if not m.reg.dentro(x, z) or m.reg.em_construcao(x, z): continue
		var h: float = m.altura_malha(x, z); var nrm: Vector3 = m.normal_malha(x, z)
		if h < m.reg.agua(x, z) - 0.05: continue
		var s := rng.randf_range(c.tam.x, c.tam.y)
		var p: Vector3 = Vector3(x, h, z) + nrm * (c.alt + rng.randf() * c.alt)
		itens.append([_transf(p, nrm, s, s * rng.randf_range(0.45, 1.0), rng.randf() * TAU), pincel(rng, x, z, h, nrm.y), 0.0, c.raio])
		if c.flores and rng.randf() < 0.006:
			var cor: Color = m.cor_chao(x, z, h, nrm.y)
			if cor.g > cor.r and m._dist_estrada(Vector2(x, z)) > 3.0 and Vector2(x, z).length() > 18.0:
				var fl: Color = [Color(0.92, 0.3, 0.25), Color(0.96, 0.94, 0.88), Color(0.62, 0.42, 0.85), Color(0.98, 0.84, 0.3)][rng.randi() % 4]
				for j in rng.randi_range(3, 6):
					var q := Vector3(x + rng.randf_range(-0.3, 0.3), 0, z + rng.randf_range(-0.3, 0.3))
					q.y = m.altura_malha(q.x, q.z) + 0.13
					itens.append([_transf(q, nrm, 0.09, 0.09, 0.0), fl * rng.randf_range(0.9, 1.1), 0.0, c.raio])
	return itens

# blocos que ficaram prontos em segundo plano: põe na tela (se ainda estão no alcance)
func _receber() -> void:
	if m == null or m.jogador == null: return
	var p := Vector2(m.jogador.global_position.x, m.jogador.global_position.z)
	for r in obras.prontos():
		var c: Dictionary = camadas[r[0][0]]; var k: Vector2i = r[0][1]; var buf: PackedFloat32Array = r[1]
		var b: int = c.bloco
		if c.ativos.has(k) or Vector2((k.x + 0.5) * b, (k.y + 0.5) * b).distance_to(p) > c.raio + b * 1.5: continue
		c.ativos[k] = _multimesh_buf(buf) if buf.size() > 0 else null

func _multimesh_buf(buf: PackedFloat32Array) -> MultiMeshInstance3D:
	var pm := PlaneMesh.new(); pm.size = Vector2(1, 1)
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true; mm.use_custom_data = true; mm.mesh = pm
	mm.instance_count = buf.size() / 20; mm.buffer = buf
	var mi := MultiMeshInstance3D.new(); mi.multimesh = mm; mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi); return mi

func _multimesh(itens: Array) -> MultiMeshInstance3D:
	var pm := PlaneMesh.new(); pm.size = Vector2(1, 1)
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true; mm.use_custom_data = true; mm.mesh = pm
	mm.instance_count = itens.size()
	for i in itens.size():
		var it: Array = itens[i]
		mm.set_instance_transform(i, it[0]); mm.set_instance_color(i, it[1])
		mm.set_instance_custom_data(i, Color(it[2], it[3] if it.size() > 3 else 0.0, 0, 0))   # r = água, g = alcance da camada
	var mi := MultiMeshInstance3D.new(); mi.multimesh = mm; mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi); return mi

# poças na estrada e na praça: água (reflete o céu) com borda de lama escura
func _pocas() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 91
	var itens := []
	var lugares := []
	var est: PackedVector2Array = m.estrada
	for k in 26:
		var i := rng.randi() % (est.size() - 1)
		lugares.append(est[i].lerp(est[i + 1], rng.randf()) + Vector2(rng.randf_range(-1.2, 1.2), rng.randf_range(-1.2, 1.2)))
	for k in 8: lugares.append(Vector2(rng.randf_range(-12, 12), rng.randf_range(-12, 12)))
	for p in lugares:
		if p.length() < 2.5: continue
		var r := rng.randf_range(0.6, 1.5)
		var ang := rng.randf() * TAU; var alonga := rng.randf_range(0.5, 0.9)
		var nrm: Vector3 = m.normal_malha(p.x, p.y)
		for j in 12:                            # borda de lama em manchas pequenas
			var a := TAU * j / 12.0 + rng.randf() * 0.3
			var o := Vector2(cos(a) * r, sin(a) * r * alonga).rotated(ang) * 0.95
			var q := Vector3(p.x + o.x, 0, p.y + o.y); q.y = m.altura_malha(q.x, q.z) + 0.09
			itens.append([_transf(q, nrm, r * 0.45, r * 0.3, a), Color(0.3, 0.21, 0.14) * rng.randf_range(0.85, 1.1), 0.0])
		for j in 4:                             # água
			var o := Vector2(rng.randf_range(-0.35, 0.35) * r, rng.randf_range(-0.35, 0.35) * r * alonga).rotated(ang)
			var q := Vector3(p.x + o.x, 0, p.y + o.y); q.y = m.altura_malha(q.x, q.z) + 0.12
			itens.append([_transf(q, nrm, r * 1.5, r * 1.5 * alonga, ang), Color.WHITE, 1.0])
	_multimesh(itens)

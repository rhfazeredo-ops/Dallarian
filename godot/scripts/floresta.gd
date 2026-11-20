# Floresta com a técnica de "cartões" (alpha cards), a mesma usada em MMOs para ter muita árvore sem pesar:
#  - tronco simples (poucos lados, abrindo na base) com alguns galhos;
#  - a copa é feita de ~25 retângulos planos ("cartões") cruzados em ângulos diferentes, cada um com o desenho
#    de um galho cheio de folhas com fundo transparente (gerado aqui, em pixel art);
#  - pinheiros: andares de cartões de agulhas caídos para baixo em volta do tronco;
#  - arbustos: 5 cartões cruzados.
# A mesma árvore serve de perto e de longe (não precisa trocar), poucas centenas de triângulos cada.
# Árvores em pedaços de 128 m (MultiMesh por tipo), desenhadas até ~320 m. Colisão só perto do jogador.
extends Node3D
class_name Floresta

const PED := 128.0
const VISTA := 320.0
const COLIDE := 120.0
var m
var reg: Regiao
var malhas := {}         # nome → [malha do tronco (ou null), malha dos cartões (ou null)]
var arvores := {}        # Vector2i → [[pos, raio], ...]
var corpos := {}
var _mat_cartao := {}
# pontas dos galhos na malha do tronco (cartões saem delas)
const PONTAS := [Vector3(1.4, 4.2, 0.3), Vector3(-1.2, 4.7, -0.5), Vector3(0.2, 4.9, 1.2)]

func montar(mundo) -> void:
	m = mundo; reg = mundo.reg
	_mat_cartao = {
		"folhagem": _material(_tex_folhagem(96, 11)),
		"agulhas": _material(_tex_agulhas(128, 64, 12)),
		"arbusto": _material(_tex_folhagem(64, 13, true)),
	}
	malhas = {
		"copa_a": [_tronco_copa(), _cartoes_copa(1)],
		"copa_b": [null, _cartoes_copa(2)],
		"pinho": [_tronco_pinho(), _cartoes_pinho(3)],
		"arbusto": [null, _cartoes_arbusto(4)],
		"morta": [_tronco_copa(Color(0.55, 0.52, 0.48)), null],
	}
	var n := int(ceil(2.0 * Regiao.LIM / PED))
	for j in n: for i in n: _pedaco(Vector2i(i, j))

func _material(t: ImageTexture) -> ShaderMaterial:
	var sm := ShaderMaterial.new(); sm.shader = load("res://shaders/cartao.gdshader")
	sm.set_shader_parameter("tex", t); sm.set_shader_parameter("neblina", m.NEBLINA)
	return sm

# ---------- desenhos dos cartões (tons de cinza: a cor vem de cada árvore) ----------
func _px(im: Image, x: int, y: int, l: float, w: int) -> void:
	for dy in w: for dx in w:
		var xx := x + dx; var yy := y + dy
		if xx >= 0 and yy >= 0 and xx < im.get_width() and yy < im.get_height(): im.set_pixel(xx, yy, Color(l, l, l, 1))

func _linha(im: Image, a: Vector2, b: Vector2, l: float, w: int) -> void:
	var n := int(a.distance_to(b)) + 1
	for i in n + 1:
		var p := a.lerp(b, float(i) / n); _px(im, int(p.x), int(p.y), l, w)

# galho folhoso: gravetos escuros saindo de baixo e tufos de folhinhas quadradas nas pontas
func _tex_folhagem(t: int, seed: int, redondo := false) -> ImageTexture:
	var rng := RandomNumberGenerator.new(); rng.seed = seed
	var im := Image.create(t, t, true, Image.FORMAT_RGBA8); im.fill(Color(0, 0, 0, 0))
	var base := Vector2(t * 0.5, t - 1)
	var centros := []
	for k in (7 if not redondo else 5):
		var a := rng.randf_range(-PI * 0.85, -PI * 0.15) if not redondo else rng.randf() * TAU
		var r := rng.randf_range(0.18, 0.36) * t
		centros.append(Vector2(t * 0.5, t * 0.44) + Vector2(cos(a), sin(a)) * r)
	if not redondo:
		for c in centros: _linha(im, base.lerp(c, 0.35), base.lerp(c, 0.8), 0.3, 1)     # gravetos curtos (não viram "guarda-chuva")
	var nf := int(t * t * 0.14)
	for i in nf:
		var c: Vector2 = centros[rng.randi() % centros.size()]
		var p := c + Vector2(rng.randfn(0, 1), rng.randfn(0, 1)) * t * (0.085 if not redondo else 0.11)
		var l := 0.62 + 0.42 * (1.0 - p.y / t) + rng.randf_range(-0.08, 0.08)
		if rng.randf() < 0.12: l *= 0.7
		_px(im, int(p.x), int(p.y), clampf(l, 0.3, 1.1), rng.randi_range(2, 3))
	im.generate_mipmaps()
	return ImageTexture.create_from_image(im)

# galho de pinheiro visto de cima: graveto no meio (esquerda = tronco) e agulhas para os lados
func _tex_agulhas(w: int, h: int, seed: int) -> ImageTexture:
	var rng := RandomNumberGenerator.new(); rng.seed = seed
	var im := Image.create(w, h, true, Image.FORMAT_RGBA8); im.fill(Color(0, 0, 0, 0))
	_linha(im, Vector2(0, h * 0.5), Vector2(w - 4, h * 0.5), 0.3, 2)
	for i in 900:
		var u := rng.randf()
		var x := u * (w - 4)
		var larg := h * 0.48 * (1.0 - u * 0.75)                 # mais largo perto do tronco
		var lado := 1.0 if rng.randf() < 0.5 else -1.0
		var comp := rng.randf_range(0.3, 1.0) * larg
		var a := Vector2(x, h * 0.5); var b := a + Vector2(comp * 0.45, lado * comp)
		_linha(im, a, b, clampf(0.62 + rng.randf_range(-0.12, 0.3) + (0.15 if lado < 0 else 0.0), 0.35, 1.1), 1)
	im.generate_mipmaps()
	return ImageTexture.create_from_image(im)

# ---------- malhas ----------
func _cartao(st: SurfaceTool, c: Vector3, dir_u: Vector3, dir_v: Vector3, meia: Vector2, tom: float) -> void:
	var r := dir_u.normalized() * meia.x; var u := dir_v.normalized() * meia.y
	var n := r.cross(u).normalized()
	var vs := [c - r - u, c + r - u, c + r + u, c - r + u]
	var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	for k in [0, 1, 2, 0, 2, 3]:
		st.set_normal(n); st.set_color(Color(tom, tom, tom)); st.set_uv(uvs[k]); st.add_vertex(vs[k])

func _tronco_copa(cor := Color.WHITE) -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	m.cilindro(st, Vector3(0, -0.4, 0), 0.58, 0.32, 1.0, 6)                # base abrindo
	m.cilindro(st, Vector3(0, 0.6, 0), 0.32, 0.17, 3.8, 6)
	for g in PONTAS:
		var a := Vector3(0, g.y - 1.6, 0); var d: Vector3 = g - a
		var x := d.normalized().cross(Vector3(0, 0, 1)).normalized() * 0.09
		var z := d.normalized().cross(x).normalized() * 0.09
		m._quad(st, a - x, a + x, a + d + x * 0.4, a + d - x * 0.4, 0.3, 1.0)
		m._quad(st, a - z, a + z, a + d + z * 0.4, a + d - z * 0.4, 0.3, 1.0)
	var mesh := ArrayMesh.new(); st.set_material(m.mat("casca", 1.0, cor)); st.commit(mesh)
	return mesh

func _cartoes_copa(seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new(); rng.seed = seed
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centro := Vector3(0, 4.9, 0)
	# um cartão em cada ponta de galho + ~24 cruzados pela copa (casca externa e miolo)
	var pontos := []
	for p in PONTAS: pontos.append(p + Vector3(0, 0.3, 0))
	for k in 24:
		var d := Vector3(rng.randfn(0, 1), rng.randfn(0, 0.65), rng.randfn(0, 1)).normalized()
		pontos.append(centro + d * Vector3(2.0, 1.35, 2.0) * rng.randf_range(0.25, 0.95))
	for p in pontos:
		var fora: Vector3 = (p - centro); fora.y *= 0.5
		fora = fora.normalized() if fora.length() > 0.1 else Vector3(1, 0, 0)
		var cima := (Vector3.UP * rng.randf_range(0.2, 1.0) + fora * rng.randf_range(0.2, 0.9) + Vector3(rng.randfn(0, 0.35), 0, rng.randfn(0, 0.35))).normalized()
		var lado := cima.cross(fora.rotated(Vector3.UP, rng.randf_range(-0.6, 0.6))).normalized()
		if lado.length() < 0.1: lado = Vector3(1, 0, 0)
		var tam := rng.randf_range(1.05, 1.5)
		var tom := clampf(0.72 + 0.3 * ((p.y - centro.y) / 1.35 * 0.5 + 0.5) + fora.length() * 0.0, 0.6, 1.08)
		_cartao(st, p, lado, cima, Vector2(tam, tam), tom)
		# cruzado: o mesmo lugar, girado 90° em volta do "cima" (vê-se cheio de qualquer lado)
		if rng.randf() < 0.55: _cartao(st, p, lado.rotated(cima, PI / 2), cima, Vector2(tam, tam) * 0.9, tom * 0.92)
	var mesh := ArrayMesh.new(); st.set_material(_mat_cartao["folhagem"]); st.commit(mesh)
	return mesh

func _tronco_pinho() -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	m.cilindro(st, Vector3(0, -0.4, 0), 0.42, 0.24, 0.9, 6)
	m.cilindro(st, Vector3(0, 0.5, 0), 0.24, 0.05, 7.4, 6)
	var mesh := ArrayMesh.new(); st.set_material(m.mat("casca")); st.commit(mesh)
	return mesh

func _cartoes_pinho(seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new(); rng.seed = seed
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var andares := 7
	for a in andares:
		var t := float(a) / (andares - 1)
		var y: float = lerp(1.5, 7.2, t); var comp: float = lerp(2.5, 0.7, t)
		var n := 6 if t < 0.6 else 4
		var giro := rng.randf() * TAU
		for k in n:
			var ang := giro + TAU * k / n + rng.randf_range(-0.2, 0.2)
			var fora := Vector3(cos(ang), 0, sin(ang))
			var cai := fora.rotated(fora.cross(Vector3.UP).normalized(), deg_to_rad(rng.randf_range(18, 32)))   # caído para baixo
			var lado := fora.cross(Vector3.UP).normalized()
			var c := Vector3(0, y, 0) + cai * comp * 0.5
			var tom: float = lerp(0.72, 1.0, t) * rng.randf_range(0.92, 1.05)
			_cartao(st, c, cai, lado.rotated(cai, deg_to_rad(rng.randf_range(-20, 20))), Vector2(comp * 0.5, comp * 0.3), tom)
	# ponta: dois cartões em pé, cruzados
	for k in 2:
		var lado := Vector3(cos(k * PI / 2), 0, sin(k * PI / 2))
		_cartao(st, Vector3(0, 7.9, 0), Vector3.UP, lado, Vector2(0.8, 0.28), 1.05)
	var mesh := ArrayMesh.new(); st.set_material(_mat_cartao["agulhas"]); st.commit(mesh)
	return mesh

func _cartoes_arbusto(seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new(); rng.seed = seed
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 5:
		var ang := TAU * k / 5.0 + rng.randf_range(-0.2, 0.2)
		var lado := Vector3(cos(ang), 0, sin(ang))
		var cima := Vector3(0, 1, 0).rotated(lado, rng.randf_range(-0.35, 0.35))
		_cartao(st, Vector3(0, 0.5, 0), lado, cima, Vector2(0.75, 0.62), rng.randf_range(0.85, 1.05))
	_cartao(st, Vector3(0, 0.75, 0), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector2(0.6, 0.6), 1.05)   # tampa de cima
	var mesh := ArrayMesh.new(); st.set_material(_mat_cartao["arbusto"]); st.commit(mesh)
	return mesh

# ---------- distribuição ----------
func _pedaco(k: Vector2i) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = hash([k.x, k.y, 99])
	var o := Vector2(k.x * PED - Regiao.LIM, k.y * PED - Regiao.LIM)
	var grupos := {}   # nome → [[Transform3D, Color], ...]
	for nome in malhas.keys(): grupos[nome] = []
	var lista := []
	var passo := 5.2
	for jj in int(PED / passo):
		for ii in int(PED / passo):
			var x := o.x + (ii + rng.randf()) * passo; var z := o.y + (jj + rng.randf()) * passo
			var f := reg.floresta(x, z); var pnt := reg.zona_pantano(z)
			var prob := f * 0.95 + 0.02
			if pnt > 0.5: prob = 0.06
			var arbusto := false
			if rng.randf() > prob:
				# arbustos: na beira da mata e espalhados pelo campo
				if rng.randf() < 0.05 + smoothstep(0.1, 0.5, f) * 0.25: arbusto = true
				else: continue
			if not reg.dentro(x, z) or reg.dist_estrada(x, z) < (3.0 if arbusto else 5.0) or Vector2(x, z).length() < (30.0 if arbusto else 45.0): continue
			if reg.campo_em(x, z) >= 0 or reg.dist_rio(x, z) < (9.0 if arbusto else 12.0): continue
			if Vector2(x - Regiao.LAGO.x, z - Regiao.LAGO.y).length() < Regiao.LAGO.z + 6.0: continue
			var h := reg.altura(x, z)
			if h > 36.0 or h < 0.6 or (x > 380.0 and h < 2.5): continue
			if m.perto_de_lugar(x, z, 4.0 if arbusto else 8.0): continue
			var giro := Basis(Vector3.UP, rng.randf() * TAU)
			if arbusto:
				var s := rng.randf_range(0.7, 1.5)
				grupos["arbusto"].append([Transform3D(giro.scaled(Vector3(s, s * rng.randf_range(0.8, 1.2), s)), Vector3(x, h - 0.05, z)), _verde(rng, f) * 0.9])
				continue
			var s := rng.randf_range(0.75, 1.4)
			var base := Vector3(x, h - 0.2, z)
			if pnt > 0.5:
				grupos["morta"].append([Transform3D(giro.scaled(Vector3(s, s * 0.9, s)), base), Color.WHITE]); lista.append([base, 0.3 * s])
			elif h > 18.0 or reg.ruido.get_noise_2d(x * 0.9, z * 0.9) > 0.25:
				var t := Transform3D(giro.scaled(Vector3(s, s * rng.randf_range(1.0, 1.35), s)), base)
				grupos["pinho"].append([t, Color(0.3, 0.48, 0.3) * rng.randf_range(0.85, 1.1)]); lista.append([base, 0.26 * s])
			else:
				var t := Transform3D(giro.scaled(Vector3(s, s * rng.randf_range(0.9, 1.15), s)), base)
				grupos["copa_a" if rng.randf() < 0.5 else "copa_b"].append([t, _cor_copa(rng, x, z)]); lista.append([base, 0.32 * s])
	arvores[k] = lista
	var no := Node3D.new(); add_child(no)
	for nome in grupos.keys():
		var itens: Array = grupos[nome]
		if itens.is_empty(): continue
		var par: Array = malhas[nome]
		# copa_b usa o tronco da copa_a
		var tronco: ArrayMesh = par[0] if par[0] != null else (malhas["copa_a"][0] if nome == "copa_b" else null)
		if tronco: no.add_child(_mm(tronco, itens, false))
		if par[1]: no.add_child(_mm(par[1], itens, true))

func _mm(malha: ArrayMesh, itens: Array, cores: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_colors = cores; mm.mesh = malha
	mm.instance_count = itens.size()
	for i in itens.size():
		mm.set_instance_transform(i, itens[i][0])
		if cores: mm.set_instance_color(i, itens[i][1])
	var mi := MultiMeshInstance3D.new(); mi.multimesh = mm; mi.visibility_range_end = VISTA
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func _verde(rng: RandomNumberGenerator, f: float) -> Color:
	var tons := [Color(0.36, 0.55, 0.22), Color(0.45, 0.62, 0.25), Color(0.3, 0.48, 0.2), Color(0.5, 0.6, 0.24)]
	return tons[rng.randi() % tons.size()] * rng.randf_range(0.9, 1.1) * (1.0 - f * 0.1)

func _cor_copa(rng: RandomNumberGenerator, x: float, z: float) -> Color:
	if reg.ruido_grande.get_noise_2d(x * 3.0, z * 3.0) > 0.38:
		return [Color(0.9, 0.6, 0.22), Color(0.82, 0.4, 0.18), Color(0.92, 0.75, 0.3)][rng.randi() % 3] * rng.randf_range(0.9, 1.08)
	return _verde(rng, 0.0)

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
		elif not perto and corpos.has(k) and centro.distance_to(p) > COLIDE + 40.0:
			corpos[k].queue_free(); corpos.erase(k)

# Floresta com a técnica de "cartões" (alpha cards), a mesma usada em MMOs para ter muita árvore sem pesar:
#  - tronco simples (poucos lados, abrindo na base) com alguns galhos;
#  - a copa é feita de ~25 retângulos planos ("cartões") cruzados em ângulos diferentes, cada um com o desenho
#    de um galho com cachos de folhas (formato de folha de verdade) e fundo transparente, gerado aqui;
#  - pinheiros: andares de cartões de agulhas caídos para baixo em volta do tronco;
#  - arbustos: 5 cartões cruzados (verde, com flores/frutinhas e samambaias na mata);
#  - taboas e juncos na beira do rio e do lago (cartões altos com folhas compridas e a espiga marrom).
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
		"folhagem": _material(_tex_folhagem(192, 11)),
		"folhagem2": _material(_tex_folhagem(192, 21)),
		"agulhas": _material(_tex_agulhas(128, 80, 12)),
		"arbusto": _material(_tex_folhagem(128, 13, true)),
		"flor_a": _material(_tex_florido(17, [Color(0.95, 0.95, 0.88), Color(1.0, 0.86, 0.35)])),     # flores brancas/amarelas
		"flor_b": _material(_tex_florido(23, [Color(0.78, 0.12, 0.12), Color(0.55, 0.08, 0.15)])),    # frutinhas vermelhas
		"flor_c": _material(_tex_florido(29, [Color(0.72, 0.5, 0.88), Color(0.9, 0.62, 0.8)])),       # flores lilás
		"samambaia": _material(_tex_samambaia(96, 160, 31)),
		"junco": _material(_tex_junco(128, 192, 37)),
	}
	if OS.get_cmdline_user_args().has("--desenhos"):
		for k in _mat_cartao.keys():
			var tx: ImageTexture = _mat_cartao[k].get_shader_parameter("tex"); tx.get_image().save_png("user://cartao_%s.png" % k)
	malhas = {
		"copa_a": [_tronco_copa(), _cartoes_copa(1)],
		"copa_b": [null, _cartoes_copa(2, "folhagem2")],
		"copa_c": [null, _cartoes_copa(5)],
		"copa_d": [null, _cartoes_copa(6, "folhagem2")],
		"pinho": [_tronco_pinho(), _cartoes_pinho(3)],
		"arbusto": [null, _cartoes_arbusto(4)],
		"flor_a": [null, _cartoes_arbusto(7, "flor_a")],
		"flor_b": [null, _cartoes_arbusto(8, "flor_b")],
		"flor_c": [null, _cartoes_arbusto(9, "flor_c")],
		"samambaia": [null, _cartoes_samambaia(10)],
		"morta": [_tronco_copa(Color(0.55, 0.52, 0.48)), null],
	}
	var n := int(ceil(2.0 * Regiao.LIM / PED))
	for j in n: for i in n: _pedaco(Vector2i(i, j))
	_beira_agua()
	_jardins()

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

# galho folhoso: graveto curvo que afina e se divide (de baixo para cima), com cachos de folhas de verdade
# (formato de folha: oval com ponta, nervura clara no meio) nas pontas e ao longo dos galhos.
# Tons de cinza: a cor vem de cada árvore. Fundo transparente.
func _tex_folhagem(t: int, seed: int, redondo := false) -> ImageTexture:
	var rng := RandomNumberGenerator.new(); rng.seed = seed
	var im := Image.create(t, t, true, Image.FORMAT_RGBA8); im.fill(Color(0, 0, 0, 0))
	var pontas := []          # [posição, direção] onde nascem os cachos
	var galhos := []          # [a, b, espessura]
	var _ramo := func(rec: Callable, a: Vector2, dir: Vector2, comp: float, esp: float, nivel: int) -> void:
		var p := a; var d := dir
		var passos := 6
		for i in passos:
			d = d.rotated(rng.randf_range(-0.25, 0.25)).normalized()
			var q := p + d * comp / passos
			galhos.append([p, q, esp * (1.0 - float(i) / passos * 0.5)])
			if nivel < 3 and i >= 2 and rng.randf() < 0.45:
				var lado := 1.0 if rng.randf() < 0.5 else -1.0
				rec.call(rec, q, d.rotated(lado * rng.randf_range(0.5, 1.0)), comp * rng.randf_range(0.45, 0.65), esp * 0.6, nivel + 1)
			p = q
		pontas.append([p, d])
	if redondo:
		for k in 6: _ramo.call(_ramo, Vector2(t * 0.5, t * 0.85), Vector2(0, -1).rotated(lerp(-1.2, 1.2, k / 5.0) + rng.randf_range(-0.15, 0.15)), t * 0.36, t * 0.022, 1)
	else:
		_ramo.call(_ramo, Vector2(t * 0.5, t * 0.98), Vector2(rng.randf_range(-0.15, 0.15), -1).normalized(), t * 0.62, t * 0.035, 0)
	# gravetos (escuros)
	for g in galhos: _traco(im, g[0], g[1], max(g[2], 1.0), 0.22)
	# folhas: muitas nas pontas (cachos) e algumas ao longo dos galhos
	var folhas := []
	for pt in pontas:
		var c: Vector2 = pt[0]
		for k in 30:
			var o := Vector2(rng.randfn(0, 1), rng.randfn(0, 1)) * t * 0.065
			folhas.append([c + o, rng.randf() * TAU, -o.y / (t * 0.065)])
	for g in galhos:
		if rng.randf() < 0.5:
			var p: Vector2 = g[0].lerp(g[1], rng.randf())
			folhas.append([p + Vector2(rng.randfn(0, 1), rng.randfn(0, 1)) * t * 0.02, rng.randf() * TAU, 0.0])
	# as de baixo/escuras primeiro, as de cima (claras) por cima
	folhas.sort_custom(func(a, b): return a[2] < b[2])
	for f in folhas:
		var p: Vector2 = f[0]
		var l: float = 0.55 + 0.35 * (1.0 - p.y / t) + 0.14 * clampf(f[2], -1.0, 1.0) + rng.randf_range(-0.08, 0.08)
		_folha(im, p, f[1], t * rng.randf_range(0.045, 0.065), t * rng.randf_range(0.018, 0.026), clampf(l, 0.32, 1.1))
	im.generate_mipmaps()
	return ImageTexture.create_from_image(im)

# graveto: traço com espessura
func _traco(im: Image, a: Vector2, b: Vector2, esp: float, l: float) -> void:
	var n := int(a.distance_to(b)) + 1
	var r := esp * 0.5
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		for dy in range(int(-r) - 1, int(r) + 2):
			for dx in range(int(-r) - 1, int(r) + 2):
				if dx * dx + dy * dy <= r * r + 0.5:
					var x := int(p.x) + dx; var y := int(p.y) + dy
					if x >= 0 and y >= 0 and x < im.get_width() and y < im.get_height(): im.set_pixel(x, y, Color(l, l, l, 1))

# uma folha: oval com as duas pontas finas (formato de folha), metade de um lado um tom mais clara (nervura)
func _folha(im: Image, c: Vector2, ang: float, comp: float, larg: float, l: float) -> void:
	var d := Vector2(cos(ang), sin(ang)); var n := Vector2(-d.y, d.x)
	var r := int(comp) + 1
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var q := Vector2(dx, dy)
			var u := q.dot(d) / comp; var v := q.dot(n)
			if abs(u) > 1.0: continue
			var meia: float = larg * sqrt(max(0.0, 1.0 - u * u)) * (1.0 - 0.35 * max(u, 0.0))   # mais fina na ponta
			if abs(v) > meia: continue
			var x := int(c.x) + dx; var y := int(c.y) + dy
			if x < 0 or y < 0 or x >= im.get_width() or y >= im.get_height(): continue
			var tom := l * (1.08 if v > 0.0 else 0.9)
			if abs(v) < 0.6 and u > -0.8: tom = l * 1.15                                     # nervura
			im.set_pixel(x, y, Color(tom, tom, tom, 1))

# galho de pinheiro visto de cima: graveto no meio (esquerda = tronco) e agulhas para os lados
func _tex_agulhas(w: int, h: int, seed: int) -> ImageTexture:
	var rng := RandomNumberGenerator.new(); rng.seed = seed
	var im := Image.create(w, h, true, Image.FORMAT_RGBA8); im.fill(Color(0, 0, 0, 0))
	# raminhos laterais saindo do galho central, cada um coberto de agulhas apontando para a frente
	for r in 34:
		var u := float(r) / 34.0
		var x := u * (w - 6)
		var larg := h * 0.5 * (1.0 - u * 0.7)
		for lado in [-1.0, 1.0]:
			var a := Vector2(x, h * 0.5)
			var b := a + Vector2(larg * 0.75, lado * larg * 0.95)
			for i in 18:
				var q := a.lerp(b, i / 18.0)
				var comp := rng.randf_range(5.0, 9.0)
				var dir := (b - a).normalized().rotated(lado * rng.randf_range(-0.7, 0.2))
				var l := clampf(0.6 + rng.randf_range(-0.12, 0.25) + (0.18 if lado < 0 else -0.05) + (1.0 - u) * -0.08, 0.35, 1.1)
				_linha(im, q, q + dir * comp, l, 2)
	_linha(im, Vector2(0, h * 0.5), Vector2(w - 6, h * 0.5), 0.28, 2)
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

func _cartoes_copa(seed: int, tex := "folhagem") -> ArrayMesh:
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
		var tam := rng.randf_range(0.65, 1.0) if rng.randf() < 0.4 else (rng.randf_range(1.0, 1.5) if rng.randf() < 0.7 else rng.randf_range(1.5, 2.0))
		var tom := clampf(0.72 + 0.3 * ((p.y - centro.y) / 1.35 * 0.5 + 0.5) + fora.length() * 0.0, 0.6, 1.08)
		_cartao(st, p, lado, cima, Vector2(tam, tam), tom)
		# cruzado: o mesmo lugar, girado 90° em volta do "cima" (vê-se cheio de qualquer lado)
		if rng.randf() < 0.55: _cartao(st, p, lado.rotated(cima, PI / 2), cima, Vector2(tam, tam) * 0.9, tom * 0.92)
	var mesh := ArrayMesh.new(); st.set_material(_mat_cartao[tex]); st.commit(mesh)
	return mesh

func _tronco_pinho() -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	m.cilindro(st, Vector3(0, -0.4, 0), 0.42, 0.24, 0.9, 6)
	m.cilindro(st, Vector3(0, 0.5, 0), 0.24, 0.05, 7.8, 6)
	var mesh := ArrayMesh.new(); st.set_material(m.mat("casca")); st.commit(mesh)
	return mesh

# pinheiro: andares de galhos em volta do tronco; cada galho é um cartão dobrado em "telhado" (as duas metades
# caem para os lados) e curvado para baixo (a ponta cai mais que a base), como galho de pinheiro pesado.
func _cartoes_pinho(seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new(); rng.seed = seed
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var andares := 11
	for a in andares:
		var t := float(a) / (andares - 1)
		var y: float = lerp(1.6, 7.6, t) + rng.randf_range(-0.12, 0.12)
		var comp: float = lerp(2.7, 0.55, pow(t, 0.9)) * rng.randf_range(0.9, 1.1)
		var n := 7 if t < 0.5 else (6 if t < 0.8 else 4)
		var giro := rng.randf() * TAU
		for k in n:
			var ang := giro + TAU * k / n + rng.randf_range(-0.25, 0.25)
			var fora := Vector3(cos(ang), 0, sin(ang))
			var lado := fora.cross(Vector3.UP).normalized()
			var desce := deg_to_rad(rng.randf_range(12, 24) + t * 8.0)       # o galho sai inclinado para baixo
			var tom: float = lerp(0.7, 1.02, t) * rng.randf_range(0.9, 1.06)
			_galho_pinho(st, Vector3(0, y, 0), fora, lado, desce, comp, comp * 0.42, tom)
	# ponta: dois cartões em pé, cruzados
	for k in 2:
		var lado := Vector3(cos(k * PI / 2), 0, sin(k * PI / 2))
		_cartao(st, Vector3(0, 8.1, 0), Vector3.UP, lado, Vector2(0.75, 0.25), 1.05)
	var mesh := ArrayMesh.new(); st.set_material(_mat_cartao["agulhas"]); st.commit(mesh)
	return mesh

func _galho_pinho(st: SurfaceTool, base: Vector3, fora: Vector3, lado: Vector3, desce: float, comp: float, larg: float, tom: float) -> void:
	# 3 pontos ao longo do galho; a ponta cai mais (curva); as bordas laterais ficam mais baixas (telhado)
	var meio := []
	for i in 3:
		var u := i / 2.0
		var d := fora * comp * u
		var queda := comp * u * tan(desce) + comp * 0.22 * u * u           # curva para baixo
		meio.append(base + d - Vector3(0, queda, 0))
	for i in 2:
		var u0 := i / 2.0; var u1 := (i + 1) / 2.0
		var c0: Vector3 = meio[i]; var c1: Vector3 = meio[i + 1]
		var w0 := larg * (1.0 - u0 * 0.55); var w1 := larg * (1.0 - u1 * 0.55)
		var cai0 := Vector3(0, -w0 * 0.55, 0); var cai1 := Vector3(0, -w1 * 0.55, 0)
		for lad in [-1.0, 1.0]:
			var e0: Vector3 = c0 + lado * w0 * lad + cai0; var e1: Vector3 = c1 + lado * w1 * lad + cai1
			var v := 0.0 if lad < 0 else 1.0
			var vs := [c0, c1, e1, e0]
			var uvs := [Vector2(u0, 0.5), Vector2(u1, 0.5), Vector2(u1, v), Vector2(u0, v)]
			var n := (c1 - c0).cross(e0 - c0).normalized()
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_normal(n); st.set_color(Color(tom, tom, tom)); st.set_uv(uvs[k]); st.add_vertex(vs[k])

func _cartoes_arbusto(seed: int, mat := "arbusto") -> ArrayMesh:
	var rng := RandomNumberGenerator.new(); rng.seed = seed
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 5:
		var ang := TAU * k / 5.0 + rng.randf_range(-0.2, 0.2)
		var lado := Vector3(cos(ang), 0, sin(ang))
		var cima := Vector3(0, 1, 0).rotated(lado, rng.randf_range(-0.35, 0.35))
		_cartao(st, Vector3(0, 0.5, 0), lado, cima, Vector2(0.75, 0.62), rng.randf_range(0.85, 1.05))
	_cartao(st, Vector3(0, 0.75, 0), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector2(0.6, 0.6), 1.05)   # tampa de cima
	var mesh := ArrayMesh.new(); st.set_material(_mat_cartao[mat]); st.commit(mesh)
	return mesh

# samambaia: 7 folhas (frondes) saindo do centro e caindo para fora
func _cartoes_samambaia(seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new(); rng.seed = seed
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 7:
		var ang := TAU * k / 7.0 + rng.randf_range(-0.25, 0.25)
		var fora := Vector3(cos(ang), 0, sin(ang))
		var sobe := (fora * rng.randf_range(0.6, 1.0) + Vector3.UP).normalized()
		_cartao(st, fora * 0.3 + Vector3(0, 0.36, 0), fora.cross(Vector3.UP), sobe, Vector2(0.24, 0.45), rng.randf_range(0.85, 1.05))
	var mesh := ArrayMesh.new(); st.set_material(_mat_cartao["samambaia"]); st.commit(mesh)
	return mesh

# touceira de taboa/junco: 4 cartões altos cruzados (1,6 m)
func _cartoes_junco(seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new(); rng.seed = seed
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 4:
		var ang := PI * k / 4.0 + rng.randf_range(-0.2, 0.2)
		var lado := Vector3(cos(ang), 0, sin(ang))
		_cartao(st, Vector3(rng.randf_range(-0.15, 0.15), 0.8, rng.randf_range(-0.15, 0.15)), lado, Vector3.UP, Vector2(0.55, 0.8), 1.0)
	var mesh := ArrayMesh.new(); st.set_material(_mat_cartao["junco"]); st.commit(mesh)
	return mesh

# ---------- desenhos novos (estes já vêm coloridos: a cor da instância só varia o tom) ----------
func _pix(im: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < im.get_width() and y < im.get_height(): im.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))

# arbusto com flores ou frutinhas: a folhagem redonda pintada de verde + pontinhos coloridos por cima
func _tex_florido(seed: int, cores: Array) -> ImageTexture:
	var base: Image = _tex_folhagem(128, seed, true).get_image()
	var im := Image.create(128, 128, true, Image.FORMAT_RGBA8); im.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new(); rng.seed = seed * 7
	for y in 128:
		for x in 128:
			var c := base.get_pixel(x, y)
			if c.a > 0.5: im.set_pixel(x, y, Color(c.r * 0.42, c.r * 0.62, c.r * 0.24, 1.0))
	for k in 160:
		var x := rng.randi_range(4, 122); var y := rng.randi_range(4, 105)
		if base.get_pixel(x, y).a < 0.5: continue
		var c: Color = cores[rng.randi() % cores.size()] * rng.randf_range(0.85, 1.1)
		for dy in 3: for dx in 3: if not (dx != 1 and dy != 1): _pix(im, x + dx, y + dy, c * (0.8 if dy == 2 else 1.0))
	im.generate_mipmaps()
	return ImageTexture.create_from_image(im)

# fronde de samambaia (em pé no cartão): talo do meio curvado e folhinhas dos dois lados, menores na ponta
func _tex_samambaia(w: int, h: int, seed: int) -> ImageTexture:
	var rng := RandomNumberGenerator.new(); rng.seed = seed
	var im := Image.create(w, h, true, Image.FORMAT_RGBA8); im.fill(Color(0, 0, 0, 0))
	var pts := []
	for i in 41:
		var u := i / 40.0
		pts.append(Vector2(w * 0.5 + sin(u * 2.2) * w * 0.12, h * (0.98 - u * 0.94)))
	for i in range(2, pts.size() - 1):
		var u := float(i) / pts.size()
		var p: Vector2 = pts[i]; var d: Vector2 = (pts[i + 1] - p).normalized()
		var comp := w * 0.36 * (1.0 - u) * (0.6 + 0.4 * sin(u * PI)) + 3.0
		for lado in [-1.0, 1.0]:
			if i % 2 == 0:
				var dir := d.rotated(lado * 1.15)
				_folha(im, p + dir * comp * 0.5, dir.angle(), comp * 0.5, 2.6, 0.62 + 0.3 * u + rng.randf_range(-0.06, 0.06))
	for i in pts.size() - 1: _traco(im, pts[i], pts[i + 1], 2.0, 0.45)
	im.generate_mipmaps()
	return ImageTexture.create_from_image(im)

# taboas e juncos: folhas compridas e finas que curvam no alto, algumas com a espiga marrom
func _tex_junco(w: int, h: int, seed: int) -> ImageTexture:
	var rng := RandomNumberGenerator.new(); rng.seed = seed
	var im := Image.create(w, h, true, Image.FORMAT_RGBA8); im.fill(Color(0, 0, 0, 0))
	for i in 30:
		var x0 := rng.randf_range(6, w - 6); var topo := rng.randf_range(h * 0.08, h * 0.5)
		var curva := rng.randf_range(-16, 16)
		var cor := Color(0.32, 0.52, 0.2).lerp(Color(0.6, 0.66, 0.3), rng.randf()) * rng.randf_range(0.8, 1.1)
		var larg := rng.randi_range(2, 3)
		for y in range(int(topo), h):
			var u := (y - topo) / (h - topo)
			var x := x0 + curva * pow(1.0 - u, 2.0)
			var ww: int = max(1, int(larg * (0.35 + u * 0.65) + 0.5))
			for dx in ww: _pix(im, int(x) + dx, y, cor * (0.75 + 0.3 * (1.0 - u)) * (1.1 if dx == 0 else 0.9))
	for i in 6:                                   # taboas: talo reto e a espiga marrom
		var x := int(rng.randf_range(10, w - 10)); var topo := int(rng.randf_range(h * 0.04, h * 0.2))
		for y in range(topo, h): _pix(im, x, y, Color(0.34, 0.46, 0.2))
		for y in range(topo - 6, topo): _pix(im, x, y, Color(0.5, 0.45, 0.3))
		for y in range(topo + 3, topo + 19):
			for dx in range(-2, 3): _pix(im, x + dx, y, Color(0.42, 0.26, 0.14) * (1.15 if dx < 0 else 0.85))
	im.generate_mipmaps()
	return ImageTexture.create_from_image(im)

# ---------- beira d'água: taboas e juncos em touceiras ao longo do rio e em volta do lago ----------
func _beira_agua() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 555
	var junco := _cartoes_junco(41)
	var por_ped := {}                 # Vector2i → itens
	var pontos := []                  # [posição, meia largura da água]
	for i in reg.rio.size() - 1:
		var a: Vector2 = reg.rio[i]; var b: Vector2 = reg.rio[i + 1]
		var n := int(a.distance_to(b) / 1.3)
		for k in n:
			var u := float(k) / n; var p := a.lerp(b, u)
			var t := (float(i) + u) / (reg.rio.size() - 1)
			var nrm := Vector2(-(b - a).normalized().y, (b - a).normalized().x)
			for lado in [-1.0, 1.0]: pontos.append([p, nrm * lado, reg.largura_rio(t) * 0.5])
	var lc := Vector2(Regiao.LAGO.x, Regiao.LAGO.y)
	for k in 300:
		var a := TAU * k / 300.0; var d := Vector2(cos(a), sin(a))
		pontos.append([lc, d, Regiao.LAGO.z])
		pontos.append([lc, d, Regiao.ILHA.z + 1.0])       # beira da ilha também
	for pt in pontos:
		var c: Vector2 = pt[0]; var d: Vector2 = pt[1]; var meia: float = pt[2]
		# touceiras com falhas (ruído): umas partes cheias, outras com margem limpa
		var q0 := c + d * meia
		if reg.ruido.get_noise_2d(q0.x * 1.7, q0.y * 1.7) < -0.12 or rng.randf() < 0.25: continue
		for e in rng.randi_range(1, 2):
			var q := c + d * (meia + rng.randf_range(-0.3, 2.2)) + Vector2(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.6, 0.6))
			if reg.dist_estrada(q.x, q.y) < 5.0 or m.perto_de_lugar(q.x, q.y, 1.0) or not reg.dentro(q.x, q.y): continue
			var h := reg.altura(q.x, q.y)
			var s := rng.randf_range(0.7, 1.25)
			var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.85, 1.2), s)), Vector3(q.x, h - 0.1, q.y))
			var kk := Vector2i(int((q.x + Regiao.LIM) / PED), int((q.y + Regiao.LIM) / PED))
			if not por_ped.has(kk): por_ped[kk] = []
			por_ped[kk].append([t, Color(1, 1, 1) * rng.randf_range(0.85, 1.08)])
	for kk in por_ped.keys():
		var mi := _mm(junco, por_ped[kk], true); mi.visibility_range_end = 200.0; add_child(mi)

# arbustos floridos e moitas perto das casas (jardins), sem encostar na rua
func _jardins() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 808
	var itens := {"flor_a": [], "flor_b": [], "flor_c": [], "arbusto": []}
	for c in m.casas:
		if rng.randf() < 0.35: continue
		var p: Vector3 = c[0]; var ang: float = c[1]; var w: float = c[2]; var dd: float = c[3]
		for k in rng.randi_range(1, 3):
			var lado := 1.0 if rng.randf() < 0.5 else -1.0
			var loc := Vector2(lado * (w * 0.5 + rng.randf_range(0.7, 1.2)), rng.randf_range(-dd * 0.45, dd * 0.45))
			if rng.randf() < 0.4: loc = Vector2(rng.randf_range(-w * 0.45, w * 0.45), -(dd * 0.5 + rng.randf_range(0.7, 1.1)))   # fundos
			var q := Vector2(p.x, p.z) + loc.rotated(-ang)
			if reg.folga_caminho(q.x, q.y) < 0.6 or m.perto_de_casa(q.x, q.y, 0.3): continue
			var nome: String = ["flor_a", "flor_b", "flor_c", "arbusto"][rng.randi() % 4]
			var s := rng.randf_range(0.95, 1.4)
			var cor := Color(1, 1, 1) * rng.randf_range(0.9, 1.08) if nome != "arbusto" else _verde(rng, 0.0)
			itens[nome].append([Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(q.x, reg.altura(q.x, q.y) - 0.05, q.y)), cor])
	for nome in itens.keys():
		if not itens[nome].is_empty(): add_child(_mm(malhas[nome][1], itens[nome], true))

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
				if rng.randf() < 0.08 + smoothstep(0.1, 0.5, f) * 0.35: arbusto = true
				else: continue
			if not reg.dentro(x, z) or reg.dist_estrada(x, z) < (3.0 if arbusto else 5.0) or Vector2(x, z).length() < (30.0 if arbusto else 45.0): continue
			if reg.campo_em(x, z) >= 0 or reg.dist_rio(x, z) < (9.0 if arbusto else 12.0): continue
			if Vector2(x - Regiao.LAGO.x, z - Regiao.LAGO.y).length() < Regiao.LAGO.z + 6.0: continue
			var h := reg.altura(x, z)
			if h > 36.0 or h < 0.6 or (x > 380.0 and h < 2.5): continue
			if m.perto_de_lugar(x, z, 4.0 if arbusto else 8.0): continue
			var giro := Basis(Vector3.UP, rng.randf() * TAU)
			if arbusto:
				var s := rng.randf_range(0.95, 1.8)
				var tipo := "arbusto"; var cor := _verde(rng, f) * 0.9
				var r := rng.randf()
				if f > 0.45 and r < 0.45: tipo = "samambaia"; s *= 1.1
				elif r < 0.2: tipo = ["flor_a", "flor_b", "flor_c"][rng.randi() % 3]; cor = Color(1, 1, 1) * rng.randf_range(0.88, 1.06)
				grupos[tipo].append([Transform3D(giro.scaled(Vector3(s, s * rng.randf_range(0.8, 1.2), s)), Vector3(x, h - 0.05, z)), cor])
				continue
			var sorteio := rng.randf()
			var s := rng.randf_range(0.42, 0.65) if sorteio < 0.15 else (rng.randf_range(0.7, 1.25) if sorteio < 0.8 else rng.randf_range(1.4, 2.1))
			var base := Vector3(x, h - 0.2, z)
			if pnt > 0.5:
				grupos["morta"].append([Transform3D(giro.scaled(Vector3(s, s * 0.9, s)), base), Color.WHITE]); lista.append([base, 0.3 * s])
			elif h > 18.0 or reg.ruido.get_noise_2d(x * 0.9, z * 0.9) > 0.25:
				var t := Transform3D(giro.scaled(Vector3(s, s * rng.randf_range(1.0, 1.35), s)), base)
				grupos["pinho"].append([t, Color(0.3, 0.48, 0.3) * rng.randf_range(0.85, 1.1)]); lista.append([base, 0.26 * s])
			else:
				var larg := s * rng.randf_range(0.85, 1.2)          # umas mais largas, outras mais altas
				var t := Transform3D(giro.scaled(Vector3(larg, s * rng.randf_range(0.85, 1.2), larg)), base)
				grupos[["copa_a", "copa_b", "copa_c", "copa_d"][rng.randi() % 4]].append([t, _cor_copa(rng, x, z)]); lista.append([base, 0.32 * s])
	arvores[k] = lista
	var no := Node3D.new(); add_child(no)
	for nome in grupos.keys():
		var itens: Array = grupos[nome]
		if itens.is_empty(): continue
		var par: Array = malhas[nome]
		# copa_b usa o tronco da copa_a
		var tronco: ArrayMesh = par[0] if par[0] != null else (malhas["copa_a"][0] if nome.begins_with("copa") else null)
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

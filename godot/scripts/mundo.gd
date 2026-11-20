# Dallarian — primeira cena: um vale com uma vila, visto em primeira pessoa.
# Visual: PS1 pintado (shaders/ps1.gdshader) + pixel splats (shaders/splat.gdshader) para grama e copas,
# desenhado numa imagem de resolução baixa e ampliada sem suavizar, com paleta reduzida e pontilhado.
# Tudo é gerado por código (terreno, casas, árvores, grama) até chegarem os modelos do Tripo.
extends Node

const TAM := 260.0          # lado do terreno (m)
const CEL := 100            # quadrados do terreno por lado
const REDUCAO := 4          # a imagem 3D é desenhada em 1/4 da resolução da tela
const NEBLINA := Color(0.74, 0.83, 0.94)
const TEMPESTADE := false     # céu limpo; true = relâmpagos (clima de tempestade)

var vp: SubViewport
var raiz: Node3D
var jogador: Jogador
var controles: Controles
var estrada: PackedVector2Array = PackedVector2Array([
	Vector2(6, 92), Vector2(10, 74), Vector2(2, 58), Vector2(-8, 44), Vector2(-4, 30), Vector2(2, 18), Vector2(0, 6)])
var casas := [] # [pos, ang, w, d]
var args := {}
var _mats := {}
var _hs: PackedFloat32Array   # alturas da malha do terreno (para pôr coisas exatamente no chão)

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var p := a.trim_prefix("--").split("=")
		args[p[0]] = p[1] if p.size() > 1 else "1"
	_tela()
	_ambiente()
	_terreno()
	_vila()
	var chao := ChaoSplat.new(); raiz.add_child(chao); chao.montar(self)
	_arvores()
	_grama()
	jogador = Jogador.new(); raiz.add_child(jogador)
	jogador.position = Vector3(10, altura(10, 74) + 0.2, 74)
	jogador.rotation.y = deg_to_rad(8)
	controles = Controles.new(); var cl := CanvasLayer.new(); add_child(cl); cl.add_child(controles)
	jogador.controles = controles
	if args.has("shot"): _modo_teste()

# ---------- tela: 3D em resolução baixa + filtro de paleta ----------
func _tela() -> void:
	var cont := SubViewportContainer.new()
	cont.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cont.stretch = true; cont.stretch_shrink = REDUCAO
	cont.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new(); sm.shader = load("res://shaders/tela.gdshader"); cont.material = sm
	add_child(cont)
	vp = SubViewport.new(); vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	cont.add_child(vp)
	raiz = Node3D.new(); vp.add_child(raiz)

func _ambiente() -> void:
	var we := WorldEnvironment.new(); var env := Environment.new()
	var sky := Sky.new(); var sm := ShaderMaterial.new(); sm.shader = load("res://shaders/ceu.gdshader"); sky.sky_material = sm
	env.background_mode = Environment.BG_SKY; env.sky = sky
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	we.environment = env; raiz.add_child(we)

# relâmpagos de vez em quando (clarão em tudo pelo parâmetro global "relampago")
var _prox_raio := 4.0
var _raio := 0.0
func _process(delta: float) -> void:
	if not TEMPESTADE and not args.has("raio"): return
	_prox_raio -= delta
	if _prox_raio <= 0.0:
		_prox_raio = randf_range(7.0, 16.0); _raio = 1.0
	if _raio > 0.0:
		_raio = max(0.0, _raio - delta * 2.2)
		var v: float = _raio * (0.6 + 0.4 * float(int(_raio * 14.0) % 2))    # pisca
		RenderingServer.global_shader_parameter_set("relampago", v)

# ---------- material PS1 ----------
func mat(textura: String, escala := 1.0, cor := Color.WHITE) -> ShaderMaterial:
	var k := "%s|%s|%s" % [textura, escala, cor]
	if _mats.has(k): return _mats[k]
	var m := ShaderMaterial.new(); m.shader = load("res://shaders/ps1.gdshader")
	if textura == "": m.set_shader_parameter("usa_tex", false)
	else: m.set_shader_parameter("tex", Texturas.pegar(textura))
	m.set_shader_parameter("escala_uv", escala); m.set_shader_parameter("cor", cor)
	m.set_shader_parameter("neblina", NEBLINA)
	_mats[k] = m; return m

# modelo GLB (do Tripo) com o material PS1: mesma luz por vértice, textura sem suavização e neblina do mundo
func modelo_ps1(caminho: String) -> Node3D:
	var no: Node3D = load(caminho).instantiate()
	for n in no.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n
		for i in mi.mesh.get_surface_count():
			var orig: BaseMaterial3D = mi.mesh.surface_get_material(i)
			var sm := ShaderMaterial.new(); sm.shader = load("res://shaders/ps1.gdshader")
			if orig and orig.albedo_texture: sm.set_shader_parameter("tex", orig.albedo_texture)
			else: sm.set_shader_parameter("usa_tex", false)
			sm.set_shader_parameter("neblina", NEBLINA)
			mi.set_surface_override_material(i, sm)
	return no

# ---------- terreno ----------
var _ruido := FastNoiseLite.new()
func altura(x: float, z: float) -> float:
	var r := Vector2(x, z).length()
	var h := 0.0016 * r * r + _ruido.get_noise_2d(x, z) * 5.0
	if r > 108.0: h += pow(r - 108.0, 1.5) * 0.3 * (0.7 + 0.6 * (_ruido.get_noise_2d(x * 0.4, z * 0.4) + 0.5))   # montanhas em volta
	h = lerp(0.6, h, smoothstep(16.0, 30.0, r))                    # praça da vila plana
	var de := _dist_estrada(Vector2(x, z))
	h -= (1.0 - smoothstep(1.5, 4.0, de)) * 0.35                   # estrada um pouco afundada
	return h

func _dist_estrada(p: Vector2) -> float:
	var d := 1e9
	for i in estrada.size() - 1:
		d = min(d, Geometry2D.get_closest_point_to_segment(p, estrada[i], estrada[i + 1]).distance_to(p))
	return d

func cor_chao(x: float, z: float, h: float, ny: float) -> Color:
	var n := _ruido.get_noise_2d(x * 0.7 + 100.0, z * 0.7)
	var campo := Color(0.8, 0.66, 0.32)            # trigo dourado
	var grama := Color(0.45, 0.56, 0.27)
	var c := grama.lerp(campo, smoothstep(-0.1, 0.25, n))
	var de := _dist_estrada(Vector2(x, z))
	var r := Vector2(x, z).length()
	if de < 2.6 or r < 17.0: c = Color(0.52, 0.38, 0.24) * (0.95 + n * 0.1)   # terra batida
	if ny < 0.8: c = c.lerp(Color(0.46, 0.5, 0.6), smoothstep(0.8, 0.65, ny))  # encosta de pedra (azulada)
	if h > 34.0: c = c.lerp(Color(0.86, 0.9, 0.98), smoothstep(34.0, 40.0, h)) # neve no alto
	return c

func _terreno() -> void:
	_ruido.seed = 11; _ruido.frequency = 0.018; _ruido.fractal_octaves = 3
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var passo := TAM / CEL; var meio := TAM / 2.0
	var hs := PackedFloat32Array(); hs.resize((CEL + 1) * (CEL + 1))
	for j in CEL + 1: for i in CEL + 1:
		hs[j * (CEL + 1) + i] = altura(i * passo - meio, j * passo - meio)
	_hs = hs
	var pos := func(i: int, j: int) -> Vector3: return Vector3(i * passo - meio, hs[j * (CEL + 1) + i], j * passo - meio)
	for j in CEL: for i in CEL:
		var a: Vector3 = pos.call(i, j); var b: Vector3 = pos.call(i + 1, j)
		var c: Vector3 = pos.call(i + 1, j + 1); var d: Vector3 = pos.call(i, j + 1)
		for tri in [[a, c, b], [a, d, c]]:
			var nrm: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0]).normalized()
			if nrm.y < 0: nrm = -nrm
			for v in tri:
				st.set_normal(nrm)
				st.set_color(cor_chao(v.x, v.z, v.y, nrm.y))
				st.set_uv(Vector2(v.x, v.z) / 4.0)
				st.add_vertex(v)
	var mi := MeshInstance3D.new(); mi.mesh = st.commit(); mi.material_override = mat("terreno")
	raiz.add_child(mi)
	# colisão: a própria malha do terreno
	var corpo := StaticBody3D.new(); var cs := CollisionShape3D.new(); var forma: ConcavePolygonShape3D = mi.mesh.create_trimesh_shape()
	forma.backface_collision = true; cs.shape = forma
	corpo.add_child(cs); raiz.add_child(corpo)

# altura e normal exatas da malha do terreno (triângulos), para os splats encostarem no chão
func altura_malha(x: float, z: float) -> float:
	var passo := TAM / CEL; var fx := (x + TAM / 2.0) / passo; var fz := (z + TAM / 2.0) / passo
	var i := clampi(int(floor(fx)), 0, CEL - 1); var j := clampi(int(floor(fz)), 0, CEL - 1)
	var u := clampf(fx - i, 0.0, 1.0); var v := clampf(fz - j, 0.0, 1.0)
	var ha := _hs[j * (CEL + 1) + i]; var hb := _hs[j * (CEL + 1) + i + 1]
	var hc := _hs[(j + 1) * (CEL + 1) + i + 1]; var hd := _hs[(j + 1) * (CEL + 1) + i]
	if u > v: return ha + (hb - ha) * u + (hc - hb) * v
	return ha + (hd - ha) * v + (hc - hd) * u

func normal_malha(x: float, z: float) -> Vector3:
	var e := 0.5
	var dx := altura_malha(x + e, z) - altura_malha(x - e, z)
	var dz := altura_malha(x, z + e) - altura_malha(x, z - e)
	return Vector3(-dx, 2.0 * e, -dz).normalized()

# ---------- vila ----------
func _vila() -> void:
	var lugares := [[-13, -8], [-15, 6], [-6, -16], [8, -15], [15, -5], [14, 9], [-4, 15]]
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	for l in lugares:
		var p := Vector2(l[0], l[1])
		var ang := atan2(-p.x, -p.y)                     # porta virada para a praça
		_casa(Vector3(p.x, altura(p.x, p.y) - 0.2, p.y), ang, rng.randf_range(4.5, 6.5), rng.randf_range(4.0, 5.0), rng.randf_range(2.6, 3.2))
	_poco(Vector3(0, altura(0, 0), 0))
	# a Dallarian (modelo do Tripo, 2.500 triângulos) em pé na praça, para ver como fica no mundo.
	# No arquivo: 0,98 m de altura, de frente para +X, pés em y = -0,49 → 1,75 m, virada para a estrada.
	var her := modelo_ps1("res://assets/modelos/dallarian.glb")
	var k := 1.75 / 0.979
	her.scale = Vector3(k, k, k); her.rotation_degrees.y = -90
	her.position = Vector3(3.0, altura(3.0, 6.0) + 0.489 * k, 6.0)
	raiz.add_child(her); _colisor_cilindro(Vector3(3.0, altura(3.0, 6.0), 6.0), 0.3, 1.75)
	for b in [[3.5, 2.0], [4.2, 2.6], [-3.0, 3.6], [6.0, -9.0]]:
		_barril(Vector3(b[0], altura(b[0], b[1]), b[1]))

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, uw: float, vh: float) -> void:
	var n := (b - a).cross(d - a).normalized()
	var uvs := [Vector2(0, vh), Vector2(uw, vh), Vector2(uw, 0), Vector2(0, 0)]
	var vs := [a, b, c, d]
	for k in [0, 1, 2, 0, 2, 3]:
		st.set_normal(n); st.set_color(Color.WHITE); st.set_uv(uvs[k]); st.add_vertex(vs[k])

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, uw: float, vh: float) -> void:
	var n := (b - a).cross(c - a).normalized()
	for k in 3:
		st.set_normal(n); st.set_color(Color.WHITE)
		st.set_uv([Vector2(0, vh), Vector2(uw, vh), Vector2(uw * 0.5, 0)][k]); st.add_vertex([a, b, c][k])

func _casa(pos: Vector3, ang: float, w: float, d: float, h: float) -> void:
	var x := w / 2.0; var z := d / 2.0; var cume := h + w * 0.55; var beiral := 0.45
	var mesh := ArrayMesh.new()
	# paredes (com as empenas triangulares) — textura enxaimel a cada 2 m
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var p := [Vector3(-x, 0, z), Vector3(x, 0, z), Vector3(x, 0, -z), Vector3(-x, 0, -z)]
	for k in 4:
		var a: Vector3 = p[k]; var b: Vector3 = p[(k + 1) % 4]
		_quad(st, a, b, b + Vector3(0, h, 0), a + Vector3(0, h, 0), a.distance_to(b) / 2.0, h / 2.0)
	_tri(st, Vector3(x, h, z), Vector3(x, h, -z), Vector3(x, cume, 0), d / 2.0, (cume - h) / 2.0)
	_tri(st, Vector3(-x, h, -z), Vector3(-x, h, z), Vector3(-x, cume, 0), d / 2.0, (cume - h) / 2.0)
	st.set_material(mat("parede")); st.commit(mesh)
	# telhado de palha (duas águas, com beiral)
	st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var xe := x + beiral; var ze := z + beiral; var hb := h - beiral * 0.5
	_quad(st, Vector3(-xe, hb, ze), Vector3(xe, hb, ze), Vector3(xe, cume, 0), Vector3(-xe, cume, 0), w / 2.0, 2.0)
	_quad(st, Vector3(xe, hb, -ze), Vector3(-xe, hb, -ze), Vector3(-xe, cume, 0), Vector3(xe, cume, 0), w / 2.0, 2.0)
	st.set_material(mat("palha")); st.commit(mesh)
	# base de pedra, porta e chaminé
	st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var e := 0.06
	for k in 4:
		var a: Vector3 = p[k] * Vector3(1 + e / x, 1, 1 + e / z); var b: Vector3 = p[(k + 1) % 4] * Vector3(1 + e / x, 1, 1 + e / z)
		_quad(st, a + Vector3(0, -0.4, 0), b + Vector3(0, -0.4, 0), b + Vector3(0, 0.6, 0), a + Vector3(0, 0.6, 0), a.distance_to(b) / 2.0, 0.5)
	_caixa(st, Vector3(x * 0.45, cume - 0.6, -z * 0.3), Vector3(0.7, 2.2, 0.7))
	st.set_material(mat("pedra")); st.commit(mesh)
	st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_quad(st, Vector3(-0.55, 0.0, z + 0.08), Vector3(0.55, 0.0, z + 0.08), Vector3(0.55, 2.0, z + 0.08), Vector3(-0.55, 2.0, z + 0.08), 1.0, 1.4)
	for jx in [-x * 0.6, x * 0.6]:
		_quad(st, Vector3(jx - 0.4, 1.2, z + 0.08), Vector3(jx + 0.4, 1.2, z + 0.08), Vector3(jx + 0.4, 1.9, z + 0.08), Vector3(jx - 0.4, 1.9, z + 0.08), 0.6, 0.5)
	st.set_material(mat("madeira", 1.0, Color(0.55, 0.5, 0.5))); st.commit(mesh)
	var mi := MeshInstance3D.new(); mi.mesh = mesh; mi.position = pos; mi.rotation.y = ang; raiz.add_child(mi)
	# colisão: caixa das paredes
	var corpo := StaticBody3D.new(); var cs := CollisionShape3D.new(); var bx := BoxShape3D.new()
	bx.size = Vector3(w, h + 2.0, d); cs.shape = bx; cs.position = Vector3(0, (h + 2.0) / 2.0, 0)
	corpo.add_child(cs); corpo.position = pos; corpo.rotation.y = ang; raiz.add_child(corpo)
	casas.append([pos, ang, w, d])

func _caixa(st: SurfaceTool, c: Vector3, s: Vector3) -> void:
	var h := s / 2.0
	var v := func(a: float, b: float, cc: float) -> Vector3: return c + Vector3(a * h.x, b * h.y, cc * h.z)
	_quad(st, v.call(-1, -1, 1), v.call(1, -1, 1), v.call(1, 1, 1), v.call(-1, 1, 1), s.x / 2, s.y / 2)
	_quad(st, v.call(1, -1, -1), v.call(-1, -1, -1), v.call(-1, 1, -1), v.call(1, 1, -1), s.x / 2, s.y / 2)
	_quad(st, v.call(1, -1, 1), v.call(1, -1, -1), v.call(1, 1, -1), v.call(1, 1, 1), s.z / 2, s.y / 2)
	_quad(st, v.call(-1, -1, -1), v.call(-1, -1, 1), v.call(-1, 1, 1), v.call(-1, 1, -1), s.z / 2, s.y / 2)
	_quad(st, v.call(-1, 1, 1), v.call(1, 1, 1), v.call(1, 1, -1), v.call(-1, 1, -1), s.x / 2, s.z / 2)

# cilindro low poly (lados poucos, como no PS1)
func cilindro(st: SurfaceTool, base: Vector3, r0: float, r1: float, alt: float, lados: int, tampa := false) -> void:
	for k in lados:
		var a0 := TAU * k / lados; var a1 := TAU * (k + 1) / lados
		var p0 := base + Vector3(cos(a0) * r0, 0, sin(a0) * r0); var p1 := base + Vector3(cos(a1) * r0, 0, sin(a1) * r0)
		var q0 := base + Vector3(cos(a0) * r1, alt, sin(a0) * r1); var q1 := base + Vector3(cos(a1) * r1, alt, sin(a1) * r1)
		if r1 < 0.001: _tri(st, p1, p0, q0, TAU * r0 / lados, alt / 2.0)
		else: _quad(st, p1, p0, q0, q1, TAU * r0 / lados, alt / 2.0)
		if tampa and r1 > 0.001: _tri(st, q1, q0, base + Vector3(0, alt, 0), r1, r1)

func _poco(pos: Vector3) -> void:
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	cilindro(st, Vector3.ZERO, 1.1, 1.1, 0.9, 8, true); st.set_material(mat("pedra")); st.commit(mesh)
	st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_caixa(st, Vector3(-0.95, 1.4, 0), Vector3(0.15, 1.8, 0.15)); _caixa(st, Vector3(0.95, 1.4, 0), Vector3(0.15, 1.8, 0.15))
	cilindro(st, Vector3(0, 2.3, 0), 1.5, 0.0, 0.9, 4)
	st.set_material(mat("madeira")); st.commit(mesh)
	var mi := MeshInstance3D.new(); mi.mesh = mesh; mi.position = pos; raiz.add_child(mi)
	_colisor_cilindro(pos, 1.15, 2.0)

func _barril(pos: Vector3) -> void:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	cilindro(st, Vector3.ZERO, 0.32, 0.38, 0.45, 8); cilindro(st, Vector3(0, 0.45, 0), 0.38, 0.32, 0.45, 8, true)
	var mi := MeshInstance3D.new(); mi.mesh = st.commit(); mi.material_override = mat("madeira"); mi.position = pos
	raiz.add_child(mi); _colisor_cilindro(pos, 0.38, 0.9)

func _colisor_cilindro(pos: Vector3, r: float, h: float) -> void:
	var corpo := StaticBody3D.new(); var cs := CollisionShape3D.new(); var c := CylinderShape3D.new()
	c.radius = r; c.height = h; cs.shape = c; cs.position = Vector3(0, h / 2.0, 0); corpo.add_child(cs)
	corpo.position = pos; raiz.add_child(corpo)

# ---------- árvores: pinheiros low poly + árvores de outono com copa em splats ----------
func _livre(p: Vector2, r: float) -> bool:
	if p.length() < 24.0 or _dist_estrada(p) < 3.5 + r: return false
	for c in casas:
		if p.distance_to(Vector2(c[0].x, c[0].z)) < max(c[2], c[3]) * 0.8 + r: return false
	return true

func _arvores() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 21
	var pinho := SurfaceTool.new(); pinho.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tronco := SurfaceTool.new(); tronco.begin(Mesh.PRIMITIVE_TRIANGLES)
	var folhas: Array = []   # [pos, cor, tam]
	var feitas := 0; var tent := 0
	while feitas < 260 and tent < 5000:
		tent += 1
		var p := Vector2(rng.randf_range(-118, 118), rng.randf_range(-118, 118))
		if p.length() > 96.0 or not _livre(p, 1.5): continue
		var h := altura(p.x, p.y)
		if h > 28.0: continue
		var b := Vector3(p.x, h - 0.2, p.y)
		var outono := _ruido.get_noise_2d(p.x * 0.5, p.y * 0.5 + 50.0) > 0.12 and h < 25.0
		var s := rng.randf_range(0.8, 1.3)
		if outono:
			cilindro(tronco, b, 0.28 * s, 0.16 * s, 3.4 * s, 5)
			var copa := b + Vector3(0, 4.4 * s, 0)
			var tom: Color = [Color(0.88, 0.52, 0.2), Color(0.95, 0.72, 0.28), Color(0.78, 0.36, 0.18), Color(0.7, 0.66, 0.25)][rng.randi() % 4]
			for k in 46:
				var dv := Vector3(rng.randfn(0, 1), rng.randfn(0, 0.8), rng.randfn(0, 1)).normalized() * pow(rng.randf(), 0.5) * 2.2 * s
				var sombra: float = 0.62 + 0.38 * clamp((dv.y / (2.2 * s)) * 0.5 + 0.5, 0.0, 1.0)
				folhas.append([copa + dv, tom * sombra * rng.randf_range(0.9, 1.08), rng.randf_range(0.8, 1.2) * s])
		else:
			cilindro(tronco, b, 0.22 * s, 0.14 * s, 1.6 * s, 5)
			for k in 3:
				var y0 := (1.2 + k * 1.5) * s; var r0 := (2.1 - k * 0.55) * s
				cilindro(pinho, b + Vector3(0, y0, 0), r0, 0.0, 2.6 * s, 6)
		_colisor_cilindro(b, 0.3 * s, 3.0)
		feitas += 1
	var m1 := MeshInstance3D.new(); m1.mesh = pinho.commit(); m1.material_override = mat("pinho"); raiz.add_child(m1)
	var m2 := MeshInstance3D.new(); m2.mesh = tronco.commit(); m2.material_override = mat("casca"); raiz.add_child(m2)
	_splats(folhas, Vector2(1.1, 1.1), false, 0.3)

# MultiMesh de splats: itens = [posição, cor, escala]
func _splats(itens: Array, tam: Vector2, em_pe: bool, balanco: float, ate := 0.0) -> MultiMeshInstance3D:
	var q := QuadMesh.new(); q.size = Vector2(1, 1)
	if em_pe: q.center_offset = Vector3(0, 0.5, 0)
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_colors = true; mm.mesh = q
	mm.instance_count = itens.size()
	for i in itens.size():
		var it: Array = itens[i]; var s: float = it[2]
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(tam.x * s, tam.y * s, 1)), it[0]))
		mm.set_instance_color(i, it[1])
	var sm := ShaderMaterial.new(); sm.shader = load("res://shaders/splat.gdshader")
	sm.set_shader_parameter("em_pe", em_pe); sm.set_shader_parameter("balanco", balanco); sm.set_shader_parameter("neblina", NEBLINA)
	var mi := MultiMeshInstance3D.new(); mi.multimesh = mm; mi.material_override = sm
	if ate > 0.0: mi.visibility_range_end = ate; mi.visibility_range_end_margin = 4.0
	raiz.add_child(mi); return mi

# ---------- grama e trigo em splats (blocos de 20 m, só desenhados perto) ----------
func _grama() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 33
	var bloco := 20.0
	for bz in range(-110, 110, int(bloco)):
		for bx in range(-110, 110, int(bloco)):
			var itens := []
			for k in 170:
				var p := Vector2(bx + rng.randf() * bloco, bz + rng.randf() * bloco)
				var r := p.length()
				if r > 105.0 or r < 17.0 or _dist_estrada(p) < 2.4: continue
				var h := altura(p.x, p.y)
				if h > 26.0: continue
				var c := cor_chao(p.x, p.y, h, 1.0)
				var trigo := c.r > 0.66
				var base_cor := c * (0.78 if not trigo else 0.95)
				for f in rng.randi_range(3, 5):
					var o := Vector2(rng.randf_range(-0.12, 0.12), rng.randf_range(-0.12, 0.12))
					var s := rng.randf_range(0.7, 1.3) * (1.5 if trigo else 1.0)
					itens.append([Vector3(p.x + o.x, h - 0.05, p.y + o.y), base_cor * rng.randf_range(0.85, 1.2), s])
			if itens.is_empty(): continue
			var mi := _splats(itens, Vector2(0.1, 0.42), true, 0.05, 42.0)
			mi.custom_aabb = AABB(Vector3(bx, -5, bz), Vector3(bloco, 80, bloco))

# ---------- modo de teste: --shot=arquivo.png --espera=2 --pos=x,z --olhar=graus ----------
func _modo_teste() -> void:
	if args.has("pos"):
		var pp := String(args.pos).split(","); jogador.position = Vector3(float(pp[0]), altura(float(pp[0]), float(pp[1])) + 0.2, float(pp[1]))
	if args.has("olhar"): jogador.rotation.y = deg_to_rad(float(args.olhar))
	if args.has("raio"): _prox_raio = 0.0
	await get_tree().create_timer(float(args.get("espera", "2"))).timeout
	get_viewport().get_texture().get_image().save_png(args.shot)
	get_tree().quit()

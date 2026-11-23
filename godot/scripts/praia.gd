# Praia viva: conchas (leque rosado e caramujo em espiral), pedrinhas lisas na areia e caranguejos vermelhos que
# andam de lado e fogem quando a Rachel chega perto. Tudo é montado por trechos de 60 m da costa, só perto dela
# (os trechos longe somem pela distância de visão), e os caranguejos renascem perto dela.
extends Node3D
class_name Praia

const TRECHO := 60.0
const MAX_CARANG := 8
var m
var rng := RandomNumberGenerator.new()
var _feitos := {}                    # índice do trecho → true
var _costa := {}                     # índice → x da linha da água
var _t := 0.0
var _malhas := []                    # [concha leque, caramujo, pedrinha]
var _mat: ShaderMaterial
var _carang_malha: ArrayMesh
var carangs := []                    # {no, alvo, espera, vel, foge}

func montar(mundo) -> void:
	m = mundo; rng.seed = 77
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF     # caranguejos andam no _process
	_mat = m.mat("", 1.0, Color.WHITE)
	_malhas = [_leque(), _caramujo(), _pedrinha()]
	_carang_malha = _caranguejo()

# ---------- malhas (cores nos vértices; o shader PS1 usa COLOR como cor) ----------
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, cor: Color) -> void:
	var n := (b - a).cross(c - a).normalized()
	if n.y < 0.0: n = -n                       # sempre virada para o céu (pegam a luz do sol)
	st.set_color(cor); st.set_normal(n.lerp(Vector3.UP, 0.5).normalized())
	st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)

func _leque() -> ArrayMesh:                 # concha em leque com gomos (≈ 9 cm)
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 9; var r := 0.09
	for i in n:
		var a0 := lerpf(-1.1, 1.1, float(i) / n); var a1 := lerpf(-1.1, 1.1, float(i + 1) / n)
		var alto := 0.02 if i % 2 == 0 else 0.012
		var p0 := Vector3(sin(a0) * r, alto, cos(a0) * r); var p1 := Vector3(sin(a1) * r, alto, cos(a1) * r)
		var cor := Color(0.98, 0.82, 0.74) if i % 2 == 0 else Color(0.9, 0.62, 0.58)
		_tri(st, Vector3(0, 0.012, -0.01), p1, p0, cor)
	return st.commit()

func _caramujo() -> ArrayMesh:              # caramujo: cone torcido em espiral (≈ 10 cm)
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lados := 6; var aneis := 5
	for k in aneis:
		var r0 := 0.045 * (1.0 - float(k) / aneis); var r1 := 0.045 * (1.0 - float(k + 1) / aneis)
		var z0 := k * 0.022; var z1 := (k + 1) * 0.022
		var cor := Color(0.96, 0.7, 0.42) if k % 2 == 0 else Color(0.99, 0.93, 0.82)
		for i in lados:
			var a0 := TAU * i / lados + k * 0.5; var a1 := TAU * (i + 1) / lados + k * 0.5
			var b0 := TAU * i / lados + (k + 1) * 0.5; var b1 := TAU * (i + 1) / lados + (k + 1) * 0.5
			var p00 := Vector3(cos(a0) * r0, sin(a0) * r0 * 0.8 + 0.035, z0); var p01 := Vector3(cos(a1) * r0, sin(a1) * r0 * 0.8 + 0.035, z0)
			var p10 := Vector3(cos(b0) * r1, sin(b0) * r1 * 0.8 + 0.035, z1); var p11 := Vector3(cos(b1) * r1, sin(b1) * r1 * 0.8 + 0.035, z1)
			_tri(st, p00, p10, p01, cor); _tri(st, p01, p10, p11, cor)
	return st.commit()

func _pedrinha() -> ArrayMesh:              # seixo achatado (≈ 12 cm)
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 7; var topo := Vector3(0, 0.045, 0)
	for i in n:
		var a0 := TAU * i / n; var a1 := TAU * (i + 1) / n
		var p0 := Vector3(cos(a0) * 0.07, 0.0, sin(a0) * 0.05); var p1 := Vector3(cos(a1) * 0.07, 0.0, sin(a1) * 0.05)
		var q0 := Vector3(cos(a0) * 0.05, 0.03, sin(a0) * 0.035); var q1 := Vector3(cos(a1) * 0.05, 0.03, sin(a1) * 0.035)
		_tri(st, p0, q0, p1, Color(0.78, 0.76, 0.72)); _tri(st, p1, q0, q1, Color(0.78, 0.76, 0.72))
		_tri(st, q0, topo, q1, Color(0.88, 0.86, 0.82))
	return st.commit()

func _caranguejo() -> ArrayMesh:            # carapaça vermelha, olhinhos, 2 garras e 6 patas (≈ 25 cm)
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ver := Color(0.86, 0.16, 0.1); var esc := Color(0.6, 0.08, 0.05); var cla := Color(0.98, 0.45, 0.3)
	# carapaça: losango achatado
	var n := 8; var topo := Vector3(0, 0.085, 0)
	for i in n:
		var a0 := TAU * i / n; var a1 := TAU * (i + 1) / n
		var p0 := Vector3(cos(a0) * 0.12, 0.04, sin(a0) * 0.085); var p1 := Vector3(cos(a1) * 0.12, 0.04, sin(a1) * 0.085)
		_tri(st, p0, topo, p1, ver if i % 2 == 0 else cla)
		_tri(st, p1, Vector3(0, 0.03, 0), p0, esc)
	# patas: 3 de cada lado (x = lados do corpo, ele anda de lado)
	for lado in [-1.0, 1.0]:
		for k in 3:
			var z := (k - 1) * 0.06
			var raiz := Vector3(0.08 * lado, 0.045, z); var joelho := Vector3(0.16 * lado, 0.07, z * 1.3); var pe := Vector3(0.2 * lado, 0.0, z * 1.5)
			_tri(st, raiz, joelho, raiz + Vector3(0, 0, 0.015), esc); _tri(st, joelho, pe, joelho + Vector3(0, 0, 0.015), esc)
			_tri(st, raiz + Vector3(0, 0, 0.015), joelho, raiz, esc); _tri(st, joelho + Vector3(0, 0, 0.015), pe, joelho, esc)
	# garras (na frente = -z) e olhinhos
	for lado in [-1.0, 1.0]:
		var b := Vector3(0.06 * lado, 0.05, -0.08); var g := Vector3(0.09 * lado, 0.07, -0.16)
		_tri(st, b, g + Vector3(0.03 * lado, 0, 0), g + Vector3(0, 0.03, 0), ver); _tri(st, g + Vector3(0, 0.03, 0), g + Vector3(0.03 * lado, 0, 0), b, ver)
		_tri(st, g, g + Vector3(0.035 * lado, 0.02, -0.04), g + Vector3(0, 0.035, -0.02), cla)
		_tri(st, g + Vector3(0, 0.035, -0.02), g + Vector3(0.035 * lado, 0.02, -0.04), g, cla)
		var o := Vector3(0.03 * lado, 0.09, -0.06)
		_tri(st, o, o + Vector3(0.012, 0.03, 0), o + Vector3(-0.012, 0.03, 0), Color(0.1, 0.08, 0.06))
		_tri(st, o + Vector3(-0.012, 0.03, 0), o + Vector3(0.012, 0.03, 0), o, Color(0.1, 0.08, 0.06))
	return st.commit()

# ---------- trechos da costa ----------
func _process(delta: float) -> void:
	if m == null or m.jogador == null: return
	var jp: Vector3 = m.jogador.global_position
	_caranguejos(delta, jp)
	_t -= delta
	if _t > 0.0: return
	_t = 0.4
	if jp.x < 1950.0: return                     # longe do mar
	var i0 := int(floor(jp.z / TRECHO))
	for di in [0, -1, 1, -2, 2]:                 # um trecho por vez (sem tranco)
		var i: int = i0 + di
		if _feitos.has(i): continue
		_feitos[i] = true; _montar_trecho(i); return

func costa(i: int) -> float:
	if not _costa.has(i): _costa[i] = m.linha_praia((i + 0.5) * TRECHO)
	return _costa[i]

func _montar_trecho(i: int) -> void:
	var cx := costa(i)
	if cx < 0.0: return
	var r := RandomNumberGenerator.new(); r.seed = 1000 + i
	var listas := [[], [], []]
	for k in 480:
		var z := (i + r.randf()) * TRECHO; var x := cx - r.randf_range(-1.0, 26.0)
		if m.reg.na_cidade(x, z, 30.0): continue
		var h: float = m.altura_malha(x, z)
		if h < 0.12 or h > 2.6 or m.na_agua(x, z): continue
		var tipo := 2 if r.randf() < 0.5 else (0 if r.randf() < 0.55 else 1)
		var esc := r.randf_range(1.7, 2.7) * (1.4 if tipo == 2 and r.randf() < 0.3 else 1.0)
		var b := Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3.ONE * esc)
		var cor := Color.WHITE
		if tipo == 2: cor = Color.from_hsv(r.randf_range(0.05, 0.6), r.randf_range(0.0, 0.15), r.randf_range(0.45, 0.95))
		elif tipo == 0: cor = Color(1, r.randf_range(0.85, 1.0), r.randf_range(0.8, 1.0))
		listas[tipo].append([Transform3D(b, Vector3(x, h - 0.005, z)), cor])
	for t in 3:
		if listas[t].is_empty(): continue
		var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_colors = true
		mm.mesh = _malhas[t]; mm.instance_count = listas[t].size()
		mm.buffer = Obras.empacotar(listas[t], false)
		var mi := MultiMeshInstance3D.new(); mi.multimesh = mm; mi.material_override = _mat
		mi.visibility_range_end = 45.0; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)

# ---------- caranguejos ----------
func _caranguejos(delta: float, jp: Vector3) -> void:
	var i0 := int(floor(jp.z / TRECHO))
	var perto := jp.x > 1950.0 and _costa.has(i0) and costa(i0) > 0.0 and jp.x > costa(i0) - 90.0
	if perto and carangs.size() < MAX_CARANG:
		var c := _novo_carang(jp)
		if not c.is_empty(): carangs.append(c)
	for c in carangs.duplicate():
		var no: Node3D = c.no
		var p := Vector2(no.position.x, no.position.z); var pj := Vector2(jp.x, jp.z)
		if p.distance_to(pj) > 70.0 or not perto:            # ficou longe: some (renasce perto dela)
			no.queue_free(); carangs.erase(c); continue
		var fugir := p.distance_to(pj) < 4.5
		c.espera -= delta
		if fugir:
			c.alvo = p + (p - pj).normalized() * 6.0; c.espera = 0.0
		elif c.espera <= 0.0 and p.distance_to(c.alvo) < 0.1:
			var a := rng.randf() * TAU
			c.alvo = p + Vector2(cos(a), sin(a)) * rng.randf_range(0.5, 2.5); c.espera = rng.randf_range(0.6, 3.0)
		if c.espera > 0.0 and not fugir: continue
		var d: Vector2 = c.alvo - p
		if d.length() < 0.05: continue
		var vel := 2.6 if fugir else 0.9
		var passo := d.normalized() * minf(d.length(), vel * delta)
		var np := p + passo
		var h: float = m.altura_malha(np.x, np.y)
		if m.na_agua(np.x, np.y) and not fugir: c.alvo = p; continue
		no.position = Vector3(np.x, h + absf(sin(Time.get_ticks_msec() * 0.03)) * 0.01, np.y)
		# anda de lado: o corpo fica atravessado na direção do passo, com tremidinha
		no.rotation.y = atan2(d.x, d.y) + PI * 0.5 + sin(Time.get_ticks_msec() * 0.04) * 0.08

func _novo_carang(jp: Vector3) -> Dictionary:
	for tent in 6:
		var a := rng.randf() * TAU; var r := rng.randf_range(10.0, 40.0)
		var x := jp.x + cos(a) * r; var z := jp.z + sin(a) * r
		var cx := costa(int(floor(z / TRECHO)))
		if cx < 0.0 or x < cx - 30.0: continue
		var h: float = m.altura_malha(x, z)
		if h < 0.1 or h > 2.4 or m.na_agua(x, z) or m.reg.na_cidade(x, z, 20.0): continue
		var no := MeshInstance3D.new(); no.mesh = _carang_malha; no.material_override = _mat
		no.scale = Vector3.ONE * rng.randf_range(1.4, 2.0); no.position = Vector3(x, h, z)
		no.visibility_range_end = 40.0; add_child(no)
		return {"no": no, "alvo": Vector2(x, z), "espera": rng.randf_range(0.0, 2.0)}
	return {}

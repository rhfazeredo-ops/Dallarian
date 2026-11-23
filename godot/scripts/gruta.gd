# Ambientação da Gruta dos Lodosos (tudo procedural, em MultiMesh): estalactites no teto, estalagmites junto das
# paredes, cogumelos que brilham no escuro, poças, ossadas de peixe, conchas e pedrinhas, totens com o cajado de
# caveira de peixe na entrada das salas, gotas pingando do teto (com o som do pingo) e, com a Rachel lá dentro,
# o som ambiente da caverna e mais eco nos efeitos.
extends Node3D
class_name Gruta

var m
var reg: Regiao
var rng := RandomNumberGenerator.new()
var _pingos := []                  # [posição do teto, próxima gota (s), CPUParticles3D]
var _som_pingo: Array = []
var _ambiente: AudioStreamPlayer
var _t_som := 0.0

func montar(mundo) -> void:
	m = mundo; reg = m.reg; rng.seed = 8080
	var pedra: ShaderMaterial = m.mat("", 1.0, Color(0.95, 0.92, 0.88))
	var bb := Regiao.GRUTA_BB
	# pontos dentro da gruta coberta: perto da parede (borda) e no meio
	var borda := []; var meio := []
	for k in 9000:
		var x := bb.position.x + rng.randf() * bb.size.x; var z := bb.position.y + rng.randf() * bb.size.y
		if z > Regiao.GRUTA_COBERTA_Z - 1.0: continue
		var d := reg.gruta_d(x, z)
		if d > -0.3: continue
		if d > -2.2: borda.append([Vector2(x, z), d])
		elif d < -3.0: meio.append(Vector2(x, z))
	# estalactites (no teto, em todo lugar) e estalagmites (junto das paredes, sem fechar o caminho)
	var cima := []; var baixo := []
	for i in 230:
		var p: Vector2 = (meio[rng.randi() % meio.size()] if rng.randf() < 0.6 else borda[rng.randi() % borda.size()][0])
		var comp := rng.randf_range(0.5, 2.3) * (1.6 if rng.randf() < 0.12 else 1.0)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(rng.randf_range(0.7, 1.3), comp, rng.randf_range(0.7, 1.3)))
		cima.append([Transform3D(b.rotated(Vector3.RIGHT, PI), Vector3(p.x, reg.gruta_teto(p.x, p.y) + 0.3, p.y)), _cor_rocha()])
	for i in 110:
		var e: Array = borda[rng.randi() % borda.size()]
		var p: Vector2 = e[0]
		var alt := rng.randf_range(0.4, 1.9) * (1.5 if float(e[1]) > -1.0 and rng.randf() < 0.3 else 1.0)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(rng.randf_range(0.8, 1.4), alt, rng.randf_range(0.8, 1.4)))
		baixo.append([Transform3D(b, Vector3(p.x, reg.gruta_piso(p.x, p.y) - 0.1, p.y)), _cor_rocha()])
	_mm(_cone(), cima + baixo, pedra)
	# cogumelos que brilham: tufos de 3 a 6 junto das paredes
	var cog := []
	for i in 70:
		var e: Array = borda[rng.randi() % borda.size()]
		var c: Vector2 = e[0]
		var cor: Color = [Color(0.35, 1.0, 0.95), Color(0.45, 0.85, 1.0), Color(0.6, 1.0, 0.55)][rng.randi() % 3]
		for j in rng.randi_range(3, 6):
			var p := c + Vector2(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.6, 0.6))
			var s := rng.randf_range(0.6, 1.5)
			var b := Basis(Vector3.UP, rng.randf() * TAU).rotated(Vector3(rng.randf() - 0.5, 0, rng.randf() - 0.5).normalized(), rng.randf_range(0.0, 0.25)).scaled(Vector3.ONE * s)
			cog.append([Transform3D(b, Vector3(p.x, reg.gruta_piso(p.x, p.y) - 0.02, p.y)), cor * rng.randf_range(0.85, 1.1)])
	var brilho := StandardMaterial3D.new(); brilho.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	brilho.vertex_color_use_as_albedo = true; brilho.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_mm(_cogumelo(), cog, brilho)
	# poças d'água no chão
	var pocas := []
	for i in 16:
		var p: Vector2 = meio[rng.randi() % meio.size()]
		var s := rng.randf_range(0.9, 2.2)
		pocas.append([Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, 1, s * rng.randf_range(0.6, 1.0))), Vector3(p.x, reg.gruta_piso(p.x, p.y) + 0.04, p.y)), Color(0.18, 0.3, 0.38)])
	_mm(_disco(), pocas, pedra)
	# ossadas de peixe, conchas e pedrinhas (as da praia)
	var ossos := []
	for i in 45:
		var p: Vector2 = (borda[rng.randi() % borda.size()][0] if rng.randf() < 0.5 else meio[rng.randi() % meio.size()])
		var s := rng.randf_range(0.7, 1.6)
		ossos.append([Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(p.x, reg.gruta_piso(p.x, p.y), p.y)), Color(0.92, 0.88, 0.78) * rng.randf_range(0.8, 1.05)])
	_mm(_ossada(), ossos, pedra)
	if m.praia and not m.praia._malhas.is_empty():
		for t in 3:
			var l := []
			for i in 40:
				var p: Vector2 = borda[rng.randi() % borda.size()][0]
				var s := rng.randf_range(1.6, 2.6)
				l.append([Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(p.x, reg.gruta_piso(p.x, p.y) - 0.01, p.y)), Color(1, 1, 1) * rng.randf_range(0.75, 1.0)])
			_mm(m.praia._malhas[t], l, pedra)
	# totens: o cajado de caveira de peixe fincado no chão na entrada de cada sala
	for sl in Regiao.GRUTA_SALAS:
		var c: Vector2 = sl[0]; var r: float = sl[1]
		for lado in [-1.0, 1.0]:
			var dirp := (Regiao.GRUTA_ENTRADA - c).normalized()
			var p: Vector2 = c + dirp * (r - 1.5) + dirp.orthogonal() * lado * 2.6
			if reg.gruta_d(p.x, p.y) > -0.5: continue
			_totem(p)
	_boca()
	# musgo úmido nas pedras da entrada e gotas pingando do teto
	for i in 12:
		var p: Vector2 = meio[rng.randi() % meio.size()]
		_pingo(Vector3(p.x, reg.gruta_teto(p.x, p.y) - 0.2, p.y))
	for i in 3: _som_pingo.append(load("res://assets/som/gruta/pingo_%d.ogg" % (i + 1)))
	_ambiente = AudioStreamPlayer.new(); var st: AudioStreamOggVorbis = load("res://assets/som/gruta/gruta_ambiente.ogg"); st.loop = true
	_ambiente.stream = st; _ambiente.bus = "Efeitos"; _ambiente.volume_db = -60.0; add_child(_ambiente)

func _cor_rocha() -> Color: return Color(0.55, 0.52, 0.48) * rng.randf_range(0.7, 1.05)

func _mm(malha: Mesh, itens: Array, mat: Material) -> void:
	if itens.is_empty(): return
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_colors = true
	mm.mesh = malha; mm.instance_count = itens.size(); mm.buffer = Obras.empacotar(itens, false)
	var mi := MultiMeshInstance3D.new(); mi.multimesh = mm; mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(mi)

# ---------- malhas ----------
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, cor: Color) -> void:
	st.set_color(cor); st.set_normal((b - a).cross(c - a).normalized()); st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)

func _cone() -> ArrayMesh:                # pedra pontuda de 1 m (estalactite virada para baixo)
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 6; var ponta := Vector3(0.03, 1.0, -0.02)
	for i in n:
		var a0 := TAU * i / n; var a1 := TAU * (i + 1) / n
		var p0 := Vector3(cos(a0) * 0.22, 0, sin(a0) * 0.22); var p1 := Vector3(cos(a1) * 0.22, 0, sin(a1) * 0.22)
		var q0 := Vector3(cos(a0 + 0.3) * 0.12, 0.45, sin(a0 + 0.3) * 0.12); var q1 := Vector3(cos(a1 + 0.3) * 0.12, 0.45, sin(a1 + 0.3) * 0.12)
		var c := Color(1, 1, 1) * (0.85 if i % 2 == 0 else 1.0)
		_tri(st, p0, q0, p1, c * 0.85); _tri(st, p1, q0, q1, c * 0.85); _tri(st, q0, ponta, q1, c)
	return st.commit()

func _cogumelo() -> ArrayMesh:            # cabinho claro e chapéu que brilha (cor da instância)
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 6; var cabo := Color(0.75, 0.8, 0.8)
	for i in n:
		var a0 := TAU * i / n; var a1 := TAU * (i + 1) / n
		var b0 := Vector3(cos(a0) * 0.025, 0, sin(a0) * 0.025); var b1 := Vector3(cos(a1) * 0.025, 0, sin(a1) * 0.025)
		_tri(st, b0, b0 + Vector3(0, 0.14, 0), b1, cabo); _tri(st, b1, b0 + Vector3(0, 0.14, 0), b1 + Vector3(0, 0.14, 0), cabo)
		var c0 := Vector3(cos(a0) * 0.1, 0.13, sin(a0) * 0.1); var c1 := Vector3(cos(a1) * 0.1, 0.13, sin(a1) * 0.1)
		_tri(st, c0, Vector3(0, 0.2, 0), c1, Color(1, 1, 1)); _tri(st, c1, Vector3(0, 0.12, 0), c0, Color(0.7, 0.7, 0.7))
	return st.commit()

func _disco() -> ArrayMesh:               # poça (escura e lisa)
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 8
	for i in n:
		var a0 := TAU * i / n; var a1 := TAU * (i + 1) / n
		_tri(st, Vector3.ZERO, Vector3(cos(a1), 0, sin(a1)), Vector3(cos(a0), 0, sin(a0)), Color(1, 1, 1))
	return st.commit()

func _ossada() -> ArrayMesh:              # espinha de peixe: cabeça, coluna e 5 pares de costelas (≈ 45 cm)
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := Color(1, 1, 1)
	var caixa := func(c: Vector3, t: Vector3, giro: float):
		var b := Basis(Vector3.UP, giro)
		var v := []
		for k in 8: v.append(c + b * Vector3((k & 1) * 2 - 1, ((k >> 1) & 1) * 2 - 1, ((k >> 2) & 1) * 2 - 1) * t * 0.5)
		for f in [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]:
			_tri(st, v[f[0]], v[f[1]], v[f[2]], w); _tri(st, v[f[0]], v[f[2]], v[f[3]], w)
	caixa.call(Vector3(0, 0.02, 0), Vector3(0.4, 0.025, 0.025), 0.0)                       # coluna
	caixa.call(Vector3(0.24, 0.04, 0), Vector3(0.1, 0.07, 0.08), 0.0)                       # cabeça
	for k in 5:
		var x := 0.12 - k * 0.06
		for lado in [-1.0, 1.0]: caixa.call(Vector3(x, 0.02, lado * 0.05), Vector3(0.015, 0.015, 0.09), lado * 0.35)
	return st.commit()

func _totem(p: Vector2) -> void:
	var arq := "res://assets/modelos/lodoso_n3_arma.glb"
	if not ResourceLoader.exists(arq): return
	var no: Node3D = m.modelo_ps1(arq)
	add_child(no)
	var bb := AABB()
	for mi in no.find_children("*", "MeshInstance3D", true, false): bb = mi.get_aabb() if bb.size == Vector3.ZERO else bb.merge(mi.get_aabb())
	var esc := 2.4 / maxf(bb.size.y, 0.01)
	no.scale = Vector3.ONE * esc; no.rotation.y = rng.randf() * TAU
	no.position = Vector3(p.x, reg.gruta_piso(p.x, p.y) - bb.position.y * esc - 0.25, p.y) - Vector3(bb.get_center().x, 0, bb.get_center().z).rotated(Vector3.UP, no.rotation.y) * esc

func _pingo(teto: Vector3) -> void:
	var gotas := CPUParticles3D.new(); gotas.amount = 1; gotas.lifetime = 1.1; gotas.one_shot = true; gotas.emitting = false
	gotas.local_coords = false; gotas.gravity = Vector3(0, -9.8, 0); gotas.initial_velocity_min = 0.0; gotas.initial_velocity_max = 0.0
	var q := QuadMesh.new(); q.size = Vector2(0.03, 0.09)
	var mt := StandardMaterial3D.new(); mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mt.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mt.albedo_color = Color(0.75, 0.85, 0.95); q.material = mt; gotas.mesh = q
	gotas.position = teto; add_child(gotas)
	_pingos.append([teto, rng.randf_range(0.5, 4.0), gotas])

func _process(delta: float) -> void:
	if m == null or m.jogador == null: return
	var dentro: float = m.gruta_dentro
	# som ambiente e eco dos efeitos acompanham a entrada na gruta
	_ambiente.volume_db = lerpf(-60.0, -9.0, dentro)
	if dentro > 0.01 and not _ambiente.playing: _ambiente.play()
	elif dentro <= 0.01 and _ambiente.playing: _ambiente.stop()
	var fx := AudioServer.get_bus_index("Efeitos")
	if fx >= 0 and AudioServer.get_bus_effect_count(fx) > 0:
		var rv = AudioServer.get_bus_effect(fx, 0)
		if rv is AudioEffectReverb: rv.room_size = lerpf(0.35, 0.85, dentro); rv.wet = lerpf(0.12, 0.32, dentro)
	if dentro < 0.05: return
	var pj: Vector3 = m.jogador.global_position
	for pg in _pingos:
		pg[1] -= delta
		if pg[1] > 0.0: continue
		pg[1] = rng.randf_range(1.5, 4.5)
		var teto: Vector3 = pg[0]
		if teto.distance_to(pj) > 28.0: continue
		(pg[2] as CPUParticles3D).restart()
		var queda := sqrt(2.0 * maxf(teto.y - reg.gruta_piso(teto.x, teto.z), 0.5) / 9.8)
		var som := AudioStreamPlayer3D.new(); som.stream = _som_pingo[rng.randi() % _som_pingo.size()]; som.bus = "Efeitos"
		som.unit_size = 3.0; som.max_distance = 26.0; som.volume_db = -6.0; som.pitch_scale = rng.randf_range(0.85, 1.2)
		som.position = Vector3(teto.x, reg.gruta_piso(teto.x, teto.z) + 0.1, teto.z); add_child(som)
		get_tree().create_timer(queda).timeout.connect(func(): if is_instance_valid(som): som.play())
		get_tree().create_timer(queda + 1.2).timeout.connect(func(): if is_instance_valid(som): som.queue_free())

# ---------- boca da gruta (como a arte de referência do dono): arco de rochas grandes com musgo em cima,
# trepadeiras penduradas, caminho de terra clara entrando com grama dos lados, pedras com musgo e florzinhas
# pela beira do caminho, e uma luz quente lá no fundo ----------
func _boca() -> void:
	var r := RandomNumberGenerator.new(); r.seed = 7171
	var bz := Regiao.GRUTA_COBERTA_Z
	var cx := Regiao.GRUTA_ENTRADA.x; var meia := 0.0
	for k in 40:
		var xx := cx - 10.0 + k * 0.5
		if reg.gruta_d(xx, bz) < 0.0: meia = maxf(meia, absf(xx - cx))
	meia = maxf(meia, 3.0)
	var piso := reg.gruta_piso(cx, bz); var teto := reg.gruta_teto(cx, bz)
	var alto := Regiao.GRUTA_TETO + 3.0                 # altura do arco da boca no meio
	var pedras := []                  # [posição, tamanho, musgo]
	_entrada_modelo(cx, bz, piso)
	# pedras pela beira do caminho (menores longe da boca)
	for lado in [-1.0, 1.0]:
		for i in 9:
			var z := bz + 2.5 + r.randf_range(0.0, 22.0)
			var x: float = cx + float(lado) * (3.6 + r.randf_range(0.0, 3.0) + (z - bz) * 0.06)
			var tam := r.randf_range(0.8, 2.4) * (1.0 - (z - bz) / 40.0)
			pedras.append([Vector3(x, reg.altura(x, z) - tam * 0.2, z), tam, 0.5])
	var itens := []
	for pd in pedras:
		var tam: float = pd[1]
		var b := Basis(Vector3.UP, r.randf() * TAU).rotated(Vector3(r.randf() - 0.5, 0, r.randf() - 0.5).normalized(), r.randf_range(0.0, 0.35))
		b = b.scaled(Vector3(tam * r.randf_range(0.9, 1.2), tam * r.randf_range(0.7, 1.0), tam * r.randf_range(0.8, 1.1)))
		itens.append([Transform3D(b, pd[0]), Color(0.46, 0.5, 0.6) * r.randf_range(0.9, 1.1), pd[2]])   # rocha da montanha
	var mm_mat: ShaderMaterial = m.mat("terreno")
	_mm_musgo(itens, mm_mat)
	# florzinhas e tufos na beira do caminho
	var flores := []
	for i in 260:
		var lado := -1.0 if r.randf() < 0.5 else 1.0
		var z := bz + 1.0 + r.randf_range(0.0, 26.0)
		var x: float = cx + lado * r.randf_range(2.4, 7.0)
		if reg.caminho_gruta(x, z) > 0.3: continue
		var cor: Color = [Color(1.0, 0.85, 0.2), Color(1.0, 0.55, 0.65), Color(0.95, 0.95, 1.0), Color(0.7, 0.55, 1.0)][r.randi() % 4]
		flores.append([Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3.ONE * r.randf_range(0.7, 1.3)), Vector3(x, reg.altura(x, z) - 0.02, z)), cor])
	_mm(_flor(), flores, m.mat("", 1.0, Color.WHITE))
	# pedrinhas no caminho
	var casc := []
	for i in 400:
		var x := cx + r.randf_range(-3.0, 3.0); var z := r.randf_range(-930.0, -872.0)
		if r.randf() > reg.caminho_gruta(x, z) * 0.6: continue
		casc.append([Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3.ONE * r.randf_range(0.8, 1.8)), Vector3(x, reg.altura(x, z), z)), Color(0.8, 0.74, 0.64) * r.randf_range(0.7, 1.05)])
	if m.praia and not m.praia._malhas.is_empty(): _mm(m.praia._malhas[2], casc, m.mat("", 1.0, Color.WHITE))
	# luz quente lá no fundo do túnel (como na arte)
	var fundo := Vector2(1538.0, -945.0)
	m._fogueira_gruta(fundo)

func _mm_musgo(itens: Array, mat: Material) -> void:      # rochas: cada uma com musgo verde no topo (custom = quanto)
	var por_musgo := {}
	for it in itens:
		var k := int(round(float(it[2]) * 4.0))
		if not por_musgo.has(k): por_musgo[k] = []
		por_musgo[k].append([it[0], it[1]])
	for k in por_musgo.keys(): _mm(_pedregulho(k / 4.0), por_musgo[k], mat)

func _pedregulho(musgo := 0.0) -> ArrayMesh:          # rocha angulosa de ~1 m (poucas faces grandes; musgo no topo)
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := RandomNumberGenerator.new(); r.seed = 5
	var anel := 3; var lados := 6; var pts := []
	for j in anel + 1:
		var v := float(j) / anel; var lat := lerpf(-PI * 0.5, PI * 0.5, v)
		var fila := []
		for i in lados:
			var lon := TAU * i / lados + j * 0.4
			var k := 0.5 * r.randf_range(0.75, 1.2)
			var pt := Vector3(cos(lat) * cos(lon), sin(lat) * 0.75, cos(lat) * sin(lon)) * k
			if j == anel: pt.y = 0.33 + r.randf_range(-0.04, 0.04); pt.x *= 0.55; pt.z *= 0.55   # topo achatado (degrau)
			fila.append(pt + Vector3(0, 0.3, 0))
		pts.append(fila)
	for j in anel:
		for i in lados:
			var a: Vector3 = pts[j][i]; var b: Vector3 = pts[j][(i + 1) % lados]; var c: Vector3 = pts[j + 1][(i + 1) % lados]; var d: Vector3 = pts[j + 1][i]
			var cor := Color(1, 1, 1) * (0.72 + 0.28 * float(j) / anel) * (0.92 + 0.08 * float(i % 2))
			if musgo > 0.0 and j == anel - 1 and i % 3 != 0: cor = cor.lerp(Color(0.9, 1.15, 0.45), musgo)   # vezes a cor da rocha = verde da grama
			_tri(st, a, c, b, cor); _tri(st, a, d, c, cor)
	var topo: Vector3 = Vector3(0, 0.33 + 0.3, 0)
	for i in lados:                                       # tampa do topo (musgo/grama)
		var a: Vector3 = pts[anel][i]; var b: Vector3 = pts[anel][(i + 1) % lados]
		_tri(st, a, topo, b, (Color(1, 1, 1) * 0.98).lerp(Color(0.9, 1.15, 0.45), musgo))
	return st.commit()

func _flor() -> ArrayMesh:                # florzinha: cabinho verde e 2 pétalas cruzadas (cor da instância)
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var g := Color(0.35, 0.6, 0.25)
	_tri(st, Vector3(-0.01, 0, 0), Vector3(0.01, 0, 0), Vector3(0, 0.2, 0), g)
	for a in [0.0, PI * 0.5]:
		var d := Vector3(cos(a), 0, sin(a)) * 0.06
		_tri(st, Vector3(0, 0.2, 0) - d, Vector3(0, 0.2, 0) + d, Vector3(0, 0.26, 0), Color.WHITE)
		_tri(st, Vector3(0, 0.2, 0) - d, Vector3(0, 0.14, 0), Vector3(0, 0.2, 0) + d, Color.WHITE)
	return st.commit()

# PAREDÃO DE ROCHA da boca (como a arte): uma superfície de rocha só, facetada, em volta de um buraco em arco,
# saltando para fora em volta da borda; do arco sai um túnel arredondado de rocha entrando na montanha.
# Facetas viradas para cima ficam com musgo. Tem colisão.
func _paredao_rocha(cx: float, bz: float, meia: float, piso: float, alto: float, _teto: float) -> void:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	var ra := meia + 1.8; var rb := alto + 1.6            # elipse do buraco (boca grande, como na arte)
	var w := meia + 11.0; var passo := 2.0
	var pos := func(u: float, v: float) -> Vector3:
		var e := sqrt(pow(u / ra, 2.0) + pow(v / rb, 2.0))          # 1 na borda do buraco
		var borda := exp(-pow(maxf(e - 1.0, 0.0) * 2.6, 2.0))            # a rocha salta perto da borda
		var wl := meia + 8.0 + reg.ruido.get_noise_2d(v * 6.0, 11.0) * 3.0          # contorno irregular
		var some := smoothstep(wl + 1.0, wl - 4.0, absf(u))                             # funde na montanha na borda
		var d := (1.2 + reg.ruido.get_noise_2d(u * 6.0, v * 6.0) * 1.4 + reg.ruido.get_noise_2d(u * 15.0 + 40.0, v * 15.0) * 0.4) * some + borda * 2.6 - (1.0 - some) * 1.5
		return Vector3(cx + u, piso + v, bz + d)
	var nu := int(2.0 * w / passo)
	for i in nu:
		var u0 := -w + i * passo; var u1 := u0 + passo
		var topo := maxf(reg.altura(cx + u0, bz - 3.0, false), reg.altura(cx + u1, bz - 3.0, false)) - piso
		var nv := int((topo + 1.0) / passo) + 1
		for j in nv:
			var v0 := -1.0 + j * passo; var v1 := v0 + passo
			var wl0 := meia + 8.0 + reg.ruido.get_noise_2d(v0 * 6.0, 11.0) * 3.0
			if absf(u0) > wl0 + 1.5 and absf(u1) > wl0 + 1.5: continue
			if v0 > topo - 1.0 - absf(reg.ruido.get_noise_2d(u0 * 5.0, 3.0)) * 4.0: continue     # topo irregular
			var fora := true
			for c in [Vector2(u0, v0), Vector2(u1, v0), Vector2(u0, v1), Vector2(u1, v1)]:
				if pow(c.x / ra, 2.0) + pow(maxf(c.y, 0.0) / rb, 2.0) < 1.0: fora = false
			if not fora: continue
			var a: Vector3 = pos.call(u0, v0); var b: Vector3 = pos.call(u1, v0); var c2: Vector3 = pos.call(u1, v1); var d2: Vector3 = pos.call(u0, v1)
			for tri in [[a, b, c2], [a, c2, d2]]:
				_faceta(st, tri[0], tri[1], tri[2]); faces.append_array(PackedVector3Array(tri))
	# túnel arredondado: anéis da elipse entrando na montanha (de onde o paredão salta até 10 m para dentro)
	var segs := 14; var aneis := [3.4, 1.4, -1.5, -4.5, -8.0, -11.0]
	for k in aneis.size() - 1:
		for i in segs:
			var a0 := PI * i / segs; var a1 := PI * (i + 1) / segs
			var pts := []
			for zz in [aneis[k], aneis[k + 1]]:
				for aa in [a0, a1]:
					var j := 1.0 + reg.ruido.get_noise_2d(aa * 20.0, float(zz) * 3.0) * 0.12
					pts.append(Vector3(cx + cos(aa) * ra * j, piso + sin(aa) * rb * j, bz + float(zz)))
			var esc := clampf(1.0 - (2.0 - float(aneis[k])) / 12.0, 0.25, 1.0)          # escurece para dentro
			_faceta(st, pts[0], pts[2], pts[3], esc); _faceta(st, pts[0], pts[3], pts[1], esc)
	var mi := MeshInstance3D.new(); mi.mesh = st.commit(); mi.material_override = m.mat("terreno"); add_child(mi)   # mesma textura da montanha
	var corpo := StaticBody3D.new(); var cs := CollisionShape3D.new(); var f := ConcavePolygonShape3D.new()
	f.set_faces(faces); f.backface_collision = true; cs.shape = f; corpo.add_child(cs); add_child(corpo)

func _faceta(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, luz := 1.0) -> void:      # triângulo de rocha com cor própria
	var n := (b - a).cross(c - a).normalized()
	if n.z < 0.0 and absf(n.y) < 0.6: n = -n
	var m0 := (a + b + c) / 3.0
	# a mesma cor que o terreno teria aqui (rocha nas faces em pé, grama nos degraus, neve no alto)
	var cor := reg.cor(m0.x, m0.z, m0.y, absf(n.y), false)
	if luz < 1.0: cor = Color(0.5, 0.42, 0.34).lerp(cor, 0.3) * luz                  # dentro do túnel: rocha morna e escura
	for p in [a, b, c]: st.set_color(cor); st.set_normal(n); st.set_uv(Vector2(p.x + p.z, p.y) * 0.25); st.add_vertex(p)

# entrada modelada pelo dono (Tripo): rochas com musgo e hera em volta do túnel. No arquivo a boca olha para +X,
# a largura é o eixo Z e a altura Y; aqui a boca olha para o vale (+Z) e o fundo encosta na montanha.
func _entrada_modelo(cx: float, bz: float, piso: float) -> void:
	var arq := "res://assets/modelos/entrada_gruta.glb"
	if not ResourceLoader.exists(arq): return
	var no: Node3D = m.modelo_ps1(arq)
	var bb := AABB()
	for mi in no.find_children("*", "MeshInstance3D", true, false):
		bb = mi.get_aabb() if bb.size == Vector3.ZERO else bb.merge(mi.get_aabb())
		(mi as MeshInstance3D).visibility_range_end = 400.0
	# tira a parede do fundo da toca do modelo (faces viradas para a boca, no meio e embaixo, na metade de trás):
	# pela abertura aparece o túnel de verdade
	for mi: MeshInstance3D in no.find_children("*", "MeshInstance3D", true, false):
		var am := ArrayMesh.new(); var mesh: Mesh = mi.mesh
		for sf in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(sf)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]; var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			var novo := PackedInt32Array()
			var x_corte := bb.position.x + bb.size.x * 0.5; var y_corte := bb.position.y + bb.size.y * 0.5
			var z_meia := bb.size.z * 0.19
			for t in range(0, idx.size(), 3):
				var a := v[idx[t]]; var b := v[idx[t + 1]]; var c := v[idx[t + 2]]
				var cc := (a + b + c) / 3.0; var n := (b - a).cross(c - a).normalized()
				if cc.x < x_corte and cc.y < y_corte and absf(cc.z - bb.get_center().z) < z_meia and n.x > 0.7: continue
				novo.append(idx[t]); novo.append(idx[t + 1]); novo.append(idx[t + 2])
			arr[Mesh.ARRAY_INDEX] = novo
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			am.surface_set_material(sf, mesh.surface_get_material(sf))
		var mat_o = mi.get_surface_override_material(0)
		mi.mesh = am
		if mat_o: mi.set_surface_override_material(0, mat_o)
	var esc := 23.0 / bb.size.z                                     # ~23 m de largura (boca de ~12 m)
	var fundo := 0.55                                               # menos fundo (o túnel de verdade continua atrás)
	add_child(no)
	no.scale = Vector3(esc * fundo, esc, esc)
	no.rotation.y = -PI * 0.5                                       # +X do arquivo → +Z (para o vale)
	# o fundo da rocha encosta na montanha (1,5 m para dentro); a frente fica no vale
	no.position = Vector3(cx - bb.get_center().z * esc, piso - bb.position.y * esc - 0.3, bz - 1.5 - bb.position.x * esc * fundo)

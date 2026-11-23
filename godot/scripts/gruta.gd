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

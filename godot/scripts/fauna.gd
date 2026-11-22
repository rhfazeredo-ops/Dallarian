# Vida no mundo: silhuetas de peixes no rio e no lago (um grande e lento sozinho, ou cardumes de 4 a 6
# pequeninos e rápidos, às vezes um pequeno sozinho) e pássaros voando alto (sozinhos, em dupla ou em trio).
# Tudo acontece perto da Rachel: grupos que ficam longe renascem perto dela (leve no celular).
extends Node3D
class_name Fauna

var m
var reg: Regiao
var rng := RandomNumberGenerator.new()
# rio: comprimento acumulado de cada ponto da linha
# vale para os dois rios: [linha, comprimentos acumulados, total, largura(t), nível(t)]
var _rios := []
var _s_perto := [0.0, 0.0]     # ponto de cada rio mais perto da Rachel (metros ao longo do rio)
var _rio_perto := 0            # o rio mais perto da Rachel (os cardumes renascem nele)
var _t_proc := 0.0
# peixes
const MAX_PEIXES := 48
var _mm: MultiMesh
var cardumes := []             # {lago, s, ang, lado, dir, vel, grande, membros:[{off, fase}], alvo_lado}
# pássaros
var bandos := []               # {pos, rumo, giro, alt, aves:[{no, asa_e, asa_d, off, fase}]}

func montar(mundo) -> void:
	m = mundo; reg = m.reg; rng.seed = 2024
	for par in [[reg.rio, reg.largura_rio, reg.nivel_rio], [reg.rio2, reg.largura_rio2, reg.nivel_rio2]]:
		var linha: Array = par[0]; var acum := PackedFloat32Array([0.0]); var tot := 0.0
		for i in range(1, linha.size()):
			tot += linha[i].distance_to(linha[i - 1]); acum.append(tot)
		_rios.append([linha, acum, tot, par[1], par[2]])
	# peixes: um MultiMesh com um quadrado deitado por peixe
	var pm := PlaneMesh.new(); pm.size = Vector2(1, 0.6)
	_mm = MultiMesh.new(); _mm.transform_format = MultiMesh.TRANSFORM_3D; _mm.use_custom_data = true; _mm.mesh = pm
	_mm.instance_count = MAX_PEIXES; _mm.visible_instance_count = 0
	var sm := ShaderMaterial.new(); sm.shader = load("res://shaders/peixe.gdshader"); sm.render_priority = 2
	var mi := MultiMeshInstance3D.new(); mi.multimesh = _mm; mi.material_override = sm
	mi.custom_aabb = AABB(Vector3(-2000, -200, -2000), Vector3(4000, 600, 4000)); add_child(mi)
	for i in 5: cardumes.append(_novo_cardume(false))
	for i in 3: cardumes.append(_novo_cardume(true))
	for i in 3: bandos.append(_novo_bando(true))

# ---------- rio ----------
func _no_rio(s: float, r := 0) -> Array:            # [ponto, direção, t (0..1)]
	var linha: Array = _rios[r][0]; var acum: PackedFloat32Array = _rios[r][1]; var tot: float = _rios[r][2]
	s = clampf(s, 0.0, tot - 0.01)
	var i := 1
	while i < acum.size() - 1 and acum[i] < s: i += 1
	var a: Vector2 = linha[i - 1]; var b: Vector2 = linha[i]
	var u := (s - acum[i - 1]) / maxf(acum[i] - acum[i - 1], 0.01)
	return [a.lerp(b, u), (b - a).normalized(), s / tot]

func _mais_perto_no_rio(p: Vector2, r := 0) -> Array:   # [metros ao longo do rio, distância]
	var linha: Array = _rios[r][0]; var acum: PackedFloat32Array = _rios[r][1]
	var melhor := 0.0; var md := 1e9
	for i in range(1, linha.size()):
		var a: Vector2 = linha[i - 1]; var b: Vector2 = linha[i]
		var ab := b - a; var u := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var d := p.distance_to(a + ab * u)
		if d < md: md = d; melhor = acum[i - 1] + ab.length() * u
	return [melhor, md]

func _novo_cardume(lago: bool) -> Dictionary:
	var r := rng.randf()
	var grande := r < 0.3; var n := 1 if (grande or r > 0.82) else rng.randi_range(4, 6)
	var c := {"lago": lago, "rio": _rio_perto, "s": _s_perto[_rio_perto] + rng.randf_range(-55.0, 55.0), "ang": rng.randf() * TAU,
		"raio": rng.randf_range(Regiao.ILHA.z + 6.0, Regiao.LAGO.z - 7.0), "lado": rng.randf_range(-0.6, 0.6),
		"alvo_lado": rng.randf_range(-0.7, 0.7), "dir": 1.0 if rng.randf() < 0.5 else -1.0,
		"vel": rng.randf_range(0.35, 0.6) if grande else rng.randf_range(1.6, 2.6), "grande": grande, "membros": [],
		"pausa": 0.0, "arranque": 1.0}
	for k in n:
		c.membros.append({"off": Vector2(rng.randf_range(-1.1, 0.4), rng.randf_range(-0.7, 0.7)) if k > 0 else Vector2.ZERO,
			"fase": rng.randf() * TAU, "tam": rng.randf_range(1.1, 1.5) * (1.0 if grande else 0.42)})
	return c

# ---------- pássaros ----------
func _novo_bando(longe_ok: bool) -> Dictionary:
	var pj: Vector3 = m.jogador.global_position if m.jogador else Vector3.ZERO
	var a := rng.randf() * TAU
	var dist := rng.randf_range(60.0, 170.0) if longe_ok else rng.randf_range(140.0, 180.0)
	var pos := Vector3(pj.x + cos(a) * dist, 0.0, pj.z + sin(a) * dist)
	var rumo := atan2(pj.z - pos.z, pj.x - pos.x) + rng.randf_range(-0.6, 0.6)   # passa perto da Rachel
	var n := 1
	var r := rng.randf()
	if r > 0.5: n = 2
	if r > 0.75: n = 3
	var b := {"pos": pos, "rumo": rumo, "giro": 0.0, "alt": rng.randf_range(26.0, 40.0), "aves": [], "vel": rng.randf_range(8.0, 11.0)}
	var offs := [Vector2.ZERO, Vector2(-3.2, 2.6), Vector2(-3.2, -2.6)]
	for k in n:
		var ave := _ave()
		add_child(ave[0])
		b.aves.append({"no": ave[0], "asa_e": ave[1], "asa_d": ave[2], "off": offs[k], "fase": rng.randf() * TAU,
			"batendo": rng.randf_range(0.0, 2.0)})
	return b

# ave low poly escura: corpo, cabeça, cauda e duas asas que batem (envergadura ~1,7 m)
func _ave() -> Array:
	var cor: Material = m.mat("", 1.0, Color(0.16, 0.13, 0.12))
	var no := Node3D.new()
	var corpo_no := Node3D.new(); corpo_no.scale = Vector3(1.6, 1.6, 1.6); no.add_child(corpo_no)   # ave grande (gavião)
	var st: SurfaceTool = m._st()
	m._caixa(st, Vector3(0, 0, 0), Vector3(0.16, 0.14, 0.62))         # corpo (frente = -Z)
	m._caixa(st, Vector3(0, 0.03, -0.38), Vector3(0.11, 0.1, 0.14))   # cabeça
	m._tri(st, Vector3(0, 0, 0.28), Vector3(-0.17, 0, 0.62), Vector3(0.17, 0, 0.62), 1, 1)   # cauda
	var corpo := MeshInstance3D.new(); corpo.mesh = st.commit(); corpo.material_override = cor; corpo_no.add_child(corpo)
	var asas := []
	for lado in [-1.0, 1.0]:
		var piv := Node3D.new(); piv.position = Vector3(0.07 * lado, 0.04, -0.05); corpo_no.add_child(piv)
		var sa: SurfaceTool = m._st()
		m._quad(sa, Vector3(0, 0, -0.16), Vector3(0.45 * lado, 0, -0.14), Vector3(0.45 * lado, 0, 0.14), Vector3(0, 0, 0.16), 1, 1)
		m._quad(sa, Vector3(0.45 * lado, 0, -0.14), Vector3(0.85 * lado, 0, -0.02), Vector3(0.85 * lado, 0, 0.1), Vector3(0.45 * lado, 0, 0.14), 1, 1)
		var w := MeshInstance3D.new(); w.mesh = sa.commit(); w.material_override = cor; piv.add_child(w)
		asas.append(piv)
	return [no, asas[0], asas[1]]

# ---------- a cada quadro ----------
func _process(delta: float) -> void:
	if m == null or m.jogador == null: return
	var pj: Vector3 = m.jogador.global_position
	var p2 := Vector2(pj.x, pj.z)
	_t_proc -= delta
	if _t_proc <= 0.0:
		_t_proc = 1.0
		var md := 1e9
		for r in _rios.size():
			var res := _mais_perto_no_rio(p2, r); _s_perto[r] = res[0]
			if res[1] < md: md = res[1]; _rio_perto = r
		for i in cardumes.size():                    # cardume longe da Rachel renasce perto dela
			var c: Dictionary = cardumes[i]
			var cp := _centro_cardume(c)
			if cp.distance_to(p2) > 110.0 and (not c.lago or p2.distance_to(Vector2(Regiao.LAGO.x, Regiao.LAGO.y)) < 160.0 or rng.randf() < 0.2):
				cardumes[i] = _novo_cardume(c.lago)
		for i in bandos.size():
			var b: Dictionary = bandos[i]
			if Vector2(b.pos.x, b.pos.z).distance_to(p2) > 230.0:
				for a in b.aves: a.no.queue_free()
				bandos[i] = _novo_bando(false)
	_peixes(delta, p2)
	_passaros(delta)

func _centro_cardume(c: Dictionary) -> Vector2:
	if c.lago: return Vector2(Regiao.LAGO.x, Regiao.LAGO.y) + Vector2(cos(c.ang), sin(c.ang)) * c.raio
	return _no_rio(c.s, c.rio)[0]

func _peixes(delta: float, p2: Vector2) -> void:
	var idx := 0
	var tempo := Lobo._relogio()
	for c in cardumes:
		# nado: os grandes deslizam devagar; os pequenos dão arrancadas e param um instante
		c.pausa -= delta
		var vel: float = c.vel
		if not c.grande:
			if c.pausa <= 0.0 and rng.randf() < delta * 0.4: c.pausa = rng.randf_range(0.4, 1.2); c.arranque = 0.0
			c.arranque = minf(1.0, c.arranque + delta * 1.5)
			vel *= 0.15 if c.pausa > 0.0 else (0.6 + 0.8 * (1.0 - c.arranque) + 0.4)
		c.lado = move_toward(c.lado, c.alvo_lado, delta * 0.08 * (1.0 if c.grande else 3.0))
		if absf(c.lado - c.alvo_lado) < 0.02: c.alvo_lado = rng.randf_range(-0.7, 0.7)
		var centro: Vector2; var dir: Vector2; var y: float; var meia: float
		if c.lago:
			c.ang += c.dir * vel * delta / c.raio
			var q := Vector2(cos(c.ang), sin(c.ang))
			centro = Vector2(Regiao.LAGO.x, Regiao.LAGO.y) + q * (c.raio + c.lado * 4.0)
			dir = Vector2(-q.y, q.x) * c.dir; y = reg.nivel_lago() - 0.08; meia = 0.0
		else:
			c.s += c.dir * vel * delta
			var rio: Array = _rios[c.rio]
			if c.s < 5.0 or c.s > float(rio[2]) - 5.0: c.dir = -c.dir
			var r := _no_rio(c.s, c.rio)
			var t: float = r[2]
			meia = float(rio[3].call(t)) * 0.5 - 1.3
			var nrm := Vector2(-r[1].y, r[1].x)
			centro = r[0] + nrm * c.lado * meia; dir = r[1] * c.dir; y = float(rio[4].call(t)) - 0.08
		if centro.distance_to(p2) > 120.0: continue
		var lado := Vector2(-dir.y, dir.x)
		for mb in c.membros:
			if idx >= MAX_PEIXES: break
			var off: Vector2 = mb.off
			var wob := Vector2(sin(tempo * 1.7 + mb.fase) * 0.15, cos(tempo * 1.3 + mb.fase) * 0.2)
			var q2: Vector2 = centro + dir * (off.x + wob.x) + lado * (off.y + wob.y)
			var ang := atan2(-dir.y, dir.x)
			var tam: float = mb.tam
			var b := Basis(Vector3.UP, ang).scaled(Vector3(tam, 1.0, tam))
			_mm.set_instance_transform(idx, Transform3D(b, Vector3(q2.x, y + 0.03, q2.y)))
			_mm.set_instance_custom_data(idx, Color(mb.fase, 4.0 if c.grande else 14.0, 0.6 if c.grande else 0.7, 0.0))
			idx += 1
	_mm.visible_instance_count = idx

func _passaros(delta: float) -> void:
	for b in bandos:
		# voa reto com curvas suaves, de vez em quando gira um pouco
		b.giro = lerpf(b.giro, sin(Lobo._relogio() * 0.13 + b.alt) * 0.12, delta * 0.5)
		b.rumo += b.giro * delta
		var fr := Vector3(cos(b.rumo), 0.0, sin(b.rumo))
		b.pos += fr * b.vel * delta
		var chao := maxf(reg.altura(b.pos.x, b.pos.z), 0.0)
		var alvo_y: float = chao + b.alt
		b.pos.y = alvo_y if b.pos.y == 0.0 else lerpf(b.pos.y, alvo_y, delta * 0.3)
		var lado := Vector3(-fr.z, 0.0, fr.x)
		for a in b.aves:
			var off: Vector2 = a.off
			var no: Node3D = a.no
			no.global_position = b.pos + fr * off.x + lado * off.y + Vector3(0, sin(Lobo._relogio() * 0.8 + a.fase) * 0.6, 0)
			no.rotation = Vector3(0.0, atan2(-fr.x, -fr.z), -b.giro * 2.5)
			# bate as asas um tempo e plana outro
			a.batendo -= delta
			if a.batendo < -2.6: a.batendo = rng.randf_range(1.0, 2.2)
			a.fase += delta * (9.0 if a.batendo > 0.0 else 0.0)
			var asa := sin(a.fase) * 0.75 if a.batendo > 0.0 else 0.12
			a.asa_e.rotation.z = -asa; a.asa_d.rotation.z = asa

# O mapa novo (docs/MAPA_NOVO.md): Altamar e a Vila do Vale construídas do zero, só com peças do pacote POLYGON
# Fantasy Kingdom (Synty). Usa as ferramentas do mundo (casas, colisões, placas, postes, freiras) e preenche as
# posições que os sistemas do jogo usam (lojas, taverna, ferraria, estábulo, porto, píer).
extends RefCounted
class_name Reino

var m                                   # o mundo
var rng := RandomNumberGenerator.new()

func construir(mundo) -> void:
	m = mundo; rng.seed = 2026
	_altamar()
	_vila()
	_estabulo()
	_cercas_dos_campos()
	_enfeitar_cidade()
	_enfeitar_vila_e_campos()
	_natureza()
	_lugares_novos()
	_cidadaos()

# ---------- ajudas ----------
func _y(p: Vector2) -> float: return m.reg.altura(p.x, p.y)
func _por(nome: String, p: Vector2, ang: float, esc := 1.0, colisao := true, y := INF) -> void:
	Synty.por(m, nome, Vector3(p.x, (_y(p) if y == INF else y), p.y), ang, esc, colisao)
# ângulo para a porta (+Z do modelo) ficar virada para "alvo"
static func _virado(de: Vector2, alvo: Vector2) -> float:
	var d := alvo - de; return atan2(d.x, d.y)
# muralha de castelo (peças de 5 m esticadas) de a até b, com colisão
func _muro(a: Vector2, b: Vector2, y: float, alt := 2.2, esp := 3.0, fundo := 1.0) -> void:
	var dl := (b - a).normalized(); var comp := a.distance_to(b)
	if comp < 0.5: return
	var n := maxi(1, int(round(comp / 10.0))); var lp := comp / n
	for i in n:
		var q := a + dl * (lp * (i + 0.5))
		Synty.por3(m, "SM_Bld_Castle_Wall_04", Vector3(q.x, y - fundo, q.y), atan2(-dl.y, dl.x), Vector3(lp / 5.0, alt, esp), false)
	var meio := (a + b) * 0.5
	m._colisor_caixa(Vector3(meio.x, y - fundo, meio.y), Vector3(esp * 1.1, alt * 5.0, comp), atan2(dl.x, dl.y))
func _torre(p: Vector2, y: float, grande := false) -> void:
	if grande: Synty.por(m, "SM_Bld_Preset_Tower_01_Optimized", Vector3(p.x, y - 1.0, p.y), rng.randf() * TAU, 1.25, true)
	else:
		Synty.por(m, "SM_Bld_Castle_Wall_Tower_L_01", Vector3(p.x, y - 1.0, p.y), 0.0, 2.4, false)
		m._colisor_cilindro(Vector3(p.x, y - 1.0, p.y), 4.4, 14.0)

# casas em fila dos dois lados de uma rua (porta virada para a rua)
func _fila(a: Vector2, b: Vector2, recuo: float, passo: float, y_de: Callable, pular: Callable, lojas := []) -> void:
	var dl := (b - a).normalized(); var n := Vector2(-dl.y, dl.x); var comp := a.distance_to(b)
	var s := passo * 0.5
	while s < comp:
		for lado in [-1.0, 1.0]:
			var q: Vector2 = a + dl * s + n * lado * recuo
			if pular.call(q): continue
			if m.perto_de_casa(q.x, q.y, 6.0) or m.perto_de_lugar(q.x, q.y, 5.0): continue
			var w := rng.randf_range(8.5, 11.0); var d := rng.randf_range(8.0, 10.0)
			var ang := _virado(q, q - n * lado)
			m._casa(Vector3(q.x, y_de.call(q), q.y), ang, w, d, 7.0, null, null, true)
			if not lojas.is_empty():
				var nome: String = lojas.pop_front()
				m._placa(Vector3(q.x, y_de.call(q), q.y), ang, w, d, 7.0, nome)
				m.cidade_lojas.append([nome, q - n * lado * (d * 0.5 + 1.5)])
		s += passo + rng.randf_range(-1.0, 2.0)

# ---------- Altamar ----------
func _altamar() -> void:
	var C: Rect2 = Regiao.CIDADE
	var x0 := C.position.x; var x1 := C.end.x; var z0 := C.position.y; var z1 := C.end.y
	var zc := Regiao.CIDADE_C.y
	m.cidade_pos = Regiao.CIDADE_C; m.cidade_y = Regiao.ALTURA_CIDADE
	var yc := func(q: Vector2) -> float: return Regiao.altura_cidade(q.x, q.y)
	# ---- muralhas (norte, oeste com o portão, sul) e um paredão baixo no cais
	var porta := 9.0
	_muro(Vector2(x0, z0), Vector2(x1 - 20.0, z0), Regiao.ALTURA_CIDADE)
	_muro(Vector2(x0, z1), Vector2(x1 - 20.0, z1), Regiao.ALTURA_CIDADE)
	_muro(Vector2(x0, z0), Vector2(x0, zc - porta), Regiao.ALTURA_CIDADE)
	_muro(Vector2(x0, zc + porta), Vector2(x0, z1), Regiao.ALTURA_CIDADE)
	for t in [Vector2(x0, z0), Vector2(x0, z1)] + _ao_longo(Vector2(x0, z0), Vector2(x1 - 20.0, z0), 60.0) + _ao_longo(Vector2(x0, z1), Vector2(x1 - 20.0, z1), 60.0) \
			+ _ao_longo(Vector2(x0, z0), Vector2(x0, zc - porta - 12.0), 60.0) + _ao_longo(Vector2(x0, zc + porta + 12.0), Vector2(x0, z1), 60.0):
		_torre(t, Regiao.altura_cidade(t.x, t.y))
	# ---- Portão Oeste: arco, duas torres prontas, estátuas de cavaleiro e bandeiras
	var pg := Vector2(x0, zc)
	Synty.por3(m, "SM_Bld_Castle_Wall_Archway_01", Vector3(pg.x, Regiao.ALTURA_CIDADE - 1.0, pg.y), PI * 0.5, Vector3(3.8, 2.8, 6.0), false)
	_torre(pg + Vector2(0, -porta - 6.0), Regiao.ALTURA_CIDADE, true); _torre(pg + Vector2(0, porta + 6.0), Regiao.ALTURA_CIDADE, true)
	for lado in [-1.0, 1.0]:
		for k in 2:
			var q := pg + Vector2(-24.0 - k * 18.0, lado * 9.5)
			_por("SM_Prop_Statue_Knight_01", q, _virado(q, q + Vector2(0, -lado)), 2.2, true)
		_por("SM_Prop_Battle_Banner_01", pg + Vector2(6.0, lado * 7.5), PI * 0.5, 2.5, false)
	# ---- degraus entre os níveis: paredões baixos (com passagem nas ruas)
	for xd in [Regiao.X_MERCADO, Regiao.X_PORTO]:
		var segs := [[z0 + 4.0, zc - 9.0], [zc + 9.0, z1 - 4.0]]
		for sg in segs:
			var za: float = sg[0]; var zb: float = sg[1]
			if xd == Regiao.X_MERCADO and za < zc: za = maxf(za, Regiao.CASTELO.y + 90.0)
			if zb - za > 8.0: _muro(Vector2(xd - 9.0, za), Vector2(xd - 9.0, zb), Regiao.altura_cidade(xd - 12.0, (za + zb) * 0.5), 0.9, 1.6, 0.6)
	# ---- castelo no morro (noroeste): torre de menagem, quatro torres e muralha em volta
	var cs := Regiao.CASTELO; var yk := Regiao.ALTURA_CASTELO
	Synty.por(m, "SM_Bld_Preset_Tower_01_Optimized", Vector3(cs.x, yk - 1.0, cs.y), 0.0, 2.7, true)
	var cantos := [cs + Vector2(-38, -32), cs + Vector2(38, -32), cs + Vector2(38, 32), cs + Vector2(-38, 32)]
	for i in 4:
		Synty.por(m, "SM_Bld_Preset_Tower_01_Optimized", Vector3(cantos[i].x, yk - 1.5, cantos[i].y), 0.0, 1.35, true)
		var a: Vector2 = cantos[i]; var b: Vector2 = cantos[(i + 1) % 4]
		if i == 2:                                          # lado sul: portão do castelo no meio
			var meio := (a + b) * 0.5
			_muro(a, meio + Vector2(8, 0), yk, 2.4); _muro(meio - Vector2(8, 0), b, yk, 2.4)
			Synty.por3(m, "SM_Bld_Castle_Wall_Archway_01", Vector3(meio.x, yk - 1.0, meio.y), 0.0, Vector3(3.2, 2.6, 4.0), false)
		else: _muro(a, b, yk, 2.4)
	m.lugares.append([cs, 70.0])
	# ---- catedral (nível alto, ao norte da avenida) com praça na frente
	var cat := Vector2(1860.0, 30.0)
	m._casa(Vector3(cat.x, Regiao.ALTURA_CIDADE, cat.y), 0.0, 19.0, 33.0, 15.0, null, null, true, "SM_Bld_Preset_Church_01_B_Optimized", 3.0)
	m._freira("Irmã Odília", cat + Vector2(0, 21.0), Vector2(0, 1), Regiao.ALTURA_CIDADE, 4343)
	m.lugares.append([cat + Vector2(0, 28.0), 14.0])
	# ---- bairro dos magos (nível alto, ao sul): torre grande e duas menores
	var tm := Vector2(1830.0, 215.0)
	Synty.por(m, "SM_Bld_Preset_Tower_01_Optimized", Vector3(tm.x, Regiao.ALTURA_CIDADE - 1.0, tm.y), 0.0, 2.0, true)
	m._particulas_magia(Vector3(tm.x, Regiao.ALTURA_CIDADE + 46.0, tm.y))
	for q in [tm + Vector2(40, 30), tm + Vector2(-35, 35)]:
		Synty.por(m, "SM_Bld_Preset_Tower_01_Optimized", Vector3(q.x, Regiao.ALTURA_CIDADE - 1.0, q.y), rng.randf() * TAU, 1.2, true)
	m.lugares.append([tm, 26.0])
	# ---- praça do mercado: chafariz, barracas em roda, bancos e floreiras
	var pr := Regiao.PRACA; var yp := Regiao.NIVEL_MERCADO
	Synty.por(m, "SM_Env_Fountain_01", Vector3(pr.x, yp - 0.1, pr.y), 0.0, 3.2, false)
	m._colisor_cilindro(Vector3(pr.x, yp - 0.3, pr.y), 7.5, 2.0)
	var barracas := ["SM_Prop_Market_Stall_01", "SM_Prop_Market_Stall_02", "SM_Prop_Market_Stall_03", "SM_Prop_Market_Stall_05",
		"SM_Prop_Market_Stall_06", "SM_Prop_Market_Stall_07", "SM_Prop_Market_Stall_08", "SM_Prop_Market_Stall_09"]
	for k in 14:
		var a := TAU * (k + 0.5) / 14.0
		var q := pr + Vector2(cos(a), sin(a)) * 19.0
		if absf(q.y - pr.y) < 5.0 or absf(q.x - pr.x) < 5.0: continue          # livre nas ruas
		_por(barracas[k % barracas.size()], q, _virado(q, pr), 1.0, true, yp)
	for k in 6:
		var a := TAU * k / 6.0 + 0.5
		var q := pr + Vector2(cos(a), sin(a)) * 11.0
		_por("SM_Prop_Bench_Seat_01", q, _virado(q, pr) + PI * 0.5, 1.0, false, yp)
	m.lugares.append([pr, 25.0])
	# ---- taverna (Cidade Velha, ao sul da praça) e o porto
	m.taverna_pos = Vector2(2000.0, 160.0)
	m._casa(Vector3(m.taverna_pos.x, Regiao.NIVEL_MERCADO, m.taverna_pos.y), PI, 14.0, 14.0, 9.0, null, null, true, "SM_Bld_Preset_Tavern_01_Optimized", 1.0)
	m._placa(Vector3(m.taverna_pos.x, Regiao.NIVEL_MERCADO, m.taverna_pos.y), PI, 14.0, 14.0, 9.0, "taverna")
	m.cidade_lojas.append(["taverna", m.taverna_pos + Vector2(0, -9.0)])
	_porto(x1, zc)
	# ---- casas em filas pelas ruas: avenida (portão → praça → cais), rua do mercado e duas ruas paralelas
	var pular := func(q: Vector2) -> bool:
		return not C.grow(-12.0).has_point(q) or q.distance_to(Regiao.CASTELO) < 95.0 or Regiao.rua_cidade(q.x, q.y) < 7.5 \
			or absf(q.x - Regiao.X_MERCADO) < 14.0 or absf(q.x - Regiao.X_PORTO) < 14.0
	var lojas := ["banco", "armas", "armaduras", "alquimia", "alfaiate", "joalheiro", "estalagem", "ferreiro"]
	_fila(Vector2(x0 + 20.0, zc), Vector2(pr.x - 30.0, zc), 15.0, 14.0, yc, pular)
	_fila(Vector2(pr.x - 26.0, zc), Vector2(pr.x + 26.0, zc), 33.0, 13.0, yc, pular, lojas)       # lojas viradas para a praça
	_fila(Vector2(pr.x, z0 + 20.0), Vector2(pr.x, z1 - 20.0), 15.0, 14.0, yc, pular, lojas)
	_fila(Vector2(pr.x + 30.0, zc), Vector2(x1 - 10.0, zc), 15.0, 15.0, yc, pular)
	for zr in Regiao.RUAS_Z:
		_fila(Vector2(x0 + 16.0, zr), Vector2(x1 - 16.0, zr), 13.0, 13.0, yc, pular)
	for xr in Regiao.RUAS_X:
		_fila(Vector2(xr, z0 + 16.0), Vector2(xr, z1 - 16.0), 13.0, 13.0, yc, pular)
	# ---- miolo dos quarteirões: mais casas (viradas para a rua mais perto), deixando becos entre elas
	for xx in range(int(x0) + 18, int(x1) - 12, 12):
		for zz in range(int(z0) + 18, int(z1) - 12, 12):
			var q := Vector2(xx + rng.randf_range(-2.0, 2.0), zz + rng.randf_range(-2.0, 2.0))
			if pular.call(q) or rng.randf() < 0.08: continue
			if m.perto_de_casa(q.x, q.y, 4.8) or m.perto_de_lugar(q.x, q.y, 5.0): continue
			m._casa(Vector3(q.x, yc.call(q), q.y), _rumo_rua(q), rng.randf_range(7.5, 9.5), rng.randf_range(7.0, 9.0), 6.0, null, null, true)
	# ---- postes e árvores pelas ruas principais
	for xx in range(int(x0) + 30, int(x1) - 10, 34):
		for lado in [-1.0, 1.0]:
			var q := Vector2(xx, zc + lado * 8.0)
			if q.distance_to(pr) > 30.0: m._poste_em(q, Vector2(xx, zc))
	for zz in range(int(z0) + 30, int(z1) - 10, 36):
		var q := Vector2(pr.x + 8.0, zz)
		if q.distance_to(pr) > 30.0: m._poste_em(q, Vector2(pr.x, zz))
	for q in [cat + Vector2(-16, 30), cat + Vector2(16, 30), tm + Vector2(20, -24), tm + Vector2(-24, -20), Vector2(1790, 110), Vector2(1790, 160)]:
		m.arvores_cidade.append([Vector3(q.x, Regiao.altura_cidade(q.x, q.y) - 0.2, q.y), rng.randf_range(0.8, 1.1)])
		m._colisor_cilindro(Vector3(q.x, Regiao.altura_cidade(q.x, q.y), q.y), 0.35, 4.0)
	m.lugares.append([Regiao.CIDADE_C, 300.0])

# ângulo para a porta ficar virada para a rua mais perto
func _rumo_rua(q: Vector2) -> float:
	var melhor := INF; var alvo := q + Vector2(0, 1)
	for rz in Regiao.RUAS_Z + [Regiao.CIDADE_C.y]:
		if absf(q.y - rz) < melhor: melhor = absf(q.y - rz); alvo = Vector2(q.x, rz)
	for rx in Regiao.RUAS_X + [Regiao.PRACA.x]:
		if absf(q.x - rx) < melhor: melhor = absf(q.x - rx); alvo = Vector2(rx, q.y)
	return _virado(q, alvo)

func cat_pos() -> Vector2: return Vector2(1860.0, 30.0)
func tm_pos() -> Vector2: return Vector2(1830.0, 215.0)

func _ao_longo(a: Vector2, b: Vector2, passo: float) -> Array:
	var r := []; var comp := a.distance_to(b); var n := int(comp / passo)
	for i in range(1, n + 1): r.append(a.lerp(b, float(i) / (n + 1)))
	return r

# cais de madeira entrando no mar, barcos, caixotes e barris
func _porto(x1: float, zc: float) -> void:
	for zz in [zc - 120.0, zc, zc + 120.0]:
		for i in 9:
			var x := x1 - 8.0 + i * 5.4
			Synty.por3(m, "SM_Bld_Bridge_01", Vector3(x, Regiao.NIVEL_PORTO + 0.4, zz), 0.0, Vector3(1.0, 1.5, 1.3), false)
		m._colisor_caixa(Vector3(x1 + 14.0, Regiao.NIVEL_PORTO + 0.1, zz), Vector3(7.0, 0.6, 50.0), PI * 0.5)
		for lado in [-1.0, 1.0]:
			var b := Vector2(x1 + 10.0 + rng.randf_range(0.0, 25.0), zz + lado * 7.5)
			Synty.por(m, "SM_Veh_Boat_Dinghy_01", Vector3(b.x, 0.25, b.y), PI * 0.5 + rng.randf_range(-0.3, 0.3), 1.6, false)
		for k in 3:
			var q := Vector2(x1 - 20.0 + k * 4.0, zz + rng.randf_range(-9.0, 9.0))
			_por(["SM_Prop_Crate_Stack_01", "SM_Prop_Barrel_Stack_01", "SM_Prop_Sack_Stack_01"][k], q, rng.randf() * TAU, 1.0, true, Regiao.NIVEL_PORTO)
	m.porto_pos = Vector2(x1 - 10.0, zc)
	m.lugares.append([m.porto_pos + Vector2(20, 0), 30.0])

# ---------- Vila do Vale ----------
func _vila() -> void:
	var v := Regiao.VILA
	var yv := func(q: Vector2) -> float: return 0.0           # _casa aplaina o chão sozinha
	# praça: poço, barraquinhas e bancos
	_por("SM_Prop_Well_01", v, 0.0, 1.4, true)
	for k in 3:
		var a := PI * 0.25 + k * PI * 0.5
		var q := v + Vector2(cos(a), sin(a)) * 9.0
		_por(["SM_Prop_Market_Stall_04", "SM_Prop_Market_Stall_06", "SM_Prop_Market_Stall_01"][k], q, _virado(q, v), 1.0, true)
	_por("SM_Prop_Bench_Seat_02", v + Vector2(-6, 6), PI * 0.25, 1.0, false)
	m.lugares.append([v, 14.0])
	# taverna, igreja, ferraria e moinho
	var tv := v + Vector2(-34.0, -22.0)
	m._casa(Vector3(tv.x, 0, tv.y), 0.0, 14.0, 14.0, 9.0, null, null, false, "SM_Bld_Preset_Tavern_01_Optimized", 1.0)
	m._placa(Vector3(tv.x, _y(tv), tv.y), 0.0, 14.0, 14.0, 9.0, "taverna")
	var ig := v + Vector2(44.0, -40.0)
	m._casa(Vector3(ig.x, 0, ig.y), 0.0, 7.0, 11.0, 10.0, null, null, false, "SM_Bld_Preset_Church_01_A_Optimized", 1.3)
	m.igreja_vila = [ig, Vector2(0, 1), 14.0]
	var fe := v + Vector2(-82.0, 22.0)
	m._casa(Vector3(fe.x, 0, fe.y), PI, 12.0, 10.0, 9.0, null, null, false, "SM_Bld_Preset_Blacksmith_01_Optimized", 1.0)
	# bigorna e forja do lado de fora (o ferreiro trabalha na frente, virado para a rua)
	m.ferraria_ang = 0.0; m.ferraria_pos = fe + Vector2(-1.2, -9.5)
	var big: Vector2 = m.ferraria_pos + Vector2(1.2, -0.4)
	_por("SM_Prop_Anvil_01", big, PI * 0.5, 1.6, true)
	_por("SM_Prop_Forge_01", big + Vector2(-4.0, -1.0), 0.0, 1.0, true)
	m.lugares.append([m.ferraria_pos, 6.0])
	var mo := v + Vector2(150.0, -95.0)
	m._casa(Vector3(mo.x, 0, mo.y), _virado(mo, v), 10.0, 10.0, 15.0, null, null, false, "SM_Bld_Preset_House_Windmill_01_Optimized", 1.0)
	# casas ao longo da rua (oeste–leste) e das saídas norte e sul
	var pular := func(q: Vector2) -> bool:
		return q.distance_to(v) < 16.0 or m.reg.dist_rio(q.x, q.y) < 16.0 or m.reg.campo_em(q.x, q.y) >= 0
	var ruas: Array = [m.reg.estradas[m.reg.estrada_real], m.reg.estradas[2], m.reg.estradas[1], m.reg.estradas[0]]
	for e in ruas:
		var acum := 0.0
		for i in e.size() - 1:
			var a: Vector2 = e[i]; var b: Vector2 = e[i + 1]
			if a.distance_to(v) > 150.0: break
			var b2 := a + (b - a).limit_length(maxf(150.0 - acum, 0.0))
			_fila(a, b2, 13.0, 15.0, yv, pular)
			acum += a.distance_to(b)
	# píer no rio, a leste da vila
	var pp := Vector2(444.0, 470.0)
	for i in 3: Synty.por3(m, "SM_Bld_Bridge_01", Vector3(pp.x - 6.0 + i * 5.4, m.reg.nivel_rio(0.6) + 0.6, pp.y), 0.0, Vector3(1.0, 1.2, 0.6), false)
	m.pier_pos = pp
	# caixotes, barris e feno pela vila
	for k in 10:
		var q := v + Vector2(rng.randf_range(-90, 90), rng.randf_range(-40, 40))
		if m.reg.dist_estrada(q.x, q.y) < 4.0 or m.perto_de_casa(q.x, q.y, 3.0): continue
		_por(["SM_Prop_Barrel_Stack_01", "SM_Prop_Crate_Stack_02", "SM_Prop_Hay_Bale_01", "SM_Prop_Wood_Pile_01", "SM_Prop_Sack_Stack_02"][k % 5], q, rng.randf() * TAU, 1.0, true)
	m.lugares.append([v, 30.0])

# ---------- estábulo (fora do Portão Oeste) ----------
func _estabulo() -> void:
	var e := Regiao.ESTABULO; m.estabulo_pos = e
	var y: float = m.reg.aplanar(e + Vector2(-8.0, 3.0), Vector2(26.0, 14.0), 0.0, 6.0)
	m.reg.planos[-1].append(false)
	m.lugares.append([e + Vector2(-8.0, 3.0), 28.0])
	Synty.por(m, "SM_Bld_Preset_Stables_01_Optimized", Vector3(e.x, y, e.y - 6.0), 0.0, 1.2, true)
	var hc := e + Vector2(-25.0, -5.0)
	m._casa(Vector3(hc.x, y, hc.y), 0.0, 8.0, 7.0, 3.6, null, null, true, "SM_Bld_Preset_Hut_01_Optimized", 1.0)
	# cercado com cerca do pacote (aberto do lado da casa)
	var cx0 := e.x - 12.0; var cx1 := e.x + 12.0; var cz0 := e.y + 1.0; var cz1 := e.y + 15.0
	for seg in [[Vector2(cx0, cz0 + 5.0), Vector2(cx0, cz1)], [Vector2(cx0, cz1), Vector2(cx1, cz1)], [Vector2(cx1, cz1), Vector2(cx1, cz0)]]:
		_cerca(seg[0], seg[1], y)
	for k in 3: _por("SM_Prop_Hay_Bale_01", e + Vector2(10.5, -2.0 + k * 1.4), 0.0, 1.0, true, y)
	var cores := ["cavalo_branco", "cavalo_marrom", "cavalo_preto", "cavalo_dourado"]
	for i in 4:
		var cv: Node3D = m.cavalo(cores[i]); m.raiz.add_child(cv)
		cv.position = Vector3(e.x - 7.0 + i * 5.5, y, e.y + 7.5 + (i % 2) * 3.0); cv.rotation.y = 0.5 - i * 0.45
		m._colisor_caixa(Vector3(cv.position.x, y, cv.position.z), Vector3(1.0, 1.8, 2.6), cv.rotation.y)
	var npc := Morador.new(); npc.tipo = "forte"; npc.profissao = "cavalarico"
	npc.posto = hc + Vector2(5.5, 6.0); npc.olhar_posto = npc.posto + Vector2(0.6, 5.0)
	m.raiz.add_child(npc); npc.position = Vector3(npc.posto.x, y, npc.posto.y)
	npc.montar(m, 4242, npc.posto, 1.0)
	m.estabulo_npc = npc
	m._placa(Vector3(e.x + 13.2, y - 0.4, e.y + 16.0), PI * 0.5, 0.6, 0.6, 4.6, "estabulo")

# cerca do pacote de a até b (peças de 2,5 m), com colisão
func _cerca(a: Vector2, b: Vector2, y := INF) -> void:
	var dl := (b - a).normalized(); var comp := a.distance_to(b); var n := maxi(1, int(round(comp / 2.5)))
	for i in n:
		var q := a + dl * (comp * (i + 0.5) / n)
		Synty.por3(m, "SM_Prop_Fence_01", Vector3(q.x, (_y(q) if y == INF else y), q.y), atan2(-dl.y, dl.x), Vector3(comp / n / 2.5, 1.0, 1.0), false)
	var meio := (a + b) * 0.5
	m._colisor_caixa(Vector3(meio.x, (_y(meio) if y == INF else y), meio.y), Vector3(0.3, 1.3, comp), atan2(dl.x, dl.y))

# campos cercados (a cerca deixa uma porteira do lado mais perto da estrada)
func _cercas_dos_campos() -> void:
	for c in m.reg.campos:
		if c[2] < 30: continue                         # hortas pequenas ficam sem cerca
		var cc := Vector2(c[0], c[1]); var ang := deg_to_rad(c[4]); var hw: float = c[2] * 0.5 + 1.5; var hl: float = c[3] * 0.5 + 1.5
		var cantos := [Vector2(-hw, -hl), Vector2(hw, -hl), Vector2(hw, hl), Vector2(-hw, hl)]
		for i in 4:
			var a: Vector2 = cc + (cantos[i] as Vector2).rotated(ang); var b: Vector2 = cc + (cantos[(i + 1) % 4] as Vector2).rotated(ang)
			var meio := (a + b) * 0.5
			if m.reg.dist_estrada(meio.x, meio.y) < 4.0: continue
			var dl := (b - a).normalized(); var comp := a.distance_to(b)
			_cerca(a, meio - dl * 2.0); _cerca(meio + dl * 2.0, b)              # porteira no meio de cada lado
		# casinha do sítio perto do campo
		var q := cc + Vector2(hw + 12.0, 0).rotated(ang)
		if not m.perto_de_casa(q.x, q.y, 6.0) and m.reg.dist_estrada(q.x, q.y) > 8.0 and m.reg.dist_rio(q.x, q.y) > 14.0:
			m._casa(Vector3(q.x, 0, q.y), _virado(q, cc), 7.0, 7.0, 5.0)

# ---------- gente do pacote (cidadãos com as animações da Synty) ----------
const POVO := ["SM_Chr_Peasant_Male_01", "SM_Chr_Peasant_Female_01", "SM_Chr_Merchant_01", "SM_Chr_Hermit_01",
	"SM_Chr_Monk_01", "SM_Chr_Bartender_01", "SM_Chr_Blacksmith_Male_01", "SM_Chr_Blacksmith_Female_01", "SM_Chr_Rider_01"]
var _n_cid := 0
func _cidadao(tipo: String, p: Vector2, centro: Vector2, raio: float, fixo := false, olhar := Vector2.ZERO) -> void:
	if not Cidadao.existe(): return
	var c := Cidadao.new(); c.tipo = tipo; c.centro = centro; c.raio = raio; c.fixo = fixo; c.olhar = olhar
	m.raiz.add_child(c); c.position = Vector3(p.x, m.reg.altura(p.x, p.y), p.y)
	c.montar(m, 9000 + _n_cid); _n_cid += 1

func _multidao(centro: Vector2, raio: float, n: int, tipos: Array = POVO) -> void:
	for i in n:
		for t in 10:
			var a := rng.randf() * TAU; var q := centro + Vector2(cos(a), sin(a)) * rng.randf_range(2.0, raio)
			if not m.perto_de_casa(q.x, q.y, 1.2):
				_cidadao(tipos[rng.randi() % tipos.size()], q, centro, raio); break

func _cidadaos() -> void:
	var pr := Regiao.PRACA; var zc := Regiao.CIDADE_C.y; var x0 := Regiao.CIDADE.position.x
	_multidao(pr, 34.0, 22)                                                   # praça do mercado cheia
	_multidao(Vector2(1840.0, zc), 40.0, 10)                                  # avenida do portão
	_multidao(Vector2(2120.0, zc), 40.0, 8, ["SM_Chr_Peasant_Male_01", "SM_Chr_Merchant_01", "SM_Chr_Hermit_01", "SM_Chr_Rider_01"])   # porto
	_multidao(Vector2(2000.0, 185.0), 30.0, 8)                               # Cidade Velha (taverna)
	_multidao(Regiao.VILA, 60.0, 14, ["SM_Chr_Peasant_Male_01", "SM_Chr_Peasant_Female_01", "SM_Chr_Hermit_01", "SM_Chr_Blacksmith_Male_01", "SM_Chr_Monk_01"])
	# guardas no Portão Oeste e no castelo
	for lado in [-1.0, 1.0]:
		var q := Vector2(x0 + 4.0, zc + lado * 6.5)
		_cidadao("SM_Chr_Soldier_Male_01" if lado < 0 else "SM_Chr_Soldier_Female_01", q, q, 1.0, true, q + Vector2(-5, 0))
		var q2 := Vector2(x0 - 10.0, zc + lado * 6.0)
		_cidadao("SM_Chr_Soldier_Male_01", q2, q2, 1.0, true, q2 + Vector2(-5, 0))
	var cs := Regiao.CASTELO + Vector2(0, 38.0)
	for lado in [-1.0, 1.0]: _cidadao("SM_Chr_Soldier_Male_01", cs + Vector2(lado * 6.0, 4.0), cs, 1.0, true, cs + Vector2(lado * 6.0, 12.0))
	_cidadao("SM_Chr_King_01", Regiao.CASTELO + Vector2(-3, 24), Regiao.CASTELO + Vector2(0, 24), 6.0)
	_cidadao("SM_Chr_Queen_01", Regiao.CASTELO + Vector2(3, 24), Regiao.CASTELO + Vector2(0, 24), 6.0)
	_cidadao("SM_Chr_Prince_01", Regiao.CASTELO + Vector2(-8, 28), Regiao.CASTELO + Vector2(0, 26), 12.0)
	_cidadao("SM_Chr_Princess_01", Regiao.CASTELO + Vector2(8, 28), Regiao.CASTELO + Vector2(0, 26), 12.0)
	# patrulha pela avenida
	for k in 2: _cidadao("SM_Chr_Soldier_Male_01", Vector2(1830.0 + k * 100.0, zc + 4.0), Vector2(1900.0, zc), 70.0)
	# vendedores nas barracas (parados, virados para fora) e figuras da praça
	for k in 14:
		var a := TAU * (k + 0.5) / 14.0
		var q := pr + Vector2(cos(a), sin(a)) * 21.5
		if absf(q.y - pr.y) < 5.0 or absf(q.x - pr.x) < 5.0 or k % 2 == 1: continue
		_cidadao("SM_Chr_Merchant_01" if k % 4 == 0 else "SM_Chr_Peasant_Female_01", q, q, 1.0, true, pr)
	_cidadao("SM_Chr_Jester_01", pr + Vector2(12, 4), pr, 10.0)
	_cidadao("SM_Chr_FortuneTeller_01", pr + Vector2(-20, -14), pr + Vector2(-20, -14), 1.0, true, pr)
	_cidadao("SM_Chr_Mage_01", tm_pos() + Vector2(0, -12), tm_pos(), 16.0)
	_cidadao("SM_Chr_Priest_01", cat_pos() + Vector2(0, 26), cat_pos() + Vector2(0, 30), 8.0)
	_cidadao("SM_Chr_Nun_01", cat_pos() + Vector2(6, 30), cat_pos() + Vector2(0, 30), 8.0)
	_cidadao("SM_Chr_Bartender_01", m.taverna_pos + Vector2(3.0, -9.5), m.taverna_pos + Vector2(3.0, -9.5), 1.0, true, m.taverna_pos + Vector2(3.0, -20.0))
	# camponeses nos campos
	for c in m.reg.campos:
		if c[2] < 30: continue
		var cc := Vector2(c[0], c[1])
		_cidadao("SM_Chr_Peasant_Male_01" if rng.randf() < 0.6 else "SM_Chr_Peasant_Female_01", cc, cc, c[3] * 0.4)

# ======================================================================================================
# TUDO DO PACOTE: enfeites da cidade, da vila e dos campos, natureza e lugares para explorar
# ======================================================================================================
func _sorte(lista: Array) -> String: return lista[rng.randi() % lista.size()]
func _livre(q: Vector2, folga := 2.0) -> bool:
	return not m.perto_de_casa(q.x, q.y, folga) and m.reg.agua(q.x, q.y) == 0.0 and m.reg.dist_estrada(q.x, q.y) > 3.5

func _enfeitar_cidade() -> void:
	var C: Rect2 = Regiao.CIDADE; var zc := Regiao.CIDADE_C.y; var pr := Regiao.PRACA
	var yc := func(q: Vector2) -> float: return Regiao.altura_cidade(q.x, q.y)
	# na porta das casas: floreiras, barris, caixotes, sacos, vasos; atrás: varais
	for ca in m.casas:
		var pos: Vector3 = ca[0]; var ang: float = ca[1]; var d: float = ca[3]
		if not C.has_point(Vector2(pos.x, pos.z)): continue
		var fr := Vector2(sin(ang), cos(ang)); var ld := Vector2(fr.y, -fr.x)
		var porta := Vector2(pos.x, pos.z) + fr * (d * 0.5 + 1.4)
		if rng.randf() < 0.75:
			var q := porta + ld * rng.randf_range(2.0, 4.0) * (1.0 if rng.randf() < 0.5 else -1.0)
			_por(_sorte(["SM_Prop_PlanterBox_Preset_01", "SM_Prop_PlanterBox_Preset_02", "SM_Prop_PlanterBox_Preset_03", "SM_Prop_PlanterBox_Preset_04",
				"SM_Env_Planter_Preset_01", "SM_Env_Planter_Preset_02", "SM_Prop_Barrel_Stack_02", "SM_Prop_Crate_Stack_03", "SM_Prop_Sack_Stack_01",
				"SM_Env_Planter_Pedestal_01_Preset_01", "SM_Prop_Bench_Seat_03", "SM_Prop_Wood_Pile_02"]), q, ang, 1.0, true, yc.call(q))
		if rng.randf() < 0.3:
			var tr := Vector2(pos.x, pos.z) - fr * (d * 0.5 + 3.0)
			_por(_sorte(["SM_Prop_WashingLine_01_Preset_01", "SM_Prop_WashingLine_01_Preset_02", "SM_Prop_Hanging_Clothes_Line_02"]), tr, ang + PI * 0.5, 1.0, false, yc.call(tr) + 0.0)
	# bandeirolas por cima da avenida e da rua do mercado
	for xx in range(int(C.position.x) + 40, int(C.end.x) - 20, 28):
		var q := Vector2(xx, zc)
		if q.distance_to(pr) < 30.0: continue
		Synty.por(m, _sorte(["SM_Prop_Bunting_03", "SM_Prop_Bunting_04"]), Vector3(q.x, yc.call(q) + 5.5, q.y), PI * 0.5, 1.0, false)
	for zz in range(int(C.position.y) + 30, int(C.end.y) - 20, 30):
		var q := Vector2(pr.x, zz)
		if q.distance_to(pr) < 30.0: continue
		Synty.por(m, _sorte(["SM_Prop_Bunting_03", "SM_Prop_Bunting_04"]), Vector3(q.x, yc.call(q) + 5.5, q.y), 0.0, 1.0, false)
	# estandartes na muralha (lado de dentro) e bandeiras nas torres
	for t in _ao_longo(C.position, Vector2(C.end.x - 20.0, C.position.y), 22.0) + _ao_longo(Vector2(C.position.x, C.end.y), Vector2(C.end.x - 20.0, C.end.y), 22.0):
		var dentro := Vector2(0, 2.0) if t.y < zc else Vector2(0, -2.0)
		var q: Vector2 = t + dentro
		Synty.por(m, _sorte(["SM_Prop_Banner_01", "SM_Prop_Banner_02", "SM_Prop_Banner_03", "SM_Prop_Banner_04"]), Vector3(q.x, Regiao.ALTURA_CIDADE + 9.0, q.y), 0.0 if t.y > zc else PI, 2.0, false)
	for t in [C.position, Vector2(C.position.x, C.end.y)]:
		Synty.por(m, _sorte(["SM_Prop_Flag_01", "SM_Prop_Flag_02", "SM_Prop_Flag_03"]), Vector3(t.x, Regiao.ALTURA_CIDADE + 20.0, t.y), rng.randf() * TAU, 1.5, false)
	# praça do mercado: palco com o bobo, quadro de missões, poço e mais barracas, carroças e uma carroça de mercador
	_por("SM_Prop_Stage_01", pr + Vector2(-24, 24), PI * 0.25, 1.0, true, Regiao.NIVEL_MERCADO)
	_por("SM_Prop_Quest_Board_01_Posters_01", pr + Vector2(14, -24), PI, 1.2, true, Regiao.NIVEL_MERCADO)
	_por("SM_Veh_TraderWagon_01", pr + Vector2(26, -14), 0.6, 1.0, true, Regiao.NIVEL_MERCADO)
	for k in 6:
		var a := rng.randf() * TAU; var q := pr + Vector2(cos(a), sin(a)) * rng.randf_range(24.0, 32.0)
		if Regiao.rua_cidade(q.x, q.y) < 6.0 or m.perto_de_casa(q.x, q.y, 2.0): continue
		_por(_sorte(["SM_Veh_Cart_01", "SM_Veh_Cart_02", "SM_Veh_Cart_03", "SM_Veh_Wheelbarrow_01", "SM_Prop_Hay_Cart_01", "SM_Veh_Cart_Fireworks_01_Preset"]), q, rng.randf() * TAU, 1.0, true, Regiao.NIVEL_MERCADO)
	# praça dos nobres: árvore grande com calçada, cercas-vivas e gazebo
	var nb := Vector2(2030.0, -30.0)
	if not m.perto_de_casa(nb.x, nb.y, 8.0):
		_por("SM_Env_Big_Tree_Base_Paving_01", nb, 0.0, 1.0, false, Regiao.altura_cidade(nb.x, nb.y))
		_por("SM_Env_Big_Tree_01", nb, 0.0, 0.8, true, Regiao.altura_cidade(nb.x, nb.y))
		for k in 4:
			var q := nb + Vector2(cos(k * PI * 0.5 + 0.4), sin(k * PI * 0.5 + 0.4)) * 11.0
			_por("SM_Env_Hedge_01", q, k * PI * 0.5 + 0.4 + PI * 0.5, 1.0, true, Regiao.altura_cidade(q.x, q.y))
		m.lugares.append([nb, 13.0])
	# praça da justiça na Cidade Velha: forca e guilhotina
	var ju := Vector2(2090.0, 230.0)
	if not m.perto_de_casa(ju.x, ju.y, 6.0):
		_por("SM_Prop_Gallows_Platform_02", ju, 0.0, 1.0, true, Regiao.altura_cidade(ju.x, ju.y))
		_por("SM_Prop_Guillotine_01", ju + Vector2(9, 0), 0.0, 1.0, true, Regiao.altura_cidade(ju.x, ju.y))
		m.lugares.append([ju, 10.0])
	# porto: remos, baldes de peixe, redes, barcos virados, caixotes
	for k in 16:
		var q := Vector2(rng.randf_range(Regiao.X_PORTO + 14.0, C.end.x - 6.0), rng.randf_range(C.position.y + 10.0, C.end.y - 10.0))
		if m.perto_de_casa(q.x, q.y, 2.0) or Regiao.rua_cidade(q.x, q.y) < 6.0: continue
		_por(_sorte(["SM_Prop_Oar_01", "SM_Prop_Bucket_Fish_01", "SM_Prop_Barrel_Stack_03", "SM_Prop_Crate_Stack_04", "SM_Prop_Sack_Stack_02", "SM_Prop_Boat_01" if Synty.existe("SM_Prop_Boat_01") else "SM_Veh_Boat_Dinghy_01"]), q, rng.randf() * TAU, 1.0, true, Regiao.NIVEL_PORTO)
	# postes de amarrar cavalo e placas na entrada
	var x0 := C.position.x
	for lado in [-1.0, 1.0]: _por("SM_Prop_Horse_Hitching_Post_01", Vector2(x0 - 30.0, zc + lado * 9.0), 0.0, 1.0, true)
	_por("SM_Prop_Direction_Sign_01", Vector2(x0 - 60.0, zc - 7.0), PI * 0.5, 1.0, true)

func _enfeitar_vila_e_campos() -> void:
	var v := Regiao.VILA
	# vila: quadro de missões, placa de direção, carroças, carrinho de mão, tronco de cortar lenha, colmeias, girassóis
	_por("SM_Prop_Quest_Board_01_Posters_01", v + Vector2(10, -12), PI, 1.1, true)
	_por("SM_Prop_Direction_Sign_02", v + Vector2(-10, 12), 0.6, 1.0, true)
	for k in 14:
		var q := v + Vector2(rng.randf_range(-110, 110), rng.randf_range(-60, 60))
		if not _livre(q, 2.5): continue
		_por(_sorte(["SM_Veh_Cart_01", "SM_Veh_Wheelbarrow_01", "SM_Prop_Chopping_Board_01", "SM_Prop_Beehive_01", "SM_Prop_Hay_Pile_01",
			"SM_Prop_Wood_Pile_03", "SM_Env_Sunflower_02", "SM_Env_Sunflower_03", "SM_Prop_Plow_02", "SM_Prop_Hay_Bale_01"]), q, rng.randf() * TAU, 1.0, true)
	# roda d'água no rio, perto do píer
	var rw := Vector2(436.0, 500.0)
	_por("SM_Bld_Waterwheel_01", rw, PI * 0.5, 0.6, false, m.reg.nivel_rio(0.62) + 1.0)
	# campos: canteiros de horta com abóboras e repolhos nos arados; espantalho no trigo
	for c in m.reg.campos:
		var cc := Vector2(c[0], c[1]); var ang := deg_to_rad(c[4])
		if c[5] == 1 and c[2] >= 30:
			for i in 6:
				var q := cc + Vector2(-c[2] * 0.35 + i * c[2] * 0.14, 0).rotated(ang)
				_por(_sorte(["SM_Env_Ground_Farm_Row_01", "SM_Env_Ground_Farm_Row_02", "SM_Env_Ground_Farm_Row_03"]), q, -ang, 1.0, false)
				for j in 3:
					var q2 := q + Vector2(0, (j - 1) * c[3] * 0.25).rotated(ang)
					_por(_sorte(["SM_Prop_Pumpkin_Plant_01", "SM_Prop_Pumpkin_Plant_02", "SM_Prop_Cabbage_01", "SM_Prop_Cabbage_02"]), q2, rng.randf() * TAU, 1.0, false)
		elif c[5] == 0 and c[2] >= 30:
			_por("SM_Prop_Scarecrow_01", cc, rng.randf() * TAU, 1.2, true)
			for k in 4: _por("SM_Prop_Hay_Bale_01", cc + Vector2(rng.randf_range(-c[2] * 0.4, c[2] * 0.4), rng.randf_range(-c[3] * 0.4, c[3] * 0.4)).rotated(ang), rng.randf() * TAU, 1.0, true)

# pedras e paredões nas encostas, samambaias na mata, juncos e lírios na água
func _natureza() -> void:
	var r: Regiao = m.reg
	for i in 2600:
		var x := rng.randf_range(Regiao.X0 + 60.0, Regiao.X1 - 120.0); var z := rng.randf_range(Regiao.Z0 + 60.0, Regiao.Z1 - 60.0)
		if r.na_cidade(x, z, 40.0) or r.dist_estrada(x, z) < 8.0 or Vector2(x, z).distance_to(Regiao.VILA) < 150.0 or r.agua(x, z) != 0.0: continue
		if m.perto_de_lugar(x, z, 8.0) or r.campo_em(x, z) >= 0: continue
		var h := r.altura(x, z); var nrm := Vector3(h - r.altura(x + 3.0, z), 3.0, h - r.altura(x, z + 3.0)).normalized()
		var q := Vector2(x, z)
		if nrm.y < 0.78 and rng.randf() < 0.8:                   # encosta íngreme: paredão de pedra
			_por(_sorte(["SM_Env_Rock_Cliff_01", "SM_Env_Rock_Cliff_02", "SM_Env_Rock_Cliff_03", "SM_Env_Rock_Cliff_05"]), q, rng.randf() * TAU, rng.randf_range(0.6, 1.1), true, h - 2.0)
		elif rng.randf() < 0.25:
			_por(_sorte(["SM_Env_Rock_Chunk_01", "SM_Env_Rock_Chunk_02", "SM_Env_Rock_Chunk_03", "SM_Env_Rock_01", "SM_Env_Rock_03"]), q, rng.randf() * TAU, rng.randf_range(0.8, 2.0), true, h - 0.3)
		elif r.floresta(x, z) > 0.4 and rng.randf() < 0.5:
			_por(_sorte(["SM_Env_Fern_01", "SM_Env_Fern_02", "SM_Env_Fern_03"]), q, rng.randf() * TAU, rng.randf_range(0.9, 1.4), false, h - 0.05)
		elif r.floresta(x, z) < 0.2 and rng.randf() < 0.4:
			_por(_sorte(["SM_Env_Flowers_01", "SM_Env_Flowers_04", "SM_Env_Flowers_07", "SM_Env_Flowers_10", "SM_Env_Sunflower_01"]), q, rng.randf() * TAU, 1.0, false, h - 0.05)
	# beira do lago: juncos e lírios
	var lg := Vector2(Regiao.LAGO.x, Regiao.LAGO.y)
	for k in 60:
		var a := rng.randf() * TAU; var q := lg + Vector2(cos(a), sin(a)) * (Regiao.LAGO.z + rng.randf_range(-6.0, 3.0))
		if k % 3 == 0: _por(_sorte(["SM_Env_Lily_01", "SM_Env_Lily_02", "SM_Env_Lily_03"]), q, rng.randf() * TAU, 1.0, false, r.nivel_lago() - 0.9)
		else: _por(_sorte(["SM_Env_Reeds_01", "SM_Env_Reeds_02", "SM_Env_Reeds_03"]), q, rng.randf() * TAU, 1.2, false, r.altura(q.x, q.y) - 0.2)

# ---------- lugares para explorar ----------
var lugares_bussola := []
func _achar(p: Vector2, raio: float) -> Vector2:               # um lugar livre e plano perto de p
	for t in 60:
		var a := t * 2.4; var q := p + Vector2(cos(a), sin(a)) * (t * 1.5)
		if m.reg.dist_estrada(q.x, q.y) > raio * 0.5 and m.reg.agua(q.x, q.y) == 0.0 and not m.perto_de_lugar(q.x, q.y, raio) and not m.reg.na_cidade(q.x, q.y, raio):
			var h: float = m.reg.altura(q.x, q.y); var ok := true
			for o in [Vector2(raio * 0.5, 0), Vector2(-raio * 0.5, 0), Vector2(0, raio * 0.5), Vector2(0, -raio * 0.5)]:
				if absf(m.reg.altura(q.x + o.x, q.y + o.y) - h) > raio * 0.25: ok = false
			if ok: return q
	return p

func _lugares_novos() -> void:
	# Campo de Batalha: restos de uma batalha (catapulta, trabuco, torre de cerco caída, mortos, estandartes rasgados)
	var cb := _achar(Vector2(760.0, -330.0), 30.0)
	_por("SM_Wep_Trebuchet_01", cb + Vector2(-14, -8), 0.4, 1.0, true)
	_por("SM_Wep_Catapult_01", cb + Vector2(12, 10), -0.8, 1.0, true)
	_por("SM_Wep_Siege_Tower_Fallen_01", cb + Vector2(4, -20), 1.1, 1.0, true)
	for k in 26:
		var q := cb + Vector2(rng.randf_range(-30, 30), rng.randf_range(-30, 30))
		_por(_sorte(["SM_Dead_Soldier_01", "SM_Dead_Soldier_03", "SM_Dead_Soldier_05", "SM_Dead_Knight_01", "SM_Dead_Knight_03", "SM_Prop_Dead_Horse_01",
			"SM_Prop_Battle_Bramble_01", "SM_Prop_Battle_Bramble_02", "SM_Prop_Battle_Banner_02", "SM_Prop_Battle_Cross_01", "SM_Prop_Spike_Fortification_02",
			"SM_Prop_Destroyed_House_Debris_01", "SM_Wep_Ballista_Mobile_01"]), q, rng.randf() * TAU, 1.0, false)
	m.lugares.append([cb, 34.0]); lugares_bussola.append(["Campo de Batalha", cb, "espadas", 30.0])
	# Acampamento Militar: tendas, armas, bonecos de treino, alvos, fogueira, cerca de estacas
	var am := _achar(Vector2(1350.0, -320.0), 28.0)
	for k in 5:
		var a := TAU * k / 5.0; var q := am + Vector2(cos(a), sin(a)) * 16.0
		_por(_sorte(["SM_Bld_Tent_Large_01", "SM_Bld_Tent_Square_01", "SM_Bld_Tent_Round_01"]), q, a + PI, 1.0, true)
	_por("SM_Prop_Camp_Firepit_01", am, 0.0, 1.5, true)
	for k in 8:
		var q := am + Vector2(rng.randf_range(-10, 10), rng.randf_range(-10, 10))
		if q.distance_to(am) < 3.0: continue
		_por(_sorte(["SM_Prop_Weapon_Rack_01", "SM_Prop_Weapon_Rack_02", "SM_Prop_Dummy_Armour_01", "SM_Prop_Dummy_Archery_01", "SM_Prop_Target_01",
			"SM_Prop_Camp_Brazier_01", "SM_Prop_Camp_Weapon_Rack_01", "SM_Prop_Barrel_Stack_01"]), q, rng.randf() * TAU, 1.0, true)
	for k in 14:
		var a := TAU * k / 14.0; var q := am + Vector2(cos(a), sin(a)) * 26.0
		if k % 7 == 0: continue
		_por("SM_Prop_Spike_Wall_02", q, -a, 1.0, true)
	m.lugares.append([am, 30.0]); lugares_bussola.append(["Acampamento Militar", am, "tenda", 28.0])
	for k in 4: _cidadao("SM_Chr_Soldier_Male_01" if k % 2 == 0 else "SM_Chr_Soldier_Female_01", am + Vector2(4 + k, 4), am, 12.0)
	# Cemitério atrás da igreja da vila
	var ce: Vector2 = (m.igreja_vila[0] as Vector2) + Vector2(0, -26.0) if not m.igreja_vila.is_empty() else Regiao.VILA + Vector2(40, -70)
	for i in 4:
		for j in 5:
			var q := ce + Vector2(-8.0 + j * 4.0, -5.0 + i * 3.5) + Vector2(rng.randf_range(-0.4, 0.4), 0)
			_por(_sorte(["SM_Prop_Gravestone_01", "SM_Prop_Gravestone_02", "SM_Prop_Gravestone_03", "SM_Prop_Gravestone_04", "SM_Prop_Gravestone_05", "SM_Prop_Gravestone_Broken_01"]), q, 0.0, 1.0, false)
	for seg in [[ce + Vector2(-12, -8), ce + Vector2(12, -8)], [ce + Vector2(-12, -8), ce + Vector2(-12, 9)], [ce + Vector2(12, -8), ce + Vector2(12, 9)]]:
		var a: Vector2 = seg[0]; var b: Vector2 = seg[1]; var n := int(a.distance_to(b) / 5.0) + 1
		for i in n:
			var q := a.lerp(b, (i + 0.5) / n); var dl := (b - a).normalized()
			_por("SM_Env_StoneWall_01", q, atan2(-dl.y, dl.x), a.distance_to(b) / n / 5.1, true)
	m.lugares.append([ce, 14.0])
	# Bosque das Fadas, no planalto do oeste: árvore enorme, casinhas de fada e flores flutuantes
	var bf := _achar(Vector2(-820.0, 320.0), 16.0)
	_por("SM_Env_Big_Tree_01", bf, 0.0, 1.0, true)
	for k in 10:
		var a := rng.randf() * TAU; var q := bf + Vector2(cos(a), sin(a)) * rng.randf_range(6.0, 14.0)
		_por(_sorte(["SM_Prop_Fairy_House_01", "SM_Prop_Fairy_House_02", "SM_Prop_Fairy_House_03", "SM_Item_FloatingFlower_01", "SM_Item_Mushroom_01" if Synty.existe("SM_Item_Mushroom_01") else "SM_Env_Fern_04"]), q, rng.randf() * TAU, 1.5, false)
	m.lugares.append([bf, 16.0]); lugares_bussola.append(["Bosque das Fadas", bf, "arvore", 20.0])
	# Ruínas no norte: casas destruídas e uma torre
	var ru := _achar(Vector2(-250.0, -640.0), 24.0)
	_por("SM_Prop_Destroyed_House_Preset_01", ru, 0.3, 1.2, true)
	_por("SM_Prop_Destroyed_House_Preset_02", ru + Vector2(14, 6), -0.5, 1.2, true)
	_por("SM_Wep_Siege_Tower_01", ru + Vector2(-12, 10), 0.8, 1.0, true)
	for k in 8: _por(_sorte(["SM_Prop_Destroyed_House_Piece_01_Burnt", "SM_Prop_Destroyed_House_Debris_02", "SM_Prop_Destroyed_House_Piece_03"]), ru + Vector2(rng.randf_range(-16, 16), rng.randf_range(-16, 16)), rng.randf() * TAU, 1.0, true)
	m.lugares.append([ru, 24.0]); lugares_bussola.append(["Ruínas do Norte", ru, "ruinas", 25.0])
	# torres de vigia no alto de três morros
	for p in [Vector2(1000.0, -650.0), Vector2(-120.0, -200.0), Vector2(900.0, 700.0)]:
		var t := _achar(p, 10.0)
		_por("SM_Bld_Preset_Tower_01_Optimized", t, rng.randf() * TAU, 0.9, true)
		m.lugares.append([t, 10.0]); lugares_bussola.append(["Torre de Vigia", t, "torre", 18.0])

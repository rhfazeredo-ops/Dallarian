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
	var cat := Vector2(1790.0, 0.0)
	m._casa(Vector3(cat.x, Regiao.ALTURA_CIDADE, cat.y), 0.0, 19.0, 33.0, 15.0, null, null, true, "SM_Bld_Preset_Church_01_B_Optimized", 3.0)
	m._freira("Irmã Odília", cat + Vector2(0, 21.0), Vector2(0, 1), Regiao.ALTURA_CIDADE, 4343)
	m.lugares.append([cat + Vector2(0, 28.0), 14.0])
	# ---- bairro dos magos (nível alto, ao sul): torre grande e duas menores
	var tm := Vector2(1755.0, 250.0)
	Synty.por(m, "SM_Bld_Preset_Tower_01_Optimized", Vector3(tm.x, Regiao.ALTURA_CIDADE - 1.0, tm.y), 0.0, 2.0, true)
	m._particulas_magia(Vector3(tm.x, Regiao.ALTURA_CIDADE + 46.0, tm.y))
	for q in [tm + Vector2(60, 40), tm + Vector2(-40, 60)]:
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
	m.taverna_pos = Vector2(1985.0, 175.0)
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
	for xx in range(int(x0) + 20, int(x1) - 14, 14):
		for zz in range(int(z0) + 20, int(z1) - 14, 14):
			var q := Vector2(xx + rng.randf_range(-2.0, 2.0), zz + rng.randf_range(-2.0, 2.0))
			if pular.call(q) or rng.randf() < 0.15: continue
			if m.perto_de_casa(q.x, q.y, 5.5) or m.perto_de_lugar(q.x, q.y, 5.0): continue
			m._casa(Vector3(q.x, yc.call(q), q.y), _rumo_rua(q), rng.randf_range(7.5, 9.5), rng.randf_range(7.0, 9.0), 6.0, null, null, true)
	# ---- postes e árvores pelas ruas principais
	for xx in range(int(x0) + 30, int(x1) - 10, 34):
		for lado in [-1.0, 1.0]:
			var q := Vector2(xx, zc + lado * 8.0)
			if q.distance_to(pr) > 30.0: m._poste_em(q, Vector2(xx, zc))
	for zz in range(int(z0) + 30, int(z1) - 10, 36):
		var q := Vector2(pr.x + 8.0, zz)
		if q.distance_to(pr) > 30.0: m._poste_em(q, Vector2(pr.x, zz))
	for q in [cat + Vector2(-16, 30), cat + Vector2(16, 30), tm + Vector2(20, -24), tm + Vector2(-24, -20), Vector2(1700, -10), Vector2(1700, 160)]:
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

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
	_vila_norte()
	_estabulo()
	_cercas_dos_campos()
	_enfeitar_cidade()
	_enfeitar_vila_e_campos()
	_natureza()
	_lugares_novos()
	_estrada_dos_herois()
	_fumaca_chamines()
	_cidadaos()
	_interiores()

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

# ---------- Altamar (bairros, canais com pontes, muralha irregular, fortaleza no morro, porto) ----------
func cat_pos() -> Vector2: return Regiao.ILHA_CATEDRAL
func tm_pos() -> Vector2: return Vector2(1850.0, 225.0)
func _ao_longo(a: Vector2, b: Vector2, passo: float) -> Array:
	var r := []; var comp := a.distance_to(b); var n := int(comp / passo)
	for i in range(1, n + 1): r.append(a.lerp(b, float(i) / (n + 1)))
	return r
func _yc(q: Vector2) -> float: return Regiao.altura_cidade(q.x, q.y)
# rua mais perto: [distância, ponto mais perto]
func _rua_perto(q: Vector2) -> Array:
	var md := INF; var mp := q
	for r in Regiao.RUAS:
		for i in r.size() - 1:
			var c := Geometry2D.get_closest_point_to_segment(q, r[i], r[i + 1])
			if q.distance_to(c) < md: md = q.distance_to(c); mp = c
	return [md, mp]
func _rumo_rua(q: Vector2) -> float: return _virado(q, _rua_perto(q)[1])

func _altamar() -> void:
	var y0 := Regiao.ALTURA_CIDADE
	m.cidade_pos = Regiao.CIDADE_C; m.cidade_y = y0
	var pg := Regiao.PORTAO
	# ---- muralha com torres (abre no Portão Oeste; a beira do mar fica livre para o porto)
	var linhas := [Regiao.MURALHA, Regiao.MURALHA_SUL]
	for l in linhas:
		for i in l.size() - 1:
			var a: Vector2 = l[i]; var b: Vector2 = l[i + 1]
			if a == pg: a = a + (b - a).normalized() * 9.0
			if b == pg: b = b + (a - b).normalized() * 9.0
			_muro(a, b, _yc(a.lerp(b, 0.5)) if a.distance_to(Regiao.CASTELO) > 60.0 else y0, 2.6, 3.2)
			for t in _ao_longo(a, b, 45.0): _torre(t, y0)
			if l[i] != pg: _torre(l[i], y0, i % 2 == 1)
	# ---- Portão Oeste: arco grande entre duas torres, estandartes, guardas (cidadãos)
	Synty.por3(m, "SM_Bld_Castle_Wall_Archway_01", Vector3(pg.x, y0 - 1.0, pg.y), PI * 0.5, Vector3(3.8, 3.0, 6.0), false)
	_torre(pg + Vector2(0, -15.0), y0, true); _torre(pg + Vector2(0, 15.0), y0, true)
	for lado in [-1.0, 1.0]: _por("SM_Prop_Battle_Banner_01", pg + Vector2(7.0, lado * 7.5), PI * 0.5, 2.5, false, y0)
	m.lugares.append([pg, 18.0])
	# ---- fortaleza no morro (noroeste): torre de menagem, quatro torres, muralha própria e portão
	var cs := Regiao.CASTELO; var yk := Regiao.ALTURA_CASTELO
	Synty.por(m, "SM_Bld_Preset_Tower_01_Optimized", Vector3(cs.x, yk - 1.0, cs.y), 0.0, 2.8, true)
	var cantos := [cs + Vector2(-40, -34), cs + Vector2(40, -34), cs + Vector2(40, 34), cs + Vector2(-40, 34)]
	for i in 4:
		Synty.por(m, "SM_Bld_Preset_Tower_01_Optimized", Vector3(cantos[i].x, yk - 1.5, cantos[i].y), 0.0, 1.4, true)
		var a: Vector2 = cantos[i]; var b: Vector2 = cantos[(i + 1) % 4]
		if i == 2:
			var meio := (a + b) * 0.5
			_muro(a, meio + Vector2(8, 0), yk, 2.6); _muro(meio - Vector2(8, 0), b, yk, 2.6)
			Synty.por3(m, "SM_Bld_Castle_Wall_Archway_01", Vector3(meio.x, yk - 1.0, meio.y), 0.0, Vector3(3.2, 2.8, 4.0), false)
		else: _muro(a, b, yk, 2.6)
	for k in 6: _por(_sorte(["SM_Prop_Banner_01", "SM_Prop_Banner_02"]), cs + Vector2(-30 + k * 12, 33), 0.0, 2.2, false, yk + 7.0)
	m.lugares.append([cs, 72.0])
	# ---- ilha da catedral: catedral grande no meio, praça calçada em volta, quatro pontes
	var il := Regiao.ILHA_CATEDRAL
	m._casa(Vector3(il.x, y0, il.y - 4.0), 0.0, 19.0, 33.0, 15.0, null, null, true, "SM_Bld_Preset_Church_01_B_Optimized", 3.0)
	m._freira("Irmã Odília", il + Vector2(-6.0, 22.0), Vector2(0, 1), y0, 4343)
	for k in 8:
		var a := TAU * k / 8.0 + 0.4; var q := il + Vector2(cos(a), sin(a)) * 40.0
		if absf(q.y - (il.y + 20.0)) < 6.0 and q.y > il.y: continue
		m.arvores_cidade.append([Vector3(q.x, y0 - 0.2, q.y), 0.9]); m._colisor_cilindro(Vector3(q.x, y0, q.y), 0.35, 4.0)
	for a in [PI * 0.83, PI * 0.42, -PI * 0.12, -PI * 0.55]:
		var d := Vector2(cos(a), sin(a))
		_ponte(il + d * 44.0, il + d * 72.0)
	m.lugares.append([il, Regiao.RAIO_ILHA + 14.0])
	# ---- pontes onde as ruas cruzam os canais
	for r in Regiao.RUAS:
		for i in r.size() - 1:
			var a: Vector2 = r[i]; var b: Vector2 = r[i + 1]; var dentro := false; var ini := a
			var n := int(a.distance_to(b))
			for k in n + 1:
				var q := a.lerp(b, float(k) / maxf(n, 1))
				var agua := Regiao.dist_canal(q.x, q.y) < 6.5 and q.distance_to(il) > 45.0
				if agua and not dentro: ini = q; dentro = true
				elif not agua and dentro: _ponte(ini - (q - ini).normalized() * 2.5, q + (q - ini).normalized() * 2.5); dentro = false
	# ---- água dos canais (o anel em volta da ilha e os braços)
	_agua_canais()
	# ---- praça do mercado (bairro comercial): chafariz, barracas em roda, bancos, palco, quadro de missões
	var pr := Regiao.PRACA
	Synty.por(m, "SM_Env_Fountain_01", Vector3(pr.x, y0 - 0.1, pr.y), 0.0, 3.0, false)
	m._colisor_cilindro(Vector3(pr.x, y0 - 0.3, pr.y), 7.0, 2.0)
	var barracas := ["SM_Prop_Market_Stall_01", "SM_Prop_Market_Stall_02", "SM_Prop_Market_Stall_03", "SM_Prop_Market_Stall_05",
		"SM_Prop_Market_Stall_06", "SM_Prop_Market_Stall_07", "SM_Prop_Market_Stall_08", "SM_Prop_Market_Stall_09"]
	for k in 16:
		var a := TAU * (k + 0.5) / 16.0; var q := pr + Vector2(cos(a), sin(a)) * 20.0
		if Regiao.rua_cidade(q.x, q.y) < 4.0: continue
		_por(barracas[k % barracas.size()], q, _virado(q, pr), 1.0, true, y0)
	for k in 6:
		var a := TAU * k / 6.0 + 0.5; var q := pr + Vector2(cos(a), sin(a)) * 11.0
		_por("SM_Prop_Bench_Seat_01", q, _virado(q, pr) + PI * 0.5, 1.0, false, y0)
	_por("SM_Prop_Stage_01", pr + Vector2(-26, 14), PI * 0.3, 1.0, true, y0)
	_por("SM_Prop_Quest_Board_01_Posters_01", pr + Vector2(16, -26), PI, 1.2, true, y0)
	_por("SM_Veh_TraderWagon_01", pr + Vector2(28, 8), 0.6, 1.0, true, y0)
	m.lugares.append([pr, 27.0])
	# ---- taverna (no mercado) e bairro dos magos
	m.taverna_pos = pr + Vector2(50.0, 32.0)
	m._casa(Vector3(m.taverna_pos.x, y0, m.taverna_pos.y), PI, 14.0, 14.0, 9.0, null, null, true, "SM_Bld_Preset_Tavern_01_Optimized", 1.0)
	m._placa(Vector3(m.taverna_pos.x, y0, m.taverna_pos.y), PI, 14.0, 14.0, 9.0, "taverna")
	m.cidade_lojas.append(["taverna", m.taverna_pos + Vector2(0, -9.0)])
	var tm := tm_pos()
	Synty.por(m, "SM_Bld_Preset_Tower_01_Optimized", Vector3(tm.x, y0 - 1.0, tm.y), 0.0, 2.0, true)
	m._particulas_magia(Vector3(tm.x, y0 + 46.0, tm.y))
	Synty.por(m, "SM_Bld_Preset_Tower_01_Optimized", Vector3(tm.x + 34.0, y0 - 1.0, tm.y + 18.0), 1.0, 1.2, true)
	for k in 5: _por(_sorte(["SM_Prop_Alchemy_Stand_01", "SM_Prop_Alchemy_Stand_03", "SM_Prop_Cauldron_02", "SM_Env_Planter_Preset_02"]), tm + Vector2(rng.randf_range(-14, 14), rng.randf_range(-22, -12)), rng.randf() * TAU, 1.0, true, y0)
	m.lugares.append([tm, 24.0]); m.lugares.append([tm + Vector2(34, 18), 12.0])
	# ---- porto (cais embaixo, a leste): armazéns, barracas de peixe, píeres no mar, barcos, farol
	_porto()
	# ---- casas: quarteirões entre as ruas (porta para a rua mais perto), lojas na rua do mercado
	var lojas := ["banco", "armas", "armaduras", "alquimia", "alfaiate", "joalheiro", "estalagem", "ferreiro"]
	var C: Rect2 = Regiao.CIDADE
	for xx in range(int(C.position.x) + 10, int(C.end.x), 11):
		for zz in range(int(C.position.y) + 10, int(C.end.y), 11):
			var q := Vector2(xx + rng.randf_range(-2.5, 2.5), zz + rng.randf_range(-2.5, 2.5))
			if not Regiao.dentro_cidade(q) or Regiao._dist_linha(q, Regiao.MURALHA) < 9.0 or Regiao._dist_linha(q, Regiao.MURALHA_SUL) < 9.0: continue
			if q.distance_to(Regiao.CASTELO) < 92.0 or q.distance_to(il) < 75.0 or q.distance_to(pr) < 32.0 or q.x > Regiao.X_PORTO - 6.0: continue
			var rp := _rua_perto(q)
			if rp[0] < 8.0 or Regiao.dist_canal(q.x, q.y) < 12.0 or m.perto_de_casa(q.x, q.y, 4.6) or m.perto_de_lugar(q.x, q.y, 4.0): continue
			if rp[0] > 34.0 and rng.randf() < 0.35: continue                       # pátios e quintais no meio dos quarteirões
			var bairro := Regiao.distrito(q.x, q.y)
			var ang := _virado(q, rp[1])
			var modelo := ""
			if bairro == "velho" and rng.randf() < 0.5: modelo = _sorte(["SM_Bld_Preset_House_02_A_Optimized", "SM_Bld_Preset_House_08_Optimized", "SM_Bld_Preset_Hut_01_Optimized"])
			if bairro == "magos" and rng.randf() < 0.3: modelo = "SM_Bld_Preset_House_06_Optimized"
			m._casa(Vector3(q.x, _yc(q), q.y), ang, rng.randf_range(7.5, 10.0), rng.randf_range(7.0, 9.5), 7.0, null, null, true, modelo, 1.0)
			if bairro == "comercio" and rp[0] < 13.0 and not lojas.is_empty() and q.distance_to(pr) < 90.0:
				var nome: String = lojas.pop_front()
				m._placa(Vector3(q.x, _yc(q), q.y), ang, 9.0, 8.5, 7.0, nome)
				m.cidade_lojas.append([nome, (rp[1] as Vector2) + (q - rp[1]).normalized() * 2.0])
	# ---- postes pelas ruas
	for r in Regiao.RUAS:
		var lado := 1.0
		for i in r.size() - 1:
			var a: Vector2 = r[i]; var b: Vector2 = r[i + 1]; var dl := (b - a).normalized(); var nr := Vector2(-dl.y, dl.x)
			var sp := 10.0
			while sp < a.distance_to(b):
				var c := a + dl * sp; var q := c + nr * lado * 5.5
				if Regiao.dentro_cidade(c) and Regiao.dist_canal(q.x, q.y) > 7.0 and not m.perto_de_casa(q.x, q.y, 0.8) and q.distance_to(pr) > 26.0:
					m._poste_em(q, c)
				sp += 24.0; lado = -lado
	m.lugares.append([Regiao.CIDADE_C, 260.0])

func _ponte(a: Vector2, b: Vector2) -> void:
	var dl := (b - a).normalized(); var comp := a.distance_to(b); var giro := atan2(-dl.y, dl.x)
	var y := Regiao.ALTURA_CIDADE
	var n := maxi(1, int(round(comp / 5.4)))
	for i in n:
		var q := a + dl * (comp * (i + 0.5) / n)
		Synty.por3(m, "SM_Bld_Bridge_01", Vector3(q.x, y + 0.05, q.y), giro, Vector3(comp / n / 5.6, 1.5, 9.0 / 5.5), false)
		for lado in [-1.0, 1.0]:
			var ql: Vector2 = q + Vector2(-dl.y, dl.x) * lado * 4.6
			Synty.por3(m, "SM_Bld_Bridge_Railing_01", Vector3(ql.x, y + 0.25, ql.y), giro + PI * 0.5, Vector3(1.0, 1.0, comp / n / 5.0), false)
	var meio := (a + b) * 0.5
	m._colisor_caixa(Vector3(meio.x, y - 0.4, meio.y), Vector3(9.0, 0.5, comp), atan2(dl.x, dl.y))
	for lado in [-1.0, 1.0]:
		var ql: Vector2 = meio + Vector2(-dl.y, dl.x) * lado * 4.6
		m._colisor_caixa(Vector3(ql.x, y, ql.y), Vector3(0.4, 1.2, comp), atan2(dl.x, dl.y))

func _agua_canais() -> void:
	var am := ShaderMaterial.new(); am.shader = load("res://shaders/agua.gdshader"); am.set_shader_parameter("neblina", m.NEBLINA)
	var anel := PackedVector2Array()
	for k in 73: anel.append(Regiao.ILHA_CATEDRAL + Vector2(cos(TAU * k / 72.0), sin(TAU * k / 72.0)) * (Regiao.RAIO_ILHA + 7.0))
	var larg := func(_t: float) -> float: return 9.0
	var niv := func(_t: float) -> float: return Regiao.NIVEL_CANAL
	m._faixa_rio(anel, larg, niv, am)
	for c in Regiao.CANAIS: m._faixa_rio(PackedVector2Array(c), larg, niv, am)
	# cais de pedra nas duas margens: paredão vertical da água até a rua, com mureta em cima (vão nas pontes)
	var paredoes := []                                   # [a, b] em volta do anel e dos braços
	for k in 48:
		var a0 := TAU * k / 48.0; var a1 := TAU * (k + 1) / 48.0
		if _perto_ponte_ilha((a0 + a1) * 0.5): continue
		for r in [Regiao.RAIO_ILHA + 2.2, Regiao.RAIO_ILHA + 11.8]:
			paredoes.append([Regiao.ILHA_CATEDRAL + Vector2(cos(a0), sin(a0)) * r, Regiao.ILHA_CATEDRAL + Vector2(cos(a1), sin(a1)) * r])
	for c in Regiao.CANAIS:
		for i in c.size() - 1:
			var a: Vector2 = c[i]; var b: Vector2 = c[i + 1]; var nr := Vector2(-(b - a).normalized().y, (b - a).normalized().x)
			for lado in [-1.0, 1.0]: paredoes.append([a + nr * lado * 4.8, b + nr * lado * 4.8])
	for pw in paredoes:
		var a: Vector2 = pw[0]; var b: Vector2 = pw[1]
		var meio := (a + b) * 0.5
		if Regiao.rua_cidade(meio.x, meio.y) < 5.5 or not Regiao.CIDADE.grow(-2.0).has_point(meio): continue
		var dl := (b - a).normalized(); var giro := atan2(-dl.y, dl.x)
		var comp := a.distance_to(b) + 0.3
		Synty.por3(m, "SM_Bld_Castle_Wall_01", Vector3(meio.x, Regiao.NIVEL_CANAL - 1.6, meio.y), giro, Vector3(comp / 5.0, (Regiao.ALTURA_CIDADE - Regiao.NIVEL_CANAL + 1.5) / 5.0, 0.6), false)
		Synty.por3(m, "SM_Env_StoneWall_01", Vector3(meio.x, Regiao.ALTURA_CIDADE - 0.05, meio.y), giro, Vector3(comp / 5.1, 0.75, 0.8), false)
		m._colisor_caixa(Vector3(meio.x, Regiao.ALTURA_CIDADE - 0.1, meio.y), Vector3(0.6, 1.0, comp), atan2(dl.x, dl.y))
func _perto_ponte_ilha(a: float) -> bool:
	for pa in [PI * 0.83, PI * 0.42, -PI * 0.12, -PI * 0.55]:
		if absf(wrapf(a - pa, -PI, PI)) < 0.12: return true
	return false

func _porto() -> void:
	var yp := Regiao.NIVEL_PORTO; var xq := 2240.0
	for zz in [-20.0, 75.0, 170.0]:                                             # píeres de madeira entrando no mar
		for i in 10:
			Synty.por3(m, "SM_Bld_Bridge_01", Vector3(xq - 4.0 + i * 5.4, yp + 0.4, zz), 0.0, Vector3(1.0, 1.5, 1.3), false)
		m._colisor_caixa(Vector3(xq + 22.0, yp + 0.1, zz), Vector3(7.0, 0.6, 56.0), PI * 0.5)
		for lado in [-1.0, 1.0]:
			for k in 2:
				var b := Vector2(xq + 10.0 + k * 20.0 + rng.randf_range(0.0, 6.0), zz + lado * 7.5)
				Synty.por(m, "SM_Veh_Boat_Dinghy_01", Vector3(b.x, 0.25, b.y), PI * 0.5 + rng.randf_range(-0.3, 0.3), 1.6, false)
	Synty.por(m, "SM_Bld_Preset_Tower_01_Optimized", Vector3(xq + 52.0, 1.5, 75.0), 0.0, 0.9, true)   # farol
	for zz in range(-35, 245, 24):                                               # armazéns encostados no degrau
		var q := Vector2(Regiao.X_PORTO + 18.0, zz)
		if absf(zz - 75.0) < 14.0 or Regiao.dist_canal(q.x, q.y) < 12.0 or m.perto_de_casa(q.x, q.y, 9.0): continue
		m._casa(Vector3(q.x, yp, q.y), PI * 0.5, 15.0, 10.0, 8.0, null, null, true, _sorte(["SM_Bld_Preset_House_04_Optimized", "SM_Bld_Preset_Stables_01_Optimized", "SM_Bld_Preset_Shelter_01_Optimized"]), 1.0)
	for k in 8:
		var q := Vector2(xq - 14.0, 90.0 + k * 6.0)
		_por(_sorte(["SM_Prop_Market_Stall_02", "SM_Prop_Market_Stall_05", "SM_Prop_Market_Stall_08"]), q, -PI * 0.5, 1.0, true, yp)
		_por("SM_Prop_Bucket_Fish_01", q + Vector2(-2.2, 0), 0.0, 1.0, false, yp)
	for k in 40:
		var q := Vector2(rng.randf_range(xq - 30.0, xq - 4.0), rng.randf_range(-45.0, 245.0))
		if absf(q.y - 75.0) < 6.0 or Regiao.dist_canal(q.x, q.y) < 7.0 or m.perto_de_casa(q.x, q.y, 2.0): continue
		_por(_sorte(["SM_Prop_Crate_Stack_01", "SM_Prop_Crate_Stack_02", "SM_Prop_Barrel_Stack_01", "SM_Prop_Barrel_Stack_04", "SM_Prop_Sack_Stack_01",
			"SM_Prop_Crate_Wood_01", "SM_Veh_Cart_02", "SM_Veh_Wheelbarrow_01", "SM_Prop_Oar_01"]), q, rng.randf() * TAU, 1.0, true, yp)
	# escadarias do cais (do nível da cidade para o porto) nas ruas que descem
	for zr in [75.0, 175.0]:
		Synty.por3(m, "SM_Bld_Stairs_Straight_01", Vector3(Regiao.X_PORTO, yp - 0.1, zr), PI, Vector3(18.0 / 5.0, (Regiao.ALTURA_CIDADE - yp) / 5.0, 5.0), false, true)
	m.porto_pos = Vector2(xq - 10.0, 75.0)
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
			if a.distance_to(v) > 95.0: break
			var b2 := a + (b - a).limit_length(maxf(95.0 - acum, 0.0))
			_fila(a, b2, 12.0, 12.0, yv, pular)
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
	var y0 := Regiao.ALTURA_CIDADE
	# na porta das casas da cidade: floreiras, barris, caixotes, sacos, vasos, bancos; atrás: varais
	for ca in m.casas:
		var pos: Vector3 = ca[0]; var ang: float = ca[1]; var d: float = ca[3]
		if not Regiao.dentro_cidade(Vector2(pos.x, pos.z)): continue
		var fr := Vector2(sin(ang), cos(ang)); var ld := Vector2(fr.y, -fr.x)
		var porta := Vector2(pos.x, pos.z) + fr * (d * 0.5 + 1.4)
		if rng.randf() < 0.75:
			var q := porta + ld * rng.randf_range(2.0, 4.0) * (1.0 if rng.randf() < 0.5 else -1.0)
			if Regiao.rua_cidade(q.x, q.y) > 3.5:
				_por(_sorte(["SM_Prop_PlanterBox_Preset_01", "SM_Prop_PlanterBox_Preset_02", "SM_Prop_PlanterBox_Preset_03", "SM_Prop_PlanterBox_Preset_04",
					"SM_Env_Planter_Preset_01", "SM_Env_Planter_Preset_02", "SM_Prop_Barrel_Stack_02", "SM_Prop_Crate_Stack_03", "SM_Prop_Sack_Stack_01",
					"SM_Env_Planter_Pedestal_01_Preset_01", "SM_Prop_Bench_Seat_03", "SM_Prop_Wood_Pile_02"]), q, ang, 1.0, true, Regiao.altura_cidade(q.x, q.y))
		if rng.randf() < 0.3:
			var tr := Vector2(pos.x, pos.z) - fr * (d * 0.5 + 3.0)
			_por(_sorte(["SM_Prop_WashingLine_01_Preset_01", "SM_Prop_WashingLine_01_Preset_02", "SM_Prop_Hanging_Clothes_Line_02"]), tr, ang + PI * 0.5, 1.0, false, Regiao.altura_cidade(tr.x, tr.y))
	# bandeirolas por cima das ruas principais
	for r in Regiao.RUAS:
		for i in r.size() - 1:
			var a: Vector2 = r[i]; var b: Vector2 = r[i + 1]; var dl := (b - a).normalized()
			var sp := 15.0
			while sp < a.distance_to(b):
				var q := a + dl * sp
				if Regiao.dentro_cidade(q) and q.distance_to(Regiao.PRACA) > 25.0 and Regiao.dist_canal(q.x, q.y) > 8.0:
					Synty.por(m, _sorte(["SM_Prop_Bunting_03", "SM_Prop_Bunting_04"]), Vector3(q.x, Regiao.altura_cidade(q.x, q.y) + 5.5, q.y), atan2(-dl.x, -dl.y) + PI * 0.5, 0.55, false)
				sp += 30.0
	# estandartes na muralha (lado de dentro)
	for l in [Regiao.MURALHA, Regiao.MURALHA_SUL]:
		for i in l.size() - 1:
			for t in _ao_longo(l[i], l[i + 1], 22.0):
				var q: Vector2 = t + (Regiao.CIDADE_C - t).normalized() * 2.0
				Synty.por(m, _sorte(["SM_Prop_Banner_01", "SM_Prop_Banner_02", "SM_Prop_Banner_03", "SM_Prop_Banner_04"]), Vector3(q.x, y0 + 10.0, q.y), _virado(t, Regiao.CIDADE_C), 2.0, false)
	# praça da justiça (Cidade Velha) e jardim dos nobres
	var ju := Vector2(2110.0, -95.0)
	if not m.perto_de_casa(ju.x, ju.y, 6.0):
		_por("SM_Prop_Gallows_Platform_02", ju, 0.0, 1.0, true, y0); _por("SM_Prop_Guillotine_01", ju + Vector2(9, 0), 0.0, 1.0, true, y0)
		m.lugares.append([ju, 10.0])
	var nb := Vector2(1950.0, -70.0)
	_por("SM_Env_Big_Tree_Base_Paving_01", nb, 0.0, 1.0, false, y0); _por("SM_Env_Big_Tree_01", nb, 0.0, 0.8, true, y0)
	for k in 4:
		var q := nb + Vector2(cos(k * PI * 0.5 + 0.4), sin(k * PI * 0.5 + 0.4)) * 11.0
		_por("SM_Env_Hedge_01", q, k * PI * 0.5 + 0.4 + PI * 0.5, 1.0, true, y0)
	# postes de amarrar cavalo e placa na entrada
	for lado in [-1.0, 1.0]: _por("SM_Prop_Horse_Hitching_Post_01", Regiao.PORTAO + Vector2(-30.0, lado * 9.0), 0.0, 1.0, true)
	_por("SM_Prop_Direction_Sign_01", Regiao.PORTAO + Vector2(-60.0, -7.0), PI * 0.5, 1.0, true)

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
	for i in 7000:
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
			_por(_sorte(["SM_Env_Flowers_01", "SM_Env_Flowers_04", "SM_Env_Sunflower_01", "MF:SM_Env_Wildflowers_01", "MF:SM_Env_Wildflowers_02", "MF:SM_Env_Wildflowers_03", "MF:SM_Env_Flowers_Flat_01"]), q, rng.randf() * TAU, 1.0, false, h - 0.05)
		elif r.floresta(x, z) > 0.3 and rng.randf() < 0.35:
			_por(_sorte(["MF:SM_Prop_Mushroom_Group_02", "MF:SM_Prop_Mushroom_Group_03", "MF:SM_Prop_Mushroom_Sparse_01", "MF:SM_Env_Rock_Pile_03", "MF:SM_Env_Rock_Small_Pile_01", "MF:SM_Prop_Leaves_Pile_01"]), q, rng.randf() * TAU, 1.5, false, h - 0.05)
	# beira do lago: juncos e lírios
	var lg := Vector2(Regiao.LAGO.x, Regiao.LAGO.y)
	for k in 60:
		var a := rng.randf() * TAU; var q := lg + Vector2(cos(a), sin(a)) * (Regiao.LAGO.z + rng.randf_range(-6.0, 3.0))
		if k % 3 == 0: _por(_sorte(["SM_Env_Lily_01", "SM_Env_Lily_02", "SM_Env_Lily_03"]), q, rng.randf() * TAU, 1.0, false, r.nivel_lago() - 0.9)
		else: _por(_sorte(["SM_Env_Reeds_01", "SM_Env_Reeds_02", "SM_Env_Reeds_03"]), q, rng.randf() * TAU, 1.2, false, r.altura(q.x, q.y) - 0.2)

# ---------- lugares para explorar ----------
var lugares_bussola := []
var lugares_bussola_extra := false
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

# ======================================================================================================
# INTERIORES: salas montadas com as paredes e os pisos modulares do pacote, embaixo do mapa (y = -300), com os
# móveis do pacote e gente dentro. Perto da porta aparece ENTRAR (lá dentro, SAIR): m.portas
# ======================================================================================================
const ESCADA_GIRO := PI
const T := 2.5                     # módulo das peças (m)
func _peca_int(nome: String, p: Vector3, ang := 0.0, esc := 1.0, col := false) -> void:
	Synty.por(m, nome, p, ang, esc, col)

# sala de nx × nz módulos com "alt" andares de parede; porta no meio da parede sul (+Z). Devolve o ponto de dentro da porta.
func _sala(o: Vector3, nx: int, nz: int, piso: String, paredes: Array, alt: int, porta_parede := "SM_Bld_House_Wall_Door_01") -> Vector3:
	var pe := 0.5 if paredes[0].begins_with("SM_Bld_Castle_") else 1.0          # peças do castelo têm 5 m: metade
	for i in nx:
		for j in nz:
			_peca_int(piso, o + Vector3((i + 0.5) * T, 0.0, (j + 0.5) * T))
			_peca_int(piso, o + Vector3((i + 0.5) * T, alt * T, (j + 0.5) * T), 0.0)                 # teto
	var porta_i := nx / 2
	for k in alt:
		var y := o.y + k * T
		for i in nx:
			var pn := Vector3(o.x + (i + 0.5) * T, y, o.z)
			var ps := Vector3(o.x + (i + 0.5) * T, y, o.z + nz * T)
			_peca_int(_sorte(paredes), pn, 0.0, pe)
			if k == 0 and i == porta_i: _peca_int(porta_parede, ps, PI)
			else: _peca_int(_sorte(paredes), ps, PI, pe)
		for j in nz:
			_peca_int(_sorte(paredes), Vector3(o.x, y, o.z + (j + 0.5) * T), PI * 0.5, pe)
			_peca_int(_sorte(paredes), Vector3(o.x + nx * T, y, o.z + (j + 0.5) * T), -PI * 0.5, pe)
	# colisão: chão e quatro paredes (a porta fica fechada: sai pelo botão SAIR)
	var w := nx * T; var d := nz * T; var h := alt * T
	m._colisor_caixa(Vector3(o.x + w * 0.5, o.y - 0.5, o.z + d * 0.5), Vector3(w + 2.0, 1.0, d + 2.0), 0.0)
	m._colisor_caixa(Vector3(o.x + w * 0.5, o.y, o.z - 0.3), Vector3(0.6, h, w + 1.0), PI * 0.5)
	m._colisor_caixa(Vector3(o.x + w * 0.5, o.y, o.z + d + 0.3), Vector3(0.6, h, w + 1.0), PI * 0.5)
	m._colisor_caixa(Vector3(o.x - 0.3, o.y, o.z + d * 0.5), Vector3(0.6, h, d + 1.0), 0.0)
	m._colisor_caixa(Vector3(o.x + w + 0.3, o.y, o.z + d * 0.5), Vector3(0.6, h, d + 1.0), 0.0)
	return Vector3(o.x + (porta_i + 0.5) * T, o.y, o.z + d - 1.6)

func _gente(tipo: String, p: Vector3, olhar: Vector3) -> void:
	if not Cidadao.existe(): return
	var c := Cidadao.new(); c.tipo = tipo; c.fixo = true; c.olhar = Vector2(olhar.x, olhar.z)
	m.raiz.add_child(c); c.position = p; c.montar(m, 9500 + _n_cid); _n_cid += 1

func _porta(nome: String, fora: Vector2, ang_fora: float, dentro: Vector3) -> void:
	var yf: float = m.reg.altura(fora.x, fora.y)
	if Regiao.CIDADE.has_point(fora): yf = Regiao.altura_cidade(fora.x, fora.y)
	m.portas.append([Vector3(fora.x, yf, fora.y), dentro, ang_fora, PI, nome])

const PAREDE_MADEIRA := ["SM_Bld_House_Wall_01", "SM_Bld_House_Wall_02", "SM_Bld_House_Wall_03"]
const PAREDE_PEDRA := ["SM_Bld_Castle_Wall_01", "SM_Bld_Castle_Wall_02", "SM_Bld_Castle_Wall_03"]

func _interiores() -> void:
	m.portas = []
	var base := Vector3(1000.0, -300.0, -1000.0)
	# ---- taverna de Altamar
	var o := base
	var d := _sala(o, 6, 5, "SM_Bld_House_Floor_Wood_01", PAREDE_MADEIRA, 2)
	for i in 3: _peca_int("SM_Prop_Bar_02", o + Vector3(4.5 + i * 2.7, 0, 2.6), PI * 0.5, 1.0, true)
	_peca_int("SM_Prop_Barrel_Dispenser_Large_01", o + Vector3(7.5, 0, 0.9), PI * 0.5)
	_peca_int("SM_Bld_House_Fireplace_01", o + Vector3(14.6, 0, 6.2), -PI * 0.5)
	_peca_int("SM_Prop_Animal_Head_Deer_01", o + Vector3(0.3, 2.6, 6.2), PI * 0.5)
	_peca_int("SM_Prop_Chandelier_01", o + Vector3(7.5, 3.0, 7.0))
	_peca_int("SM_Prop_Rug_02_Round", o + Vector3(7.5, 0.02, 8.0))
	for q in [Vector3(3.0, 0, 7.0), Vector3(3.0, 0, 10.0), Vector3(11.5, 0, 7.5), Vector3(11.5, 0, 10.5)]:
		_peca_int(_sorte(["SM_Prop_Table_Preset_01", "SM_Prop_Table_Preset_02", "SM_Prop_Table_Preset_03"]), o + q, PI * 0.5, 1.0, true)
		for lado in [-1.0, 1.0]: _peca_int(_sorte(["SM_Prop_Stool_02", "SM_Prop_Stool_03"]), o + q + Vector3(0, 0, lado * 1.0))
	_gente("SM_Chr_Bartender_01", o + Vector3(7.5, 0, 1.6), o + Vector3(7.5, 0, 8.0))
	for q in [Vector3(2.2, 0, 7.6), Vector3(12.3, 0, 8.2), Vector3(3.8, 0, 10.6), Vector3(6.0, 0, 3.8)]:
		_gente(_sorte(["SM_Chr_Peasant_Male_01", "SM_Chr_Hermit_01", "SM_Chr_Rider_01", "SM_Chr_Peasant_Female_01"]), o + q, o + Vector3(7.5, 0, 6.0))
	_porta("Taverna de Altamar", m.taverna_pos + Vector2(0, -9.0), PI, d)
	# ---- catedral
	o = base + Vector3(60, 0, 0)
	d = _sala(o, 6, 12, "SM_Bld_House_Floor_Stone_01", PAREDE_PEDRA, 3)
	_peca_int("SM_Prop_Throne_Plinth_01", o + Vector3(7.5, 0, 3.0), 0.0, 1.2, true)
	_peca_int("SM_Prop_Church_Lectern_01", o + Vector3(7.5, 0.5, 4.4), 0.0)
	for lado in [-1.0, 1.0]:
		for k in 8: _peca_int("SM_Prop_Bench_Seat_Pew_01", o + Vector3(7.5 + lado * 3.6, 0, 9.0 + k * 2.4), PI, 1.0, true)
		_peca_int("SM_Prop_Curtain_Large_01", o + Vector3(7.5 + lado * 5.0, 0, 0.5), 0.0)
		for k in 4: _peca_int(_sorte(["SM_Prop_Banner_01", "SM_Prop_Banner_03"]), o + Vector3(7.5 + lado * 7.2, 6.0, 8.0 + k * 6.0), -lado * PI * 0.5, 1.5)
	for k in 3: _peca_int("SM_Prop_Chandelier_02", o + Vector3(7.5, 4.8, 9.0 + k * 8.0))
	_peca_int("SM_Prop_Rug_01", o + Vector3(7.5, 0.02, 18.0), 0.0, 2.0)
	_gente("SM_Chr_Priest_01", o + Vector3(7.5, 0.5, 3.6), o + Vector3(7.5, 0, 20.0))
	_gente("SM_Chr_Nun_01", o + Vector3(5.0, 0, 5.5), o + Vector3(7.5, 0, 20.0))
	for k in 6: _gente(_sorte(["SM_Chr_Peasant_Male_01", "SM_Chr_Peasant_Female_01", "SM_Chr_Monk_01", "SM_Chr_Merchant_01"]), o + Vector3(4.0 + (k % 2) * 7.0, 0, 10.2 + (k / 2) * 4.8), o + Vector3(7.5, 0, 0.0))
	_porta("Catedral", cat_pos() + Vector2(0, 18.0), 0.0, d)
	# ---- sala do trono do castelo
	o = base + Vector3(120, 0, 0)
	d = _sala(o, 8, 10, "SM_Bld_House_Floor_Stone_01", PAREDE_PEDRA, 3)
	_peca_int("SM_Prop_Throne_Plinth_01", o + Vector3(10.0, 0, 2.6), 0.0, 1.4, true)
	_peca_int("SM_Prop_Throne_01", o + Vector3(9.0, 0.55, 2.3), 0.0, 1.2)
	_peca_int("SM_Prop_Throne_02", o + Vector3(11.0, 0.55, 2.3), 0.0, 1.2)
	for k in 5: _peca_int("SM_Prop_Rug_01", o + Vector3(10.0, 0.02, 6.0 + k * 3.6), 0.0, 1.4)
	for lado in [-1.0, 1.0]:
		for k in 3: _peca_int("SM_Prop_Banner_02", o + Vector3(10.0 + lado * 9.7, 5.0, 6.0 + k * 7.0), -lado * PI * 0.5, 1.6)
		for k in 3: _peca_int("SM_Prop_Table_Preset_04", o + Vector3(10.0 + lado * 6.0, 0, 9.0 + k * 3.0), 0.0, 1.0, true)
		for k in 3: _gente("SM_Chr_Soldier_Male_01", o + Vector3(10.0 + lado * 2.6, 0, 8.0 + k * 5.0), o + Vector3(10.0, 0, 8.0 + k * 5.0))
	for k in 2: _peca_int("SM_Prop_Chandelier_03", o + Vector3(10.0, 5.0, 8.0 + k * 9.0))
	_peca_int("SM_Prop_Map_01", o + Vector3(3.0, 0.9, 20.0), 0.0, 1.5)
	_peca_int("SM_Prop_Table_Preset_01", o + Vector3(3.0, 0, 20.0), 0.0, 1.0, true)
	_gente("SM_Chr_King_01", o + Vector3(9.0, 0.55, 3.0), o + Vector3(9.0, 0, 20.0))
	_gente("SM_Chr_Queen_01", o + Vector3(11.0, 0.55, 3.0), o + Vector3(11.0, 0, 20.0))
	_gente("SM_Chr_Jester_01", o + Vector3(10.0, 0, 9.0), o + Vector3(10.0, 0, 2.0))
	_porta("Castelo de Altamar", Regiao.CASTELO + Vector2(0, 14.0), 0.0, d)
	# ---- taverna da vila
	o = base + Vector3(180, 0, 0)
	d = _sala(o, 5, 4, "SM_Bld_House_Floor_Wood_01", PAREDE_MADEIRA, 2)
	_peca_int("SM_Prop_Bar_01", o + Vector3(3.0, 0, 2.0), PI * 0.5, 1.0, true)
	_peca_int("SM_Bld_House_Fireplace_01", o + Vector3(12.2, 0, 5.0), -PI * 0.5)
	for q in [Vector3(4.0, 0, 6.5), Vector3(9.0, 0, 6.5)]:
		_peca_int("SM_Prop_Table_Preset_02", o + q, PI * 0.5, 1.0, true)
		for lado in [-1.0, 1.0]: _peca_int("SM_Prop_Stool_02", o + q + Vector3(0, 0, lado * 1.0))
	_gente("SM_Chr_Bartender_01", o + Vector3(3.0, 0, 1.0), o + Vector3(3.0, 0, 6.0))
	_gente("SM_Chr_Peasant_Male_01", o + Vector3(9.0, 0, 7.5), o + Vector3(9.0, 0, 6.5))
	_porta("Taverna da Vila", Regiao.VILA + Vector2(-34.0, -14.0), 0.0, d)
	# ---- oficina de alquimia (torre dos magos)
	o = base + Vector3(240, 0, 0)
	d = _sala(o, 4, 4, "SM_Bld_House_Floor_Stone_01", PAREDE_PEDRA, 2)
	_peca_int("SM_Prop_Workbench_Alchemy_01_Preset", o + Vector3(5.0, 0, 1.0), 0.0, 1.0, true)
	for k in 3: _peca_int(_sorte(["SM_Prop_Shelves_01", "SM_Prop_Shelves_02"]), o + Vector3(0.4, 0, 2.5 + k * 2.4), PI * 0.5, 1.0, true)
	_peca_int("SM_Prop_Cauldron_01", o + Vector3(7.5, 0, 6.0), 0.0, 1.2, true)
	_peca_int("SM_Prop_Planetarium_01", o + Vector3(8.6, 0, 1.6), 0.0, 1.0, true)
	_peca_int("SM_Prop_Rug_02_Round", o + Vector3(5.0, 0.02, 5.0))
	_gente("SM_Chr_Mage_01", o + Vector3(5.0, 0, 2.2), o + Vector3(5.0, 0, 8.0))
	_porta("Torre dos Magos", tm_pos() + Vector2(0, 10.5), 0.0, d)
	# ---- ferrarias (vila e Altamar): forja, bigornas, fole, rebolo, armas nas paredes, bancada, ferreiros
	for k in 2:
		o = base + Vector3(300 + k * 60, 0, 0)
		d = _sala(o, 5, 4, "SM_Bld_House_Floor_Stone_01", PAREDE_MADEIRA, 2)
		_peca_int("SM_Prop_Forge_02", o + Vector3(6.25, 0, 1.4), 0.0, 1.2, true)
		_peca_int("SM_Prop_Bellows_01", o + Vector3(3.6, 0, 1.2), 0.0, 1.0, true)
		_peca_int("SM_Prop_Anvil_01", o + Vector3(6.25, 0, 4.6), PI * 0.5, 1.6, true)
		_peca_int("SM_Prop_Anvil_02", o + Vector3(9.5, 0, 5.2), 0.3, 1.4, true)
		_peca_int("SM_Prop_Grinding_Wheel_01", o + Vector3(2.0, 0, 6.5), 0.5, 1.0, true)
		_peca_int("SM_Prop_Workbench_01_Preset", o + Vector3(11.0, 0, 2.0), -PI * 0.5, 1.0, true)
		for j in 3: _peca_int(_sorte(["SM_Prop_Weapon_Rack_01", "SM_Prop_Weapon_Rack_02", "SM_Prop_Weapon_Rack_03"]), o + Vector3(0.6, 0, 2.5 + j * 2.4), PI * 0.5, 1.0, true)
		_peca_int("SM_Prop_Mannequin_01", o + Vector3(11.6, 0, 7.4), -PI * 0.7, 1.0, true)
		_peca_int("SM_Prop_Barrel_Arrows_01", o + Vector3(9.0, 0, 8.6), 0.0, 1.0, true)
		_peca_int("SM_Prop_Barrel_Stack_01", o + Vector3(11.8, 0, 9.0), 0.0, 1.0, true)
		_gente("SM_Chr_Blacksmith_Male_01", o + Vector3(6.25, 0, 5.6), o + Vector3(6.25, 0, 4.6))
		_gente("SM_Chr_Blacksmith_Female_01", o + Vector3(3.0, 0, 6.6), o + Vector3(2.0, 0, 6.5))
		if k == 0:
			var fe: Vector2 = m.ferraria_pos + Vector2(1.2, 9.5)
			_porta("Ferraria do Bram", fe + Vector2(5.0, -6.5), PI, d)
		else:
			for l in m.cidade_lojas:
				if l[0] == "ferreiro": _porta("Ferraria de Altamar", l[1], 0.0, d); break
	# ---- igreja da vila: bancos, púlpito, cruz, velas, monge e camponeses rezando
	o = base + Vector3(420, 0, 0)
	d = _sala(o, 4, 7, "SM_Bld_House_Floor_Wood_01", PAREDE_MADEIRA, 3)
	_peca_int("SM_Prop_Church_Lectern_01", o + Vector3(5.0, 0, 2.6), 0.0)
	_peca_int("SM_Prop_Cross_01", o + Vector3(5.0, 0, 0.6), 0.0, 1.2)
	for lado in [-1.0, 1.0]:
		for j in 4: _peca_int("SM_Prop_Bench_Seat_Pew_01", o + Vector3(5.0 + lado * 2.4, 0, 6.0 + j * 2.4), PI, 0.8, true)
		_peca_int("FX_Item_Candlestick_01", o + Vector3(5.0 + lado * 1.6, 0, 1.6), 0.0, 1.0)
	_peca_int("SM_Prop_Rug_01", o + Vector3(5.0, 0.02, 10.0), 0.0, 1.2)
	_gente("SM_Chr_Monk_01", o + Vector3(5.0, 0, 3.2), o + Vector3(5.0, 0, 12.0))
	for j in 3: _gente(_sorte(["SM_Chr_Peasant_Male_01", "SM_Chr_Peasant_Female_01"]), o + Vector3(2.6 + (j % 2) * 4.8, 0, 6.6 + j * 2.4), o + Vector3(5.0, 0, 0.0))
	if not m.igreja_vila.is_empty(): _porta("Igreja da Vila", (m.igreja_vila[0] as Vector2) + Vector2(0, 8.5), 0.0, d)
	# ---- taverna da Vila da Serra
	o = base + Vector3(480, 0, 0)
	d = _sala(o, 4, 4, "SM_Bld_House_Floor_Wood_01", PAREDE_MADEIRA, 2)
	_peca_int("SM_Prop_Bar_03", o + Vector3(2.5, 0, 2.2), PI * 0.5, 1.0, true)
	_peca_int("SM_Bld_House_Fireplace_01", o + Vector3(9.7, 0, 5.0), -PI * 0.5)
	_peca_int("SM_Prop_Table_Preset_03", o + Vector3(5.5, 0, 6.5), PI * 0.5, 1.0, true)
	for lado in [-1.0, 1.0]: _peca_int("SM_Prop_Stool_02", o + Vector3(5.5, 0, 6.5 + lado))
	_gente("SM_Chr_Bartender_01", o + Vector3(2.5, 0, 1.2), o + Vector3(2.5, 0, 6.0))
	_gente("SM_Chr_Hermit_01", o + Vector3(5.5, 0, 7.5), o + Vector3(5.5, 0, 6.5))
	var vn := Regiao.VILA_NORTE; var tq := vn + Vector2(46.0, -8.0)
	_porta("Taverna da Serra", tq + (vn - tq).normalized() * 7.5, _virado(tq, vn) + PI, d)

# ---------- Vila da Serra (pequena, ao norte, na Estrada do Norte): casas de madeira, serraria, poço ----------
func _vila_norte() -> void:
	var v := Regiao.VILA_NORTE
	_por("SM_Prop_Well_01", v, 0.0, 1.3, true)
	var tipos := ["SM_Bld_Preset_Hut_01_Optimized", "SM_Bld_Preset_Hut_02_Optimized", "SM_Bld_Preset_House_02_A_Optimized",
		"SM_Bld_Preset_House_08_Optimized", "SM_Bld_Preset_Shelter_01_Optimized", "SM_Bld_Preset_House_03_Optimized"]
	for k in 11:
		var a := TAU * k / 11.0 + rng.randf_range(-0.12, 0.12); var r := rng.randf_range(20.0, 34.0)
		var q := v + Vector2(cos(a), sin(a)) * r
		if m.reg.dist_estrada(q.x, q.y) < 8.0 or m.perto_de_casa(q.x, q.y, 6.0): continue
		m._casa(Vector3(q.x, 0, q.y), _virado(q, v), 7.0, 7.0, 5.0, null, null, false, tipos[k % tipos.size()], 1.0)
	m._casa(Vector3(v.x + 46.0, 0, v.y - 8.0), _virado(v + Vector2(46, -8), v), 12.0, 10.0, 9.0, null, null, false, "SM_Bld_Preset_Tavern_01_Optimized", 0.85)
	for k in 12:
		var q := v + Vector2(rng.randf_range(-40, 40), rng.randf_range(-40, 40))
		if q.distance_to(v) < 5.0 or not _livre(q, 2.0): continue
		_por(_sorte(["SM_Prop_Wood_Pile_01", "SM_Prop_Wood_Pile_02", "SM_Prop_Log_01", "SM_Prop_Ground_Logs_01", "SM_Prop_Chopping_Board_01",
			"SM_Veh_Cart_03", "SM_Prop_Hay_Bale_01", "SM_Prop_Barrel_Stack_01", "SM_Prop_Camp_Firepit_01"]), q, rng.randf() * TAU, 1.0, true)
	for k in 4: m._poste_em(v + Vector2(cos(k * PI * 0.5 + 0.4), sin(k * PI * 0.5 + 0.4)) * 11.0, v)
	_multidao(v, 35.0, 9, ["SM_Chr_Peasant_Male_01", "SM_Chr_Peasant_Female_01", "SM_Chr_Hermit_01", "SM_Chr_Blacksmith_Male_01", "SM_Chr_Monk_01"])
	m.lugares.append([v, 40.0])
	lugares_bussola.append(["Vila da Serra", v, "vila", 45.0])

# ---------- Estrada dos Heróis: estátuas gigantes nos dois lados da Estrada Real antes do Portão Oeste ----------
func _estrada_dos_herois() -> void:
	var linha: PackedVector2Array = m.reg.estradas[m.reg.estrada_real]
	var tipos := ["SM_Prop_Statue_Hero_01", "SM_Prop_Statue_Knight_02", "SM_Prop_Statue_Hero_02", "SM_Prop_Statue_Knight_01"]
	var k := 0
	for sp in [70.0, 110.0, 150.0, 190.0]:
		var pr: Array = m._ponto_na_linha(linha, _comp(linha) - 40.0 - sp)
		var pt: Vector2 = pr[0]; var tg: Vector2 = pr[1]; var nr := Vector2(-tg.y, tg.x)
		for lado in [-1.0, 1.0]:
			var q: Vector2 = pt + nr * lado * 12.0
			var y: float = m.reg.altura(q.x, q.y)
			Synty.por(m, "SM_Prop_Statue_Plinth_02", Vector3(q.x, y - 0.2, q.y), _virado(q, pt), 2.2, true)
			var topo := Synty.caixa("SM_Prop_Statue_Plinth_02").end.y * 2.2
			Synty.por(m, tipos[k % tipos.size()], Vector3(q.x, y - 0.3 + topo, q.y), _virado(q, pt), 3.2, false)
			m._poste_em(q + tg * 6.0 - nr * lado * 4.0, pt)
			k += 1
	lugares_bussola.append(["Estrada dos Heróis", (m._ponto_na_linha(linha, _comp(linha) - 170.0) as Array)[0], "castelo", 25.0])

func _comp(l: PackedVector2Array) -> float:
	var t := 0.0
	for i in l.size() - 1: t += l[i].distance_to(l[i + 1])
	return t

# ---------- fumaça saindo das chaminés (casas da cidade e das vilas, nem todas) ----------
func _fumaca_chamines() -> void:
	var tex := GradientTexture2D.new(); tex.fill = GradientTexture2D.FILL_RADIAL; tex.fill_from = Vector2(0.5, 0.5); tex.fill_to = Vector2(1.0, 0.5)
	var gr := Gradient.new(); gr.set_color(0, Color(1, 1, 1, 0.55)); gr.set_color(1, Color(1, 1, 1, 0.0)); tex.gradient = gr
	var mt := StandardMaterial3D.new(); mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mt.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES; mt.albedo_texture = tex; mt.vertex_color_use_as_albedo = true
	var quad := QuadMesh.new(); quad.size = Vector2(1.6, 1.6); quad.material = mt
	var n := 0
	for ca in m.casas:
		if rng.randf() > 0.35: continue
		var pos: Vector3 = ca[0]; var ang: float = ca[1]; var w: float = ca[2]
		var topo := pos + Vector3(0, 9.0, 0) + Vector3(sin(ang + PI * 0.5), 0, cos(ang + PI * 0.5)) * w * 0.25
		var f := CPUParticles3D.new(); f.mesh = quad; f.amount = 7; f.lifetime = 5.0; f.preprocess = 5.0
		f.direction = Vector3(0.25, 1, 0); f.spread = 12.0; f.initial_velocity_min = 0.6; f.initial_velocity_max = 1.0; f.gravity = Vector3(0.15, 0.05, 0)
		f.scale_amount_min = 0.8; f.scale_amount_max = 1.4
		var cs := Curve.new(); cs.add_point(Vector2(0, 0.4)); cs.add_point(Vector2(1, 2.2)); f.scale_amount_curve = cs
		f.color = Color(0.72, 0.72, 0.74, 0.7)
		f.position = topo; f.visibility_range_end = 120.0
		m.raiz.add_child(f); n += 1

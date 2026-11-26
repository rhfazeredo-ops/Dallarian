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

var rede_nos := []
var rede_viz := []
var marcos := {"barraca": [], "balcao": [], "caminho": [], "pulpito": [], "anjo": []}
func _altamar() -> void:
	m.cidade_pos = Regiao.CIDADE_C; m.cidade_y = Regiao.ALTURA_CIDADE
	m.lugares.append([Regiao.CIDADE_C, 150.0])                            # nada do resto do mapa nasce dentro da cidade
	if not ResourceLoader.exists("res://arte/altamar/cena.json"): return
	var D := Regiao.ALTAMAR_DESL
	var lista: Array = JSON.parse_string(FileAccess.get_file_as_string("res://arte/altamar/cena.json"))
	var agua := ShaderMaterial.new(); agua.shader = load("res://shaders/agua.gdshader"); agua.set_shader_parameter("neblina", m.NEBLINA)
	for o in lista:
		var t: Array = o.t; var nome: String = o.n
		var T := Transform3D(Basis(Vector3(t[0], t[1], t[2]), Vector3(t[3], t[4], t[5]), Vector3(t[6], t[7], t[8])), Vector3(t[9], t[10], t[11]) + D)
		if nome.begins_with("SM_Env_Water"):                                 # rio e cachoeiras: a água do jogo
			for p in Synty.pecas(nome):
				var mi := MeshInstance3D.new(); mi.mesh = p[0]; mi.transform = T * (p[1] as Transform3D); mi.material_override = agua; m.raiz.add_child(mi)
			continue
		var r := _regra(nome)
		Synty.por_t(m, nome, T, r[0], r[1])
		_marco(nome, T)
	# o chão grande (morros, gramados), cortado no recorte, com colisão
	var chao: ArrayMesh = load("res://arte/altamar/chao.res")
	var mc := MeshInstance3D.new(); mc.mesh = chao; mc.position = D; mc.material_override = Synty.material(m.NEBLINA, "atlas")
	mc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; m.raiz.add_child(mc)
	var cb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var sh := ConcavePolygonShape3D.new()
	sh.set_faces(chao.get_faces()); sh.backface_collision = true; cs.shape = sh; cb.position = D; cb.add_child(cs); m.raiz.add_child(cb)
	_gente_de_altamar()

# colisão e distância de visão de cada peça, pelo nome
const SEM_COLISAO := ["Roof", "WoodBeam", "Supports", "Chimney", "Trim", "Shutter", "Banner", "Bunting", "Flag", "Sign", "Lamp", "Chandelier",
	"Curtain", "Rug", "Carpet", "Clothes", "Book", "Flower", "Cabbage", "Plant", "Path", "Candle", "Paper", "Cup", "Plate", "Bottle", "Food",
	"Bread", "Apple", "Fish", "Vine", "Ivy", "Grass", "Web", "Chain", "Rope", "Fx", "FX_"]
func _regra(n: String) -> Array:
	var cx := Synty.caixa(n); var tam := maxf(cx.size.x, maxf(cx.size.y, cx.size.z))
	var vis := 0
	if n.begins_with("SM_Item") or n.begins_with("FX_") or ((n.begins_with("SM_Prop") or n.begins_with("SM_Env_Planter")) and tam < 1.6): vis = 3
	elif n.begins_with("SM_Prop") or n.begins_with("SM_Env_Bush") or n.begins_with("SM_Env_Flower") or n.begins_with("SM_Env_Plant") or n.begins_with("SM_Generic_Grass"): vis = 4
	for k in SEM_COLISAO: if k in n: return ["", vis]
	if Synty.existe(n + "_Collision"): return ["colisao", vis]
	if n.begins_with("SM_Env_Tree"): return ["tronco", vis]
	for k in ["Ground", "Rock", "Cliff", "Stairs", "Bridge", "Door", "Arch", "Gate", "Floor", "Battlements", "Slope", "Ramp", "Well", "Fountain", "Base_Wall", "Base_Corner",
			"Pillars", "Window", "Gap", "Cut", "Hole", "Opening", "Railing", "Balcony", "Corbels"]:
		if k in n: return ["malha", vis]
	if n.begins_with("SM_Bld") or n.begins_with("SM_Env_Hedge") or n.begins_with("SM_Env_StoneWall") or n.begins_with("SM_Env_Fence"): return ["caixa", vis]
	if n.begins_with("SM_Prop") and tam >= 1.2 and cx.size.y >= 0.5: return ["caixa", vis]
	return ["", vis]

func _marco(n: String, T: Transform3D) -> void:
	if n.begins_with("SM_Prop_Market_Stall"): marcos.barraca.append(T)
	elif n.begins_with("SM_Prop_Bar_0"): marcos.balcao.append(T)
	elif n.begins_with("SM_Prop_Path_Brick") or n.begins_with("SM_Env_Path"): marcos.caminho.append(T.origin)
	elif n == "SM_Prop_Church_Lectern_01": marcos.pulpito.append(T)
	elif n == "SM_Prop_Statue_Angel_01": marcos.anjo.append(T)

# vendedores atrás das barracas, taverneiros atrás dos balcões, a freira na capela, o povo pelos caminhos de pedra
func _gente_de_altamar() -> void:
	var mercadorias := [["Frutas e verduras", "<Verdureira>"], ["Pães e bolos", "<Padeiro>"], ["Peixe fresco", "<Peixeiro>"], ["Tecidos finos", "<Tecelã>"],
		["Ervas e temperos", "<Herbalista>"], ["Cerâmica", "<Oleiro>"], ["Carnes e queijos", "<Açougueiro>"], ["Bugigangas", "<Mascate>"],
		["Armas usadas", "<Armeiro>"], ["Joias e anéis", "<Joalheiro>"]]
	var modelos := ["SM_Chr_Peasant_Female_01", "SM_Chr_Merchant_01", "SM_Chr_Peasant_Male_01", "SM_Chr_Peasant_Female_01", "SM_Chr_Hermit_01",
		"SM_Chr_Merchant_01", "SM_Chr_Bartender_01", "SM_Chr_FortuneTeller_01", "SM_Chr_Soldier_Male_01", "SM_Chr_Merchant_01"]
	var nomes := ["Marta", "Osvaldo", "Tobias", "Inês", "Gregório", "Anselmo", "Berta", "Zuleica", "Rufino", "Celeste"]
	var k := 0
	for T in marcos.barraca:
		var fr := Vector2(T.basis.z.x, T.basis.z.z).normalized()
		var p := Vector2(T.origin.x, T.origin.z) - fr * 1.4
		var i := k % mercadorias.size()
		_vendedor(nomes[i], mercadorias[i][1], mercadorias[i][0], modelos[i], p, p + fr * 4.0, T.origin.y)
		k += 1
	var perto_praca := func(a: Transform3D, b: Transform3D) -> bool: return Vector2(a.origin.x, a.origin.z).distance_to(Regiao.PRACA) < Vector2(b.origin.x, b.origin.z).distance_to(Regiao.PRACA)
	marcos.balcao.sort_custom(perto_praca); marcos.pulpito.sort_custom(perto_praca)
	var feitos := []
	for T in marcos.balcao:
		var q := Vector2(T.origin.x, T.origin.z)
		var perto := false
		for f in feitos: if q.distance_to(f) < 6.0: perto = true
		if perto: continue
		feitos.append(q)
		var fr := Vector2(T.basis.z.x, T.basis.z.z).normalized()
		var p := q - fr * 1.1
		_vendedor("Bartolomeu" if feitos.size() == 1 else _sorte(["Godofredo", "Rosália", "Amadeu"]), "<Taverneiro>",
			"Taverna O Javali Dourado" if feitos.size() == 1 else "Estalagem do Viajante", "SM_Chr_Bartender_01", p, p + fr * 4.0, T.origin.y, ["pocao_p", "pocao_m"])
		if feitos.size() == 1: m.taverna_pos = q
	if not marcos.pulpito.is_empty():
		var T: Transform3D = marcos.pulpito[0]
		var fr := Vector2(T.basis.z.x, T.basis.z.z).normalized()
		m._freira("Irmã Odília", Vector2(T.origin.x, T.origin.z) + fr * 2.5, fr, T.origin.y, 4343)
	for T in marcos.anjo:                                                    # a estátua de anjo da praça é uma Estátua da Guardiã
		if Vector2(T.origin.x, T.origin.z).distance_to(Regiao.PRACA) < 60.0:
			var fr := Vector2(T.basis.z.x, T.basis.z.z).normalized()
			m.estatuas.append([Vector2(T.origin.x, T.origin.z) + fr * 3.0, fr])
	# rede de caminhos (as pedras do chão): vizinhos a até 4,5 m; o povo anda de pedra em pedra
	var nos: Array = marcos.caminho
	var viz := []
	for i in nos.size(): viz.append([])
	for i in nos.size():
		for j in range(i + 1, nos.size()):
			var a: Vector3 = nos[i]; var b: Vector3 = nos[j]
			if absf(a.y - b.y) < 1.2 and Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z)) < 4.5: viz[i].append(j); viz[j].append(i)
	rede_nos = nos; rede_viz = viz
	var ligados := []
	for i in nos.size(): if viz[i].size() >= 1: ligados.append(i)
	if ligados.is_empty(): return
	for n in mini(70, ligados.size() / 3):
		var i: int = ligados[rng.randi() % ligados.size()]
		var c := Cidadao.new(); c.tipo = _sorte(POVO + ["SM_Chr_Soldier_Male_01", "SM_Chr_Peasant_Female_01", "SM_Chr_Peasant_Male_01"])
		c.rede = nos; c.viz = viz; c.no = i
		m.raiz.add_child(c); c.position = nos[i]; c.montar(m, 9000 + _n_cid); _n_cid += 1

# vendedor parado (barraca ou porta de loja): LOJA e CONVERSAR; as lojas ainda não têm mercadoria
func _vendedor(nome: String, cargo: String, loja: String, modelo: String, p: Vector2, olha: Vector2, y: float, itens := []) -> void:
	var v := Morador.new(); v.profissao = "vendedor"
	v.posto = p; v.olhar_posto = olha
	if nome == "": nome = _sorte(["Arnaldo", "Leonor", "Bento", "Catarina", "Dimas", "Filipa", "Heitor", "Joana", "Lauro", "Matilde"])
	v.set_meta("nome", nome); v.set_meta("cargo", cargo); v.set_meta("loja", loja); v.set_meta("modelo", modelo); v.set_meta("itens", itens)
	v.set_meta("y_fixo", y)
	m.raiz.add_child(v); v.position = Vector3(p.x, y, p.y)
	v.montar(m, 7700 + m.vendedores.size(), p, 1.0)
	m.vendedores.append(v)

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
	"SM_Chr_Monk_01", "SM_Chr_Bartender_01", "SM_Chr_Blacksmith_Male_01", "SM_Chr_Blacksmith_Female_01"]
var _n_cid := 0
func _cidadao(tipo: String, p: Vector2, centro: Vector2, raio: float, fixo := false, olhar := Vector2.ZERO, linha := [], dy := 0.0) -> void:
	if not Cidadao.existe(): return
	var c := Cidadao.new(); c.tipo = tipo; c.centro = centro; c.raio = raio; c.fixo = fixo; c.olhar = olhar; c.linha = linha; c.dy = dy
	m.raiz.add_child(c); c.position = Vector3(p.x, m.reg.altura(p.x, p.y) + dy, p.y)
	c.montar(m, 9000 + _n_cid); _n_cid += 1

func _multidao(centro: Vector2, raio: float, n: int, tipos: Array = POVO) -> void:
	for i in n:
		for t in 10:
			var a := rng.randf() * TAU; var q := centro + Vector2(cos(a), sin(a)) * rng.randf_range(2.0, raio)
			if not m.perto_de_casa(q.x, q.y, 1.2):
				_cidadao(tipos[rng.randi() % tipos.size()], q, centro, raio); break

func _cidadaos() -> void:
	var zc := Regiao.PORTAO.y; var x0 := Regiao.PORTAO.x
	_multidao(Regiao.VILA, 60.0, 14, ["SM_Chr_Peasant_Male_01", "SM_Chr_Peasant_Female_01", "SM_Chr_Hermit_01", "SM_Chr_Blacksmith_Male_01", "SM_Chr_Monk_01"])
	# guardas do lado de fora do Portão Oeste
	for lado in [-1.0, 1.0]:
		var q2 := Vector2(x0 - 10.0, zc + lado * 6.0)
		_cidadao("SM_Chr_Soldier_Male_01" if lado < 0 else "SM_Chr_Soldier_Female_01", q2, q2, 1.0, true, q2 + Vector2(-5, 0))
	# o rei e a rainha na sala do trono do castelo
	var tr := Regiao.CASTELO; var yt := Regiao.ALTAMAR_DESL.y + 30.6
	_gente("SM_Chr_King_01", Vector3(tr.x + 1.0, yt, tr.y + 1.2), Vector3(tr.x + 10.0, yt, tr.y + 1.2))
	_gente("SM_Chr_Queen_01", Vector3(tr.x + 1.0, yt, tr.y - 1.2), Vector3(tr.x + 10.0, yt, tr.y - 1.2))
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
	# postes de amarrar cavalo e placa na estrada, antes do Portão Oeste
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

func _interiores() -> void:
	m.portas = []
	var base := Vector3(1000.0, -300.0, -1000.0)
	var o := base
	var d := Vector3.ZERO
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
	# ---- ferraria da vila: forja, bigornas, fole, rebolo, armas nas paredes, bancada, ferreiros
	for k in 1:
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
		var fe: Vector2 = m.ferraria_pos + Vector2(1.2, 9.5)
		_porta("Ferraria do Bram", fe + Vector2(5.0, -6.5), PI, d)
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

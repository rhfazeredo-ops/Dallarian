# A região inicial do jogo (2,4 × 2,4 km — tamanho de uma zona grande de MMO), desenhada em código: relevo, limites, rio, lago, estradas, campos e
# lugares. Tudo que precisa saber "o que tem neste ponto do mapa" pergunta aqui (altura, cor, água, mato).
#
#            N  (montanhas, com um desfiladeiro fechado por uma barricada no meio)
#     ┌───────────────────────────────────────────┐
#     │  caverna   lago+mosteiro       ruínas     │
#     │ montanhas      ╲  rio            serraria  │  mar
#  O  │  fazendas ───── VILA ─────── ponte ── porto│  L
#     │  moinho        │    ╲ rio                  │
#     │  bandidos      │     ╲                     │
#     │            pântano (sul)                   │
#     └───────────────────────────────────────────┘
#            S  (morros escuros fecham o pântano)
# x = leste, z = sul (o norte é -z). A vila fica no centro (0, 0).
extends RefCounted
class_name Regiao

const LIM := 1200.0          # metade da altura (norte–sul); o mapa é retangular, mais largo para o leste
const X0 := -1200.0          # oeste
const X1 := 2600.0           # leste (o mar fica na ponta leste)
const Z0 := -1200.0          # norte
const Z1 := 1200.0           # sul
const GRADE := 4.0           # resolução das grades de distância (m)
const NX := 950              # células nas grades (oeste → leste)
const NZ := 600              # células nas grades (norte → sul)
const COSTA := 2220.0        # linha da praia (o mar vai daqui até o fim do mapa)
# cidade grande murada com porto, no canto nordeste, entre as montanhas e o mar: [x0, z0, x1, z1] das muralhas
# cidade grande redonda (centro e raio da muralha); um canal em anel corta a cidade no raio CANAL
# MAPA NOVO (docs/MAPA_NOVO.md): Altamar é um retângulo na costa leste, em degraus — nível do portão (oeste, 9 m),
# do mercado (meio, 6 m) e do porto (leste, 3 m), com o castelo num morro no noroeste (24 m)
# ALTAMAR (refeita: bairros ligados por pontes sobre canais, muralha irregular com torres, fortaleza no morro a
# noroeste, catedral numa ilha no meio, porto no mar a leste). Tudo plano no nível 7 m, o porto 4 m mais baixo.
const CIDADE := Rect2(1967.4, -71.3, 272.6, 278.4)      # caixa em volta da muralha
const CIDADE_C := Vector2(2095.0, 56.3)                  # centro (a ilha da catedral)
const CIDADE_R := 136.3
const CANAL := -1000.0
const ALTURA_CIDADE := 7.0
const NIVEL_MERCADO := 7.0
const NIVEL_PORTO := 3.0
const X_MERCADO := -100000.0                              # (sem degrau no meio da cidade)
const X_PORTO := 2196.5                                   # degrau para o porto (leste)
const CASTELO := Vector2(2013.8, -27.8)                   # topo do morro da fortaleza
const ALTURA_CASTELO := 16.0
const PRACA := Vector2(2095.0, 150.0)                     # praça do mercado (retângulo, ao sul da catedral)
const PRACA_TAM := Vector2(44.0, 40.0)
const ILHA_CATEDRAL := Vector2(2095.0, 70.8)               # no eixo da avenida do portão
const RAIO_ILHA := 29.0                                   # o canal em volta vai de 52 a 62 m
const PORTAO := Vector2(1973.2, 70.8)                     # Portão Oeste
# muralha (contorno no sentido horário); a beira do mar (leste) fica aberta para o porto
const MURALHA := [Vector2(1973.2, 70.8), Vector2(1979.0, 4.1), Vector2(1984.8, -53.9), Vector2(2042.8, -68.4),
	Vector2(2106.6, -65.5), Vector2(2170.4, -59.7), Vector2(2211.0, -36.5), Vector2(2219.7, -7.5)]
const MURALHA_SUL := [Vector2(2216.8, 172.3), Vector2(2164.6, 198.4), Vector2(2100.8, 204.2), Vector2(2037.0, 195.5),
	Vector2(1990.6, 157.8), Vector2(1973.2, 70.8)]
# ruas (retas, em grade): eixo de cada uma, meia largura da pista (cavalos e carroças no meio) e a calçada dos
# dois lados (pedestres). Avenida Real (portão → ilha), Rua do Porto, Rua Norte, Rua do Mercado (atravessa a praça),
# Rua do Castelo, Rua dos Magos, Rua dos Ofícios, Rua das Lojas (sul da praça), Rua Velha (norte) e Rua Leste.
const RUAS := [
	[Vector2(1960.0, 70.8), Vector2(2054.0, 70.8)],
	[Vector2(2136.0, 70.8), Vector2(2199.0, 70.8)],
	[Vector2(2095.0, 30.0), Vector2(2095.0, -58.0)],
	[Vector2(2095.0, 112.0), Vector2(2095.0, 198.0)],
	[Vector2(2013.8, 70.8), Vector2(2013.8, -4.0)],
	[Vector2(2030.0, 70.8), Vector2(2030.0, 176.0)],
	[Vector2(1993.0, 122.0), Vector2(2192.0, 122.0)],
	[Vector2(2030.0, 176.0), Vector2(2165.0, 176.0)],
	[Vector2(2044.0, -25.0), Vector2(2205.0, -25.0)],
	[Vector2(2160.0, -25.0), Vector2(2160.0, 122.0)],
]
const LARG_RUAS := [4.5, 4.5, 3.5, 4.0, 3.5, 3.5, 3.5, 3.5, 3.5, 3.5]      # meia largura da pista (m)
const CALCADA := 2.5
# canal: o anel em volta da ilha da catedral é feito à parte; este leva a água do anel até o mar
const CANAIS := [[Vector2(2124.0, 52.0), Vector2(2176.0, 42.0), Vector2(2245.8, 38.0)]]
static func na_praca(q: Vector2, folga := 0.0) -> bool:
	return absf(q.x - PRACA.x) < PRACA_TAM.x * 0.5 + folga and absf(q.y - PRACA.y) < PRACA_TAM.y * 0.5 + folga
static func _dist_linha(q: Vector2, l: Array) -> float:
	var d := INF
	for i in l.size() - 1: d = minf(d, q.distance_to(Geometry2D.get_closest_point_to_segment(q, l[i], l[i + 1])))
	return d
static func poligono_cidade() -> PackedVector2Array:
	var p := PackedVector2Array(MURALHA)
	p.append(Vector2(2240.0, 4.1)); p.append(Vector2(2240.0, 166.5))      # a beira do porto
	for q in MURALHA_SUL: p.append(q)
	return p
static var _poli := PackedVector2Array()
static func dentro_cidade(q: Vector2) -> bool:
	if _poli.is_empty(): _poli = poligono_cidade()
	return Geometry2D.is_point_in_polygon(q, _poli)
static func dist_canal(x: float, z: float) -> float:
	var q := Vector2(x, z)
	var d := absf(q.distance_to(ILHA_CATEDRAL) - (RAIO_ILHA + 5.0))
	for c in CANAIS: d = minf(d, _dist_linha(q, c))
	return d
const NIVEL_CANAL := ALTURA_CIDADE - 1.6
const VILA := Vector2(250.0, 420.0)              # Vila do Vale (centro da praça)
const VILA_NORTE := Vector2(470.0, -560.0)       # Vila da Serra (pequena, na Estrada do Norte)
# O desenho original era de 1,2 km. Para aumentar o mapa sem mexer na vila, tudo até 150 m do centro fica igual
# e o que está além se afasta ("Ws"/"W": distância/ponto do desenho original → mundo de 2,4 km).
const PERTO := 150.0
const K_ESPALHA := (1200.0 - 150.0) / (600.0 - 150.0)
static func Ws(r: float) -> float: return r if r < PERTO else PERTO + (r - PERTO) * K_ESPALHA
static func W(p: Vector2) -> Vector2:
	var r := p.length()
	return p if r < PERTO else p * (Ws(r) / r)

var ruido := FastNoiseLite.new()
var ruido_grande := FastNoiseLite.new()
var ruido_relevo := FastNoiseLite.new()       # mapa novo: colinas, planaltos e vales

# estradas (linhas, coordenadas do mundo) — a primeira sai da vila para o sul
var estradas := [
	PackedVector2Array([VILA + Vector2(0, 10), Vector2(244, 520), Vector2(205, 640), Vector2(232, 760), Vector2(300, 880)]),
	PackedVector2Array([VILA + Vector2(0, -10), Vector2(268, 300), Vector2(330, 120), Vector2(362, -100), Vector2(420, -350), Vector2(500, -600), Vector2(560, -820)]),
	PackedVector2Array([VILA + Vector2(-10, 0), Vector2(120, 412), Vector2(-50, 382), Vector2(-250, 330), Vector2(-400, 300), Vector2(-560, 250), Vector2(-660, 120), Vector2(-690, -150)]),
]
# trilhas: caminhos estreitos saindo da rua da vila para sítios, hortas e o rio
var trilhas := [
	PackedVector2Array([VILA + Vector2(-20, 12), VILA + Vector2(-40, 45), VILA + Vector2(-70, 70)]),
	PackedVector2Array([VILA + Vector2(30, -12), VILA + Vector2(60, -50), VILA + Vector2(90, -80)]),
	PackedVector2Array([VILA + Vector2(60, 8), VILA + Vector2(120, 20), VILA + Vector2(175, 30)]),
]
# rio do vale: nasce nas montanhas do norte, desce pelo meio do mapa, passa a leste da vila e morre no pântano
var rio := PackedVector2Array([Vector2(650, -1180), Vector2(620, -900), Vector2(560, -650), Vector2(505, -420),
	Vector2(470, -200), Vector2(432, 30), Vector2(422, 230), Vector2(440, 380), Vector2(520, 560), Vector2(650, 700),
	Vector2(850, 820), Vector2(1100, 920)])
static var LAGO := Vector3(-700.0, -300.0, 95.0)        # x, z, raio (no Planalto do Oeste)
static var ILHA := Vector3(-696.0, -294.0, 22.0)
const CENTRO_VILA := VILA
# campos: [centro x, centro z, largura, comprimento, ângulo (graus), tipo]  tipo 0 = trigo, 1 = terra arada
var campos := [
	[120, 520, 60, 40, 10, 0], [100, 320, 50, 34, -8, 1], [370, 560, 64, 40, 20, 0], [560, 470, 50, 34, -15, 0],
	[620, 600, 44, 30, 5, 1], [140, 610, 40, 30, 0, 0], [330, 250, 40, 28, 12, 0],
	[190, 470, 16, 11, 0, 1], [305, 365, 14, 10, 0, 1],                 # hortas da vila
]
var morros := []

var estrada_real := -1                       # índice da Estrada Real (vila → Altamar) em "estradas"
var d_estrada := PackedFloat32Array()
var d_trilha := PackedFloat32Array()
var d_rio := PackedFloat32Array()
var t_rio := PackedFloat32Array()            # posição ao longo do rio (0 nascente → 1 foz)
var _rio_comp := PackedFloat32Array()
var pontes := []                             # [posição Vector2, direção da estrada Vector2]
var planos := []                             # chão aplanado embaixo das construções: [centro, meia medida, ângulo, altura, margem, raio²]

func _init() -> void:
	ruido.seed = 11; ruido.frequency = 0.018; ruido.fractal_octaves = 3
	ruido_grande.seed = 4; ruido_grande.frequency = 0.004; ruido_grande.fractal_octaves = 2
	ruido_relevo.seed = 27; ruido_relevo.frequency = 0.0022; ruido_relevo.fractal_octaves = 4; ruido_relevo.fractal_gain = 0.45
	# ESTRADA REAL: da saída leste da vila, pela ponte do rio e pelos vales, até o Portão Oeste de Altamar; continua
	# como a avenida da cidade até a praça do mercado
	var porta := PORTAO
	estradas.append(PackedVector2Array([VILA + Vector2(10, 0), Vector2(400, 402), Vector2(560, 332), Vector2(760, 270),
		Vector2(980, 205), Vector2(1200, 160), Vector2(1400, 110), Vector2(1530, 80), porta + Vector2(-40, 0), porta, Vector2(1932.0, 75.0)]))
	estrada_real = estradas.size() - 1
	d_estrada.resize(NX * NZ); d_estrada.fill(1e6)
	d_rio.resize(NX * NZ); d_rio.fill(1e6); t_rio.resize(NX * NZ); t_rio.fill(0.0)
	for e in estradas: _rasterizar(e, d_estrada, null, 24.0)
	d_trilha.resize(NX * NZ); d_trilha.fill(1e6)
	for t in trilhas: _rasterizar(t, d_trilha, null, 12.0)
	var tot := 0.0; _rio_comp.append(0.0)
	for i in rio.size() - 1: tot += rio[i].distance_to(rio[i + 1]); _rio_comp.append(tot)
	for i in rio.size(): _rio_comp[i] /= tot
	_rasterizar(rio, d_rio, t_rio, 48.0)
	_preparar_rio2()
	_achar_pontes()

func _rasterizar(linha: PackedVector2Array, dist: PackedFloat32Array, tt, alcance: float, comp: PackedFloat32Array = PackedFloat32Array()) -> void:
	if comp.is_empty(): comp = _rio_comp
	for s in linha.size() - 1:
		var a := linha[s]; var b := linha[s + 1]
		var i0 := int((min(a.x, b.x) - alcance - X0) / GRADE); var i1 := int((max(a.x, b.x) + alcance - X0) / GRADE)
		var j0 := int((min(a.y, b.y) - alcance - Z0) / GRADE); var j1 := int((max(a.y, b.y) + alcance - Z0) / GRADE)
		for j in range(max(j0, 0), min(j1, NZ - 1) + 1):
			for i in range(max(i0, 0), min(i1, NX - 1) + 1):
				var p := Vector2(X0 + i * GRADE, Z0 + j * GRADE)
				var q := Geometry2D.get_closest_point_to_segment(p, a, b)
				var d := q.distance_to(p); var k := j * NX + i
				if d < dist[k]:
					dist[k] = d
					if tt != null:
						var u: float = 0.0 if a.distance_to(b) < 0.01 else a.distance_to(q) / a.distance_to(b)
						tt[k] = lerp(comp[s], comp[s + 1], u)

func _amostra(g: PackedFloat32Array, x: float, z: float) -> float:
	var fx := clampf((x - X0) / GRADE, 0.0, NX - 1.001); var fz := clampf((z - Z0) / GRADE, 0.0, NZ - 1.001)
	var i := int(fx); var j := int(fz); var u := fx - i; var v := fz - j
	var a := g[j * NX + i]; var b := g[j * NX + i + 1]; var c := g[(j + 1) * NX + i]; var d := g[(j + 1) * NX + i + 1]
	return lerp(lerp(a, b, u), lerp(c, d, u), v)

func dist_estrada(x: float, z: float) -> float: return _amostra(d_estrada, x, z)
func dist_rio(x: float, z: float) -> float: return _amostra(d_rio, x, z)
func dist_rio2(x: float, z: float) -> float: return _amostra(d_rio2, x, z)
func dist_rios(x: float, z: float) -> float: return minf(dist_rio(x, z), dist_rio2(x, z))

# ---------- rio do leste: nasce nas montanhas do norte, passa na frente do portão oeste da cidade e deságua no mar ----------
# (longe de Altamar: desce das montanhas e vai para o mar bem ao norte da cidade — a frente do reino fica livre)
var rio2 := PackedVector2Array([Vector2(1480, -1190), Vector2(1540, -1020), Vector2(1640, -880), Vector2(1790, -760),
	Vector2(1960, -680), Vector2(2120, -640), Vector2(2330, -620)])
var d_rio2 := PackedFloat32Array()
var t_rio2 := PackedFloat32Array()
var _rio2_comp := PackedFloat32Array()
var _rio2_nivel := PackedFloat32Array()
func _preparar_rio2() -> void:
	d_rio2.resize(NX * NZ); d_rio2.fill(1e6); t_rio2.resize(NX * NZ); t_rio2.fill(0.0)
	var tot := 0.0; _rio2_comp.append(0.0)
	for i in rio2.size() - 1: tot += rio2[i].distance_to(rio2[i + 1]); _rio2_comp.append(tot)
	for i in rio2.size(): _rio2_comp[i] /= tot
	# nível da água: segue o vale, desce até a altura do portão da cidade e depois até o mar (sempre descendo)
	var ant := 1e6
	for i in rio2.size():
		var p: Vector2 = rio2[i]
		var nv := base(p.y) - 1.3
		if p.distance_to(CIDADE_C) < CIDADE_R + 260.0: nv = minf(nv, ALTURA_CIDADE - 0.55)   # perto da margem (antes -1,3: parecia um fosso)
		nv = lerpf(nv, 0.1, smoothstep(COSTA - 260.0, COSTA, p.x))
		ant = minf(ant, nv); _rio2_nivel.append(ant)
	_rasterizar(rio2, d_rio2, t_rio2, 64.0, _rio2_comp)
func largura_rio2(t: float) -> float: return lerp(12.0, 30.0, t)
func nivel_rio2(t: float) -> float:
	var i := 0
	while i < _rio2_comp.size() - 2 and _rio2_comp[i + 1] < t: i += 1
	var u: float = clampf((t - _rio2_comp[i]) / maxf(_rio2_comp[i + 1] - _rio2_comp[i], 0.0001), 0.0, 1.0)
	return lerpf(_rio2_nivel[i], _rio2_nivel[i + 1], u)
func dist_trilha(x: float, z: float) -> float: return _amostra(d_trilha, x, z)
# folga até a beira do caminho mais perto (estrada larga: 2,6 m do meio; trilha: 1,3 m)
func folga_caminho(x: float, z: float) -> float: return minf(dist_estrada(x, z) - 2.6, dist_trilha(x, z) - 1.3)

func _achar_pontes() -> void:
	for e in estradas:
		for s in e.size() - 1:
			for r in rio.size() - 1:
				var p = Geometry2D.segment_intersects_segment(e[s], e[s + 1], rio[r], rio[r + 1])
				if p != null: pontes.append([p, (e[s + 1] - e[s]).normalized()])

# ---------- relevo ----------
# altura de base: desce devagar do norte (12 m) para o sul (2 m)
func base(z: float) -> float: return lerp(12.0, 2.0, clampf((z + Ws(470.0)) / (Ws(470.0) + Ws(400.0)), 0.0, 1.0))
func largura_rio(t: float) -> float: return lerp(7.0, 18.0, t)
func nivel_rio(t: float) -> float:
	# o nível da água acompanha a base no ponto do rio (aproximado pela posição ao longo dele)
	var i := 0
	while i < _rio_comp.size() - 2 and _rio_comp[i + 1] < t: i += 1
	var u: float = (t - _rio_comp[i]) / maxf(_rio_comp[i + 1] - _rio_comp[i], 0.0001)
	var z: float = lerp(rio[i].y, rio[i + 1].y, u)
	return base(z) - 1.3

func nivel_lago() -> float: return base(LAGO.y) - 1.3

func altura(x: float, z: float, cavar := true) -> float:     # cavar=false: a montanha sem a gruta
	var b := base(z)
	var dr := dist_rio(x, z); var tr := _amostra(t_rio, x, z)
	var dl := Vector2(x - LAGO.x, z - LAGO.y).length()
	var calma := smoothstep(8.0, 45.0, min(dr, dl - LAGO.z))        # perto da água o chão fica liso
	var h := b + ruido.get_noise_2d(x, z) * 3.2 * calma + ruido_grande.get_noise_2d(x, z) * 5.0 * calma
	for m in morros:
		var dm := Vector2(x - m.x, z - m.y).length()
		h += m.w * exp(-dm * dm / (m.z * m.z * 0.5))
	# RELEVO (mapa novo): colinas, planalto a oeste e o norte subindo para as montanhas. Some perto das estradas,
	# do rio, do lago, da vila e da cidade (os caminhos correm pelos vales e sobem aos poucos)
	h += relevo(x, z) * _calma_relevo(x, z, dr, dl)
	# vila plana
	var dv := Vector2(x, z).distance_to(VILA)
	h = lerp(base(VILA.y) + 0.3, h, smoothstep(30.0, 70.0, dv))
	var dvn := Vector2(x, z).distance_to(VILA_NORTE)
	if dvn < 90.0: h = lerp(base(VILA_NORTE.y) + 6.0, h, smoothstep(30.0, 85.0, dvn))
	# campos planos
	for c in campos:
		var dc := Vector2(x - c[0], z - c[1]).length()
		if dc < 60: h = lerp(b + 0.2, h, smoothstep(c[2] * 0.4, c[2] * 0.9, dc))
	# estradas um pouco afundadas
	h -= (1.0 - smoothstep(1.5, 4.0, dist_estrada(x, z))) * 0.3
	h -= (1.0 - smoothstep(0.6, 2.0, dist_trilha(x, z))) * 0.15
	# rio: leito escavado
	var lr := largura_rio(tr) * 0.5
	var nv := nivel_rio(tr)
	if dr < lr + 10.0:
		var leito := nv - 1.1 * (1.0 - smoothstep(lr * 0.4, lr, dr))
		h = lerp(min(h, leito), h, smoothstep(lr, lr + 10.0, dr))
	# lago (com ilha)
	if dl < LAGO.z + 16.0:
		var fundo := nivel_lago() - 2.6 * (1.0 - smoothstep(LAGO.z * 0.5, LAGO.z, dl))
		h = lerp(min(h, fundo), h, smoothstep(LAGO.z, LAGO.z + 16.0, dl))
		var di := Vector2(x - ILHA.x, z - ILHA.y).length()
		h = max(h, nivel_lago() + 1.6 - smoothstep(ILHA.z * 0.7, ILHA.z * 1.3, di) * 5.0)
	# mar a leste (com praia)
	# cidade: chão plano (um pouco acima da base), suave até 40 m fora das muralhas
	var dcid := _dist_cidade(x, z)
	if dcid < 60.0:
		var qc := Vector2(clampf(x, CIDADE.position.x, CIDADE.end.x), clampf(z, CIDADE.position.y, CIDADE.end.y))
		h = lerp(altura_cidade(qc.x, qc.y), h, smoothstep(0.0, 60.0, dcid))
	if CIDADE.grow(20.0).has_point(Vector2(x, z)):
		var dk := dist_canal(x, z)
		if dk < 5.0: h = minf(h, lerpf(NIVEL_CANAL - 1.4, h, smoothstep(3.4, 4.2, dk)))   # leito do canal (margem reta: cais de pedra)
	var costa := COSTA + ruido_grande.get_noise_2d(0.0, z * 2.0) * 40.0
	# na altura da cidade o mar chega até perto da muralha leste (porto)
	var dz_cid := maxf(absf(z - CIDADE_C.y) - CIDADE_R * 0.7, 0.0)
	costa = lerpf(costa, CIDADE_C.x + CIDADE_R + 45.0, 1.0 - smoothstep(60.0, 160.0, dz_cid))
	if x > costa - 30.0: h = lerp(h, 1.2 - (x - costa) * 0.16, smoothstep(costa - 30.0, costa, x))
	# rio do leste (das montanhas do norte, na frente da cidade, até o mar): margens um pouco altas e leito fundo
	var d2 := dist_rio2(x, z)
	if d2 < 60.0:
		var t2 := _amostra(t_rio2, x, z)
		var l2 := largura_rio2(t2) * 0.5; var n2 := nivel_rio2(t2)
		if d2 < l2 + 14.0 and x < COSTA - 80.0: h = maxf(h, lerpf(n2 + 0.6, h, smoothstep(l2 + 4.0, l2 + 14.0, d2)))
		# perto de Altamar: margens baixas, descendo suave até a água (antes era um barranco de 2–3 m, cara de fosso)
		if d2 < l2 + 20.0 and Vector2(x, z).distance_to(CIDADE_C) < CIDADE_R + 330.0:
			var beira := n2 + 0.45
			if h > beira: h = lerpf(beira, h, smoothstep(l2 + 1.0, l2 + 20.0, d2))
		if d2 < l2 + 8.0:
			var leito := n2 - 2.2 * (1.0 - smoothstep(l2 * 0.35, l2, d2))
			h = lerp(minf(h, leito), h, smoothstep(l2, l2 + 8.0, d2))
	# acesso ao portão oeste: estrada aterrada no nível da ponte e da cidade (antes a margem ficava ~4 m acima da
	# ponte); embaixo do vão da ponte o rio continua fundo
	var wa := acesso_ponte(x, z)
	if wa > 0.0 and absf(x - FOSSO_X) > 19.5:
		var alvo := lerpf(ALTURA_CIDADE + 0.35, ALTURA_CIDADE, smoothstep(FOSSO_X + 20.0, CIDADE_C.x - CIDADE_R, x))
		h = lerpf(h, alvo, wa)
	# estábulo e chegada da ponte: tudo no nível da estrada (antes o estábulo ficava num platô ~4 m acima e a
	# estrada passava num corte com barrancos dos lados)
	var dpt := _dist_ret(x, z, PATIO_NIVEL)
	if dpt < 24.0:
		var longe_rio := smoothstep(9.0, 15.0, dist_rio2(x, z))            # não mexe no leito nem na margem do rio
		h = lerpf(h, lerpf(ALTURA_CIDADE + 0.35, h, smoothstep(0.0, 24.0, dpt)), longe_rio)
	# pântano ao sul
	var pant := smoothstep(Ws(370.0), Ws(430.0), z + ruido_grande.get_noise_2d(x * 2.0, 0.0) * 30.0)
	if pant > 0.0: h = lerp(h, 0.25 + ruido.get_noise_2d(x * 1.7, z * 1.7) * 0.9, pant)
	# limites: montanhas ao norte e a oeste, morros escuros ao sul
	var n_borda := ruido_grande.get_noise_2d(x * 3.0, z * 3.0) * 40.0
	var dn := (-Ws(470.0) + n_borda) - z
	var passagem := smoothstep(12.0, 45.0, abs(x))                      # desfiladeiro no meio do norte
	var var_m: float = 0.75 + ruido.get_noise_2d(x * 0.6, z * 0.6) * 0.6 + abs(ruido_grande.get_noise_2d(x * 4.0, z * 4.0)) * 0.6
	if dn > 0.0: h += _serra(dn, 85.0) * var_m * (0.2 + 0.8 * passagem)
	var dw := (-Ws(480.0) + n_borda) - x
	if dw > 0.0: h += _serra(dw, 85.0) * var_m
	var ds := z - (Ws(520.0) + n_borda)
	if ds > 0.0: h += _serra(ds, 35.0) * var_m
	if not planos.is_empty(): h = _planos(x, z, h)
	h += monte_gruta(x, z)                                     # montanha grande por cima da Gruta dos Lodosos
	if SEM_GRUTA == false and cavar and GRUTA_BB.grow(14.0).has_point(Vector2(x, z)):           # Gruta dos Lodosos: cânion com o chão da gruta
		var dg := gruta_d(x, z)
		# o chão continua reto até 3 m atrás da parede (a malha do terreno é mais grossa que a parede: se subisse
		# logo na borda, a encosta atravessava para dentro da gruta)
		if dg < 9.0: h = lerpf(gruta_piso(x, z), h, smoothstep(3.0, 9.0, dg))
	return h

func relevo(x: float, z: float) -> float:
	var n := ruido_relevo.get_noise_2d(x, z) * 0.5 + 0.5                   # 0..1
	var colinas := pow(n, 1.5) * 46.0 - 7.0                                 # morros de até ~40 m e baixadas
	# cristas de serra (ruído "dobrado": linhas altas e finas) em parte do mapa
	var cr := 1.0 - absf(ruido_relevo.get_noise_2d(x * 1.7 + 900.0, z * 1.7 - 300.0))
	var cristas := pow(cr, 5.0) * 26.0 * smoothstep(0.1, 0.5, ruido_grande.get_noise_2d(x * 0.8 + 50.0, z * 0.8))
	var borda := ruido_grande.get_noise_2d(x * 2.5, z * 2.5) * 70.0
	var planalto := 26.0 * smoothstep(-330.0, -430.0, x + borda)            # planalto do Bosque Sombrio (oeste)
	var norte := 16.0 * smoothstep(-250.0, -800.0, z + borda)               # sobe para as montanhas do norte
	var sul := -3.0 * smoothstep(500.0, 850.0, z)                           # desce para o pântano
	var h := colinas + cristas + planalto + norte + sul
	# mesas: em algumas regiões o relevo vira degraus de 9 m (platôs com paredões entre eles)
	var mesa := smoothstep(0.15, 0.45, ruido_grande.get_noise_2d(x * 1.3 - 400.0, z * 1.3 + 200.0))
	if mesa > 0.0 and h > 4.0:
		var deg := 9.0; var f := fposmod(h, deg) / deg
		var deg_h := floorf(h / deg) * deg + smoothstep(0.72, 0.95, f) * deg
		h = lerpf(h, deg_h, mesa)
	return h

func _calma_relevo(x: float, z: float, dr: float, dl: float) -> float:
	var c := smoothstep(6.0, 110.0, dist_estrada(x, z))
	c *= smoothstep(14.0, 120.0, dr) * smoothstep(LAGO.z, LAGO.z + 110.0, dl)
	c *= smoothstep(70.0, 180.0, Vector2(x, z).distance_to(VILA))            # vila
	c *= smoothstep(50.0, 140.0, Vector2(x, z).distance_to(VILA_NORTE))
	c *= smoothstep(30.0, 160.0, _dist_cidade(x, z))
	c *= smoothstep(10.0, 60.0, dist_rio2(x, z))
	for cp in campos:
		var dc := Vector2(x - cp[0], z - cp[1]).length()
		if dc < 140.0: c *= smoothstep(cp[2] * 0.6, cp[2] * 0.6 + 70.0, dc)
	return c

# altura de uma serra a "d" metros da borda: sobe rápido no pé e para em "alto"
# distância até a cidade (0 dentro das muralhas)
func _dist_cidade(x: float, z: float) -> float:
	if dentro_cidade(Vector2(x, z)): return 0.0
	return _dist_ret(x, z, CIDADE)

# chão de Altamar: plano (7 m), o porto mais baixo (3 m) e o morro da fortaleza; canais cavados
static func altura_cidade(x: float, z: float) -> float:
	var h := lerpf(ALTURA_CIDADE, NIVEL_PORTO, smoothstep(X_PORTO - 8.0, X_PORTO + 8.0, x))
	var dc := Vector2(x, z).distance_to(CASTELO)
	if dc < 62.0: h = maxf(h, lerpf(ALTURA_CASTELO, ALTURA_CIDADE, smoothstep(30.0, 60.0, dc)))
	return h

func na_cidade(x: float, z: float, folga := 0.0) -> bool: return _dist_cidade(x, z) <= folga

# bairros de Altamar pelo ângulo e pela distância ao centro (leste = 0, sul = PI/2, oeste = PI, norte = -PI/2)
const FOSSO_X := PORTAO.x - 55.0
const ESTABULO := Vector2(FOSSO_X - 58.0, CIDADE_C.y - 42.0)
const PATIO_NIVEL := Rect2(FOSSO_X - 112.0, CIDADE_C.y - 78.0, 96.0, 106.0)     # aplainado no nível da estrada
# terra batida do estábulo: um quadrado certinho pegando o telheiro e o cercado (sem grama nenhuma)...
const ESTABULO_TERRA := Rect2(ESTABULO.x - 13.5, ESTABULO.y - 12.5, 27.0, 29.0)
static func patio_estabulo(x: float, z: float) -> float:          # 1 dentro do telheiro/cercado
	return 1.0 if dentro_estabulo(x, z) else 0.0
# dentro do telheiro e do cercado não nasce nada; no resto do quadrado, um pouco de grama (como em volta)
static func dentro_estabulo(x: float, z: float) -> bool:
	var q := Vector2(x, z) - ESTABULO
	return (absf(q.x) < 10.6 and q.y > -11.6 and q.y < -0.2) or (absf(q.x) < 12.2 and q.y > 0.8 and q.y < 15.2)
# ...e uma mancha irregular embaixo da casa do cavalariço e do Edric (com um pouco de grama)
func patio_casa(x: float, z: float) -> float:
	var d := Vector2(x, z).distance_to(ESTABULO + Vector2(-22.0, -1.0)) / 11.0 + ruido.get_noise_2d(x * 9.0, z * 9.0) * 0.3
	return 1.0 - smoothstep(0.7, 1.0, d)
static func _dist_ret(x: float, z: float, r: Rect2) -> float:
	var dx := maxf(maxf(r.position.x - x, x - r.end.x), 0.0); var dz := maxf(maxf(r.position.y - z, z - r.end.y), 0.0)
	return Vector2(dx, dz).length()
static var LAGO_PARQUE := Vector2(-99999.0, -99999.0)     # (a cidade nova não tem lago no parque)
static func distrito(x: float, z: float) -> String:
	var q := Vector2(x, z)
	if not dentro_cidade(q): return ""
	if q.distance_to(CASTELO) < 50.0: return "castelo"
	if q.distance_to(ILHA_CATEDRAL) < RAIO_ILHA + 9.0: return "catedral"
	if x > X_PORTO: return "porto"
	if q.distance_to(PRACA) < 70.0 or (z > 120.0 and x > 1930.0): return "comercio"
	if z > 120.0: return "magos"
	if x > 2040.0: return "velho"
	return "portao"
func parque(x: float, z: float) -> bool: return distrito(x, z) == "parque"
# distância até o eixo da rua principal mais perto (as quatro que saem da praça)
# peso (0..1) da estrada calçada que vem da Estrada Real, passa pela Ponte dos Guardiões e entra no portão oeste
static func acesso_ponte(x: float, z: float) -> float:
	var dz := absf(z - CIDADE_C.y)
	if dz > 20.0 or x < FOSSO_X - 120.0 or x > CIDADE_C.x - CIDADE_R + 6.0: return 0.0
	return (1.0 - smoothstep(10.0, 20.0, dz)) * smoothstep(FOSSO_X - 120.0, FOSSO_X - 70.0, x)
# ruas de Altamar: a avenida do portão (leste–oeste, z = 75), a rua do mercado (norte–sul, x = 1950) e as ruas
# secundárias que fecham os quarteirões
static func rua_cidade(x: float, z: float) -> float:
	var q := Vector2(x, z); var d := INF
	for r in RUAS: d = minf(d, _dist_linha(q, r))
	return d

func _serra(d: float, alto: float) -> float: return alto * (1.0 - exp(-d / 32.0))

# aplana o chão embaixo de uma construção (retângulo girado) e devolve a altura do piso.
# A altura é a média do chão nos cantos e no centro (corta um pouco e aterra um pouco), e a borda
# volta suave para o terreno em "margem" metros. Tem que ser chamado ANTES de montar o terreno.
func aplanar(c: Vector2, meia: Vector2, ang: float, margem := 4.0) -> float:
	var soma := altura(c.x, c.y); var n := 1
	for k in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var q: Vector2 = c + (k * meia).rotated(ang); soma += altura(q.x, q.y); n += 1
	var h := soma / n
	meia += Vector2(1.0, 1.0)                  # a parte plana passa 1 m da construção (sem degrau na quina)
	var r := meia.length() + margem
	planos.append([c, meia, ang, h, margem, r * r])
	return h

func _planos(x: float, z: float, h: float) -> float:
	for pl in planos:
		var c: Vector2 = pl[0]
		var dx := x - c.x; var dz := z - c.y
		if dx * dx + dz * dz > pl[5]: continue
		var q := Vector2(dx, dz).rotated(-pl[2]); var meia: Vector2 = pl[1]
		var d: float = max(abs(q.x) - meia.x, abs(q.y) - meia.y)
		h = lerp(pl[3], h, smoothstep(0.0, pl[4], d))
	return h

# ---------- Gruta dos Lodosos (DG aberta na montanha do norte, a oeste do rio do leste) ----------
# O chão da gruta é o próprio terreno, cavado num cânion com o formato dos túneis e salas (assim monstros, saque e
# tudo que usa a altura do terreno funcionam lá dentro); paredes e teto de pedra são montados em mundo.gd.
const SEM_GRUTA := true                 # a Gruta dos Lodosos (DG) saiu do jogo no mapa novo
const GRUTA_Y := 13.0                  # altura do chão (o vale na frente da montanha)
const GRUTA_TETO := 6.5
const GRUTA_COBERTA_Z := -913.0        # daqui para o norte tem teto: a boca fica onde a encosta já é mais alta que o teto
const GRUTA_BB := Rect2(1430.0, -1110.0, 180.0, 255.0)
# túneis [de, até, largura] e salas [centro, raio]
const GRUTA_TUNEIS := [
	[Vector2(1545, -862), Vector2(1545, -896), 10.0],     # entrada (rampa aberta)
	[Vector2(1545, -896), Vector2(1538, -945), 7.0],
	[Vector2(1532, -962), Vector2(1576, -969), 5.0],      # para a sala do lado (beco)
	[Vector2(1532, -962), Vector2(1498, -980), 6.0],
	[Vector2(1498, -980), Vector2(1484, -1008), 6.0],
	[Vector2(1482, -1018), Vector2(1516, -1040), 6.0],
	[Vector2(1516, -1040), Vector2(1540, -1060), 7.0]]
const GRUTA_SALAS := [
	[Vector2(1532, -962), 12.0],                           # sala 1 (acampamento)
	[Vector2(1581, -972), 8.0],                            # beco do xamã
	[Vector2(1482, -1018), 11.0],                          # sala 2
	[Vector2(1549, -1076), 17.0]]                          # câmara do Grão-Lodoso
const GRUTA_ENTRADA := Vector2(1545, -880)
const GRUTA_CAMARA := Vector2(1549, -1076)
# distância até a borda da gruta (negativa dentro), com a parede irregular de pedra
func gruta_d(x: float, z: float) -> float:
	if not GRUTA_BB.grow(12.0).has_point(Vector2(x, z)): return 99.0
	var p := Vector2(x, z); var d := 99.0
	for t in GRUTA_TUNEIS:
		var a: Vector2 = t[0]; var b: Vector2 = t[1]; var ab := b - a
		var u := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		d = minf(d, p.distance_to(a + ab * u) - float(t[2]) * 0.5)
	for sl in GRUTA_SALAS: d = minf(d, p.distance_to(sl[0]) - float(sl[1]))
	return d + ruido.get_noise_2d(x * 4.0, z * 4.0) * 1.1 + ruido.get_noise_2d(x * 13.0 + 50.0, z * 13.0) * 0.35
# morro alto por cima da gruta: sobe atrás da boca (nada muda no vale na frente da entrada)
const MONTE_C := Vector2(1525.0, -1005.0)
func monte_gruta(x: float, z: float) -> float:
	if SEM_GRUTA: return 0.0
	var d := Vector2(x, z).distance_to(MONTE_C)
	if d > 170.0: return 0.0
	var forma := 1.0 - smoothstep(0.0, 170.0, d + ruido.get_noise_2d(x * 2.0, z * 2.0) * 35.0)
	return 42.0 * forma * forma * (3.0 - 2.0 * forma) * smoothstep(-905.0, -945.0, z)
# caminho de terra clara do vale até dentro da gruta: 1 no meio, some para os lados (grama) e para o fundo
func caminho_gruta(x: float, z: float) -> float:
	if absf(x - GRUTA_ENTRADA.x) > 8.0 or z > GRUTA_COBERTA_Z - 1.0 or z < -935.0: return 0.0   # só dentro: lá fora é grama
	var meia := 1.9 + ruido.get_noise_2d(z * 3.0, 7.0) * 0.6 + smoothstep(-905.0, -920.0, z) * 2.0   # alarga ao entrar
	var cxz := GRUTA_ENTRADA.x + ruido.get_noise_2d(z * 1.5, 3.0) * 1.2 * smoothstep(-905.0, -880.0, z)  # curvinha lá fora
	return (1.0 - smoothstep(meia - 0.6, meia + 0.4, absf(x - cxz))) * smoothstep(-934.0, -918.0, z) * (1.0 - smoothstep(-874.0, -866.0, z))
func na_gruta(x: float, z: float, folga := 0.0) -> bool: return not SEM_GRUTA and gruta_d(x, z) < folga
func gruta_coberta(x: float, z: float) -> bool: return not SEM_GRUTA and z < GRUTA_COBERTA_Z and gruta_d(x, z) < 0.0
func gruta_piso(x: float, z: float) -> float: return GRUTA_Y + ruido.get_noise_2d(x * 6.0, z * 6.0) * 0.35
func gruta_teto(x: float, z: float) -> float: return GRUTA_Y + GRUTA_TETO + ruido.get_noise_2d(x * 5.0 + 9.0, z * 5.0) * 1.3 \
	+ (4.0 * (1.0 - smoothstep(6.0, 17.0, Vector2(x, z).distance_to(GRUTA_CAMARA)))) \
	+ 3.5 * (1.0 - smoothstep(0.0, 14.0, GRUTA_COBERTA_Z - z))    # câmara final mais alta; boca alta, em arco

# ---------- água ----------
# nível da água neste ponto (ou -1000 se não tem água): rio, lago, ou mar/pântano (nível 0)
func agua(x: float, z: float) -> float:
	var dr := dist_rio(x, z)
	if dr < largura_rio(_amostra(t_rio, x, z)) * 0.5 + 0.5: return nivel_rio(_amostra(t_rio, x, z))
	if Vector2(x - LAGO.x, z - LAGO.y).length() < LAGO.z + 2.0: return nivel_lago()
	if CIDADE.has_point(Vector2(x, z)) and dist_canal(x, z) < 4.0: return NIVEL_CANAL
	var d2 := dist_rio2(x, z)
	if d2 < 40.0:
		var t2 := _amostra(t_rio2, x, z)
		if d2 < largura_rio2(t2) * 0.5 + 0.5: return nivel_rio2(t2)
	return 0.0

# ---------- o que tem aqui ----------
func campo_em(x: float, z: float) -> int:
	for c in campos:
		var p := Vector2(x - c[0], z - c[1]).rotated(deg_to_rad(-c[4]))
		if abs(p.x) < c[2] * 0.5 and abs(p.y) < c[3] * 0.5: return c[5]
	return -1

func zona_pantano(z: float) -> float: return smoothstep(Ws(380.0), Ws(430.0), z)

func floresta(x: float, z: float) -> float:
	# 0 = aberto, 1 = mata fechada
	if GRUTA_BB.grow(14.0).has_point(Vector2(x, z)) and gruta_d(x, z) < 10.0: return -1.0
	var f := ruido_grande.get_noise_2d(x * 1.6 + 300.0, z * 1.6) * 1.6 + 0.35
	f += 0.25 * smoothstep(400.0, 800.0, Vector2(x, z).distance_to(VILA)) + 0.22   # mais mata (menos campo vazio)
	f -= 1.0 - smoothstep(60.0, 160.0, Vector2(x, z).distance_to(VILA))     # vila e arredores abertos
	f -= 1.0 - smoothstep(40.0, 110.0, Vector2(x, z).distance_to(VILA_NORTE))
	f -= 1.0 - smoothstep(30.0, 140.0, _dist_cidade(x, z))           # campos abertos em volta da cidade
	return clampf(f, 0.0, 1.0)

func cor(x: float, z: float, h: float, ny: float, gruta := true) -> Color:
	var n := ruido.get_noise_2d(x * 0.7 + 100.0, z * 0.7)
	var grama := Color(0.42, 0.58, 0.26)
	var c := grama.lerp(Color(0.56, 0.62, 0.3), smoothstep(-0.2, 0.4, n))     # verde mais claro e amarelado
	var f := floresta(x, z)
	c = c.lerp(Color(0.3, 0.42, 0.2), f * 0.6)                                 # chão de mata mais escuro
	c = c.lerp(Color(0.46, 0.33, 0.18), smoothstep(0.45, 0.8, f) * 0.75)     # mata fechada: chão de folhas caídas
	var tipo := 1.0                     # (vai no alfa) 1 grama, 0,5 terra, 0,25 areia, 0 pedra — texturas do pacote
	var campo := campo_em(x, z)
	if campo == 0: c = Color(0.82, 0.68, 0.3) * (0.95 + n * 0.1)
	elif campo == 1:
		var faixa := int(floor(Vector2(x, z).rotated(0.2).x / 1.6)) % 2
		c = Color(0.48, 0.34, 0.22) * (0.9 + 0.12 * faixa); tipo = 0.5
	if dist_estrada(x, z) < 2.8 or Vector2(x, z).distance_to(VILA) < 13.0 + n * 3.0: c = Color(0.52, 0.38, 0.24) * (0.95 + n * 0.1); tipo = 0.5
	elif dist_trilha(x, z) < 1.3 + n * 0.3: c = Color(0.55, 0.42, 0.27) * (0.95 + n * 0.1); tipo = 0.5     # trilha de terra
	var dr := dist_rio(x, z)
	if dr < largura_rio(_amostra(t_rio, x, z)) * 0.5 + 2.5 or abs(Vector2(x - LAGO.x, z - LAGO.y).length() - LAGO.z) < 4.0:
		c = Color(0.4, 0.33, 0.22); tipo = 0.5                                 # margem de lama
	if na_cidade(x, z) and not parque(x, z):
		c = Color(0.52, 0.5, 0.48) * (0.92 + n * 0.1); tipo = 0.0                # calçamento de pedra da cidade
	if acesso_ponte(x, z) > 0.0 and x > FOSSO_X - 95.0:                         # calçamento da ponte até o portão
		var dzp := absf(z - CIDADE_C.y)
		if dzp < 11.0: tipo = 0.0
		if dzp < 5.5: c = Color(0.66, 0.64, 0.6) * (0.94 + n * 0.08)
		elif dzp < 8.0: c = Color(0.62, 0.32, 0.24) * (0.92 + n * 0.1)
		elif dzp < 11.0: c = Color(0.52, 0.5, 0.48) * (0.92 + n * 0.1)
	if h < 2.0 and x > COSTA - 120.0: c = Color(0.86, 0.78, 0.56) * (0.95 + n * 0.08); tipo = 0.25  # praia
	var pe := maxf(patio_estabulo(x, z), patio_casa(x, z) * 0.35)        # na casa: só um gasto leve na grama
	if pe > 0.0: c = c.lerp(Color(0.5, 0.38, 0.25) * (0.9 + n * 0.14), pe); tipo = lerpf(tipo, 0.5, pe)          # terra batida do estábulo
	var p := zona_pantano(z)
	if p > 0.0: c = c.lerp(Color(0.3, 0.33, 0.2) * (0.9 + n * 0.15), p)
	if ny < 0.8: c = c.lerp(Color(0.46, 0.5, 0.6), smoothstep(0.8, 0.65, ny))  # pedra
	if h > 40.0: c = c.lerp(Color(0.88, 0.91, 0.98), smoothstep(40.0, 50.0, h))  # neve
	if gruta and GRUTA_BB.grow(12.0).has_point(Vector2(x, z)):                    # gruta: lama escura e pedra
		var dg := gruta_d(x, z)
		if dg < 9.0 and z < GRUTA_COBERTA_Z + 1.0: c = c.lerp(Color(0.33, 0.3, 0.26).lerp(Color(0.24, 0.28, 0.22), smoothstep(-0.3, 0.4, n)) * (0.9 + n * 0.12), 1.0 - smoothstep(4.0, 9.0, dg))
	if gruta:
		var cg := caminho_gruta(x, z)
		if cg > 0.0:                                                  # caminho de terra clara (bege), com salpicos
			var sp := ruido.get_noise_2d(x * 40.0, z * 40.0)
			c = c.lerp(Color(0.74, 0.62, 0.44) * (0.9 + sp * 0.12), cg)
	c.a = tipo
	return c

# dentro do chão de alguma construção (casa, ferraria, moinho...)?
func em_construcao(x: float, z: float) -> bool:
	if dentro_estabulo(x, z): return true                            # sem grama nem manchas no telheiro e no cercado
	if GRUTA_BB.grow(12.0).has_point(Vector2(x, z)) and gruta_d(x, z) < 9.0 and (z < GRUTA_COBERTA_Z + 1.0 or caminho_gruta(x, z) > 0.3): return true
	for pl in planos:
		var c: Vector2 = pl[0]
		var dx := x - c.x; var dz := z - c.y
		if dx * dx + dz * dz > pl[5]: continue
		var q := Vector2(dx, dz).rotated(-pl[2]); var meia: Vector2 = pl[1]
		if pl.size() > 6 and not pl[6]: continue                      # aplainado que não tira a grama (estábulo)
		if abs(q.x) < meia.x - 0.6 and abs(q.y) < meia.y - 0.6: return true
	return false

# a grama nasce aqui? (devolve 0..1 = densidade)
func grama(x: float, z: float, h: float, ny: float) -> float:
	if em_construcao(x, z): return 0.0
	if dist_trilha(x, z) < 1.2: return 0.0
	if x < X0 + 20 or x > X1 - 20 or abs(z) > LIM - 20 or ny < 0.8 or h > 58.0: return 0.0
	if Vector2(x, z).distance_to(VILA) < 18.0: return 0.0
	if h < agua(x, z) + 0.15: return 0.0
	if x > COSTA - 120.0 and h < 2.0: return 0.0
	if na_cidade(x, z, 2.0) and not parque(x, z): return 0.0
	if x > FOSSO_X - 95.0 and acesso_ponte(x, z) > 0.0 and absf(z - CIDADE_C.y) < 11.5: return 0.0   # calçamento do portão
	var campo := campo_em(x, z)
	if campo == 1: return 0.0
	if campo == 0: return 1.0
	var g := 1.0 - smoothstep(0.2, 0.75, floresta(x, z)) * 0.85         # na mata fechada quase não tem grama
	return g * (1.0 - 0.25 * patio_casa(x, z))                           # em volta do estábulo: grama quase normal

func dentro(x: float, z: float) -> bool: return x > X0 and x < X1 and abs(z) < LIM

# altura do arco da boca (a abertura é arredondada): 0 fora da largura da boca
func arco_boca(x: float, meia: float) -> float:
	var u := (x - GRUTA_ENTRADA.x) / maxf(meia, 0.1)
	if absf(u) >= 1.0: return 0.0
	return (GRUTA_TETO + 3.0) * sqrt(1.0 - u * u)

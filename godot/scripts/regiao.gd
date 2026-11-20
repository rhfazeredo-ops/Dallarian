# A região inicial do jogo (1,2 × 1,2 km), desenhada em código: relevo, limites, rio, lago, estradas, campos e
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

const LIM := 600.0           # metade do lado
const GRADE := 4.0           # resolução das grades de distância (m)
const N := 300               # células por lado nas grades

var ruido := FastNoiseLite.new()
var ruido_grande := FastNoiseLite.new()

# estradas (linhas) — a primeira sai da vila para o sul (onde o jogador começa)
var estradas := [
	PackedVector2Array([Vector2(0, 8), Vector2(-14, 70), Vector2(-22, 125), Vector2(4, 200), Vector2(14, 262), Vector2(40, 330), Vector2(52, 392)]),
	PackedVector2Array([Vector2(0, -8), Vector2(-8, -70), Vector2(-12, -125), Vector2(8, -200), Vector2(12, -280), Vector2(0, -380), Vector2(0, -470)]),
	PackedVector2Array([Vector2(8, 0), Vector2(80, 14), Vector2(160, 30), Vector2(240, 44), Vector2(330, 40), Vector2(408, 58)]),
	PackedVector2Array([Vector2(-8, 0), Vector2(-80, 18), Vector2(-160, 34), Vector2(-240, 30), Vector2(-300, 70), Vector2(-330, 130)]),
	PackedVector2Array([Vector2(-160, 34), Vector2(-200, -20), Vector2(-240, -70)]),
	PackedVector2Array([Vector2(12, -280), Vector2(-60, -290), Vector2(-112, -300)]),     # trilha até o lago
	PackedVector2Array([Vector2(240, 44), Vector2(260, -60), Vector2(280, -150)]),        # serraria
]
# rio em "S", das montanhas do norte até o pântano
var rio := PackedVector2Array([Vector2(-270, -520), Vector2(-250, -420), Vector2(-215, -345), Vector2(-170, -300),
	Vector2(-130, -240), Vector2(-60, -175), Vector2(40, -135), Vector2(115, -70), Vector2(140, 20), Vector2(110, 120),
	Vector2(40, 200), Vector2(30, 280), Vector2(80, 360), Vector2(150, 430), Vector2(200, 480)])
const LAGO := Vector3(-170, -300, 58)        # x, z, raio
const ILHA := Vector3(-168, -296, 16)
const CENTRO_VILA := Vector2(0, 0)
# campos das fazendas: [centro x, centro z, largura, comprimento, ângulo (graus), tipo]  tipo 0 = trigo, 1 = terra arada
var campos := [
	[-200, 75, 60, 40, 8, 0], [-205, 125, 50, 34, 8, 1], [-280, -10, 56, 42, -12, 0], [-300, 40, 40, 30, -12, 1],
	[-265, 180, 64, 40, 20, 0], [-90, 60, 44, 30, 4, 0], [70, 70, 50, 32, -6, 0], [90, -40, 36, 28, 10, 1],
]
# morros (x, z, raio, altura)
var morros := [Vector4(220, -260, 70, 16), Vector4(-60, -390, 60, 10), Vector4(330, 250, 80, 12), Vector4(-380, 330, 70, 9)]

var d_estrada := PackedFloat32Array()
var d_rio := PackedFloat32Array()
var t_rio := PackedFloat32Array()            # posição ao longo do rio (0 nascente → 1 foz)
var _rio_comp := PackedFloat32Array()
var pontes := []                             # [posição Vector2, direção da estrada Vector2]

func _init() -> void:
	ruido.seed = 11; ruido.frequency = 0.018; ruido.fractal_octaves = 3
	ruido_grande.seed = 4; ruido_grande.frequency = 0.004; ruido_grande.fractal_octaves = 2
	d_estrada.resize(N * N); d_estrada.fill(1e6)
	d_rio.resize(N * N); d_rio.fill(1e6); t_rio.resize(N * N); t_rio.fill(0.0)
	for e in estradas: _rasterizar(e, d_estrada, null, 24.0)
	var tot := 0.0; _rio_comp.append(0.0)
	for i in rio.size() - 1: tot += rio[i].distance_to(rio[i + 1]); _rio_comp.append(tot)
	for i in rio.size(): _rio_comp[i] /= tot
	_rasterizar(rio, d_rio, t_rio, 48.0)
	_achar_pontes()

func _rasterizar(linha: PackedVector2Array, dist: PackedFloat32Array, tt, alcance: float) -> void:
	for s in linha.size() - 1:
		var a := linha[s]; var b := linha[s + 1]
		var i0 := int((min(a.x, b.x) - alcance + LIM) / GRADE); var i1 := int((max(a.x, b.x) + alcance + LIM) / GRADE)
		var j0 := int((min(a.y, b.y) - alcance + LIM) / GRADE); var j1 := int((max(a.y, b.y) + alcance + LIM) / GRADE)
		for j in range(max(j0, 0), min(j1, N - 1) + 1):
			for i in range(max(i0, 0), min(i1, N - 1) + 1):
				var p := Vector2(i * GRADE - LIM, j * GRADE - LIM)
				var q := Geometry2D.get_closest_point_to_segment(p, a, b)
				var d := q.distance_to(p); var k := j * N + i
				if d < dist[k]:
					dist[k] = d
					if tt != null:
						var u: float = 0.0 if a.distance_to(b) < 0.01 else a.distance_to(q) / a.distance_to(b)
						tt[k] = lerp(_rio_comp[s], _rio_comp[s + 1], u)

func _amostra(g: PackedFloat32Array, x: float, z: float) -> float:
	var fx := clampf((x + LIM) / GRADE, 0.0, N - 1.001); var fz := clampf((z + LIM) / GRADE, 0.0, N - 1.001)
	var i := int(fx); var j := int(fz); var u := fx - i; var v := fz - j
	var a := g[j * N + i]; var b := g[j * N + i + 1]; var c := g[(j + 1) * N + i]; var d := g[(j + 1) * N + i + 1]
	return lerp(lerp(a, b, u), lerp(c, d, u), v)

func dist_estrada(x: float, z: float) -> float: return _amostra(d_estrada, x, z)
func dist_rio(x: float, z: float) -> float: return _amostra(d_rio, x, z)

func _achar_pontes() -> void:
	for e in estradas:
		for s in e.size() - 1:
			for r in rio.size() - 1:
				var p = Geometry2D.segment_intersects_segment(e[s], e[s + 1], rio[r], rio[r + 1])
				if p != null: pontes.append([p, (e[s + 1] - e[s]).normalized()])

# ---------- relevo ----------
# altura de base: desce devagar do norte (12 m) para o sul (2 m)
func base(z: float) -> float: return lerp(12.0, 2.0, clampf((z + 470.0) / 870.0, 0.0, 1.0))
func largura_rio(t: float) -> float: return lerp(7.0, 15.0, t)
func nivel_rio(t: float) -> float:
	# o nível da água acompanha a base no ponto do rio (aproximado pela posição ao longo dele)
	var i := 0
	while i < _rio_comp.size() - 2 and _rio_comp[i + 1] < t: i += 1
	var u: float = (t - _rio_comp[i]) / maxf(_rio_comp[i + 1] - _rio_comp[i], 0.0001)
	var z: float = lerp(rio[i].y, rio[i + 1].y, u)
	return base(z) - 1.3

func nivel_lago() -> float: return base(LAGO.y) - 1.3

func altura(x: float, z: float) -> float:
	var b := base(z)
	var dr := dist_rio(x, z); var tr := _amostra(t_rio, x, z)
	var dl := Vector2(x - LAGO.x, z - LAGO.y).length()
	var calma := smoothstep(8.0, 45.0, min(dr, dl - LAGO.z))        # perto da água o chão fica liso
	var h := b + ruido.get_noise_2d(x, z) * 3.2 * calma + ruido_grande.get_noise_2d(x, z) * 5.0 * calma
	for m in morros:
		var dm := Vector2(x - m.x, z - m.y).length()
		h += m.w * exp(-dm * dm / (m.z * m.z * 0.5))
	# vila plana
	var dv := Vector2(x, z).length()
	h = lerp(base(0.0) + 0.3, h, smoothstep(22.0, 48.0, dv))
	# campos planos
	for c in campos:
		var dc := Vector2(x - c[0], z - c[1]).length()
		if dc < 60: h = lerp(b + 0.2, h, smoothstep(c[2] * 0.4, c[2] * 0.9, dc))
	# estradas um pouco afundadas
	h -= (1.0 - smoothstep(1.5, 4.0, dist_estrada(x, z))) * 0.3
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
	var costa := 430.0 + ruido_grande.get_noise_2d(0.0, z * 2.0) * 40.0
	if x > costa - 30.0: h = lerp(h, 1.2 - (x - costa) * 0.16, smoothstep(costa - 30.0, costa, x))
	# pântano ao sul
	var pant := smoothstep(370.0, 430.0, z + ruido_grande.get_noise_2d(x * 2.0, 0.0) * 30.0)
	if pant > 0.0: h = lerp(h, 0.25 + ruido.get_noise_2d(x * 1.7, z * 1.7) * 0.9, pant)
	# limites: montanhas ao norte e a oeste, morros escuros ao sul
	var n_borda := ruido_grande.get_noise_2d(x * 3.0, z * 3.0) * 40.0
	var dn := (-470.0 + n_borda) - z
	var passagem := smoothstep(12.0, 45.0, abs(x))                      # desfiladeiro no meio do norte
	var var_m: float = 0.75 + ruido.get_noise_2d(x * 0.6, z * 0.6) * 0.6 + abs(ruido_grande.get_noise_2d(x * 4.0, z * 4.0)) * 0.6
	if dn > 0.0: h += _serra(dn, 85.0) * var_m * (0.2 + 0.8 * passagem)
	var dw := (-480.0 + n_borda) - x
	if dw > 0.0: h += _serra(dw, 85.0) * var_m
	var ds := z - (520.0 + n_borda)
	if ds > 0.0: h += _serra(ds, 35.0) * var_m
	return h

# altura de uma serra a "d" metros da borda: sobe rápido no pé e para em "alto"
func _serra(d: float, alto: float) -> float: return alto * (1.0 - exp(-d / 32.0))

# ---------- água ----------
# nível da água neste ponto (ou -1000 se não tem água): rio, lago, ou mar/pântano (nível 0)
func agua(x: float, z: float) -> float:
	var dr := dist_rio(x, z)
	if dr < largura_rio(_amostra(t_rio, x, z)) * 0.5 + 0.5: return nivel_rio(_amostra(t_rio, x, z))
	if Vector2(x - LAGO.x, z - LAGO.y).length() < LAGO.z + 2.0: return nivel_lago()
	return 0.0

# ---------- o que tem aqui ----------
func campo_em(x: float, z: float) -> int:
	for c in campos:
		var p := Vector2(x - c[0], z - c[1]).rotated(deg_to_rad(-c[4]))
		if abs(p.x) < c[2] * 0.5 and abs(p.y) < c[3] * 0.5: return c[5]
	return -1

func zona_pantano(z: float) -> float: return smoothstep(380.0, 430.0, z)

func floresta(x: float, z: float) -> float:
	# 0 = aberto, 1 = mata fechada
	var f := ruido_grande.get_noise_2d(x * 1.6 + 300.0, z * 1.6) * 1.6 + 0.35
	f += 0.25 * smoothstep(250.0, 420.0, Vector2(x, z).length())   # mais mata longe da vila
	f -= 1.0 - smoothstep(40.0, 110.0, Vector2(x, z).length())       # vila e arredores abertos
	return clampf(f, 0.0, 1.0)

func cor(x: float, z: float, h: float, ny: float) -> Color:
	var n := ruido.get_noise_2d(x * 0.7 + 100.0, z * 0.7)
	var grama := Color(0.42, 0.58, 0.26)
	var c := grama.lerp(Color(0.56, 0.62, 0.3), smoothstep(-0.2, 0.4, n))     # verde mais claro e amarelado
	var f := floresta(x, z)
	c = c.lerp(Color(0.3, 0.42, 0.2), f * 0.6)                                 # chão de mata mais escuro
	var campo := campo_em(x, z)
	if campo == 0: c = Color(0.82, 0.68, 0.3) * (0.95 + n * 0.1)
	elif campo == 1:
		var faixa := int(floor(Vector2(x, z).rotated(0.2).x / 1.6)) % 2
		c = Color(0.48, 0.34, 0.22) * (0.9 + 0.12 * faixa)
	if dist_estrada(x, z) < 2.6 or Vector2(x, z).length() < 20.0: c = Color(0.52, 0.38, 0.24) * (0.95 + n * 0.1)
	var dr := dist_rio(x, z)
	if dr < largura_rio(_amostra(t_rio, x, z)) * 0.5 + 2.5 or abs(Vector2(x - LAGO.x, z - LAGO.y).length() - LAGO.z) < 4.0:
		c = Color(0.4, 0.33, 0.22)                                             # margem de lama
	if h < 2.0 and x > 380.0: c = Color(0.86, 0.78, 0.56) * (0.95 + n * 0.08)  # praia
	var p := zona_pantano(z)
	if p > 0.0: c = c.lerp(Color(0.3, 0.33, 0.2) * (0.9 + n * 0.15), p)
	if ny < 0.8: c = c.lerp(Color(0.46, 0.5, 0.6), smoothstep(0.8, 0.65, ny))  # pedra
	if h > 40.0: c = c.lerp(Color(0.88, 0.91, 0.98), smoothstep(40.0, 50.0, h))  # neve
	return c

# a grama nasce aqui? (devolve 0..1 = densidade)
func grama(x: float, z: float, h: float, ny: float) -> float:
	if abs(x) > LIM - 20 or abs(z) > LIM - 20 or ny < 0.8 or h > 30.0: return 0.0
	if Vector2(x, z).length() < 18.0: return 0.0
	if h < agua(x, z) + 0.15: return 0.0
	if x > 380.0 and h < 2.0: return 0.0
	var campo := campo_em(x, z)
	if campo == 1: return 0.0
	if campo == 0: return 1.0
	return 1.0 - floresta(x, z) * 0.6

func dentro(x: float, z: float) -> bool: return abs(x) < LIM and abs(z) < LIM

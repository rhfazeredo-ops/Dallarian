# Texturas pequenas e pixeladas geradas por código (estilo PS1): 32×32, mostradas sem suavização.
# Servem até chegarem as texturas dos modelos do Tripo.
class_name Texturas

static var _cache := {}

static func _img(n: int) -> Image: return Image.create(n, n, false, Image.FORMAT_RGB8)

static func _ruido(seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new(); r.seed = seed; return r

static func pegar(nome: String) -> ImageTexture:
	if _cache.has(nome): return _cache[nome]
	var im: Image
	match nome:
		"terreno": im = _terreno()
		"parede": im = _parede()
		"palha": im = _palha()
		"pedra": im = _pedra()
		"madeira": im = _madeira()
		"casca": im = _casca()
		"pinho": im = _pinho()
		"telha": im = _telha()
		_: im = _aco()
	var t := ImageTexture.create_from_image(im); _cache[nome] = t; return t

# telhas em fileiras, em tons claros de cinza (a cor do material pinta: azul, roxo...)
static func _telha() -> Image:
	var im := _img(32); var r := _ruido(9)
	for y in 32: for x in 32:
		var fila := y / 4; var desl := 4 if fila % 2 == 1 else 0
		var v := 1.0 + r.randf() * 0.12
		if y % 4 == 3: v = 0.62                            # sombra embaixo de cada fileira
		elif (x + desl) % 8 == 0: v = 0.78                 # junta entre as telhas
		elif y % 4 == 0: v *= 1.12                         # brilho na borda de cima
		im.set_pixel(x, y, Color(v, v, v))
	return im

# detalhe do terreno (cinza, multiplica a cor dos vértices)
static func _terreno() -> Image:
	var im := _img(32); var r := _ruido(1)
	for y in 32: for x in 32:
		var v := 0.9 + r.randf() * 0.14 - (0.08 if r.randf() < 0.08 else 0.0)
		im.set_pixel(x, y, Color(v, v, v))
	return im

# parede enxaimel: reboco bege com vigas de madeira escura
static func _parede() -> Image:
	var im := _img(32); var r := _ruido(2)
	for y in 32: for x in 32:
		var c := Color(0.82, 0.74, 0.58) * (0.92 + r.randf() * 0.12)
		var viga: bool = x < 3 or x > 28 or y < 3 or y > 28 or abs(x - y) < 2 or abs(x - 16) < 1
		if viga: c = Color(0.3, 0.2, 0.13) * (0.85 + r.randf() * 0.2)
		im.set_pixel(x, y, Color(c.r, c.g, c.b))
	return im

static func _palha() -> Image:
	var im := _img(32); var r := _ruido(3)
	for y in 32: for x in 32:
		var faixa := 0.85 + 0.15 * float((y / 4) % 2)
		var c := Color(0.78, 0.62, 0.3) * faixa * (0.85 + r.randf() * 0.25)
		if r.randf() < 0.1: c = c.darkened(0.3)
		im.set_pixel(x, y, Color(c.r, c.g, c.b))
	return im

static func _pedra() -> Image:
	var im := _img(32); var r := _ruido(4)
	for y in 32: for x in 32:
		var lin := y / 8; var off := 8 if lin % 2 == 1 else 0
		var junta: bool = y % 8 == 0 or (x + off) % 16 == 0
		var c := Color(0.55, 0.53, 0.55) * (0.85 + r.randf() * 0.2)
		if junta: c = Color(0.3, 0.29, 0.32)
		im.set_pixel(x, y, Color(c.r, c.g, c.b))
	return im

static func _madeira() -> Image:
	var im := _img(32); var r := _ruido(5)
	for y in 32: for x in 32:
		var c := Color(0.48, 0.32, 0.18) * (0.85 + r.randf() * 0.15)
		if x % 8 == 0: c = Color(0.25, 0.16, 0.09)
		if r.randf() < 0.06: c = c.darkened(0.25)
		im.set_pixel(x, y, Color(c.r, c.g, c.b))
	return im

static func _casca() -> Image:
	var im := _img(32); var r := _ruido(6)
	for y in 32: for x in 32:
		var c := Color(0.36, 0.26, 0.18) * (0.8 + r.randf() * 0.25)
		if (x + int(r.randf() * 2.0)) % 5 == 0: c = c.darkened(0.35)
		im.set_pixel(x, y, Color(c.r, c.g, c.b))
	return im

static func _pinho() -> Image:
	var im := _img(32); var r := _ruido(7)
	for y in 32: for x in 32:
		var c := Color(0.17, 0.3, 0.2) * (0.75 + r.randf() * 0.4)
		if (x + y * 3) % 7 == 0: c = c.darkened(0.3)
		im.set_pixel(x, y, Color(c.r, c.g, c.b))
	return im

static func _aco() -> Image:
	var im := _img(32); var r := _ruido(8)
	for y in 32: for x in 32:
		var v := 0.62 + 0.25 * float(x > 14 and x < 18) + r.randf() * 0.06
		im.set_pixel(x, y, Color(v, v, v * 1.05))
	return im

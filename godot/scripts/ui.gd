# Peças de interface no estilo do WoW (janelas escuras com borda dourada, espaços de item, moedas, dicas)
# e os ícones dos itens. Ícone: usa a arte em assets/ui/itens/<id>.png se existir; senão desenha um provisório.
extends RefCounted
class_name UI

const DOURADO := Color(0.85, 0.7, 0.42)
const TEXTO := Color(1, 0.92, 0.75)
const AMARELO := Color(1.0, 0.82, 0.0)
static var _icones := {}
static var _moedas_tex := {}

static func estilo(fundo: Color, borda: Color, raio := 12, margem := 22, espessura := 4) -> StyleBoxFlat:
	var st := StyleBoxFlat.new(); st.bg_color = fundo; st.set_corner_radius_all(raio)
	st.border_color = borda; st.set_border_width_all(espessura)
	st.content_margin_left = margem; st.content_margin_right = margem; st.content_margin_top = margem * 0.8; st.content_margin_bottom = margem
	st.shadow_color = Color(0, 0, 0, 0.45); st.shadow_size = 8
	return st

static func janela() -> PanelContainer:
	var p := PanelContainer.new(); p.add_theme_stylebox_override("panel", estilo(Color(0.07, 0.06, 0.05, 0.95), DOURADO))
	return p

static func rotulo(t: String, tam: int, cor := TEXTO, contorno := true) -> Label:
	var l := Label.new(); l.text = t; l.add_theme_font_size_override("font_size", tam); l.add_theme_color_override("font_color", cor)
	if contorno: l.add_theme_constant_override("outline_size", 6); l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	return l

static func botao(t: String, f: Callable, ativo := true, tam := 26, largura := 170.0) -> Button:
	var b := Button.new(); b.text = t; b.add_theme_font_size_override("font_size", tam); b.custom_minimum_size = Vector2(largura, 60)
	b.add_theme_stylebox_override("normal", estilo(Color(0.45, 0.08, 0.06), DOURADO, 8, 12, 3))     # vermelho dos botões do WoW
	b.add_theme_stylebox_override("hover", estilo(Color(0.58, 0.12, 0.08), Color(1, 0.85, 0.5), 8, 12, 3))
	b.add_theme_stylebox_override("pressed", estilo(Color(0.3, 0.05, 0.04), Color(1, 0.85, 0.5), 8, 12, 3))
	b.add_theme_stylebox_override("disabled", estilo(Color(0.2, 0.18, 0.16), Color(0.45, 0.4, 0.35), 8, 12, 3))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", AMARELO); b.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5))
	b.disabled = not ativo; b.pressed.connect(f)
	return b

static func botao_fechar(f: Callable) -> Button:
	var b := botao("X", f, true, 28, 60.0); b.custom_minimum_size = Vector2(60, 56); return b

# espaço de item: quadrado escuro com borda (cor da qualidade), ícone e quantidade
static func espaco(id: String, qtd: int, tam := 84.0, vazio_tex: Texture2D = null) -> Panel:
	var p := Panel.new(); p.custom_minimum_size = Vector2(tam, tam); p.mouse_filter = Control.MOUSE_FILTER_STOP
	var borda := Color(0.32, 0.28, 0.22)
	if id != "" and Bolsa.ITENS[id].qual != "lixo" and Bolsa.ITENS[id].qual != "comum": borda = Bolsa.CORES[Bolsa.ITENS[id].qual]
	p.add_theme_stylebox_override("panel", estilo(Color(0.03, 0.03, 0.03, 0.9), borda, 6, 0, 3))
	var tex: Texture2D = icone(id) if id != "" else vazio_tex
	if tex:
		var ic := TextureRect.new(); ic.texture = tex; ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.position = Vector2(5, 5); ic.size = Vector2(tam - 10, tam - 10); ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if id == "": ic.modulate = Color(1, 1, 1, 0.25)
		p.add_child(ic)
	if qtd > 1:
		var l := rotulo(str(qtd), 24); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.position = Vector2(0, tam - 34); l.size = Vector2(tam - 6, 30); l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(l)
	return p

# dinheiro como no WoW: só as moedas que aparecem (número + moedinha)
static func dinheiro(c: int, tam := 26, cor := TEXTO) -> HBoxContainer:
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 6); h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mo: Array = Bolsa.moedas(c)
	var nomes := ["ouro", "prata", "cobre"]
	for k in 3:
		if mo[k] == 0 and not (k == 2 and c == 0): continue
		h.add_child(rotulo(str(mo[k]), tam, cor))
		var ic := TextureRect.new(); ic.texture = moeda(nomes[k]); ic.custom_minimum_size = Vector2(tam, tam)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(ic)
	return h

static func moeda(nome: String) -> Texture2D:
	if _moedas_tex.has(nome): return _moedas_tex[nome]
	var arq := "res://assets/ui/moedas/%s.png" % nome
	if ResourceLoader.exists(arq): _moedas_tex[nome] = load(arq); return _moedas_tex[nome]
	var cor: Color = {"ouro": Color(1.0, 0.8, 0.22), "prata": Color(0.8, 0.82, 0.88), "cobre": Color(0.8, 0.45, 0.22)}[nome]
	var im := Image.create(32, 32, false, Image.FORMAT_RGBA8); im.fill(Color(0, 0, 0, 0))
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length()
			if d < 13.5: im.set_pixel(x, y, cor.darkened(0.45) if d > 11.5 else (cor.lightened(0.4) if Vector2(x - 11, y - 11).length() < 4 else cor))
	_moedas_tex[nome] = ImageTexture.create_from_image(im)
	return _moedas_tex[nome]

# ---------- ícones ----------
static func icone(id: String) -> Texture2D:
	if _icones.has(id): return _icones[id]
	var arq := "res://assets/ui/itens/%s.png" % id
	if not ResourceLoader.exists(arq) and id.begins_with("bolsa_"): arq = "res://assets/ui/itens/bolsa.png"
	var t: Texture2D
	if ResourceLoader.exists(arq): t = load(arq)
	elif id.begins_with("bolsa_"): t = _icone_bolsa(int(Bolsa.ITENS[id].espacos))
	elif Bolsa.ITENS[id].get("tipo", "") == "arma": t = _icone_espada(Bolsa.ITENS[id].get("modelo", "") == "ferro")
	elif Bolsa.ITENS[id].get("tipo", "") == "escudo": t = _icone_escudo()
	else: t = _icone_dentes()
	_icones[id] = t
	return t

static func _px(im: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < im.get_width() and y < im.get_height(): im.set_pixel(x, y, c)

# provisório: saco de couro amarrado (mais escuro e com faixas conforme o tamanho)
static func _icone_bolsa(espacos: int) -> ImageTexture:
	var im := Image.create(48, 48, false, Image.FORMAT_RGBA8); im.fill(Color(0, 0, 0, 0))
	var cor := Color(0.66, 0.45, 0.25).lerp(Color(0.35, 0.22, 0.12), clampf((espacos - 10) / 40.0, 0.0, 1.0))
	for y in 48:
		for x in 48:
			var d := Vector2((x - 24) / 17.0, (y - 30) / 15.0).length()
			var pesc := absf(x - 24) < 7 - (y - 8) * 0.1 and y >= 8 and y < 18
			if d < 1.0 or pesc:
				var c := cor * (1.15 - 0.4 * clampf((y - 14) / 34.0, 0.0, 1.0))
				if d > 0.88 or (pesc and absf(x - 24) > 5 - (y - 8) * 0.1): c = c.darkened(0.5)
				_px(im, x, y, c)
	for x in range(15, 34): _px(im, x, 17, Color(0.85, 0.72, 0.4)); _px(im, x, 18, Color(0.6, 0.48, 0.25))   # cordão
	if espacos >= 30:
		var faixa := Color(0.2, 0.55, 0.2) if espacos < 50 else Color(0.2, 0.35, 0.75)
		for x in range(9, 40): _px(im, x, 31, faixa); _px(im, x, 32, faixa)
	return ImageTexture.create_from_image(im)

# provisório: espada na diagonal (lâmina de madeira clara ou de ferro, guarda e cabo de couro)
static func _icone_espada(ferro: bool) -> ImageTexture:
	var im := Image.create(48, 48, false, Image.FORMAT_RGBA8); im.fill(Color(0, 0, 0, 0))
	var lam := Color(0.78, 0.8, 0.84) if ferro else Color(0.82, 0.62, 0.36)
	for t in 30:                                   # lâmina: de (14,34) até (42,6)
		var x := 14 + t; var y := 34 - t
		for w in range(-2, 3):
			var c := lam.lightened(0.3) if w < 0 else (lam.darkened(0.25) if w > 0 else lam)
			_px(im, x + w, y + w, c); _px(im, x + w + 1, y + w, c)
	for k in range(-6, 7): _px(im, 13 + k, 35 + k, Color(0.55, 0.45, 0.25) if not ferro else Color(0.45, 0.42, 0.4)); _px(im, 14 + k, 35 + k, Color(0.35, 0.28, 0.16))   # guarda
	for t in 9:                                    # cabo
		_px(im, 11 - t, 37 + t, Color(0.42, 0.26, 0.14)); _px(im, 12 - t, 37 + t, Color(0.3, 0.18, 0.1)); _px(im, 11 - t, 38 + t, Color(0.3, 0.18, 0.1))
	_px(im, 2, 46, Color(0.6, 0.5, 0.3)); _px(im, 3, 46, Color(0.6, 0.5, 0.3)); _px(im, 2, 45, Color(0.6, 0.5, 0.3))
	return ImageTexture.create_from_image(im)

# provisório: escudo redondo de tábuas com o umbo de ferro no meio
static func _icone_escudo() -> ImageTexture:
	var im := Image.create(48, 48, false, Image.FORMAT_RGBA8); im.fill(Color(0, 0, 0, 0))
	for y in 48:
		for x in 48:
			var d := Vector2(x - 23.5, y - 23.5).length()
			if d < 21.0:
				var tab := int(x / 7) % 2
				var c := Color(0.62, 0.42, 0.22) if tab == 0 else Color(0.55, 0.36, 0.18)
				if d > 18.5: c = Color(0.35, 0.22, 0.12)
				if d < 6.0: c = Color(0.6, 0.6, 0.62) if d < 4.5 else Color(0.35, 0.35, 0.38)
				_px(im, x, y, c)
	return ImageTexture.create_from_image(im)

# provisório: três presas curvas cor de marfim e duas garras escuras, presas por uma tira de couro
static func _icone_dentes() -> ImageTexture:
	var im := Image.create(48, 48, false, Image.FORMAT_RGBA8); im.fill(Color(0, 0, 0, 0))
	var marfim := Color(0.93, 0.86, 0.66)
	for k in 3:
		var bx := 14 + k * 9
		for t in 26:
			var u := t / 25.0
			var x := bx + int(sin(u * 1.4) * 6.0); var y := 8 + t
			var w := int(4.0 * (1.0 - u) + 1.0)
			for dx in w: _px(im, x + dx, y, marfim.darkened(0.15 * u) if dx > 0 else marfim.darkened(0.4))
	for k in 2:
		var bx := 10 + k * 26
		for t in 14:
			var u := t / 13.0
			var x := bx + int(u * u * 5.0 * (1 if k == 0 else -1)); var y := 22 + t
			for dx in int(3.0 * (1.0 - u) + 1.0): _px(im, x + dx, y, Color(0.35, 0.3, 0.26))
	for x in range(10, 40):
		for y in range(19, 24): _px(im, x, y, Color(0.45, 0.28, 0.14) * (1.1 if y == 19 else 0.9))
	return ImageTexture.create_from_image(im)

# Bússola no topo da tela (estilo RPG de mundo aberto): uma faixa que gira com a câmera mostrando
# N, NE, L, SE, S, SO, O, NO, marquinhas a cada 15° e os graus. Os locais importantes aparecem como ícones:
#  - ainda não descoberto: ícone apagado (só contorno), quando está a até 140 m;
#  - descoberto (chegou a menos do raio do local): ícone aceso até 400 m, e aparece "LOCAL DESCOBERTO".
extends Control
class_name Bussola

const LARG := 960.0
const ALT := 46.0
const CAMPO := 120.0            # graus visíveis na faixa
var m
var locais := []                # [nome, posição Vector2, tipo, raio de descoberta, descoberto?]
var aviso: Label
var aviso_nome: Label
var fonte: Font
var _icones := {}
signal descobriu(nome: String)

func montar(mundo, lista: Array) -> void:
	m = mundo
	for l in lista: locais.append([l[0], l[1], l[2], l[3], false])
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter = Control.MOUSE_FILTER_IGNORE
	fonte = ThemeDB.fallback_font
	aviso = _rotulo(26, Color(0.95, 0.88, 0.7), 140.0); aviso.text = "LOCAL DESCOBERTO"
	aviso_nome = _rotulo(40, Color(1, 1, 1), 172.0)

func _rotulo(tam: int, cor: Color, y: float) -> Label:
	var l := Label.new(); l.add_theme_font_size_override("font_size", tam); l.add_theme_color_override("font_color", cor)
	l.add_theme_constant_override("outline_size", 10); l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.anchor_left = 0.5; l.anchor_right = 0.5; l.offset_left = -700; l.offset_right = 700; l.offset_top = y; l.offset_bottom = y + 70
	l.modulate.a = 0.0; add_child(l); return l

func _rumo() -> float:            # para onde a câmera olha, em graus (N = 0, L = 90)
	return fposmod(-rad_to_deg(m.jogador.rotation.y), 360.0)

func _process(_d: float) -> void:
	if m == null or m.jogador == null: return
	var p := Vector2(m.jogador.global_position.x, m.jogador.global_position.z)
	for l in locais:
		if not l[4] and p.distance_to(l[1]) < l[3]:
			l[4] = true; _anunciar(l[0]); descobriu.emit(l[0])
	queue_redraw()

func _anunciar(nome: String) -> void:
	aviso_nome.text = nome
	for lb in [aviso, aviso_nome]:
		lb.modulate.a = 0.0
		var tw: Tween = lb.create_tween(); tw.tween_property(lb, "modulate:a", 1.0, 0.6); tw.tween_interval(2.6); tw.tween_property(lb, "modulate:a", 0.0, 1.0)

func _draw() -> void:
	if m == null or m.jogador == null: return
	var cx := get_viewport_rect().size.x * 0.5; var y0 := 22.0
	var meio := y0 + ALT * 0.5
	# só uma linha fina dourada que some nas pontas (sem faixa de fundo)
	var passos := 60
	for i in passos:
		var u0 := float(i) / passos; var u1 := float(i + 1) / passos
		var a := 0.5 * (1.0 - pow(abs((u0 + u1) - 1.0), 2.0))
		draw_line(Vector2(cx - LARG * 0.5 + LARG * u0, meio + 14), Vector2(cx - LARG * 0.5 + LARG * u1, meio + 14), Color(0.92, 0.8, 0.55, a), 1.5)
	var rumo := _rumo()
	var px_por_grau := LARG / CAMPO
	var letras := {0: "N", 45: "NE", 90: "L", 135: "SE", 180: "S", 225: "SO", 270: "O", 315: "NO"}
	for g in range(0, 360, 15):
		var rel := wrapf(g - rumo, -180.0, 180.0)
		if abs(rel) > CAMPO * 0.5 - 4: continue
		var x := cx + rel * px_por_grau
		var fade := 1.0 - pow(abs(rel) / (CAMPO * 0.5), 2.0)
		if letras.has(g):
			var t: String = letras[g]; var tam := 26 if t.length() == 1 else 19
			var cor := Color(1, 0.86, 0.55, fade * 0.95) if g == 0 else Color(1, 1, 1, fade * (0.9 if t.length() == 1 else 0.7))
			var w := fonte.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
			draw_string_outline(fonte, Vector2(x - w * 0.5, meio + tam * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, 5, Color(0, 0, 0, fade * 0.5))
			draw_string(fonte, Vector2(x - w * 0.5, meio + tam * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, cor)
		else:
			draw_line(Vector2(x, meio + 10), Vector2(x, meio + 14), Color(1, 1, 1, fade * 0.45), 1.5)
	# locais
	var p := Vector2(m.jogador.global_position.x, m.jogador.global_position.z)
	for l in locais:
		var d: Vector2 = l[1] - p; var dist := d.length()
		var conhecido: bool = l[4]
		if dist < 6.0 or dist > (400.0 if conhecido else 140.0): continue
		var rel := wrapf(rad_to_deg(atan2(d.x, -d.y)) - rumo, -180.0, 180.0)
		if abs(rel) > CAMPO * 0.5 - 4: continue
		var x := cx + rel * px_por_grau
		var fade := 1.0 - pow(abs(rel) / (CAMPO * 0.5), 2.0)
		_icone(l[2], Vector2(x, meio - 1), conhecido, fade * 0.9)
	# chefe: a única criatura que aparece na bússola, em vermelho, quando a Rachel está a até 160 m dele
	var ch = m.get("golem")
	if ch and is_instance_valid(ch) and ch.estado != "morto":
		var dc: Vector2 = Vector2(ch.global_position.x, ch.global_position.z) - p
		if dc.length() < 160.0 and dc.length() > 4.0:
			var relc := wrapf(rad_to_deg(atan2(dc.x, -dc.y)) - rumo, -180.0, 180.0)
			relc = clampf(relc, -CAMPO * 0.5 + 6.0, CAMPO * 0.5 - 6.0)          # fora da vista: fica preso na ponta
			_icone_chefe(Vector2(cx + relc * px_por_grau, meio - 2), dc.length())
	# marcador do centro: um tracinho
	draw_line(Vector2(cx, meio + 12), Vector2(cx, meio + 20), Color(1, 0.86, 0.55, 0.85), 2.0)

# ícone do chefe: arte em assets/ui/icones/chefe.png (pintada de vermelho); sem a arte, uma caveira vermelha.
# Pulsa mais rápido quanto mais perto.
func _icone_chefe(c: Vector2, dist: float) -> void:
	var pulso := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.001 * lerpf(9.0, 3.0, clampf(dist / 160.0, 0.0, 1.0)))
	var t := 40.0 * pulso
	if not _icones.has("chefe"):
		var cam := "res://assets/ui/icones/chefe.png"
		_icones["chefe"] = load(cam) if ResourceLoader.exists(cam) else null
	var tx: Texture2D = _icones["chefe"]
	var vermelho := Color(1.0, 0.18, 0.12)
	if tx:
		var r := Rect2(c - Vector2(t, t) * 0.5, Vector2(t, t))
		draw_texture_rect(tx, Rect2(r.position + Vector2(2, 2), r.size), false, Color(0, 0, 0, 0.7))
		draw_texture_rect(tx, r, false, vermelho.lightened(0.15))
		return
	var k := t / 40.0
	draw_circle(c + Vector2(1.5, 1.5), 15.0 * k, Color(0, 0, 0, 0.7))
	draw_circle(c + Vector2(0, -2) * k, 14.0 * k, vermelho)                       # crânio
	draw_rect(Rect2(c + Vector2(-8, 6) * k, Vector2(16, 8) * k), vermelho)        # queixo
	draw_circle(c + Vector2(-5.5, -2) * k, 4.2 * k, Color(0.12, 0.02, 0.02))      # olhos
	draw_circle(c + Vector2(5.5, -2) * k, 4.2 * k, Color(0.12, 0.02, 0.02))
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, 2) * k, c + Vector2(-2, 6) * k, c + Vector2(2, 6) * k]), Color(0.12, 0.02, 0.02))
	for dx in [-5.0, 0.0, 5.0]: draw_line(c + Vector2(dx, 8) * k, c + Vector2(dx, 14) * k, Color(0.12, 0.02, 0.02), 1.5 * k)

# ícones simples desenhados em linhas (conhecido: cheio e claro; desconhecido: só contorno, apagado)
func _icone(tipo: String, c: Vector2, aceso: bool, fade: float) -> void:
	# ícones desenhados (arte em assets/ui/icones); se faltar algum, usa o desenho em linhas
	if not _icones.has(tipo):
		var cam := "res://assets/ui/icones/%s.png" % tipo
		_icones[tipo] = load(cam) if ResourceLoader.exists(cam) else null
	var tx: Texture2D = _icones[tipo]
	if tx:
		var t := 34.0
		var r := Rect2(c - Vector2(t, t) * 0.5, Vector2(t, t))
		draw_texture_rect(tx, Rect2(r.position + Vector2(1.5, 1.5), r.size), false, Color(0, 0, 0, fade * (0.6 if aceso else 0.3)))
		draw_texture_rect(tx, r, false, Color(1, 0.97, 0.88, fade) if aceso else Color(0.8, 0.8, 0.8, fade * 0.4))
		return
	var cor := Color(1, 0.97, 0.88, fade) if aceso else Color(0.75, 0.75, 0.75, fade * 0.55)
	var sombra := Color(0, 0, 0, fade * (0.75 if aceso else 0.4))
	var formas := _formas(tipo, c, 0.75)
	for f in formas:                                     # contorno escuro por baixo
		draw_polyline(f, sombra, 3.5, true)
	for f in formas:
		if aceso and f.size() > 3 and f[0] == f[f.size() - 1]: draw_colored_polygon(f, Color(cor.r, cor.g, cor.b, fade * 0.35))
		draw_polyline(f, cor, 1.6, true)

func _formas(tipo: String, c: Vector2, k := 1.0) -> Array:
	var P := func(pts: Array) -> PackedVector2Array:
		var r := PackedVector2Array()
		for q in pts: r.append(c + q * k)
		return r
	match tipo:
		"vila":       # casinha com telhado
			return [P.call([Vector2(-10, 10), Vector2(-10, -1), Vector2(0, -11), Vector2(10, -1), Vector2(10, 10), Vector2(-10, 10)]), P.call([Vector2(-3, 10), Vector2(-3, 3), Vector2(3, 3), Vector2(3, 10)])]
		"ferraria":   # bigorna
			return [P.call([Vector2(-12, -5), Vector2(10, -5), Vector2(6, 0), Vector2(3, 0), Vector2(3, 5), Vector2(8, 10), Vector2(-8, 10), Vector2(-3, 5), Vector2(-3, 0), Vector2(-8, 0), Vector2(-12, -5)])]
		"mosteiro":   # torre com cruz
			return [P.call([Vector2(-6, 11), Vector2(-6, -3), Vector2(0, -8), Vector2(6, -3), Vector2(6, 11), Vector2(-6, 11)]), P.call([Vector2(0, -8), Vector2(0, -15)]), P.call([Vector2(-3, -12), Vector2(3, -12)])]
		"porto", "pier":   # barco com vela
			return [P.call([Vector2(-11, 4), Vector2(11, 4), Vector2(7, 10), Vector2(-7, 10), Vector2(-11, 4)]), P.call([Vector2(0, 4), Vector2(0, -12), Vector2(8, 1), Vector2(0, 1)])]
		"ruinas":     # torre quebrada
			return [P.call([Vector2(-8, 11), Vector2(-8, -8), Vector2(-4, -5), Vector2(-1, -11), Vector2(3, -4), Vector2(8, -7), Vector2(8, 11), Vector2(-8, 11)])]
		"serraria":   # tora com machado
			return [P.call([Vector2(-11, 3), Vector2(9, 3), Vector2(9, 10), Vector2(-11, 10), Vector2(-11, 3)]), P.call([Vector2(-2, 3), Vector2(4, -11)]), P.call([Vector2(2, -9), Vector2(8, -12), Vector2(8, -6), Vector2(3, -6)])]
		"bandidos":   # tenda
			return [P.call([Vector2(-11, 10), Vector2(0, -11), Vector2(11, 10), Vector2(-11, 10)]), P.call([Vector2(0, -11), Vector2(0, 10)]), P.call([Vector2(-4, 10), Vector2(0, 2), Vector2(4, 10)])]
		"caverna":    # arco de pedra
			return [P.call([Vector2(-12, 10), Vector2(-9, -3), Vector2(-3, -9), Vector2(3, -9), Vector2(9, -3), Vector2(12, 10), Vector2(-12, 10)]), P.call([Vector2(-5, 10), Vector2(-4, 1), Vector2(0, -3), Vector2(4, 1), Vector2(5, 10)])]
		"passagem":   # montanhas
			return [P.call([Vector2(-13, 10), Vector2(-5, -6), Vector2(0, 2), Vector2(5, -10), Vector2(13, 10), Vector2(-13, 10)])]
	return [P.call([Vector2(-6, 0), Vector2(0, -6), Vector2(6, 0), Vector2(0, 6), Vector2(-6, 0)])]

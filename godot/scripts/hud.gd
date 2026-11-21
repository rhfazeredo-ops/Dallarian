# HUD da personagem no canto superior direito (inspirado nos quadros de unidade dos MMOs, desenho nosso):
# retrato redondo da Rachel numa moldura dourada com um cantinho em degrau, e ao lado uma plaqueta com o
# nome, o nível e as barras de vida (verde) e mana (azul). O retrato é tirado do próprio modelo 3D dela.
# As molduras podem ser trocadas depois por arte (PNG) feita no ChatGPT.
extends Control
class_name Hud

var nome := "Rachel"
var hora := 9.0                    # relógio do jogo (vem do mundo)
var nivel := 1
var vida := 100.0; var vida_max := 100.0
var mana := 100.0; var mana_max := 100.0
var xp := 0.0; var xp_max := 400.0
var _xp_vis := 0.0
var _xp_texto_alfa := 0.0          # o texto da barra de XP só aparece um pouco quando ganha XP
var _nivel_alfa := 0.0             # aviso de "NÍVEL X" no meio da tela
var _vida_vis := 1.0; var _mana_vis := 1.0
var retrato: Texture2D
var fonte: Font
const R := 54.0                      # raio do retrato
const OURO := Color(0.86, 0.68, 0.32)
const OURO_CLARO := Color(1.0, 0.86, 0.5)

func montar() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter = Control.MOUSE_FILTER_IGNORE
	fonte = ThemeDB.fallback_font
	_tirar_retrato()

# renderiza o rosto da Rachel uma vez numa tela escondida e guarda como imagem
func _tirar_retrato() -> void:
	var vp := SubViewport.new(); vp.size = Vector2i(256, 256); vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS; vp.own_world_3d = true; add_child(vp)
	var mod: Node3D = load("res://assets/modelos/dallarian.glb").instantiate(); vp.add_child(mod)
	mod.rotation_degrees.y = -90                      # o modelo olha para +X; assim olha para +Z (para a câmera)
	var luz := DirectionalLight3D.new(); luz.rotation_degrees = Vector3(-25, 35, 0); luz.light_energy = 1.1; vp.add_child(luz)
	var amb := WorldEnvironment.new(); var env := Environment.new(); env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.75, 0.72, 0.8); env.ambient_light_energy = 0.8
	amb.environment = env; vp.add_child(amb)
	var cam := Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = 0.2
	cam.position = Vector3(0.0, 0.385, 1.0); vp.add_child(cam); cam.current = true      # o modelo vai de y -0,49 a 0,49
	for n in mod.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n
		var orig: BaseMaterial3D = mi.mesh.surface_get_material(0)
		if orig:
			var mt := orig.duplicate() as BaseMaterial3D; mt.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			mi.material_override = mt
	for k in 4: await RenderingServer.frame_post_draw
	retrato = ImageTexture.create_from_image(vp.get_texture().get_image())
	vp.queue_free(); queue_redraw()

func _process(delta: float) -> void:
	_vida_vis = move_toward(_vida_vis, vida / vida_max, delta * 0.8)
	_mana_vis = move_toward(_mana_vis, mana / mana_max, delta * 0.8)
	_xp_vis = move_toward(_xp_vis, xp / xp_max, delta * 0.6)
	_xp_texto_alfa = maxf(0.0, _xp_texto_alfa - delta * 0.35)
	_nivel_alfa = maxf(0.0, _nivel_alfa - delta * 0.3)
	for a in _avisos: a[2] -= delta
	while not _avisos.is_empty() and _avisos[0][2] <= 0.0: _avisos.pop_front()
	queue_redraw()

# artes (ChatGPT): plaqueta 2172×724 e moldura 1254×1254, ambas com fundo transparente.
# Medidas na imagem da plaqueta: centro do arco (172, 364); trilho da vida x 418–2042, y 337–458;
# trilho da mana x 429–1977, y 498–548; faixa do nome x 592–1938, y 174–300. Moldura: buraco centro (611, 627), raio 477.
var tex_plaqueta: Texture2D = load("res://assets/ui/plaqueta.png")
var tex_moldura: Texture2D = load("res://assets/ui/moldura_retrato.png")

func _draw() -> void:
	var tela := get_viewport_rect().size
	var k := 0.2                                              # escala da plaqueta na tela
	var pw := 2172.0 * k; var ph := 724.0 * k
	var p0 := Vector2(tela.x - pw - 24.0, 18.0)               # canto superior esquerdo da plaqueta
	var P := func(x: float, y: float) -> Vector2: return p0 + Vector2(x, y) * k
	_desenhar_xp(tela)
	_desenhar_avisos(tela)
	_desenhar_relogio(tela)
	draw_texture_rect(tex_plaqueta, Rect2(p0, Vector2(pw, ph)), false)
	# barras dentro dos trilhos
	_barra(Rect2(P.call(418, 337), Vector2(2042 - 418, 458 - 337) * k), _vida_vis, Color(0.42, 0.78, 0.22), Color(0.62, 0.92, 0.36), "%d / %d" % [vida, vida_max])
	_barra(Rect2(P.call(429, 498), Vector2(1977 - 429, 548 - 498) * k), _mana_vis, Color(0.16, 0.36, 0.82), Color(0.36, 0.58, 1.0), "")
	# nome e nível na faixa de couro
	var base_nome: Vector2 = P.call(640, 262)
	draw_string_outline(fonte, base_nome, nome, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 5, Color(0, 0, 0, 0.85))
	draw_string(fonte, base_nome, nome, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, OURO_CLARO)
	var nv := str(nivel); var wn := fonte.get_string_size(nv, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	var base_nv: Vector2 = P.call(1890, 262) - Vector2(wn, 0)
	draw_string_outline(fonte, base_nv, nv, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 5, Color(0, 0, 0, 0.85))
	draw_string(fonte, base_nv, nv, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, OURO_CLARO)
	# retrato no arco da plaqueta, com a moldura dourada por cima
	var c: Vector2 = P.call(172, 364)
	var r_moldura := 66.0                                     # meia largura da moldura na tela
	var km := r_moldura / 627.0
	var r_foto := 477.0 * km + 1.0
	var cf := c + Vector2(611 - 627, 0) * km                  # o buraco da moldura é um pouco à esquerda do centro
	var pts := PackedVector2Array(); var uvs := PackedVector2Array()
	for i in 48:
		var a := TAU * i / 48.0; var q := Vector2(cos(a), sin(a))
		pts.append(cf + q * r_foto); uvs.append(Vector2(0.5, 0.5) + q * 0.5)
	draw_colored_polygon(pts, Color(0.12, 0.16, 0.3), uvs)
	if retrato: draw_colored_polygon(pts, Color.WHITE, uvs, retrato)
	draw_texture_rect(tex_moldura, Rect2(c - Vector2(627, 627) * km, Vector2(1254, 1254) * km), false)

# níveis: do 1 ao 30 (máximo por enquanto). XP para passar do nível n: 80·n^1,5 (arredondado de 10 em 10):
# 80, 230, 420, 640 ... ~12.500 no 29. Cada nível: +8 de vida e +5 de mana, e enche as duas.
const NIVEL_MAX := 30
signal mudou                       # XP/nível mudaram (o mundo salva o progresso)
# tabela do WoW Classic (XP para passar do nível n para o n+1)
const TABELA_XP := [400, 900, 1400, 2100, 2800, 3600, 4500, 5400, 6500, 7600, 8800, 10100, 11400, 12900, 14400,
	16000, 17700, 19400, 21300, 23200, 25200, 27300, 29400, 31700, 34000, 36400, 38900, 41400, 44300]
static func xp_do_nivel(n: int) -> float: return float(TABELA_XP[clampi(n, 1, TABELA_XP.size()) - 1])

# XP por matar um bicho, como no Classic: 45 + 5×nível dele, +5% por nível acima da Rachel (até +4),
# menos conforme ele é mais fraco ("zona de diferença"), e nada se ele for "cinza" (fraco demais)
static func xp_por_matar(nv_bicho: int, nv_heroi: int) -> float:
	var base := 45.0 + 5.0 * nv_bicho
	if nv_bicho >= nv_heroi: return roundf(base * (1.0 + 0.05 * mini(nv_bicho - nv_heroi, 4)))
	var cinza := 0 if nv_heroi <= 5 else nv_heroi - int(nv_heroi / 10.0) - 5
	if nv_bicho <= cinza: return 0.0
	var zd := 5 if nv_heroi <= 7 else (6 if nv_heroi <= 9 else (7 if nv_heroi <= 11 else (8 if nv_heroi <= 15 else (9 if nv_heroi <= 19 else 11))))
	return roundf(base * maxf(0.0, 1.0 - float(nv_heroi - nv_bicho) / zd))

func ganhar_xp(qtd: float) -> void:
	if nivel >= NIVEL_MAX: return
	xp += qtd; _xp_texto_alfa = 1.0
	avisar("+%d XP" % qtd, Color(1.0, 0.86, 0.45))
	while xp >= xp_max and nivel < NIVEL_MAX:
		xp -= xp_max; nivel += 1; xp_max = xp_do_nivel(nivel); _xp_vis = 0.0; _nivel_alfa = 1.0
		vida_max += 8.0; mana_max += 5.0; vida = vida_max; mana = mana_max
	if nivel >= NIVEL_MAX: xp = xp_max
	mudou.emit()

# põe o progresso salvo (nível e XP) sem avisos
func definir_nivel(n: int, x: float) -> void:
	nivel = clampi(n, 1, NIVEL_MAX); xp_max = xp_do_nivel(nivel); xp = clampf(x, 0.0, xp_max - 1.0)
	vida_max = 100.0 + (nivel - 1) * 8.0; mana_max = 100.0 + (nivel - 1) * 5.0; vida = vida_max; mana = mana_max
	_xp_vis = xp / xp_max; _vida_vis = 1.0

# relógio clean embaixo da bússola: sol ou lua + hora (de 5 em 5 minutos)
func _desenhar_relogio(tela: Vector2) -> void:
	var h := int(hora); var mi := int(fmod(hora, 1.0) * 60.0) / 5 * 5
	var t := "%02d:%02d" % [h, mi]
	var tam := 24
	var w := fonte.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	var c := Vector2(tela.x * 0.5, 84.0)
	var ic := c + Vector2(-w * 0.5 - 16.0, -8.0)
	var dia := hora >= 6.0 and hora < 18.5
	if dia:
		draw_circle(ic, 7.0, Color(0, 0, 0, 0.5)); draw_circle(ic, 5.5, Color(1.0, 0.85, 0.4))
		for k in 8:
			var a := TAU * k / 8.0; var d := Vector2(cos(a), sin(a))
			draw_line(ic + d * 8.0, ic + d * 11.0, Color(1.0, 0.85, 0.4, 0.9), 2.0)
	else:
		draw_arc(ic, 6.5, PI * 0.42, PI * 1.58, 18, Color(0, 0, 0, 0.5), 6.0)     # lua crescente
		draw_arc(ic, 6.0, PI * 0.45, PI * 1.55, 18, Color(0.9, 0.92, 1.0), 4.0)
	var pos := Vector2(c.x - w * 0.5 + 6.0, c.y)
	draw_string_outline(fonte, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, 6, Color(0, 0, 0, 0.75))
	draw_string(fonte, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, Color(1, 0.95, 0.85, 0.92))

# avisos curtos que sobem no lado esquerdo (XP ganho, item pego, dinheiro)
var _avisos := []                 # [texto, cor, tempo]
func avisar(t: String, cor := Color(1, 1, 1)) -> void:
	_avisos.append([t, cor, 3.0])
	if _avisos.size() > 5: _avisos.pop_front()

func _desenhar_avisos(tela: Vector2) -> void:
	var y := tela.y * 0.62
	for i in range(_avisos.size() - 1, -1, -1):
		var a: Array = _avisos[i]
		var alfa := clampf(a[2], 0.0, 1.0)
		var pos := Vector2(40, y)
		draw_string_outline(fonte, pos, a[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, 7, Color(0, 0, 0, 0.8 * alfa))
		var c: Color = a[1]; c.a = alfa
		draw_string(fonte, pos, a[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, c)
		y -= 34

# barra de XP: uma linha fina no rodapé, quase invisível; brilha um pouco e mostra o texto quando ganha XP
func _desenhar_xp(tela: Vector2) -> void:
	var m := 260.0; var h := 6.0
	var r := Rect2(m, tela.y - h - 6.0, tela.x - m * 2.0, h)
	draw_rect(r.grow(1), Color(0, 0, 0, 0.45))
	draw_rect(r, Color(0.1, 0.09, 0.08, 0.55))
	var f := Rect2(r.position, Vector2(r.size.x * clampf(_xp_vis, 0, 1), h))
	var brilho := 0.75 + 0.25 * _xp_texto_alfa
	draw_rect(f, Color(0.86, 0.66, 0.28, brilho))
	draw_rect(Rect2(f.position, Vector2(f.size.x, 2)), Color(1, 0.88, 0.55, brilho))
	for i in range(1, 10):                                   # divisórias discretas a cada 10%
		var x := r.position.x + r.size.x * i / 10.0
		draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(0, 0, 0, 0.35), 1.0)
	if _xp_texto_alfa > 0.0:
		var t := "%d / %d XP" % [xp, xp_max] if nivel < NIVEL_MAX else "NÍVEL MÁXIMO"
		var w := fonte.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		var pos := Vector2(tela.x * 0.5 - w * 0.5, r.position.y - 8)
		draw_string_outline(fonte, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, Color(0, 0, 0, 0.8 * minf(1.0, _xp_texto_alfa * 2.0)))
		draw_string(fonte, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 0.9, 0.65, minf(1.0, _xp_texto_alfa * 2.0)))
	if _nivel_alfa > 0.0:
		var a := minf(1.0, _nivel_alfa * 2.5)
		var t2 := "NÍVEL %d" % nivel
		var w2 := fonte.get_string_size(t2, HORIZONTAL_ALIGNMENT_LEFT, -1, 56).x
		var p2 := Vector2(tela.x * 0.5 - w2 * 0.5, tela.y * 0.36)
		draw_string_outline(fonte, p2, t2, HORIZONTAL_ALIGNMENT_LEFT, -1, 56, 10, Color(0, 0, 0, 0.8 * a))
		draw_string(fonte, p2, t2, HORIZONTAL_ALIGNMENT_LEFT, -1, 56, Color(1, 0.86, 0.5, a))

func _barra(r: Rect2, frac: float, cor: Color, brilho: Color, texto: String) -> void:
	var f := Rect2(r.position, Vector2(r.size.x * clampf(frac, 0, 1), r.size.y))
	draw_rect(f, cor)
	draw_rect(Rect2(f.position, Vector2(f.size.x, f.size.y * 0.35)), brilho)          # faixa de brilho em cima
	if texto != "":
		var w := fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		var pos := Vector2(r.position.x + (r.size.x - w) * 0.5, r.position.y + r.size.y * 0.5 + 6)
		draw_string_outline(fonte, pos, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 4, Color(0, 0, 0, 0.85))
		draw_string(fonte, pos, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 1, 1))

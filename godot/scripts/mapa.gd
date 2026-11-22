# Mapa da região (como o mapa do WoW): a imagem do terreno inteira, sem lugares marcados (eles só aparecem na
# bússola), e a Rachel como uma setinha dourada apontando para onde ela olha. Botão de mapa (PC: tecla M).
extends Control
class_name Mapa

var m
var aberto := false
# nome deste mapa (região inicial); Dallarian é o continente. Cada mapa novo terá o seu nome.
const NOME := "Vale de Aldren"
var _tex: Texture2D = load("res://assets/ui/mapa.png")
var _botao: BotaoAcao
var _tecla_antes := false
var _quadro := Rect2()

func montar(mundo) -> void:
	m = mundo
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter = Control.MOUSE_FILTER_IGNORE
	_botao = BotaoAcao.criar("mapa", 112)
	_botao.anchor_left = 1; _botao.anchor_right = 1
	_botao.offset_left = -270; _botao.offset_right = -158; _botao.offset_top = 182; _botao.offset_bottom = 294
	_botao.apertou.connect(alternar); add_child(_botao)

func alternar() -> void:
	aberto = not aberto
	mouse_filter = Control.MOUSE_FILTER_STOP if aberto else Control.MOUSE_FILTER_IGNORE
	m.controles.set_process_input(not aberto)
	for c in get_parent().get_children(): if c is Bussola: c.visible = not aberto
	if aberto: m.controles.dir = Vector2.ZERO
	queue_redraw()

func _gui_input(e: InputEvent) -> void:
	# tocar fora do mapa (ou no X) fecha
	if aberto and ((e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed)):
		var fechar := Rect2(_quadro.end.x - 70, _quadro.position.y + 10, 60, 60)
		if not _quadro.has_point(e.position) or fechar.has_point(e.position): alternar()
		accept_event()

func _process(_d: float) -> void:
	var t := Input.is_key_pressed(KEY_M)
	if t and not _tecla_antes: alternar()
	_tecla_antes = t
	if aberto: queue_redraw()

func _draw() -> void:
	if not aberto: return
	var tela := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, tela), Color(0, 0, 0, 0.55))
	# mapa retangular (mais largo que alto): cabe na tela mantendo a proporção do mundo
	var prop := (Regiao.X1 - Regiao.X0) / (Regiao.Z1 - Regiao.Z0)
	var alt := minf(tela.y - 150.0, (tela.x - 120.0) / prop); var larg := alt * prop
	_quadro = Rect2((tela - Vector2(larg, alt)) * 0.5 + Vector2(0, 40), Vector2(larg, alt))
	# moldura dourada e o mapa
	draw_rect(_quadro.grow(14), Color(0.07, 0.06, 0.05))
	draw_rect(_quadro.grow(14), UI.DOURADO, false, 5.0)
	draw_rect(_quadro.grow(5), Color(0.45, 0.35, 0.2), false, 3.0)
	draw_texture_rect(_tex, _quadro, false)
	var fonte := ThemeDB.fallback_font
	var tit := NOME
	var w := fonte.get_string_size(tit, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
	draw_string_outline(fonte, Vector2(tela.x * 0.5 - w * 0.5, _quadro.position.y - 24), tit, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, 8, Color(0, 0, 0, 0.9))
	draw_string(fonte, Vector2(tela.x * 0.5 - w * 0.5, _quadro.position.y - 24), tit, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, UI.AMARELO)
	# rosa dos ventos simples (N em cima)
	var rn := _quadro.position + Vector2(48, 60)
	draw_string_outline(fonte, rn + Vector2(-9, -12), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 7, Color(0, 0, 0, 0.9))
	draw_string(fonte, rn + Vector2(-9, -12), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 0.95, 0.85))
	draw_colored_polygon(PackedVector2Array([rn + Vector2(0, -6), rn + Vector2(7, 14), rn + Vector2(0, 9), rn + Vector2(-7, 14)]), Color(0.9, 0.2, 0.15))
	# fechar
	var xr := Rect2(_quadro.end.x - 64, _quadro.position.y + 12, 52, 52)
	draw_rect(xr, Color(0.45, 0.08, 0.06)); draw_rect(xr, UI.DOURADO, false, 3.0)
	draw_string(fonte, xr.position + Vector2(15, 39), "X", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, UI.AMARELO)
	# a Rachel: setinha dourada na posição dela, girando conforme ela olha (pisca de leve)
	if m.jogador == null: return
	var p: Vector3 = m.jogador.global_position
	var u := Vector2((p.x - Regiao.X0) / (Regiao.X1 - Regiao.X0), (p.z - Regiao.Z0) / (Regiao.Z1 - Regiao.Z0))
	var c := _quadro.position + u * _quadro.size
	var fr: Vector3 = -m.jogador.global_transform.basis.z
	var d := Vector2(fr.x, fr.z).normalized(); var lado2 := Vector2(-d.y, d.x)
	var s := 16.0 + 2.0 * sin(Time.get_ticks_msec() * 0.006)
	var seta := PackedVector2Array([c + d * s, c - d * s * 0.7 + lado2 * s * 0.75, c - d * s * 0.35, c - d * s * 0.7 - lado2 * s * 0.75])
	var borda := PackedVector2Array(); for q in seta: borda.append(c + (q - c) * 1.35)
	draw_colored_polygon(borda, Color(0, 0, 0, 0.85))
	draw_colored_polygon(seta, Color(1.0, 0.82, 0.2))

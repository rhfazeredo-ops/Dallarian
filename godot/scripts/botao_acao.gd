# Botão de ação com as artes do HUD: moldura dourada celta (assets/ui/botao.png) + símbolo branco
# (assets/ui/acoes/<nome>.png). Ao apertar, afunda um pouco e o símbolo brilha dourado.
# Inativo (desligado): fica apagado. Recarga (0..1): "pizza" escura girando por cima.
extends Control
class_name BotaoAcao

signal apertou
signal soltou
var icone: Texture2D
var ativo := true
var recarga := 0.0
var _apertado := false
var _escala := 1.0
static var _moldura: Texture2D

static func criar(nome: String, tamanho: float) -> BotaoAcao:
	var b := BotaoAcao.new()
	b.icone = load("res://assets/ui/acoes/%s.png" % nome)
	b.custom_minimum_size = Vector2(tamanho, tamanho); b.size = Vector2(tamanho, tamanho)
	return b

func _ready() -> void:
	if _moldura == null: _moldura = load("res://assets/ui/botao.png")
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT) or e is InputEventScreenTouch:
		var dentro: bool = (e.position - size * 0.5).length() < size.x * 0.5
		if e.pressed and dentro and not _apertado:
			_apertado = true; apertou.emit(); accept_event()
		elif not e.pressed and _apertado:
			_apertado = false; soltou.emit(); accept_event()

func _process(delta: float) -> void:
	_escala = move_toward(_escala, 0.9 if _apertado else 1.0, delta * 2.5)
	queue_redraw()

func _draw() -> void:
	var t := size.x * _escala; var c := size * 0.5
	var r := Rect2(c - Vector2(t, t) * 0.5, Vector2(t, t))
	var a := 1.0 if ativo else 0.5
	draw_texture_rect(_moldura, r, false, Color(1, 1, 1, 0.92 * a))
	if icone:
		var ti := t * 0.46; var ri := Rect2(c - Vector2(ti, ti) * 0.5, Vector2(ti, ti))
		draw_texture_rect(icone, Rect2(ri.position + Vector2(2, 3), ri.size), false, Color(0, 0, 0, 0.55 * a))
		var cor := Color(1.0, 0.86, 0.5) if _apertado else Color(1, 1, 1, a)
		draw_texture_rect(icone, ri, false, cor)
	if recarga > 0.0:
		var pts := PackedVector2Array([c]); var rr := t * 0.33
		for i in 33:
			var ang := -PI / 2.0 + TAU * recarga * i / 32.0; pts.append(c + Vector2(cos(ang), sin(ang)) * rr)
		draw_colored_polygon(pts, Color(0, 0, 0, 0.6))

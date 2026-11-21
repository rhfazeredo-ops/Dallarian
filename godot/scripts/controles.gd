# Controles: celular (joystick à esquerda, arrastar à direita para olhar, botões ATACAR, BLOQUEAR, CORRER,
# PULAR — atacar, bloquear e correr funcionam segurando) e PC (WASD anda, Shift corre, espaço pula,
# mouse olha, botão esquerdo ataca — segurar = golpe forte —, botão direito bloqueia).
extends Control
class_name Controles

var dir := Vector2.ZERO
var _olhar := Vector2.ZERO
var _pulo := false
var _ataque := false
var _seg := {}                 # botões de segurar apertados agora
var ataque_mouse := false
var bloqueio_mouse := false
var _dedo := -1; var _centro := Vector2.ZERO; var _ponta := Vector2.ZERO
var _dedo_olhar := -1
var fps: Label
var _base: Texture2D
var _pino: Texture2D
var _pular_btn: Control
const RAIO := 110.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_botao("ATACAR", -320, -310, 250, "atacar")
	_botao("BLOQUEAR", -575, -240, 180, "bloquear")
	_botao("CORRER", -300, -540, 165, "correr")
	_botao("PULAR", -520, -455, 150, "pular")
	_base = load("res://assets/ui/joystick_base.png"); _pino = load("res://assets/ui/joystick_pino.png")
	fps = Label.new(); fps.position = Vector2(24, 18); fps.add_theme_font_size_override("font_size", 30)
	fps.add_theme_color_override("font_outline_color", Color.BLACK); fps.add_theme_constant_override("outline_size", 8)
	add_child(fps)

func _botao(_txt: String, x: float, y: float, t: float, nome: String) -> void:
	var b := BotaoAcao.criar(nome, t)
	b.anchor_left = 1; b.anchor_top = 1; b.anchor_right = 1; b.anchor_bottom = 1
	b.offset_left = x; b.offset_top = y; b.offset_right = x + t; b.offset_bottom = y + t
	b.apertou.connect(func():
		_seg[nome] = true
		if nome == "pular": _pulo = true)
	b.soltou.connect(func(): _seg[nome] = false)
	add_child(b)

func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		# garantia para vários dedos: tocar no PULAR com o outro dedo no joystick sempre pula
		if e.pressed and _pular_btn and _pular_btn.get_global_rect().has_point(e.position): _pulo = true
		if e.pressed:
			if e.position.x < get_viewport_rect().size.x * 0.4 and _dedo == -1:
				_dedo = e.index; _centro = e.position; _ponta = e.position
			elif _dedo_olhar == -1 and e.position.x >= get_viewport_rect().size.x * 0.4:
				_dedo_olhar = e.index
		else:
			if e.index == _dedo: _dedo = -1; dir = Vector2.ZERO
			if e.index == _dedo_olhar: _dedo_olhar = -1
		queue_redraw()
	elif e is InputEventScreenDrag:
		if e.index == _dedo:
			_ponta = e.position
			var v: Vector2 = (_ponta - _centro) / RAIO
			dir = v.limit_length(1.0) if v.length() > 0.12 else Vector2.ZERO
			queue_redraw()
		elif e.index == _dedo_olhar:
			_olhar += e.relative

func _process(_d: float) -> void:
	fps.text = "%d FPS" % Engine.get_frames_per_second()
	if _dedo != -1: return
	var k := Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))
	if Input.is_key_pressed(KEY_A): k.x -= 1
	if Input.is_key_pressed(KEY_D): k.x += 1
	if Input.is_key_pressed(KEY_W): k.y -= 1
	if Input.is_key_pressed(KEY_S): k.y += 1
	dir = k.limit_length(1.0)
	if Input.is_key_pressed(KEY_SPACE): _pulo = true

func consumir_olhar() -> Vector2:
	var v := _olhar; _olhar = Vector2.ZERO; return v
func consumir_pulo() -> bool:
	var v := _pulo; _pulo = false; return v
func atacando() -> bool: return _seg.get("atacar", false) or ataque_mouse
func bloqueando() -> bool: return _seg.get("bloquear", false) or bloqueio_mouse
func correndo() -> bool: return _seg.get("correr", false) or Input.is_key_pressed(KEY_SHIFT)

func _draw() -> void:
	# joystick com as artes: aparece onde o dedo toca; parado, fica bem apagado no canto (só no celular)
	var tela := get_viewport_rect().size
	var centro := _centro; var ponta := _ponta; var alfa := 0.95
	if _dedo == -1:
		if not (OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()): return
		centro = Vector2(250, tela.y - 260); ponta = centro; alfa = 0.35
	var rb := RAIO * 1.35
	draw_texture_rect(_base, Rect2(centro - Vector2(rb, rb), Vector2(rb, rb) * 2.0), false, Color(1, 1, 1, alfa * 0.9))
	var pp := centro + (ponta - centro).limit_length(RAIO)
	var rp := RAIO * 0.5
	draw_texture_rect(_pino, Rect2(pp - Vector2(rp, rp), Vector2(rp, rp) * 2.0), false, Color(1, 1, 1, alfa))

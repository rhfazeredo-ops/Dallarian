# Controles: celular (joystick à esquerda, arrastar à direita para olhar, botões ATACAR, BLOQUEAR e PULAR —
# atacar e bloquear funcionam segurando; correr é pela trava acima do joystick) e PC (WASD anda, Shift corre, espaço pula,
# mouse olha, botão esquerdo ataca — segurar = golpe forte —, botão direito dá escudada).
extends Control
class_name Controles

var dir := Vector2.ZERO
var _olhar := Vector2.ZERO
var _pulo := false
var _alvo := false
var _tab_antes := false
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
# joystick fixo no canto de baixo à esquerda; empurrando para cima além da borda aparece a TRAVA logo acima dele:
# levando o dedo até ela, a Rachel corre sozinha para a frente (corrida automática). Com a trava ligada o joystick
# só vira para os lados; puxar para trás ou tocar no botão AUTO desliga. PC: tecla R liga/desliga.
var auto := false
var _mostrar_trava := false
var _joy := Vector2.ZERO
var _r_antes := false
func _centro_fixo() -> Vector2: return Vector2(250, get_viewport_rect().size.y - 260)
func _pos_trava() -> Vector2: return _centro_fixo() + Vector2(0, -RAIO * 3.3)   # bem acima: andando não pega sem querer
func _aplicar_dir() -> void:
	if auto:
		if _joy.y > 0.55: auto = false; dir = _joy; return          # puxou para trás: desliga a trava
		dir = Vector2(_joy.x, -1.0).limit_length(1.0)
	else: dir = _joy

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_botao("ATACAR", -320, -310, 250, "atacar")
	_botao("ESCUDADA", -575, -240, 180, "bloquear")
	_botao("PULAR", -520, -455, 150, "pular")
	_botao("ALVO", -190, -720, 130, "alvo")
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
		if nome == "pular": _pulo = true
		if nome == "alvo": _alvo = true)
	b.soltou.connect(func(): _seg[nome] = false)
	add_child(b)

func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		# garantia para vários dedos: tocar no PULAR com o outro dedo no joystick sempre pula
		if e.pressed and _pular_btn and _pular_btn.get_global_rect().has_point(e.position): _pulo = true
		if e.pressed:
			if auto and e.position.distance_to(_pos_trava()) < 75.0:          # tocou no AUTO: desliga
				auto = false; _aplicar_dir()
			elif e.position.x < get_viewport_rect().size.x * 0.4 and _dedo == -1:
				_dedo = e.index; _centro = _centro_fixo(); _ponta = e.position
				_arrastar(e.position)
			elif _dedo_olhar == -1 and e.position.x >= get_viewport_rect().size.x * 0.4:
				_dedo_olhar = e.index
		else:
			if e.index == _dedo: _dedo = -1; _joy = Vector2.ZERO; _mostrar_trava = false; _aplicar_dir()
			if e.index == _dedo_olhar: _dedo_olhar = -1
		queue_redraw()
	elif e is InputEventScreenDrag:
		if e.index == _dedo:
			_arrastar(e.position)
		elif e.index == _dedo_olhar:
			_olhar += e.relative

func _arrastar(pos: Vector2) -> void:
	_ponta = pos
	var v: Vector2 = (_ponta - _centro) / RAIO
	_joy = v.limit_length(1.0) if v.length() > 0.12 else Vector2.ZERO
	_mostrar_trava = not auto and v.y < -1.9 and absf(v.x) < 0.9            # esticou o dedo bem além da borda
	if _mostrar_trava and _ponta.distance_to(_pos_trava()) < 60.0:
		auto = true; _mostrar_trava = false
	_aplicar_dir(); queue_redraw()

func _process(_d: float) -> void:
	fps.text = "%d FPS" % Engine.get_frames_per_second()
	if not is_processing_input() and auto: auto = false                       # abriu bolsa/loja/menu: para
	if auto or _mostrar_trava: queue_redraw()
	var r := Input.is_key_pressed(KEY_R)
	if r and not _r_antes and is_processing_input(): auto = not auto
	_r_antes = r
	var tab := Input.is_key_pressed(KEY_TAB)                 # Tab trava/solta a mira (PC)
	if tab and not _tab_antes: _alvo = true
	_tab_antes = tab
	if _dedo != -1: return
	var k := Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))
	if Input.is_key_pressed(KEY_A): k.x -= 1
	if Input.is_key_pressed(KEY_D): k.x += 1
	if Input.is_key_pressed(KEY_W): k.y -= 1
	if Input.is_key_pressed(KEY_S): k.y += 1
	_joy = k.limit_length(1.0); _aplicar_dir()
	if Input.is_key_pressed(KEY_SPACE): _pulo = true

func consumir_olhar() -> Vector2:
	var v := _olhar; _olhar = Vector2.ZERO; return v
func consumir_alvo() -> bool:
	var v := _alvo; _alvo = false; return v
func consumir_pulo() -> bool:
	var v := _pulo; _pulo = false; return v
func atacando() -> bool: return _seg.get("atacar", false) or ataque_mouse
func bloqueando() -> bool: return _seg.get("bloquear", false) or bloqueio_mouse
func correndo() -> bool: return _seg.get("correr", false) or Input.is_key_pressed(KEY_SHIFT) or auto

func _draw() -> void:
	# joystick com as artes, fixo no canto de baixo à esquerda; parado fica bem apagado (só no celular)
	var centro := _centro_fixo(); var ponta := _ponta; var alfa := 0.95
	var toque := OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	if _mostrar_trava or auto: _desenhar_trava(_pos_trava(), auto)
	if _dedo == -1:
		if not toque: return
		ponta = centro; alfa = 0.35
	var rb := RAIO * 1.35
	draw_texture_rect(_base, Rect2(centro - Vector2(rb, rb), Vector2(rb, rb) * 2.0), false, Color(1, 1, 1, alfa * 0.9))
	var pp := centro + (ponta - centro).limit_length(RAIO)
	var rp := RAIO * 0.5
	draw_texture_rect(_pino, Rect2(pp - Vector2(rp, rp), Vector2(rp, rp) * 2.0), false, Color(1, 1, 1, alfa))

# botão da trava: círculo dourado com duas setas para cima; ligado mostra "AUTO" e pulsa
func _desenhar_trava(c: Vector2, ligado: bool) -> void:
	var t := Time.get_ticks_msec() * 0.001
	var r := 46.0 + (3.0 * sin(t * 6.0) if not ligado else 2.0 * sin(t * 3.0))
	draw_circle(c, r + 5.0, Color(0, 0, 0, 0.55))
	draw_circle(c, r, Color(0.14, 0.11, 0.08, 0.92) if not ligado else Color(0.55, 0.38, 0.08, 0.95))
	draw_arc(c, r, 0.0, TAU, 40, Color(0.95, 0.78, 0.35), 4.0)
	var cor := Color(1.0, 0.92, 0.6)
	for k in 2:
		var y := c.y + 6.0 - k * 16.0
		draw_polyline(PackedVector2Array([Vector2(c.x - 16, y + 8), Vector2(c.x, y - 6), Vector2(c.x + 16, y + 8)]), cor, 6.0)
	var fonte := get_theme_default_font()
	var txt := "AUTO" if ligado else "TRAVAR"
	var w := fonte.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	draw_string_outline(fonte, Vector2(c.x - w * 0.5, c.y + r + 28), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 6, Color(0, 0, 0, 0.9))
	draw_string(fonte, Vector2(c.x - w * 0.5, c.y + r + 28), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, cor)

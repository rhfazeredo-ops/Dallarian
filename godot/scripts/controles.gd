# Controles: celular (joystick à esquerda, arrastar à direita para olhar, botões PULAR e ATACAR)
# e PC (WASD/setas, espaço pula, mouse olha e clique ataca).
extends Control
class_name Controles

var dir := Vector2.ZERO
var _olhar := Vector2.ZERO
var _pulo := false
var _ataque := false
var _dedo := -1; var _centro := Vector2.ZERO; var _ponta := Vector2.ZERO
var _dedo_olhar := -1
var fps: Label
const RAIO := 110.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_botao("ATACAR", -330, -300, 250, func(): _ataque = true)
	_botao("PULAR", -590, -200, 200, func(): _pulo = true)
	fps = Label.new(); fps.position = Vector2(24, 18); fps.add_theme_font_size_override("font_size", 30)
	fps.add_theme_color_override("font_outline_color", Color.BLACK); fps.add_theme_constant_override("outline_size", 8)
	add_child(fps)

func _botao(txt: String, x: float, y: float, t: float, f: Callable) -> void:
	var b := Button.new(); b.text = txt; b.add_theme_font_size_override("font_size", int(t * 0.17))
	b.anchor_left = 1; b.anchor_top = 1; b.anchor_right = 1; b.anchor_bottom = 1
	b.offset_left = x; b.offset_top = y; b.offset_right = x + t; b.offset_bottom = y + t
	var st := StyleBoxFlat.new(); st.bg_color = Color(0.12, 0.1, 0.16, 0.55); st.set_corner_radius_all(int(t / 2))
	st.border_color = Color(0.85, 0.75, 0.5, 0.8); st.set_border_width_all(4)
	for k in ["normal", "hover", "pressed", "focus"]: b.add_theme_stylebox_override(k, st)
	b.button_down.connect(f); add_child(b)

func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
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
func consumir_ataque() -> bool:
	var v := _ataque; _ataque = false; return v

func _draw() -> void:
	if _dedo == -1: return
	draw_circle(_centro, RAIO, Color(1, 0.95, 0.8, 0.15))
	draw_arc(_centro, RAIO, 0, TAU, 40, Color(0.9, 0.8, 0.55, 0.6), 4.0)
	draw_circle(_centro + (_ponta - _centro).limit_length(RAIO), 50, Color(1, 0.95, 0.8, 0.45))

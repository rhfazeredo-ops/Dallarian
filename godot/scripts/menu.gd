# Menu do jogo (botão no canto de cima à esquerda; PC: Esc): CONTINUAR e CONFIGURAÇÕES.
# Configurações → Gráfico: distância de visão (de 60 m até "tudo"). Com pouca distância o mundo some numa névoa
# branca (como no Minecraft) e o celular desenha muito menos coisa. A escolha fica salva no aparelho.
extends Control
class_name Menu

const ARQUIVO := "user://config.json"
const MIN_VISTA := 60.0
const MAX_VISTA := 270.0
var m
var aberto := false
var distancia := 270.0
var nitidez := 2              # a imagem 3D é desenhada em 1/nitidez da tela: 3 = leve, 2 = média, 1 = alta (tela cheia)
var pontilhado := false       # filtro retrô (paleta curta + pontilhado Bayer): desligado por padrão
var tremido := false          # vértices presos à grade de tela baixa (tremor do PS1): desligado por padrão
var _botao: BotaoAcao
var _painel: PanelContainer
var _conteudo: VBoxContainer
var _tecla_antes := false

func montar(mundo) -> void:
	m = mundo
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter = Control.MOUSE_FILTER_IGNORE
	_botao = BotaoAcao.criar("menu", 96)
	_botao.offset_left = 24; _botao.offset_right = 120; _botao.offset_top = 70; _botao.offset_bottom = 166
	_botao.process_mode = Node.PROCESS_MODE_ALWAYS
	_botao.apertou.connect(alternar); add_child(_botao)
	distancia = 180.0 if m.celular else MAX_VISTA
	nitidez = 2 if m.celular else 1
	_carregar()
	if m.args.has("nitidez"): nitidez = int(m.args.nitidez)
	if m.args.has("pontilhado"): pontilhado = true
	aplicar_distancia(distancia)
	m.aplicar_imagem(nitidez, pontilhado)
	pontilhado = false; tremido = false
	RenderingServer.global_shader_parameter_set("tremor_ps1", 0.0)

func _process(_d: float) -> void:
	var t := Input.is_key_pressed(KEY_ESCAPE)
	if t and not _tecla_antes: alternar()
	_tecla_antes = t

func alternar() -> void:
	if aberto: fechar()
	else: _abrir_principal()

func fechar() -> void:
	aberto = false
	if _painel: _painel.queue_free(); _painel = null
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().paused = false
	m.controles.set_process_input(true)

func _novo_painel(titulo: String) -> void:
	if _painel: _painel.queue_free()
	aberto = true; get_tree().paused = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	m.controles.set_process_input(false); m.controles.dir = Vector2.ZERO
	_painel = UI.janela(); _painel.process_mode = Node.PROCESS_MODE_ALWAYS; add_child(_painel)
	_conteudo = VBoxContainer.new(); _conteudo.add_theme_constant_override("separation", 22); _painel.add_child(_conteudo)
	var topo := HBoxContainer.new(); _conteudo.add_child(topo)
	var t := UI.rotulo(titulo, 40, UI.AMARELO); t.size_flags_horizontal = Control.SIZE_EXPAND_FILL; topo.add_child(t)
	topo.add_child(UI.botao_fechar(fechar))

func _centralizar() -> void:
	_painel.reset_size()
	var tam := _painel.get_combined_minimum_size()
	_painel.position = (get_viewport_rect().size - tam) * 0.5

func _abrir_principal() -> void:
	_novo_painel("Menu")
	for par in [["CONTINUAR", fechar], ["CONFIGURAÇÕES", _abrir_config]]:
		var b := UI.botao(par[0], par[1], true, 30, 460.0); b.custom_minimum_size.y = 80
		_conteudo.add_child(b)
	_centralizar()

func _abrir_config() -> void:
	_novo_painel("Configurações")
	_conteudo.add_child(UI.rotulo("Gráfico", 32, Color(1, 0.92, 0.75)))
	var linha := HBoxContainer.new(); linha.add_theme_constant_override("separation", 18); _conteudo.add_child(linha)
	linha.add_child(UI.rotulo("Distância de visão", 28))
	var valor := UI.rotulo("", 28, UI.AMARELO); valor.custom_minimum_size = Vector2(170, 0)
	valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var sl := HSlider.new(); sl.min_value = MIN_VISTA; sl.max_value = MAX_VISTA; sl.step = 10.0; sl.value = distancia
	sl.custom_minimum_size = Vector2(640, 60); sl.process_mode = Node.PROCESS_MODE_ALWAYS
	var grab := ImageTexture.create_from_image(_bolinha())
	sl.add_theme_icon_override("grabber", grab); sl.add_theme_icon_override("grabber_highlight", grab)
	var trilho := StyleBoxFlat.new(); trilho.bg_color = Color(0.25, 0.2, 0.14); trilho.set_corner_radius_all(6)
	trilho.content_margin_top = 8; trilho.content_margin_bottom = 8
	var cheio := StyleBoxFlat.new(); cheio.bg_color = UI.DOURADO; cheio.set_corner_radius_all(6); cheio.content_margin_top = 8; cheio.content_margin_bottom = 8
	sl.add_theme_stylebox_override("slider", trilho); sl.add_theme_stylebox_override("grabber_area", cheio); sl.add_theme_stylebox_override("grabber_area_highlight", cheio)
	var mostrar := func(v: float): valor.text = "Tudo" if v >= MAX_VISTA else "%d m" % int(v)
	mostrar.call(distancia)
	sl.value_changed.connect(func(v: float):
		mostrar.call(v); aplicar_distancia(v); _salvar())
	_conteudo.add_child(sl); linha.add_child(valor)
	var dica := UI.rotulo("Menos distância = jogo mais leve (o resto fica na névoa).", 22, Color(0.8, 0.78, 0.7))
	_conteudo.add_child(dica)
	# nitidez da imagem e filtro retrô
	_opcoes("Nitidez", [["LEVE", 3], ["MÉDIA", 2], ["ALTA", 1]], nitidez, func(v):
		nitidez = v; m.aplicar_imagem(nitidez, pontilhado); _salvar(); _abrir_config())
	_conteudo.add_child(UI.rotulo("Nitidez alta = imagem mais limpa, mas pesa mais no celular.", 22, Color(0.8, 0.78, 0.7)))
	var b := UI.botao("VOLTAR", _abrir_principal, true, 26, 220.0); _conteudo.add_child(b)
	_centralizar()

# linha com um título e botões de escolha (o escolhido fica aceso)
func _opcoes(titulo: String, ops: Array, atual: int, ao_escolher: Callable) -> void:
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 14); _conteudo.add_child(h)
	var t := UI.rotulo(titulo, 28); t.custom_minimum_size = Vector2(300, 0); h.add_child(t)
	for op in ops:
		var v: int = op[1]
		var b := UI.botao(op[0], func(): ao_escolher.call(v), true, 22, 170.0)
		b.process_mode = Node.PROCESS_MODE_ALWAYS
		b.modulate = Color(1, 1, 1) if v == atual else Color(0.55, 0.55, 0.55)
		h.add_child(b)

func _bolinha() -> Image:
	var im := Image.create(44, 44, false, Image.FORMAT_RGBA8); im.fill(Color(0, 0, 0, 0))
	for y in 44:
		for x in 44:
			var d := Vector2(x - 21.5, y - 21.5).length()
			if d < 20.0: im.set_pixel(x, y, Color(0.15, 0.1, 0.05) if d > 17.0 else Color(1.0, 0.85, 0.45))
	return im

# névoa: começa a 15% da distância e fecha nela; a câmera não desenha nada além (o celular agradece)
func aplicar_distancia(d: float) -> void:
	distancia = d
	var fim := d
	RenderingServer.global_shader_parameter_set("neb_fim", fim)
	RenderingServer.global_shader_parameter_set("neb_ini", minf(40.0, fim * 0.15))
	RenderingServer.global_shader_parameter_set("neblina_ceu", clampf((MAX_VISTA - d) / (MAX_VISTA - MIN_VISTA), 0.0, 1.0))
	if m.jogador and m.jogador.cam: m.jogador.cam.far = 900.0 if d >= MAX_VISTA else d + 10.0

func _salvar() -> void:
	var f := FileAccess.open(ARQUIVO, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify({"distancia": distancia, "nitidez_v2": nitidez, "pontilhado": pontilhado, "tremido": tremido}))

func _carregar() -> void:
	if m.args.has("shot") and not m.args.has("vista"): return
	if FileAccess.file_exists(ARQUIVO):
		var d = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO))
		if typeof(d) == TYPE_DICTIONARY:
			distancia = clampf(float(d.get("distancia", distancia)), MIN_VISTA, MAX_VISTA)
			nitidez = clampi(int(d.get("nitidez_v2", nitidez)), 1, 3)   # (o filtro PS1 saiu: pontilhado e tremido sempre desligados)
			tremido = bool(d.get("tremido", tremido))

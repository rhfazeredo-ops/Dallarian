# Seleção de heróis (como a tela de personagens do WoW): fundo do salão do castelo de Altamar, a heroína escolhida
# em pé no meio (girando devagar), a lista de heróis à direita e, embaixo à direita, CRIAR NOVO HERÓI e INICIAR
# JOGO. Por enquanto só existe a Rachel (o nível vem do save do aparelho); criar herói chega numa próxima tela.
extends Control
signal iniciar

const FUNDO := "res://assets/ui/selecao_fundo.png"
var _modelo: CorpoHeroi
var _sel := 0
var _cartoes: Array[PanelContainer] = []
var _aviso: Label
var _nome: Label
var _painel: PanelContainer
var _lista: Array = []

func _montar_lista(escolher := 0) -> void:
	for c in _painel.get_children(): c.queue_free()
	_cartoes.clear(); _lista = Herois.lista()
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 12); _painel.add_child(v)
	var tit := UI.rotulo("Vale de Aldren", 30, Color(1.0, 0.82, 0.3)); tit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(tit)
	for h in _lista:
		var c := PanelContainer.new(); c.mouse_filter = Control.MOUSE_FILTER_STOP; v.add_child(c); _cartoes.append(c)
		var cv := VBoxContainer.new(); cv.add_theme_constant_override("separation", 2); c.add_child(cv)
		cv.add_child(UI.rotulo(h.nome, 30, Color(1, 1, 1)))
		cv.add_child(UI.rotulo("Nível %d  %s" % [Herois.nivel(h), h.classe], 22, Color(0.95, 0.85, 0.6)))
		cv.add_child(UI.rotulo("Altamar", 20, Color(0.75, 0.75, 0.75)))
		var i := _cartoes.size() - 1
		c.gui_input.connect(func(e): if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed): _escolher(i))
	if not _lista.is_empty(): _escolher(clampi(escolher, 0, _lista.size() - 1))

func _abrir_criacao(primeira := false) -> void:
	var cr = load("res://scripts/criacao.gd").new(); cr.pode_voltar = not primeira; add_child(cr)
	cr.voltar.connect(func(): cr.queue_free())
	cr.pronto.connect(func(h: Dictionary):
		cr.queue_free(); _montar_lista(Herois.lista().size() - 1)
		pass)                   # volta para a seleção com o herói novo escolhido: só entra no jogo com INICIAR JOGO

func _ready() -> void:
	call_deferred("_primeira_vez")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# fundo: arte do salão do castelo (enquanto não chega, a arte de Altamar escurecida)
	var fundo := ColorRect.new(); fundo.color = Color(0.06, 0.05, 0.07); fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(fundo)
	var arq := FUNDO if ResourceLoader.exists(FUNDO) else "res://assets/ui/tela_inicio.png"
	if ResourceLoader.exists(arq):
		var img := TextureRect.new(); img.texture = load(arq)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(img)
		if arq != FUNDO:
			var sombra := ColorRect.new(); sombra.color = Color(0.05, 0.03, 0.08, 0.55); sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(sombra)
	# a heroína em 3D no meio
	var cont := SubViewportContainer.new(); cont.stretch = true; cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cont.anchor_left = 0.26; cont.anchor_right = 0.74; cont.anchor_top = 0.08; cont.anchor_bottom = 0.98; add_child(cont)
	var vp := SubViewport.new(); vp.transparent_bg = true; vp.own_world_3d = true; cont.add_child(vp)
	_modelo_pai = vp; _trocar_modelo(Herois.lista()[0] if not Herois.lista().is_empty() else Herois.RACHEL)
	var luz := DirectionalLight3D.new(); luz.rotation_degrees = Vector3(-25, 30, 0); luz.light_energy = 1.2; luz.light_color = Color(1.0, 0.9, 0.78); vp.add_child(luz)
	var amb := WorldEnvironment.new(); var env := Environment.new(); env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.72, 0.68, 0.8); env.ambient_light_energy = 0.85
	amb.environment = env; vp.add_child(amb)
	var cam := Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = 1.95
	cam.position = Vector3(0.0, 0.86, 3.0); vp.add_child(cam); cam.current = true
	# nome embaixo da heroína
	_nome = UI.rotulo("Rachel", 34, Color(1.0, 0.82, 0.3)); _nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nome.anchor_left = 0.28; _nome.anchor_right = 0.66; _nome.anchor_top = 0.9; _nome.anchor_bottom = 0.96; add_child(_nome)
	# lista de heróis (direita)
	_painel = UI.janela(); var painel := _painel; painel.anchor_left = 1; painel.anchor_right = 1
	painel.offset_left = -470; painel.offset_right = -30; painel.offset_top = 30; add_child(painel)
	_montar_lista()
	# botões embaixo à direita
	var b := VBoxContainer.new(); b.add_theme_constant_override("separation", 14); b.alignment = BoxContainer.ALIGNMENT_END
	b.anchor_left = 1; b.anchor_right = 1; b.anchor_top = 1; b.anchor_bottom = 1
	b.offset_left = -470; b.offset_right = -30; b.offset_top = -220; b.offset_bottom = -30; add_child(b)
	b.add_child(UI.botao("CRIAR NOVO HERÓI", _abrir_criacao, true, 26, 440.0))
	var ini := UI.botao("INICIAR JOGO", func(): (_abrir_criacao(true) if _lista.is_empty() else (func(): Herois.ativo = _lista[_sel]; iniciar.emit()).call()), true, 34, 440.0); ini.custom_minimum_size.y = 84; b.add_child(ini)
	_aviso = UI.rotulo("", 24, Color(1.0, 0.85, 0.4)); _aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.anchor_left = 0.28; _aviso.anchor_right = 0.66; _aviso.anchor_top = 0.04; _aviso.anchor_bottom = 0.1; add_child(_aviso)

var _modelo_pai: Node
var _modelo_arq := ""
func _trocar_modelo(h: Dictionary) -> void:
	var arq := Herois.modelo(h)
	if arq == _modelo_arq or _modelo_pai == null: return
	_modelo_arq = arq
	if _modelo: _modelo.queue_free()
	var c := CorpoHeroi.new(); _modelo_pai.add_child(c); c.montar(null, arq, false); _modelo = c

func _escolher(i: int) -> void:
	_sel = i
	if i < _lista.size(): _trocar_modelo(_lista[i])
	if _nome and i < _lista.size(): _nome.text = String(_lista[i].nome)
	for k in _cartoes.size():
		var sel := k == i
		_cartoes[k].add_theme_stylebox_override("panel", UI.estilo(Color(0.35, 0.22, 0.06, 0.9) if sel else Color(0.08, 0.07, 0.06, 0.85),
			Color(1.0, 0.82, 0.3) if sel else UI.DOURADO, 8, 14, 3 if sel else 2))

func _process(delta: float) -> void:
	if _modelo:                                     # de frente, virando devagar de um lado para o outro, respirando
		_modelo.giro_teste = PI + sin(Time.get_ticks_msec() / 1000.0 * 0.6) * 0.35
		_modelo.j._tempo = Time.get_ticks_msec() / 1000.0; _modelo.animar(get_process_delta_time())

# sem nenhum herói salvo (jogo novo): abre direto a criação, que é obrigatória
func _primeira_vez() -> void:
	if Herois.lista().is_empty(): _abrir_criacao(true)

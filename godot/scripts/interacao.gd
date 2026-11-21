# Interação com NPCs: chegando perto do ferreiro aparecem os botões CRIAR e CONVERSAR (PC: F conversa).
# CONVERSAR abre uma caixa de fala com o nome e uma frase; o ferreiro para de bater, vira para a Dallarian e
# gesticula enquanto fala. CRIAR ainda não funciona (mostra "em breve").
extends Control
class_name Interacao

const ALCANCE := 4.0
var m
var npc: Morador = null           # com quem dá para interagir agora
var painel: HBoxContainer
var caixa: PanelContainer
var nome_lbl: Label
var fala_lbl: Label
var aviso: Label
var _falando := false
var _f_antes := false
# diálogos: lista de falas [quem, texto, áudio (ou "")]; quem = "heroina" ou "ferreiro"
const NOME_HEROINA := "Rachel"
const DIALOGOS_FERREIRO := [
	[["heroina", "Bom dia, mestre ferreiro. Que barulho bonito esse do martelo.", "res://assets/voz/heroina_01.ogg"],
	 ["ferreiro", "Ferro quente não espera ninguém, garota. Se quer ser cavaleira, comece aprendendo que toda boa lâmina nasceu de mil marteladas.", "res://assets/voz/ferreiro_01.ogg"]],
	[["heroina", "Um dia vou ter uma espada digna de um cavaleiro. Você faria uma pra mim?", "res://assets/voz/heroina_02.ogg"],
	 ["ferreiro", "Uma espada não faz o cavaleiro... mas um cavaleiro sem uma boa espada vira história curta. Volte quando tiver moedas.", "res://assets/voz/ferreiro_02.ogg"]],
	[["heroina", "Como você sabe quando uma lâmina está pronta?", "res://assets/voz/heroina_03.ogg"],
	 ["ferreiro", "Escuta o som do martelo? Quando ele canta limpo, o aço está pronto. Quando ele chia, alguém vai morrer com essa lâmina.", "res://assets/voz/ferreiro_03.ogg"]],
]
# falas soltas do Bram: quando a Dallarian chega perto e quando vai embora (legenda pequena + voz 3D)
const CHEGA := [["Cuidado com as faíscas!", "res://assets/voz/ferreiro_chega_01.ogg"],
	["Precisa de alguma coisa? Fala logo, o ferro tá esfriando.", "res://assets/voz/ferreiro_chega_02.ogg"]]
const TCHAU := ["Vai com os deuses... e com um bom aço.", "res://assets/voz/ferreiro_tchau_01.ogg"]
var _chega_i := 0
var _ultima_solta := -100.0
var _conversou := false
var legenda: Label
var _dialogo: Array = []
var _fala := 0
var _tempo_fala := 0.0
var voz: AudioStreamPlayer
var _fala_i := 0
# barraca: botão DESCANSAR (dorme até as 6h da manhã)
var painel_barraca: Control
var escuro: ColorRect
var _dormindo := false

func montar(mundo) -> void:
	m = mundo
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter = Control.MOUSE_FILTER_IGNORE
	painel = HBoxContainer.new(); painel.add_theme_constant_override("separation", 26)
	painel.anchor_left = 0.5; painel.anchor_right = 0.5; painel.anchor_top = 1; painel.anchor_bottom = 1
	painel.offset_left = -250; painel.offset_right = 250; painel.offset_top = -380; painel.offset_bottom = -210
	add_child(painel)
	painel.add_child(_botao("CRIAR", false, func(): _aviso("A forja ainda está esfriando... em breve.")))
	painel.add_child(_botao("LOJA", true, _abrir_loja))
	painel.add_child(_botao("CONVERSAR", true, _conversar))
	painel.visible = false
	painel_barraca = _botao("DESCANSAR", true, _descansar)
	painel_barraca.anchor_left = 0.5; painel_barraca.anchor_right = 0.5; painel_barraca.anchor_top = 1; painel_barraca.anchor_bottom = 1
	painel_barraca.offset_left = -75; painel_barraca.offset_right = 75; painel_barraca.offset_top = -380; painel_barraca.offset_bottom = -210
	painel_barraca.visible = false; add_child(painel_barraca)
	escuro = ColorRect.new(); escuro.color = Color(0, 0, 0, 1); escuro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	escuro.mouse_filter = Control.MOUSE_FILTER_IGNORE; escuro.modulate.a = 0.0; escuro.visible = false; add_child(escuro)
	# caixa de fala
	caixa = PanelContainer.new()
	var st := StyleBoxFlat.new(); st.bg_color = Color(0.1, 0.08, 0.07, 0.88); st.set_corner_radius_all(14)
	st.border_color = Color(0.85, 0.7, 0.42); st.set_border_width_all(4)
	st.content_margin_left = 34; st.content_margin_right = 34; st.content_margin_top = 20; st.content_margin_bottom = 24
	caixa.add_theme_stylebox_override("panel", st)
	caixa.anchor_left = 0.5; caixa.anchor_right = 0.5; caixa.anchor_top = 1; caixa.anchor_bottom = 1
	caixa.offset_left = -620; caixa.offset_right = 620; caixa.offset_top = -330; caixa.offset_bottom = -110
	var v := VBoxContainer.new(); caixa.add_child(v)
	nome_lbl = Label.new(); nome_lbl.add_theme_font_size_override("font_size", 36); nome_lbl.add_theme_color_override("font_color", Color(0.98, 0.8, 0.42))
	fala_lbl = Label.new(); fala_lbl.add_theme_font_size_override("font_size", 32); fala_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fala_lbl.custom_minimum_size = Vector2(1100, 0)
	var dica := Label.new(); dica.text = "toque para continuar"; dica.add_theme_font_size_override("font_size", 22); dica.add_theme_color_override("font_color", Color(0.7, 0.65, 0.58))
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(nome_lbl); v.add_child(fala_lbl); v.add_child(dica)
	caixa.gui_input.connect(func(e): if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed: _avancar())
	caixa.visible = false; add_child(caixa)
	aviso = Label.new(); aviso.add_theme_font_size_override("font_size", 30); aviso.add_theme_constant_override("outline_size", 8)
	aviso.add_theme_color_override("font_outline_color", Color.BLACK); aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aviso.anchor_left = 0.5; aviso.anchor_right = 0.5; aviso.anchor_top = 1; aviso.anchor_bottom = 1
	aviso.offset_left = -500; aviso.offset_right = 500; aviso.offset_top = -400; aviso.offset_bottom = -350
	aviso.modulate.a = 0.0; add_child(aviso)
	voz = AudioStreamPlayer.new(); voz.volume_db = 0.0; voz.bus = "Voz"; add_child(voz)
	legenda = Label.new(); legenda.add_theme_font_size_override("font_size", 30); legenda.add_theme_constant_override("outline_size", 9)
	legenda.add_theme_color_override("font_outline_color", Color.BLACK); legenda.add_theme_color_override("font_color", Color(1.0, 0.86, 0.55))
	legenda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; legenda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legenda.anchor_left = 0.5; legenda.anchor_right = 0.5; legenda.anchor_top = 1; legenda.anchor_bottom = 1
	legenda.offset_left = -560; legenda.offset_right = 560; legenda.offset_top = -470; legenda.offset_bottom = -350
	legenda.modulate.a = 0.0; add_child(legenda)

func _botao(txt: String, ativo: bool, f: Callable) -> Control:
	var caixa_b := VBoxContainer.new(); caixa_b.alignment = BoxContainer.ALIGNMENT_CENTER
	var b := BotaoAcao.criar({"LOJA": "inventario"}.get(txt, txt.to_lower()), 132)
	b.ativo = ativo; b.apertou.connect(f)
	var cont := CenterContainer.new(); cont.custom_minimum_size = Vector2(150, 132); cont.add_child(b)
	var l := Label.new(); l.text = txt; l.add_theme_font_size_override("font_size", 24); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Color(1, 0.9, 0.65) if ativo else Color(0.7, 0.67, 0.62))
	l.add_theme_constant_override("outline_size", 7); l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	caixa_b.add_child(cont); caixa_b.add_child(l)
	return caixa_b

# ---------- loja do ferreiro: ele compra os itens da Rachel ----------
var loja: PanelContainer
var _loja_lista: VBoxContainer
var _loja_dinheiro: HBoxContainer
const FALAS_LOJA := ["Dente de lobo dá bom cabo de faca. Pago justo.", "Garra afiada assim? Isso eu compro.", "Hm... cobre por cobre, negócio fechado."]

func _abrir_loja() -> void:
	if npc == null: return
	if loja == null: _montar_loja()
	_falando = false; painel.visible = false; caixa.visible = false
	loja.visible = true; _atualizar_loja()
	m.controles.set_process_input(false); m.controles.dir = Vector2.ZERO
	npc.falando_com = m.jogador; npc.gesticula = true

func _fechar_loja() -> void:
	if loja: loja.visible = false
	m.controles.set_process_input(true)
	if npc: npc.falando_com = null

func _estilo(cor_fundo: Color, borda: Color, raio := 14) -> StyleBoxFlat:
	var st := StyleBoxFlat.new(); st.bg_color = cor_fundo; st.set_corner_radius_all(raio)
	st.border_color = borda; st.set_border_width_all(4)
	st.content_margin_left = 30; st.content_margin_right = 30; st.content_margin_top = 20; st.content_margin_bottom = 22
	return st

func _rotulo(t: String, tam: int, cor := Color(1, 0.92, 0.75)) -> Label:
	var l := Label.new(); l.text = t; l.add_theme_font_size_override("font_size", tam); l.add_theme_color_override("font_color", cor)
	return l

func _botao_texto(t: String, f: Callable, ativo := true) -> Button:
	var b := Button.new(); b.text = t; b.add_theme_font_size_override("font_size", 26); b.custom_minimum_size = Vector2(190, 64)
	b.add_theme_stylebox_override("normal", _estilo(Color(0.32, 0.22, 0.12), Color(0.85, 0.7, 0.42), 10))
	b.add_theme_stylebox_override("hover", _estilo(Color(0.42, 0.3, 0.16), Color(1.0, 0.85, 0.5), 10))
	b.add_theme_stylebox_override("pressed", _estilo(Color(0.22, 0.15, 0.08), Color(1.0, 0.85, 0.5), 10))
	b.add_theme_stylebox_override("disabled", _estilo(Color(0.2, 0.18, 0.16), Color(0.45, 0.4, 0.35), 10))
	b.add_theme_color_override("font_color", Color(1, 0.92, 0.72)); b.disabled = not ativo
	b.pressed.connect(f); return b

func _montar_loja() -> void:
	loja = PanelContainer.new(); loja.add_theme_stylebox_override("panel", _estilo(Color(0.1, 0.08, 0.07, 0.94), Color(0.85, 0.7, 0.42)))
	loja.anchor_left = 0.5; loja.anchor_right = 0.5; loja.anchor_top = 0.5; loja.anchor_bottom = 0.5
	loja.offset_left = -560; loja.offset_right = 560; loja.offset_top = -330; loja.offset_bottom = 330
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 16); loja.add_child(v)
	var topo := HBoxContainer.new(); v.add_child(topo)
	var titulo := _rotulo("Loja do Bram — vender", 40, Color(0.98, 0.8, 0.42)); titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(titulo); topo.add_child(_botao_texto("FECHAR", _fechar_loja))
	_loja_dinheiro = HBoxContainer.new(); _loja_dinheiro.add_theme_constant_override("separation", 10); v.add_child(_loja_dinheiro)
	var sep := HSeparator.new(); v.add_child(sep)
	var rolar := ScrollContainer.new(); rolar.size_flags_vertical = Control.SIZE_EXPAND_FILL; v.add_child(rolar)
	_loja_lista = VBoxContainer.new(); _loja_lista.add_theme_constant_override("separation", 12)
	_loja_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL; rolar.add_child(_loja_lista)
	loja.visible = false; add_child(loja)

# moeda desenhada (círculo com borda) + número
func _moeda(qtd: int, cor: Color) -> Control:
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 6)
	var c := Control.new(); c.custom_minimum_size = Vector2(30, 30)
	c.draw.connect(func():
		c.draw_circle(Vector2(15, 17), 13.0, cor * 0.6)
		c.draw_circle(Vector2(15, 15), 12.0, cor)
		c.draw_circle(Vector2(12, 12), 4.0, cor.lightened(0.45)))
	h.add_child(c); h.add_child(_rotulo(str(qtd), 30)); return h

func _atualizar_loja() -> void:
	for c in _loja_dinheiro.get_children(): c.queue_free()
	for c in _loja_lista.get_children(): c.queue_free()
	var mo: Array = Bolsa.moedas(m.bolsa.cobre)
	_loja_dinheiro.add_child(_rotulo("Seu dinheiro:", 30))
	_loja_dinheiro.add_child(_moeda(mo[0], Color(1.0, 0.8, 0.25)))
	_loja_dinheiro.add_child(_moeda(mo[1], Color(0.82, 0.84, 0.88)))
	_loja_dinheiro.add_child(_moeda(mo[2], Color(0.78, 0.45, 0.22)))
	if m.bolsa.itens.is_empty():
		_loja_lista.add_child(_rotulo("Você não tem nada para vender. Cace uns lobos e volte aqui.", 28, Color(0.75, 0.7, 0.62)))
		return
	for id in m.bolsa.itens.keys():
		var info: Array = Bolsa.ITENS[id]; var qtd: int = m.bolsa.itens[id]
		var linha := HBoxContainer.new(); linha.add_theme_constant_override("separation", 16)
		var nome := _rotulo("%s  ×%d" % [info[0], qtd], 30); nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		linha.add_child(nome)
		linha.add_child(_rotulo("%s cada" % Bolsa.texto_dinheiro(info[1]), 26, Color(0.85, 0.75, 0.55)))
		linha.add_child(_botao_texto("VENDER 1", func(): _vender(id, 1)))
		linha.add_child(_botao_texto("VENDER TODOS", func(): _vender(id, 9999)))
		_loja_lista.add_child(linha)

func _vender(id: String, qtd: int) -> void:
	var ganho: int = m.bolsa.vender(id, qtd)
	if ganho > 0:
		m.hud.avisar("+%s" % Bolsa.texto_dinheiro(ganho), Color(0.95, 0.7, 0.4))
		_fala_bram(FALAS_LOJA[randi() % FALAS_LOJA.size()])
	_atualizar_loja()

func _fala_bram(t: String) -> void:
	legenda.text = "Bram: " + t; legenda.modulate.a = 1.0; move_child(legenda, get_child_count() - 1)
	var tw := legenda.create_tween(); tw.tween_interval(2.5); tw.tween_property(legenda, "modulate:a", 0.0, 0.5)

# descansar na barraca: tela escurece, o tempo passa até as 6h e amanhece
func _descansar() -> void:
	if _dormindo: return
	_dormindo = true; painel_barraca.visible = false
	escuro.visible = true; move_child(escuro, get_child_count() - 1)
	var tw := create_tween()
	tw.tween_property(escuro, "modulate:a", 1.0, 1.2)
	tw.tween_callback(func():
		m.hora = 6.0
		aviso.text = "Rachel descansou até o amanhecer."; aviso.modulate.a = 1.0
		move_child(aviso, get_child_count() - 1))
	tw.tween_interval(1.6)
	tw.tween_property(escuro, "modulate:a", 0.0, 1.4)
	tw.parallel().tween_property(aviso, "modulate:a", 0.0, 1.4).set_delay(0.8)
	tw.tween_callback(func(): escuro.visible = false; _dormindo = false)

func perto_da_barraca() -> bool:
	var pj: Vector3 = m.jogador.global_position
	for b in m.barracas:
		if Vector2(pj.x - b.x, pj.z - b.y).length() < 4.5: return true
	return false

func _aviso(t: String) -> void:
	aviso.text = t; aviso.modulate.a = 1.0
	var tw := aviso.create_tween(); tw.tween_interval(1.8); tw.tween_property(aviso, "modulate:a", 0.0, 0.5)

# fala solta (sem abrir a caixa): legenda curta embaixo e a voz
func _fala_solta(f: Array, sempre := false) -> void:
	if _falando or (not sempre and m._tempo_jogo() - _ultima_solta < 12.0): return
	_ultima_solta = m._tempo_jogo()
	legenda.text = "Bram: " + f[0]; legenda.modulate.a = 1.0
	voz.stream = load(f[1]); voz.play()
	var tw := legenda.create_tween(); tw.tween_interval(voz.stream.get_length() + 0.8); tw.tween_property(legenda, "modulate:a", 0.0, 0.5)

func _conversar() -> void:
	if npc == null: return
	_conversou = true; legenda.modulate.a = 0.0
	_falando = true; painel.visible = false
	_dialogo = DIALOGOS_FERREIRO[_fala_i % DIALOGOS_FERREIRO.size()]; _fala_i += 1
	_fala = 0; caixa.visible = true
	npc.falando_com = m.jogador
	_mostrar_fala()

# mostra a fala atual (legenda + voz); sem voz, fica o tempo de leitura
func _mostrar_fala() -> void:
	var f: Array = _dialogo[_fala]
	nome_lbl.text = NOME_HEROINA if f[0] == "heroina" else "Bram, o ferreiro"
	nome_lbl.add_theme_color_override("font_color", Color(0.62, 0.82, 1.0) if f[0] == "heroina" else Color(0.98, 0.8, 0.42))
	fala_lbl.text = f[1]
	if npc: npc.gesticula = f[0] == "ferreiro"
	voz.stop()
	if f[2] != "" and ResourceLoader.exists(f[2]):
		voz.stream = load(f[2]); voz.play(); _tempo_fala = voz.stream.get_length() + 0.6
	else:
		_tempo_fala = 1.5 + f[1].length() * 0.055

func _avancar() -> void:
	_fala += 1
	if _fala >= _dialogo.size(): _fechar()
	else: _mostrar_fala()

func _fechar() -> void:
	caixa.visible = false; _falando = false; voz.stop()
	if npc: npc.falando_com = null; npc.gesticula = true

func _process(_d: float) -> void:
	if m == null or m.jogador == null: return
	var perto: Morador = null
	for mo in m.raiz.get_children():
		if mo is Morador and mo.profissao == "ferreiro" and mo.global_position.distance_to(m.jogador.global_position) < ALCANCE:
			perto = mo
	if perto != npc:
		if npc and _falando: _fechar()
		if loja and loja.visible: _fechar_loja()
		if perto != null and npc == null:
			_conversou = false
			_fala_solta(CHEGA[_chega_i % CHEGA.size()]); _chega_i += 1
		elif perto == null and npc != null and _conversou:
			_fala_solta(TCHAU, true)
		npc = perto
	painel.visible = npc != null and not _falando and not (loja != null and loja.visible)
	var na_barraca := perto_da_barraca() and not _dormindo
	painel_barraca.visible = na_barraca and npc == null
	Audio.falando = _falando and voz.playing
	if _falando:
		_tempo_fala -= _d
		if _tempo_fala <= 0.0: _avancar()          # passa sozinho quando a fala termina
	var f := Input.is_key_pressed(KEY_F)
	if f and not _f_antes:
		if _falando: _avancar()
		elif npc: _conversar()
		elif na_barraca: _descansar()
	_f_antes = f

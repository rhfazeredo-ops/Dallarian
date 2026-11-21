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
const FALAS_FERREIRO := [
	"Ferro quente não espera ninguém, garota. Se quer ser cavaleira, comece aprendendo que toda boa lâmina nasceu de mil marteladas.",
	"Uma espada não faz o cavaleiro... mas um cavaleiro sem uma boa espada vira história curta. Volte quando tiver moedas.",
	"Escuta o som do martelo? Quando ele canta limpo, o aço está pronto. Quando ele chia, alguém vai morrer com essa lâmina.",
]
var _fala_i := 0

func montar(mundo) -> void:
	m = mundo
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter = Control.MOUSE_FILTER_IGNORE
	painel = HBoxContainer.new(); painel.add_theme_constant_override("separation", 26)
	painel.anchor_left = 0.5; painel.anchor_right = 0.5; painel.anchor_top = 1; painel.anchor_bottom = 1
	painel.offset_left = -330; painel.offset_right = 330; painel.offset_top = -330; painel.offset_bottom = -230
	add_child(painel)
	painel.add_child(_botao("CRIAR", false, func(): _aviso("A forja ainda está esfriando... em breve.")))
	painel.add_child(_botao("CONVERSAR", true, _conversar))
	painel.visible = false
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
	var dica := Label.new(); dica.text = "toque para fechar"; dica.add_theme_font_size_override("font_size", 22); dica.add_theme_color_override("font_color", Color(0.7, 0.65, 0.58))
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(nome_lbl); v.add_child(fala_lbl); v.add_child(dica)
	caixa.gui_input.connect(func(e): if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed: _fechar())
	caixa.visible = false; add_child(caixa)
	aviso = Label.new(); aviso.add_theme_font_size_override("font_size", 30); aviso.add_theme_constant_override("outline_size", 8)
	aviso.add_theme_color_override("font_outline_color", Color.BLACK); aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aviso.anchor_left = 0.5; aviso.anchor_right = 0.5; aviso.anchor_top = 1; aviso.anchor_bottom = 1
	aviso.offset_left = -500; aviso.offset_right = 500; aviso.offset_top = -400; aviso.offset_bottom = -350
	aviso.modulate.a = 0.0; add_child(aviso)

func _botao(txt: String, ativo: bool, f: Callable) -> Button:
	var b := Button.new(); b.text = txt; b.add_theme_font_size_override("font_size", 34)
	b.custom_minimum_size = Vector2(300, 96)
	var st := StyleBoxFlat.new(); st.set_corner_radius_all(48); st.set_border_width_all(4)
	st.bg_color = Color(0.16, 0.12, 0.1, 0.85) if ativo else Color(0.16, 0.14, 0.13, 0.6)
	st.border_color = Color(0.9, 0.72, 0.4) if ativo else Color(0.5, 0.46, 0.42)
	for k in ["normal", "hover", "pressed", "focus"]: b.add_theme_stylebox_override(k, st)
	if not ativo: b.add_theme_color_override("font_color", Color(0.65, 0.62, 0.58))
	b.pressed.connect(f); return b

func _aviso(t: String) -> void:
	aviso.text = t; aviso.modulate.a = 1.0
	var tw := aviso.create_tween(); tw.tween_interval(1.8); tw.tween_property(aviso, "modulate:a", 0.0, 0.5)

func _conversar() -> void:
	if npc == null: return
	_falando = true; painel.visible = false
	nome_lbl.text = "Bram, o ferreiro"
	fala_lbl.text = FALAS_FERREIRO[_fala_i % FALAS_FERREIRO.size()]; _fala_i += 1
	caixa.visible = true
	npc.falando_com = m.jogador

func _fechar() -> void:
	caixa.visible = false; _falando = false
	if npc: npc.falando_com = null

func _process(_d: float) -> void:
	if m == null or m.jogador == null: return
	var perto: Morador = null
	for mo in m.raiz.get_children():
		if mo is Morador and mo.profissao == "ferreiro" and mo.global_position.distance_to(m.jogador.global_position) < ALCANCE:
			perto = mo
	if perto != npc:
		if npc and _falando: _fechar()
		npc = perto
	painel.visible = npc != null and not _falando
	var f := Input.is_key_pressed(KEY_F)
	if f and not _f_antes:
		if _falando: _fechar()
		elif npc: _conversar()
	_f_antes = f

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
# arbusto de frutinhas: botão COLETAR (PC: F)
var painel_coletar: Control
var _baga: Array = []
# estábulo de Altamar: o cavalariço vende os cavalos (LOJA) e conversa
var painel_estabulo: HBoxContainer
const DIALOGOS_CAVALARICO := [
	[["heroina", "Que cavalos bonitos! Eles estão à venda?", ""],
	 ["cavalarico", "Os melhores do Vale de Aldren, moça. Oitenta de cobre cada um, com sela e tudo. Um cavalo te leva longe antes do lobo te alcançar.", ""]],
	[["heroina", "Qual deles você escolheria?", ""],
	 ["cavalarico", "O branco é manso, o marrom aguenta qualquer estrada e o preto... o preto corre como se o vento devesse dinheiro a ele.", ""]],
	[["heroina", "Como eu chamo o cavalo quando estiver na estrada?", ""],
	 ["cavalarico", "Um bom cavalo sempre ouve o assobio da dona. Assobia e ele vem. Assobia de novo e ele volta pro pasto.", ""]],
]
const LOJA_ESTABULO := {"nome": "Edric", "cargo": "<Cavalariço>", "itens": ["cavalo_branco", "cavalo_marrom", "cavalo_preto", "cavalo_dourado"],
	"falas_compra": ["Trate bem dele, que ele trata bem de você.", "Escolha boa! Esse aí não refuga estrada."],
	"falas_venda": ["Hum, isso eu revendo na cidade.", "Fechado. Cobre na mão."]}
# freiras (Irmã Celina na vila, Irmã Odília na catedral): vendem poções de vida
const DIALOGOS_FREIRA := [
	[["heroina", "Bom dia, irmã. A senhora cuida de quem chega ferido?", ""],
	 ["freira", "Que a luz te guarde, minha filha. Cuido, sim. Quem volta da mata com mordida de lobo sempre encontra um banco e uma poção aqui.", ""]],
	[["heroina", "Essas poções são feitas de quê?", ""],
	 ["freira", "Ervas do horto, mel das nossas abelhas e água da fonte benta. E muita reza enquanto ferve, que ninguém é de ferro.", ""]],
	[["heroina", "A senhora não tem medo de ficar aqui fora sozinha?", ""],
	 ["freira", "Medo eu tenho é de quem sai sem levar uma poção na bolsa. Vai com Deus, e volta inteira.", ""]],
]
const LOJA_FREIRA := {"cargo": "<Irmã de caridade>", "itens": ["pocao_p", "pocao_m", "pocao_g"],
	"falas_compra": ["Que te faça bem, minha filha.", "Beba devagar, que cura melhor.", "A luz te acompanhe na estrada."],
	"falas_venda": ["Tudo serve para os pobres do vale.", "Deus lhe pague."]}
var _tipo_npc := ""
var _ferreiros := []
var _t_baga := 0.0               # "ferreiro" ou "cavalarico"

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
	painel_estabulo = HBoxContainer.new(); painel_estabulo.add_theme_constant_override("separation", 26)
	painel_estabulo.anchor_left = 0.5; painel_estabulo.anchor_right = 0.5; painel_estabulo.anchor_top = 1; painel_estabulo.anchor_bottom = 1
	painel_estabulo.offset_left = -165; painel_estabulo.offset_right = 165; painel_estabulo.offset_top = -380; painel_estabulo.offset_bottom = -210
	add_child(painel_estabulo)
	painel_estabulo.add_child(_botao("LOJA", true, _abrir_loja))
	painel_estabulo.add_child(_botao("CONVERSAR", true, _conversar))
	painel_estabulo.visible = false
	painel_barraca = _botao("DESCANSAR", true, _descansar)
	painel_barraca.anchor_left = 0.5; painel_barraca.anchor_right = 0.5; painel_barraca.anchor_top = 1; painel_barraca.anchor_bottom = 1
	painel_barraca.offset_left = -75; painel_barraca.offset_right = 75; painel_barraca.offset_top = -380; painel_barraca.offset_bottom = -210
	painel_barraca.visible = false; add_child(painel_barraca)
	painel_coletar = _botao("COLETAR", true, _coletar)
	painel_coletar.anchor_left = 0.5; painel_coletar.anchor_right = 0.5; painel_coletar.anchor_top = 1; painel_coletar.anchor_bottom = 1
	painel_coletar.offset_left = -75; painel_coletar.offset_right = 75; painel_coletar.offset_top = -380; painel_coletar.offset_bottom = -210
	painel_coletar.visible = false; add_child(painel_coletar)
	for par in [["ENTRAR", true], ["SAIR", false]]:                      # portas dos interiores
		var b := _botao(par[0], true, func(): _usar_porta(par[1]))
		b.anchor_left = 0.5; b.anchor_right = 0.5; b.anchor_top = 1; b.anchor_bottom = 1
		b.offset_left = -75; b.offset_right = 75; b.offset_top = -380; b.offset_bottom = -210
		b.visible = false; add_child(b)
		if par[1]: botao_entrar = b
		else: botao_sair = b
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
	var dica := Label.new(); dica.text = ""; dica.add_theme_font_size_override("font_size", 22); dica.add_theme_color_override("font_color", Color(0.7, 0.65, 0.58))
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(nome_lbl); v.add_child(fala_lbl); v.add_child(dica)
	# tocar na caixa nunca corta a fala: só passa adiante depois que a voz da fala atual terminou
	caixa.gui_input.connect(func(e): if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed: _tocar_caixa())
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
	var b := BotaoAcao.criar(txt.to_lower(), 132)
	b.ativo = ativo; b.apertou.connect(f)
	var cont := CenterContainer.new(); cont.custom_minimum_size = Vector2(150, 132); cont.add_child(b)
	var l := Label.new(); l.text = txt; l.add_theme_font_size_override("font_size", 24); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Color(1, 0.9, 0.65) if ativo else Color(0.7, 0.67, 0.62))
	l.add_theme_constant_override("outline_size", 7); l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	caixa_b.add_child(cont); caixa_b.add_child(l)
	return caixa_b

# ---------- loja do ferreiro (janela de vendedor em loja.gd) ----------
func _abrir_loja() -> void:
	if npc == null: return
	_falando = false; painel.visible = false; caixa.visible = false
	if _tipo_npc == "cavalarico":
		var c := LOJA_ESTABULO.duplicate(); c["retrato"] = load("res://assets/ui/itens/cavalo_marrom.png")
		m.loja_ui.abrir(npc, c)
	elif _tipo_npc == "vendedor":
		var it: Array = npc.get_meta("itens", [])
		var c := {"nome": String(npc.get_meta("nome", "")) + " — " + String(npc.get_meta("loja", "")), "cargo": String(npc.get_meta("cargo", "")),
			"itens": it, "falas_compra": ["Volte sempre!", "Ótima escolha."], "falas_venda": ["Hum, serve. Fechado."]}
		c["retrato"] = load("res://assets/ui/itens/pocao_m.png")
		m.loja_ui.abrir(npc, c)
		if it.is_empty(): _aviso("As prateleiras ainda estão vazias... volte em breve!")
	elif _tipo_npc == "freira":
		var c := LOJA_FREIRA.duplicate(); c["retrato"] = load("res://assets/ui/itens/pocao_m.png"); c["nome"] = String(npc.get_meta("nome", "Irmã"))
		m.loja_ui.abrir(npc, c)
	else: m.loja_ui.abrir(npc)

func _fala_npc(quem: String, t: String) -> void:
	legenda.text = quem + ": " + t; legenda.modulate.a = 1.0; move_child(legenda, get_child_count() - 1)
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

# colhe o arbusto de frutinhas mais perto: 1 a 3 frutinhas para a bolsa; o arbusto fica sem frutinhas por 5 min
func _coletar() -> void:
	if _baga.is_empty() or m.floresta == null: return
	var n := randi_range(1, 3)
	var sobra: int = m.bolsa.pegar("frutinhas", n)
	if n - sobra <= 0: m.hud.avisar("Suas bolsas estão cheias!", Color(1, 0.35, 0.3)); return
	m.floresta.colher(_baga); _baga = []
	m.hud.avisar("+%d %s" % [n - sobra, Bolsa.ITENS["frutinhas"].nome], Color(1, 1, 1))

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
	var lista: Array = DIALOGOS_CAVALARICO if _tipo_npc == "cavalarico" else (DIALOGOS_FREIRA if _tipo_npc == "freira" else (_dialogos_vendedor() if _tipo_npc == "vendedor" else DIALOGOS_FERREIRO))
	_dialogo = lista[_fala_i % lista.size()]; _fala_i += 1
	_fala = 0; caixa.visible = true
	npc.falando_com = m.jogador
	_mostrar_fala()

func _dialogos_vendedor() -> Array:
	var loja := String(npc.get_meta("loja", "minha loja"))
	return [
		[["heroina", "Bom dia! O que o senhor vende aqui?", ""], ["vendedor", "Bem-vinda à %s! As mercadorias novas estão chegando de navio, logo, logo as prateleiras enchem." % loja, ""]],
		[["heroina", "Como andam os negócios em Altamar?", ""], ["vendedor", "Com a praça cheia assim, não posso reclamar. Só os lobos da estrada é que espantam os mercadores de fora.", ""]],
		[["heroina", "Volto mais tarde, então.", ""], ["vendedor", "Volte mesmo! E diga aos amigos que a %s tem o melhor preço da cidade." % loja, ""]],
	]

# mostra a fala atual (legenda + voz); sem voz, fica o tempo de leitura
func _mostrar_fala() -> void:
	var f: Array = _dialogo[_fala]
	nome_lbl.text = NOME_HEROINA if f[0] == "heroina" else ("Edric, o cavalariço" if f[0] == "cavalarico" else ("Bram, o ferreiro" if f[0] == "ferreiro" else String(npc.get_meta("nome", "Irmã")) if npc else "Irmã"))
	nome_lbl.add_theme_color_override("font_color", Color(0.62, 0.82, 1.0) if f[0] == "heroina" else Color(0.98, 0.8, 0.42))
	fala_lbl.text = f[1]
	if npc: npc.gesticula = f[0] != "heroina"
	voz.stop()
	if f[2] != "" and ResourceLoader.exists(f[2]):
		voz.stream = load(f[2]); voz.play(); _tempo_fala = voz.stream.get_length() + 0.6
		_inicio_fala = Time.get_ticks_msec()
	else:
		_tempo_fala = 1.5 + f[1].length() * 0.055

func _tocar_caixa() -> void:
	if voz.playing or Time.get_ticks_msec() - _inicio_fala < 600: return
	_avancar()

var _inicio_fala := 0
func _avancar() -> void:
	_fala += 1
	if _fala >= _dialogo.size(): _fechar()
	else: _mostrar_fala()

func _fechar() -> void:
	caixa.visible = false; _falando = false; voz.stop()
	if npc: npc.falando_com = null; npc.gesticula = true

# ---------- portas: entrar nos interiores e sair ----------
var botao_entrar: Control
var botao_sair: Control
var _porta: Array = []
var _porta_dentro := false
func _usar_porta(entrar: bool) -> void:
	if _porta.is_empty() or m.jogador.montado: return
	var alvo: Vector3 = _porta[1] if entrar else _porta[0]
	var ang: float = _porta[3] if entrar else _porta[2]
	escuro.visible = true
	var tw := create_tween(); tw.tween_property(escuro, "modulate:a", 1.0, 0.25)
	tw.tween_callback(func():
		m.jogador.global_position = alvo + Vector3(0, 0.3, 0); m.jogador.velocity = Vector3.ZERO
		m.jogador.rotation.y = ang
		if m.jogador.has_method("reset_physics_interpolation"): m.jogador.reset_physics_interpolation()
		_aviso(String(_porta[4]) if entrar else ""))
	tw.tween_property(escuro, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func(): escuro.visible = false)

func _ver_portas() -> void:
	_porta = []
	var pj: Vector3 = m.jogador.global_position
	for p in m.portas:
		if pj.distance_to(p[0]) < 3.2: _porta = p; _porta_dentro = false; break
		if pj.distance_to(p[1]) < 2.6: _porta = p; _porta_dentro = true; break
	botao_entrar.visible = not _porta.is_empty() and not _porta_dentro and npc == null
	botao_sair.visible = not _porta.is_empty() and _porta_dentro

func _process(_d: float) -> void:
	if m == null or m.jogador == null: return
	if botao_entrar: _ver_portas()
	var perto: Morador = null
	if _ferreiros.is_empty():                     # procura uma vez só (andar por todos os nós a cada quadro pesava)
		for mo in m.raiz.get_children(): if mo is Morador and mo.profissao == "ferreiro": _ferreiros.append(mo)
	for mo in _ferreiros:
		if mo.global_position.distance_to(m.jogador.global_position) < (ALCANCE if not _falando else 12.0):
			perto = mo
	var tipo := "ferreiro" if perto else ""
	var cv: Morador = m.estabulo_npc
	if perto == null and cv and cv.global_position.distance_to(m.jogador.global_position) < (6.0 if not _falando else 12.0):
		perto = cv; tipo = "cavalarico"
	if perto == null:
		for fr in m.freiras:
			if fr.global_position.distance_to(m.jogador.global_position) < (5.0 if not _falando else 12.0): perto = fr; tipo = "freira"
	if perto == null:
		var md := 3.6 if not _falando else 12.0
		for vd in m.vendedores:
			var dv: float = vd.global_position.distance_to(m.jogador.global_position)
			if dv < md: perto = vd; tipo = "vendedor"; md = dv
	if perto != npc:
		if npc and _falando: _fechar()
		if m.loja_ui and m.loja_ui.aberta: m.loja_ui.fechar()
		if perto != null and npc == null and tipo == "ferreiro":
			_conversou = false
			_fala_solta(CHEGA[_chega_i % CHEGA.size()]); _chega_i += 1
		elif perto == null and npc != null and _conversou and _tipo_npc == "ferreiro":
			_fala_solta(TCHAU, true)
		npc = perto; _tipo_npc = tipo
	var livre: bool = npc != null and not _falando and not (m.loja_ui != null and m.loja_ui.aberta)
	painel.visible = livre and _tipo_npc == "ferreiro"
	painel_estabulo.visible = livre and (_tipo_npc == "cavalarico" or _tipo_npc == "freira" or _tipo_npc == "vendedor")
	var na_barraca := perto_da_barraca() and not _dormindo
	painel_barraca.visible = na_barraca and npc == null
	_t_baga -= _d
	if _t_baga <= 0.0:                          # procura arbusto perto 5× por segundo (não a cada quadro)
		_t_baga = 0.2
		_baga = m.floresta.baga_perto(m.jogador.global_position) if (m.floresta and npc == null and not na_barraca and not m.jogador.montado) else []
	painel_coletar.visible = not _baga.is_empty() and npc == null and not na_barraca
	Audio.falando = _falando and voz.playing
	if _falando:
		_tempo_fala -= _d
		if _tempo_fala <= 0.0 and not voz.playing: _avancar()          # passa sozinho quando a fala termina
	var f := Input.is_key_pressed(KEY_F)
	if f and not _f_antes:
		if _falando: _tocar_caixa()
		elif not _porta.is_empty(): _usar_porta(not _porta_dentro)
		elif npc: _conversar()
		elif na_barraca: _descansar()
		elif not _baga.is_empty(): _coletar()
	_f_antes = f

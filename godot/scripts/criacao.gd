# Criação de herói (inspirada na tela de criação do WoW): à esquerda raça, sexo e classe (só o que já existe no jogo
# fica liberado; o resto aparece trancado "em breve"); no meio a heroína em 3D sobre uma pedra; à direita os
# textos da raça e da classe escolhidas; embaixo o nome (com ALEATÓRIO) e ACEITAR / VOLTAR.
extends Control
signal pronto(heroi: Dictionary)
signal voltar

const RACAS := [["Humana", true], ["Anã", false], ["Elfa", false], ["Meio-elfa", false]]
const CLASSES := [["Guerreira", true], ["Paladina", false], ["Caçadora", false], ["Maga", false], ["Sacerdotisa", false]]
const TEXTOS := {
	"Humana": "Os humanos do Vale de Aldren ergueram Altamar entre a montanha e o mar. Teimosos e corajosos, vivem de lavrar a terra, forjar o ferro e defender as muralhas contra o que desce das montanhas e sobe dos rios.",
	"Guerreira": "Guerreiras lutam na linha de frente com espada e escudo. Aguentam pancadas que derrubariam qualquer outro, bloqueiam golpes erguendo o escudo e terminam as lutas na força do braço.",
}
const NOMES := ["Aldra", "Brienne", "Cerys", "Elowen", "Isolde", "Maelis", "Rowena", "Sabine", "Tamsin", "Wren", "Ysolde", "Lyra", "Morgana", "Edwina"]
var _raca := "Humana"
var _classe := "Guerreira"
var _nome: LineEdit
var _aviso: Label
var _modelo: Node3D
var _txt_raca: Label
var _txt_classe: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fundo := ColorRect.new(); fundo.color = Color(0.1, 0.06, 0.04); fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(fundo)
	var arq := "res://assets/ui/criacao_fundo.png" if ResourceLoader.exists("res://assets/ui/criacao_fundo.png") else "res://assets/ui/tela_inicio.png"
	if ResourceLoader.exists(arq):
		var img := TextureRect.new(); img.texture = load(arq); img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED; img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(img)
		var sombra := ColorRect.new(); sombra.color = Color(0.12, 0.04, 0.0, 0.45); sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(sombra)
	_heroina_3d()
	# ----- painel da esquerda: raça, sexo, classe
	var esq := UI.janela(); esq.offset_left = 24; esq.offset_top = 24; esq.offset_right = 420; add_child(esq)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 10); esq.add_child(v)
	v.add_child(_titulo("RAÇA"))
	var gr := GridContainer.new(); gr.columns = 2; gr.add_theme_constant_override("h_separation", 8); gr.add_theme_constant_override("v_separation", 8); v.add_child(gr)
	for r in RACAS: gr.add_child(_opcao(r[0], r[1], r[0] == _raca, func(): pass))
	v.add_child(_titulo("SEXO"))
	var hs := HBoxContainer.new(); hs.add_theme_constant_override("separation", 8); v.add_child(hs)
	hs.add_child(_opcao("Feminino", true, true, func(): pass)); hs.add_child(_opcao("Masculino", false, false, func(): pass))
	v.add_child(_titulo("CLASSE"))
	var gc := GridContainer.new(); gc.columns = 2; gc.add_theme_constant_override("h_separation", 8); gc.add_theme_constant_override("v_separation", 8); v.add_child(gc)
	for c in CLASSES: gc.add_child(_opcao(c[0], c[1], c[0] == _classe, func(): pass))
	var obs := UI.rotulo("Trancadas: chegam em breve.", 18, Color(0.7, 0.7, 0.7)); v.add_child(obs)
	# ----- painel da direita: textos
	var dir := VBoxContainer.new(); dir.add_theme_constant_override("separation", 14)
	dir.anchor_left = 1; dir.anchor_right = 1; dir.offset_left = -470; dir.offset_right = -24; dir.offset_top = 24; add_child(dir)
	_txt_raca = _cartao_texto(dir, _raca, TEXTOS[_raca])
	_txt_classe = _cartao_texto(dir, _classe, TEXTOS[_classe])
	# ----- nome embaixo no meio
	var nb := VBoxContainer.new(); nb.add_theme_constant_override("separation", 8)
	nb.anchor_left = 0.5; nb.anchor_right = 0.5; nb.anchor_top = 1; nb.anchor_bottom = 1
	nb.offset_left = -230; nb.offset_right = 230; nb.offset_top = -170; nb.offset_bottom = -20; add_child(nb)
	var tn := UI.rotulo("Nome", 28, Color(1.0, 0.82, 0.3)); tn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; nb.add_child(tn)
	_nome = LineEdit.new(); _nome.max_length = 12; _nome.placeholder_text = "nome da heroína"; _nome.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nome.add_theme_font_size_override("font_size", 30); _nome.custom_minimum_size = Vector2(460, 62)
	_nome.add_theme_stylebox_override("normal", UI.estilo(Color(0.05, 0.04, 0.03, 0.92), UI.DOURADO, 8, 12, 3))
	_nome.add_theme_stylebox_override("focus", UI.estilo(Color(0.08, 0.06, 0.04, 0.95), Color(1.0, 0.82, 0.3), 8, 12, 3))
	nb.add_child(_nome)
	var ale := UI.botao("ALEATÓRIO", func(): _nome.text = NOMES[randi() % NOMES.size()], true, 22, 460.0); ale.custom_minimum_size.y = 50; nb.add_child(ale)
	_aviso = UI.rotulo("", 24, Color(1.0, 0.5, 0.4)); _aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.anchor_left = 0.3; _aviso.anchor_right = 0.7; _aviso.anchor_top = 1; _aviso.anchor_bottom = 1; _aviso.offset_top = -215; _aviso.offset_bottom = -180; add_child(_aviso)
	# ----- ACEITAR / VOLTAR embaixo à direita
	var b := VBoxContainer.new(); b.add_theme_constant_override("separation", 12); b.alignment = BoxContainer.ALIGNMENT_END
	b.anchor_left = 1; b.anchor_right = 1; b.anchor_top = 1; b.anchor_bottom = 1
	b.offset_left = -330; b.offset_right = -24; b.offset_top = -170; b.offset_bottom = -20; add_child(b)
	var ac := UI.botao("ACEITAR", _aceitar, true, 32, 306.0); ac.custom_minimum_size.y = 74; b.add_child(ac)
	b.add_child(UI.botao("VOLTAR", func(): voltar.emit(), true, 24, 306.0))

func _titulo(t: String) -> Label:
	return UI.rotulo(t, 24, Color(1.0, 0.82, 0.3))

func _opcao(t: String, livre: bool, sel: bool, f: Callable) -> Button:
	var b := Button.new(); b.text = t; b.disabled = not livre; b.custom_minimum_size = Vector2(176, 52)
	b.add_theme_font_size_override("font_size", 20)
	var cor := Color(0.4, 0.24, 0.06, 0.95) if sel else (Color(0.12, 0.1, 0.08, 0.9) if livre else Color(0.08, 0.08, 0.08, 0.8))
	var borda := Color(1.0, 0.82, 0.3) if sel else (UI.DOURADO if livre else Color(0.35, 0.33, 0.3))
	for st in ["normal", "hover", "pressed", "disabled", "focus"]: b.add_theme_stylebox_override(st, UI.estilo(cor, borda, 8, 10, 3 if sel else 2))
	b.add_theme_color_override("font_color", Color(1, 1, 1)); b.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5))
	b.pressed.connect(f)
	return b

func _cartao_texto(pai: Control, titulo: String, texto: String) -> Label:
	var p := UI.janela(); pai.add_child(p)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 6); p.add_child(v)
	v.add_child(UI.rotulo(titulo, 28, Color(1.0, 0.82, 0.3)))
	var l := UI.rotulo(texto, 20, Color(0.95, 0.9, 0.8)); l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; l.custom_minimum_size = Vector2(400, 0)
	v.add_child(l); return l

func _heroina_3d() -> void:
	var cont := SubViewportContainer.new(); cont.stretch = true; cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cont.anchor_left = 0.3; cont.anchor_right = 0.64; cont.anchor_top = 0.06; cont.anchor_bottom = 0.78; add_child(cont)
	var vp := SubViewport.new(); vp.transparent_bg = true; vp.own_world_3d = true; cont.add_child(vp)
	_modelo = load("res://assets/modelos/dallarian.glb").instantiate(); vp.add_child(_modelo)
	for n in _modelo.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n
		var orig: BaseMaterial3D = mi.mesh.surface_get_material(0)
		if orig:
			var mt := orig.duplicate() as BaseMaterial3D; mt.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST; mi.material_override = mt
	# pedra embaixo dos pés
	var pedra := MeshInstance3D.new(); var cil := CylinderMesh.new(); cil.top_radius = 0.3; cil.bottom_radius = 0.36; cil.height = 0.1; cil.radial_segments = 9
	var pm := StandardMaterial3D.new(); pm.albedo_color = Color(0.45, 0.42, 0.4); cil.material = pm; pedra.mesh = cil; pedra.position = Vector3(0, -0.545, 0); vp.add_child(pedra)
	var luz := DirectionalLight3D.new(); luz.rotation_degrees = Vector3(-25, 30, 0); luz.light_energy = 1.2; luz.light_color = Color(1.0, 0.88, 0.75); vp.add_child(luz)
	var amb := WorldEnvironment.new(); var env := Environment.new(); env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.75, 0.65, 0.6); env.ambient_light_energy = 0.85
	amb.environment = env; vp.add_child(amb)
	var cam := Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = 1.3
	cam.position = Vector3(0.0, 0.55, 2.0); vp.add_child(cam); cam.look_at(Vector3(0, -0.08, 0)); cam.current = true   # um pouco de cima: vê o topo da pedra

func _process(_d: float) -> void:
	if _modelo: _modelo.rotation.y = -PI * 0.5 + sin(Time.get_ticks_msec() / 1000.0 * 0.6) * 0.35

func _aceitar() -> void:
	var n := _nome.text.strip_edges()
	if n.length() < 3: _aviso.text = "O nome precisa ter pelo menos 3 letras."; return
	var re := RegEx.new(); re.compile("^[A-Za-zÀ-ÿ]+$")
	if re.search(n) == null: _aviso.text = "Use só letras, sem espaços."; return
	n = n.substr(0, 1).to_upper() + n.substr(1).to_lower()
	if Herois.nome_existe(n): _aviso.text = "Já existe um herói com esse nome."; return
	pronto.emit(Herois.criar(n, _raca, _classe))

# Menu de início (tela de título): a arte de Altamar, o nome do jogo e os botões JOGAR e SAIR. JOGAR leva à seleção de
# heróis (e de lá à criação). A música do menu já começa aqui.
extends Control
signal jogar

func _ready() -> void:
	print("MENU DE INICIO aberto")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fundo := ColorRect.new(); fundo.color = Color(0.06, 0.05, 0.05); fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(fundo)
	if ResourceLoader.exists("res://assets/ui/tela_inicio.png"):
		var img := TextureRect.new(); img.texture = load("res://assets/ui/tela_inicio.png")
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(img)
	var sombra := ColorRect.new(); sombra.color = Color(0, 0, 0, 0.3); sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(sombra)
	var v := VBoxContainer.new(); v.alignment = BoxContainer.ALIGNMENT_CENTER; v.add_theme_constant_override("separation", 18)
	v.anchor_left = 0.5; v.anchor_right = 0.5; v.anchor_top = 0.5; v.anchor_bottom = 0.5
	v.offset_left = -260; v.offset_right = 260; v.offset_top = -230; v.offset_bottom = 260; add_child(v)
	var t := UI.rotulo("DALLARIAN", 92, Color(1.0, 0.82, 0.3)); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_constant_override("outline_size", 16); v.add_child(t)
	var st := UI.rotulo("Vale de Aldren", 34, Color(0.95, 0.9, 0.8)); st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(st)
	var esp := Control.new(); esp.custom_minimum_size = Vector2(0, 40); v.add_child(esp)
	var bj := UI.botao("JOGAR", func(): jogar.emit(), true, 38, 520.0); bj.custom_minimum_size.y = 90; v.add_child(bj)
	if not OS.has_feature("web"):
		v.add_child(UI.botao("SAIR", func(): get_tree().quit(), true, 28, 520.0))
	var ver := UI.rotulo("versão %d" % _versao(), 20, Color(0.85, 0.85, 0.85)); ver.anchor_left = 1; ver.anchor_right = 1; ver.anchor_top = 1; ver.anchor_bottom = 1
	ver.offset_left = -200; ver.offset_right = -20; ver.offset_top = -44; ver.offset_bottom = -14; ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; add_child(ver)

func _versao() -> int:
	var n := 0
	for arq in ["user://atualizacao/versao.json", "res://versao.json"]:
		if FileAccess.file_exists(arq):
			var d = JSON.parse_string(FileAccess.get_file_as_string(arq))
			if d is Dictionary: n = maxi(n, int(d.get("n", 0)))
	return n

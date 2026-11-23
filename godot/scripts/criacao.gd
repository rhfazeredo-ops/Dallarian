# Criação de herói: o herói aparece em pé na grama de um campo do Vale de Aldren, de dia, visto de frente em
# terceira pessoa (como se já estivesse no mapa). À esquerda, as 4 raças, cada uma com o retrato da versão
# masculina e da feminina (só a humana feminina — a Rachel — existe por enquanto; as outras ficam escuras,
# indisponíveis). À direita, a lore da raça escolhida. Embaixo, o nome (com ALEATÓRIO) e ACEITAR / VOLTAR.
# Sem customização: cada herói já vem pronto.
extends Control
signal pronto(heroi: Dictionary)
signal voltar

# [nome da raça, lore, [masculino disponível?, feminino disponível?]]
const RACAS := [
	["Humanos", "Os humanos do Vale de Aldren ergueram Altamar entre a montanha e o mar. Teimosos e corajosos, vivem de lavrar a terra, forjar o ferro e defender as muralhas contra o que desce das montanhas e sobe dos rios. Suas cavaleiras juram proteger o vale aos pés das Estátuas da Guardiã.", [false, true]],
	["Raça 2", "Em breve.", [false, false]],
	["Raça 3", "Em breve.", [false, false]],
	["Raça 4", "Em breve.", [false, false]],
]
const NOMES := ["Aldra", "Brienne", "Cerys", "Elowen", "Isolde", "Maelis", "Rowena", "Sabine", "Tamsin", "Wren", "Ysolde", "Lyra", "Morgana", "Edwina"]
var _raca := 0
var _sexo := 1                      # 0 masculino, 1 feminino
var _nome: LineEdit
var _aviso: Label
var _modelo: Node3D
var _lore_tit: Label
var _lore: Label
var _botoes := []                   # [botão, raça, sexo]
var pode_voltar := true

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cena_campo()
	# ----- esquerda: as 4 raças, retrato masculino e feminino de cada
	var esq := UI.janela(); esq.offset_left = 20; esq.offset_top = 20; add_child(esq)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 10); esq.add_child(v)
	v.add_child(UI.rotulo("RAÇAS", 26, Color(1.0, 0.82, 0.3)))
	for r in RACAS.size():
		var linha := HBoxContainer.new(); linha.add_theme_constant_override("separation", 10); v.add_child(linha)
		for sx in 2:
			var livre: bool = RACAS[r][2][sx]
			var b := Button.new(); b.custom_minimum_size = Vector2(96, 96); b.disabled = not livre
			var ic := _retrato(r, sx, livre); ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			ic.offset_left = 5; ic.offset_top = 5; ic.offset_right = -5; ic.offset_bottom = -5
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE; b.add_child(ic)
			var rr := r; var ss := sx
			b.pressed.connect(func(): _escolher(rr, ss))
			linha.add_child(b); _botoes.append([b, r, sx])
		var nm := UI.rotulo(RACAS[r][0], 20, Color(0.95, 0.9, 0.8) if r == 0 else Color(0.5, 0.5, 0.5)); nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		linha.add_child(nm)
	# ----- direita: lore da raça
	var dir := UI.janela(); dir.anchor_left = 1; dir.anchor_right = 1; dir.offset_left = -470; dir.offset_right = -20; dir.offset_top = 20; add_child(dir)
	var dv := VBoxContainer.new(); dv.add_theme_constant_override("separation", 8); dir.add_child(dv)
	_lore_tit = UI.rotulo("", 30, Color(1.0, 0.82, 0.3)); dv.add_child(_lore_tit)
	_lore = UI.rotulo("", 21, Color(0.95, 0.9, 0.8)); _lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _lore.custom_minimum_size = Vector2(410, 0); dv.add_child(_lore)
	# ----- nome embaixo no meio
	var nb := VBoxContainer.new(); nb.add_theme_constant_override("separation", 8)
	nb.anchor_left = 0.5; nb.anchor_right = 0.5; nb.anchor_top = 1; nb.anchor_bottom = 1
	nb.offset_left = -230; nb.offset_right = 230; nb.offset_top = -170; nb.offset_bottom = -20; add_child(nb)
	var tn := UI.rotulo("Nome", 28, Color(1.0, 0.82, 0.3)); tn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; nb.add_child(tn)
	_nome = LineEdit.new(); _nome.max_length = 12; _nome.placeholder_text = "nome do herói"; _nome.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nome.add_theme_font_size_override("font_size", 30); _nome.custom_minimum_size = Vector2(460, 62)
	_nome.add_theme_stylebox_override("normal", UI.estilo(Color(0.05, 0.04, 0.03, 0.92), UI.DOURADO, 8, 12, 3))
	_nome.add_theme_stylebox_override("focus", UI.estilo(Color(0.08, 0.06, 0.04, 0.95), Color(1.0, 0.82, 0.3), 8, 12, 3))
	nb.add_child(_nome)
	var ale := UI.botao("ALEATÓRIO", func(): _nome.text = NOMES[randi() % NOMES.size()], true, 22, 460.0); ale.custom_minimum_size.y = 50; nb.add_child(ale)
	_aviso = UI.rotulo("", 24, Color(1.0, 0.5, 0.4)); _aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.anchor_left = 0.3; _aviso.anchor_right = 0.7; _aviso.anchor_top = 1; _aviso.anchor_bottom = 1; _aviso.offset_top = -215; _aviso.offset_bottom = -180; add_child(_aviso)
	# ----- ACEITAR / VOLTAR
	var b2 := VBoxContainer.new(); b2.add_theme_constant_override("separation", 12); b2.alignment = BoxContainer.ALIGNMENT_END
	b2.anchor_left = 1; b2.anchor_right = 1; b2.anchor_top = 1; b2.anchor_bottom = 1
	b2.offset_left = -330; b2.offset_right = -20; b2.offset_top = -170; b2.offset_bottom = -20; add_child(b2)
	var ac := UI.botao("ACEITAR", _aceitar, true, 32, 310.0); ac.custom_minimum_size.y = 74; b2.add_child(ac)
	if pode_voltar: b2.add_child(UI.botao("VOLTAR", func(): voltar.emit(), true, 24, 310.0))
	else:                                              # primeira vez: criar o herói é obrigatório
		var bv := UI.rotulo("Crie seu herói para começar", 30, Color(1.0, 0.85, 0.4)); bv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bv.anchor_left = 0.25; bv.anchor_right = 0.75; bv.offset_top = 24; bv.offset_bottom = 70; add_child(bv)
	_escolher(0, 1)

# retrato: arte do dono (assets/ui/racas/N_m.png / N_f.png) se existir; senão o rosto do modelo (Rachel) ou um "?"
func _retrato(r: int, sx: int, livre: bool) -> Control:
	var ic: String = "res://assets/ui/racas/%d_%s.png" % [r + 1, "m" if sx == 0 else "f"]
	if ResourceLoader.exists(ic):
		var t := TextureRect.new(); t.texture = load(ic); t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		if not livre: t.modulate = Color(0.25, 0.25, 0.28)          # indisponível: escuro
		return t
	if livre and r == 0 and sx == 1:                       # Rachel: rosto renderizado do modelo
		var cont := SubViewportContainer.new(); cont.stretch = true
		var vp := SubViewport.new(); vp.own_world_3d = true; cont.add_child(vp)
		var mod: Node3D = load("res://assets/modelos/dallarian.glb").instantiate(); mod.rotation_degrees.y = -90; vp.add_child(mod)
		_nitido(mod)
		var luz := DirectionalLight3D.new(); luz.rotation_degrees = Vector3(-20, 25, 0); vp.add_child(luz)
		var we := WorldEnvironment.new(); var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.25, 0.32, 0.22)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.8, 0.78, 0.8); env.ambient_light_energy = 0.8; we.environment = env; vp.add_child(we)
		var cam := Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = 0.22; cam.position = Vector3(0, 0.39, 1.0); vp.add_child(cam); cam.current = true
		return cont
	var q := ColorRect.new(); q.color = Color(0.1, 0.1, 0.12)
	var l := UI.rotulo("?", 44, Color(0.35, 0.35, 0.38)); l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; q.add_child(l)
	return q

func _nitido(mod: Node3D) -> void:
	for n in mod.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n
		var orig: BaseMaterial3D = mi.mesh.surface_get_material(0)
		if orig:
			var mt := orig.duplicate() as BaseMaterial3D; mt.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST; mi.material_override = mt

# o campo: céu de dia, grama verde, árvores lá no fundo e o herói em pé na grama, visto de frente
func _cena_campo() -> void:
	var arq := "res://assets/ui/criacao_fundo.png"
	var tem_arte := ResourceLoader.exists(arq)
	if tem_arte:                                            # arte de fundo (campo de dia) atrás do herói
		var img := TextureRect.new(); img.texture = load(arq); img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED; img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(img)
	var cont := SubViewportContainer.new(); cont.stretch = true; cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cont.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(cont)
	var vp := SubViewport.new(); vp.own_world_3d = true; vp.transparent_bg = tem_arte; cont.add_child(vp)
	var we := WorldEnvironment.new(); var env := Environment.new()
	if not tem_arte:
		var ceu := ProceduralSkyMaterial.new(); ceu.sky_top_color = Color(0.32, 0.55, 0.9); ceu.sky_horizon_color = Color(0.75, 0.85, 0.95)
		ceu.ground_horizon_color = Color(0.5, 0.65, 0.4); ceu.ground_bottom_color = Color(0.3, 0.45, 0.25)
		var sky := Sky.new(); sky.sky_material = ceu; env.sky = sky; env.background_mode = Environment.BG_SKY
	else: env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.75, 0.8, 0.85); env.ambient_light_energy = 0.55
	we.environment = env; vp.add_child(we)
	var sol := DirectionalLight3D.new(); sol.rotation_degrees = Vector3(-40, 30, 0); sol.light_energy = 0.9; sol.light_color = Color(1.0, 0.96, 0.88)
	sol.shadow_enabled = true; vp.add_child(sol)
	if not tem_arte:
		var chao := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(400, 400); chao.mesh = pm
		var mg := StandardMaterial3D.new(); mg.albedo_texture = Texturas.pegar("terreno"); mg.albedo_color = Color(0.3, 0.46, 0.2)
		mg.uv1_scale = Vector3(160, 160, 1); mg.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS; pm.material = mg; vp.add_child(chao)
		var rng := RandomNumberGenerator.new(); rng.seed = 7
		var tufo := PrismMesh.new(); tufo.size = Vector3(0.07, 0.2, 0.02)
		var mt := StandardMaterial3D.new(); mt.albedo_color = Color(0.3, 0.5, 0.2); mt.cull_mode = BaseMaterial3D.CULL_DISABLED; tufo.material = mt
		var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = tufo; mm.instance_count = 1400
		for i in 1400:
			var p := Vector3(rng.randf_range(-8, 8), 0.12, rng.randf_range(-10, 3))
			mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.6, 1.4)), p))
		var mmi := MultiMeshInstance3D.new(); mmi.multimesh = mm; vp.add_child(mmi)
		var tronco := CylinderMesh.new(); tronco.top_radius = 0.25; tronco.bottom_radius = 0.35; tronco.height = 4.0
		var mtr := StandardMaterial3D.new(); mtr.albedo_color = Color(0.35, 0.24, 0.15); tronco.material = mtr
		var copa := SphereMesh.new(); copa.radius = 2.6; copa.height = 4.4
		var mco := StandardMaterial3D.new(); mco.albedo_color = Color(0.27, 0.5, 0.22); copa.material = mco
		var pinho := CylinderMesh.new(); pinho.top_radius = 0.0; pinho.bottom_radius = 2.2; pinho.height = 8.0
		var mpi := StandardMaterial3D.new(); mpi.albedo_color = Color(0.18, 0.38, 0.22); pinho.material = mpi
		for i in 30:
			var x := rng.randf_range(-80, 80); var z := rng.randf_range(-80, -40)
			var t := MeshInstance3D.new(); t.mesh = tronco; t.position = Vector3(x, 2.0, z); vp.add_child(t)
			var c := MeshInstance3D.new(); c.mesh = copa if rng.randf() < 0.6 else pinho; c.position = Vector3(x, 5.5, z)
			c.scale = Vector3.ONE * rng.randf_range(0.8, 1.3); vp.add_child(c)
	if tem_arte:                                            # sombra redonda nos pés (pisa na grama da arte)
		var somb := MeshInstance3D.new(); var dm := PlaneMesh.new(); dm.size = Vector2(1.1, 0.7); somb.mesh = dm
		var ms := StandardMaterial3D.new(); ms.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; ms.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var gt := GradientTexture2D.new(); gt.fill = GradientTexture2D.FILL_RADIAL; gt.fill_from = Vector2(0.5, 0.5); gt.fill_to = Vector2(1.0, 0.5)
		var gr := Gradient.new(); gr.set_color(0, Color(0.05, 0.1, 0.02, 0.55)); gr.set_color(1, Color(0.05, 0.1, 0.02, 0.0)); gt.gradient = gr
		ms.albedo_texture = gt; dm.material = ms; somb.position = Vector3(0.08, 0.01, 0.05); vp.add_child(somb)
	# o herói em pé na grama (no arquivo o modelo tem 0,98 de altura, de -0,49 a 0,49)
	_modelo = load("res://assets/modelos/dallarian.glb").instantiate(); vp.add_child(_modelo)
	_nitido(_modelo)
	var k := 1.65 / 0.98; _modelo.scale = Vector3.ONE * k; _modelo.position = Vector3(0, 0.49 * k, 0)
	var cam := Camera3D.new(); cam.fov = 40.0; cam.position = Vector3(0.0, 1.25, 3.3); vp.add_child(cam); cam.look_at(Vector3(0.0, 0.92, 0)); cam.current = true   # perto: herói grande

func _escolher(r: int, sx: int) -> void:
	if not RACAS[r][2][sx]: return
	_raca = r; _sexo = sx
	_lore_tit.text = RACAS[r][0]; _lore.text = RACAS[r][1]
	for bt in _botoes:
		var sel: bool = bt[1] == r and bt[2] == sx
		var livre: bool = RACAS[bt[1]][2][bt[2]]
		for st in ["normal", "hover", "pressed", "disabled", "focus"]:
			bt[0].add_theme_stylebox_override(st, UI.estilo(Color(0.1, 0.08, 0.06, 0.9), Color(1.0, 0.82, 0.3) if sel else (UI.DOURADO if livre else Color(0.3, 0.3, 0.3)), 8, 4, 4 if sel else 2))

func _process(_d: float) -> void:
	if _modelo: _modelo.rotation.y = -PI * 0.5 + sin(Time.get_ticks_msec() / 1000.0 * 0.5) * 0.25

func _aceitar() -> void:
	var n := _nome.text.strip_edges()
	if n.length() < 3: _aviso.text = "O nome precisa ter pelo menos 3 letras."; return
	var re := RegEx.new(); re.compile("^[A-Za-zÀ-ÿ]+$")
	if re.search(n) == null: _aviso.text = "Use só letras, sem espaços."; return
	n = n.substr(0, 1).to_upper() + n.substr(1).to_lower()
	if Herois.nome_existe(n): _aviso.text = "Já existe um herói com esse nome."; return
	pronto.emit(Herois.criar(n, "Humana" if _sexo == 1 else "Humano", "Guerreira" if _sexo == 1 else "Guerreiro"))

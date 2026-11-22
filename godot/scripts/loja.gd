# Janela de vendedor no estilo do WoW: retrato e nome do vendedor no alto, mercadorias em duas colunas
# (ícone, nome na cor da qualidade e preço em moedas), abas COMPRAR e RECOMPRAR embaixo e o dinheiro da Rachel.
# Para vender, as bolsas abrem junto: toque num item e em VENDER (vende a pilha toda, como o clique direito do WoW).
extends Control
class_name Loja

var m
var aberta := false
var npc: Morador
var _janela: PanelContainer
var _grade: GridContainer
var _dinheiro: HBoxContainer
var _aba := "comprar"
var _pagina := 0
var _rodape: Label
var _retrato: Texture2D
var _abas := {}
var _foto: Control
var _retrato_bram: Texture2D
var _nome_lbl: Label
var _cargo_lbl: Label
var cfg := {}                    # vendedor atual: nome, cargo, itens, retrato, falas_compra, falas_venda (vazio = Bram)
# mercadorias do Bram (por enquanto: bolsas; as de 40 e 50 vão para mercadores de cidade)
const MERCADORIAS := ["espada_ferro", "bolsa_10", "bolsa_16", "bolsa_20", "bolsa_30"]
const FALAS_VENDA := ["Dente de lobo dá bom cabo de faca. Pago justo.", "Garra afiada assim? Isso eu compro.", "Cobre por cobre, negócio fechado."]
const FALAS_COMPRA := ["Couro bom, costura dupla. Não rasga fácil.", "Leva, leva. Uma aventureira precisa de onde guardar as coisas."]

func montar(mundo) -> void:
	m = mundo
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tirar_retrato()

func abrir(quem: Morador, c := {}) -> void:
	npc = quem; aberta = true; _aba = "comprar"; _pagina = 0; cfg = c
	if _janela == null: _montar()
	_nome_lbl.text = cfg.get("nome", "Bram"); _cargo_lbl.text = cfg.get("cargo", "<Ferreiro>")
	_retrato = cfg.get("retrato", _retrato_bram); _foto.queue_redraw()
	_janela.visible = true; _atualizar()
	m.inventario.abrir(true)
	if npc: npc.falando_com = m.jogador; npc.gesticula = true

func fechar() -> void:
	if not aberta: return
	aberta = false
	if _janela: _janela.visible = false
	m.inventario.fechar()
	m.controles.set_process_input(true)
	if npc: npc.falando_com = null

func _montar() -> void:
	_janela = UI.janela(); add_child(_janela)
	_janela.position = Vector2(60, 110)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 12); _janela.add_child(v)
	# cabeçalho: retrato redondo + nome + fechar
	var topo := HBoxContainer.new(); topo.add_theme_constant_override("separation", 14); v.add_child(topo)
	var foto := Control.new(); foto.custom_minimum_size = Vector2(96, 96); topo.add_child(foto); _foto = foto
	foto.draw.connect(func():
		foto.draw_circle(Vector2(48, 48), 48.0, UI.DOURADO)
		foto.draw_circle(Vector2(48, 48), 44.0, Color(0.1, 0.08, 0.07))
		if _retrato:
			var pts := PackedVector2Array(); var uvs := PackedVector2Array()
			for i in 40:
				var a := TAU * i / 40.0; var q := Vector2(cos(a), sin(a))
				pts.append(Vector2(48, 48) + q * 43.0); uvs.append(Vector2(0.5, 0.5) + q * 0.5)
			foto.draw_colored_polygon(pts, Color.WHITE, uvs, _retrato))
	var nomes := VBoxContainer.new(); nomes.size_flags_horizontal = Control.SIZE_EXPAND_FILL; topo.add_child(nomes)
	_nome_lbl = UI.rotulo("Bram", 36, UI.AMARELO); nomes.add_child(_nome_lbl)
	_cargo_lbl = UI.rotulo("<Ferreiro>", 24, Color(0.85, 0.85, 0.85)); nomes.add_child(_cargo_lbl)
	topo.add_child(UI.botao_fechar(fechar))
	# mercadorias
	_grade = GridContainer.new(); _grade.columns = 2
	_grade.add_theme_constant_override("h_separation", 18); _grade.add_theme_constant_override("v_separation", 12)
	v.add_child(_grade)
	# página
	var pag := HBoxContainer.new(); pag.alignment = BoxContainer.ALIGNMENT_CENTER; pag.add_theme_constant_override("separation", 16); v.add_child(pag)
	pag.add_child(UI.botao("<", func(): _pagina = maxi(0, _pagina - 1); _atualizar(), true, 26, 70.0))
	_rodape = UI.rotulo("Página 1", 22); pag.add_child(_rodape)
	pag.add_child(UI.botao(">", func(): _pagina += 1; _atualizar(), true, 26, 70.0))
	var dica := UI.rotulo("Para vender: toque num item da sua bolsa e em VENDER.", 20, Color(0.8, 0.78, 0.7))
	v.add_child(dica)
	# dinheiro + abas
	var baixo := HBoxContainer.new(); baixo.add_theme_constant_override("separation", 12); v.add_child(baixo)
	for aba in ["comprar", "recomprar"]:
		var b := UI.botao(aba.to_upper(), func(): _aba = aba; _pagina = 0; _atualizar(), true, 22, 160.0)
		_abas[aba] = b; baixo.add_child(b)
	var vazio := Control.new(); vazio.size_flags_horizontal = Control.SIZE_EXPAND_FILL; baixo.add_child(vazio)
	_dinheiro = HBoxContainer.new(); baixo.add_child(_dinheiro)
	m.bolsa.mudou.connect(func(): if aberta: _atualizar())

func _atualizar() -> void:
	for c in _grade.get_children(): c.queue_free()
	for c in _dinheiro.get_children(): c.queue_free()
	_dinheiro.add_child(UI.dinheiro(m.bolsa.cobre, 26))
	for aba in _abas.keys():
		var b: Button = _abas[aba]; b.modulate = Color(1, 1, 1) if aba == _aba else Color(0.6, 0.6, 0.6)
	var lista := []
	if _aba == "comprar":
		for id in cfg.get("itens", MERCADORIAS): lista.append([id, 1, int(Bolsa.ITENS[id].compra), -1])
	else:
		for k in m.bolsa.recompra.size():
			var r: Array = m.bolsa.recompra[k]; lista.append([r[0], r[1], r[2], k])
	var paginas := maxi(1, int(ceil(lista.size() / 10.0)))
	_pagina = clampi(_pagina, 0, paginas - 1)
	_rodape.text = "Página %d de %d" % [_pagina + 1, paginas]
	for n in 10:
		var idx := _pagina * 10 + n
		_grade.add_child(_celula(lista[idx] if idx < lista.size() else []))

# uma mercadoria: espaço com o ícone, nome (cor da qualidade) e preço — tocar compra
func _celula(it: Array) -> Control:
	var c := PanelContainer.new(); c.custom_minimum_size = Vector2(400, 100)
	c.add_theme_stylebox_override("panel", UI.estilo(Color(0.12, 0.1, 0.08, 0.85), Color(0.25, 0.21, 0.16), 6, 8, 2))
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 12); c.add_child(h)
	if it.is_empty():
		h.add_child(UI.espaco("", 0, 80.0)); return c
	var id: String = it[0]; var info := Bolsa.info(id)
	var e := UI.espaco(id, it[1], 80.0); e.mouse_filter = Control.MOUSE_FILTER_IGNORE; h.add_child(e)
	var v := VBoxContainer.new(); v.alignment = BoxContainer.ALIGNMENT_CENTER; h.add_child(v)
	var nome := UI.rotulo(info.nome, 22, Bolsa.CORES[info.qual]); nome.custom_minimum_size = Vector2(280, 0)
	nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(nome)
	var preco: int = it[2]
	var pode: bool = m.bolsa.cobre >= preco
	if Bolsa.eh_montaria(id) and m.bolsa.tem_montaria(id): v.add_child(UI.rotulo("Já é sua", 22, Color(0.6, 0.9, 0.5)))
	else:
		var d := UI.dinheiro(preco, 22, UI.TEXTO if pode else Color(1, 0.3, 0.3))   # só o número fica vermelho
		v.add_child(d)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.gui_input.connect(func(ev):
		if (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or (ev is InputEventScreenTouch and ev.pressed):
			_comprar(it))
	return c

func _comprar(it: Array) -> void:
	var erro := ""
	if it[3] >= 0: erro = m.bolsa.recomprar(it[3])
	else: erro = m.bolsa.comprar(it[0])
	if erro != "": m.hud.avisar(erro, Color(1, 0.35, 0.3)); return
	m.hud.avisar("Comprou: %s" % Bolsa.ITENS[it[0]].nome, Color(1, 1, 1))
	if Bolsa.eh_montaria(it[0]): m.hud.avisar("Está na sua bolsa: toque duas vezes nele para aprender a montaria.", Color(0.12, 1.0, 0.0))
	var fc: Array = cfg.get("falas_compra", FALAS_COMPRA)
	if it[3] < 0: m.interacao._fala_npc(cfg.get("nome", "Bram"), fc[randi() % fc.size()])

func vender(k: int, i: int) -> void:
	var s = m.bolsa.slot(k, i)
	if s == null: return
	var ganho: int = m.bolsa.vender_slot(k, i)
	if ganho > 0:
		m.hud.avisar("Vendeu %s: +%s" % [Bolsa.ITENS[s[0]].nome, Bolsa.texto_dinheiro(ganho)], Color(0.95, 0.75, 0.4))
		var fv: Array = cfg.get("falas_venda", FALAS_VENDA)
		m.interacao._fala_npc(cfg.get("nome", "Bram"), fv[randi() % fv.size()])

# retrato do vendedor tirado do modelo dele (como o da Rachel no HUD)
func _tirar_retrato() -> void:
	var vp := SubViewport.new(); vp.size = Vector2i(160, 160); vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS; vp.own_world_3d = true; add_child(vp)
	var mod: Node3D = load("res://assets/modelos/ferreiro.glb").instantiate(); vp.add_child(mod)
	mod.rotation_degrees.y = -90
	var luz := DirectionalLight3D.new(); luz.rotation_degrees = Vector3(-25, 35, 0); luz.light_energy = 1.1; vp.add_child(luz)
	var amb := WorldEnvironment.new(); var env := Environment.new(); env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.75, 0.72, 0.8); env.ambient_light_energy = 0.8
	amb.environment = env; vp.add_child(amb)
	var cam := Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = 0.24
	cam.position = Vector3(0.0, 0.875, 1.0); vp.add_child(cam); cam.current = true
	for n in mod.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n
		var orig: BaseMaterial3D = mi.mesh.surface_get_material(0)
		if orig:
			var mt := orig.duplicate() as BaseMaterial3D; mt.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			mi.material_override = mt
	for k in 4: await RenderingServer.frame_post_draw
	_retrato_bram = ImageTexture.create_from_image(vp.get_texture().get_image())
	if cfg.is_empty(): _retrato = _retrato_bram
	vp.queue_free()
	if _foto: _foto.queue_redraw()

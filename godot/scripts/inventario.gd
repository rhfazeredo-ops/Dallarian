# Inventário no estilo do WoW: janelas das bolsas empilhadas no canto direito (de baixo para cima, e uma
# coluna nova à esquerda quando não cabe), barra com os 3 lugares de bolsa e o dinheiro embaixo.
# Tocar num item mostra a dica (nome na cor da qualidade, descrição, preço de venda) com EQUIPAR (bolsas)
# ou VENDER (com a loja aberta). Abre pelo botão de inventário (PC: tecla I ou B).
extends Control
class_name Inventario

const TAM := 84.0               # tamanho de um espaço
const GAP := 6.0
var m
var aberto := false
var modo_venda := false          # loja aberta: a dica mostra VENDER
var _janelas: Control
var _dica: PanelContainer
var _botao: BotaoAcao
var _tecla_antes := false

func montar(mundo) -> void:
	m = mundo
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter = Control.MOUSE_FILTER_IGNORE
	_janelas = Control.new(); _janelas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_janelas.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(_janelas)
	_botao = BotaoAcao.criar("inventario", 112)
	_botao.anchor_left = 1; _botao.anchor_right = 1
	_botao.offset_left = -150; _botao.offset_right = -38; _botao.offset_top = 182; _botao.offset_bottom = 294
	_botao.apertou.connect(alternar); add_child(_botao)
	m.bolsa.mudou.connect(func(): if aberto: _refazer())

func alternar() -> void:
	if aberto: fechar()
	else: abrir()

func abrir(venda := false) -> void:
	aberto = true; modo_venda = venda; _refazer()
	m.controles.set_process_input(false); m.controles.dir = Vector2.ZERO

func fechar() -> void:
	aberto = false; modo_venda = false; _esconder_dica()
	for c in _janelas.get_children(): c.queue_free()
	if not (m.loja_ui and m.loja_ui.aberta): m.controles.set_process_input(true)

func _process(_d: float) -> void:
	var t := Input.is_key_pressed(KEY_I) or Input.is_key_pressed(KEY_B)
	if t and not _tecla_antes: alternar()
	_tecla_antes = t

# ---------- montagem das janelas ----------
func _colunas(n: int) -> int: return 4 if n <= 16 else (5 if n <= 30 else 8)

func _refazer() -> void:
	_esconder_dica()
	for c in _janelas.get_children(): c.queue_free()
	var tela := get_viewport_rect().size
	var x_dir := tela.x - 24.0; var y_base := tela.y - 24.0
	# barra de baixo: dinheiro + 3 lugares de bolsa + fechar
	var barra := UI.janela(); _janelas.add_child(barra)
	var hb := HBoxContainer.new(); hb.add_theme_constant_override("separation", 10); barra.add_child(hb)
	# equipamento (arma e escudo) — tocar mostra os status
	for lugar in ["arma", "escudo"]:
		var eid: String = m.bolsa.equip.get(lugar, "")
		var se := UI.espaco(eid, 0, 70.0)
		se.gui_input.connect(func(e): if _toque(e) and eid != "": _mostrar_dica(eid, 1, se, [], true))
		hb.add_child(se)
	var esp0 := Control.new(); esp0.custom_minimum_size = Vector2(10, 0); hb.add_child(esp0)
	hb.add_child(UI.dinheiro(m.bolsa.cobre, 28))
	var esp := Control.new(); esp.custom_minimum_size = Vector2(16, 0); hb.add_child(esp)
	for k in Bolsa.MAX_BOLSAS:
		var b = m.bolsa.bolsas[k]
		var s := UI.espaco(b.id if b else "", 0, 70.0, UI.icone("bolsa_10"))
		s.gui_input.connect(func(e): if _toque(e): _dica_bolsa_equipada(k, s))
		hb.add_child(s)
	hb.add_child(UI.botao_fechar(fechar))
	barra.reset_size()
	var tb := barra.get_combined_minimum_size()
	barra.position = Vector2(x_dir - tb.x, y_base - tb.y)
	# bolsas: a primeira em baixo (logo acima da barra), as outras por cima; coluna nova à esquerda se faltar altura
	var y := y_base - tb.y - 10.0; var x := x_dir; var larg_col := 0.0
	for k in Bolsa.MAX_BOLSAS:
		var b = m.bolsa.bolsas[k]
		if b == null: continue
		var j := _janela_bolsa(k, b)
		var t := j.get_combined_minimum_size()
		if y - t.y < 110.0:
			x -= larg_col + 12.0; y = y_base - tb.y - 10.0; larg_col = 0.0
		j.position = Vector2(x - t.x, y - t.y); y -= t.y + 10.0; larg_col = maxf(larg_col, t.x)

func _janela_bolsa(k: int, b: Dictionary) -> PanelContainer:
	var j := UI.janela(); _janelas.add_child(j)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 8); j.add_child(v)
	var info := Bolsa.info(b.id)
	var topo := HBoxContainer.new(); v.add_child(topo)
	var ic := TextureRect.new(); ic.texture = UI.icone(b.id); ic.custom_minimum_size = Vector2(40, 40)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	topo.add_child(ic)
	var tit := UI.rotulo(info.nome, 24, Bolsa.CORES[info.qual]); tit.size_flags_horizontal = Control.SIZE_EXPAND_FILL; topo.add_child(tit)
	var g := GridContainer.new(); g.columns = _colunas(b.slots.size())
	g.add_theme_constant_override("h_separation", int(GAP)); g.add_theme_constant_override("v_separation", int(GAP)); v.add_child(g)
	for i in b.slots.size():
		var s = b.slots[i]
		var e := UI.espaco(s[0] if s != null else "", int(s[1]) if s != null else 0, TAM)
		e.gui_input.connect(func(ev): if _toque(ev): _tocar(k, i, e))
		g.add_child(e)
	return j

func _toque(e: InputEvent) -> bool:
	return (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed)

func usar_montaria(k: int, i: int) -> void:
	var id: String = m.bolsa.aprender_montaria(k, i)
	if id == "": return
	m.hud.avisar("Montaria adquirida: %s" % Bolsa.ITENS[id].nome, Color(0.12, 1.0, 0.0))
	m.hud.anunciar("MONTARIA ADQUIRIDA", Bolsa.ITENS[id].nome)
	m.bolsa.salvar(m.hud.nivel, m.hud.xp)

# ---------- dica (tooltip) ----------
func _esconder_dica() -> void:
	if _dica: _dica.queue_free(); _dica = null

var _ultimo_toque := [-1, -1, 0]       # bolsa, espaço, quando (para o toque duplo)
func _tocar(k: int, i: int, alvo: Control) -> void:
	var s = m.bolsa.slot(k, i)
	if s == null: _esconder_dica(); return
	var id: String = s[0]; var info := Bolsa.info(id)
	var agora := Time.get_ticks_msec()
	var duplo: bool = _ultimo_toque[0] == k and _ultimo_toque[1] == i and agora - int(_ultimo_toque[2]) < 450
	_ultimo_toque = [k, i, agora]
	if Bolsa.eh_montaria(id) and duplo and not modo_venda:       # toque duplo no cavalo: vira montaria
		_esconder_dica(); usar_montaria(k, i); return
	var botoes := []
	if modo_venda: botoes.append(UI.botao("VENDER", func(): m.loja_ui.vender(k, i); _esconder_dica()))
	if Bolsa.lugar_equip(id) != "": botoes.append(UI.botao("EQUIPAR", func():
		var erro: String = m.bolsa.equipar_item(k, i, m.hud.nivel)
		if erro != "": m.hud.avisar(erro, Color(1, 0.35, 0.3))
		_esconder_dica()))
	if info.has("cura"): botoes.append(UI.botao("CONSUMIR", func():
		var cura: int = m.bolsa.consumir(k, i)
		if cura > 0:
			var antes: float = m.hud.vida
			m.hud.vida = minf(m.hud.vida + cura, m.hud.vida_max)
			m.hud.numero_heroi("+%d" % int(round(m.hud.vida - antes)), Color(0.3, 1.0, 0.3))
		var s2 = m.bolsa.slot(k, i)
		if s2 == null: _esconder_dica()
		else: _tocar(k, i, alvo)))
	if Bolsa.eh_bolsa(id): botoes.append(UI.botao("EQUIPAR", func():
		var erro: String = m.bolsa.equipar_bolsa(k, i)
		if erro != "": m.hud.avisar(erro, Color(1, 0.35, 0.3))
		_esconder_dica()))
	_mostrar_dica(id, int(s[1]), alvo, botoes)

func _dica_bolsa_equipada(k: int, alvo: Control) -> void:
	var b = m.bolsa.bolsas[k]
	if b == null:
		_mostrar_texto("Lugar de bolsa vazio", "Compre uma bolsa e toque em EQUIPAR para usar até 3 bolsas.", alvo); return
	_mostrar_dica(b.id, 1, alvo, [UI.botao("TIRAR", func():
		var erro: String = m.bolsa.desequipar_bolsa(k)
		if erro != "": m.hud.avisar(erro, Color(1, 0.35, 0.3))
		_esconder_dica())], true)

func _linha_dupla(a: String, b: String) -> HBoxContainer:
	var h := HBoxContainer.new(); h.custom_minimum_size = Vector2(380, 0)
	var la := UI.rotulo(a, 21); la.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(la)
	h.add_child(UI.rotulo(b, 21)); return h

func _mostrar_texto(titulo: String, texto: String, alvo: Control) -> void:
	_esconder_dica()
	_dica = _caixa_dica()
	var v: VBoxContainer = _dica.get_child(0)
	v.add_child(UI.rotulo(titulo, 26))
	var l := UI.rotulo(texto, 22, UI.AMARELO); l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; l.custom_minimum_size = Vector2(380, 0); v.add_child(l)
	_posicionar(alvo)

func _caixa_dica() -> PanelContainer:
	var d := PanelContainer.new()
	d.add_theme_stylebox_override("panel", UI.estilo(Color(0.04, 0.05, 0.12, 0.96), Color(0.7, 0.7, 0.75), 8, 18, 3))   # azul-escuro das dicas do WoW
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 6); d.add_child(v)
	add_child(d)
	return d

func _mostrar_dica(id: String, qtd: int, alvo: Control, botoes: Array, equipada := false) -> void:
	_esconder_dica()
	var info := Bolsa.info(id)
	_dica = _caixa_dica()
	var v: VBoxContainer = _dica.get_child(0)
	v.add_child(UI.rotulo(info.nome, 28, Bolsa.CORES[info.qual]))
	if Bolsa.eh_bolsa(id): v.add_child(UI.rotulo("Bolsa de %d espaços%s" % [info.espacos, "  (equipada)" if equipada else ""], 22))
	if info.get("tipo", "") == "arma":
		v.add_child(_linha_dupla(info.maos, info.subtipo))
		v.add_child(_linha_dupla("%d - %d de dano" % [info.dano_min, info.dano_max], "Velocidade %.2f" % info.velocidade))
		v.add_child(UI.rotulo("(%.1f de dano por segundo)" % ((info.dano_min + info.dano_max) * 0.5 / info.velocidade), 21))
	elif info.get("tipo", "") == "escudo":
		v.add_child(_linha_dupla("Mão secundária", info.subtipo))
		v.add_child(UI.rotulo("%d de armadura" % info.armadura, 21))
		v.add_child(UI.rotulo("%d de bloqueio" % info.bloqueio, 21))
		v.add_child(UI.rotulo("Equipar: segurando o escudo, bloqueia %d%% do dano." % int(info.bloqueio_ativo * 100), 20, Color(0.12, 1.0, 0.0)))
	if info.has("nivel") and int(info.nivel) > 1:
		v.add_child(UI.rotulo("Requer nível %d" % info.nivel, 21, Color(1, 1, 1) if m.hud.nivel >= int(info.nivel) else Color(1, 0.3, 0.3)))
	if equipada and info.has("tipo"): v.add_child(UI.rotulo("(equipado)", 20, Color(0.7, 0.7, 0.7)))
	if info.pilha > 1: v.add_child(UI.rotulo("Pilha: %d / %d" % [qtd, info.pilha], 20, Color(0.8, 0.8, 0.8)))
	if Bolsa.eh_montaria(id): v.add_child(UI.rotulo("Toque duas vezes para aprender esta montaria.", 20, Color(0.12, 1.0, 0.0)))
	if info.has("cura"): v.add_child(UI.rotulo("Usar: recupera %d de vida." % int(info.cura), 20, Color(0.12, 1.0, 0.0)))
	var d := UI.rotulo("\"%s\"" % info.desc, 21, UI.AMARELO); d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(380, 0); v.add_child(d)
	var pv := HBoxContainer.new(); pv.add_child(UI.rotulo("Preço de venda: ", 21))
	pv.add_child(UI.dinheiro(int(info.venda) * maxi(qtd, 1), 21)); v.add_child(pv)
	if not botoes.is_empty():
		var hb := HBoxContainer.new(); hb.add_theme_constant_override("separation", 10); v.add_child(hb)
		for b in botoes: hb.add_child(b)
	_posicionar(alvo)

func _posicionar(alvo: Control) -> void:
	_dica.reset_size()
	var t := _dica.get_combined_minimum_size()
	var r := alvo.get_global_rect()
	var p := Vector2(r.position.x - t.x - 12.0, r.position.y - t.y * 0.5)
	var tela := get_viewport_rect().size
	if p.x < 10.0: p.x = r.end.x + 12.0
	p.y = clampf(p.y, 10.0, tela.y - t.y - 10.0)
	_dica.position = p

# Montarias no estilo do WoW: botão da ferradura (perto do escudo) chama a montaria escolhida — aparece uma barra
# de "Montando..." de 1,5 s (andar, atacar ou apertar de novo cancela) e, ao terminar, a Rachel já está em cima do
# cavalo. Apertar de novo desmonta na hora. PC: tecla V monta/desmonta, C abre o menu do personagem.
# O menu do personagem (botão ao lado do mapa e da bolsa) tem as abas PERSONAGEM e MONTARIAS; tocar numa
# montaria a escolhe para o botão.
extends Control
class_name Montaria

const TEMPO := 1.5
var m
var _botao: BotaoAcao
var _botao_menu: BotaoAcao
var _cast := -1.0                  # >= 0: carregando
var _janela: PanelContainer
var aberto := false
var _aba := "montarias"
var _conteudo: VBoxContainer
var _abas := {}
var _v_antes := false
var _c_antes := false
var _pos_cast := Vector3.ZERO

func montar(mundo) -> void:
	m = mundo
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter = Control.MOUSE_FILTER_IGNORE
	_botao = BotaoAcao.criar("montaria", 120)
	_botao.anchor_left = 1; _botao.anchor_top = 1; _botao.anchor_right = 1; _botao.anchor_bottom = 1
	_botao.offset_left = -760; _botao.offset_top = -170; _botao.offset_right = -640; _botao.offset_bottom = -50
	_botao.apertou.connect(alternar_montaria); add_child(_botao)
	_botao_menu = BotaoAcao.criar("personagem", 112)
	_botao_menu.anchor_left = 1; _botao_menu.anchor_right = 1
	_botao_menu.offset_left = -390; _botao_menu.offset_right = -278; _botao_menu.offset_top = 182; _botao_menu.offset_bottom = 294
	_botao_menu.apertou.connect(alternar_menu); add_child(_botao_menu)

# ---------- montar / desmontar ----------
func alternar_montaria() -> void:
	var j: Jogador = m.jogador
	if j.montado: j.desmontar(); return
	if _cast >= 0.0: cancelar(); return
	if m.bolsa.montarias.is_empty():
		m.hud.avisar("Você ainda não tem montaria. Compre um cavalo no estábulo de Altamar.", Color(1, 0.75, 0.4)); return
	if m.bolsa.montaria_sel == "": m.bolsa.montaria_sel = m.bolsa.montarias[0]
	if not j.is_on_floor(): m.hud.avisar("Não dá para montar no ar.", Color(1, 0.35, 0.3)); return
	_cast = 0.0; _pos_cast = j.global_position
	queue_redraw()

func cancelar() -> void:
	if _cast < 0.0: return
	_cast = -1.0; m.hud.avisar("Interrompido", Color(1, 0.35, 0.3)); queue_redraw()

func _process(delta: float) -> void:
	if m == null: return
	var v := Input.is_key_pressed(KEY_V)
	if v and not _v_antes: alternar_montaria()
	_v_antes = v
	var c := Input.is_key_pressed(KEY_C)
	if c and not _c_antes: alternar_menu()
	_c_antes = c
	if _cast >= 0.0:
		var j: Jogador = m.jogador
		var mexeu := Vector2(j.global_position.x - _pos_cast.x, j.global_position.z - _pos_cast.z).length() > 0.25
		if mexeu or m.controles.atacando() or not j.is_on_floor(): cancelar(); return
		_cast += delta
		if _cast >= TEMPO:
			_cast = -1.0; j.montar_em(m.bolsa.montaria_sel, m.cavalo(m.bolsa.montaria_sel)); queue_redraw()
		queue_redraw()

# barra de carregar no estilo do WoW: moldura escura, preenchimento dourado, nome da montaria
func _draw() -> void:
	if _cast < 0.0: return
	var tela := get_viewport_rect().size
	var w := 620.0; var h := 44.0
	var r := Rect2(Vector2((tela.x - w) * 0.5, tela.y - 330.0), Vector2(w, h))
	draw_rect(r.grow(6.0), Color(0, 0, 0, 0.75))
	draw_rect(r.grow(3.0), Color(0.55, 0.45, 0.28))
	draw_rect(r, Color(0.08, 0.07, 0.06))
	var f := clampf(_cast / TEMPO, 0.0, 1.0)
	draw_rect(Rect2(r.position, Vector2(w * f, h)), Color(0.95, 0.72, 0.15))
	draw_rect(Rect2(r.position, Vector2(w * f, h * 0.35)), Color(1.0, 0.88, 0.45, 0.6))
	var fonte := get_theme_default_font()
	var nome: String = Bolsa.ITENS[m.bolsa.montaria_sel].nome if m.bolsa.montaria_sel != "" else ""
	var txt := "Montando: " + nome
	var tam := 28
	var ts := fonte.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam)
	var p := r.position + Vector2((w - ts.x) * 0.5, h * 0.5 + ts.y * 0.32)
	draw_string_outline(fonte, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, 7, Color.BLACK)
	draw_string(fonte, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, Color.WHITE)

# ---------- menu do personagem ----------
func alternar_menu() -> void:
	if aberto: fechar_menu()
	else: abrir_menu()

func abrir_menu(aba := "") -> void:
	if aba != "": _aba = aba
	aberto = true
	if _janela == null: _montar_menu()
	_janela.visible = true; _atualizar()
	m.controles.set_process_input(false); m.controles.dir = Vector2.ZERO

func fechar_menu() -> void:
	aberto = false
	if _janela: _janela.visible = false
	m.controles.set_process_input(true)

func _montar_menu() -> void:
	_janela = UI.janela(); add_child(_janela)
	_janela.position = Vector2(60, 110)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 12); _janela.add_child(v)
	var topo := HBoxContainer.new(); topo.add_theme_constant_override("separation", 14); v.add_child(topo)
	var t := UI.rotulo("Rachel", 36, UI.AMARELO); t.size_flags_horizontal = Control.SIZE_EXPAND_FILL; topo.add_child(t)
	topo.add_child(UI.botao_fechar(fechar_menu))
	_conteudo = VBoxContainer.new(); _conteudo.add_theme_constant_override("separation", 10)
	_conteudo.custom_minimum_size = Vector2(760, 470); v.add_child(_conteudo)
	var baixo := HBoxContainer.new(); baixo.add_theme_constant_override("separation", 12); v.add_child(baixo)
	for aba in ["personagem", "montarias"]:
		var b := UI.botao(aba.to_upper(), func(): _aba = aba; _atualizar(), true, 22, 200.0)
		_abas[aba] = b; baixo.add_child(b)
	m.bolsa.mudou.connect(func(): if aberto: _atualizar())

func _atualizar() -> void:
	for c in _conteudo.get_children(): c.queue_free()
	for aba in _abas.keys():
		var b: Button = _abas[aba]; b.modulate = Color(1, 1, 1) if aba == _aba else Color(0.6, 0.6, 0.6)
	if _aba == "personagem":
		_conteudo.add_child(UI.rotulo("Nível %d" % m.hud.nivel, 30, UI.TEXTO))
		_conteudo.add_child(UI.rotulo("Vida: %d / %d" % [m.hud.vida, m.hud.vida_max], 26, Color(0.62, 0.92, 0.36)))
		for lugar in ["arma", "escudo"]:
			var id: String = m.bolsa.equip.get(lugar, "")
			var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 12); _conteudo.add_child(h)
			var e := UI.espaco(id, 1, 80.0); e.mouse_filter = Control.MOUSE_FILTER_IGNORE; h.add_child(e)
			var nome: String = "(nada)" if id == "" else Bolsa.ITENS[id].nome
			var cor: Color = UI.TEXTO if id == "" else Bolsa.CORES[Bolsa.ITENS[id].qual]
			h.add_child(UI.rotulo(("Arma: " if lugar == "arma" else "Escudo: ") + nome, 26, cor))
		var mt: String = m.bolsa.montaria_sel
		_conteudo.add_child(UI.rotulo("Montaria: " + ("nenhuma" if mt == "" else Bolsa.ITENS[mt].nome), 26, UI.TEXTO))
		return
	# montarias: lista das que a Rachel tem; tocar escolhe (a escolhida fica com moldura dourada)
	if m.bolsa.montarias.is_empty():
		var l := UI.rotulo("Nenhuma montaria ainda.\nO cavalariço Edric vende cavalos no estábulo, logo depois do portão oeste de Altamar.", 26, Color(0.85, 0.82, 0.75))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; l.custom_minimum_size = Vector2(740, 0); _conteudo.add_child(l)
		return
	_conteudo.add_child(UI.rotulo("Toque para escolher. Use o botão da ferradura para montar.", 22, Color(0.8, 0.78, 0.7)))
	for id in m.bolsa.montarias:
		var sel: bool = id == m.bolsa.montaria_sel
		var c := PanelContainer.new(); c.custom_minimum_size = Vector2(740, 100)
		c.add_theme_stylebox_override("panel", UI.estilo(Color(0.18, 0.15, 0.08, 0.9) if sel else Color(0.12, 0.1, 0.08, 0.85),
			UI.DOURADO if sel else Color(0.25, 0.21, 0.16), 6, 8, 3 if sel else 2))
		var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 14); c.add_child(h)
		var e := UI.espaco(id, 1, 80.0); e.mouse_filter = Control.MOUSE_FILTER_IGNORE; h.add_child(e)
		var vv := VBoxContainer.new(); vv.alignment = BoxContainer.ALIGNMENT_CENTER; h.add_child(vv)
		vv.add_child(UI.rotulo(Bolsa.ITENS[id].nome + ("  (escolhida)" if sel else ""), 26, Bolsa.CORES[Bolsa.ITENS[id].qual]))
		vv.add_child(UI.rotulo(Bolsa.ITENS[id].desc, 20, Color(0.85, 0.82, 0.75)))
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		c.gui_input.connect(func(ev):
			if (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or (ev is InputEventScreenTouch and ev.pressed):
				_escolher(id))
		_conteudo.add_child(c)

func _escolher(id: String) -> void:
	m.bolsa.montaria_sel = id; m.bolsa.salvar(m.hud.nivel, m.hud.xp)
	if m.jogador.montado: m.jogador.desmontar(); m.jogador.montar_em(id, m.cavalo(id))     # troca de cavalo na hora
	_atualizar()

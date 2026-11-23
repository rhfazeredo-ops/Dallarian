# Saque estilo WoW: o monstro morto fica no chão por 3 minutos com o que deixou cair. Com a mira (meio da tela)
# nele, perto, ganha um contorno branco; tocar no corpo (PC: tecla E) abre uma janelinha com os itens:
# tocar num item passa ele para a bolsa, PEGAR TUDO passa todos, X fecha e deixa o resto lá.
# Depois de 3 minutos o corpo afunda no chão e some, junto com o que sobrou.
extends Control
class_name Saque

const DURACAO := 180.0            # segundos que o corpo fica no chão
const ALCANCE := 5.0              # distância para mirar/saquear (m)
const CONTORNOS := {
	"res://shaders/lobo.gdshader": "res://shaders/lobo_contorno.gdshader",
	"res://shaders/aranha.gdshader": "res://shaders/aranha_contorno.gdshader",
	"res://shaders/npc.gdshader": "res://shaders/npc_contorno.gdshader",
}
var m
var alvo: Node3D = null            # corpo na mira (com contorno)
var aberto: Node3D = null          # corpo com a janela aberta
var _janela: PanelContainer
var _dica: Label
var _e_antes := false
var _toques := {}                  # dedo → [posição, quando]
var _t_limpa := 0.0

func montar(mundo) -> void:
	m = mundo
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dica = UI.rotulo("", 22, Color(1, 1, 1, 0.9)); _dica.visible = false
	_dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; add_child(_dica)

# chamado quando um monstro morre: guarda o saque nele e começa a contar os 3 minutos
func registrar(mo: Node3D, itens: Array) -> void:
	mo.set_meta("saque", itens); mo.set_meta("morte_t", Time.get_ticks_msec() / 1000.0)
	mo.add_to_group("cadaveres")

# sorteia [[id, chance, mín, máx], ...] → [[id, qtd], ...]
static func sortear(drops: Array) -> Array:
	var r := []
	for d in drops:
		if randf() <= d[1]: r.append([d[0], randi_range(d[2], d[3])])
	return r

static func nome_de(mo: Node) -> String:
	if mo is Lobo: return ("Líder da matilha" if mo.lider else "Lobo %s" % mo.tipo)
	if mo is Aranha: return "Aranha-musgo"
	if mo is Monstro:
		if mo.nome != "": return mo.nome
		if mo.tipo == "golem": return "Grumo, o Guardião do Vale"
		return {"lodoso_j": "Lodoso Jovem", "lodoso_g": "Lodoso Pescador", "lodoso_x": "Xamã da Lama", "lodoso_c": "Grão-Lodoso"}.get(mo.tipo, "Lodoso")
	return "Monstro"

func _tem_saque(mo) -> bool:
	return is_instance_valid(mo) and mo.is_inside_tree() and not mo.has_meta("sumindo") and (mo.get_meta("saque", []) as Array).size() > 0

func _process(delta: float) -> void:
	var agora := Time.get_ticks_msec() / 1000.0
	# corpos velhos afundam e somem (com o que sobrou)
	_t_limpa -= delta
	if _t_limpa <= 0.0:
		_t_limpa = 1.0
		for c in get_tree().get_nodes_in_group("cadaveres"):
			if not c.has_meta("sumindo") and agora - float(c.get_meta("morte_t", agora)) > DURACAO: _sumir(c)
	# qual corpo está na mira
	var novo := _procurar(agora)
	if novo != alvo:
		_contorno(alvo, false); alvo = novo
	if alvo: _contorno(alvo, true)
	_mostrar_dica()
	# PC: E saqueia
	var e := Input.is_key_pressed(KEY_E)
	if e and not _e_antes and alvo and aberto == null: abrir(alvo)
	_e_antes = e
	# janela aberta: fecha se o corpo sumiu ou a Rachel se afastou
	if aberto:
		if not is_instance_valid(aberto) or aberto.has_meta("sumindo") or _dist(aberto) > _alcance(aberto) + 2.0: fechar()

func _alcance(mo: Node) -> float:                # o golem é gigante: dá para saquear de mais longe
	return ALCANCE * (2.0 if mo is Monstro and mo.tipo == "golem" else 1.0)

func _dist(mo: Node3D) -> float:
	var p: Vector3 = m.jogador.global_position; var q := mo.global_position
	return Vector2(p.x - q.x, p.z - q.z).length()

func _centro(mo: Node3D) -> Vector3:
	return mo.global_position + Vector3(0, 0.35, 0)

func _procurar(agora: float) -> Node3D:
	if m.heroina_desmaiada: return null
	var cam: Camera3D = m.jogador.cam
	var tela: Vector2 = get_viewport_rect().size
	var melhor: Node3D = null; var mel := 1e9
	for c in get_tree().get_nodes_in_group("cadaveres"):
		if not _tem_saque(c) or agora - float(c.get_meta("morte_t", agora)) < 1.5: continue
		var d := _dist(c)
		if d > _alcance(c): continue
		var p3 := _centro(c)
		if cam.is_position_behind(p3): continue
		var p: Vector2 = cam.unproject_position(p3) * m.hud.escala_3d
		var desvio := p.distance_to(tela * 0.5) / tela.y          # 0 = bem no meio da tela
		if desvio > 0.3: continue
		var nota := desvio * 3.0 + d * 0.1
		if nota < mel: mel = nota; melhor = c
	return melhor

# ---------- contorno branco ----------
func _materiais(mo: Node) -> Array:
	var r := []
	for mi in mo.find_children("*", "MeshInstance3D", true, false):
		var sm = mi.material_override
		if sm is ShaderMaterial and sm.shader and CONTORNOS.has(sm.shader.resource_path): r.append(sm)
	return r

func _contorno(mo, ligar: bool) -> void:
	if mo == null or not is_instance_valid(mo): return
	for sm: ShaderMaterial in _materiais(mo):
		if not ligar: sm.next_pass = null; continue
		var cm: ShaderMaterial = sm.next_pass
		if cm == null:
			cm = ShaderMaterial.new(); cm.shader = load(CONTORNOS[sm.shader.resource_path]); sm.next_pass = cm
		for u in sm.shader.get_shader_uniform_list():         # mesma pose do corpo
			cm.set_shader_parameter(u.name, sm.get_shader_parameter(u.name))

func _mostrar_dica() -> void:
	_dica.visible = alvo != null and aberto == null
	if not _dica.visible: return
	var toque := OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	_dica.text = "Toque no corpo para saquear" if toque else "E  Saquear"
	var tela := get_viewport_rect().size
	_dica.reset_size(); _dica.position = Vector2(tela.x * 0.5 - _dica.size.x * 0.5, tela.y * 0.5 + 40.0)

# ---------- toque no corpo ----------
func _input(ev: InputEvent) -> void:
	if alvo == null or aberto != null: return
	var toque := OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	if ev is InputEventScreenTouch:
		if ev.pressed: _toques[ev.index] = [ev.position, Time.get_ticks_msec()]
		elif _toques.has(ev.index):
			var t: Array = _toques[ev.index]; _toques.erase(ev.index)
			if ev.position.distance_to(t[0]) < 30.0 and Time.get_ticks_msec() - int(t[1]) < 400 and _no_corpo(ev.position): abrir(alvo)
	elif not toque and ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and _no_corpo(ev.position):
		abrir(alvo)

func _no_corpo(pos: Vector2) -> bool:
	var cam: Camera3D = m.jogador.cam
	var c := _centro(alvo)
	var p: Vector2 = cam.unproject_position(c) * m.hud.escala_3d
	var lado: Vector2 = cam.unproject_position(c + cam.global_transform.basis.x) * m.hud.escala_3d
	var raio := maxf(90.0, p.distance_to(lado) * 1.1)          # ~1,1 m em volta do corpo
	return pos.distance_to(p) < raio

# ---------- janelinha do saque ----------
func abrir(mo: Node3D) -> void:
	if not _tem_saque(mo): return
	aberto = mo; _refazer()
	m.controles.set_process_input(false); m.controles.dir = Vector2.ZERO

func fechar() -> void:
	aberto = null
	if _janela: _janela.queue_free(); _janela = null
	if not (m.inventario.aberto or (m.loja_ui and m.loja_ui.aberta)): m.controles.set_process_input(true)

func _refazer() -> void:
	if _janela: _janela.queue_free(); _janela = null
	var itens: Array = aberto.get_meta("saque", [])
	if itens.is_empty(): fechar(); return
	_janela = UI.janela(); add_child(_janela)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 10); _janela.add_child(v)
	var topo := HBoxContainer.new(); v.add_child(topo)
	var tit := UI.rotulo(nome_de(aberto), 24, Color(1.0, 0.82, 0.2)); tit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(tit)
	topo.add_child(UI.botao_fechar(fechar))
	for i in itens.size():
		var it: Array = itens[i]
		var linha := HBoxContainer.new(); linha.add_theme_constant_override("separation", 10); v.add_child(linha)
		var esp := UI.espaco(it[0], it[1], 72.0)
		var info: Dictionary = Bolsa.ITENS[it[0]]
		var nome := UI.rotulo(info.nome, 20, Bolsa.CORES[info.qual]); nome.custom_minimum_size = Vector2(230, 0)
		nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; nome.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		nome.mouse_filter = Control.MOUSE_FILTER_STOP
		linha.add_child(esp); linha.add_child(nome)
		esp.gui_input.connect(func(e): if _toque(e): pegar(i))
		nome.gui_input.connect(func(e): if _toque(e): pegar(i))
	v.add_child(UI.botao("PEGAR TUDO", pegar_tudo, true, 24, 300.0))
	_janela.reset_size()
	var tela := get_viewport_rect().size; var t := _janela.get_combined_minimum_size()
	_janela.position = Vector2(tela.x * 0.5 + 60.0, clampf(tela.y * 0.5 - t.y * 0.5, 90.0, tela.y - t.y - 20.0))

func _toque(e: InputEvent) -> bool:
	return (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed)

# passa um item para a bolsa (o que não couber fica no corpo)
func pegar(i: int) -> bool:
	if aberto == null or not is_instance_valid(aberto): return false
	var itens: Array = aberto.get_meta("saque", [])
	if i >= itens.size(): return false
	var it: Array = itens[i]
	var sobra: int = m.bolsa.pegar(it[0], it[1])
	var info: Dictionary = Bolsa.ITENS[it[0]]
	if it[1] - sobra > 0: m.hud.avisar("+%d %s" % [it[1] - sobra, info.nome], Bolsa.CORES[info.qual])
	if sobra > 0:
		it[1] = sobra; m.hud.avisar("Suas bolsas estão cheias!", Color(1, 0.35, 0.3))
	else: itens.remove_at(i)
	aberto.set_meta("saque", itens)
	if itens.is_empty(): _contorno(aberto, false); fechar()
	else: _refazer()
	return sobra == 0

func pegar_tudo() -> void:
	if aberto == null: return
	var i := 0
	while aberto != null and i < (aberto.get_meta("saque", []) as Array).size():
		if not pegar(i): i += 1                  # não coube: fica e passa para o próximo

func _sumir(c: Node3D) -> void:
	c.set_meta("sumindo", true); c.remove_from_group("cadaveres")
	if c == alvo: _contorno(c, false); alvo = null
	var vis: Node3D = c.get("visual") if c.get("visual") is Node3D else c
	var tw := c.create_tween()
	tw.tween_property(vis, "position:y", vis.position.y - 1.2, 3.0)
	tw.tween_callback(c.queue_free)

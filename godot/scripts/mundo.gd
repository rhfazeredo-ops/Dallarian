# Dallarian — a região inicial (1,2 × 1,2 km, scripts/regiao.gd), vista em primeira pessoa.
# Limites naturais: montanhas ao norte (com um desfiladeiro fechado) e a oeste, mar a leste, pântano e morros
# ao sul. Um rio em "S" corta a região, passa por um lago com um mosteiro numa ilha, e três pontes levam a
# estrada por cima dele. A vila fica no centro, no cruzamento das estradas; em volta: fazendas e moinho,
# porto de pescadores, ruínas de uma torre num morro, serraria, acampamento de bandidos, caverna.
# Visual: PS1 pintado (shaders/ps1.gdshader) + pixel splats (chão, copas, grama), em resolução baixa com
# paleta reduzida e pontilhado. Tudo gerado por código até chegarem os modelos do Tripo.
extends Node

const REDUCAO := 4          # a imagem 3D é desenhada em 1/4 da resolução da tela
const NEBLINA := Color(0.74, 0.83, 0.94)
const TEMPESTADE := false     # céu limpo; true = relâmpagos (clima de tempestade)

var vp: SubViewport
var raiz: Node3D
var jogador: Jogador
var controles: Controles
var reg: Regiao
var terreno: Terreno
var estrada: PackedVector2Array      # estrada que sai da vila para o sul (poças)
var casas := [] # [pos, ang, w, d]
var lugares := []                    # [centro Vector2, raio] — as árvores não nascem aqui
var moinhos := []
var _depois: Array[Callable] = []    # peças montadas depois do terreno (precisam da altura exata da malha)
var args := {}
var _mats := {}
var _ultima := Vector3.ZERO

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var p := a.trim_prefix("--").split("=", true, 1)
		args[p[0]] = p[1] if p.size() > 1 else "1"
	reg = Regiao.new(); estrada = reg.estradas[0]
	_tela()
	_ambiente()
	terreno = Terreno.new(); raiz.add_child(terreno)
	jogador = Jogador.new()
	_lugares()                      # antes do terreno: as construções aplanam o chão embaixo delas
	terreno.montar(self)
	for f in _depois: f.call()        # cercas, muros e blocos: assentados na malha final do terreno
	_agua()
	var fl := Floresta.new(); raiz.add_child(fl); fl.montar(self)
	var chao := ChaoSplat.new(); raiz.add_child(chao); chao.montar(self)
	var grama := Grama.new(); raiz.add_child(grama); grama.montar(self)
	_moradores()
	raiz.add_child(jogador)
	jogador.position = Vector3(-4, altura(-4, 48) + 0.3, 48)
	_ultima = jogador.position
	controles = Controles.new(); var cl := CanvasLayer.new(); add_child(cl); cl.add_child(controles)
	jogador.controles = controles
	var inter := Interacao.new(); cl.add_child(inter); inter.montar(self)
	_musica()
	if args.has("estrada"): _checar_estrada(); get_tree().quit(); return
	if args.has("checar"): _checar_chao()
	if args.has("shot"): _modo_teste()

# moradores: o mesmo modelo com cores e alturas sorteadas, andando pela vila (e alguns no porto e nas fazendas)
func _moradores() -> void:
	var grupos := [[Vector2.ZERO, 42.0, 10], [Vector2(360, 60), 30.0, 3], [Vector2(-215, 60), 40.0, 3]]
	var n := 0
	for g in grupos:
		for i in g[2]:
			var mo := Morador.new(); raiz.add_child(mo)
			var a := randf() * TAU; var p: Vector2 = g[0] + Vector2(cos(a), sin(a)) * randf_range(4.0, g[1] * 0.8)
			for t in 20:
				if not perto_de_casa(p.x, p.y, 1.5): break
				a = randf() * TAU; p = g[0] + Vector2(cos(a), sin(a)) * randf_range(4.0, g[1] * 0.8)
			mo.position = Vector3(p.x, altura(p.x, p.y) + 0.3, p.y)
			mo.montar(self, 1000 + n, g[0], g[1]); n += 1
	_profissionais()
	# já começam algumas conversas na vila
	var vila := []
	for mo in raiz.get_children():
		if mo is Morador and Vector2(mo.position.x, mo.position.z).length() < 45.0: vila.append(mo)
	for k in range(0, mini(vila.size() - 1, 4), 2): vila[k].convidar(vila[k + 1])

# trabalhadores: ferreiro na bigorna, lenhador cortando um tronco caído na mata perto da serraria,
# um fazendeiro dentro de cada campo cercado
func _profissionais() -> void:
	var n := 0
	# ferreiro: em pé na frente da bigorna (no espaço da ferraria: bigorna em (1,2; -0,4))
	if ferraria_pos != Vector2.ZERO:
		var loc := func(x: float, z: float) -> Vector2: return ferraria_pos + Vector2(x, z).rotated(-ferraria_ang)
		var big: Vector2 = loc.call(1.2, -0.4)
		var fe := Morador.new(); fe.profissao = "ferreiro"; fe.posto = loc.call(1.2, 0.42); fe.olhar_posto = big
		raiz.add_child(fe); fe.position = Vector3(fe.posto.x, altura(fe.posto.x, fe.posto.y), fe.posto.y)
		var yb := reg.altura(big.x, big.y)
		var faisca := _particulas(Vector3(big.x, yb + 1.08, big.y), [Color(1.0, 0.8, 0.3), Color(1.0, 0.55, 0.15)], 16, 3.2, 0.45)
		# som da martelada (3D: alto perto da ferraria, some ao longe); sorteia uma das batidas e varia o tom
		var som := AudioStreamPlayer3D.new(); som.position = Vector3(big.x, yb + 1.0, big.y)
		som.unit_size = 6.0; som.max_distance = 70.0; som.volume_db = -4.0; som.bus = "Efeitos"
		som.attenuation_filter_cutoff_hz = 9000.0; som.attenuation_filter_db = -12.0   # de longe fica abafado
		raiz.add_child(som)
		var batidas := []
		for k in 4: batidas.append(load("res://assets/som/martelo_%d.ogg" % (k + 1)))
		fe.ao_bater = func():
			faisca.restart()
			som.stream = batidas[randi() % batidas.size()]; som.pitch_scale = randf_range(0.94, 1.06); som.play()
		fe.montar(self, 5000 + n, fe.posto, 1.0); n += 1
	# lenhador: tronco caído na beira da mata, perto da serraria
	var serra := Vector2(286, -170); var lp := serra + Vector2(0, 22)
	for t in 40:
		var a := t * 0.7; var q := serra + Vector2(cos(a), sin(a)) * (18.0 + t * 0.6)
		if reg.floresta(q.x, q.y) > 0.35 and reg.dist_estrada(q.x, q.y) > 6.0 and not perto_de_casa(q.x, q.y, 3.0) and reg.dist_rio(q.x, q.y) > 14.0:
			lp = q; break
	var ang := randf() * TAU
	var tronco_c := lp + Vector2(cos(ang), sin(ang)) * 1.0
	_tronco_caido(tronco_c, -ang - PI / 2)       # deitado de través na frente do lenhador
	lugares.append([tronco_c, 4.0])
	var le := Morador.new(); le.profissao = "lenhador"; le.posto = lp; le.olhar_posto = tronco_c
	raiz.add_child(le); le.position = Vector3(lp.x, altura(lp.x, lp.y), lp.y)
	var lascas := _particulas(Vector3(tronco_c.x, altura(tronco_c.x, tronco_c.y) + 0.45, tronco_c.y), [Color(0.85, 0.66, 0.4), Color(0.6, 0.42, 0.24)], 12, 2.4, 0.6)
	le.ao_bater = func(): lascas.restart()
	le.montar(self, 6000, lp, 1.0)
	# fazendeiros: um em cada campo cercado
	for cp in reg.campos:
		var fz := Morador.new(); fz.profissao = "fazendeiro"; fz.campo = cp
		var c := Vector2(cp[0], cp[1])
		fz.posto = c; fz.olhar_posto = c + Vector2(1, 0)
		raiz.add_child(fz); fz.position = Vector3(c.x, altura(c.x, c.y), c.y)
		fz.montar(self, 7000 + n, c, 1.0); n += 1

# faíscas / lascas: partículas que saem num estouro (restart() a cada golpe)
func _particulas(pos: Vector3, cores: Array, qtd: int, vel: float, vida: float) -> CPUParticles3D:
	var p := CPUParticles3D.new(); p.position = pos
	p.one_shot = true; p.emitting = false; p.amount = qtd; p.lifetime = vida; p.explosiveness = 1.0
	p.direction = Vector3(0, 1, 0); p.spread = 70.0; p.initial_velocity_min = vel * 0.5; p.initial_velocity_max = vel
	p.gravity = Vector3(0, -9.0, 0); p.scale_amount_min = 0.6; p.scale_amount_max = 1.2
	var q := QuadMesh.new(); q.size = Vector2(0.05, 0.05)
	var mt := StandardMaterial3D.new(); mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; mt.vertex_color_use_as_albedo = true
	q.material = mt; p.mesh = q
	var g := Gradient.new(); g.set_color(0, cores[0]); g.set_color(1, cores[1]); p.color_initial_ramp = g
	raiz.add_child(p); return p

# tronco caído (para o lenhador cortar): deitado no chão, com um corte em V no meio e lascas em volta
func _tronco_caido(c: Vector2, ang: float) -> void:
	var y := terreno.altura_malha(c.x, c.y)
	var st := _st(); cilindro(st, Vector3(0, -1.4, 0), 0.34, 0.3, 2.8, 7, true)
	var mi := _peca(st, mat("casca"), Vector3(c.x, y + 0.28, c.y)); mi.rotation = Vector3(0, ang, PI / 2)
	st = _st(); _caixa(st, Vector3(0, 0.0, 0), Vector3(0.18, 0.2, 0.62))
	var corte := _peca(st, mat("", 1.0, Color(0.86, 0.68, 0.42)), Vector3(c.x, y + 0.56, c.y)); corte.rotation.y = ang
	var lascas := []
	for k in 16:
		var q := c + Vector2(randf_range(-0.9, 0.9), randf_range(-0.9, 0.9))
		lascas.append([Vector3(q.x, terreno.altura_malha(q.x, q.y) + 0.03, q.y), Color(0.82, 0.64, 0.4) * randf_range(0.85, 1.1), randf_range(0.06, 0.1)])
	_splats(lascas, Vector2(1, 1), false, 0.0)
	_colisor_caixa(Vector3(c.x, y - 0.1, c.y), Vector3(0.7, 0.75, 2.8), ang + PI / 2)

# ponto dentro (ou perto) de uma casa?
func perto_de_casa(x: float, z: float, folga: float) -> bool:
	for c in casas:
		var q := Vector2(x - c[0].x, z - c[0].z).rotated(c[1])
		if abs(q.x) < c[2] * 0.5 + folga and abs(q.y) < c[3] * 0.5 + folga: return true
	if Vector2(x, z).length() < 2.0: return true          # poço
	return false

# música de fundo ("Time Flows Ever Onward"), em volume bem baixo, repetindo
func _musica() -> void:
	Audio.montar()
	var st: AudioStreamOggVorbis = load("res://assets/som/musica_vale.ogg")
	st.loop = true
	var mus := AudioStreamPlayer.new(); mus.stream = st; mus.volume_db = -16.0; mus.bus = "Musica"
	add_child(mus); mus.play()

# o jogador não sai da região nem entra em água funda (volta para o último lugar bom)
func _physics_process(_d: float) -> void:
	if jogador == null: return
	var p := jogador.global_position
	var fundo := reg.agua(p.x, p.z) - p.y
	if not reg.dentro(p.x * 1.04, p.z * 1.04) or fundo > 0.9 or p.y < -20.0:
		jogador.global_position = _ultima; jogador.velocity = Vector3.ZERO
	elif jogador.is_on_floor():
		_ultima = p

func _tempo_jogo() -> float: return Time.get_ticks_msec() / 1000.0
func altura(x: float, z: float) -> float: return reg.altura(x, z)
func cor_chao(x: float, z: float, h: float, ny: float) -> Color: return reg.cor(x, z, h, ny)
func altura_malha(x: float, z: float) -> float: return terreno.altura_malha(x, z)
func normal_malha(x: float, z: float) -> Vector3: return terreno.normal_malha(x, z)
func _dist_estrada(p: Vector2) -> float: return reg.dist_estrada(p.x, p.y)
func perto_de_lugar(x: float, z: float, folga: float) -> bool:
	for l in lugares:
		if Vector2(x, z).distance_to(l[0]) < l[1] + folga: return true
	return false

# ---------- tela: 3D em resolução baixa + filtro de paleta ----------
func _tela() -> void:
	var cont := SubViewportContainer.new()
	cont.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cont.stretch = true; cont.stretch_shrink = REDUCAO
	cont.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new(); sm.shader = load("res://shaders/tela.gdshader"); cont.material = sm
	add_child(cont)
	vp = SubViewport.new(); vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	cont.add_child(vp)
	raiz = Node3D.new(); vp.add_child(raiz)

func _ambiente() -> void:
	var we := WorldEnvironment.new(); var env := Environment.new()
	var sky := Sky.new(); var sm := ShaderMaterial.new(); sm.shader = load("res://shaders/ceu.gdshader"); sky.sky_material = sm
	env.background_mode = Environment.BG_SKY; env.sky = sky
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	we.environment = env; raiz.add_child(we)

# relâmpagos de vez em quando (clarão em tudo pelo parâmetro global "relampago")
var _prox_raio := 4.0
var _raio := 0.0
func _process(delta: float) -> void:
	Audio.atualizar(delta)
	for mo in moinhos: mo.rotate_object_local(Vector3(0, 0, 1), delta * 0.6)
	if not TEMPESTADE and not args.has("raio"): return
	_prox_raio -= delta
	if _prox_raio <= 0.0:
		_prox_raio = randf_range(7.0, 16.0); _raio = 1.0
	if _raio > 0.0:
		_raio = max(0.0, _raio - delta * 2.2)
		var v: float = _raio * (0.6 + 0.4 * float(int(_raio * 14.0) % 2))    # pisca
		RenderingServer.global_shader_parameter_set("relampago", v)

# ---------- material PS1 ----------
func mat(textura: String, escala := 1.0, cor := Color.WHITE) -> ShaderMaterial:
	var k := "%s|%s|%s" % [textura, escala, cor]
	if _mats.has(k): return _mats[k]
	var m := ShaderMaterial.new(); m.shader = load("res://shaders/ps1.gdshader")
	if textura == "": m.set_shader_parameter("usa_tex", false)
	else: m.set_shader_parameter("tex", Texturas.pegar(textura))
	m.set_shader_parameter("escala_uv", escala); m.set_shader_parameter("cor", cor)
	m.set_shader_parameter("neblina", NEBLINA)
	_mats[k] = m; return m

# modelo GLB (do Tripo) com o material PS1: mesma luz por vértice, textura sem suavização e neblina do mundo
func modelo_ps1(caminho: String) -> Node3D:
	var no: Node3D = load(caminho).instantiate()
	for n in no.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n
		for i in mi.mesh.get_surface_count():
			var orig: BaseMaterial3D = mi.mesh.surface_get_material(i)
			var sm := ShaderMaterial.new(); sm.shader = load("res://shaders/ps1.gdshader")
			if orig and orig.albedo_texture: sm.set_shader_parameter("tex", orig.albedo_texture)
			else: sm.set_shader_parameter("usa_tex", false)
			sm.set_shader_parameter("neblina", NEBLINA)
			mi.set_surface_override_material(i, sm)
	return no

# ---------- vila (no cruzamento das estradas, centro da região) ----------
func _vila() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	# casas nos quatro cantos, longe das estradas (que saem para N, S, L e O)
	for l in [[14, -14], [30, -26], [-15, -13], [14, 13], [-17, 14], [-30, 28], [30, 30], [44, -10], [-44, 12], [-12, 40], [16, 44]]:
		var p := Vector2(l[0], l[1])
		var ang := atan2(-p.x, -p.y)
		_casa(Vector3(p.x, altura(p.x, p.y) - 0.2, p.y), ang, rng.randf_range(4.5, 6.5), rng.randf_range(4.0, 5.0), rng.randf_range(2.6, 3.2))
	# taverna (maior, dois andares)
	var tv := Vector2(-31, -22)
	_casa(Vector3(tv.x, altura(tv.x, tv.y) - 0.2, tv.y), atan2(-tv.x, -tv.y), 10.0, 7.5, 5.2)
	# igreja de pedra com torre
	var ig := Vector2(18, -40); var ang_ig := atan2(-ig.x, -ig.y)
	_casa(Vector3(ig.x, altura(ig.x, ig.y) - 0.2, ig.y), ang_ig, 7.5, 12.0, 5.0, mat("pedra"), mat("madeira", 1.0, Color(0.55, 0.5, 0.55)))
	var pig: Vector3 = casas[casas.size() - 1][0]
	var torre := Vector3(pig.x, 0, pig.z) + Vector3(0, 0, -7.5).rotated(Vector3.UP, ang_ig)
	torre.y = reg.aplanar(Vector2(torre.x, torre.z), Vector2(2.4, 2.4), -ang_ig, 3.0) - 0.3
	var mesh := ArrayMesh.new(); var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_caixa(st, Vector3(0, 5.0, 0), Vector3(3.6, 10.0, 3.6)); st.set_material(mat("pedra")); st.commit(mesh)
	st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	cilindro(st, Vector3(0, 10.0, 0), 2.7, 0.0, 4.5, 4); st.set_material(mat("madeira", 1.0, Color(0.55, 0.5, 0.55))); st.commit(mesh)
	var mi := MeshInstance3D.new(); mi.mesh = mesh; mi.position = torre; mi.rotation.y = ang_ig + PI / 4.0; raiz.add_child(mi)
	_colisor_caixa(torre, Vector3(3.6, 10, 3.6), ang_ig)
	_poco(Vector3(0, reg.aplanar(Vector2.ZERO, Vector2(1.6, 1.6), 0.0, 2.0) - 0.1, 0))
	for b in [[3.5, 2.0], [4.2, 2.6], [-3.0, 3.6], [6.0, -9.0], [-26, -16], [-25, -15.2]]:
		_barril(Vector3(b[0], altura(b[0], b[1]), b[1]))
	_ferraria()
	lugares.append([Vector2.ZERO, 50.0])

# ferraria: telheiro aberto de madeira (4 esteios e telhado inclinado de tábuas), fornalha de pedra com
# chaminé e fogo aceso, bigorna sobre um toco, tina d'água, monte de carvão e um suporte de ferramentas.
# O lugar é escolhido sozinho: livre de casas e longe da estrada, na beira da vila.
var ferraria_pos := Vector2.ZERO
var ferraria_ang := 0.0
func _ferraria() -> void:
	var c := Vector2(-34, 44)
	for t in 80:
		var a := deg_to_rad(120.0 + t * 37.0); var r := 30.0 + (t % 5) * 5.0
		var q := Vector2(cos(a), sin(a)) * r
		if not perto_de_casa(q.x, q.y, 6.0) and reg.dist_estrada(q.x, q.y) > 9.0: c = q; break
	var ang := atan2(-c.x, -c.y)                         # frente aberta virada para a praça
	var livre := _longe_da_estrada(c, Vector2(4.5, 3.5), ang)
	c = livre; ferraria_pos = c; ferraria_ang = ang
	var y := reg.aplanar(c, Vector2(5.0, 4.0), -ang, 3.0)
	var base := Vector3(c.x, y, c.y)
	var no := Node3D.new(); no.position = base; no.rotation.y = ang; raiz.add_child(no)
	var add := func(st: SurfaceTool, mt: Material) -> void:
		var mi := MeshInstance3D.new(); mi.mesh = st.commit(); mi.material_override = mt; no.add_child(mi)
	var col := func(pos: Vector3, tam: Vector3) -> void:
		var corpo := StaticBody3D.new(); var cs := CollisionShape3D.new(); var bx := BoxShape3D.new()
		bx.size = tam; cs.shape = bx; cs.position = pos + Vector3(0, tam.y / 2.0, 0); corpo.add_child(cs); no.add_child(corpo)
	# piso de pedra batida
	var st := _st(); _caixa(st, Vector3(0, -0.15, 0), Vector3(9.0, 0.4, 7.0)); add.call(st, mat("pedra", 1.0, Color(0.75, 0.72, 0.7)))
	# esteios e vigas
	st = _st()
	for e in [Vector2(-4.2, 3.2), Vector2(4.2, 3.2), Vector2(-4.2, -3.2), Vector2(4.2, -3.2)]:
		var alt: float = 3.4 if e.y > 0 else 2.6
		_caixa(st, Vector3(e.x, alt / 2.0 - 0.3, e.y), Vector3(0.3, alt + 0.6, 0.3))
		col.call(Vector3(e.x, -0.3, e.y), Vector3(0.32, alt, 0.32))
	_caixa(st, Vector3(0, 3.2, 3.2), Vector3(8.8, 0.25, 0.25)); _caixa(st, Vector3(0, 2.4, -3.2), Vector3(8.8, 0.25, 0.25))
	add.call(st, mat("madeira"))
	# telhado de tábuas inclinado (mais alto na frente)
	st = _st()
	_quad(st, Vector3(-4.8, 2.5, -3.8), Vector3(4.8, 2.5, -3.8), Vector3(4.8, 3.45, 3.8), Vector3(-4.8, 3.45, 3.8), 5.0, 4.0)
	_quad(st, Vector3(4.8, 2.5, -3.8), Vector3(-4.8, 2.5, -3.8), Vector3(-4.8, 3.45, 3.8), Vector3(4.8, 3.45, 3.8), 5.0, 4.0)
	add.call(st, mat("madeira", 1.0, Color(0.62, 0.55, 0.5)))
	# fornalha de pedra no fundo, com chaminé atravessando o telhado
	st = _st()
	_caixa(st, Vector3(-2.2, 0.75, -2.3), Vector3(2.4, 1.5, 1.8))
	_caixa(st, Vector3(-2.2, 1.9, -2.6), Vector3(1.6, 0.8, 1.2))
	_caixa(st, Vector3(-2.2, 3.4, -2.6), Vector3(0.9, 2.6, 0.9))
	add.call(st, mat("pedra"))
	col.call(Vector3(-2.2, 0, -2.3), Vector3(2.4, 2.4, 1.8))
	# boca da fornalha: brasa (escuro + laranja) e fogo em splats
	st = _st(); _quad(st, Vector3(-2.9, 0.35, -1.38), Vector3(-1.5, 0.35, -1.38), Vector3(-1.5, 1.05, -1.38), Vector3(-2.9, 1.05, -1.38), 1, 1)
	add.call(st, mat("", 1.0, Color(1.6, 0.55, 0.15)))
	var fogo := []
	for k in 18:
		fogo.append([no.transform * Vector3(-2.2 + randf_range(-0.45, 0.45), randf_range(0.4, 1.0), -1.3 + randf_range(-0.05, 0.08)),
			[Color(1.0, 0.75, 0.3), Color(0.98, 0.45, 0.15), Color(1.0, 0.9, 0.55)][k % 3], randf_range(0.18, 0.32)])
	_splats(fogo, Vector2(1, 1), false, 0.6)
	# bigorna sobre um toco
	st = _st(); cilindro(st, Vector3(1.2, -0.1, -0.4), 0.45, 0.42, 0.75, 7, true); add.call(st, mat("casca"))
	st = _st()
	_caixa(st, Vector3(1.2, 0.72, -0.4), Vector3(0.38, 0.18, 0.3))
	_caixa(st, Vector3(1.2, 0.92, -0.4), Vector3(0.75, 0.22, 0.34))
	_caixa(st, Vector3(1.68, 0.95, -0.4), Vector3(0.25, 0.14, 0.18))      # bico
	add.call(st, mat("", 1.0, Color(0.3, 0.3, 0.34)))
	col.call(Vector3(1.2, -0.1, -0.4), Vector3(0.9, 1.05, 0.9))
	# tina d'água e monte de carvão
	st = _st(); cilindro(st, Vector3(3.2, -0.1, -2.2), 0.6, 0.65, 0.75, 8); add.call(st, mat("madeira"))
	st = _st(); _quad(st, Vector3(2.65, 0.55, -2.75), Vector3(3.75, 0.55, -2.75), Vector3(3.75, 0.55, -1.65), Vector3(2.65, 0.55, -1.65), 1, 1)
	add.call(st, mat("", 1.0, Color(0.2, 0.32, 0.42)))
	col.call(Vector3(3.2, -0.1, -2.2), Vector3(1.3, 0.85, 1.3))
	st = _st(); cilindro(st, Vector3(-3.6, -0.1, 1.2), 0.9, 0.0, 0.7, 6); add.call(st, mat("", 1.0, Color(0.13, 0.12, 0.12)))
	# parede de tábuas no fundo (à direita da fornalha), onde fica o suporte de ferramentas
	st = _st()
	_caixa(st, Vector3(1.25, 1.0, -3.3), Vector3(5.9, 2.6, 0.12))
	for k in 6: _caixa(st, Vector3(-1.4 + k * 1.06, 1.0, -3.22), Vector3(0.09, 2.6, 0.06))      # frestas entre tábuas
	add.call(st, mat("madeira", 1.0, Color(0.72, 0.62, 0.55)))
	col.call(Vector3(1.25, -0.3, -3.3), Vector3(5.9, 2.6, 0.2))
	# suporte de ferramentas preso na parede (tenazes e martelos pendurados)
	st = _st()
	_caixa(st, Vector3(1.6, 1.6, -3.15), Vector3(2.2, 0.12, 0.12))
	for k in 5:
		var x := 0.8 + k * 0.4
		_caixa(st, Vector3(x, 1.25, -3.12), Vector3(0.05, 0.7, 0.05))
		_caixa(st, Vector3(x, 0.92, -3.12), Vector3(0.16, 0.1, 0.08))
	add.call(st, mat("", 1.0, Color(0.32, 0.3, 0.3)))
	lugares.append([c, 7.0])

func _colisor_caixa(pos: Vector3, tam: Vector3, ang: float) -> void:
	var corpo := StaticBody3D.new(); var cs := CollisionShape3D.new(); var bx := BoxShape3D.new()
	bx.size = tam; cs.shape = bx; cs.position = Vector3(0, tam.y / 2.0, 0)
	corpo.add_child(cs); corpo.position = pos; corpo.rotation.y = ang; raiz.add_child(corpo)

# malha solta com um material (para peças de cenário montadas por código)
func _peca(st: SurfaceTool, material: Material, pos: Vector3, ang := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); mi.mesh = st.commit(); mi.material_override = material
	mi.position = pos; mi.rotation.y = ang; raiz.add_child(mi); return mi

func _st() -> SurfaceTool:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES); return st

# ---------- água ----------
func _agua() -> void:
	var am := ShaderMaterial.new(); am.shader = load("res://shaders/agua.gdshader"); am.set_shader_parameter("neblina", NEBLINA)
	# mar (leste) e poças do pântano (sul): um plano no nível 0
	var mar := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(1700, 1700); mar.mesh = pm
	mar.material_override = am; raiz.add_child(mar)
	# rio: faixa que segue a linha do rio, no nível da água de cada trecho
	var st := _st(); var pts := []
	for i in reg.rio.size() - 1:
		var a: Vector2 = reg.rio[i]; var b: Vector2 = reg.rio[i + 1]
		var n := int(ceil(a.distance_to(b) / 3.0))
		for k in n: pts.append(a.lerp(b, float(k) / n))
	pts.append(reg.rio[reg.rio.size() - 1])
	var tot := 0.0; var ts := [0.0]
	for i in range(1, pts.size()): tot += pts[i].distance_to(pts[i - 1]); ts.append(tot)
	var ant_l := Vector3.ZERO; var ant_r := Vector3.ZERO
	for i in pts.size():
		var t: float = ts[i] / tot
		var d: Vector2 = (pts[min(i + 1, pts.size() - 1)] - pts[max(i - 1, 0)]).normalized()
		var nrm := Vector2(-d.y, d.x) * (reg.largura_rio(t) * 0.5 + 1.0)
		var y := reg.nivel_rio(t) - 0.12
		var l := Vector3(pts[i].x + nrm.x, y, pts[i].y + nrm.y); var r := Vector3(pts[i].x - nrm.x, y, pts[i].y - nrm.y)
		if i > 0: _quad(st, ant_l, ant_r, r, l, 1, 1)
		ant_l = l; ant_r = r
	_peca(st, am, Vector3.ZERO)
	# lago
	st = _st()
	var c := Vector3(Regiao.LAGO.x, reg.nivel_lago() - 0.12, Regiao.LAGO.y); var rl := Regiao.LAGO.z + 3.0
	for k in 40:
		var a0 := TAU * k / 40.0; var a1 := TAU * (k + 1) / 40.0
		_tri(st, c, c + Vector3(cos(a1) * rl, 0, sin(a1) * rl), c + Vector3(cos(a0) * rl, 0, sin(a0) * rl), 1, 1)
	_peca(st, am, Vector3.ZERO)

# ---------- lugares da região ----------
func _lugares() -> void:
	_vila()
	_pontes()
	_fazendas()
	_porto()
	_mosteiro()
	_ruinas()
	_serraria()
	_bandidos()
	_caverna()
	_barricada()

# pontes de madeira onde as estradas cruzam o rio (com rampas nas pontas e colisão)
func _pontes() -> void:
	for pt in reg.pontes:
		var p: Vector2 = pt[0]; var d: Vector2 = pt[1]
		var lado := Vector2(-d.y, d.x)
		var meia := reg.largura_rio(0.5) * 0.5 + 7.0
		var a := p - d * meia; var b := p + d * meia
		var ha := altura(a.x, a.y) + 0.05; var hb := altura(b.x, b.y) + 0.05
		var topo: float = max(max(ha, hb), reg.agua(p.x, p.y) + 1.0) + 0.3
		var perfil := [[-meia, ha], [-meia + 4.0, topo], [meia - 4.0, topo], [meia, hb]]
		var st := _st(); var w := 1.8
		for i in 3:
			var s0: float = perfil[i][0]; var s1: float = perfil[i + 1][0]
			var p0 := p + d * s0; var p1 := p + d * s1
			var y0: float = perfil[i][1]; var y1: float = perfil[i + 1][1]
			var l0 := Vector3(p0.x + lado.x * w, y0, p0.y + lado.y * w); var r0 := Vector3(p0.x - lado.x * w, y0, p0.y - lado.y * w)
			var l1 := Vector3(p1.x + lado.x * w, y1, p1.y + lado.y * w); var r1 := Vector3(p1.x - lado.x * w, y1, p1.y - lado.y * w)
			_quad(st, r0, l0, l1, r1, 2, (s1 - s0) / 2.0)                                      # tábuas
			_quad(st, l0 - Vector3(0, 0.4, 0), l1 - Vector3(0, 0.4, 0), l1, l0, (s1 - s0) / 2.0, 0.2)
			_quad(st, r1 - Vector3(0, 0.4, 0), r0 - Vector3(0, 0.4, 0), r0, r1, (s1 - s0) / 2.0, 0.2)
		var mi := _peca(st, mat("madeira"), Vector3.ZERO)
		var corpo := StaticBody3D.new(); var cs := CollisionShape3D.new(); var f: ConcavePolygonShape3D = mi.mesh.create_trimesh_shape()
		f.backface_collision = true; cs.shape = f; corpo.add_child(cs); raiz.add_child(corpo)
		# corrimão e pilares
		st = _st()
		for lad in [-1.0, 1.0]:
			for k in 7:
				var s0: float = lerp(-meia + 4.0, meia - 4.0, k / 6.0)
				var q: Vector2 = p + d * s0 + lado * w * lad
				_caixa(st, Vector3(q.x, topo + 0.5, q.y), Vector3(0.18, 1.0, 0.18))
				_caixa(st, Vector3(q.x, topo - 1.6, q.y), Vector3(0.35, 3.0, 0.35))
			var c0: Vector2 = p + d * (-meia + 4.0) + lado * w * lad; var c1: Vector2 = p + d * (meia - 4.0) + lado * w * lad
			var y := topo + 0.95
			_quad(st, Vector3(c0.x, y - 0.12, c0.y), Vector3(c1.x, y - 0.12, c1.y), Vector3(c1.x, y, c1.y), Vector3(c0.x, y, c0.y), meia, 0.1)
			_colisor_caixa(Vector3((c0.x + c1.x) / 2, topo, (c0.y + c1.y) / 2), Vector3(0.3, 1.2, (meia - 4.0) * 2.0), atan2(d.x, d.y))
		_peca(st, mat("madeira", 1.0, Color(0.7, 0.62, 0.55)), Vector3.ZERO)
		lugares.append([p, meia])

# cerca de madeira em volta de um retângulo (centro, tamanho, ângulo), com abertura na frente
func _cerca(c: Vector2, tam: Vector2, ang: float) -> void:
	_depois.append(func(): _montar_cerca(c, tam, ang))

# cerca de madeira na altura EXATA da malha do terreno: mourões enterrados 0,6 m, travessas seguindo o chão
# a cada 1 m (nunca flutuam nem entram no chão), e colisão em cada trecho (só a porteira fica aberta)
func _montar_cerca(c: Vector2, tam: Vector2, ang: float) -> void:
	var st := _st()
	var cantos := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for k in 4:
		var a: Vector2 = c + (cantos[k] * tam * 0.5).rotated(ang); var b: Vector2 = c + (cantos[(k + 1) % 4] * tam * 0.5).rotated(ang)
		var comp := a.distance_to(b)
		var n := maxi(int(comp / 3.0), 1)
		var abre0 := 0.5 - 2.0 / comp; var abre1 := 0.5 + 2.0 / comp      # porteira de 4 m no meio do lado 2
		for i in n + 1:
			var t := float(i) / n
			if k == 2 and t > abre0 and t < abre1: continue
			var q := a.lerp(b, t); var y := terreno.altura_malha(q.x, q.y)
			_caixa(st, Vector3(q.x, y + 0.25, q.y), Vector3(0.15, 1.7, 0.15))           # de -0,6 a +1,1
		# travessas em pedaços de ~1 m seguindo o chão
		var m := maxi(int(comp), 1)
		var trecho_ini := -1
		for j in m + 1:
			var t := float(j) / m
			var aberto := k == 2 and t > abre0 - 0.001 and t < abre1 + 0.001
			if j < m and not aberto and not (k == 2 and float(j + 1) / m > abre0 and float(j + 1) / m < abre1):
				var q := a.lerp(b, t); var q2 := a.lerp(b, float(j + 1) / m)
				var y := terreno.altura_malha(q.x, q.y); var y2 := terreno.altura_malha(q2.x, q2.y)
				for alt in [0.45, 0.85]:
					_quad(st, Vector3(q.x, y + alt, q.y), Vector3(q2.x, y2 + alt, q2.y), Vector3(q2.x, y2 + alt + 0.1, q2.y), Vector3(q.x, y + alt + 0.1, q.y), 1.0, 0.1)
					_quad(st, Vector3(q2.x, y2 + alt, q2.y), Vector3(q.x, y + alt, q.y), Vector3(q.x, y + alt + 0.1, q.y), Vector3(q2.x, y2 + alt + 0.1, q2.y), 1.0, 0.1)
		# colisão: um trecho reto de cada lado da porteira (ou o lado inteiro)
		var partes := [[0.0, 1.0]] if k != 2 else [[0.0, abre0], [abre1, 1.0]]
		for pt in partes:
			var p0: Vector2 = a.lerp(b, pt[0]); var p1: Vector2 = a.lerp(b, pt[1])
			_parede_colisao(p0, p1, 0.3, 1.3)
	_peca(st, mat("madeira", 1.0, Color(0.8, 0.7, 0.6)), Vector3.ZERO)

# caixa de colisão de um trecho reto (de p0 a p1), da altura do chão mais baixo até "alt" acima do mais alto
func _parede_colisao(p0: Vector2, p1: Vector2, esp: float, alt: float) -> void:
	var d := p1 - p0; var comp := d.length()
	if comp < 0.2: return
	var meio := (p0 + p1) * 0.5
	var ymin := INF; var ymax := -INF
	for i in 5:
		var q := p0.lerp(p1, i / 4.0); var y := terreno.altura_malha(q.x, q.y)
		ymin = minf(ymin, y); ymax = maxf(ymax, y)
	_colisor_caixa(Vector3(meio.x, ymin - 0.3, meio.y), Vector3(esp, ymax - ymin + alt + 0.3, comp), atan2(d.x, d.y))

func _fazendas() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 8
	for cp in reg.campos:
		var livre := _longe_da_estrada(Vector2(cp[0], cp[1]), Vector2(cp[2] + 2, cp[3] + 2) * 0.5, -deg_to_rad(cp[4]))
		cp[0] = livre.x; cp[1] = livre.y
	for cp in reg.campos:
		var c := Vector2(cp[0], cp[1]); var ang := deg_to_rad(cp[4])
		lugares.append([c, max(cp[2], cp[3]) * 0.55])
		_cerca(c, Vector2(cp[2] + 2, cp[3] + 2), ang)
		if cp[5] == 0 and rng.randf() < 0.75:
			# celeiro vermelho ao lado do campo
			var bp: Vector2 = c + Vector2(cp[2] * 0.5 + 9.0, 0).rotated(ang)
			if reg.dist_estrada(bp.x, bp.y) > 7.0:
				_casa(Vector3(bp.x, altura(bp.x, bp.y) - 0.2, bp.y), ang + PI / 2, 8.0, 10.0, 4.2, mat("madeira", 1.0, Color(1.25, 0.62, 0.52)), mat("madeira", 1.0, Color(0.6, 0.55, 0.5)))
	# moinho de vento entre as fazendas
	var mp := Vector2(-244, 100); var y := reg.aplanar(mp, Vector2(3.6, 3.6), 0.0, 4.0)
	var st := _st(); cilindro(st, Vector3.ZERO, 3.0, 2.2, 9.0, 8, true); _peca(st, mat("pedra"), Vector3(mp.x, y - 0.3, mp.y))
	st = _st(); cilindro(st, Vector3(0, 8.7, 0), 2.6, 0.0, 3.2, 8); _peca(st, mat("palha"), Vector3(mp.x, y - 0.3, mp.y))
	st = _st()
	for k in 4:
		var b := Node3D.new()
		_caixa(st, Vector3(0, 4.2, 0).rotated(Vector3(0, 0, 1), TAU * k / 4.0), Vector3(0.3, 8.0, 0.1).abs())
	var pas := _peca(st, mat("madeira", 1.0, Color(0.9, 0.85, 0.75)), Vector3(mp.x + 2.6, y + 8.0, mp.y))
	pas.rotation.y = PI / 2
	moinhos.append(pas)
	_colisor_cilindro(Vector3(mp.x, y - 0.3, mp.y), 3.0, 9.0)
	lugares.append([mp, 5.0])

func _porto() -> void:
	var z := 58.0; var xc := 380.0
	while xc < 560.0 and altura(xc, z) > 0.4: xc += 1.0
	var st := _st()
	var y := 1.5
	for i in 18:                                        # píer: tábuas sobre estacas
		var x := xc - 6.0 + i * 2.0
		_caixa(st, Vector3(x, y, z), Vector3(2.0, 0.2, 3.2))
		if i % 2 == 0:
			for lz in [-1.4, 1.4]: _caixa(st, Vector3(x, y - 1.6, z + lz), Vector3(0.3, 3.2, 0.3))
	_peca(st, mat("madeira"), Vector3.ZERO)
	_colisor_caixa(Vector3(xc + 11.0, y - 0.1, z), Vector3(36.0, 0.2, 3.2), PI / 2)
	# barcos
	for b in [[xc + 14.0, z + 5.0], [xc + 24.0, z - 5.0]]:
		st = _st(); _caixa(st, Vector3(0, 0.25, 0), Vector3(5.0, 0.7, 1.8)); _caixa(st, Vector3(2.7, 0.35, 0), Vector3(0.8, 0.5, 1.0))
		_peca(st, mat("madeira", 1.0, Color(0.75, 0.6, 0.5)), Vector3(b[0], 0.0, b[1]), 0.2)
	for h in [[xc - 24.0, z - 24.0], [xc - 30.0, z + 26.0], [xc - 16.0, z + 46.0], [xc - 40.0, z - 4.0]]:
		var p := Vector2(h[0], h[1])
		if altura(p.x, p.y) < 0.8: continue
		_casa(Vector3(p.x, altura(p.x, p.y) - 0.2, p.y), atan2(xc - p.x, z - p.y) + PI, 5.0, 4.4, 2.7)
	for b in [[xc - 2.0, z + 3.0], [xc - 1.0, z + 3.6], [xc - 3.0, z - 3.0]]:
		_barril(Vector3(b[0], altura(b[0], b[1]), b[1]))
	lugares.append([Vector2(xc - 20.0, z), 45.0])

func _mosteiro() -> void:
	var c := Vector2(Regiao.ILHA.x, Regiao.ILHA.y); var y := reg.aplanar(c + Vector2(2.5, -1.5), Vector2(8.0, 6.0), 0.0, 3.0)
	_casa(Vector3(c.x, y - 0.3, c.y), PI / 2, 8.0, 6.0, 4.0, mat("pedra"), mat("madeira", 1.0, Color(0.55, 0.5, 0.55)))
	var tp := Vector3(c.x + 5.5, y - 0.6, c.y - 3.0)
	var st := _st(); cilindro(st, Vector3.ZERO, 2.0, 1.8, 11.0, 8, true); _peca(st, mat("pedra"), tp)
	st = _st(); cilindro(st, Vector3(0, 11.0, 0), 2.6, 0.0, 4.0, 8); _peca(st, mat("madeira", 1.0, Color(0.55, 0.5, 0.55)), tp)
	_colisor_cilindro(tp, 2.0, 11.0)
	# passarela da margem até a ilha
	var a := Vector2(-112, -300); var b := Vector2(-153, -297)
	var yp := reg.nivel_lago() + 0.6
	st = _st()
	var n := int(a.distance_to(b) / 1.5)
	for i in n + 1:
		var q := a.lerp(b, float(i) / n)
		_caixa(st, Vector3(q.x, yp, q.y), Vector3(1.4, 0.15, 1.6))
		if i % 3 == 0: _caixa(st, Vector3(q.x, yp - 1.5, q.y), Vector3(0.25, 3.0, 0.25))
	_peca(st, mat("madeira"), Vector3.ZERO, 0.0).rotation.y = 0.0
	var mid := (a + b) * 0.5
	_colisor_caixa(Vector3(mid.x, yp - 0.1, mid.y), Vector3(1.6, 0.2, a.distance_to(b) + 2.0), atan2(b.x - a.x, b.y - a.y))
	lugares.append([c, 18.0])

func _ruinas() -> void:
	var c := Vector2(220, -260); var y := reg.aplanar(c, Vector2(5.0, 5.0), 0.0, 6.0)
	var st := _st(); var rng := RandomNumberGenerator.new(); rng.seed = 3
	for k in 10:                                         # torre quebrada: anel de pedras com alturas diferentes
		var a0 := TAU * k / 10.0; var a1 := TAU * (k + 1) / 10.0; var h := rng.randf_range(2.5, 9.0)
		var p0 := Vector3(cos(a0) * 3.4, 0, sin(a0) * 3.4); var p1 := Vector3(cos(a1) * 3.4, 0, sin(a1) * 3.4)
		_quad(st, p1, p0, p0 + Vector3(0, h, 0), p1 + Vector3(0, h, 0), 2, h / 2)
		_quad(st, p0 * 0.8, p1 * 0.8, p1 * 0.8 + Vector3(0, h, 0), p0 * 0.8 + Vector3(0, h, 0), 2, h / 2)
		_quad(st, p0 + Vector3(0, h, 0), p0 * 0.8 + Vector3(0, h, 0), p1 * 0.8 + Vector3(0, h, 0), p1 + Vector3(0, h, 0), 1, 0.3)
	var blocos := []
	for k in 9:                                          # muros caídos e blocos (assentados depois do terreno)
		var q := Vector3(rng.randf_range(-14, 14), 0, rng.randf_range(-14, 14))
		if q.length() < 5.0: continue
		blocos.append([Vector2(c.x + q.x, c.y + q.z), Vector3(rng.randf_range(1, 5), rng.randf_range(0.6, 2.2), rng.randf_range(0.6, 1.2)), rng.randf() * PI])
	_depois.append(func():
		var sb := _st()
		for bl in blocos:
			var p: Vector2 = bl[0]; var t: Vector3 = bl[1]; var giro: float = bl[2]
			var ymin := INF
			for o in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var w: Vector2 = p + (o * Vector2(t.x, t.z) * 0.5).rotated(-giro); ymin = minf(ymin, terreno.altura_malha(w.x, w.y))
			var bx := _st(); _caixa(bx, Vector3(0, t.y * 0.5 - 0.4, 0), t + Vector3(0, 0.4, 0))
			var mi := _peca(bx, mat("pedra"), Vector3(p.x, ymin, p.y)); mi.rotation.y = giro
			_colisor_caixa(Vector3(p.x, ymin - 0.4, p.y), t + Vector3(0, 0.4, 0), giro))
	_peca(st, mat("pedra"), Vector3(c.x, y - 0.8, c.y))
	_colisor_cilindro(Vector3(c.x, y - 0.8, c.y), 3.5, 6.0)
	lugares.append([c, 18.0])

func _serraria() -> void:
	var c := Vector2(286, -170); var y := reg.aplanar(c, Vector2(14.0, 12.0), 0.0, 5.0)   # a estrada chega na beira do pátio
	_casa(Vector3(c.x, y - 0.2, c.y), 0.4, 7.0, 5.0, 2.8, mat("madeira"), mat("madeira", 1.0, Color(0.6, 0.55, 0.5)))
	var st := _st()
	for pilha in [[8.0, 4.0], [9.0, -5.0], [-8.0, 6.0]]:
		for k in 6:
			var r := 0.35; var fila := k / 3; var col := k % 3
			var q := Vector3(pilha[0], y + r + fila * 0.6, pilha[1] + (col - 1) * 0.72 + fila * 0.36)
			var tmp := _st(); cilindro(tmp, Vector3(0, -2.5, 0), r, r, 5.0, 6, true)
			var mi := _peca(tmp, mat("casca"), Vector3(c.x, 0, c.y) + q); mi.rotation = Vector3(0, 0, PI / 2)
	for k in 5:
		var q := Vector2(c.x + randf_range(-14, 14), c.y + randf_range(-14, 14))
		cilindro(st, Vector3(q.x, altura(q.x, q.y) - 0.4, q.y), 0.4, 0.38, 0.8, 6, true)
	_peca(st, mat("casca"), Vector3.ZERO)
	lugares.append([c, 16.0])

func _bandidos() -> void:
	var c := Vector2(-330, 300)
	var yb := reg.aplanar(c, Vector2(11.0, 11.0), 0.0, 5.0)        # clareira plana do acampamento
	var st := _st()
	for k in 3:
		var a := TAU * k / 3.0 + 0.4; var q := c + Vector2(cos(a), sin(a)) * 7.0; var y := yb
		cilindro(st, Vector3(q.x, y - 0.3, q.y), 2.4, 0.0, 2.8, 4)
		_colisor_cilindro(Vector3(q.x, y - 0.1, q.y), 1.8, 2.4)
	_peca(st, mat("", 1.0, Color(0.55, 0.28, 0.22)), Vector3.ZERO)
	# fogueira: pedras + lenha + chamas em splats
	var y0 := yb
	st = _st(); cilindro(st, Vector3(c.x, y0 - 0.1, c.y), 0.9, 0.9, 0.25, 8); _peca(st, mat("pedra"), Vector3.ZERO)
	var chamas := []
	for k in 14:
		chamas.append([Vector3(c.x + randf_range(-0.35, 0.35), y0 + randf_range(0.2, 1.1), c.y + randf_range(-0.35, 0.35)),
			[Color(1.0, 0.75, 0.3), Color(0.98, 0.45, 0.15), Color(1.0, 0.9, 0.55)][k % 3], randf_range(0.25, 0.45)])
	_splats(chamas, Vector2(1, 1), false, 0.6)
	st = _st()
	var yc := yb
	for k in 4: _caixa(st, Vector3(c.x + 5 + k * 0.9, yc + 0.3, c.y - 6.0), Vector3(0.8, 1.0, 0.8))
	_peca(st, mat("madeira"), Vector3.ZERO)
	lugares.append([c, 14.0])

func _caverna() -> void:
	# boca de caverna no pé das montanhas a oeste
	var z := -200.0; var x := -420.0
	while x > -560.0 and altura(x, z) < base_vale(z) + 9.0: x -= 2.0
	var y := reg.aplanar(Vector2(x + 7.0, z), Vector2(4.0, 5.0), 0.0, 4.0)
	var st := _st()
	_caixa(st, Vector3(0, 1.4, -3.2), Vector3(3.0, 6.0, 2.0)); _caixa(st, Vector3(0, 1.4, 3.2), Vector3(3.0, 6.0, 2.0))
	_caixa(st, Vector3(0, 5.0, 0), Vector3(3.4, 1.6, 8.6))
	_peca(st, mat("pedra"), Vector3(x + 5.0, y - 0.5, z))
	st = _st(); _quad(st, Vector3(0, 0, 2.2), Vector3(0, 0, -2.2), Vector3(0, 4.3, -2.2), Vector3(0, 4.3, 2.2), 1, 1)
	_peca(st, mat("", 1.0, Color(0.02, 0.02, 0.03)), Vector3(x + 4.6, y - 0.5, z))
	_colisor_caixa(Vector3(x + 4.0, y - 0.5, z), Vector3(2.0, 6.0, 9.0), 0.0)
	lugares.append([Vector2(x + 5.0, z), 8.0])

func base_vale(z: float) -> float: return reg.base(z)

func _barricada() -> void:
	# paliçada fechando o desfiladeiro do norte (por enquanto não se passa): estacas enterradas 1,5 m na malha
	var z := -468.0
	_depois.append(func():
		var st := _st()
		for i in 112:
			var x := -45.0 + i * 0.8; var y := terreno.altura_malha(x, z)
			cilindro(st, Vector3(x, y - 1.5, z), 0.38, 0.32, 5.6, 5)
			cilindro(st, Vector3(x, y + 4.1, z), 0.32, 0.0, 0.7, 5)
		_peca(st, mat("casca"), Vector3.ZERO)
		_parede_colisao(Vector2(-45.5, z), Vector2(44.5, z), 1.2, 4.6))
	lugares.append([Vector2(0, z), 46.0])

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, uw: float, vh: float) -> void:
	var n := (b - a).cross(d - a).normalized()
	var uvs := [Vector2(0, vh), Vector2(uw, vh), Vector2(uw, 0), Vector2(0, 0)]
	var vs := [a, b, c, d]
	for k in [0, 1, 2, 0, 2, 3]:
		st.set_normal(n); st.set_color(Color.WHITE); st.set_uv(uvs[k]); st.add_vertex(vs[k])

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, uw: float, vh: float) -> void:
	var n := (b - a).cross(c - a).normalized()
	for k in 3:
		st.set_normal(n); st.set_color(Color.WHITE)
		st.set_uv([Vector2(0, vh), Vector2(uw, vh), Vector2(uw * 0.5, 0)][k]); st.add_vertex([a, b, c][k])

func _casa(pos: Vector3, ang: float, w: float, d: float, h: float, parede: Material = null, telhado: Material = null) -> void:
	var x := w / 2.0; var z := d / 2.0; var cume := h + w * 0.55; var beiral := 0.45
	var livre := _longe_da_estrada(Vector2(pos.x, pos.z), Vector2(x + 0.5, z + 0.5), ang)   # nunca em cima da estrada
	pos.x = livre.x; pos.z = livre.y
	pos.y = reg.aplanar(Vector2(pos.x, pos.z), Vector2(x + 0.8, z + 0.8), -ang, 4.0) - 0.05
	var mesh := ArrayMesh.new()
	# paredes (com as empenas triangulares) — textura enxaimel a cada 2 m
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var p := [Vector3(-x, 0, z), Vector3(x, 0, z), Vector3(x, 0, -z), Vector3(-x, 0, -z)]
	for k in 4:
		var a: Vector3 = p[k]; var b: Vector3 = p[(k + 1) % 4]
		_quad(st, a, b, b + Vector3(0, h, 0), a + Vector3(0, h, 0), a.distance_to(b) / 2.0, h / 2.0)
	_tri(st, Vector3(x, h, z), Vector3(x, h, -z), Vector3(x, cume, 0), d / 2.0, (cume - h) / 2.0)
	_tri(st, Vector3(-x, h, -z), Vector3(-x, h, z), Vector3(-x, cume, 0), d / 2.0, (cume - h) / 2.0)
	st.set_material(parede if parede else mat("parede")); st.commit(mesh)
	# telhado de palha (duas águas, com beiral)
	st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var xe := x + beiral; var ze := z + beiral; var hb := h - beiral * 0.5
	_quad(st, Vector3(-xe, hb, ze), Vector3(xe, hb, ze), Vector3(xe, cume, 0), Vector3(-xe, cume, 0), w / 2.0, 2.0)
	_quad(st, Vector3(xe, hb, -ze), Vector3(-xe, hb, -ze), Vector3(-xe, cume, 0), Vector3(xe, cume, 0), w / 2.0, 2.0)
	st.set_material(telhado if telhado else mat("palha")); st.commit(mesh)
	# base de pedra, porta e chaminé
	st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var e := 0.06
	for k in 4:
		var a: Vector3 = p[k] * Vector3(1 + e / x, 1, 1 + e / z); var b: Vector3 = p[(k + 1) % 4] * Vector3(1 + e / x, 1, 1 + e / z)
		_quad(st, a + Vector3(0, -1.2, 0), b + Vector3(0, -1.2, 0), b + Vector3(0, 0.6, 0), a + Vector3(0, 0.6, 0), a.distance_to(b) / 2.0, 0.9)
	_caixa(st, Vector3(x * 0.45, cume - 0.6, -z * 0.3), Vector3(0.7, 2.2, 0.7))
	st.set_material(mat("pedra")); st.commit(mesh)
	st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_quad(st, Vector3(-0.55, 0.0, z + 0.08), Vector3(0.55, 0.0, z + 0.08), Vector3(0.55, 2.0, z + 0.08), Vector3(-0.55, 2.0, z + 0.08), 1.0, 1.4)
	for jx in [-x * 0.6, x * 0.6]:
		_quad(st, Vector3(jx - 0.4, 1.2, z + 0.08), Vector3(jx + 0.4, 1.2, z + 0.08), Vector3(jx + 0.4, 1.9, z + 0.08), Vector3(jx - 0.4, 1.9, z + 0.08), 0.6, 0.5)
	st.set_material(mat("madeira", 1.0, Color(0.55, 0.5, 0.5))); st.commit(mesh)
	var mi := MeshInstance3D.new(); mi.mesh = mesh; mi.position = pos; mi.rotation.y = ang; raiz.add_child(mi)
	# colisão: caixa das paredes
	var corpo := StaticBody3D.new(); var cs := CollisionShape3D.new(); var bx := BoxShape3D.new()
	bx.size = Vector3(w, h + 2.0, d); cs.shape = bx; cs.position = Vector3(0, (h + 2.0) / 2.0, 0)
	corpo.add_child(cs); corpo.position = pos; corpo.rotation.y = ang; raiz.add_child(corpo)
	casas.append([pos, ang, w, d]); lugares.append([Vector2(pos.x, pos.z), max(w, d) * 0.7])

func _caixa(st: SurfaceTool, c: Vector3, s: Vector3) -> void:
	var h := s / 2.0
	var v := func(a: float, b: float, cc: float) -> Vector3: return c + Vector3(a * h.x, b * h.y, cc * h.z)
	_quad(st, v.call(-1, -1, 1), v.call(1, -1, 1), v.call(1, 1, 1), v.call(-1, 1, 1), s.x / 2, s.y / 2)
	_quad(st, v.call(1, -1, -1), v.call(-1, -1, -1), v.call(-1, 1, -1), v.call(1, 1, -1), s.x / 2, s.y / 2)
	_quad(st, v.call(1, -1, 1), v.call(1, -1, -1), v.call(1, 1, -1), v.call(1, 1, 1), s.z / 2, s.y / 2)
	_quad(st, v.call(-1, -1, -1), v.call(-1, -1, 1), v.call(-1, 1, 1), v.call(-1, 1, -1), s.z / 2, s.y / 2)
	_quad(st, v.call(-1, 1, 1), v.call(1, 1, 1), v.call(1, 1, -1), v.call(-1, 1, -1), s.x / 2, s.z / 2)

# cilindro low poly (lados poucos, como no PS1)
func cilindro(st: SurfaceTool, base: Vector3, r0: float, r1: float, alt: float, lados: int, tampa := false) -> void:
	for k in lados:
		var a0 := TAU * k / lados; var a1 := TAU * (k + 1) / lados
		var p0 := base + Vector3(cos(a0) * r0, 0, sin(a0) * r0); var p1 := base + Vector3(cos(a1) * r0, 0, sin(a1) * r0)
		var q0 := base + Vector3(cos(a0) * r1, alt, sin(a0) * r1); var q1 := base + Vector3(cos(a1) * r1, alt, sin(a1) * r1)
		if r1 < 0.001: _tri(st, p1, p0, q0, TAU * r0 / lados, alt / 2.0)
		else: _quad(st, p1, p0, q0, q1, TAU * r0 / lados, alt / 2.0)
		if tampa and r1 > 0.001: _tri(st, q1, q0, base + Vector3(0, alt, 0), r1, r1)

func _poco(pos: Vector3) -> void:
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	cilindro(st, Vector3.ZERO, 1.1, 1.1, 0.9, 8, true); st.set_material(mat("pedra")); st.commit(mesh)
	st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_caixa(st, Vector3(-0.95, 1.4, 0), Vector3(0.15, 1.8, 0.15)); _caixa(st, Vector3(0.95, 1.4, 0), Vector3(0.15, 1.8, 0.15))
	cilindro(st, Vector3(0, 2.3, 0), 1.5, 0.0, 0.9, 4)
	st.set_material(mat("madeira")); st.commit(mesh)
	var mi := MeshInstance3D.new(); mi.mesh = mesh; mi.position = pos; raiz.add_child(mi)
	_colisor_cilindro(pos, 1.15, 2.0)

func _barril(pos: Vector3) -> void:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	cilindro(st, Vector3(0, -0.15, 0), 0.32, 0.38, 0.6, 8); cilindro(st, Vector3(0, 0.45, 0), 0.38, 0.32, 0.45, 8, true)
	var mi := MeshInstance3D.new(); mi.mesh = st.commit(); mi.material_override = mat("madeira"); mi.position = pos
	raiz.add_child(mi); _colisor_cilindro(pos, 0.38, 0.9)

func _colisor_cilindro(pos: Vector3, r: float, h: float) -> void:
	var corpo := StaticBody3D.new(); var cs := CollisionShape3D.new(); var c := CylinderShape3D.new()
	c.radius = r; c.height = h; cs.shape = c; cs.position = Vector3(0, h / 2.0, 0); corpo.add_child(cs)
	corpo.position = pos; raiz.add_child(corpo)

# MultiMesh de splats: itens = [posição, cor, escala]
func _splats(itens: Array, tam: Vector2, em_pe: bool, balanco: float, ate := 0.0) -> MultiMeshInstance3D:
	var q := QuadMesh.new(); q.size = Vector2(1, 1)
	if em_pe: q.center_offset = Vector3(0, 0.5, 0)
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_colors = true; mm.mesh = q
	mm.instance_count = itens.size()
	for i in itens.size():
		var it: Array = itens[i]; var s: float = it[2]
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(tam.x * s, tam.y * s, 1)), it[0]))
		mm.set_instance_color(i, it[1])
	var sm := ShaderMaterial.new(); sm.shader = load("res://shaders/splat.gdshader")
	sm.set_shader_parameter("em_pe", em_pe); sm.set_shader_parameter("balanco", balanco); sm.set_shader_parameter("neblina", NEBLINA)
	var mi := MultiMeshInstance3D.new(); mi.multimesh = mm; mi.material_override = sm
	if ate > 0.0: mi.visibility_range_end = ate; mi.visibility_range_end_margin = 4.0
	raiz.add_child(mi); return mi

# teste: lista construções e campos em cima da estrada (pontos da área a menos de 2,6 m do meio da estrada)
func _checar_estrada() -> void:
	var ruins := 0
	for c in casas:
		var p: Vector3 = c[0]
		var d := _pior_estrada(Vector2(p.x, p.z), Vector2(c[2], c[3]) * 0.5, c[1])
		if d < 3.0: ruins += 1; print("CASA na estrada: %s  folga %.1f m" % [Vector2(p.x, p.z), d - 2.6])
	for cp in reg.campos:
		var d := _pior_estrada(Vector2(cp[0], cp[1]), Vector2(cp[2] + 2, cp[3] + 2) * 0.5, -deg_to_rad(cp[4]))
		if d < 3.0: ruins += 1; print("CAMPO na estrada: %s  folga %.1f m" % [Vector2(cp[0], cp[1]), d - 2.6])
	for pl in reg.planos:
		var d := _pior_estrada(pl[0], pl[1] - Vector2(1, 1), -pl[2])
		if d < 3.0: ruins += 1; print("PLANO na estrada: %s  folga %.1f m" % [pl[0], d - 2.6])
	print("na estrada: %d" % ruins)

# empurra um retângulo para longe da estrada até sobrar "folga" metros entre ele e a beira da estrada
func _longe_da_estrada(c: Vector2, meia: Vector2, ang: float, folga := 1.5) -> Vector2:
	var precisa := 2.6 + folga
	for it in 120:
		var pior := INF; var ponto := c
		for j in 5: for i in 5:
			var q: Vector2 = c + (Vector2(lerp(-1.0, 1.0, i / 4.0), lerp(-1.0, 1.0, j / 4.0)) * meia).rotated(-ang)
			var dq := reg.dist_estrada(q.x, q.y)
			if dq < pior: pior = dq; ponto = q
		if pior >= precisa: return c
		var e := 0.6
		var g := Vector2(reg.dist_estrada(ponto.x + e, ponto.y) - reg.dist_estrada(ponto.x - e, ponto.y),
			reg.dist_estrada(ponto.x, ponto.y + e) - reg.dist_estrada(ponto.x, ponto.y - e))
		if g.length() < 0.001: g = (c - ponto)
		if g.length() < 0.001: g = Vector2(1, 0)
		c += g.normalized() * 0.5
	return c

# menor distância do meio da estrada a um retângulo (centro, meia medida, ângulo como rotation.y)
func _pior_estrada(c: Vector2, meia: Vector2, ang: float) -> float:
	var pior := INF
	for j in 5: for i in 5:
		var q: Vector2 = c + (Vector2(lerp(-1.0, 1.0, i / 4.0), lerp(-1.0, 1.0, j / 4.0)) * meia).rotated(-ang)
		pior = minf(pior, reg.dist_estrada(q.x, q.y))
	return pior

# teste: mede o vão entre o piso de cada construção e o terreno de verdade (cantos e meio das bordas)
func _checar_chao() -> void:
	var pior := 0.0; var ruins := 0
	for pl in reg.planos:
		var c: Vector2 = pl[0]; var meia: Vector2 = pl[1] - Vector2(1.0, 1.0)
		for k in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(0, 1), Vector2(0, -1), Vector2(1, 0), Vector2(-1, 0)]:
			var q: Vector2 = c + (k * meia).rotated(pl[2])
			var vao: float = pl[3] - terreno.altura_malha(q.x, q.y)
			if abs(vao) > 0.25:
				ruins += 1; print("VÃO %.2f m em %s" % [vao, q])
			pior = max(pior, abs(vao))
	print("planos: %d  pior vão: %.2f m  pontos ruins: %d" % [reg.planos.size(), pior, ruins])
	get_tree().quit()

# ---------- modo de teste: --shot=arquivo.png --espera=2 --pos=x,z --olhar=graus ----------
func _modo_teste() -> void:
	if args.has("pos"):
		var pp := String(args.pos).split(","); jogador.position = Vector3(float(pp[0]), altura(float(pp[0]), float(pp[1])) + 0.3, float(pp[1])); _ultima = jogador.position
	if args.has("olhar"): jogador.rotation.y = deg_to_rad(float(args.olhar))
	if args.has("raio"): _prox_raio = 0.0
	if args.has("pose"): jogador.mostrar_pose(args.pose)
	if args.has("falar") and args.falar == "1":
		get_tree().create_timer(3.0).timeout.connect(func():
			for c in get_children():
				if c is CanvasLayer:
					for i in c.get_children():
						if i is Interacao: i._conversar())
	if args.has("ver"):          # teste: olha um trabalhador de perto (--ver=ferreiro|lenhador|fazendeiro[:lado])
		var partes := String(args.ver).split(":")
		for mo in raiz.get_children():
			if mo is Morador and mo.profissao == partes[0] and (not "arado" in partes or (not mo.campo.is_empty() and mo.campo[5] == 1)):
				if "arado" in partes: mo._alvo = Vector2(mo.global_position.x, mo.global_position.z); mo._tempo_estado = 1000.0
				var alvo3: Vector3 = mo.global_position
				var ang_v: float = mo.rotation.y + (PI * 0.5 if "lado" in partes else PI * 0.15)
				var pj := alvo3 + Vector3(-sin(ang_v), 0, -cos(ang_v)) * float(args.get("dist", "3.2"))
				jogador.global_position = Vector3(pj.x, altura(pj.x, pj.z) + 0.3, pj.z); _ultima = jogador.global_position
				var d3 := alvo3 - pj; jogador.rotation.y = atan2(-d3.x, -d3.z); break
	if args.has("ferraria"):
		var f3 := Vector3(ferraria_pos.x, 0, ferraria_pos.y); var dirf := (Vector3.ZERO - f3).normalized()
		var pj := f3 + dirf * 9.0; jogador.global_position = Vector3(pj.x, altura(pj.x, pj.z) + 0.3, pj.z)
		jogador.rotation.y = atan2(dirf.x, dirf.z)
	if args.has("npc"):          # teste: põe moradores parados em fila na frente do jogador
		var fr := -jogador.global_transform.basis.z; var lado := jogador.global_transform.basis.x
		var k := 0
		for mo in raiz.get_children():
			if mo is Morador and k < 5:
				var q: Vector3 = jogador.global_position + fr * 4.5 + lado * (k - 2) * 1.3
				mo.global_position = Vector3(q.x, altura(q.x, q.z) + 0.1, q.z); mo.rotation.y = jogador.rotation.y + PI
				mo.estado = "atividade"; mo._tempo_estado = 1000.0; mo._prox_conversa = 1000.0
				mo.atividade = String(args.npc) if args.npc != "1" else "olhar"
				mo._olhar_para = Vector2(jogador.global_position.x, jogador.global_position.z)
				if args.has("perfil"): mo._olhar_para = Vector2(q.x, q.z) + Vector2(lado.x, lado.z) * 10.0; mo.rotation.y = jogador.rotation.y - PI / 2
				if args.npc == "anda": mo.estado = "andar"; mo._alvo = Vector2(q.x, q.z) + Vector2(fr.x, fr.z) * -40.0
				if args.npc == "lado": mo.estado = "andar"; mo._alvo = Vector2(q.x, q.z) + Vector2(lado.x, lado.z) * 40.0
				k += 1
		if args.npc == "conversa":
			var ms := []
			for mo in raiz.get_children(): if mo is Morador and ms.size() < 2: ms.append(mo)
			for mo in raiz.get_children():
				if mo is Morador and not (mo in ms): mo.visible = false; mo.process_mode = Node.PROCESS_MODE_DISABLED
			ms[0]._prox_conversa = 0; ms[1]._prox_conversa = 0; ms[0].convidar(ms[1])
	if args.has("andar"):        # teste de colisão: anda para a frente N segundos e diz onde parou
		await get_tree().create_timer(2.0).timeout
		var ini := jogador.global_position
		controles.dir = Vector2(0, -1); controles.set_process(false)
		await get_tree().create_timer(float(args.andar)).timeout
		print("ANDOU de %s até %s" % [ini, jogador.global_position]); get_tree().quit(); return
	if args.has("golpe"):        # filma um golpe: --golpe=leve1 (ou combo) → varios PNGs a cada 1/30 s
		await get_tree().create_timer(float(args.get("espera", "2"))).timeout
		Engine.time_scale = float(args.get("lento", "0.16"))     # o jogo anda devagar: cada quadro ≈ 1/30 s de jogo
		var nomes := ["leve1", "leve2", "leve3"] if args.golpe == "combo" else [args.golpe]
		var q := 0
		for nm in nomes:
			jogador.iniciar(nm)
			for f in int(args.get("quadros", "20")):
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(String(args.shot).replace(".png", "-%02d.png" % q)); q += 1
		get_tree().quit(); return
	await get_tree().create_timer(float(args.get("espera", "2"))).timeout
	get_viewport().get_texture().get_image().save_png(args.shot)
	get_tree().quit()

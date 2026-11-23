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
# celular: corta mais distância e densidade (o mesmo jogo, mais leve). PC: "--celular" para testar assim.
var celular := OS.has_feature("mobile") or OS.get_cmdline_user_args().has("--celular")
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
var porto_pos := Vector2.ZERO
var caverna_pos := Vector2.ZERO
var pier_pos := Vector2.ZERO
var _depois: Array[Callable] = []    # peças montadas depois do terreno (precisam da altura exata da malha)
var args := {}
var _mats := {}
var _ultima := Vector3.ZERO

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var p := a.trim_prefix("--").split("=", true, 1)
		args[p[0]] = p[1] if p.size() > 1 else "1"
	var _tc := Time.get_ticks_msec()
	reg = Regiao.new(); estrada = reg.estradas[0]
	if args.has("carga"): print("CARGA regiao ", Time.get_ticks_msec() - _tc, " ms"); _tc = Time.get_ticks_msec()
	_tela()
	_ambiente()
	terreno = Terreno.new(); raiz.add_child(terreno)
	jogador = Jogador.new()
	_lugares()                      # antes do terreno: as construções aplanam o chão embaixo delas
	if args.has("carga"): print("CARGA lugares ", Time.get_ticks_msec() - _tc, " ms"); _tc = Time.get_ticks_msec()
	terreno.montar(self)
	if args.has("gerar_terreno"): return               # só gerando o terreno pronto (workflow do APK)
	if args.has("carga"): print("CARGA terreno ", Time.get_ticks_msec() - _tc, " ms"); _tc = Time.get_ticks_msec()
	for f in _depois: f.call()        # cercas, muros e blocos: assentados na malha final do terreno
	if args.has("carga"): print("CARGA depois ", Time.get_ticks_msec() - _tc, " ms"); _tc = Time.get_ticks_msec()
	_agua_feita = false
	_agua()
	if args.has("carga"): print("CARGA agua ", Time.get_ticks_msec() - _tc, " ms"); _tc = Time.get_ticks_msec()
	_espuma()
	if args.has("carga"): print("CARGA espuma ", Time.get_ticks_msec() - _tc, " ms"); _tc = Time.get_ticks_msec()
	_juntar_estaticos()
	if args.has("carga"): print("CARGA juntar ", Time.get_ticks_msec() - _tc, " ms"); _tc = Time.get_ticks_msec()
	var fl := Floresta.new(); raiz.add_child(fl); fl.montar(self); floresta = fl
	if args.has("carga"): print("CARGA floresta ", Time.get_ticks_msec() - _tc, " ms"); _tc = Time.get_ticks_msec()
	var chao := ChaoSplat.new(); raiz.add_child(chao); chao.montar(self)
	if args.has("carga"): print("CARGA chao ", Time.get_ticks_msec() - _tc, " ms"); _tc = Time.get_ticks_msec()
	var grama := Grama.new(); raiz.add_child(grama); grama.montar(self)
	if args.has("carga"): print("CARGA grama ", Time.get_ticks_msec() - _tc, " ms"); _tc = Time.get_ticks_msec()
	_moradores()
	if args.has("carga"): print("CARGA moradores ", Time.get_ticks_msec() - _tc, " ms"); _tc = Time.get_ticks_msec()
	raiz.add_child(jogador)
	# a Rachel começa no portão oeste de Altamar, logo antes de sair do reino, virada para a ponte (testes: --vila)
	var ini := Vector2(-4, 48) if args.has("vila") else Regiao.CIDADE_C + Vector2(-Regiao.CIDADE_R + 9.0, 0.0)
	jogador.position = Vector3(ini.x, altura(ini.x, ini.y) + 0.3, ini.y)
	if not args.has("vila"): jogador.rotation.y = PI * 0.5                # olhando para o oeste (portão e ponte)
	_ultima = jogador.position
	controles = Controles.new(); var cl := CanvasLayer.new(); add_child(cl); cl.add_child(controles)
	jogador.controles = controles
	bolsa.equipou.connect(func(lugar: String, id: String): jogador.trocar_equip(lugar, id))
	hud = Hud.new(); cl.add_child(hud); hud.montar(); hud.escala_3d = REDUCAO
	_carregar_progresso()
	_tela_dano = ColorRect.new(); _tela_dano.color = Color(0.7, 0.0, 0.0, 1.0); _tela_dano.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tela_dano.mouse_filter = Control.MOUSE_FILTER_IGNORE; _tela_dano.modulate.a = 0.0; cl.add_child(_tela_dano)
	cl.move_child(_tela_dano, hud.get_index())          # o vermelho fica embaixo do HUD (o "VOCÊ MORREU" por cima)
	var inter := Interacao.new(); cl.add_child(inter); inter.montar(self); interacao = inter
	inventario = Inventario.new(); cl.add_child(inventario); inventario.montar(self)
	saque = Saque.new(); cl.add_child(saque); saque.montar(self)
	loja_ui = Loja.new(); cl.add_child(loja_ui); loja_ui.montar(self)
	mapa = Mapa.new(); cl.add_child(mapa); mapa.montar(self)
	montaria_ui = Montaria.new(); cl.add_child(montaria_ui); montaria_ui.montar(self)
	menu = Menu.new(); cl.add_child(menu); menu.montar(self)
	# bússola com os locais importantes: [nome, posição, ícone, raio para descobrir]
	var bus := Bussola.new(); cl.add_child(bus)
	bus.descobriu.connect(func(_n): hud.ganhar_xp(roundf(40.0 + 20.0 * hud.nivel)))      # descobrir um local dá XP
	bus.montar(self, [
		["Vila do Vale", Vector2(0, 0), "vila", 45.0],
		["Ferraria do Bram", ferraria_pos, "ferraria", 12.0],
		["Mosteiro da Ilha", Vector2(Regiao.ILHA.x, Regiao.ILHA.y), "torre", 30.0],
		["Porto dos Pescadores", porto_pos, "farol", 30.0],
		["Píer do Rio", pier_pos, "agua", 14.0],
		["Moinho", Regiao.W(Vector2(-244, 100)), "moinho", 18.0],
		["Torre em Ruínas", Regiao.W(Vector2(220, -260)), "ruinas", 25.0],
		["Serraria", Regiao.W(Vector2(286, -170)), "arvore", 22.0],
		["Acampamento de Bandidos", Regiao.W(Vector2(-330, 300)), "bandidos", 25.0],
		["Caverna do Oeste", caverna_pos, "caverna", 18.0],
		["Gruta dos Lodosos", Regiao.GRUTA_ENTRADA, "caverna", 16.0],
		["Desfiladeiro do Norte", Vector2(0, -Regiao.Ws(468.0)), "montanhas", 40.0],
		["Altamar", cidade_pos, "castelo", 200.0],
	] + barracas.map(func(b: Vector2) -> Array: return ["Acampamento", b, "tenda", 14.0]))
	fauna.montar(self)
	praia.montar(self)
	if args.has("carga"): print("CARGA fauna ", Time.get_ticks_msec() - _tc, " ms"); _tc = Time.get_ticks_msec()
	_montar_chuva()
	_montar_vento()
	if args.has("chuva"): _chuva_alvo = float(args.chuva); chuva = _chuva_alvo
	_musica()
	if args.has("carga"): print("CARGA musica ", Time.get_ticks_msec() - _tc, " ms"); _tc = Time.get_ticks_msec()
	if args.has("estrada"): _checar_estrada(); get_tree().quit(); return
	if args.has("checar"): _checar_chao()
	if args.has("shot"): _modo_teste()

# moradores: o mesmo modelo com cores e alturas sorteadas, andando pela vila (e alguns no porto e nas fazendas)
func _moradores() -> void:
	var grupos := [[Vector2(-3, 0), 58.0, 12], [porto_pos + Vector2(-25, 0), 30.0, 3], [Regiao.W(Vector2(-215, 60)), 40.0, 3],
		[cidade_pos + Vector2(0, 30), 120.0, 18], [cidade_pos + Vector2(-140, 0), 60.0, 6], [cidade_pos + Vector2(120, 60), 60.0, 6]]
	var n := 0
	for g in grupos:
		for i in g[2]:
			var _ta := Time.get_ticks_usec()
			var mo := Morador.new(); raiz.add_child(mo)
			var _tb := Time.get_ticks_usec()
			var a := randf() * TAU; var p: Vector2 = g[0] + Vector2(cos(a), sin(a)) * randf_range(4.0, g[1] * 0.8)
			for t in 20:
				if not perto_de_casa(p.x, p.y, 1.5): break
				a = randf() * TAU; p = g[0] + Vector2(cos(a), sin(a)) * randf_range(4.0, g[1] * 0.8)
			var _tc2 := Time.get_ticks_usec()
			mo.position = Vector3(p.x, altura(p.x, p.y) + 0.3, p.y)
			mo.montar(self, 1000 + n, g[0], g[1]); n += 1
			var _dt := (Time.get_ticks_usec() - _ta) / 1000.0
			if args.has("carga") and _dt > 50.0: print("MOR lento n=%d add=%.1f busca=%.1f resto=%.1f ms grupo=%s" % [n, (_tb - _ta) / 1000.0, (_tc2 - _tb) / 1000.0, (Time.get_ticks_usec() - _tc2) / 1000.0, str(g[0])])
	var _t1 := Time.get_ticks_msec()
	_profissionais()
	if args.has("carga"): print("CARGA  profissionais ", Time.get_ticks_msec() - _t1); _t1 = Time.get_ticks_msec()
	_criancas()
	if args.has("carga"): print("CARGA  criancas ", Time.get_ticks_msec() - _t1)
	var _t_lobos := Time.get_ticks_msec()
	_lobos()
	if args.has("carga"): print("CARGA  _lobos ", Time.get_ticks_msec() - _t_lobos)
	var _t_aranhas := Time.get_ticks_msec()
	_aranhas()
	if args.has("carga"): print("CARGA  _aranhas ", Time.get_ticks_msec() - _t_aranhas)
	var _t_lodosos := Time.get_ticks_msec()
	_lodosos()
	_gruta_iniciar()
	if args.has("carga"): print("CARGA  _lodosos ", Time.get_ticks_msec() - _t_lodosos)
	var _t_golem := Time.get_ticks_msec()
	_golem()
	if args.has("carga"): print("CARGA  _golem ", Time.get_ticks_msec() - _t_golem)
	fauna = Fauna.new(); raiz.add_child(fauna)
	praia = Praia.new(); raiz.add_child(praia)
	# já começam algumas conversas na vila
	var vila := []
	for mo in raiz.get_children():
		if mo is Morador and Vector2(mo.position.x, mo.position.z).length() < 45.0: vila.append(mo)
	for k in range(0, mini(vila.size() - 1, 4), 2): vila[k].convidar(vila[k + 1])

# ---------- lobos ----------
# matilhas de 4 a 6 com um líder preto (maior): brancos só nas montanhas, marrons só nas florestas.
var hud: Hud
var heroina_desmaiada := false
# medição de "trancos": quanto cada sistema gasta montando pedaços do mundo (só com --picos)
var _picos := {}
func pico(nome: String, t0: int) -> void:
	if not args.has("picos"): return
	var dt := (Time.get_ticks_usec() - t0) / 1000.0
	var p: Array = _picos.get(nome, [0, 0.0, 0.0]); p[0] += 1; p[1] += dt; p[2] = maxf(p[2], dt); _picos[nome] = p
var estatuas := []                # Estátuas da Guardiã (onde a Rachel renasce): [posição, direção da frente]
var morte_pos := Vector2.ZERO     # onde a Rachel morreu por último (caveirinha no mapa e na bússola por 5 min)
var morte_ate := -1.0
func morte_marcada() -> bool: return morte_ate > _tempo_jogo()
var _tela_dano: ColorRect
var matilhas := []
var fauna: Fauna
var praia: Praia
var interacao: Interacao
var inventario: Inventario
var saque: Saque
var loja_ui: Loja
var mapa: Mapa
var menu: Menu
func _lobos() -> void:
	var _tl0 := Time.get_ticks_msec()
	var rng := RandomNumberGenerator.new(); rng.seed = 404
	var montanha := []; var mata := []
	for i in 24000:
		var q := Vector2(rng.randf_range(Regiao.X0 + 60, Regiao.X1 - 60), rng.randf_range(-Regiao.LIM + 60, Regiao.LIM - 60))
		# verificações baratas (grades e contas simples) primeiro; a altura do terreno (cara) só no fim
		if q.length() < 120.0 or reg.dist_rio(q.x, q.y) < 20.0 or reg.dist_rio2(q.x, q.y) < 20.0 or reg.folga_caminho(q.x, q.y) < 12.0: continue
		if reg.na_cidade(q.x, q.y, 40.0) or reg.campo_em(q.x, q.y) >= 0 or perto_de_lugar(q.x, q.y, 30.0): continue
		var h0 := reg.altura(q.x, q.y)
		if h0 < 1.0 or (h0 - reg.base(q.y) <= 5.0 and reg.floresta(q.x, q.y) <= 0.5): continue    # nem montanha nem mata
		var longe_barraca := true
		for b in barracas: if q.distance_to(b) < 60.0: longe_barraca = false; break
		if not longe_barraca: continue
		if reg.agua(q.x, q.y) != 0.0: continue
		var desn := 0.0
		for o in [Vector2(5, 0), Vector2(-5, 0), Vector2(0, 5), Vector2(0, -5)]:
			desn = maxf(desn, absf(reg.altura(q.x + o.x, q.y + o.y) - h0))
		if desn > 2.2: continue
		if h0 - reg.base(q.y) > 5.0: montanha.append(q)
		elif reg.floresta(q.x, q.y) > 0.5: mata.append(q)
	if args.has("carga"): print("CARGA   lobos sorteio ", Time.get_ticks_msec() - _tl0)
	var escolhidos := []
	for lista in [[montanha, "branco", 50], [mata, "marrom", 100]]:
		var cands: Array = lista[0]; var feitos := 0
		cands.shuffle()
		for q in cands:
			if feitos >= lista[2]: break
			var ok := true
			for e in escolhidos: if q.distance_to(e) < 60.0: ok = false
			if not ok: continue
			escolhidos.append(q); feitos += 1
			_matilha(q, lista[1], rng)
	# grupinhos de 3 lobos marrons de nível 1–2 nas matas mais perto da vila (para quem está começando)
	var perto := []
	for i in 3000:
		var q := Vector2(rng.randf_range(-330, 330), rng.randf_range(-330, 330))
		if q.length() < 85.0 or q.length() > 320.0 or reg.folga_caminho(q.x, q.y) < 8.0 or reg.agua(q.x, q.y) != 0.0: continue
		if perto_de_lugar(q.x, q.y, 20.0) or reg.campo_em(q.x, q.y) >= 0 or perto_de_casa(q.x, q.y, 12.0): continue
		if reg.floresta(q.x, q.y) < 0.3 or reg.altura(q.x, q.y) - reg.base(q.y) > 5.0: continue
		perto.append(q)
	perto.shuffle()
	var feitos2 := 0
	for q in perto:
		if feitos2 >= 22: break
		var ok := true
		for e in escolhidos: if q.distance_to(e) < 55.0: ok = false
		if not ok: continue
		escolhidos.append(q); feitos2 += 1
		_matilha(q, "marrom", rng, true)

# criar monstros DEPOIS do carregamento, alguns por quadro (os mais perto da Rachel primeiro): antes os ~650 eram
# criados antes da primeira imagem (~5 s de carregamento a mais). Os grupos já existem; os membros vão chegando.
var _fila_criar := []            # [posição, Callable]
var _fila_ordenada := false
func _criar_depois(p: Vector2, f: Callable) -> void:
	_fila_criar.append([p, f]); _fila_ordenada = false
func _tick_criar() -> void:
	if _fila_criar.is_empty() or jogador == null: return
	if not _fila_ordenada:
		var pj := Vector2(jogador.global_position.x, jogador.global_position.z)
		_fila_criar.sort_custom(func(a, b): return a[0].distance_squared_to(pj) > b[0].distance_squared_to(pj))   # mais perto no fim
		_fila_ordenada = true
	var t0 := Time.get_ticks_usec()
	while not _fila_criar.is_empty() and Time.get_ticks_usec() - t0 < 3000:      # até 3 ms por quadro
		_fila_criar.pop_back()[1].call()

func _matilha(c: Vector2, tipo: String, rng: RandomNumberGenerator, pequena := false) -> void:
	var n := 3 if pequena else rng.randi_range(2, 3)             # no máximo 3 lobos por grupo
	var g := {"casa": c, "membros": [], "alerta": false, "atacante": null, "tipo": tipo}
	# nível: marrons (floresta) 2–3, brancos (montanha) 4–6; o líder um nível acima do maior
	var nv_min := 2 if tipo == "marrom" else 4; var nv_max := 3 if tipo == "marrom" else 6
	if pequena: nv_min = 1; nv_max = 2                      # grupinhos de 3 de nível 1–2, sem líder
	for i in n:
		var lider := i == 0 and not pequena
		var a := TAU * i / n + rng.randf() * 0.4; var r := 0.0 if i == 0 else rng.randf_range(3.0, 6.0)
		var p := c + Vector2(cos(a), sin(a)) * r
		var nv := nv_max + 1 if lider else rng.randi_range(nv_min, nv_max)
		var semente := rng.randi(); var giro := rng.randf() * TAU; var vaga := TAU * i / n
		_criar_depois(p, func():
			var lobo := Lobo.new(); lobo.grupo = g
			var ps := ponto_seco(p, c)
			raiz.add_child(lobo); lobo.position = Vector3(ps.x, altura_malha(ps.x, ps.y), ps.y)
			lobo.vaga = vaga; lobo.nivel = nv
			lobo.montar(self, "preto" if lider else tipo, lider, semente)
			lobo.rotation.y = giro; lobo.reset_physics_interpolation()
			g.membros.append(lobo))
	matilhas.append(g)

# ---------- status de combate (como no WoW Classic) ----------
# dano do golpe = dano da arma (mín–máx) + bônus de força pelo nível; 5% de crítico (dobro).
func bonus_dano() -> float: return 4.0 + hud.nivel * 1.0
func rolar_dano(mult: float) -> Array:
	var a: Dictionary = Bolsa.ITENS[bolsa.equip.arma]
	var d := randf_range(a.dano_min, a.dano_max) + bonus_dano()
	var crit := randf() < 0.05
	return [maxf(1.0, roundf(d * mult * (2.0 if crit else 1.0))), crit]

func armadura() -> int:
	var e: String = bolsa.equip.get("escudo", "")
	return int(Bolsa.ITENS[e].armadura) if e != "" else 0

# mordida: a armadura tira um pouco de todo dano (fórmula do Classic); com o escudo só equipado há 5% de chance
# de bloquear sozinho (tira o valor de bloqueio). Segurando o escudo de frente: o 1º ataque depois de levantar
# é bloqueado inteiro e os seguintes perdem boa parte do dano. Devolve true quando bloqueou inteiro.
func ferir_heroina(dano: float, de: Vector3, nivel_atacante := 1) -> bool:
	if heroina_desmaiada: return false
	var fr := -jogador.global_transform.basis.z; var d := de - jogador.global_position; d.y = 0.0
	var de_frente := fr.dot(d.normalized()) > 0.3
	var e: String = bolsa.equip.get("escudo", "")
	var esc: Dictionary = Bolsa.ITENS[e] if e != "" else {}
	var bloqueado := 0.0
	if not esc.is_empty() and de_frente and jogador.bloqueando:
		if jogador.bloqueios_desde_erguer == 0:
			jogador.bloqueios_desde_erguer += 1; jogador.impacto(0.05)
			hud.numero_heroi("Bloqueado", Color(0.85, 0.85, 0.85)); return true
		jogador.bloqueios_desde_erguer += 1; jogador.impacto(0.03)
		var antes := dano
		dano = dano * (1.0 - float(esc.bloqueio_ativo)) - float(esc.bloqueio)
		bloqueado = antes - maxf(dano, 0.0)
	elif not esc.is_empty() and de_frente and randf() < 0.05:
		bloqueado = minf(dano, float(esc.bloqueio)); dano -= bloqueado
	var arm := armadura()
	dano *= 1.0 - float(arm) / (arm + 400.0 + 85.0 * nivel_atacante)
	dano = maxf(0.0, roundf(dano))
	if dano <= 0.0:
		hud.numero_heroi("Bloqueado", Color(0.85, 0.85, 0.85)); return false
	hud.numero_heroi("-%d" % dano + ("  (%d bloqueado)" % bloqueado if bloqueado >= 1.0 else ""), Color(1.0, 0.3, 0.25))
	hud.vida = maxf(0.0, hud.vida - dano)
	if args.has("lobos"): print("MORDIDA: vida %d  t=%.2f  fps=%d" % [hud.vida, Lobo._relogio(), Engine.get_frames_per_second()])
	jogador._tranco += Vector3(-2.5, randf_range(-3.0, 3.0), 0.0)
	_tela_dano.modulate.a = 0.35
	var tw := _tela_dano.create_tween(); tw.tween_property(_tela_dano, "modulate:a", 0.0, 0.4)
	if hud.vida <= 0.0: _desmaiar()
	return false

# vida zerou: a Rachel cai (a câmera tomba até o chão), a tela fica vermelha e aparece "VOCÊ MORREU"; depois
# escurece e ela desperta de frente para a Estátua da Guardiã mais perto de onde caiu, com a vida cheia
func _desmaiar() -> void:
	heroina_desmaiada = true
	for g in matilhas: g.alerta = false; g.atacante = null
	jogador.morrer()
	if montaria_ui: montaria_ui.cancelar()
	morte_pos = Vector2(jogador.global_position.x, jogador.global_position.z); morte_ate = _tempo_jogo() + 300.0
	_tela_dano.color = Color(0.55, 0.0, 0.0, 1.0); _tela_dano.modulate.a = 0.0
	var tw := _tela_dano.create_tween()
	tw.tween_property(_tela_dano, "modulate:a", 0.55, 1.1)
	tw.tween_callback(func(): hud.morte = true)
	tw.tween_interval(3.2)
	tw.tween_property(_tela_dano, "color", Color(0, 0, 0, 1), 1.0)
	tw.parallel().tween_property(_tela_dano, "modulate:a", 1.0, 1.0)
	tw.tween_callback(_renascer)
	tw.tween_interval(0.9)
	tw.tween_property(_tela_dano, "modulate:a", 0.0, 1.3)
	tw.tween_callback(func(): _tela_dano.color = Color(0.7, 0, 0, 1); heroina_desmaiada = false)

func _renascer() -> void:
	hud.morte = false
	var pj := Vector2(jogador.global_position.x, jogador.global_position.z)
	var melhor: Array = []; var md := 1e9
	for e in estatuas:
		var d: float = (e[0] as Vector2).distance_to(pj)
		if d < md: md = d; melhor = e
	var p := Vector2(-4, 48); var olha := Vector2(-4, 40)
	if not melhor.is_empty(): olha = melhor[0]; p = melhor[0] + (melhor[1] as Vector2) * 4.5
	jogador.global_position = Vector3(p.x, altura(p.x, p.y) + 0.3, p.y); jogador.velocity = Vector3.ZERO; jogador.reset_physics_interpolation()
	var d2 := olha - p; jogador.rotation.y = atan2(-d2.x, -d2.y)
	jogador.reviver()
	hud.vida = hud.vida_max
	hud.avisar("Você despertou aos pés da Estátua da Guardiã.", Color(0.85, 0.9, 1.0))

# lobo morto: XP (o líder dá um pouco mais) e deixa dentes e garras na bolsa
# nenhum monstro pode ficar dentro d'água (rio, lago, canal, fosso, mar ou poças do pântano)
func na_agua(x: float, z: float) -> bool:
	var h := altura_malha(x, z)
	if h < 0.35: return true                                          # mar e pântano (nível 0)
	var nv := reg.agua(x, z)
	if nv != 0.0 and h < nv + 0.15: return true
	return false
# um ponto em terra seca perto de "p" (procura em volta de "centro" se p estiver na água)
func ponto_seco(p: Vector2, centro: Vector2) -> Vector2:
	if not na_agua(p.x, p.y): return p
	for k in 60:
		var a := k * 2.4; var r := 3.0 + k * 1.2
		var q := centro + Vector2(cos(a), sin(a)) * r
		if not na_agua(q.x, q.y) and not na_agua(q.x + 2.0, q.y) and not na_agua(q.x - 2.0, q.y) and not na_agua(q.x, q.y + 2.0) and not na_agua(q.x, q.y - 2.0): return q
	return p

# ---------- monstros novos ----------
# aranhas: uma só por lugar, na mata fechada, longe umas das outras (nível 3–5)
func _aranhas() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 707
	var feitos: Array[Vector2] = []
	for i in 30000:
		if feitos.size() >= 100: break
		var q := Vector2(rng.randf_range(Regiao.X0 + 60, Regiao.X1 - 60), rng.randf_range(-Regiao.LIM + 60, Regiao.LIM - 60))
		if q.length() < 170.0 or reg.dist_rios(q.x, q.y) < 18.0 or reg.folga_caminho(q.x, q.y) < 10.0 or reg.na_cidade(q.x, q.y, 40.0): continue
		if reg.floresta(q.x, q.y) < 0.5 or perto_de_lugar(q.x, q.y, 25.0): continue
		var ok := true
		for f in feitos: if q.distance_to(f) < 55.0: ok = false
		if not ok: continue
		for g in matilhas: if q.distance_to(g.casa) < 35.0: ok = false
		if not ok: continue
		var ha := reg.altura(q.x, q.y)                               # a parte cara só para quem passou no resto
		if ha < 1.5 or ha - reg.base(q.y) > 6.0 or reg.agua(q.x, q.y) != 0.0: continue
		feitos.append(q)
		var ga := {"casa": q, "membros": [], "alerta": false, "tipo": "aranha"}
		var nv := rng.randi_range(3, 5); var semente := rng.randi(); var giro := rng.randf() * TAU
		var qa := q
		_criar_depois(qa, func():
			var a := Aranha.new(); a.grupo = ga
			var ps := ponto_seco(qa, qa); ga.casa = ps
			raiz.add_child(a); a.position = Vector3(ps.x, altura_malha(ps.x, ps.y), ps.y)
			a.montar(self, nv, semente); a.rotation.y = giro; a.reset_physics_interpolation()
			ga.membros.append(a))
		matilhas.append(ga)

# Lodosos (peixe-sapo): grupos de no máximo 3 em pontos da praia (a costa inteira), das duas margens dos rios e do
# lago, cada um com seu acampamento (cabanas de palafita, varal de peixes, rede, monte de tralhas, fogueira).
# Composição: um Pescador (ou um Xamã da Lama) + Jovens. O Grão-Lodoso (chefe) fica na foz do rio do leste.
const LODOSOS_MAX := 70
# água sem montar a malha do terreno (na_agua usa a malha: caro na carga, quando o pedaço ainda não existe)
func _molhado(x: float, z: float) -> bool:
	var h := reg.altura(x, z)
	if h < 0.35: return true
	var nv := reg.agua(x, z)
	return nv != 0.0 and h < nv + 0.15
func linha_praia(z: float) -> float:          # x onde a areia encontra o mar nesta latitude (ou -1 se não achar)
	var x := 2040.0
	if reg.altura(x, z) <= 1.2 or reg.altura(x - 40.0, z) <= 1.2: return -1.0     # pântano / porto: não é praia
	while x < Regiao.X1 and reg.altura(x, z) > 1.0: x += 8.0
	if x >= Regiao.X1: return -1.0
	x -= 8.0
	while x < Regiao.X1 and reg.altura(x, z) > 1.0: x += 1.0
	return x

func _lodosos() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 909
	var cands: Array[Vector2] = []
	var r := reg.rio
	for i in r.size() - 1:
		for u in [0.2, 0.5, 0.8]:
			var a: Vector2 = r[i]; var b: Vector2 = r[i + 1]; var pt := a.lerp(b, u)
			var nrm := Vector2(-(b - a).normalized().y, (b - a).normalized().x) * (1.0 if rng.randf() < 0.5 else -1.0)
			var t: float = (float(i) + float(u)) / (r.size() - 1)
			cands.append(pt + nrm * (reg.largura_rio(t) * 0.5 + 5.0))
	for k in 6:
		var ang := TAU * k / 6.0 + 0.3
		cands.append(Vector2(Regiao.LAGO.x, Regiao.LAGO.y) + Vector2(cos(ang), sin(ang)) * (Regiao.LAGO.z + 6.0))
	var z := Regiao.Z0 + 60.0                                # praia: a costa inteira, de 45 em 45 m
	while z < Regiao.Z1 - 60.0:
		var x := linha_praia(z)
		if x > 0.0: cands.append(Vector2(x - rng.randf_range(6.0, 14.0), z))
		z += 45.0
	var r2 := reg.rio2                                       # rio do leste, nas duas margens
	for i in r2.size() - 1:
		for u in [0.15, 0.5, 0.85]:
			var a2: Vector2 = r2[i]; var b2: Vector2 = r2[i + 1]; var pt2 := a2.lerp(b2, u)
			var nrm2 := Vector2(-(b2 - a2).normalized().y, (b2 - a2).normalized().x) * (1.0 if rng.randf() < 0.5 else -1.0)
			var q2 := pt2 + nrm2 * (reg.largura_rio2(lerpf(reg._rio2_comp[i], reg._rio2_comp[i + 1], u)) * 0.5 + 6.0)
			cands.append(q2)
	cands.shuffle()
	# acampamento grande na foz do rio do leste (o Grão-Lodoso mora no fundo da Gruta dos Lodosos)
	var foz: Vector2 = r2[r2.size() - 3].lerp(r2[r2.size() - 2], 0.5)
	var nf := (r2[r2.size() - 2] - r2[r2.size() - 3]).normalized().orthogonal()
	var chefe := foz + nf * (reg.largura_rio2(0.9) * 0.5 + 9.0)
	var feitos: Array[Vector2] = []
	for q0 in [chefe] + cands:
		var q: Vector2 = q0
		if feitos.size() >= LODOSOS_MAX: break
		var e_chefe: bool = feitos.is_empty()
		if not e_chefe:
			if q.length() < 160.0 or reg.dist_estrada(q.x, q.y) < 12.0 or perto_de_lugar(q.x, q.y, 18.0) or perto_de_casa(q.x, q.y, 10.0): continue
			if reg.na_cidade(q.x, q.y, 70.0) or reg.altura(q.x, q.y) > 30.0: continue
		if e_chefe:                                  # o chefe: anda para longe do rio até achar chão seco
			for k in 12: if _molhado(q.x, q.y): q += nf * 3.0
		if _molhado(q.x, q.y): continue
		var ok := true
		for f in feitos: if q.distance_to(f) < 42.0: ok = false
		if not ok: continue
		feitos.append(q)
		var g := {"casa": q, "membros": [], "alerta": false, "tipo": "lodoso"}
		var tipos: Array = ["lodoso_g", "lodoso_x", "lodoso_j"] if e_chefe else \
			[("lodoso_x" if rng.randf() < 0.25 else "lodoso_g")] + (["lodoso_j", "lodoso_j"] if rng.randf() < 0.7 else ["lodoso_j"])
		for j in tipos.size():
			var p := q + Vector2(cos(TAU * j / 3.0), sin(TAU * j / 3.0)) * (0.0 if j == 0 else 2.5)
			var tp: String = tipos[j]
			var nv := 7 if tp == "lodoso_c" else (rng.randi_range(3, 5) if tp != "lodoso_j" else rng.randi_range(2, 4))
			var semente := rng.randi(); var giro := rng.randf() * TAU
			var ql := q
			_criar_depois(p, func():
				var mo := Monstro.new(); mo.grupo = g
				if tp == "lodoso_c": mo.nome = NOME_CHEFE_LODOSO; chefe_lodoso = mo
				var ps := ponto_seco(p, ql)
				raiz.add_child(mo); mo.position = Vector3(ps.x, altura_malha(ps.x, ps.y), ps.y)
				mo.montar(self, tp, nv, semente)
				mo.rotation.y = giro; mo.reset_physics_interpolation()
				g.membros.append(mo))
		matilhas.append(g)
		var sem := rng.randi(); var grande := e_chefe
		_criar_depois(q, func(): _acampamento_lodoso(q, sem, grande))

# acampamento: 1 a 2 cabanas (grande e/ou pequena), varal de peixes, rede, monte de tralhas e fogueira, em volta do
# centro; tudo virado para o meio e com o chão seco embaixo
const PECAS_LODOSO := {          # arquivo, altura real (m) ou largura (m) se "larg"
	"casa_g": ["res://assets/modelos/casa_lodoso_g.glb", 3.6, false], "casa_p": ["res://assets/modelos/casa_lodoso_p.glb", 2.5, false],
	"varal": ["res://assets/modelos/varal_lodoso.glb", 3.0, true], "rede": ["res://assets/modelos/rede_lodoso.glb", 2.6, true],
	"lixo": ["res://assets/modelos/lixo_lodoso.glb", 1.9, true]}
func _acampamento_lodoso(c: Vector2, semente: int, grande: bool) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = semente
	var lista: Array = ["casa_g", "casa_p"] if grande or rng.randf() < 0.45 else [["casa_g", "casa_p"][rng.randi() % 2]]
	if grande: lista.append("casa_p")
	lista.append_array(["varal", "rede", "lixo"] if grande else [["varal", "rede", "lixo"][rng.randi() % 3]] + ([["varal", "rede", "lixo"][rng.randi() % 3]] if rng.randf() < 0.6 else []))
	var a0 := rng.randf() * TAU
	for k in lista.size():
		var nome: String = lista[k]
		var raio := (6.5 if nome.begins_with("casa") else 4.5) + rng.randf_range(0.0, 1.5)
		var ang := a0 + TAU * k / lista.size() + rng.randf_range(-0.25, 0.25)
		var p := c + Vector2(cos(ang), sin(ang)) * raio
		if na_agua(p.x, p.y) or na_agua(p.x, p.y + 1.5) or na_agua(p.x + 1.5, p.y): p = c - Vector2(cos(ang), sin(ang)) * raio   # do outro lado
		if na_agua(p.x, p.y) or na_agua(p.x, p.y + 1.5) or na_agua(p.x + 1.5, p.y): continue
		_peca_lodoso(nome, p, atan2(c.x - p.x, c.y - p.y) + (PI if nome.begins_with("casa") else rng.randf_range(-0.4, 0.4)))
	var y := altura_malha(c.x, c.y)
	_fogo(Vector3(c.x, y + 0.05, c.y), 0.45, 0.6, 2)
	luzes.append(Vector3(c.x, y + 0.4, c.y))

static var _aabb_peca := {}
func _peca_lodoso(nome: String, p: Vector2, giro: float) -> void:
	var d: Array = PECAS_LODOSO[nome]
	var no: Node3D = modelo_ps1(d[0])
	if not _aabb_peca.has(nome):
		var bb := AABB()
		for mi in no.find_children("*", "MeshInstance3D", true, false): bb = bb.merge(mi.get_aabb()) if bb.size != Vector3.ZERO else mi.get_aabb()
		_aabb_peca[nome] = bb
	var b: AABB = _aabb_peca[nome]
	var esc: float = float(d[1]) / (maxf(b.size.x, b.size.z) if d[2] else b.size.y)
	for mi in no.find_children("*", "MeshInstance3D", true, false): mi.visibility_range_end = 130.0
	raiz.add_child(no)
	no.scale = Vector3.ONE * esc; no.rotation.y = giro
	var y := minf(minf(altura_malha(p.x, p.y), altura_malha(p.x + 1.0, p.y)), altura_malha(p.x, p.y + 1.0))
	no.position = Vector3(p.x, y - b.position.y * esc - 0.08, p.y)

# ---------- Gruta dos Lodosos (DG aberta) ----------
# O chão é o terreno cavado (regiao.gd: gruta_d). Aqui: paredes de pedra pela borda (marching squares no campo
# de distância), teto irregular, paredão sobre a boca, tochas, acampamentos e os Lodosos; o Grão-Lodoso fica
# na câmara do fundo. As malhas são calculadas em outro núcleo na carga e entram quando ficam prontas.
var _gruta_tarefa := -1
var _gruta_caixa := [null]
var gruta_dentro := 0.0                # 0 fora, 1 dentro do trecho com teto (suave)
func _gruta_iniciar() -> void:
	var r := reg
	_gruta_tarefa = WorkerThreadPool.add_task(func(): _gruta_caixa[0] = _gruta_malhas(r), false, "gruta")
	_gruta_monstros()

func _gruta_malhas(r: Regiao) -> Dictionary:
	var bb: Rect2 = Regiao.GRUTA_BB.grow(8.0); var s := 1.0
	var nx := int(bb.size.x / s) + 1; var nz := int(bb.size.y / s) + 1
	var v := PackedFloat32Array(); v.resize(nx * nz)
	for j in nz:
		for i in nx: v[j * nx + i] = r.gruta_d(bb.position.x + i * s, bb.position.y + j * s)
	var paredes := SurfaceTool.new(); paredes.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	var ponto := func(i0: int, j0: int, i1: int, j1: int) -> Vector2:
		var a := v[j0 * nx + i0]; var b := v[j1 * nx + i1]; var t := clampf(a / (a - b), 0.0, 1.0)
		return bb.position + Vector2(lerpf(i0, i1, t), lerpf(j0, j1, t)) * s
	for j in nz - 1:
		for i in nx - 1:
			var c := 0
			if v[j * nx + i] < 0.0: c |= 1
			if v[j * nx + i + 1] < 0.0: c |= 2
			if v[(j + 1) * nx + i + 1] < 0.0: c |= 4
			if v[(j + 1) * nx + i] < 0.0: c |= 8
			if c == 0 or c == 15: continue
			var e := [ponto.call(i, j, i + 1, j), ponto.call(i + 1, j, i + 1, j + 1), ponto.call(i, j + 1, i + 1, j + 1), ponto.call(i, j, i, j + 1)]  # cima, dir, baixo, esq
			var segs := []
			match c:
				1, 14: segs = [[e[3], e[0]]]
				2, 13: segs = [[e[0], e[1]]]
				3, 12: segs = [[e[3], e[1]]]
				4, 11: segs = [[e[1], e[2]]]
				5: segs = [[e[3], e[0]], [e[1], e[2]]]
				6, 9: segs = [[e[0], e[2]]]
				7, 8: segs = [[e[3], e[2]]]
				10: segs = [[e[0], e[1]], [e[2], e[3]]]
			for sg in segs:
				if (sg[0] as Vector2).y > Regiao.GRUTA_COBERTA_Z + 0.5 and (sg[1] as Vector2).y > Regiao.GRUTA_COBERTA_Z + 0.5: continue   # entrada aberta: sem muro
				_gruta_parede(r, paredes, faces, sg[0], sg[1])
	paredes.generate_normals()
	# teto: quadrados de 2 m onde tem gruta coberta (passando um pouco da parede)
	var teto := SurfaceTool.new(); teto.begin(Mesh.PRIMITIVE_TRIANGLES)
	var t := 2.0; var x := bb.position.x
	while x < bb.end.x:
		var z := bb.position.y
		while z < bb.end.y:
			var zc := z + t * 0.5
			if zc < Regiao.GRUTA_COBERTA_Z and r.gruta_d(x + t * 0.5, zc) < 4.5:
				var q := [Vector2(x, z), Vector2(x + t, z), Vector2(x + t, z + t), Vector2(x, z + t)]
				var pts := []
				for k in 4: pts.append(Vector3(q[k].x, r.gruta_teto(q[k].x, q[k].y), q[k].y))
				var cor := Color(0.42, 0.4, 0.38) * (0.85 + r.ruido.get_noise_2d(x * 3.0, z * 3.0) * 0.2)
				for tri in [[0, 2, 1], [0, 3, 2]]:
					for k in tri:
						teto.set_color(cor * (0.8 + r.ruido.get_noise_2d(pts[k].x * 9.0, pts[k].z * 9.0) * 0.3)); teto.set_normal(Vector3.DOWN); teto.set_uv(Vector2(pts[k].x, pts[k].z) * 0.25); teto.add_vertex(pts[k])
			z += t
		x += t
	# CAPA DA MONTANHA: por cima da parte coberta, a encosta volta na altura original (sem a gruta), com as cores do
	# terreno — de fora a gruta fica escondida dentro da montanha; só a boca aparece. Tem colisão (dá para andar por
	# cima). Fica sempre acima do teto.
	var capa := SurfaceTool.new(); capa.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cf := PackedVector3Array()
	var cs := 2.0
	var alt_capa := func(px: float, pz: float) -> float:
		var h0 := r.altura(px, pz, false)
		var dg := r.gruta_d(px, pz)
		if dg < 9.5: h0 = maxf(h0, r.gruta_teto(px, pz) + 1.2 * (1.0 - smoothstep(4.0, 9.5, dg)))
		return h0
	x = bb.position.x
	while x < bb.end.x:
		var z := bb.position.y
		while z < minf(bb.end.y, Regiao.GRUTA_COBERTA_Z):
			var usa := false
			for o in [Vector2(0, 0), Vector2(cs, 0), Vector2(0, cs), Vector2(cs, cs)]:
				if r.gruta_d(x + o.x, z + o.y) < 9.5: usa = true
			if usa:
				var q := [Vector2(x, z), Vector2(x + cs, z), Vector2(x + cs, minf(z + cs, Regiao.GRUTA_COBERTA_Z)), Vector2(x, minf(z + cs, Regiao.GRUTA_COBERTA_Z))]
				var pts := []
				for k in 4: pts.append(Vector3(q[k].x, alt_capa.call(q[k].x, q[k].y), q[k].y))
				var nrm: Vector3 = (pts[3] - pts[0]).cross(pts[1] - pts[0]).normalized()
				if nrm.y < 0.0: nrm = -nrm
				for tri in [[0, 3, 2], [0, 2, 1]]:
					for k in tri:
						var pp: Vector3 = pts[k]
						capa.set_color(r.cor(pp.x, pp.z, pp.y, nrm.y, false)); capa.set_normal(nrm); capa.set_uv(Vector2(pp.x, pp.z) * 0.25)
						capa.add_vertex(pp); cf.append(pp)
			z += cs
		x += cs
	# ENCOSTA NA BOCA: na linha onde a capa termina, a parede de pedra desce da montanha até o teto da entrada (a
	# abertura) e, dos lados da boca, até o chão
	var bz := Regiao.GRUTA_COBERTA_Z
	var meia_boca := 0.0
	for k in 60:
		var xk := Regiao.GRUTA_ENTRADA.x - 15.0 + k * 0.5
		if r.gruta_d(xk, bz) < 0.0: meia_boca = maxf(meia_boca, absf(xk - Regiao.GRUTA_ENTRADA.x))
	x = bb.position.x
	while x < bb.end.x:
		var x1 := x + 1.0
		if r.gruta_d(x, bz) < 9.5 or r.gruta_d(x1, bz) < 9.5:
			var base := func(px: float) -> float:          # a abertura é um arco redondo (alto no meio)
				if r.gruta_d(px, bz) < 0.3: return r.gruta_piso(px, bz) + maxf(r.arco_boca(px, meia_boca), 0.0) - 0.3
				return r.altura(px, bz) - 0.5
			var quad := [Vector3(x, base.call(x), bz), Vector3(x1, base.call(x1), bz), Vector3(x1, alt_capa.call(x1, bz), bz), Vector3(x, alt_capa.call(x, bz), bz)]
			for tri in [[0, 1, 2], [0, 2, 3]]:
				for k in tri:
					var pp: Vector3 = quad[k]
					var mch := 0.75 + r.ruido.get_noise_2d(pp.x * 7.0, pp.y * 7.0) * 0.3
					capa.set_color(Color(0.46, 0.5, 0.6) * mch); capa.set_normal(Vector3(0, 0.2, 1).normalized())
					capa.set_uv(Vector2(pp.x, pp.y) * 0.25); capa.add_vertex(pp); cf.append(pp)
		x = x1
	return {"paredes": paredes.commit_to_arrays(), "teto": teto.commit_to_arrays(), "faces": faces, "capa": capa.commit_to_arrays(), "capa_faces": cf}

# um pedaço de parede de pedra de a até b (3 faixas na altura, a do meio estufada para dentro)
func _gruta_parede(r: Regiao, st: SurfaceTool, faces: PackedVector3Array, a: Vector2, b: Vector2) -> void:
	var m := (a + b) * 0.5; var n := (b - a).normalized().orthogonal()
	if r.gruta_d(m.x + n.x * 0.4, m.y + n.y * 0.4) > r.gruta_d(m.x - n.x * 0.4, m.y - n.y * 0.4): n = -n   # n aponta para dentro
	var linha := []
	for p: Vector2 in [a, b]:
		var piso := r.gruta_piso(p.x, p.y)
		var coberta := p.y < Regiao.GRUTA_COBERTA_Z + 1.0
		var topo := r.gruta_teto(p.x, p.y) + 0.8 if coberta else piso + 4.5 + r.ruido.get_noise_2d(p.x * 7.0, p.y * 7.0) * 1.5
		var estufa := 0.35 + 0.45 * (0.5 + 0.5 * r.ruido.get_noise_2d(p.x * 9.0, p.y * 9.0))
		var meio := lerpf(piso, topo, 0.45 + 0.15 * r.ruido.get_noise_2d(p.x * 11.0, p.y * 11.0))
		linha.append([Vector3(p.x, piso - 1.0, p.y), Vector3(p.x + n.x * estufa, meio, p.y + n.y * estufa), Vector3(p.x + n.x * 0.25, topo, p.y + n.y * 0.25)])
	var cor := Color(0.52, 0.49, 0.45) * (0.85 + r.ruido.get_noise_2d(m.x * 2.0, m.y * 2.0) * 0.25)
	for k in 2:
		var p00: Vector3 = linha[0][k]; var p01: Vector3 = linha[0][k + 1]; var p10: Vector3 = linha[1][k]; var p11: Vector3 = linha[1][k + 1]
		for tri in [[p00, p10, p11], [p00, p11, p01]]:
			for q: Vector3 in tri:
				var mancha := 0.78 + r.ruido.get_noise_2d(q.x * 9.0 + q.y * 5.0, q.z * 9.0 - q.y * 4.0) * 0.32   # rocha manchada
				var umido := (1.0 - smoothstep(r.gruta_piso(q.x, q.z), r.gruta_piso(q.x, q.z) + 2.2, q.y)) * (0.5 + 0.5 * r.ruido.get_noise_2d(q.x * 3.0, q.z * 3.0))
				st.set_color((cor * mancha).lerp(Color(0.3, 0.4, 0.26) * mancha, clampf(umido, 0.0, 0.85))); st.set_uv(Vector2(q.x + q.z, q.y) * 0.25); st.add_vertex(q)
				faces.append(q)

func _gruta_pronta() -> void:
	if _gruta_tarefa < 0 or not WorkerThreadPool.is_task_completed(_gruta_tarefa): return
	WorkerThreadPool.wait_for_task_completion(_gruta_tarefa); _gruta_tarefa = -1
	var d: Dictionary = _gruta_caixa[0]
	var pedra := mat("", 1.0, Color(0.95, 0.92, 0.88))            # rocha lisa com manchas pelas cores dos vértices
	for nome in ["paredes", "teto"]:
		var am := ArrayMesh.new(); am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, d[nome])
		var mi := MeshInstance3D.new(); mi.mesh = am; mi.material_override = pedra; raiz.add_child(mi)
	var corpo := StaticBody3D.new(); var cs := CollisionShape3D.new(); var forma := ConcavePolygonShape3D.new()
	forma.set_faces(d.faces); forma.backface_collision = true; cs.shape = forma; corpo.add_child(cs); raiz.add_child(corpo)
	var am_c := ArrayMesh.new(); am_c.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, d.capa)     # a montanha por cima
	var mi_c := MeshInstance3D.new(); mi_c.mesh = am_c; mi_c.material_override = mat("terreno"); raiz.add_child(mi_c)
	var corpo_c := StaticBody3D.new(); var cs_c := CollisionShape3D.new(); var f_c := ConcavePolygonShape3D.new()
	f_c.set_faces(d.capa_faces); cs_c.shape = f_c; corpo_c.add_child(cs_c); raiz.add_child(corpo_c)
	_gruta_enfeites()
	var amb := Gruta.new(); raiz.add_child(amb); amb.montar(self)
	if args.has("carga"): print("GRUTA pronta: ", (d.faces as PackedVector3Array).size() / 3, " triângulos de parede")

# tochas pelos túneis, acampamentos nas salas, tralhas e ossos de peixe pelo caminho
func _gruta_enfeites() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 4242
	for t in Regiao.GRUTA_TUNEIS:
		var a: Vector2 = t[0]; var b: Vector2 = t[1]; var comp := a.distance_to(b)
		var n := (b - a).normalized().orthogonal(); var k := 6.0; var lado := 1.0
		while k < comp - 2.0:
			var p: Vector2 = a.lerp(b, k / comp)
			var q := p + n * lado * (float(t[2]) * 0.5 - 0.9)
			if reg.gruta_d(q.x, q.y) < -0.3 and q.y < Regiao.GRUTA_COBERTA_Z - 6.0: _tocha_gruta(q)     # só lá dentro
			k += 13.0; lado = -lado
	var salas: Array = Regiao.GRUTA_SALAS
	# sala 1: acampamento
	var c1: Vector2 = salas[0][0]
	_peca_lodoso("casa_p", c1 + Vector2(-6.5, -3.0), 0.8); _peca_lodoso("varal", c1 + Vector2(5.5, -5.0), -0.6)
	_peca_lodoso("lixo", c1 + Vector2(4.5, 5.5), 2.4); _fogueira_gruta(c1)
	# beco do xamã
	var c2: Vector2 = salas[1][0]
	_peca_lodoso("rede", c2 + Vector2(3.5, -2.5), -1.2); _peca_lodoso("lixo", c2 + Vector2(-1.5, 4.0), 0.4); _fogueira_gruta(c2 + Vector2(-1.0, -0.5))
	# sala 2
	var c3: Vector2 = salas[2][0]
	_peca_lodoso("casa_g", c3 + Vector2(-5.0, -4.5), 0.6); _peca_lodoso("varal", c3 + Vector2(5.0, 3.5), 2.2)
	_peca_lodoso("rede", c3 + Vector2(5.5, -4.5), -2.0); _fogueira_gruta(c3 + Vector2(0.5, 1.5))
	# câmara do Grão-Lodoso: duas cabanas grandes, tralhas, redes e três fogueiras
	var c4: Vector2 = salas[3][0]
	_peca_lodoso("casa_g", c4 + Vector2(-9.0, -8.0), 0.7); _peca_lodoso("casa_g", c4 + Vector2(9.5, -7.0), -0.7)
	_peca_lodoso("lixo", c4 + Vector2(-11.0, 4.0), 1.2); _peca_lodoso("lixo", c4 + Vector2(10.5, 5.0), -1.6)
	_peca_lodoso("rede", c4 + Vector2(0.0, -12.5), 0.0); _peca_lodoso("varal", c4 + Vector2(-4.0, 11.0), PI)
	for f in [Vector2(-5.0, 2.0), Vector2(5.0, 2.0), Vector2(0.0, -5.0)]: _fogueira_gruta(c4 + f)
	# boca da gruta: duas tochas e um monte de tralhas
	# (a boca não tem tocha nem lixo: só pedras e cascalho — gruta.gd)

func _tocha_gruta(p: Vector2) -> void:
	var y := reg.gruta_piso(p.x, p.y)
	var st := _st(); _caixa(st, Vector3(p.x, y + 0.7, p.y), Vector3(0.14, 1.4, 0.14)); _peca(st, mat("madeira"), Vector3.ZERO)
	_fogo(Vector3(p.x, y + 1.4, p.y), 0.22, 0.4, 1)
	luzes.append(Vector3(p.x, y + 1.6, p.y))

func _fogueira_gruta(p: Vector2) -> void:
	var y := reg.gruta_piso(p.x, p.y)
	_fogo(Vector3(p.x, y + 0.05, p.y), 0.5, 0.7, 2)
	luzes.append(Vector3(p.x, y + 0.5, p.y))

# Lodosos da gruta: grupos pelos túneis e salas (nível 4–6) e o Grão-Lodoso sozinho na câmara do fundo
func _gruta_monstros() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 5150
	var salas: Array = Regiao.GRUTA_SALAS
	var grupos := [
		[salas[0][0], ["lodoso_g", "lodoso_j", "lodoso_j"]],
		[salas[1][0], ["lodoso_x", "lodoso_j"]],
		[Vector2(1491, -994), ["lodoso_g", "lodoso_j"]],
		[salas[2][0], ["lodoso_g", "lodoso_x", "lodoso_j"]],
		[Vector2(1516, -1040), ["lodoso_j", "lodoso_j"]],
		[salas[3][0], ["lodoso_c"]]]
	for gr in grupos:
		var q: Vector2 = gr[0]; var tipos: Array = gr[1]
		var g := {"casa": q, "membros": [], "alerta": false, "tipo": "lodoso", "gruta": true}
		for j in tipos.size():
			var p := q + Vector2(cos(TAU * j / 3.0), sin(TAU * j / 3.0)) * (0.0 if j == 0 else 2.5)
			var tp: String = tipos[j]
			var nv := 10 if tp == "lodoso_c" else (rng.randi_range(5, 6) if tp != "lodoso_j" else rng.randi_range(4, 5))
			var semente := rng.randi(); var giro := rng.randf() * TAU
			_criar_depois(p, func():
				var mo := Monstro.new(); mo.grupo = g
				if tp == "lodoso_c": mo.nome = NOME_CHEFE_LODOSO; chefe_lodoso = mo
				raiz.add_child(mo); mo.position = Vector3(p.x, altura_malha(p.x, p.y), p.y)
				mo.montar(self, tp, nv, semente)
				mo.rotation.y = giro; mo.reset_physics_interpolation()
				g.membros.append(mo))
		matilhas.append(g)

# dentro da gruta: escurece (as tochas e fogueiras acendem como de noite) e não chove
func _gruta_luz(delta: float) -> void:
	if jogador == null: return
	var p := jogador.global_position
	var dentro := reg.gruta_coberta(p.x, p.z) and p.y < Regiao.GRUTA_Y + Regiao.GRUTA_TETO
	gruta_dentro = move_toward(gruta_dentro, 1.0 if dentro else 0.0, delta / 1.2)

# os dois monstros únicos do Vale de Aldren
const NOME_GOLEM := "Barrogar, o Colosso do Vale"          # o golem de barro (nível 8)
const NOME_CHEFE_LODOSO := "Glorgo, o Rei da Lama"         # o Grão-Lodoso, no fundo da Gruta dos Lodosos (nível 10)
var chefe_lodoso: Monstro
# Barrogar, o golem de terra (chefe): dá a volta no mapa inteiro, longe da vila, andando sem parar
var golem: Monstro
func _golem() -> void:
	var rota := []
	for i in 36:
		var a := TAU * i / 36.0
		var melhor := Vector2.ZERO
		for r0 in [330.0, 310.0, 350.0, 290.0, 370.0]:
			var r := Regiao.Ws(r0)
			var q: Vector2 = Vector2(cos(a), sin(a)) * float(r)
			if reg.agua(q.x, q.y) == 0.0 and reg.altura(q.x, q.y) > 0.5 and reg.altura(q.x, q.y) - reg.base(q.y) < 9.0:
				melhor = q; break
		if melhor != Vector2.ZERO: rota.append(melhor)
	if rota.size() < 4: return
	golem = Monstro.new(); golem.rota = rota; golem.nome = NOME_GOLEM
	golem.grupo = {"casa": rota[0], "membros": [golem], "alerta": false, "tipo": "golem"}
	var p: Vector2 = rota[0]
	raiz.add_child(golem); golem.position = Vector3(p.x, altura_malha(p.x, p.y), p.y)
	golem.montar(self, "golem", 8, 31)
	matilhas.append(golem.grupo)

# pancada no chão do golem: poeira, tremor e som grave
func pancada_no_chao(pos: Vector3, raio: float) -> void:
	var p := _particulas(pos + Vector3(0, 0.3, 0), [Color(0.6, 0.48, 0.32), Color(0.42, 0.33, 0.22)], 40, 6.0, 0.9)
	p.direction = Vector3(0, 0.4, 0); p.spread = 90.0; p.gravity = Vector3(0, -6.0, 0)
	var q: QuadMesh = p.mesh; q.size = Vector2(0.35, 0.35)
	p.restart(); get_tree().create_timer(2.0).timeout.connect(p.queue_free)
	var d := jogador.global_position.distance_to(pos)
	if d < raio * 3.0: jogador._tranco += Vector3(-4.0 * (1.0 - d / (raio * 3.0)), randf_range(-3, 3), 0.0); jogador.impacto(0.1)

# Cusparada Ácida do Glorgo: com o escudo erguido e de frente bloqueia tudo; senão leva o impacto e fica com ácido
# queimando (dano a cada 1,5 s por 6 s)
func gosma_acida(dano: float, acido: float, de: Vector3, nivel_atacante := 1) -> void:
	if heroina_desmaiada: return
	if args.has("cuspe"): print("CUSPE acertou: bloqueando=", jogador.bloqueando, " vida ", hud.vida)
	var fr := -jogador.global_transform.basis.z; var d := de - jogador.global_position; d.y = 0.0
	if bolsa.equip.get("escudo", "") != "" and jogador.bloqueando and fr.dot(d.normalized()) > 0.3:
		jogador.impacto(0.05); hud.numero_heroi("Bloqueado", Color(0.6, 1.0, 0.5)); return
	ferir_heroina(dano, de, nivel_atacante)
	envenenar(acido, 6.0)
	hud.avisar("Ácido! Erga o escudo contra a Cusparada Ácida.", Color(0.5, 1.0, 0.3))

# veneno: tira vida aos poucos (número verde)
var _veneno_t := 0.0
var _veneno_dano := 0.0
var _veneno_tick := 0.0
func envenenar(dano: float, dur: float) -> void:
	_veneno_t = dur; _veneno_dano = dano; _veneno_tick = 1.0
	hud.numero_heroi("Envenenada!", Color(0.45, 1.0, 0.35))

func _tick_veneno(delta: float) -> void:
	if _veneno_t <= 0.0 or heroina_desmaiada: return
	_veneno_t -= delta; _veneno_tick -= delta
	if _veneno_tick <= 0.0:
		_veneno_tick = 1.5
		var d := roundf(_veneno_dano)
		hud.vida = maxf(0.0, hud.vida - d); hud.numero_heroi("-%d" % d, Color(0.45, 1.0, 0.35))
		if hud.vida <= 0.0: _desmaiar()

# ---------- os monstros voltam: os normais 5 min depois de morrer, o chefe 1 hora depois ----------
# (no mesmo lugar, com o mesmo nível; se a Rachel estiver por perto, espera ela se afastar para não "brotar" na cara)
const VOLTA_NORMAL := 300.0
const VOLTA_CHEFE := 3600.0
var _voltas := []                     # [segundos que faltam, Callable]
func _agendar_volta(mo: Node) -> void:
	var g: Dictionary = mo.grupo
	var casa: Vector2 = g.casa
	var f: Callable
	if mo is Lobo:
		var tp: String = mo.tipo; var ld: bool = mo.lider; var nv: int = mo.nivel; var vg: float = mo.vaga
		f = func() -> Node3D:
			var l := Lobo.new(); l.grupo = g; l.nivel = nv; l.vaga = vg
			var a := randf() * TAU; var p := casa + Vector2(cos(a), sin(a)) * (0.0 if ld else randf_range(2.0, 5.0))
			p = ponto_seco(p, casa)
			raiz.add_child(l); l.position = Vector3(p.x, altura_malha(p.x, p.y), p.y)
			l.montar(self, tp, ld, randi()); return l
	elif mo is Aranha:
		var nv: int = mo.nivel
		f = func() -> Node3D:
			var a := Aranha.new(); a.grupo = g
			var pa := ponto_seco(casa, casa)
			raiz.add_child(a); a.position = Vector3(pa.x, altura_malha(pa.x, pa.y), pa.y)
			a.montar(self, nv, randi()); return a
	elif mo is Monstro and mo.tipo == "golem":
		var rota: Array = mo.rota; var nm: String = mo.nome; var nv: int = mo.nivel
		f = func() -> Node3D:
			var gm := Monstro.new(); gm.rota = rota; gm.nome = nm; gm.grupo = g; g.alerta = false
			# nasce no ponto da volta mais longe da Rachel
			var pj := Vector2(jogador.global_position.x, jogador.global_position.z)
			var melhor := 0
			for i in rota.size(): if rota[i].distance_to(pj) > rota[melhor].distance_to(pj): melhor = i
			gm._rota_i = (melhor + 1) % rota.size()
			var p: Vector2 = rota[melhor]
			raiz.add_child(gm); gm.position = Vector3(p.x, altura_malha(p.x, p.y), p.y)
			gm.montar(self, "golem", nv, randi()); golem = gm; return gm
	elif mo is Monstro:
		var tp: String = mo.tipo; var nv: int = mo.nivel; var nm: String = mo.nome
		f = func() -> Node3D:
			var lm := Monstro.new(); lm.grupo = g; lm.nome = nm
			if tp == "lodoso_c": chefe_lodoso = lm
			var a := randf() * TAU; var p := casa + Vector2(cos(a), sin(a)) * randf_range(0.0, 2.5)
			p = ponto_seco(p, casa)
			raiz.add_child(lm); lm.position = Vector3(p.x, altura_malha(p.x, p.y), p.y)
			lm.montar(self, tp, nv, randi()); return lm
	else: return
	var espera := VOLTA_CHEFE if (mo is Monstro and mo.tipo == "golem") else VOLTA_NORMAL
	if mo is Monstro and mo.tipo == "lodoso_c": espera = 1800.0         # Grão-Lodoso: volta em 30 min
	if args.has("volta_rapida"): espera = float(args.volta_rapida)
	_voltas.append([espera, f, g])

func _tick_voltas(delta: float) -> void:
	for i in range(_voltas.size() - 1, -1, -1):
		var v: Array = _voltas[i]
		v[0] -= delta
		if v[0] > 0.0: continue
		var g: Dictionary = v[2]
		var casa: Vector2 = g.casa
		var longe := 0.0 if (g.get("tipo", "") == "golem" or args.has("volta_rapida")) else 45.0
		if Vector2(jogador.global_position.x, jogador.global_position.z).distance_to(casa) < longe:
			v[0] = 10.0; continue                         # a Rachel está ali: tenta de novo daqui a pouco
		var novo: Node3D = v[1].call()
		g.membros = g.membros.filter(func(o): return is_instance_valid(o) and o.estado != "morto")
		g.membros.append(novo)
		_voltas.remove_at(i)
		if args.has("volta_rapida"): print("VOLTOU: ", novo.get_script().resource_path.get_file(), " em ", casa)

# morte de aranha, Lodoso ou golem: XP (o chefe vale muito mais), dinheiro e drops
func monstro_morreu(mo: Node) -> void:
	_agendar_volta(mo)
	var ganho := Hud.xp_por_matar(mo.nivel, hud.nivel)
	var mult := 1.0
	if mo is Monstro: mult = mo.cfg.xp
	elif mo is Aranha: mult = 1.3
	if ganho > 0.0: hud.ganhar_xp(roundf(ganho * mult))
	# [id, chance, mín, máx] — quanto mais vale o item, menor a chance (o saque fica no corpo; ver saque.gd)
	var drops := []
	if mo is Aranha: drops = [["presa_aranha", 0.4, 1, 1], ["veneno_aranha", 0.3, 1, 1]]
	elif mo is Monstro and mo.tipo == "golem":
		drops = [["nucleo_golem", 1.0, 1, 1], ["espada_ferro", 0.35, 1, 1], ["bolsa_16", 0.35, 1, 1], ["egide_guardia", 0.2, 1, 1], ["cutelo_rochedo", 0.15, 1, 1]]
		var moedas := randi_range(150, 400); bolsa.cobre += moedas; bolsa.mudou.emit()
		hud.avisar("+%s" % Bolsa.texto_dinheiro(moedas), Color(0.95, 0.75, 0.4))
		hud.avisar("%s foi derrotado!" % NOME_GOLEM, Color(1.0, 0.82, 0.2))
	elif mo is Monstro:                   # Lodosos: escama, barbatana e olho; o xamã (lodoso_x) larga a Pérola da Lama
		drops = [["escama_lodoso", 0.5, 1, 2 if mo.tipo == "lodoso_g" else 1], ["barbatana_lodoso", 0.35, 1, 1],
			["olho_lodoso", 0.2, 1, 1]]
		if mo.tipo == "lodoso_x": drops.append(["perola_lama", 0.12, 1, 1])
		# Grão-Lodoso: os itens dos Lodosos (40%), os dois só dele (15%) e a espada Presa da Maré (10%; depois vira
		# recompensa da missão do soldado de Altamar)
		if mo.tipo == "lodoso_c": drops = [["escama_lodoso", 0.4, 2, 3], ["barbatana_lodoso", 0.4, 1, 2], ["olho_lodoso", 0.4, 1, 2],
			["perola_lama", 0.4, 1, 1], ["coroa_grao_lodoso", 0.15, 1, 1], ["tridente_partido", 0.15, 1, 1], ["presa_da_mare", 0.1, 1, 1]]
	saque.registrar(mo, Saque.sortear(drops))

func lobo_morreu(l: Lobo) -> void:
	_agendar_volta(l)
	var ganho := Hud.xp_por_matar(l.nivel, hud.nivel)
	if ganho > 0.0: hud.ganhar_xp(ganho)
	# dentes e garras (45%, vale menos) e pelo (35%); o líder deixa mais
	saque.registrar(l, Saque.sortear([["dentes_garras", 0.45, 1, 2 if l.lider else 1], ["pelo_lobo", 0.35, 1, 2 if l.lider else 1]]))

# progresso salvo no aparelho (nível, XP, dinheiro e itens); nos testes com print não carrega nem salva
var bolsa := Bolsa.new()
var _salvar_em := -1.0
var nuvem: Nuvem
func _carregar_progresso() -> void:
	if args.has("shot") and not args.has("progresso"): return
	var d := bolsa.carregar()
	if not d.is_empty(): hud.definir_nivel(int(d.get("nivel", 1)), float(d.get("xp", 0.0)))
	jogador.trocar_equip("arma", bolsa.equip.arma); jogador.trocar_equip("escudo", bolsa.equip.escudo)
	var pedir := func(): _salvar_em = 1.0
	hud.mudou.connect(pedir); bolsa.mudou.connect(pedir)
	# save na nuvem (login anônimo no Supabase): entra, e se o da nuvem for mais novo, usa ele
	nuvem = Nuvem.new(); add_child(nuvem); nuvem.log_ativo = args.has("nuvem")
	nuvem.save_baixado.connect(func(dn: Dictionary):
		bolsa.aplicar(dn); bolsa.mudou.emit()
		hud.definir_nivel(int(dn.get("nivel", 1)), float(dn.get("xp", 0.0)))
		jogador.trocar_equip("arma", bolsa.equip.arma); jogador.trocar_equip("escudo", bolsa.equip.escudo)
		var f := FileAccess.open(Bolsa.ARQUIVO, FileAccess.WRITE)
		if f: f.store_string(JSON.stringify(dn))
		hud.avisar("Progresso carregado da nuvem.", Color(0.6, 0.85, 1.0)))
	nuvem.iniciar(float(d.get("salvo_em", 0.0)))

# saindo ou indo para o fundo (celular): salva e manda para a nuvem na hora
func _notification(what: int) -> void:
	if (what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED) and nuvem and hud:
		nuvem.enviar(bolsa.salvar(hud.nivel, hud.xp), true)

# crianças brincando de pega-pega num pedaço livre da vila (o lugar com mais espaço sem casas perto da praça)
var brincadeira_pos := Vector2.ZERO
func _criancas() -> void:
	var melhor := Vector2(8, 8); var nota := -1
	for i in 60:
		var a := TAU * i / 60.0 * 7.0; var r := 7.0 + float(i % 6) * 3.0
		var c := Vector2(cos(a), sin(a)) * r
		var livres := 0
		for k in 16:
			var b := TAU * k / 16.0
			for rr in [2.5, 5.0, 7.5]:
				var q: Vector2 = c + Vector2(cos(b), sin(b)) * float(rr)
				if not perto_de_casa(q.x, q.y, 1.0) and reg.agua(q.x, q.y) == 0.0: livres += 1
		if livres > nota: nota = livres; melhor = c
	brincadeira_pos = melhor
	var kids := []
	for t in ["menino", "menina"]:
		var mo := Morador.new(); mo.tipo = t; raiz.add_child(mo)
		var p := melhor + Vector2(2.0 if t == "menino" else -2.0, 0)
		mo.position = Vector3(p.x, altura(p.x, p.y), p.y)
		mo.montar(self, 777 + kids.size(), melhor, 9.0); kids.append(mo)
	kids[0].par = kids[1]; kids[1].par = kids[0]; kids[0].pegador = true; kids[0]._contar = 1.0

# trabalhadores: ferreiro na bigorna, lenhador cortando um tronco caído na mata perto da serraria,
# um fazendeiro dentro de cada campo cercado
func _profissionais() -> void:
	if not igreja_vila.is_empty():               # Irmã Celina na frente da igreja da vila
		var qv: Vector2 = igreja_vila[0]; var dv: Vector2 = igreja_vila[1]
		var pf := qv + dv * (float(igreja_vila[2]) * 0.5 + 2.4)
		_freira("Irmã Celina", pf, dv, altura(pf.x, pf.y), 4141)
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
		# volume cheio até ~6 m da bigorna; depois cai aos poucos (ouve-se baixinho chegando na ferraria)
		som.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		som.unit_size = 6.0; som.max_distance = 75.0; som.volume_db = -10.5; som.bus = "Efeitos"   # metade do volume de antes (-4,5 dB → -10,5 dB)
		som.attenuation_filter_cutoff_hz = 6000.0; som.attenuation_filter_db = -8.0   # de longe fica um pouco abafado
		raiz.add_child(som)
		var batidas := []
		for k in 4: batidas.append(load("res://assets/som/martelo_%d.ogg" % (k + 1)))
		fe.ao_bater = func():
			faisca.restart()
			som.stream = batidas[randi() % batidas.size()]; som.pitch_scale = randf_range(0.94, 1.06); som.play()
		fe.montar(self, 5000 + n, fe.posto, 1.0); n += 1
	# lenhador: tronco caído na beira da mata, perto da serraria
	var serra := Regiao.W(Vector2(286, -170)); var lp := serra + Vector2(0, 22)
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
# fogo animado: n labaredas (quadrados com o shader de fogo) espalhadas na base + fagulhas subindo
func _fogo(pos: Vector3, larg: float, alt: float, n: int, brasas := true, raio := -1.0) -> Node3D:
	var no := Node3D.new(); no.position = pos; raiz.add_child(no)
	if raio < 0.0: raio = larg * 0.25
	var q := QuadMesh.new(); q.size = Vector2(1, 1); q.center_offset = Vector3(0, 0.5, 0)
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = q; mm.instance_count = n
	for i in n:
		var a := TAU * i / n + randf() * 0.5; var r := 0.0 if i == 0 else raio * randf_range(0.4, 1.0)
		var s := 1.0 if i == 0 else randf_range(0.55, 0.85)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(larg * s, alt * s, 1)), Vector3(cos(a) * r, 0, sin(a) * r)))
	var sm := ShaderMaterial.new(); sm.shader = load("res://shaders/fogo.gdshader"); sm.set_shader_parameter("neblina", NEBLINA)
	var mi := MultiMeshInstance3D.new(); mi.multimesh = mm; mi.material_override = sm; mi.visibility_range_end = 160.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; no.add_child(mi)
	if brasas:
		var p := CPUParticles3D.new(); p.position = Vector3(0, alt * 0.4, 0)
		p.amount = 10 + n * 2; p.lifetime = 1.8; p.preprocess = 2.0
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; p.emission_sphere_radius = larg * 0.3
		p.direction = Vector3(0, 1, 0); p.spread = 18.0; p.initial_velocity_min = 0.6; p.initial_velocity_max = 1.4
		p.gravity = Vector3(0, 0.35, 0); p.damping_min = 0.2; p.damping_max = 0.5
		p.scale_amount_min = 0.5; p.scale_amount_max = 1.0; p.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 6, 4))
		var bq := QuadMesh.new(); bq.size = Vector2(0.045, 0.045)
		var mt := StandardMaterial3D.new(); mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mt.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES; mt.vertex_color_use_as_albedo = true
		mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bq.material = mt; p.mesh = bq
		var gr := Gradient.new(); gr.set_color(0, Color(1.0, 0.9, 0.5, 1)); gr.add_point(0.5, Color(1.0, 0.5, 0.12, 1)); gr.set_color(2, Color(0.6, 0.1, 0.05, 0))
		p.color_ramp = gr
		no.add_child(p)
	return no

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
# grades de 64 m para achar rápido as casas e os lugares perto de um ponto (o mapa tem centenas deles)
const CEL_G := 64.0
var _g_casas := {}
var _g_lugares := {}
var _n_casas := 0
var _n_lugares := 0
func _indexar(grade: Dictionary, item: Array, c: Vector2, raio: float) -> void:
	for j in range(int(floor((c.y - raio) / CEL_G)), int(floor((c.y + raio) / CEL_G)) + 1):
		for i in range(int(floor((c.x - raio) / CEL_G)), int(floor((c.x + raio) / CEL_G)) + 1):
			var k := Vector2i(i, j)
			if not grade.has(k): grade[k] = []
			grade[k].append(item)
func _atualizar_grades() -> void:
	while _n_casas < casas.size():
		var c: Array = casas[_n_casas]; _indexar(_g_casas, c, Vector2(c[0].x, c[0].z), maxf(c[2], c[3]) * 0.75 + 12.0); _n_casas += 1
	while _n_lugares < lugares.size():
		var l: Array = lugares[_n_lugares]; _indexar(_g_lugares, l, l[0], l[1] + 40.0); _n_lugares += 1

func perto_de_casa(x: float, z: float, folga: float) -> bool:
	_atualizar_grades()
	if folga > 10.0:
		for c in casas:
			var q0 := Vector2(x - c[0].x, z - c[0].z).rotated(c[1])
			if abs(q0.x) < c[2] * 0.5 + folga and abs(q0.y) < c[3] * 0.5 + folga: return true
		return Vector2(x, z).length() < 2.0
	for c in _g_casas.get(Vector2i(int(floor(x / CEL_G)), int(floor(z / CEL_G))), []):
		var q := Vector2(x - c[0].x, z - c[0].z).rotated(c[1])
		if abs(q.x) < c[2] * 0.5 + folga and abs(q.y) < c[3] * 0.5 + folga: return true
	if Vector2(x, z).length() < 2.0: return true          # poço
	return false

# música de fundo ("Time Flows Ever Onward"), em volume bem baixo, repetindo
# nitidez automática (celular): o jogo roda travado em 60 FPS; se ficar abaixo de ~48 por 4 s seguidos (fora do
# carregamento e com o jogo aberto), baixa UM nível de nitidez (a imagem 3D fica um pouco mais "pixelada", mas tudo
# continua igual). Não salva: na próxima vez começa da escolha do menu de novo.
var _auto_t := 0.0
var _auto_q := 0
var _auto_espera := 8.0
func _nitidez_auto(delta: float) -> void:
	if not celular or menu == null or menu.aberto or get_tree().paused: return
	_auto_espera -= delta
	if _auto_espera > 0.0: return
	_auto_t += delta; _auto_q += 1
	if _auto_t < 4.0: return
	var fps := _auto_q / _auto_t
	_auto_t = 0.0; _auto_q = 0
	if fps < 48.0 and menu.nitidez < 4:
		menu.nitidez += 1; aplicar_imagem(menu.nitidez, menu.pontilhado)
		_auto_espera = 6.0

# música: a do vale em todo lugar; dentro dos muros de Altamar entra a música da cidade (troca devagar, em 3 s,
# e a outra fica pausada no ponto onde parou). Sem o arquivo da cidade, continua só a do vale.
const VOL_MUSICA := -16.0
var _mus_vale: AudioStreamPlayer
var _mus_cidade: AudioStreamPlayer
var _na_cidade := false
var _t_musica := 0.0
func _musica() -> void:
	Audio.montar()
	_mus_vale = _tocador("res://assets/som/musica_vale.ogg"); _mus_vale.play()
	if ResourceLoader.exists("res://assets/som/musica_altamar.ogg"):
		_mus_cidade = _tocador("res://assets/som/musica_altamar.ogg"); _mus_cidade.volume_db = -60.0

func _tocador(arq: String) -> AudioStreamPlayer:
	var st: AudioStreamOggVorbis = load(arq); st.loop = true
	var mus := AudioStreamPlayer.new(); mus.stream = st; mus.volume_db = VOL_MUSICA; mus.bus = "Musica"
	add_child(mus); return mus

func _tick_musica(delta: float) -> void:
	if _mus_cidade == null or jogador == null: return
	_t_musica -= delta
	if _t_musica > 0.0: return
	_t_musica = 0.5
	var p := Vector2(jogador.global_position.x, jogador.global_position.z)
	var dentro := p.distance_to(Regiao.CIDADE_C) < Regiao.CIDADE_R - 4.0
	if dentro == _na_cidade: return
	_na_cidade = dentro
	var entra := _mus_cidade if dentro else _mus_vale
	var sai := _mus_vale if dentro else _mus_cidade
	if not entra.playing: entra.play()
	entra.stream_paused = false
	var tw := create_tween().set_parallel(true)
	tw.tween_property(entra, "volume_db", VOL_MUSICA, 3.0).set_trans(Tween.TRANS_SINE)
	tw.tween_property(sai, "volume_db", -60.0, 3.0).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_callback(func(): if (sai == _mus_vale) == _na_cidade: sai.stream_paused = true)

# o jogador não sai da região nem entra em água funda (volta para o último lugar bom)
func _physics_process(_d: float) -> void:
	if jogador == null: return
	var p := jogador.global_position
	var fundo := reg.agua(p.x, p.z) - p.y
	if not reg.dentro(p.x * 1.04, p.z * 1.04) or fundo > 0.9 or p.y < -20.0:
		jogador.global_position = _ultima; jogador.velocity = Vector3.ZERO; jogador.reset_physics_interpolation()
	elif jogador.is_on_floor():
		_ultima = p

func _tempo_jogo() -> float: return Time.get_ticks_msec() / 1000.0
func altura(x: float, z: float) -> float: return reg.altura(x, z)
func cor_chao(x: float, z: float, h: float, ny: float) -> Color: return reg.cor(x, z, h, ny)
func altura_malha(x: float, z: float) -> float: return terreno.altura_malha(x, z)
func normal_malha(x: float, z: float) -> Vector3: return terreno.normal_malha(x, z)
func _dist_estrada(p: Vector2) -> float: return reg.dist_estrada(p.x, p.y)
func perto_de_lugar(x: float, z: float, folga: float) -> bool:
	_atualizar_grades()
	var lista: Array = lugares if folga > 40.0 else _g_lugares.get(Vector2i(int(floor(x / CEL_G)), int(floor(z / CEL_G))), [])
	for l in lista:
		if Vector2(x, z).distance_to(l[0]) < l[1] + folga: return true
	return false

# junta as peças paradas (paredes, telhados, cercas, pedras...) do mesmo material em blocos de 96 m:
# o celular desenha muito menos objetos por quadro (cada objeto é uma "chamada de desenho")
var _agua_feita := false
func _juntar_estaticos() -> void:
	# casas têm várias partes (paredes, telhado, base, porta): cada parte vai para o grupo do seu material
	var grupos := {}                 # [material, célula x, célula z] → [[malha, superfície, transform], ...]
	var pular := {}
	for mo in moinhos: pular[mo] = true
	var ps1 := func(mt: Material) -> bool:
		var sm := mt as ShaderMaterial
		return sm != null and sm.shader != null and sm.shader.resource_path.ends_with("ps1.gdshader")
	var tirar := []
	for c in raiz.get_children():
		if not (c is MeshInstance3D) or pular.has(c) or c.get_child_count() > 0 or c.mesh == null: continue
		var mi: MeshInstance3D = c
		if not mi.visible or mi.mesh is PrimitiveMesh: continue
		var mats := []
		for si in mi.mesh.get_surface_count():
			var mt: Material = mi.material_override if mi.material_override else mi.mesh.surface_get_material(si)
			mats.append(mt)
		var todos := true
		for mt in mats: if not ps1.call(mt): todos = false
		if not todos: continue
		var p := mi.global_position
		for si in mats.size():
			var chave := [mats[si], int(floor(p.x / 96.0)), int(floor(p.z / 96.0))]
			if not grupos.has(chave): grupos[chave] = []
			grupos[chave].append([mi.mesh, si, mi.global_transform])
		tirar.append(mi)
	var antes := tirar.size(); var depois := 0
	for chave in grupos.keys():
		var lista: Array = grupos[chave]
		var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var base: Vector3 = lista[0][2].origin
		for it in lista: st.append_from(it[0], it[1], Transform3D(Basis(), -base) * it[2])
		var novo := MeshInstance3D.new(); novo.mesh = st.commit(); novo.material_override = chave[0]
		novo.position = base; raiz.add_child(novo); depois += 1
	for mi in tirar: mi.queue_free()
	if args.has("perf"): print("JUNTOU peças paradas: %d → %d objetos" % [antes, depois])

# ---------- tela: 3D em resolução baixa + filtro de paleta ----------
var _tela_cont: SubViewportContainer
# nitidez: a imagem 3D sai em 1/n da tela (4 leve, 3 média, 2 alta); pontilhado: filtro retrô de paleta curta.
# Sem o pontilhado a paleta fica bem maior (32 níveis), só para manter o jeitinho pintado sem faixas.
func aplicar_imagem(n: int, pont: bool) -> void:
	_tela_cont.stretch_shrink = n
	if hud: hud.escala_3d = n
	var sm: ShaderMaterial = _tela_cont.material
	sm.set_shader_parameter("forca_pontilhado", 0.7 if pont else 0.0)
	sm.set_shader_parameter("niveis", 9.0 if pont else 32.0)

func _tela() -> void:
	var cont := SubViewportContainer.new()
	cont.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cont.stretch = true; cont.stretch_shrink = REDUCAO
	cont.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new(); sm.shader = load("res://shaders/tela.gdshader"); cont.material = sm
	add_child(cont); _tela_cont = cont
	vp = SubViewport.new(); vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.audio_listener_enable_3d = true         # a câmera desta tela é o "ouvido" dos sons 3D (sem isso ficam mudos)
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
	_tick_criar()
	_gruta_pronta()
	_tick_estrada(delta)
	_gruta_luz(delta)
	_tick_musica(delta)
	_nitidez_auto(delta)
	_dia_noite(delta)
	_tick_veneno(delta)
	if jogador: _tick_voltas(delta)
	if hud and jogador:            # barra de vida do chefe no alto da tela (golem ou Rei da Lama) quando ele está brigando perto
		var ch: Monstro = null
		for c in [golem, chefe_lodoso]:
			if c and is_instance_valid(c) and c.grupo.alerta and c.estado != "morto" and c.global_position.distance_to(jogador.global_position) < 60.0: ch = c
		hud.chefe = ch
	if _salvar_em > 0.0:
		_salvar_em -= delta
		if _salvar_em <= 0.0:
			var ds := bolsa.salvar(hud.nivel, hud.xp)
			if nuvem: nuvem.enviar(ds)
	for mo in moinhos: mo.rotate_object_local(Vector3(0, 0, 1), delta * 0.6)
	if not TEMPESTADE and not args.has("raio"): return
	_prox_raio -= delta
	if _prox_raio <= 0.0:
		_prox_raio = randf_range(7.0, 16.0); _raio = 1.0
	if _raio > 0.0:
		_raio = max(0.0, _raio - delta * 2.2)
		var v: float = _raio * (0.6 + 0.4 * float(int(_raio * 14.0) % 2))    # pisca
		RenderingServer.global_shader_parameter_set("relampago", v)

# ---------- dia e noite ----------
# relógio do jogo: 1 hora = 1 minuto de verdade (o dia inteiro dura 24 min). A luz ambiente vai do branco
# (dia) ao laranja (pôr/nascer do sol) e ao azul-escuro (noite); as lanternas e fogueiras acendem no escuro.
var hora := 9.0
const MINUTOS_POR_HORA := 1.0
var luzes: Array[Vector3] = []       # lanternas dos postes e fogueiras (posição da chama)
var _brilhos: Array[Node3D] = []     # chamas das lanternas (aparecem só de noite)
var _t_luzes := 0.0
var noite := 0.0
func _dia_noite(delta: float) -> void:
	hora = fmod(hora + delta / (60.0 * MINUTOS_POR_HORA), 24.0)
	# noite: 0 de dia (7h–17h30), sobe no fim da tarde, 1 das 20h30 às 4h30, desce no amanhecer
	var h := hora
	noite = 1.0 - smoothstep(4.5, 7.0, h) if h < 12.0 else smoothstep(17.5, 20.5, h)
	var crep := clampf(1.0 - absf(noite - 0.45) * 2.6, 0.0, 1.0)
	var dia := Color(1, 1, 1); var tarde := Color(1.0, 0.72, 0.52); var escuro := Color(0.2, 0.25, 0.45)
	var c := dia.lerp(escuro, noite).lerp(tarde * (1.0 - noite * 0.5), crep * 0.55)
	_tempo_chuva(delta)
	_vento(delta)
	if hud: hud.hora = hora
	c = c.lerp(c * Color(0.62, 0.66, 0.74), chuva)                  # chovendo: tudo mais escuro e azulado
	c = c.lerp(Color(0.46, 0.44, 0.5), gruta_dentro)                # dentro da gruta: penumbra (tochas acesas)
	RenderingServer.global_shader_parameter_set("luz_ambiente", Vector3(c.r, c.g, c.b))
	RenderingServer.global_shader_parameter_set("noite", noite)
	var acesa := maxf(smoothstep(0.25, 0.6, noite), gruta_dentro)
	for b in _brilhos: b.visible = acesa > 0.05
	_t_luzes -= delta
	if _t_luzes > 0.0 or jogador == null: return
	_t_luzes = 0.25
	var pj := jogador.global_position
	var ordem := luzes.duplicate()
	ordem.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_squared_to(pj) < b.distance_squared_to(pj))
	for i in 6:
		var v := Vector4(0, -1000, 0, 0)
		if i < ordem.size() and acesa > 0.0:
			var q: Vector3 = ordem[i]; v = Vector4(q.x, q.y, q.z, acesa * (0.9 + 0.1 * sin(_tempo_jogo() * 7.0 + i)))
		RenderingServer.global_shader_parameter_set("lanterna%d" % i, v)

# ---------- chuva ----------
# de vez em quando chove: o céu fecha, a luz fica cinza-azulada, cai chuva em volta da Rachel e o som entra
# devagar (e sai devagar quando para). Tempo bom de 4 a 9 min, chuva de 2 a 4 min (tempo de verdade).
var chuva := 0.0
var _chuva_alvo := 0.0
var _prox_troca := 0.0
var _gotas: CPUParticles3D
var _som_chuva: AudioStreamPlayer
var _mat_gotas: StandardMaterial3D
func _montar_chuva() -> void:
	_prox_troca = randf_range(240.0, 540.0)
	_gotas = CPUParticles3D.new(); _gotas.amount = 380 if celular else 700; _gotas.lifetime = 0.9; _gotas.emitting = false
	_gotas.local_coords = false
	_gotas.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; _gotas.emission_box_extents = Vector3(16, 1, 16)
	_gotas.direction = Vector3(0.08, -1, 0.03); _gotas.spread = 3.0
	_gotas.initial_velocity_min = 17.0; _gotas.initial_velocity_max = 21.0; _gotas.gravity = Vector3.ZERO
	_gotas.visibility_aabb = AABB(Vector3(-20, -25, -20), Vector3(40, 30, 40))
	var q := QuadMesh.new(); q.size = Vector2(0.035, 0.6)
	var mt := StandardMaterial3D.new(); mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y; mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mt.albedo_color = Color(0.78, 0.84, 0.95, 0.45); q.material = mt; _gotas.mesh = q; _mat_gotas = mt
	raiz.add_child(_gotas)
	_som_chuva = AudioStreamPlayer.new(); var st: AudioStreamOggVorbis = load("res://assets/som/chuva.ogg"); st.loop = true
	_som_chuva.stream = st; _som_chuva.bus = "Efeitos"; _som_chuva.volume_db = -60.0; add_child(_som_chuva)

func _tempo_chuva(delta: float) -> void:
	if _gotas == null: return
	if not args.has("chuva"):
		_prox_troca -= delta
		if _prox_troca <= 0.0:
			_chuva_alvo = 1.0 - _chuva_alvo
			_prox_troca = randf_range(120.0, 240.0) if _chuva_alvo > 0.5 else randf_range(240.0, 540.0)
	chuva = move_toward(chuva, _chuva_alvo, delta / 25.0)                # entra e sai em ~25 s
	RenderingServer.global_shader_parameter_set("chuva", chuva)
	if jogador: _gotas.global_position = jogador.global_position + Vector3(0, 13, 0); _gotas.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_gotas.emitting = chuva > 0.15 and gruta_dentro < 0.5
	_mat_gotas.albedo_color.a = 0.45 * clampf((chuva - 0.1) / 0.9, 0.1, 1.0)     # chuva fraca no começo/fim
	if chuva > 0.01:
		if not _som_chuva.playing: _som_chuva.play()
		_som_chuva.volume_db = linear_to_db(chuva) - 11.0                 # mais baixa (antes -4 dB)
	elif _som_chuva.playing: _som_chuva.stop()

# ---------- vento ----------
# vento leve o tempo todo, com rajadas de vez em quando (mais forte na chuva): a grama, as árvores e as
# folhas balançam mais (uniform global forca_vento), folhinhas voam em volta da Rachel e o som acompanha.
var vento := 1.0
var _folhas: CPUParticles3D
var _som_vento: AudioStreamPlayer
const DIR_VENTO := Vector3(1.0, 0.0, 0.55)
func _montar_vento() -> void:
	_folhas = CPUParticles3D.new(); _folhas.amount = 26; _folhas.lifetime = 4.5; _folhas.local_coords = false
	_folhas.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; _folhas.emission_box_extents = Vector3(12, 2.5, 12)
	_folhas.direction = DIR_VENTO.normalized() + Vector3(0, 0.15, 0); _folhas.spread = 25.0
	_folhas.initial_velocity_min = 2.0; _folhas.initial_velocity_max = 4.0; _folhas.gravity = Vector3(0, -0.35, 0)
	_folhas.angle_min = 0.0; _folhas.angle_max = 360.0; _folhas.angular_velocity_min = -220.0; _folhas.angular_velocity_max = 220.0
	_folhas.scale_amount_min = 0.7; _folhas.scale_amount_max = 1.3
	_folhas.visibility_aabb = AABB(Vector3(-25, -6, -25), Vector3(50, 14, 50))
	var q := QuadMesh.new(); q.size = Vector2(0.09, 0.06)
	var mt := StandardMaterial3D.new(); mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES; mt.vertex_color_use_as_albedo = true; mt.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = mt; _folhas.mesh = q
	var g := Gradient.new(); g.set_color(0, Color(0.45, 0.62, 0.25)); g.add_point(0.5, Color(0.85, 0.65, 0.25)); g.set_color(2, Color(0.6, 0.35, 0.15))
	_folhas.color_initial_ramp = g
	raiz.add_child(_folhas)
	_som_vento = AudioStreamPlayer.new(); var st: AudioStreamOggVorbis = load("res://assets/som/vento.ogg"); st.loop = true
	_som_vento.stream = st; _som_vento.bus = "Efeitos"; _som_vento.volume_db = -30.0; add_child(_som_vento); _som_vento.play()

func _vento(delta: float) -> void:
	if _folhas == null: return
	var t := Lobo._relogio()
	var raj := clampf(0.5 + 0.6 * sin(t * 0.19) * sin(t * 0.47 + 1.3) + 0.15 * sin(t * 1.3), 0.0, 1.0)
	vento = lerpf(vento, 0.65 + raj * 0.85 + chuva * 0.6, 1.0 - exp(-0.8 * delta))
	RenderingServer.global_shader_parameter_set("forca_vento", vento)
	if jogador: _folhas.global_position = jogador.global_position + Vector3(0, 1.5, 0) - DIR_VENTO * 6.0; _folhas.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_folhas.emitting = vento > 1.05 and chuva < 0.6 and hora > 5.5 and hora < 20.0
	_folhas.speed_scale = clampf(vento * 0.8, 0.6, 1.6)
	_som_vento.volume_db = linear_to_db(clampf((vento - 0.45) / 1.5, 0.08, 1.0)) - 7.0

# postes de madeira com lanterna ao longo da rua principal e na praça (lanterna virada para a rua)
func _postes() -> void:
	var pontos := []                                       # [posição, para onde a lanterna aponta]
	for k in 6:                                            # praça do poço
		var a := TAU * (k + 0.5) / 6.0; var q := Vector2(cos(a), sin(a)) * 9.5
		if reg.folga_caminho(q.x, q.y) > 0.6 and not perto_de_casa(q.x, q.y, 0.6): pontos.append([q, Vector2.ZERO])
	for e in 2:
		var linha: PackedVector2Array = reg.estradas[e]
		var sp := 18.0; var lado := 1.0
		while sp < 74.0:
			var pr := _ponto_na_linha(linha, sp)
			var pt: Vector2 = pr[0]; var tg: Vector2 = pr[1]; var nrm := Vector2(-tg.y, tg.x) * lado
			for tent in 4:
				var q: Vector2 = pt + nrm * (3.6 + tent * 0.6)
				if reg.folga_caminho(q.x, q.y) > 0.4 and not perto_de_casa(q.x, q.y, 0.5):
					pontos.append([q, pt]); break
			sp += 13.0; lado = -lado
	var lista := []
	for pp in pontos:
		var q: Vector2 = pp[0]; var alvo: Vector2 = pp[1]
		var bom := true
		for o in lista: if q.distance_to(o[0]) < 6.0: bom = false
		if bom: lista.append(pp)
	for pp in lista: _poste_em(pp[0], pp[1])
	_postes_estrada_real()
	_estrada_preparar()

# Estrada Real iluminada: poste a cada 18 m, um lado e depois o outro (a luz de cada lanterna alcança ~9 m, então
# a estrada fica clara a noite toda); começa depois dos postes da vila e para antes da ponte (lá já tem os da cidade).
# Longe da Rachel os postes não são desenhados (alcance 130 m).
func _postes_estrada_real() -> void:
	if reg.estrada_real < 0: return
	var linha: PackedVector2Array = reg.estradas[reg.estrada_real]
	var lado := 1.0; var sp := 80.0; var n := 0
	while true:
		var pr := _ponto_na_linha(linha, sp)
		var pt: Vector2 = pr[0]; var tg: Vector2 = pr[1]
		if pt.x > Regiao.FOSSO_X - 40.0: break
		var nrm := Vector2(-tg.y, tg.x) * lado
		for tent in 4:
			var q: Vector2 = pt + nrm * (3.6 + tent * 0.6)
			if reg.folga_caminho(q.x, q.y) > 0.4 and reg.agua(q.x, q.y) == 0.0 and reg.dist_rios(q.x, q.y) > 8.0 and not perto_de_casa(q.x, q.y, 0.5):
				_poste_em(q, pt, 130.0); n += 1; break
		sp += 18.0; lado = -lado
	if args.has("perf"): print("ESTRADA REAL: %d postes" % n)

# Estrada Real calçada de pedra (textura pintada pelo dono): uma faixa própria por cima do terreno, da vila até a
# ponte (de lá em diante já é o calçamento da cidade). Montada em pedaços de ~90 m só quando a Rachel chega perto
# (usa a altura da malha do terreno, que só existe perto dela) e longe some pela distância de visão.
const ESTRADA_MEIA := 2.9
var _estrada_ped := []          # [centro, amostras [[ponto, normal, s]], feito, meia largura]
var _t_estrada := 0.0
func _estrada_preparar() -> void:
	if reg.estrada_real < 0: return
	var c := Regiao.CIDADE_C; var fx := Regiao.FOSSO_X; var rr := Regiao.CIDADE_R
	# Estrada Real (vila → ponte) e, com a mesma pedra, a chegada da ponte, as quatro ruas principais de Altamar
	# (da praça até os portões; a do norte para no castelo) e a praça
	_faixa_linha(reg.estradas[reg.estrada_real], ESTRADA_MEIA, func(p: Vector2) -> bool: return p.x > fx - 92.0)
	_faixa_linha(PackedVector2Array([Vector2(fx - 92.0, c.y), Vector2(fx - 19.5, c.y)]), 4.0)
	var fora_canal := func(p: Vector2) -> bool: return absf(p.distance_to(c) - Regiao.CANAL) < 7.0    # pontes do canal
	_faixa_linha(PackedVector2Array([Vector2(fx + 19.5, c.y), c + Vector2(-24.0, 0)]), 5.5, fora_canal)
	_faixa_linha(PackedVector2Array([c + Vector2(24.0, 0), c + Vector2(rr + 30.0, 0)]), 5.5, fora_canal)
	_faixa_linha(PackedVector2Array([c + Vector2(0, -24.0), c + Vector2(0, -150.0)]), 5.5, fora_canal)
	_faixa_linha(PackedVector2Array([c + Vector2(0, 24.0), c + Vector2(0, rr - 2.0)]), 5.5, fora_canal)
	_estrada_ped.append([c, [], false, -24.0])                     # a praça (disco de 24 m; meia < 0 = disco)

# amostras a cada 1,5 m ao longo da linha; "pular" tira trechos (ponte, canal); pedaços de ~90 m
func _faixa_linha(linha: PackedVector2Array, meia: float, pular := Callable()) -> void:
	var trechos := [[]]; var sp := 0.0
	var total := 0.0
	for i in linha.size() - 1: total += linha[i].distance_to(linha[i + 1])
	while sp <= total:
		var pr := _ponto_na_linha(linha, sp)
		var pt: Vector2 = pr[0]; var tg: Vector2 = pr[1]
		if pular.is_valid() and pular.call(pt):
			if not trechos[-1].is_empty(): trechos.append([])
		else: trechos[-1].append([pt, Vector2(-tg.y, tg.x), sp])
		sp += 1.5
	for amostras: Array in trechos:
		var k := 0
		while k < amostras.size() - 1:
			var fim := mini(k + 60, amostras.size() - 1)
			var pedaco := amostras.slice(k, fim + 1)
			var cc := Vector2.ZERO
			for a in pedaco: cc += a[0]
			_estrada_ped.append([cc / pedaco.size(), pedaco, false, meia])
			k = fim

func _tick_estrada(delta: float) -> void:
	_t_estrada -= delta
	if _t_estrada > 0.0 or jogador == null: return
	_t_estrada = 0.4
	var pj := Vector2(jogador.global_position.x, jogador.global_position.z)
	for pd in _estrada_ped:
		if pd[2] or (pd[0] as Vector2).distance_to(pj) > 240.0: continue
		pd[2] = true                                               # um pedaço por vez
		if float(pd[3]) < 0.0: _praca_montar(pd[0], -float(pd[3]))
		else: _estrada_montar(pd[1], pd[3])
		return

func _estrada_montar(amostras: Array, meia: float) -> void:
	var st := _st()
	var linhas := []
	for a in amostras:
		var p: Vector2 = a[0]; var n: Vector2 = a[1]
		var fila := []
		for u in [-1.0, -0.5, 0.0, 0.5, 1.0]:
			var q: Vector2 = p + n * float(u) * meia
			var y := altura_malha(q.x, q.y) + (0.05 if absf(u) > 0.9 else 0.09)
			fila.append([Vector3(q.x, y, q.y), Vector2((u + 1.0) * meia / 2.8, float(a[2]) / 2.8)])
		linhas.append(fila)
	for i in linhas.size() - 1:
		for j in 4:
			var v00: Array = linhas[i][j]; var v01: Array = linhas[i][j + 1]; var v10: Array = linhas[i + 1][j]; var v11: Array = linhas[i + 1][j + 1]
			for t in [[v00, v10, v11], [v00, v11, v01]]:
				for v: Array in t:
					st.set_normal(Vector3.UP); st.set_color(Color.WHITE); st.set_uv(v[1]); st.add_vertex(v[0])
	var mi := _peca(st, mat("estrada_pedra", 1.0), Vector3.ZERO)
	mi.visibility_range_end = 260.0

func _praca_montar(c: Vector2, r: float) -> void:              # disco de pedra (anéis de 2 m, 24 fatias)
	var st := _st()
	var n := 24; var aneis := int(ceil(r / 2.0))
	var pt := func(rad: float, a: float) -> Vector3:
		var q := c + Vector2(cos(a), sin(a)) * rad
		return Vector3(q.x, altura_malha(q.x, q.y) + 0.08, q.y)
	for k in aneis:
		var r0 := r * k / aneis; var r1 := r * (k + 1) / aneis
		for i in n:
			var a0 := TAU * i / n; var a1 := TAU * (i + 1) / n
			var p00: Vector3 = pt.call(r0, a0); var p01: Vector3 = pt.call(r0, a1); var p10: Vector3 = pt.call(r1, a0); var p11: Vector3 = pt.call(r1, a1)
			for t in [[p00, p10, p11], [p00, p11, p01]]:
				for q: Vector3 in t:
					st.set_normal(Vector3.UP); st.set_color(Color.WHITE); st.set_uv(Vector2(q.x, q.z) / 2.8); st.add_vertex(q)
	var mi := _peca(st, mat("estrada_pedra", 1.0), Vector3.ZERO)
	mi.visibility_range_end = 260.0

# um poste com lanterna em q, virado para "olha"
func _poste_em(q: Vector2, olha: Vector2, alcance := 0.0) -> void:
		var d: Vector2 = (olha - q).normalized()
		_depois.append(func():
			var y := altura_malha(q.x, q.y)
			var mod := modelo_ps1("res://assets/modelos/poste.glb")
			var k := 2.6 / 0.977
			mod.scale = Vector3(k, k, k); mod.position = Vector3(q.x, y + 0.489 * k - 0.05, q.y)
			mod.rotation.y = atan2(-d.x, -d.y)             # lanterna (-Z do modelo) para a rua
			raiz.add_child(mod)
			if alcance > 0.0:
				for mi in mod.find_children("*", "MeshInstance3D", true, false): (mi as MeshInstance3D).visibility_range_end = alcance
			_colisor_cilindro(Vector3(q.x, y, q.y), 0.16, 2.6)
			var lp := mod.global_transform * Vector3(0.065, 0.243, -0.181)
			luzes.append(lp + Vector3(0, -0.2, 0))
			var ch := _splats([[lp, Color(1.0, 0.82, 0.4), 0.22], [lp + Vector3(0, 0.04, 0), Color(1.0, 0.95, 0.7), 0.12]], Vector2(1, 1), false, 0.0, 0.0, true)
			if alcance > 0.0 and ch is GeometryInstance3D: (ch as GeometryInstance3D).visibility_range_end = alcance
			ch.visible = false; _brilhos.append(ch))

# barracas de acampamento: longe da vila, longe umas das outras e longe das estradas, em lugares isolados.
# Cada uma tem uma fogueira; perto dela aparece o botão DESCANSAR (dorme até as 6h).
var barracas: Array[Vector2] = []
var _fogueiras_barraca: Array[Vector2] = []
func _barracas() -> void:
	var cand := []
	var rng := RandomNumberGenerator.new(); rng.seed = 91
	for i in 3000:
		var q := Vector2(rng.randf_range(Regiao.X0 + 80, Regiao.X1 - 80), rng.randf_range(-Regiao.LIM + 80, Regiao.LIM - 80))
		if q.length() < 170.0 or reg.folga_caminho(q.x, q.y) < 22.0 or reg.agua(q.x, q.y) != 0.0: continue
		if reg.dist_rio(q.x, q.y) < 25.0 or Vector2(q.x - Regiao.LAGO.x, q.y - Regiao.LAGO.y).length() < Regiao.LAGO.z + 15.0: continue
		if perto_de_lugar(q.x, q.y, 30.0) or reg.campo_em(q.x, q.y) >= 0: continue
		var h0 := reg.altura(q.x, q.y); var desnivel := 0.0
		for o in [Vector2(4, 0), Vector2(-4, 0), Vector2(0, 4), Vector2(0, -4)]:
			desnivel = maxf(desnivel, absf(reg.altura(q.x + o.x, q.y + o.y) - h0))
		if desnivel > 1.2: continue
		cand.append(q)
	# escolhe as mais espalhadas (cada nova o mais longe possível das já escolhidas e da vila)
	var esc: Array[Vector2] = []
	while esc.size() < 9 and not cand.is_empty():
		var melhor: Vector2 = cand[0]; var md := -1.0
		for q in cand:
			var d: float = q.length() * 0.6
			for e in esc: d = minf(d, q.distance_to(e))
			if d > md: md = d; melhor = q
		if md < 260.0 and esc.size() > 0: break
		esc.append(melhor)
	for q in esc: _barraca(q, rng.randf() * TAU)

func _barraca(c: Vector2, ang: float) -> void:
	var y := reg.aplanar(c, Vector2(3.0, 3.0), ang, 3.0)
	barracas.append(c); lugares.append([c, 6.0]); _fogueiras_barraca.append(c + Vector2(2.9, 0).rotated(-ang))
	var mod := modelo_ps1("res://assets/modelos/barraca.glb")
	var k := 2.4 / 0.975
	mod.scale = Vector3(k, k, k); mod.position = Vector3(c.x, y + 0.33 * k - 0.04, c.y); mod.rotation.y = ang
	raiz.add_child(mod)
	_colisor_caixa(Vector3(c.x, y, c.y), Vector3(2.3, 1.5, 1.6), ang)
	# fogueira na frente (pedras, lenha e chamas)
	var f := c + Vector2(2.9, 0).rotated(-ang)            # na frente da entrada (ponta +X do modelo)
	var st := _st(); cilindro(st, Vector3(f.x, y - 0.1, f.y), 0.5, 0.5, 0.2, 7); _peca(st, mat("pedra"), Vector3.ZERO)
	st = _st()
	_caixa(st, Vector3(f.x, y + 0.1, f.y), Vector3(0.9, 0.1, 0.12)); _caixa(st, Vector3(f.x, y + 0.2, f.y), Vector3(0.12, 0.1, 0.9))
	_peca(st, mat("madeira"), Vector3.ZERO)
	_fogo(Vector3(f.x, y + 0.12, f.y), 0.75, 1.0, 4)
	luzes.append(Vector3(f.x, y + 0.6, f.y))

# ---------- material PS1 ----------
func mat(textura: String, escala := 1.0, cor := Color.WHITE) -> ShaderMaterial:
	var k := "%s|%s|%s" % [textura, escala, cor]
	if _mats.has(k): return _mats[k]
	var m := ShaderMaterial.new(); m.shader = load("res://shaders/terreno.gdshader" if textura == "terreno" else "res://shaders/ps1.gdshader")
	if textura == "terreno": m.set_shader_parameter("tex_rocha", Texturas.pegar("rocha_montanha"))   # montanhas com a rocha da entrada da gruta
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
	# VILA REDONDA: casas em dois anéis em volta da praça do poço, viradas para o centro; vãos onde passam as
	# estradas e as trilhas. A taverna fica no anel de dentro, perto da estrada sul (por onde se chega);
	# a igreja no anel de fora, ao norte.
	var espec := {}
	for anel in [[24.0, 0], [40.0, 1]]:
		var r: float = anel[0]
		var a := rng.randf() * 0.3
		while a < TAU:
			var w := rng.randf_range(4.8, 6.6); var d := rng.randf_range(4.0, 5.2); var h := rng.randf_range(2.6, 3.3)
			var parede: Material = null; var telhado: Material = null
			var am := a + (w * 0.5 + 1.0) / r
			var q := Vector2(cos(am), sin(am)) * r
			var e_taverna: bool = anel[1] == 0 and not espec.has("taverna") and q.y > 8.0 and q.x < -6.0
			var e_igreja: bool = anel[1] == 1 and not espec.has("igreja") and q.y < -20.0 and q.x > 6.0
			if e_taverna: w = 10.0; d = 7.5; h = 5.2
			if e_igreja: w = 7.5; d = 12.0; h = 5.0; parede = mat("pedra"); telhado = mat("madeira", 1.0, Color(0.55, 0.5, 0.55))
			am = a + (w * 0.5 + 1.0) / r; q = Vector2(cos(am), sin(am)) * r
			a += (w + rng.randf_range(2.2, 4.0)) / r
			if reg.dist_estrada(q.x, q.y) < w * 0.5 + 4.5 or reg.dist_trilha(q.x, q.y) < w * 0.5 + 2.5: continue
			if not (e_taverna or e_igreja) and rng.randf() < 0.12: continue        # alguns vãos (quintais)
			if perto_de_casa(q.x, q.y, maxf(w, d) * 0.5 + 0.8): continue
			var ang := atan2(-q.x, -q.y)                                         # porta virada para a praça
			_casa(Vector3(q.x, 0, q.y), ang, w, d, h, parede, telhado)
			if e_taverna: espec["taverna"] = true
			if e_igreja: espec["igreja"] = true; _torre_igreja(ang); igreja_vila = [q, Vector2(-q.x, -q.y).normalized(), d]
	# grupos de casas no fim das trilhas: sítio a oeste, casas a leste, casa de pescador no rio, casa ao norte
	for g in [[Vector2(-58, -36), 3], [Vector2(-46, -54), 3], [Vector2(-64, -48), 3], [Vector2(38, 50), 1], [Vector2(52, 38), 1],
			[Vector2(100, -74), 2], [Vector2(32, -88), 3]]:
		var c: Vector2 = g[0]
		if perto_de_casa(c.x, c.y, 4.0): continue
		var fim := _fim_trilha(g[1]); var ang := atan2(fim.x - c.x, fim.y - c.y)
		_casa(Vector3(c.x, 0, c.y), ang, rng.randf_range(4.6, 6.0), rng.randf_range(4.0, 4.8), rng.randf_range(2.6, 3.0))
	_pier_rio()
	_poco(Vector3(0, reg.aplanar(Vector2.ZERO, Vector2(1.6, 1.6), 0.0, 2.0) - 0.1, 0))
	for b in [[3.5, 2.0], [4.2, 2.6], [-3.0, 3.6], [6.0, -9.0]]:
		_barril(Vector3(b[0], altura(b[0], b[1]), b[1]))
	_ferraria()
	lugares.append([Vector2.ZERO, 16.0])

# ponto a "s" metros ao longo de uma linha (e a direção dela ali)
func _ponto_na_linha(linha: PackedVector2Array, s_pos: float) -> Array:
	var acum := 0.0
	for i in linha.size() - 1:
		var seg := linha[i].distance_to(linha[i + 1])
		if acum + seg >= s_pos: return [linha[i].lerp(linha[i + 1], (s_pos - acum) / seg), (linha[i + 1] - linha[i]).normalized()]
		acum += seg
	return [linha[linha.size() - 1], (linha[linha.size() - 1] - linha[linha.size() - 2]).normalized()]

func _fim_trilha(i: int) -> Vector2:
	var t: PackedVector2Array = reg.trilhas[i]; return t[t.size() - 1]

func _torre_igreja(ang_ig: float) -> void:
	var pig: Vector3 = casas[casas.size() - 1][0]
	var torre := Vector3(pig.x, 0, pig.z) + Vector3(0, 0, -7.5).rotated(Vector3.UP, ang_ig)
	torre.y = reg.aplanar(Vector2(torre.x, torre.z), Vector2(2.4, 2.4), -ang_ig, 3.0) - 0.3
	var mesh := ArrayMesh.new(); var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_caixa(st, Vector3(0, 5.0, 0), Vector3(3.6, 10.0, 3.6)); st.set_material(mat("pedra")); st.commit(mesh)
	st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	cilindro(st, Vector3(0, 10.0, 0), 2.7, 0.0, 4.5, 4); st.set_material(mat("madeira", 1.0, Color(0.55, 0.5, 0.55))); st.commit(mesh)
	var mi := MeshInstance3D.new(); mi.mesh = mesh; mi.position = torre; mi.rotation.y = ang_ig + PI / 4.0; raiz.add_child(mi)
	_colisor_caixa(torre, Vector3(3.6, 10, 3.6), ang_ig)
	casas.append([torre, ang_ig, 3.6, 3.6])

# píer de madeira no fim da trilha do rio, entrando na água, com um barquinho amarrado
func _pier_rio() -> void:
	var ini := _fim_trilha(2) + Vector2(-2, 0)
	var dir := Vector2(1, 0)
	var na_agua := ini
	for k in 40:
		na_agua = ini + dir * k
		if reg.dist_rio(na_agua.x, na_agua.y) < reg.largura_rio(0.4) * 0.5 - 1.0: break
	var comp := ini.distance_to(na_agua) + 4.0
	var y := maxf(reg.altura(ini.x, ini.y), reg.agua(na_agua.x, na_agua.y)) + 0.45
	var st := _st()
	var n := int(comp / 1.2)
	for i in n:
		var q := ini + dir * (i * 1.2 + 0.6)
		_caixa(st, Vector3(q.x, y, q.y), Vector3(1.2, 0.14, 2.2))
		if i % 2 == 0:
			for lz in [-1.0, 1.0]: _caixa(st, Vector3(q.x, y - 1.4, q.y + lz), Vector3(0.22, 2.8, 0.22))
	_peca(st, mat("madeira"), Vector3.ZERO)
	var meio := ini + dir * comp * 0.5
	_colisor_caixa(Vector3(meio.x, y - 0.12, meio.y), Vector3(2.2, 0.15, comp), PI / 2)
	var bp := ini + dir * (comp - 1.0) + Vector2(0, 2.4)
	st = _st(); _caixa(st, Vector3(0, 0.25, 0), Vector3(3.8, 0.55, 1.4)); _caixa(st, Vector3(2.0, 0.32, 0), Vector3(0.6, 0.4, 0.8))
	_peca(st, mat("madeira", 1.0, Color(0.75, 0.6, 0.5)), Vector3(bp.x, reg.agua(bp.x, bp.y) - 0.05, bp.y), 0.15)
	lugares.append([meio, comp * 0.5 + 2.0]); pier_pos = meio

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
		if not perto_de_casa(q.x, q.y, 6.0) and reg.folga_caminho(q.x, q.y) > 5.0: c = q; break
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
	var boca: Vector3 = no.transform * Vector3(-2.2, 0.36, -1.32)
	for dx in [-0.42, 0.0, 0.42]:
		_fogo(boca + no.transform.basis * Vector3(dx, 0, 0), 0.5, 0.62, 2, dx == 0.0, 0.1)
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

# piso fino em grade de 1,5 m que acompanha o chão (um pouco acima, para não brigar com o terreno)
func _chao_textura(r: Rect2, material: Material, passo := 1.5) -> void:
	var st := _st()
	var nx := int(ceil(r.size.x / passo)); var nz := int(ceil(r.size.y / passo))
	var h := func(x: float, z: float) -> float: return reg.altura(x, z) + 0.06
	for j in nz:
		for i in nx:
			var x0 := r.position.x + i * passo; var z0 := r.position.y + j * passo
			var x1 := minf(x0 + passo, r.end.x); var z1 := minf(z0 + passo, r.end.y)
			var a := Vector3(x0, h.call(x0, z1), z1); var b := Vector3(x1, h.call(x1, z1), z1)
			var c := Vector3(x1, h.call(x1, z0), z0); var d := Vector3(x0, h.call(x0, z0), z0)
			for v in [[a, b, c], [a, c, d]]:
				for q: Vector3 in v:
					st.set_normal(Vector3.UP); st.set_color(Color.WHITE); st.set_uv(Vector2(q.x, q.z) * 0.5); st.add_vertex(q)
	_peca(st, material, Vector3.ZERO)

func _st() -> SurfaceTool:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES); return st

# ---------- água ----------
func _agua() -> void:
	var am := ShaderMaterial.new(); am.shader = load("res://shaders/agua.gdshader"); am.set_shader_parameter("neblina", NEBLINA)
	_faixa_rio(reg.rio2, reg.largura_rio2, func(t: float) -> float: return reg.nivel_rio2(t), am)
	# mar (leste) e poças do pântano (sul): um plano no nível 0
	var mar := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(Regiao.X1 - Regiao.X0 + 800.0, Regiao.LIM * 2.0 + 800.0); mar.mesh = pm
	mar.position = Vector3((Regiao.X0 + Regiao.X1) * 0.5, 0, 0)
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

# espuma nas beiradas: ondas na praia do mar, correnteza nas margens do rio, marolinhas no lago e na ilha
func _espuma() -> void:
	var faixa := func(pts_agua: Array, pts_margem: Array, ys: Array, modo: int, vel: float, forca: float) -> void:
		var st := _st(); var dist := 0.0
		for i in pts_agua.size() - 1:
			var a0: Vector2 = pts_agua[i]; var a1: Vector2 = pts_agua[i + 1]
			var m0: Vector2 = pts_margem[i]; var m1: Vector2 = pts_margem[i + 1]
			var d1 := dist + m0.distance_to(m1)
			var y0: float = ys[i]; var y1: float = ys[i + 1]
			var v := [Vector3(a0.x, y0, a0.y), Vector3(a1.x, y1, a1.y), Vector3(m1.x, y1, m1.y), Vector3(m0.x, y0, m0.y)]
			var uv := [Vector2(dist, 0), Vector2(d1, 0), Vector2(d1, 1), Vector2(dist, 1)]
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_normal(Vector3.UP); st.set_uv(uv[k]); st.add_vertex(v[k])
			dist = d1
		var sm := ShaderMaterial.new(); sm.shader = load("res://shaders/espuma.gdshader"); sm.render_priority = 1
		sm.set_shader_parameter("modo", modo); sm.set_shader_parameter("velocidade", vel); sm.set_shader_parameter("forca", forca)
		sm.set_shader_parameter("neblina", NEBLINA)
		var mi := MeshInstance3D.new(); mi.mesh = st.commit(); mi.material_override = sm; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		raiz.add_child(mi)
	# mar: acha a linha da praia (onde o chão desce abaixo do nível 0) de norte a sul, até o pântano
	var agua := []; var margem := []; var ys := []
	var z := -Regiao.LIM + 40.0
	var x_ant := -1e9
	while z < Regiao.Ws(370.0):
		# acha a praia em passos de 8 m (começando um pouco antes da praia da linha anterior) e refina de 1 em 1 m;
		# antes andava de 1 em 1 m desde o meio do mapa: ~1 milhão de consultas e 12 s de carregamento
		var x := maxf(Regiao.Ws(380.0), x_ant - 120.0)
		while x < Regiao.X1 and reg.altura(x, z) > 0.05: x += 8.0
		if x < Regiao.X1:
			x = maxf(x - 8.0, Regiao.Ws(380.0))
			while x < Regiao.X1 and reg.altura(x, z) > 0.05: x += 1.0
			x_ant = x
		if x < Regiao.X1:
			agua.append(Vector2(x + 16.0, z)); margem.append(Vector2(x - 1.2, z)); ys.append(0.05)
		z += 4.0
	if agua.size() > 1: faixa.call(agua, margem, ys, 0, 1.0, 1.0)
	# rio: uma faixa por margem, a correnteza descendo (UV.x cresce rio abaixo)
	var pts := []
	for i in reg.rio.size() - 1:
		var a: Vector2 = reg.rio[i]; var b: Vector2 = reg.rio[i + 1]
		var n := int(ceil(a.distance_to(b) / 3.0))
		for k in n: pts.append(a.lerp(b, float(k) / n))
	pts.append(reg.rio[reg.rio.size() - 1])
	var tot := 0.0; var ts := [0.0]
	for i in range(1, pts.size()): tot += pts[i].distance_to(pts[i - 1]); ts.append(tot)
	for lado in [-1.0, 1.0]:
		var ag := []; var mg := []; var yy := []
		for i in pts.size():
			var t: float = ts[i] / tot
			var d: Vector2 = (pts[min(i + 1, pts.size() - 1)] - pts[max(i - 1, 0)]).normalized()
			var nrm: Vector2 = Vector2(-d.y, d.x) * float(lado); var meia: float = reg.largura_rio(t) * 0.5
			ag.append(pts[i] + nrm * (meia - 2.2)); mg.append(pts[i] + nrm * (meia + 0.4)); yy.append(reg.nivel_rio(t) - 0.09)
		faixa.call(ag, mg, yy, 1, 1.0, 1.0)
	# lago e ilha: anéis com marolinhas lentas
	var lc := Vector2(Regiao.LAGO.x, Regiao.LAGO.y); var yl := reg.nivel_lago() - 0.09
	for anel in [[Regiao.LAGO.z - 5.0, Regiao.LAGO.z + 0.6], [Regiao.ILHA.z + 4.5, Regiao.ILHA.z - 0.6]]:
		var ag := []; var mg := []; var yy := []
		for k in 81:
			var ang := TAU * k / 80.0; var q := Vector2(cos(ang), sin(ang))
			ag.append(lc + q * anel[0]); mg.append(lc + q * anel[1]); yy.append(yl)
		faixa.call(ag, mg, yy, 0, 0.55, 0.85)

# ---------- cidade grande: Altamar (redonda, por bairros) ----------
# Muralha redonda de pedra clara com torres de telhado azul e três portões. Fora do portão oeste: fosso e a Ponte
# dos Guardiões, com quatro estátuas de heróis (guerreiro de martelo, maga de cajado, arqueira, cavaleiro de
# espada). Dentro: praça central com chafariz, anel do Comércio (lojas com placas penduradas), canal em anel com
# mureta e pontes; bairros: Castelo (norte), Catedral (noroeste), Portão (oeste), Magos (sudoeste, torre roxa),
# Parque (sul: árvores, grama e lago), Porto (sudeste: armazéns e caixotes) e Bairro Velho (leste). Ruas principais
# de pedra clara com calçada de tijolo, postes de luz e árvores. Os modelos do dono vão substituindo as peças.
var cidade_pos := Vector2.ZERO
var cidade_y := 0.0
var estabulo_pos := Vector2.ZERO
var taverna_pos := Vector2.ZERO
var estabulo_npc: Morador
var floresta: Floresta
var freiras := []                 # as irmãs que vendem poções (na frente da igreja da vila e da catedral)
var igreja_vila := []             # [posição da igreja, direção da porta]
var montaria_ui: Montaria
var cidade_lojas := []              # [nome, posição da porta] — banco, taverna, lojas (para as interações depois)
var arvores_cidade := []            # [posição Vector3, escala] — a floresta desenha
func _mat_tex(arq: String) -> ShaderMaterial:
	var k := "tex|" + arq
	if _mats.has(k): return _mats[k]
	var sm := ShaderMaterial.new(); sm.shader = load("res://shaders/ps1.gdshader")
	sm.set_shader_parameter("tex", load(arq)); sm.set_shader_parameter("neblina", NEBLINA)
	_mats[k] = sm; return sm

func _cidade() -> void:
	var c: Vector2 = Regiao.CIDADE_C; cidade_pos = c
	var RR: float = Regiao.CIDADE_R
	var y := Regiao.ALTURA_CIDADE; cidade_y = y
	var rng := RandomNumberGenerator.new(); rng.seed = 1234
	var pedra := mat("pedra", 1.0, Color(1.15, 1.12, 1.05))
	var pedra_esc := mat("pedra", 1.0, Color(0.85, 0.85, 0.9))
	var azul := mat("telha", 1.4)            # telhado de ardósia azul (textura pintada pelo dono)
	var dirv := func(a: float) -> Vector2: return Vector2(cos(a), sin(a))
	var portoes := [PI, PI * 0.5, 0.0]
	var meia_porta := 8.0 / RR
	var em_porta := func(a: float) -> bool:
		for pa in portoes: if absf(wrapf(a - pa, -PI, PI)) < meia_porta: return true
		return false
	# ---- muralha redonda com ameias
	var n_seg := 56; var alt := 10.0; var esp := 3.5
	var st := _st(); var st_am := _st()
	for k in n_seg:
		var a0 := TAU * k / n_seg; var a1 := TAU * (k + 1) / n_seg
		if em_porta.call((a0 + a1) * 0.5) or em_porta.call(a0 + 0.001) or em_porta.call(a1 - 0.001): continue   # qualquer pedaço que toque o vão sai (antes o vão caía na junta e o portão ficava fechado)
		var p0: Vector2 = c + dirv.call(a0) * RR; var p1: Vector2 = c + dirv.call(a1) * RR
		var meio := (p0 + p1) * 0.5; var comp := p0.distance_to(p1) + 0.6; var ang := atan2(p1.x - p0.x, p1.y - p0.y)
		var tr := Transform3D(Basis(Vector3.UP, ang), Vector3(meio.x, y, meio.y))
		var bx := _st(); _caixa(bx, Vector3(0, alt * 0.5 - 1.0, 0), Vector3(esp, alt + 2.0, comp)); st.append_from(bx.commit(), 0, tr)
		for i in 4:
			var ca := _st(); _caixa(ca, Vector3(0, alt + 0.6, -comp * 0.5 + (i + 0.5) * comp / 4.0), Vector3(esp + 0.2, 1.3, comp / 8.0))
			st_am.append_from(ca.commit(), 0, tr)
		_colisor_caixa(Vector3(meio.x, y - 1.0, meio.y), Vector3(esp, alt + 2.0, comp), ang)
	_peca(st, pedra, Vector3.ZERO); _peca(st_am, pedra, Vector3.ZERO)
	# ---- torres
	st = _st(); var st_t := _st()
	var torres := []
	for k in range(0, n_seg, 7):
		var a := TAU * k / n_seg
		if not em_porta.call(a): torres.append([a, 4.6, 16.0])
	for pa in portoes:
		torres.append([pa + meia_porta * 1.3, 5.6, 21.0]); torres.append([pa - meia_porta * 1.3, 5.6, 21.0])
	for t in torres:
		var tp: Vector2 = c + dirv.call(t[0]) * RR
		cilindro(st, Vector3(tp.x, y - 1.0, tp.y), t[1], t[1] - 0.4, t[2], 8, true)
		cilindro(st, Vector3(tp.x, y + t[2] - 1.0, tp.y), t[1] + 0.5, t[1] + 0.5, 1.0, 8, true)     # beiral da torre
		cilindro(st_t, Vector3(tp.x, y + t[2], tp.y), t[1] + 0.8, 0.0, t[2] * 0.45, 8)
		_colisor_cilindro(Vector3(tp.x, y - 1.0, tp.y), t[1], t[2])
	_peca(st, pedra, Vector3.ZERO); _peca(st_t, azul, Vector3.ZERO)
	st = _st()
	for pa in portoes:
		var pp: Vector2 = c + dirv.call(pa) * RR
		var arco := _st(); _caixa(arco, Vector3(0, alt + 1.0, 0), Vector3(esp + 1.5, 4.0, 20.0))
		st.append_from(arco.commit(), 0, Transform3D(Basis(Vector3.UP, atan2(-sin(pa), cos(pa))), Vector3(pp.x, y, pp.y)))
	_peca(st, pedra_esc, Vector3.ZERO)
	# ---- Ponte dos Guardiões sobre o rio do leste (portão oeste)
	var fx := Regiao.FOSSO_X
	var agua_m := ShaderMaterial.new(); agua_m.shader = load("res://shaders/agua.gdshader"); agua_m.set_shader_parameter("neblina", NEBLINA)
	st = _st()
	var x_ponte0 := fx - 19.0; var x_ponte1 := fx + 19.0
	for lado in [-1.0, 1.0]:                                     # pilares
		for xx in [fx - 9.0, fx, fx + 9.0]: _caixa(st, Vector3(xx, y - 3.0, c.y + lado * 5.0), Vector3(2.0, 6.0, 2.0))
	_caixa(st, Vector3((x_ponte0 + x_ponte1) * 0.5, y + 0.1, c.y), Vector3(x_ponte1 - x_ponte0, 0.6, 16.0))
	for lado in [-1.0, 1.0]:
		for xx in range(int(x_ponte0), int(x_ponte1), 3):
			_caixa(st, Vector3(xx + 1.5, y + 0.9, c.y + lado * 7.6), Vector3(3.0, 1.0 if (xx / 3) % 2 == 0 else 0.6, 0.8))   # mureta com ameias baixas
	_peca(st, pedra, Vector3.ZERO)
	_colisor_caixa(Vector3((x_ponte0 + x_ponte1) * 0.5, y - 0.2, c.y), Vector3(16.0, 0.6, x_ponte1 - x_ponte0), PI * 0.5)
	var x_est := [c.x - RR - 12.0, c.x - RR - 26.0]
	var tipos := [["martelo", "cajado"], ["arco", "espada"]]
	for i in 2:
		for j in 2:
			var lado := -1.0 if j == 0 else 1.0
			var sp := Vector2(x_est[i], c.y + lado * 12.0)
			var olha := Vector2(sp.x - 10.0, c.y)
			_estatua(sp, atan2(olha.x - sp.x, olha.y - sp.y), tipos[i][j], y)
			_poste_em(Vector2(sp.x - 6.0, c.y + lado * 7.0), Vector2(sp.x - 6.0, c.y))
	# ---- castelo (norte) com escadaria, portão entre torres e estandartes
	var cas := c + Vector2(0, -RR + 52.0)
	estabulo_pos = Regiao.ESTABULO; taverna_pos = c + Vector2(-180.0, 34.0)   # antes das casas
	st = _st()
	_caixa(st, Vector3(cas.x, y + 9.0, cas.y), Vector3(64.0, 20.0, 40.0))
	_caixa(st, Vector3(cas.x, y + 18.0, cas.y - 6.0), Vector3(24.0, 36.0, 22.0))
	for q in [Vector2(-32, -20), Vector2(32, -20), Vector2(-32, 20), Vector2(32, 20), Vector2(-9, 24), Vector2(9, 24)]:
		cilindro(st, Vector3(cas.x + q.x, y - 1.0, cas.y + q.y), 6.0 if absf(q.x) > 20.0 else 4.5, 5.5 if absf(q.x) > 20.0 else 4.2, 30.0 if absf(q.x) > 20.0 else 24.0, 8, true)
	for k in 8: _caixa(st, Vector3(cas.x, y + 0.25 + k * 0.5, cas.y + 40.0 - k * 1.6), Vector3(18.0 - k * 0.6, 0.5, 1.7))   # escadaria
	_peca(st, pedra, Vector3.ZERO)
	st = _st(); _quad(st, Vector3(cas.x - 4.0, y + 4.0, cas.y + 20.2), Vector3(cas.x + 4.0, y + 4.0, cas.y + 20.2), Vector3(cas.x + 4.0, y + 11.0, cas.y + 20.2), Vector3(cas.x - 4.0, y + 11.0, cas.y + 20.2), 1, 1)
	_peca(st, mat("", 1.0, Color(0.05, 0.05, 0.07)), Vector3.ZERO)                     # porta escura
	st = _st()
	for q in [Vector2(-32, -20), Vector2(32, -20), Vector2(-32, 20), Vector2(32, 20), Vector2(-9, 24), Vector2(9, 24)]:
		var big := absf(q.x) > 20.0
		cilindro(st, Vector3(cas.x + q.x, y + (29.0 if big else 23.0), cas.y + q.y), 7.0 if big else 5.4, 0.0, 12.0 if big else 9.0, 8)
	cilindro(st, Vector3(cas.x, y + 36.0, cas.y - 6.0), 16.0, 0.0, 12.0, 4)
	_peca(st, azul, Vector3.ZERO)
	st = _st()
	for bx2 in [-15.0, 15.0]:                                  # estandartes azuis
		_quad(st, Vector3(cas.x + bx2 - 2.0, y + 6.0, cas.y + 20.3), Vector3(cas.x + bx2 + 2.0, y + 6.0, cas.y + 20.3), Vector3(cas.x + bx2 + 2.0, y + 16.0, cas.y + 20.3), Vector3(cas.x + bx2 - 2.0, y + 16.0, cas.y + 20.3), 1, 1)
	_peca(st, mat("", 1.0, Color(0.18, 0.28, 0.7)), Vector3.ZERO)
	st = _st()
	for bx2 in [-15.0, 15.0]: _caixa(st, Vector3(cas.x + bx2, y + 12.0, cas.y + 20.4), Vector3(1.6, 3.0, 0.1))
	_peca(st, mat("", 1.0, Color(0.95, 0.85, 0.4)), Vector3.ZERO)                     # emblema dourado
	_colisor_caixa(Vector3(cas.x, y - 1.0, cas.y), Vector3(66.0, 38.0, 42.0), 0.0)
	# ---- catedral (noroeste) com praça aberta e flecha alta
	var cat: Vector2 = c + dirv.call(-PI * 0.83) * 155.0
	var ang_cat := atan2(c.x - cat.x, c.y - cat.y)
	_casa(Vector3(cat.x, y, cat.y), ang_cat, 20.0, 38.0, 15.0, pedra, azul, true)
	var tc: Vector2 = cat - (c - cat).normalized() * 21.0
	st = _st(); cilindro(st, Vector3(tc.x, y - 1.0, tc.y), 5.0, 4.4, 34.0, 8, true); _peca(st, pedra, Vector3.ZERO)
	st = _st(); cilindro(st, Vector3(tc.x, y + 33.0, tc.y), 5.4, 0.0, 26.0, 8); _peca(st, azul, Vector3.ZERO)
	_colisor_cilindro(Vector3(tc.x, y - 1.0, tc.y), 5.0, 34.0)
	var dc := (c - cat).normalized()
	_freira("Irmã Odília", cat + dc * 22.5, dc, y, 4343)                       # na escadaria da catedral
	# ---- torre dos magos (sudoeste)
	var tm: Vector2 = c + dirv.call(PI * 0.78) * 168.0
	st = _st(); cilindro(st, Vector3(tm.x, y - 1.0, tm.y), 7.0, 6.0, 42.0, 10, true); cilindro(st, Vector3(tm.x, y + 40.0, tm.y), 8.0, 8.0, 1.5, 10, true)
	_peca(st, mat("pedra", 1.0, Color(0.95, 0.9, 1.05)), Vector3.ZERO)
	st = _st(); cilindro(st, Vector3(tm.x, y + 41.5, tm.y), 8.5, 0.0, 16.0, 10); _peca(st, mat("telha", 1.4, Color(0.95, 0.6, 1.0)), Vector3.ZERO)
	_colisor_cilindro(Vector3(tm.x, y - 1.0, tm.y), 7.0, 42.0)
	_particulas_magia(Vector3(tm.x, y + 58.0, tm.y))
	# ---- praça central com chafariz de três andares
	st = _st()
	cilindro(st, Vector3(c.x, y - 0.3, c.y), 11.0, 11.0, 1.1, 16, true)
	cilindro(st, Vector3(c.x, y, c.y), 1.6, 1.4, 3.2, 8, true)
	cilindro(st, Vector3(c.x, y + 3.0, c.y), 5.2, 5.2, 0.6, 12, true)
	cilindro(st, Vector3(c.x, y + 3.6, c.y), 0.9, 0.8, 2.6, 8, true)
	cilindro(st, Vector3(c.x, y + 6.2, c.y), 2.6, 2.6, 0.5, 10, true)
	cilindro(st, Vector3(c.x, y + 6.7, c.y), 0.5, 0.2, 1.6, 6, true)
	_peca(st, pedra, Vector3.ZERO)
	_colisor_cilindro(Vector3(c.x, y - 0.3, c.y), 11.0, 1.4)
	st = _st()
	for disco in [[10.4, y + 0.65], [4.8, y + 3.55], [2.3, y + 6.65]]:
		var rd: float = disco[0]; var yd: float = disco[1]
		for k in 16:
			var a0 := TAU * k / 16.0; var a1 := TAU * (k + 1) / 16.0
			_tri(st, Vector3(c.x, yd, c.y), Vector3(c.x + cos(a1) * rd, yd, c.y + sin(a1) * rd), Vector3(c.x + cos(a0) * rd, yd, c.y + sin(a0) * rd), 1, 1)
	var agua_ch := MeshInstance3D.new(); agua_ch.mesh = st.commit(); agua_ch.material_override = agua_m; raiz.add_child(agua_ch)
	_jatos_chafariz(Vector3(c.x, y + 7.8, c.y))
	# ---- canal em anel: água, mureta com ameias baixas e quatro pontes
	st = _st(); var st_m := _st()
	var nc := 72
	for k in nc:
		var a0 := TAU * k / nc; var a1 := TAU * (k + 1) / nc
		var d0: Vector2 = dirv.call(a0); var d1: Vector2 = dirv.call(a1)
		var ri := Regiao.CANAL - 5.0; var re := Regiao.CANAL + 5.0; var ya := y - 0.6
		_quad(st, Vector3(c.x + d0.x * ri, ya, c.y + d0.y * ri), Vector3(c.x + d1.x * ri, ya, c.y + d1.y * ri), Vector3(c.x + d1.x * re, ya, c.y + d1.y * re), Vector3(c.x + d0.x * re, ya, c.y + d0.y * re), 1, 1)
		var am := (a0 + a1) * 0.5
		var na_rua := false
		for ra in [0.0, PI * 0.5, PI, -PI * 0.5]: if absf(wrapf(am - ra, -PI, PI)) * Regiao.CANAL < 9.0: na_rua = true
		if na_rua: continue
		for rb in [ri - 0.6, re + 0.6]:
			var meio: Vector2 = c + dirv.call(am) * rb
			var mb := _st(); _caixa(mb, Vector3(0, 0.3, 0), Vector3(1.0, 0.8 if k % 2 == 0 else 1.3, TAU * rb / nc + 0.3))
			st_m.append_from(mb.commit(), 0, Transform3D(Basis(Vector3.UP, -am), Vector3(meio.x, y, meio.y)))
	var canal := MeshInstance3D.new(); canal.mesh = st.commit(); canal.material_override = agua_m; raiz.add_child(canal)
	_peca(st_m, pedra, Vector3.ZERO)
	st = _st()
	for ra in [PI, PI * 0.5, 0.0, -PI * 0.5]:
		var pc: Vector2 = c + dirv.call(ra) * Regiao.CANAL
		var ponte := _st(); _caixa(ponte, Vector3(0, 0, 0), Vector3(16.0, 0.6, 10.0))
		for lz in [-4.8, 4.8]:
			for xx in 5: _caixa(ponte, Vector3(-6.4 + xx * 3.2, 0.75, lz), Vector3(3.2, 0.9 if xx % 2 == 0 else 0.6, 0.5))
		st.append_from(ponte.commit(), 0, Transform3D(Basis(Vector3.UP, -ra), Vector3(pc.x, y + 0.05, pc.y)))
	_peca(st, pedra, Vector3.ZERO)
	# ---- casas por bairro, em pares de anéis com uma rua entre eles (portas viradas para essa rua)
	var parede_clara := mat("parede", 1.0, Color(1.1, 1.08, 1.02))
	var estilos := {
		"comercio": [[parede_clara, mat("parede"), pedra], [azul, azul, mat("telha", 1.4, Color(0.9, 0.95, 1.0))]],
		"portao": [[parede_clara, pedra], [azul, mat("telha", 1.4, Color(0.9, 0.95, 1.0))]],
		"velho": [[mat("parede", 1.0, Color(0.95, 0.85, 0.75)), mat("pedra", 1.0, Color(0.9, 0.8, 0.7))], [mat("madeira", 1.0, Color(0.6, 0.3, 0.2)), mat("madeira", 1.0, Color(0.5, 0.25, 0.18))]],
		"magos": [[mat("parede", 1.0, Color(1.0, 0.95, 1.05)), mat("pedra", 1.0, Color(0.95, 0.9, 1.05))], [mat("telha", 1.4, Color(0.95, 0.6, 1.0)), mat("telha", 1.4, Color(0.85, 0.55, 0.95))]],
		"porto": [[mat("madeira", 1.0, Color(0.8, 0.7, 0.6)), pedra_esc], [mat("madeira", 1.0, Color(0.4, 0.42, 0.5))]],
		"catedral": [[pedra, parede_clara], [azul]],
	}
	var placas := ["banco", "taverna", "estalagem", "armas", "armaduras", "alquimia", "alfaiate", "joalheiro", "ferreiro"]
	var n_placa := 0
	var feitas := 0
	# [raio, porta para dentro?]
	var aneis := [[36.0, true], [56.0, false], [72.0, true], [114.0, false], [130.0, true], [150.0, false], [166.0, true], [186.0, false], [202.0, true]]
	for anel in aneis:
		var r: float = anel[0]; var dentro: bool = anel[1]
		var a := rng.randf() * 0.2
		while a < TAU:
			var q0: Vector2 = c + dirv.call(a) * r
			var bairro := Regiao.distrito(q0.x, q0.y)
			var grande := bairro == "porto"
			var w := rng.randf_range(14.0, 18.0) if grande else rng.randf_range(8.0, 11.5)
			var d := rng.randf_range(10.0, 12.0) if grande else rng.randf_range(7.0, 9.0)
			var hh := rng.randf_range(6.0, 8.0) if grande else rng.randf_range(5.5, 9.5)
			if bairro == "velho": w *= 0.85; d *= 0.9
			var passo := (w + rng.randf_range(2.0, 4.5)) / r
			var am := a + passo * 0.5; a += passo
			var q: Vector2 = c + dirv.call(am) * r
			bairro = Regiao.distrito(q.x, q.y)
			if not estilos.has(bairro): continue
			if Regiao.rua_cidade(q.x, q.y) < 9.5 + w * 0.5: continue
			if q.distance_to(cas) < 50.0 or q.distance_to(cat) < 46.0 or q.distance_to(tc) < 12.0 or q.distance_to(tm) < 22.0: continue
			if q.distance_to(taverna_pos) < 22.0: continue
			if bairro == "catedral": continue
			var ang := atan2(c.x - q.x, c.y - q.y) + (0.0 if dentro else PI)
			var est: Array = estilos[bairro]
			var par: Material = est[0][rng.randi() % est[0].size()]; var tel: Material = est[1][rng.randi() % est[1].size()]
			_casa(Vector3(q.x, y, q.y), ang, w, d, hh, par, tel, true)
			feitas += 1
			# lojas: as casas viradas para a praça (anel de dentro) e algumas nas ruas principais ganham placa
			if (r < 40.0 or (bairro == "comercio" and Regiao.rua_cidade(q.x, q.y) < 18.0 + w * 0.5)) and n_placa < 30:
				var nome: String = placas[n_placa % placas.size()]; n_placa += 1
				_placa(Vector3(q.x, y, q.y), ang, w, d, hh, nome)
				var frente := Vector2(sin(ang), cos(ang))
				cidade_lojas.append([nome, q + frente * (d * 0.5 + 1.5)])
			if grande:                                         # caixotes e barris na frente dos armazéns
				var fr := Vector2(sin(ang), cos(ang)); var ld := Vector2(fr.y, -fr.x)
				var cx := _st()
				for b in 3: _caixa(cx, Vector3(q.x + fr.x * (d * 0.5 + 2.0) + ld.x * (b - 1) * 2.2, y + 0.6, q.y + fr.y * (d * 0.5 + 2.0) + ld.y * (b - 1) * 2.2), Vector3(1.2, 1.2, 1.2))
				_peca(cx, mat("madeira"), Vector3.ZERO)
	_estabulo_e_taverna(c, y)
	# ---- parque: árvores, lago e bancos
	var lp: Vector2 = Regiao.LAGO_PARQUE
	st = _st()
	for k in 24:
		var a0 := TAU * k / 24.0; var a1 := TAU * (k + 1) / 24.0
		_tri(st, Vector3(lp.x, y - 1.0, lp.y), Vector3(lp.x + cos(a1) * 15.5, y - 1.0, lp.y + sin(a1) * 15.5), Vector3(lp.x + cos(a0) * 15.5, y - 1.0, lp.y + sin(a0) * 15.5), 1, 1)
	var lago_p := MeshInstance3D.new(); lago_p.mesh = st.commit(); lago_p.material_override = agua_m; raiz.add_child(lago_p)
	for i in 60:
		var a := rng.randf_range(PI * 0.32, PI * 0.6); var r := rng.randf_range(112.0, 218.0)
		var q: Vector2 = c + dirv.call(a) * r
		if q.distance_to(lp) < 20.0 or Regiao.rua_cidade(q.x, q.y) < 10.0: continue
		var ok := true
		for t in arvores_cidade: if Vector2(t[0].x, t[0].z).distance_to(q) < 9.0: ok = false
		if not ok: continue
		arvores_cidade.append([Vector3(q.x, y - 0.2, q.y), rng.randf_range(0.8, 1.2)])
		_colisor_cilindro(Vector3(q.x, y, q.y), 0.35, 4.0)
	# árvores também ao longo das ruas principais (nos dois lados), entre os postes
	for ra in [PI, PI * 0.5, 0.0, -PI * 0.5]:
		var dr: Vector2 = dirv.call(ra); var nr := Vector2(-dr.y, dr.x)
		for dist in [44.0, 82.0, 140.0, 190.0]:
			if ra == -PI * 0.5 and dist > 130.0: continue
			for lado in [-1.0, 1.0]:
				var q: Vector2 = c + dr * dist + nr * lado * 10.5
				arvores_cidade.append([Vector3(q.x, y - 0.2, q.y), 0.7])
				_colisor_cilindro(Vector3(q.x, y, q.y), 0.3, 4.0)
	# ---- cais do porto do lado de fora do portão leste
	var cais0 := c + Vector2(RR + 4.0, 0)
	while cais0.x < Regiao.X1 - 60.0 and altura(cais0.x, c.y) > 1.9: cais0.x += 2.0
	cais0.x -= 6.0
	var xm := cais0.x + 20.0
	while xm < Regiao.X1 - 60.0 and altura(xm, c.y) > -2.5: xm += 2.0
	st = _st()
	var yc := 2.1
	for i in int((xm + 30.0 - cais0.x) / 2.0):
		var x := cais0.x + i * 2.0
		for dz in [-6.0, 0.0, 6.0]: _caixa(st, Vector3(x, yc, c.y + dz), Vector3(2.0, 0.25, 6.0))
		if i % 2 == 0:
			for dz in [-8.5, 8.5]: _caixa(st, Vector3(x, yc - 2.5, c.y + dz), Vector3(0.4, 5.0, 0.4))
	for braco in [-40.0, 40.0]:
		for i in 20: _caixa(st, Vector3(xm + 10.0, yc, c.y + braco * float(i) / 20.0), Vector3(6.0, 0.25, 2.2))
	_peca(st, mat("madeira"), Vector3.ZERO)
	_colisor_caixa(Vector3((cais0.x + xm + 30.0) * 0.5, yc - 0.15, c.y), Vector3(18.0, 0.3, xm + 30.0 - cais0.x), PI / 2)
	for nav in [[xm + 26.0, c.y - 24.0], [xm + 26.0, c.y + 26.0]]:
		st = _st()
		_caixa(st, Vector3(0, 0.8, 0), Vector3(18.0, 2.4, 5.0)); _caixa(st, Vector3(-7.0, 2.4, 0), Vector3(4.0, 1.2, 4.6))
		_caixa(st, Vector3(9.5, 1.2, 0), Vector3(2.0, 1.6, 3.0))
		_peca(st, mat("madeira", 1.0, Color(0.6, 0.45, 0.35)), Vector3(nav[0], 0.0, nav[1]))
		st = _st(); _caixa(st, Vector3(0, 9.0, 0), Vector3(0.5, 16.0, 0.5)); _peca(st, mat("madeira"), Vector3(nav[0], 0.0, nav[1]))
		st = _st(); _quad(st, Vector3(0.4, 4.5, -4.0), Vector3(0.4, 4.5, 4.0), Vector3(0.4, 15.0, 3.0), Vector3(0.4, 15.0, -3.0), 1, 1)
		_peca(st, mat("", 1.0, Color(0.3, 0.42, 0.8)), Vector3(nav[0], 0.0, nav[1]))
	# ---- postes de luz ao longo das quatro ruas principais
	for ra in [PI, PI * 0.5, 0.0, -PI * 0.5]:
		var dr: Vector2 = dirv.call(ra); var nr := Vector2(-dr.y, dr.x)
		for dist in [28.0, 62.0, 124.0, 166.0, 208.0]:
			if ra == -PI * 0.5 and dist > 150.0: continue
			for lado in [-1.0, 1.0]:
				var q: Vector2 = c + dr * dist + nr * lado * 8.0
				_poste_em(q, c + dr * dist)
	lugares.append([c, RR + 15.0])
	if args.has("perf"): print("CIDADE: %d casas, %d lojas" % [feitas, cidade_lojas.size()])

# freira que vende poções de vida (modelo do Tripo com o esqueleto dos moradores), parada na frente da igreja,
# orando com as mãos juntas e olhando para a praça
func _freira(nome: String, p: Vector2, olhar: Vector2, y: float, semente: int) -> void:
	var f := Morador.new(); f.profissao = "freira"
	f.posto = p; f.olhar_posto = p + olhar * 5.0
	f.set_meta("nome", nome)
	raiz.add_child(f); f.position = Vector3(p.x, y, p.y)
	f.montar(self, semente, p, 1.0)
	freiras.append(f)

# logo depois do portão oeste: estábulo (telheiro, cocheiras, cercado com três cavalos e o cavalariço) ao norte da
# rua principal e a taverna "O Ferradura Dourada" ao sul
func _estabulo_e_taverna(c: Vector2, y: float) -> void:
	# taverna grande com placa (dentro da cidade, logo depois do portão oeste)
	var t := taverna_pos
	var ang_t := PI                                                        # porta virada para a rua principal (norte)
	_casa(Vector3(t.x, y, t.y), ang_t, 16.0, 11.0, 7.0, mat("parede"), mat("telha", 1.4), true)
	_placa(Vector3(t.x, y, t.y), ang_t, 16.0, 11.0, 7.0, "taverna")
	cidade_lojas.append(["taverna", t + Vector2(0, -7.0)])
	var b := _st()
	for k in 4: _caixa(b, Vector3(t.x - 6.0 + k * 1.1, y + 0.5, t.y - 7.0), Vector3(0.8, 1.0, 0.8))   # barris na porta
	_peca(b, mat("madeira", 1.0, Color(0.7, 0.5, 0.35)), Vector3.ZERO)
	_estabulo()

# estábulo fora da cidade, do outro lado do rio, ao norte da estrada que chega na ponte: a casinha do cavalariço,
# o telheiro com as cocheiras ao lado e o cercado com os três cavalos na frente; o Edric fica parado na frente da casa
func _estabulo() -> void:
	var e := estabulo_pos
	var y := reg.aplanar(e + Vector2(-8.0, 3.0), Vector2(26.0, 14.0), 0.0, 6.0)
	reg.planos[-1].append(false)               # grama em volta da casa e do cercado (só o cercado/telheiro ficam de terra)
	lugares.append([e + Vector2(-8.0, 3.0), 28.0])
	var madeira := mat("madeira"); var tel := mat("telha", 1.4)
	# casinha do cavalariço (à esquerda do telheiro, porta para a estrada)
	var hc := e + Vector2(-25.0, -5.0)
	_casa(Vector3(hc.x, y, hc.y), 0.0, 9.0, 7.0, 3.6, mat("parede"), mat("telha", 1.4), true)
	var lenha := _st()                                                  # lenha empilhada e um banco do lado da casa
	for k in 3: _caixa(lenha, Vector3(hc.x - 5.6, y + 0.25 + k * 0.4, hc.y - 1.0 + (k % 2) * 0.2), Vector3(0.9, 0.38, 2.6))
	_caixa(lenha, Vector3(hc.x + 2.2, y + 0.45, hc.y + 4.4), Vector3(1.8, 0.12, 0.5))
	_caixa(lenha, Vector3(hc.x + 1.5, y + 0.2, hc.y + 4.4), Vector3(0.15, 0.4, 0.45)); _caixa(lenha, Vector3(hc.x + 2.9, y + 0.2, hc.y + 4.4), Vector3(0.15, 0.4, 0.45))
	_peca(lenha, mat("madeira", 1.0, Color(0.75, 0.55, 0.38)), Vector3.ZERO)
	# telheiro aberto com cocheiras
	var st := _st()
	for q in [Vector2(-9, -5), Vector2(9, -5), Vector2(-9, 5), Vector2(9, 5), Vector2(-3, -5), Vector2(3, -5)]:
		_caixa(st, Vector3(e.x + q.x, y + 2.2, e.y + q.y - 6.0), Vector3(0.4, 4.4, 0.4))
	for xx in [-6.0, 0.0, 6.0]: _caixa(st, Vector3(e.x + xx, y + 0.6, e.y - 7.5), Vector3(0.2, 1.2, 6.0))     # divisórias baixas
	_caixa(st, Vector3(e.x, y + 1.2, e.y - 10.8), Vector3(18.0, 2.4, 0.3))                                # parede do fundo
	_peca(st, madeira, Vector3.ZERO)
	st = _st()
	_quad(st, Vector3(e.x - 10.0, y + 4.4, e.y - 0.4), Vector3(e.x + 10.0, y + 4.4, e.y - 0.4), Vector3(e.x + 10.0, y + 5.8, e.y - 11.2), Vector3(e.x - 10.0, y + 5.8, e.y - 11.2), 5, 3)
	_peca(st, tel, Vector3.ZERO)
	st = _st()                                                                                             # fardos de palha e cochos
	for xx in [-6.0, 0.0, 6.0]: _caixa(st, Vector3(e.x + xx + 3.0, y + 0.3, e.y - 9.8), Vector3(2.2, 0.6, 1.0))
	_caixa(st, Vector3(e.x + 11.0, y + 0.45, e.y - 3.0), Vector3(1.4, 0.9, 1.0)); _caixa(st, Vector3(e.x + 11.2, y + 1.3, e.y - 3.1), Vector3(1.4, 0.8, 1.0))
	_peca(st, mat("palha"), Vector3.ZERO)
	_colisor_caixa(Vector3(e.x, y, e.y - 10.8), Vector3(18.0, 3.0, 0.4), 0.0)
	# chão de terra batida debaixo do telheiro e no cercado (antes era o terreno liso)
	_chao_textura(Rect2(e.x - 10.6, e.y - 11.6, 21.2, 11.4), mat("terra", 0.5))      # telheiro
	_chao_textura(Rect2(e.x - 12.2, e.y + 0.8, 24.4, 14.4), mat("terra", 0.5))       # cercado
	# cercado na frente do telheiro (aberto do lado da casa, para entrar)
	var cerca := _st()
	var cx0 := e.x - 12.0; var cx1 := e.x + 12.0; var cz0 := e.y + 1.0; var cz1 := e.y + 15.0
	for seg in [[Vector2(cx0, cz0 + 5.0), Vector2(cx0, cz1)], [Vector2(cx0, cz1), Vector2(cx1, cz1)], [Vector2(cx1, cz1), Vector2(cx1, cz0)]]:
		var a: Vector2 = seg[0]; var bb: Vector2 = seg[1]; var n := int(a.distance_to(bb) / 3.0)
		for i in n + 1:
			var p := a.lerp(bb, float(i) / n); _caixa(cerca, Vector3(p.x, y + 0.6, p.y), Vector3(0.25, 1.2, 0.25))
		var m2 := (a + bb) * 0.5; var comp := a.distance_to(bb); var ang := atan2(bb.x - a.x, bb.y - a.y)
		for hh in [0.5, 1.0]:
			var tr := _st(); _caixa(tr, Vector3(0, 0, 0), Vector3(0.12, 0.14, comp))
			cerca.append_from(tr.commit(), 0, Transform3D(Basis(Vector3.UP, ang), Vector3(m2.x, y + hh, m2.y)))
		_colisor_caixa(Vector3(m2.x, y, m2.y), Vector3(0.3, 1.3, comp), ang)
	_peca(cerca, madeira, Vector3.ZERO)
	# três cavalos no cercado (o modelo provisório de blocos)
	var cores := ["cavalo_branco", "cavalo_marrom", "cavalo_preto", "cavalo_dourado"]
	for i in 4:
		var cv := cavalo(cores[i]); raiz.add_child(cv)
		cv.position = Vector3(e.x - 7.0 + i * 5.5, y, e.y + 7.5 + (i % 2) * 3.0); cv.rotation.y = 0.5 - i * 0.45
		_colisor_caixa(Vector3(cv.position.x, y, cv.position.z), Vector3(1.0, 1.8, 2.6), cv.rotation.y)
	# o cavalariço: parado na frente da casa, do lado do estábulo, olhando para a estrada
	var npc := Morador.new(); npc.tipo = "forte"; npc.profissao = "cavalarico"
	npc.posto = hc + Vector2(5.5, 6.0); npc.olhar_posto = npc.posto + Vector2(0.6, 5.0)
	raiz.add_child(npc); npc.position = Vector3(npc.posto.x, y, npc.posto.y)
	npc.montar(self, 4242, npc.posto, 1.0)
	estabulo_npc = npc
	# placa do estábulo (ferradura) num poste, na quina do cercado virada para a estrada
	var pp := e + Vector2(13.5, 16.0)
	var pst := _st(); _caixa(pst, Vector3(pp.x, y + 1.6, pp.y), Vector3(0.25, 3.2, 0.25)); _peca(pst, madeira, Vector3.ZERO)
	_placa(Vector3(pp.x - 0.3, y - 0.4, pp.y), PI * 0.5, 0.6, 0.6, 4.6, "estabulo")

# cavalo provisório feito de blocos (frente = -Z), na cor da montaria; patas, cabeça e cauda em nós próprios para animar
const MODELOS_CAVALO := {"cavalo_branco": "cavalo_branco", "cavalo_marrom": "cavalo_vermelho", "cavalo_preto": "cavalo_preto", "cavalo_dourado": "cavalo_dourado"}
func cavalo(id: String) -> Node3D:
	var arq := "res://assets/modelos/%s.glb" % MODELOS_CAVALO.get(id, "")
	if ResourceLoader.exists(arq):
		# modelo do Tripo (sem rig ainda): vem de cabeça para +X, ~1 m de comprimento → gira para -Z e escala para 2,6 m
		var rc := Node3D.new(); rc.name = "Cavalo"
		var mod := modelo_ps1(arq); mod.name = "Modelo"
		RigCavalo.montar(mod, arq)                       # esqueleto automático: patas, pescoço e rabo
		var k := 2.6 / 0.97
		var ymin := 0.0
		for n in mod.find_children("*", "MeshInstance3D", true, false): ymin = minf(ymin, (n as MeshInstance3D).get_aabb().position.y)
		mod.scale = Vector3(k, k, k); mod.rotation_degrees.y = 90.0; mod.position.y = -ymin * k
		rc.add_child(mod)
		rc.set_meta("sela_z", 0.1 * k + 0.35)          # a sela fica ~0,27 m atrás do meio do modelo (+ a Rachel no fundo da sela)
		var an := Node.new(); an.set_script(load("res://scripts/cavalo_anim.gd")); rc.add_child(an)
		return rc
	var info: Dictionary = Bolsa.ITENS[id]
	var cor_m := mat("", 1.0, info.cor); var crina := mat("", 1.0, info.crina); var casco := mat("", 1.0, Color(0.15, 0.12, 0.1))
	var sela := mat("", 1.0, Color(0.42, 0.24, 0.12))
	var raizc := Node3D.new(); raizc.name = "Cavalo"
	var corpo := MeshInstance3D.new(); var st := _st()
	_caixa(st, Vector3(0, 1.35, 0), Vector3(0.75, 0.8, 2.0))
	st.set_material(cor_m); var mesh := st.commit()
	st = _st(); _caixa(st, Vector3(0, 1.78, 0.1), Vector3(0.8, 0.1, 0.8)); _caixa(st, Vector3(0, 1.3, 0.1), Vector3(0.82, 0.8, 0.5)); st.set_material(sela); st.commit(mesh)
	corpo.mesh = mesh; raizc.add_child(corpo)
	var pescoco := Node3D.new(); pescoco.name = "Pescoco"; pescoco.position = Vector3(0, 1.6, -0.85); raizc.add_child(pescoco)
	var mp := MeshInstance3D.new(); st = _st()
	_caixa(st, Vector3(0, 0.35, -0.25), Vector3(0.42, 0.95, 0.5))                  # pescoço
	_caixa(st, Vector3(0, 0.75, -0.65), Vector3(0.36, 0.38, 0.8))                  # cabeça
	_caixa(st, Vector3(-0.12, 1.0, -0.38), Vector3(0.08, 0.2, 0.08)); _caixa(st, Vector3(0.12, 1.0, -0.38), Vector3(0.08, 0.2, 0.08))   # orelhas
	st.set_material(cor_m); var mesh_p := st.commit()
	st = _st(); _caixa(st, Vector3(0, 0.6, -0.05), Vector3(0.12, 1.0, 0.25)); st.set_material(crina); st.commit(mesh_p)    # crina
	st = _st(); _caixa(st, Vector3(0, 0.7, -0.75), Vector3(0.4, 0.06, 0.4)); st.set_material(sela); st.commit(mesh_p)      # cabresto
	mp.mesh = mesh_p; pescoco.add_child(mp)
	for i in 4:
		var perna := Node3D.new(); perna.name = "Perna%d" % i
		perna.position = Vector3(-0.25 if i % 2 == 0 else 0.25, 1.05, -0.75 if i < 2 else 0.75); raizc.add_child(perna)
		var ml := MeshInstance3D.new(); st = _st(); _caixa(st, Vector3(0, -0.5, 0), Vector3(0.18, 1.0, 0.2)); st.set_material(cor_m); var mesh_l := st.commit()
		st = _st(); _caixa(st, Vector3(0, -1.0, 0), Vector3(0.2, 0.12, 0.24)); st.set_material(casco); st.commit(mesh_l)
		ml.mesh = mesh_l; perna.add_child(ml)
	var cauda := Node3D.new(); cauda.name = "Cauda"; cauda.position = Vector3(0, 1.6, 1.0); raizc.add_child(cauda)
	var mc := MeshInstance3D.new(); st = _st(); _caixa(st, Vector3(0, -0.4, 0.12), Vector3(0.16, 0.9, 0.16)); st.set_material(crina); mc.mesh = st.commit(); cauda.add_child(mc)
	var s := Node.new(); s.set_script(load("res://scripts/cavalo_anim.gd")); raizc.add_child(s)
	return raizc

# placa de loja pendurada numa trave saindo da fachada (desenho em assets/ui/placas/<nome>.png)
func _placa(pos: Vector3, ang: float, w: float, d: float, h: float, nome: String) -> void:
	var b := Basis(Vector3.UP, ang)
	var base := pos + b * Vector3(w * 0.32, minf(h - 0.6, 3.6), d * 0.5)
	var st := _st()
	_caixa(st, Vector3(0, 0, 0.9), Vector3(0.22, 0.22, 1.8))                 # trave
	_caixa(st, Vector3(0, -0.35, 1.5), Vector3(0.06, 0.5, 0.06))             # correntinha
	var mi := _peca(st, mat("madeira", 1.0, Color(0.45, 0.32, 0.22)), base); mi.rotation.y = ang
	st = _st()
	for lado in [-1.0, 1.0]:                                                 # a placa: desenho dos dois lados
		var xx: float = 0.04 * lado
		_quad(st, Vector3(xx, -2.0, 0.85), Vector3(xx, -2.0, 2.15), Vector3(xx, -0.6, 2.15), Vector3(xx, -0.6, 0.85), 1, 1)
	var pl := _peca(st, _mat_tex("res://assets/ui/placas/%s.png" % nome), base); pl.rotation.y = ang

# estátua de herói (de pedra, sobre pedestal): martelo, cajado, arco ou espada
func _estatua(p: Vector2, ang: float, tipo: String, y: float) -> void:
	var st := _st()
	_caixa(st, Vector3(0, 1.5, 0), Vector3(6.5, 3.0, 6.5)); _caixa(st, Vector3(0, 3.4, 0), Vector3(5.4, 0.8, 5.4))
	if tipo == "cajado":
		cilindro(st, Vector3(0, 3.8, 0), 2.3, 1.5, 6.4, 8, true)              # manto
	else:
		_caixa(st, Vector3(-0.95, 6.0, 0), Vector3(1.4, 4.4, 1.6)); _caixa(st, Vector3(0.95, 6.0, 0), Vector3(1.4, 4.4, 1.6))
	_caixa(st, Vector3(0, 9.6, 0), Vector3(3.8, 3.6, 2.3))                     # tronco
	_caixa(st, Vector3(-2.3, 10.9, 0), Vector3(1.6, 1.3, 2.0)); _caixa(st, Vector3(2.3, 10.9, 0), Vector3(1.6, 1.3, 2.0))   # ombreiras
	_caixa(st, Vector3(0, 12.3, 0), Vector3(1.5, 1.8, 1.6))                    # cabeça
	match tipo:
		"martelo":
			_caixa(st, Vector3(2.5, 12.6, 0), Vector3(1.0, 3.4, 1.0)); _caixa(st, Vector3(-2.4, 8.6, 0.3), Vector3(1.0, 3.0, 1.0))
			_caixa(st, Vector3(2.5, 15.4, 0), Vector3(0.4, 4.4, 0.4)); _caixa(st, Vector3(2.5, 17.6, 0), Vector3(2.6, 1.6, 1.6))
		"cajado":
			_caixa(st, Vector3(2.4, 9.8, 0.6), Vector3(0.9, 2.8, 0.9)); _caixa(st, Vector3(-2.3, 9.6, 0.4), Vector3(0.9, 2.8, 0.9))
			_caixa(st, Vector3(2.6, 10.5, 1.1), Vector3(0.4, 13.0, 0.4)); _caixa(st, Vector3(2.6, 17.4, 1.1), Vector3(1.2, 1.2, 1.2))
		"arco":
			_caixa(st, Vector3(-1.9, 10.9, 1.6), Vector3(0.9, 0.9, 3.0)); _caixa(st, Vector3(1.6, 10.6, 0.6), Vector3(0.9, 0.9, 2.2))
			for k in 5: _caixa(st, Vector3(-1.9, 8.6 + k * 1.15, 3.2 + absf(k - 2) * -0.35), Vector3(0.3, 1.25, 0.3))
		_:
			_caixa(st, Vector3(-1.2, 8.9, 1.1), Vector3(0.9, 2.8, 0.9)); _caixa(st, Vector3(1.2, 8.9, 1.1), Vector3(0.9, 2.8, 0.9))
			_caixa(st, Vector3(0, 5.8, 1.8), Vector3(0.6, 6.4, 0.3)); _caixa(st, Vector3(0, 9.2, 1.8), Vector3(2.4, 0.45, 0.45))
	_peca(st, mat("pedra", 1.0, Color(1.05, 1.05, 1.1)), Vector3(p.x, y, p.y), ang)
	_colisor_caixa(Vector3(p.x, y, p.y), Vector3(6.5, 12.0, 6.5), ang)

# água caindo do chafariz
func _jatos_chafariz(pos: Vector3) -> void:
	var p := CPUParticles3D.new(); p.position = pos; p.amount = 70; p.lifetime = 1.3; p.preprocess = 2.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; p.emission_sphere_radius = 0.3
	p.direction = Vector3(0, 1, 0); p.spread = 35.0; p.initial_velocity_min = 2.5; p.initial_velocity_max = 3.5; p.gravity = Vector3(0, -9.0, 0)
	var q := QuadMesh.new(); q.size = Vector2(0.12, 0.12)
	var mt := StandardMaterial3D.new(); mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mt.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mt.albedo_color = Color(0.75, 0.88, 1.0); q.material = mt; p.mesh = q
	p.visibility_aabb = AABB(Vector3(-6, -9, -6), Vector3(12, 14, 12)); raiz.add_child(p)

# brilho roxo girando no alto da torre dos magos
func _particulas_magia(pos: Vector3) -> void:
	var p := CPUParticles3D.new(); p.position = pos; p.amount = 40; p.lifetime = 2.5; p.preprocess = 3.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING; p.emission_ring_axis = Vector3.UP; p.emission_ring_radius = 3.0; p.emission_ring_inner_radius = 2.0; p.emission_ring_height = 0.5
	p.direction = Vector3(0, 1, 0); p.spread = 20.0; p.initial_velocity_min = 0.4; p.initial_velocity_max = 1.0; p.gravity = Vector3.ZERO
	p.orbit_velocity_min = 0.15; p.orbit_velocity_max = 0.25
	var q := QuadMesh.new(); q.size = Vector2(0.4, 0.4)
	var mt := StandardMaterial3D.new(); mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mt.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mt.albedo_color = Color(0.85, 0.5, 1.0); q.material = mt; p.mesh = q
	p.visibility_aabb = AABB(Vector3(-8, -4, -8), Vector3(16, 12, 16)); raiz.add_child(p)

# faixa de água seguindo uma linha de rio (nível e largura por posição ao longo dele)
func _faixa_rio(linha: PackedVector2Array, largura: Callable, nivel: Callable, am: Material) -> void:
	var st := _st(); var pts := []
	for i in linha.size() - 1:
		var a: Vector2 = linha[i]; var b: Vector2 = linha[i + 1]
		var n := int(ceil(a.distance_to(b) / 3.0))
		for k in n: pts.append(a.lerp(b, float(k) / n))
	pts.append(linha[linha.size() - 1])
	var tot := 0.0; var ts := [0.0]
	for i in range(1, pts.size()): tot += pts[i].distance_to(pts[i - 1]); ts.append(tot)
	var ant_l := Vector3.ZERO; var ant_r := Vector3.ZERO
	for i in pts.size():
		var t: float = ts[i] / tot
		var d: Vector2 = (pts[min(i + 1, pts.size() - 1)] - pts[max(i - 1, 0)]).normalized()
		var nrm: Vector2 = Vector2(-d.y, d.x) * (float(largura.call(t)) * 0.5 + 1.0)
		var yy: float = nivel.call(t) - 0.12
		var l := Vector3(pts[i].x + nrm.x, yy, pts[i].y + nrm.y); var r := Vector3(pts[i].x - nrm.x, yy, pts[i].y - nrm.y)
		if i > 0: _quad(st, ant_l, ant_r, r, l, 1, 1)
		ant_l = l; ant_r = r
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
	_cidade()
	_estatuas_guardia()
	_barracas()
	_postes()

# Estátuas da Guardiã: onde a Rachel desperta quando morre (a mais perto de onde caiu). Espalhadas em pontos
# marcantes, sem encher o mapa: vila, meio da Estrada Real, praça de Altamar e perto dos lugares mais perigosos
# ou afastados (porto, moinho, torre em ruínas, acampamento de bandidos, caverna, desfiladeiro, lago, leste).
func _estatuas_guardia() -> void:
	var c := Regiao.CIDADE_C
	var lago := Vector2(Regiao.LAGO.x, Regiao.LAGO.y)
	var bandidos := Regiao.W(Vector2(-330, 300)); var ruinas := Regiao.W(Vector2(220, -260)); var moinho := Regiao.W(Vector2(-244, 100))
	var desf := Vector2(0, -Regiao.Ws(468.0))
	var pontos := [
		[Vector2(16, 62), Vector2(-4, 48)],                                   # entrada sul da vila
		[Vector2(850, -285), Vector2(840, -310)],                             # meio da Estrada Real
		[c + Vector2(-20, 13), c + Vector2(-20, 0)],                          # praça de Altamar
		[porto_pos + Vector2(-30, -18), porto_pos],                           # Porto dos Pescadores
		[moinho + Vector2(26, -20), moinho],                                  # Moinho
		[ruinas + Vector2(-40, 30), ruinas],                                  # Torre em Ruínas (e a serraria perto)
		[bandidos + bandidos.direction_to(Vector2.ZERO) * 70.0, bandidos],    # antes do Acampamento de Bandidos
		[caverna_pos + caverna_pos.direction_to(Vector2.ZERO) * 40.0, caverna_pos],   # Caverna do Oeste
		[desf + Vector2(30, 45), desf],                                       # Desfiladeiro do Norte
		[lago + lago.direction_to(Vector2.ZERO) * (Regiao.LAGO.z + 22.0), lago],      # margem do lago do mosteiro
		[Vector2(1350, 260), Vector2(1350, 200)],                             # terras do leste (sul)
		[Vector2(1250, -880), Vector2(1250, -820)],                           # terras do leste (norte)
	]
	for par in pontos:
		var alvo: Vector2 = par[0]; var frente_para: Vector2 = par[1]
		var p := alvo
		for t in 80:                                      # procura um lugar livre e seco perto do escolhido
			var a := t * 2.4; var q := alvo + Vector2(cos(a), sin(a)) * (t * 0.8)
			if not reg.dentro(q.x, q.y): continue
			if reg.folga_caminho(q.x, q.y) > 3.0 and not perto_de_casa(q.x, q.y, 3.5) and reg.agua(q.x, q.y) == 0.0 \
					and reg.dist_rios(q.x, q.y) > 10.0 and reg.altura(q.x, q.y) > 0.8 and not perto_de_lugar(q.x, q.y, 3.0):
				p = q; break
		var fr := (frente_para - p).normalized()
		if fr == Vector2.ZERO: fr = Vector2(0, 1)
		_estatua_guardia(p, fr)
		estatuas.append([p, fr])

func _estatua_guardia(p: Vector2, fr: Vector2) -> void:
	var ang := atan2(fr.x, fr.y)
	var y := reg.aplanar(p, Vector2(2.4, 2.4), -ang, 3.0)
	lugares.append([p, 5.0])
	var arq := "res://assets/modelos/estatua_guardia.glb"
	if ResourceLoader.exists(arq):
		# modelo do Tripo: ~0,98 de altura, de frente para +X, base em y = -0,49 → 4,5 m, de frente para "fr"
		var mod := modelo_ps1(arq); var k := 4.5 / 0.98
		mod.scale = Vector3(k, k, k); mod.rotation.y = ang - PI / 2.0
		mod.position = Vector3(p.x, y - 0.05 + 0.49 * k, p.y); raiz.add_child(mod)
		_colisor_caixa(Vector3(p.x, y, p.y), Vector3(2.8, 4.0, 2.8), ang)
		luzes.append(Vector3(p.x, y + 1.6, p.y) + Vector3(fr.x, 0, fr.y) * 1.2)     # chama azul do braseiro
		return
	var pedra := mat("pedra", 1.0, Color(1.35, 1.38, 1.32)); var musgo := mat("pedra", 1.0, Color(0.95, 1.1, 0.85))
	var st := _st()
	_caixa(st, Vector3(0, 0.25, 0), Vector3(3.6, 0.5, 3.6)); _caixa(st, Vector3(0, 0.75, 0), Vector3(2.8, 0.5, 2.8))
	_peca(st, musgo, Vector3(p.x, y - 0.05, p.y), ang)
	st = _st()
	cilindro(st, Vector3(0, 1.0, 0), 0.95, 0.42, 2.5, 8, true)                 # manto
	_caixa(st, Vector3(0, 3.65, 0.02), Vector3(0.5, 0.6, 0.5))                  # cabeça
	cilindro(st, Vector3(0, 3.3, -0.05), 0.42, 0.12, 1.0, 6)                   # capuz
	_caixa(st, Vector3(0, 2.85, 0.32), Vector3(0.36, 0.42, 0.26))               # mãos juntas no peito
	for lado in [-1.0, 1.0]:                                                    # asas abertas para trás
		var wg := _st()
		_caixa(wg, Vector3(lado * 0.7, 0.0, 0.0), Vector3(1.4, 2.2, 0.16))
		var tw := Transform3D(Basis(Vector3.UP, lado * 0.55) * Basis(Vector3(0, 0, 1), lado * 0.35), Vector3(lado * 0.3, 3.0, -0.35))
		st.append_from(wg.commit(), 0, tw)
	_peca(st, pedra, Vector3(p.x, y - 0.05, p.y), ang)
	_colisor_caixa(Vector3(p.x, y, p.y), Vector3(3.6, 3.8, 3.6), ang)
	# chama azulada aos pés (de noite ilumina como uma lanterna)
	var fogo := Vector3(p.x, y + 1.2, p.y) + Vector3(fr.x, 0, fr.y) * 1.55
	luzes.append(fogo)

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
	var mp := Regiao.W(Vector2(-244, 100)); var y := reg.aplanar(mp, Vector2(3.6, 3.6), 0.0, 4.0)
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
	var z := 58.0; var xc := Regiao.Ws(380.0)
	while xc < Regiao.X1 - 40.0 and altura(xc, z) > 0.4: xc += 1.0
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
	lugares.append([Vector2(xc - 20.0, z), 45.0]); porto_pos = Vector2(xc - 10.0, z)

func _mosteiro() -> void:
	var c := Vector2(Regiao.ILHA.x, Regiao.ILHA.y); var y := reg.aplanar(c + Vector2(2.5, -1.5), Vector2(8.0, 6.0), 0.0, 3.0)
	_casa(Vector3(c.x, y - 0.3, c.y), PI / 2, 8.0, 6.0, 4.0, mat("pedra"), mat("madeira", 1.0, Color(0.55, 0.5, 0.55)))
	var tp := Vector3(c.x + 5.5, y - 0.6, c.y - 3.0)
	var st := _st(); cilindro(st, Vector3.ZERO, 2.0, 1.8, 11.0, 8, true); _peca(st, mat("pedra"), tp)
	st = _st(); cilindro(st, Vector3(0, 11.0, 0), 2.6, 0.0, 4.0, 8); _peca(st, mat("madeira", 1.0, Color(0.55, 0.5, 0.55)), tp)
	_colisor_cilindro(tp, 2.0, 11.0)
	# passarela da margem até a ilha
	var a := Vector2(Regiao.LAGO.x + Regiao.LAGO.z + 1.0, Regiao.ILHA.y); var b := Vector2(Regiao.ILHA.x + Regiao.ILHA.z - 1.0, Regiao.ILHA.y)
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
	var c := Regiao.W(Vector2(220, -260)); var y := reg.aplanar(c, Vector2(5.0, 5.0), 0.0, 6.0)
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
	var c := Regiao.W(Vector2(286, -170)); var y := reg.aplanar(c, Vector2(14.0, 12.0), 0.0, 5.0)   # a estrada chega na beira do pátio
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
	var c := Regiao.W(Vector2(-330, 300))
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
	_fogo(Vector3(c.x, y0 + 0.1, c.y), 1.1, 1.6, 6)
	luzes.append(Vector3(c.x, y0 + 0.9, c.y))
	st = _st()
	var yc := yb
	for k in 4: _caixa(st, Vector3(c.x + 5 + k * 0.9, yc + 0.3, c.y - 6.0), Vector3(0.8, 1.0, 0.8))
	_peca(st, mat("madeira"), Vector3.ZERO)
	lugares.append([c, 14.0])

func _caverna() -> void:
	# boca de caverna no pé das montanhas a oeste
	var cv := Regiao.W(Vector2(-420, -200)); var z := cv.y; var x := cv.x
	while x > -Regiao.LIM + 40.0 and altura(x, z) < base_vale(z) + 9.0: x -= 2.0
	var y := reg.aplanar(Vector2(x + 7.0, z), Vector2(4.0, 5.0), 0.0, 4.0)
	var st := _st()
	_caixa(st, Vector3(0, 1.4, -3.2), Vector3(3.0, 6.0, 2.0)); _caixa(st, Vector3(0, 1.4, 3.2), Vector3(3.0, 6.0, 2.0))
	_caixa(st, Vector3(0, 5.0, 0), Vector3(3.4, 1.6, 8.6))
	_peca(st, mat("pedra"), Vector3(x + 5.0, y - 0.5, z))
	st = _st(); _quad(st, Vector3(0, 0, 2.2), Vector3(0, 0, -2.2), Vector3(0, 4.3, -2.2), Vector3(0, 4.3, 2.2), 1, 1)
	_peca(st, mat("", 1.0, Color(0.02, 0.02, 0.03)), Vector3(x + 4.6, y - 0.5, z))
	_colisor_caixa(Vector3(x + 4.0, y - 0.5, z), Vector3(2.0, 6.0, 9.0), 0.0)
	lugares.append([Vector2(x + 5.0, z), 8.0]); caverna_pos = Vector2(x + 5.0, z)

func base_vale(z: float) -> float: return reg.base(z)

func _barricada() -> void:
	# paliçada fechando o desfiladeiro do norte (por enquanto não se passa): estacas enterradas 1,5 m na malha
	var z := -Regiao.Ws(468.0)
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

func _casa(pos: Vector3, ang: float, w: float, d: float, h: float, parede: Material = null, telhado: Material = null, chao_fixo := false) -> void:
	var x := w / 2.0; var z := d / 2.0; var cume := h + w * 0.55; var beiral := 0.45
	var livre := _longe_da_estrada(Vector2(pos.x, pos.z), Vector2(x + 0.5, z + 0.5), ang)   # nunca em cima da estrada
	pos.x = livre.x; pos.z = livre.y
	if chao_fixo: pos.y -= 0.05                       # cidade: o chão já é plano (não precisa aplanar)
	else: pos.y = reg.aplanar(Vector2(pos.x, pos.z), Vector2(x + 0.8, z + 0.8), -ang, 4.0) - 0.05
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
func _splats(itens: Array, tam: Vector2, em_pe: bool, balanco: float, ate := 0.0, brilha := false) -> MultiMeshInstance3D:
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
	sm.set_shader_parameter("brilha", brilha)
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
	for it in 120:
		var pior := INF; var ponto := c
		for j in 5: for i in 5:
			var q: Vector2 = c + (Vector2(lerp(-1.0, 1.0, i / 4.0), lerp(-1.0, 1.0, j / 4.0)) * meia).rotated(-ang)
			var dq := reg.folga_caminho(q.x, q.y)
			if dq < pior: pior = dq; ponto = q
		if pior >= folga: return c
		var e := 0.6
		var g := Vector2(reg.folga_caminho(ponto.x + e, ponto.y) - reg.folga_caminho(ponto.x - e, ponto.y),
			reg.folga_caminho(ponto.x, ponto.y + e) - reg.folga_caminho(ponto.x, ponto.y - e))
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
	if args.has("xp"):
		for c in get_children():
			if c is CanvasLayer:
				for h in c.get_children(): if h is Hud: h.ganhar_xp(float(args.xp))
	if args.has("cima"):         # teste: vista de cima (--cima=altura[,x,z])
		var pc := String(args.cima).split(",")
		var cx := float(pc[1]) if pc.size() > 2 else 0.0; var cz := float(pc[2]) if pc.size() > 2 else 0.0
		jogador.set_physics_process(false); jogador.global_position = Vector3(cx, float(pc[0]), cz); jogador.rotation.y = 0
		jogador.pescoco.rotation.x = -PI / 2; jogador.mao.visible = false; set_physics_process(false)
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
	if args.has("hora"): hora = float(args.hora)
	if args.has("barraca") and not barracas.is_empty():
		var b: Vector2 = barracas[int(args.barraca) % barracas.size()]
		var pj := b + Vector2(5.5, 5.5)
		if args.has("frente"): pj = b + (_fogueiras_barraca[int(args.barraca) % barracas.size()] - b) * 2.6
		jogador.global_position = Vector3(pj.x, altura(pj.x, pj.y) + 0.3, pj.y); _ultima = jogador.global_position
		jogador.rotation.y = atan2(-(b - pj).x, -(b - pj).y)
		print("BARRACAS: ", barracas)
	if args.has("descansar"):
		get_tree().create_timer(1.0).timeout.connect(func():
			for c in get_children():
				if c is CanvasLayer:
					for i in c.get_children(): if i is Interacao: i._descansar())
		get_tree().create_timer(4.5).timeout.connect(func(): print("HORA depois de descansar: ", hora))
	if args.has("lobos"):          # teste: --lobos=N (matilha N), --lobo_anim=correr|atacar|esquivar[:u]
		var g: Dictionary = matilhas[int(args.lobos) % matilhas.size()]
		var c: Vector2 = g.casa
		if args.has("lobo_pos"): var lp := String(args.lobo_pos).split(","); c = Vector2(float(lp[0]), float(lp[1]))
		print("MATILHAS: ", matilhas.map(func(x): return [x.tipo, x.casa, x.membros.size()]))
		if args.has("lobo_anim"):
			var pa := String(args.lobo_anim).split(":")
			var k := 0
			for lo in g.membros:
				var q := c + Vector2((k - 1) * 3.2, 0)
				lo.global_position = Vector3(q.x, altura_malha(q.x, q.y), q.y); lo.rotation.y = float(args.get("giro_l", str(PI * 0.5)))
				lo.anim_fixa = pa[0]; lo.u_fixo = float(pa[1]) if pa.size() > 1 else -1.0
				if pa.size() > 2: lo._fase = float(pa[2]) + k * 2.1
				if k > 2 or (args.has("lobo_um") and k != int(args.lobo_um)): lo.visible = false
				k += 1
			var pj := c + Vector2(0, float(args.get("dist", "7")))
			jogador.global_position = Vector3(pj.x, altura(pj.x, pj.y) + 0.3, pj.y); jogador.rotation.y = 0.0
			jogador.mao.visible = false; jogador.set_physics_process(false); jogador.pescoco.rotation.x = float(args.get("inclina", "0"))
			jogador.global_position.x += (float(args.lobo_um) - 1.0) * 3.2 if args.has("lobo_um") else 0.0
		else:
			var pj := c + Vector2(0, float(args.get("dist", "16")))
			jogador.global_position = Vector3(pj.x, altura(pj.x, pj.y) + 0.3, pj.y); jogador.rotation.y = 0.0
		_ultima = jogador.global_position
		if args.has("numeros"):        # teste: números de combate em cima dos lobos e o dano levado
			get_tree().create_timer(2.6).timeout.connect(func():
				for lo in g.membros.slice(0, 3):
					var dl: Vector3 = (lo.global_position - jogador.global_position).normalized()
					if lo.visible: lo.golpe_da_heroina(lo.global_position - dl * 1.5, dl, 1.6 if lo.lider else 1.0)
				ferir_heroina(8.0, jogador.global_position - jogador.global_transform.basis.z, 2))
		if args.has("lobo_log"):
			for t in 14:
				if args.has("lutar"):        # teste: a Rachel golpeia o lobo mais perto
					var perto: Node3D = null
					for l in g.membros: if is_instance_valid(l) and l.estado != "morto" and (perto == null or l.global_position.distance_to(jogador.global_position) < perto.global_position.distance_to(jogador.global_position)): perto = l
					if perto: var dl := perto.global_position - jogador.global_position; jogador.rotation.y = atan2(-dl.x, -dl.z)
					controles._seg["atacar"] = true; await get_tree().create_timer(0.12).timeout; controles._seg["atacar"] = false
				await get_tree().create_timer(0.9).timeout
				if args.has("lutar"): print("BOLSA: ", bolsa.bolsas[0].slots, " XP ", hud.xp, "/", hud.xp_max, " nível ", hud.nivel)
				print("t=%d alerta=%s atac=%s " % [t, g.alerta, g.get("atacante") != null], g.membros.map(func(l): return "%s %.1f" % [l.estado, Vector2(l.global_position.x - jogador.global_position.x, l.global_position.z - jogador.global_position.z).length()] if is_instance_valid(l) else "-"))
	if args.has("casa"):           # teste: olha uma casa de lado, a 8 m (--casa=N)
		var c: Array = casas[int(args.casa) % casas.size()]
		var cp := Vector2(c[0].x, c[0].z); var pj := cp + Vector2(c[2] * 0.5 + 8.0, 2.0).rotated(-c[1])
		jogador.global_position = Vector3(pj.x, altura(pj.x, pj.y) + 0.3, pj.y); _ultima = jogador.global_position
		var dl := cp - pj; jogador.rotation.y = atan2(-dl.x, -dl.y)
	if args.has("rio"):            # teste: na beira do rio olhando a água (--rio=metros ao longo do rio)
		var r: Array = fauna._no_rio(float(args.rio))
		var nrm := Vector2(-r[1].y, r[1].x); var pj: Vector2 = r[0] + nrm * (reg.largura_rio(r[2]) * 0.5 + 1.5)
		jogador.global_position = Vector3(pj.x, altura(pj.x, pj.y) + 0.3, pj.y); _ultima = jogador.global_position
		var dl: Vector2 = r[0] - pj; jogador.rotation.y = atan2(-dl.x, -dl.y) + float(args.get("giro", "0")); jogador.pescoco.rotation.x = float(args.get("inclina", "-0.45"))
		jogador.set_physics_process(false); jogador.mao.visible = false
	if args.has("ceu"):            # teste: olhando para cima (pássaros)
		jogador.pescoco.rotation.x = 0.45; jogador.set_physics_process(false); jogador.mao.visible = false
		get_tree().create_timer(0.5).timeout.connect(func():
			for b in fauna.bandos:
				var a: float = randf() * TAU
				b.pos = jogador.global_position + Vector3(-sin(jogador.rotation.y) * 45.0 + cos(a) * 8.0, 0, -cos(jogador.rotation.y) * 45.0 + sin(a) * 8.0); b.pos.y = 0.0)
	if args.has("loja") or args.has("inv"):      # teste: --loja=N (itens e abre a loja) / --inv=1 (abre as bolsas)
		if args.has("arma"): bolsa.pegar(String(args.arma)); hud.definir_nivel(3, 0.0)
		if args.has("item"): bolsa.pegar(String(args.item), 3)           # --item=pocao_m: fica no 1º espaço
		if args.has("novos"):
			bolsa.pegar("escama_lodoso", 7); bolsa.pegar("presa_aranha", 3)
			bolsa.pegar("barbatana_lodoso", 2); bolsa.pegar("olho_lodoso", 1); bolsa.pegar("perola_lama", 1)
			bolsa.pegar("pelo_lobo", 4); bolsa.pegar("veneno_aranha", 2)
			bolsa.pegar("coroa_grao_lodoso", 1); bolsa.pegar("tridente_partido", 1); bolsa.pegar("presa_da_mare", 1)
		bolsa.pegar("dentes_garras", int(args.get("itens", args.get("loja", "27")))); bolsa.cobre = int(args.get("dinheiro", "1234"))
		if args.has("bolsas"):
			bolsa.pegar("bolsa_16"); bolsa.pegar("bolsa_30")
			for i in range(9, -1, -1):
				var sl = bolsa.slot(0, i)
				if sl != null and Bolsa.eh_bolsa(sl[0]): bolsa.equipar_bolsa(0, i)
			bolsa.pegar("dentes_garras", 30)
		if args.has("recompra"): bolsa.vender_slot(0, 0)
		var f3 := Vector3(ferraria_pos.x, 0, ferraria_pos.y); var dirf := (Vector3.ZERO - f3).normalized()
		var pj := f3 + dirf * 3.0; jogador.global_position = Vector3(pj.x, altura(pj.x, pj.z) + 0.3, pj.z)
		jogador.rotation.y = atan2(dirf.x, dirf.z)
		get_tree().create_timer(2.0).timeout.connect(func():
			if args.has("loja"): interacao._abrir_loja()
			else: inventario.abrir()
			if args.has("dica"):
				var jan: Control = inventario._janelas.get_child(1)
				inventario._tocar(0, 0, jan.find_children("*", "Panel", true, false)[0]))
	if args.has("tris"):           # teste: triângulos por grupo (perto da câmera)
		get_tree().create_timer(5.0).timeout.connect(func():
			var cam := jogador.cam.global_position
			var grupos := {}; var dcs := {}; var cache := {}
			var tri_de := func(me: Mesh) -> int:
				if cache.has(me): return cache[me]
				var tt := 0
				for si in me.get_surface_count():
					var arr := me.surface_get_arrays(si)
					tt += (arr[Mesh.ARRAY_INDEX].size() if arr[Mesh.ARRAY_INDEX] else arr[Mesh.ARRAY_VERTEX].size()) / 3
				cache[me] = tt; return tt
			for n in raiz.find_children("*", "GeometryInstance3D", true, false):
				var g: GeometryInstance3D = n
				if not g.is_visible_in_tree(): continue
				var pos: Vector3 = g.global_transform * g.get_aabb().get_center()
				var dd := pos.distance_to(cam) - g.get_aabb().size.length() * 0.5
				if (g.visibility_range_end > 0.0 and pos.distance_to(cam) > g.visibility_range_end) or dd > 270.0: continue
				if g.visibility_range_begin > 0.0 and pos.distance_to(cam) < g.visibility_range_begin: continue
				var dono: Node = g
				while dono.get_parent() != raiz and dono.get_parent() != null: dono = dono.get_parent()
				var nome: String = dono.get_class() + ":" + (dono.get_script().resource_path.get_file() if dono.get_script() else dono.name.left(12))
				var t := 0
				if g is MeshInstance3D and g.mesh: t = tri_de.call(g.mesh)
				elif g is MultiMeshInstance3D and g.multimesh and g.multimesh.mesh:
					var mm: MultiMesh = g.multimesh; var tm: int = tri_de.call(mm.mesh)
					t = tm * (mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count)
				grupos[nome] = grupos.get(nome, 0) + t; dcs[nome] = dcs.get(nome, 0) + 1
			var ks := grupos.keys(); ks.sort_custom(func(a, b): return grupos[a] > grupos[b])
			for k in ks.slice(0, 18): print("TRIS %-40s %8d  (%d nós)" % [k, grupos[k], dcs[k]]))
	if args.has("perfil"):         # teste: tempo de _process/_physics_process de cada script (chama de novo e mede)
		get_tree().create_timer(8.0).timeout.connect(func():
			var soma := {}; var cont := {}
			for rep in 3:
				for n in get_tree().root.find_children("*", "", true, false):
					var sc = n.get_script()
					if sc == null: continue
					for f in ["_process", "_physics_process"]:
						if not n.has_method(f) or not n.is_processing() and f == "_process": continue
						var t0 := Time.get_ticks_usec(); n.call(f, 0.016); var dt := Time.get_ticks_usec() - t0
						var k: String = sc.resource_path.get_file() + ":" + f
						soma[k] = soma.get(k, 0) + dt; cont[k] = cont.get(k, 0) + 1
			var ks := soma.keys(); ks.sort_custom(func(a, b): return soma[a] > soma[b])
			for k in ks.slice(0, 14): print("PERFIL %-36s %7.2f ms/quadro  (%d nós)" % [k, soma[k] / 3000.0, cont[k] / 3]))
	if args.has("perf"):           # teste: mede o custo do quadro (draw calls, triângulos, tempo de script)
		for rep in 5: get_tree().create_timer(float(args.get("perf_t", "3")) + rep * 1.5).timeout.connect(func():
			var P := Performance
			print("PERF draw=%d objetos=%d prim=%d  process=%.1fms physics=%.1fms  nos=%d" % [
				P.get_monitor(P.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), P.get_monitor(P.RENDER_TOTAL_OBJECTS_IN_FRAME),
				P.get_monitor(P.RENDER_TOTAL_PRIMITIVES_IN_FRAME), P.get_monitor(P.TIME_PROCESS) * 1000.0,
				P.get_monitor(P.TIME_PHYSICS_PROCESS) * 1000.0, P.get_monitor(P.OBJECT_NODE_COUNT)]))
	if args.has("mapa"): get_tree().create_timer(1.5).timeout.connect(func(): mapa.alternar())
	if args.has("vista"): menu.aplicar_distancia(float(args.vista))
	if args.has("limpo"):          # teste/arte: esconde toda a interface (só o mundo) e os braços
		get_tree().create_timer(0.5).timeout.connect(func():
			for c in get_children(): if c is CanvasLayer: c.visible = false
			jogador.mao.visible = false)
	if args.has("menu"): get_tree().create_timer(1.5).timeout.connect(func(): menu._abrir_config() if args.menu == "config" else menu._abrir_principal())
	if args.has("monstro"):        # teste: um monstro parado na frente da câmera numa animação (--monstro=golem --manim=soco:0.6)
		var pj := Vector2(-30, 62); var tp: String = args.monstro
		if args.has("mpos"): var mp := String(args.mpos).split(","); pj = Vector2(float(mp[0]), float(mp[1]))
		jogador.global_position = Vector3(pj.x, altura(pj.x, pj.y) + 0.3, pj.y + float(args.get("dist", "6")))
		jogador.rotation.y = 0.0; jogador.mao.visible = false; jogador.set_physics_process(false)
		jogador.pescoco.rotation.x = float(args.get("inclina", "0"))
		var mo: Node3D
		if tp == "aranha": mo = Aranha.new()
		elif tp.begins_with("lobo_"): mo = Lobo.new()          # --monstro=lobo_marrom --manim=correr:0.3
		else: mo = Monstro.new()
		mo.grupo = {"casa": pj, "membros": [mo], "alerta": false}
		raiz.add_child(mo); mo.position = Vector3(pj.x, altura_malha(pj.x, pj.y), pj.y)
		if tp == "aranha": mo.montar(self, 4, 1)
		elif tp.begins_with("lobo_"): mo.montar(self, tp.substr(5), false, 1)
		else: mo.montar(self, tp, 3, 1)
		mo.rotation.y = deg_to_rad(float(args.get("giro_m", "90")))
		mo.anim_fixa = String(args.get("manim", "andar"))
		if mo is Lobo:
			var pm := String(mo.anim_fixa).split(":"); mo.anim_fixa = pm[0]
			if pm.size() > 1: mo.u_fixo = float(pm[1])
		if tp == "golem": golem = mo; mo.grupo.alerta = true
		if tp == "lodoso_c": chefe_lodoso = mo; mo.nome = NOME_CHEFE_LODOSO
		if args.has("bloquear"): jogador.bloqueando = true               # teste: Rachel com o escudo erguido
		if tp == "lodoso_c" and args.has("cuspe"):
			jogador.rotation.y = atan2(-(pj.x - jogador.global_position.x), -(pj.y - jogador.global_position.z))   # de frente para ele
		if args.has("saque"):       # teste: --saque (contorno) / --saque=abrir (janelinha)
			get_tree().create_timer(0.5).timeout.connect(func():
				mo.anim_fixa = ""; mo.vida = 0.0; mo._mudar("morto"); mo.remove_from_group("lobos")
				if mo is Lobo: lobo_morreu(mo)
				else: monstro_morreu(mo)
				mo.set_meta("saque", [["dentes_garras", 1], ["pelo_lobo", 2]]))
			if args.saque == "abrir": get_tree().create_timer(3.0).timeout.connect(func(): saque.abrir(mo))
	if args.has("matar_golem") and golem:
		var gp := golem.global_position
		golem.vida = 0.0; golem._mudar("morto"); golem.remove_from_group("lobos"); monstro_morreu(golem)
		print("GOLEM morreu em ", gp)
	if args.has("perto_golem") and golem:
		var gp := Vector2(golem.global_position.x, golem.global_position.z) + Vector2(70, 40)
		jogador.global_position = Vector3(gp.x, altura(gp.x, gp.y) + 0.3, gp.y); _ultima = jogador.global_position
		var dg := Vector2(golem.global_position.x, golem.global_position.z) - gp; jogador.rotation.y = atan2(-dg.x, -dg.y) + 0.3
	if args.has("ir"):             # teste: vai para um lugar nomeado (--ir=cidade|porto_cidade|praca)
		var alvo := Vector2(-4, 48); var olha := Vector2.ZERO
		match String(args.ir):
			"cidade": alvo = cidade_pos + Vector2(-Regiao.CIDADE_R - 70.0, 30.0); olha = cidade_pos
			"praca": alvo = cidade_pos + Vector2(-30, 6); olha = cidade_pos + Vector2(0, -150)
			"ponte": alvo = Vector2(Regiao.FOSSO_X - 18.0, cidade_pos.y + 2.0); olha = cidade_pos
			"lojas": alvo = cidade_pos + Vector2(-14, 14); olha = cidade_pos + Vector2(-40, 30)
			"parque": alvo = cidade_pos + Vector2(-60, 160); olha = Regiao.LAGO_PARQUE
			"magos": alvo = cidade_pos + Vector2(-60, 70); olha = cidade_pos + Vector2(-130, 115)
			"porto_cidade": alvo = Vector2(Regiao.CIDADE.end.x + 22.0, cidade_pos.y + 30.0); olha = Vector2(Regiao.CIDADE.end.x + 120.0, cidade_pos.y - 10.0)
			"portao_leste": alvo = Vector2(Regiao.CIDADE.end.x + 30.0, cidade_pos.y + 4.0); olha = Vector2(Regiao.CIDADE.end.x - 40.0, cidade_pos.y)
			"alto": alvo = cidade_pos + Vector2(-260, 230); olha = cidade_pos
			"arte": alvo = cidade_pos + Vector2(-420, 150); olha = cidade_pos + Vector2(0, -40)
			"estabulo": alvo = estabulo_pos + Vector2(6.0, 34.0); olha = estabulo_pos + Vector2(-10.0, 0)
			"cercado": alvo = estabulo_pos + Vector2(1.0, 21.0); olha = estabulo_pos + Vector2(1.0, 9.0)
			"freira_vila", "freira_cidade":
				var fr: Morador = freiras[1 if args.ir == "freira_vila" else 0]
				olha = fr.posto; alvo = fr.posto + (fr.olhar_posto - fr.posto).normalized() * 3.2
			"estrada_real": alvo = Vector2(640, -215); olha = Vector2(840, -310)
			"estatua0", "estatua1", "estatua2":
				var es: Array = estatuas[int(String(args.ir).right(1))]
				olha = es[0]; alvo = es[0] + (es[1] as Vector2) * 8.0
			"cavalarico": alvo = estabulo_pos + Vector2(-19.0, 6.0); olha = estabulo_pos + Vector2(-19.5, 0.0)
			"taverna": alvo = taverna_pos + Vector2(10.0, -26.0); olha = taverna_pos
			"rua_oeste": alvo = cidade_pos + Vector2(-205.0, 0.0); olha = cidade_pos
			"lodosos":          # --ir=lodosos --n=0 (0 = acampamento do chefe)
				var ls := matilhas.filter(func(g): return g.get("tipo", "") == "lodoso")
				var cg: Vector2 = ls[int(args.get("n", "0")) % ls.size()].casa
				olha = cg; alvo = cg + Vector2(float(args.get("dx", "9")), float(args.get("dz", "6")))
				print("LODOSOS: %d grupos" % ls.size())
			"praia":
				var zp := float(args.get("z", "200")); var xp := linha_praia(zp)
				alvo = Vector2(xp - float(args.get("dx", "6")), zp); olha = alvo + (Vector2(0, 10) if args.has("ao_longo") else Vector2(10, 8))
			"gruta":           # --ir=gruta --onde=boca|sala1|sala2|camara
				var onde := String(args.get("onde", "boca"))
				var pts := {"boca": [Regiao.GRUTA_ENTRADA + Vector2(0, 14), Regiao.GRUTA_ENTRADA + Vector2(0, -20)],
					"tunel": [Vector2(1544, -905), Vector2(1539, -945)],
					"sala1": [Vector2(1540, -940), Regiao.GRUTA_SALAS[0][0]],
					"sala2": [Vector2(1490, -1000), Regiao.GRUTA_SALAS[2][0]],
					"camara": [Vector2(1536, -1056), Regiao.GRUTA_CAMARA],
					"chefe": [Regiao.GRUTA_CAMARA + Vector2(-2, 9), Regiao.GRUTA_CAMARA],
					"meio": [Vector2(1540, -925), Vector2(1537, -950)],
					"arte": [Regiao.GRUTA_ENTRADA + Vector2(-9, 22), Regiao.GRUTA_ENTRADA + Vector2(3, -36)],
					"fora": [Regiao.GRUTA_ENTRADA + Vector2(-30, 40), Regiao.GRUTA_ENTRADA + Vector2(0, -40)],
					"cima": [Regiao.GRUTA_ENTRADA + Vector2(60, 30), Vector2(1520, -1000)],
					"perto": [Vector2(1538, -943), Vector2(1534, -960)]}
				alvo = pts[onde][0]; olha = pts[onde][1]
			"ponto": alvo = Vector2(float(args.get("px", "0")), float(args.get("pz", "0"))); olha = alvo + Vector2(0, -10)   # --ir=ponto --px --pz
			"rio_cidade": alvo = Vector2(1640.0, -760.0); olha = Vector2(1612.0, -700.0)
		jogador.global_position = Vector3(alvo.x, altura(alvo.x, alvo.y) + 0.3, alvo.y); _ultima = jogador.global_position
		var dd := olha - alvo; jogador.rotation.y = atan2(-dd.x, -dd.y)
		if String(args.ir) == "alto" or String(args.ir) == "arte": jogador.global_position.y += (60.0 if args.ir == "alto" else 48.0); jogador.set_physics_process(false); jogador.pescoco.rotation.x = -0.35 if args.ir == "alto" else -0.2
		if args.has("subir"): jogador.global_position.y += float(args.subir); jogador.set_physics_process(false); jogador.pescoco.rotation.x = float(args.get("inclina", "-0.6"))
	if args.has("empunhar"): get_tree().create_timer(0.5).timeout.connect(func(): jogador.trocar_equip("arma", String(args.empunhar)))   # teste: --empunhar=presa_da_mare
	if args.has("escudo"): get_tree().create_timer(0.5).timeout.connect(func(): jogador.trocar_equip("escudo", String(args.escudo)))
	if args.has("dar_cavalos"):    # teste: dá as três montarias (e dinheiro)
		for id in ["cavalo_branco", "cavalo_marrom", "cavalo_preto", "cavalo_dourado"]: if not id in bolsa.montarias: bolsa.montarias.append(id)
		bolsa.montaria_sel = String(args.get("cavalo", "cavalo_preto")) if String(args.get("cavalo", "")) != "" else bolsa.montarias[0]
	if args.has("montar"):         # teste: aperta o botão de montar; com --montar=andar anda depois de montado
		get_tree().create_timer(1.0).timeout.connect(func(): montaria_ui.alternar_montaria())
		if String(args.montar) == "andar": get_tree().create_timer(3.0).timeout.connect(func(): controles.dir = Vector2(0, -1); controles.set_process(false))
	if args.has("cavalo_andar"):   # teste: os cavalos do cercado "andam" no lugar na velocidade dada (m/s)
		get_tree().create_timer(1.0).timeout.connect(func():
			for cv in raiz.find_children("Cavalo*", "Node3D", false, false):
				for ch in cv.get_children(): if ch.get_script() != null and "vel" in ch: ch.vel = float(args.cavalo_andar))
	if args.has("estatuas"):
		for e in estatuas: print("ESTATUA %s alt=%.1f" % [str((e[0] as Vector2).round()), reg.altura(e[0].x, e[0].y)])
	if args.has("mapa_depois"): get_tree().create_timer(float(args.mapa_depois)).timeout.connect(func(): mapa.alternar())
	if args.has("trava"):          # teste: dedo no joystick, empurra para cima até a trava, solta e a Rachel segue sozinha
		var toque := func(pressed: bool, pos: Vector2):
			var ev := InputEventScreenTouch.new(); ev.index = 0; ev.pressed = pressed; ev.position = pos; controles._input(ev)
		var arrasta := func(pos: Vector2):
			var ev := InputEventScreenDrag.new(); ev.index = 0; ev.position = pos; controles._input(ev)
		get_tree().create_timer(2.0).timeout.connect(func(): toque.call(true, controles._centro_fixo()))
		get_tree().create_timer(2.3).timeout.connect(func(): arrasta.call(controles._centro_fixo() + Vector2(0, -150)))
		get_tree().create_timer(2.5).timeout.connect(func(): arrasta.call(controles._centro_fixo() + Vector2(0, -253)); print("ALTURA ANTIGA: ", controles.auto))
		get_tree().create_timer(2.8).timeout.connect(func(): arrasta.call(controles._pos_trava()); print("TRAVA: ", controles.auto, " pos ", jogador.global_position.round()))
		get_tree().create_timer(3.2).timeout.connect(func(): toque.call(false, controles._pos_trava()))
		get_tree().create_timer(3.6).timeout.connect(func(): toque.call(true, controles._centro_fixo()); arrasta.call(controles._centro_fixo() + Vector2(90, 0)))
		get_tree().create_timer(5.0).timeout.connect(func(): print("AUTO: ", controles.auto, " dir ", controles.dir, " pos ", jogador.global_position.round()))
	if args.has("musica"):
		get_tree().create_timer(5.0).timeout.connect(func(): print("MUSICA cidade=%s vale=%.0f dB (pausada=%s) cidade=%.0f dB" % [_na_cidade, _mus_vale.volume_db, _mus_vale.stream_paused, _mus_cidade.volume_db if _mus_cidade else -99.0]))
	if args.has("picos"):          # teste: corre a cavalo pela Estrada Real e mede quadros lentos e quem montou o quê
		var quadros := []
		get_tree().create_timer(4.0).timeout.connect(func():
			_picos.clear()
			for id in ["cavalo_preto"]: if not id in bolsa.montarias: bolsa.montarias.append(id)
			bolsa.montaria_sel = "cavalo_preto"; jogador.montar_em("cavalo_preto", cavalo("cavalo_preto"))
			controles.auto = true)
		get_tree().create_timer(4.0).timeout.connect(func():
			get_tree().process_frame.connect(func(): quadros.append(get_process_delta_time() * 1000.0)))
		get_tree().create_timer(19.0).timeout.connect(func():
			quadros.sort(); var n := quadros.size()
			print("PICOS quadros=%d  mediana=%.1fms  p95=%.1fms  pior=%.1fms  >25ms=%d" % [n, quadros[n / 2], quadros[int(n * 0.95)], quadros[n - 1], quadros.filter(func(q): return q > 25.0).size()])
			for k in _picos: print("PICOS %-10s %3d pedaços  média %.1fms  pior %.1fms" % [k, _picos[k][0], _picos[k][1] / maxf(_picos[k][0], 1), _picos[k][2]]))
	if args.has("contar"):
		var cont := {}
		for g in matilhas:
			var t: String = String(g.get("tipo", "?")) + ("_pequeno" if g.get("pequena", false) else "")
			cont[t] = cont.get(t, 0) + 1
		print("GRUPOS ", cont, " total=", matilhas.size())
	if args.has("morrer"): get_tree().create_timer(2.0).timeout.connect(func(): hud.vida = 1.0; ferir_heroina(50.0, jogador.global_position + Vector3(0, 0, -2), 1))
	if args.has("loja_freira"):
		get_tree().create_timer(3.0).timeout.connect(func(): bolsa.cobre = 500; print("NPC: ", interacao._tipo_npc); interacao._abrir_loja())
		get_tree().create_timer(3.4).timeout.connect(func():
			print("COMPRA: '", bolsa.comprar("pocao_m"), "'"); hud.vida = 40.0
			for k in bolsa.bolsas.size():
				if bolsa.bolsas[k] == null: continue
				for i in bolsa.bolsas[k].slots.size():
					var sl = bolsa.bolsas[k].slots[i]
					if sl != null and sl[0] == "pocao_m":
						var c := bolsa.consumir(k, i, hud.vida_max); hud.vida = minf(hud.vida + c, hud.vida_max)
						print("POCAO: +%d -> vida %.0f / %.0f" % [c, hud.vida, hud.vida_max]); return)
	if args.has("frutiferas"):     # teste: conta árvores frutíferas e arbustos de frutinha montados e vai até a frutífera mais perto
		get_tree().create_timer(1.5).timeout.connect(func():
			var na := 0; var nb := 0; var pj := jogador.global_position; var melhor := Vector3.ZERO; var md := 1e9
			for k in floresta.bagas.keys():
				for q in floresta.bagas[k][1]:
					if k.x >= 50000: na += 1
					else: nb += 1
					var d: float = (q - pj).length()
					if k.x >= 50000 and d < md: md = d; melhor = q
			print("FRUTIFERAS árvores=%d arbustos=%d (perto da Rachel); mais perto a %.0f m" % [na, nb, md])
			var dir := Vector3(1, 0, 0.4).normalized()
			jogador.global_position = melhor + dir * 1.6 + Vector3(0, 0.3, 0); jogador.reset_physics_interpolation()
			jogador.rotation.y = atan2(dir.x, dir.z); jogador.pescoco.rotation.x = 0.35)
	if args.has("fluxo_frutinhas"): # teste: vai até o arbusto de frutinhas mais perto, coleta, abre a bolsa e come uma
		get_tree().create_timer(1.5).timeout.connect(func():
			var pj := jogador.global_position; var melhor := Vector3.ZERO; var md := 1e9
			for k in floresta.bagas.keys():
				for q in floresta.bagas[k][1]:
					var d: float = (q - pj).length()
					if d < md: md = d; melhor = q
			var dir := Vector3(1, 0, 0.3).normalized()
			jogador.global_position = melhor + dir * 1.8 + Vector3(0, 0.3, 0)
			jogador.rotation.y = atan2(dir.x, dir.z); jogador.pescoco.rotation.x = -0.35
			print("ARBUSTO a %.0f m" % md))
		get_tree().create_timer(3.0).timeout.connect(func():
			hud.vida = 60.0; interacao._coletar(); inventario.abrir())
		get_tree().create_timer(3.6).timeout.connect(func():
			for k in bolsa.bolsas.size():
				if bolsa.bolsas[k] == null: continue
				for i in bolsa.bolsas[k].slots.size():
					var sl = bolsa.bolsas[k].slots[i]
					if sl != null and sl[0] == "frutinhas":
						var antes := hud.vida; var c := bolsa.consumir(k, i); hud.vida = minf(hud.vida + c, hud.vida_max)
						print("CONSUMIU: vida %.0f -> %.0f; sobrou %s" % [antes, hud.vida, str(bolsa.slot(k, i))]); return)
	if args.has("fluxo_cavalo"):   # teste: compra o cavalo branco, abre a bolsa, "toque duplo" nele e abre as montarias
		get_tree().create_timer(1.2).timeout.connect(func():
			bolsa.cobre = 500; print("COMPRA: '", bolsa.comprar("cavalo_branco"), "'"); inventario.abrir())
		get_tree().create_timer(2.2).timeout.connect(func():
			for k in bolsa.bolsas.size():
				if bolsa.bolsas[k] == null: continue
				for i in bolsa.bolsas[k].slots.size():
					var sl = bolsa.bolsas[k].slots[i]
					if sl != null and sl[0] == "cavalo_branco": inventario.usar_montaria(k, i); print("APRENDEU: ", bolsa.montarias); return)
		get_tree().create_timer(3.0).timeout.connect(func(): inventario.fechar(); montaria_ui.abrir_menu("montarias"))
	if args.has("personagem"): get_tree().create_timer(0.8).timeout.connect(func(): montaria_ui.abrir_menu(String(args.personagem)))
	if args.has("loja_estabulo"):
		get_tree().create_timer(2.5).timeout.connect(func():
			var q := estabulo_npc.global_position + Vector3(0, 0, 1.6); jogador.global_position = q; jogador.rotation.y = 0.0)
		get_tree().create_timer(3.2).timeout.connect(func(): print("NPC perto: ", interacao.npc); interacao._abrir_loja())
	if args.has("travar"):         # teste: perto de uma matilha, trava a mira e anda de lado
		get_tree().create_timer(2.5).timeout.connect(func():
			controles._alvo = true
			get_tree().create_timer(0.6).timeout.connect(func(): controles.dir = Vector2(1, 0); controles.set_process(false)))
	if args.has("checar_agua"):    # teste: quantos monstros estão na água (agora e depois de um tempo)
		for t in [0.5, 20.0]:
			get_tree().create_timer(t).timeout.connect(func():
				var n := 0; var tot := 0
				for mo in get_tree().get_nodes_in_group("lobos"):
					tot += 1
					if na_agua(mo.global_position.x, mo.global_position.z): n += 1; print("NA AGUA: ", mo.get_script().resource_path.get_file(), " ", mo.global_position)
				print("MONSTROS NA AGUA: %d de %d" % [n, tot]))
	if args.has("criancas"):
		var c3 := Vector3(brincadeira_pos.x, 0, brincadeira_pos.y); var pj := c3 + Vector3(0, 0, float(args.get("dist", "9")))
		jogador.global_position = Vector3(pj.x, altura(pj.x, pj.z) + 0.3, pj.z); jogador.rotation.y = 0.0
		_ultima = jogador.global_position
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
		if args.has("pular"):           # teste: pula andando (e correndo com --correr) e mede a altura do pulo
			if args.has("correr"): controles._seg["correr"] = true
			await get_tree().create_timer(0.8).timeout
			var y0 := jogador.global_position.y; controles._pulo = true; var ymax := y0
			for i in 40:
				await get_tree().physics_frame; ymax = maxf(ymax, jogador.global_position.y)
			print("PULO: subiu %.2f m" % (ymax - y0))
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
	if args.has("tempos"):         # vários prints: --tempos=1.5,3,5 → saida-0.png, saida-1.png...
		var antes := 0.0; var q := 0
		for t in String(args.tempos).split(","):
			await get_tree().create_timer(float(t) - antes).timeout; antes = float(t)
			get_viewport().get_texture().get_image().save_png(String(args.shot).replace(".png", "-%d.png" % q)); q += 1
		get_tree().quit(); return
	await get_tree().create_timer(float(args.get("espera", "2"))).timeout
	get_viewport().get_texture().get_image().save_png(args.shot)
	get_tree().quit()

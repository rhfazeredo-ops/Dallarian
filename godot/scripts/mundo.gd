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
	reg = Regiao.new(); estrada = reg.estradas[0]
	_tela()
	_ambiente()
	terreno = Terreno.new(); raiz.add_child(terreno)
	jogador = Jogador.new()
	_lugares()                      # antes do terreno: as construções aplanam o chão embaixo delas
	terreno.montar(self)
	for f in _depois: f.call()        # cercas, muros e blocos: assentados na malha final do terreno
	_agua_feita = false
	_agua()
	_espuma()
	_juntar_estaticos()
	var fl := Floresta.new(); raiz.add_child(fl); fl.montar(self)
	var chao := ChaoSplat.new(); raiz.add_child(chao); chao.montar(self)
	var grama := Grama.new(); raiz.add_child(grama); grama.montar(self)
	_moradores()
	raiz.add_child(jogador)
	jogador.position = Vector3(-4, altura(-4, 48) + 0.3, 48)
	_ultima = jogador.position
	controles = Controles.new(); var cl := CanvasLayer.new(); add_child(cl); cl.add_child(controles)
	jogador.controles = controles
	bolsa.equipou.connect(func(lugar: String, id: String): jogador.trocar_equip(lugar, id))
	hud = Hud.new(); cl.add_child(hud); hud.montar(); hud.escala_3d = REDUCAO
	_carregar_progresso()
	_tela_dano = ColorRect.new(); _tela_dano.color = Color(0.7, 0.0, 0.0, 1.0); _tela_dano.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tela_dano.mouse_filter = Control.MOUSE_FILTER_IGNORE; _tela_dano.modulate.a = 0.0; cl.add_child(_tela_dano)
	var inter := Interacao.new(); cl.add_child(inter); inter.montar(self); interacao = inter
	inventario = Inventario.new(); cl.add_child(inventario); inventario.montar(self)
	loja_ui = Loja.new(); cl.add_child(loja_ui); loja_ui.montar(self)
	mapa = Mapa.new(); cl.add_child(mapa); mapa.montar(self)
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
		["Desfiladeiro do Norte", Vector2(0, -Regiao.Ws(468.0)), "montanhas", 40.0],
		["Altamar", cidade_pos, "castelo", 200.0],
	] + barracas.map(func(b: Vector2) -> Array: return ["Acampamento", b, "tenda", 14.0]))
	fauna.montar(self)
	_montar_chuva()
	_montar_vento()
	if args.has("chuva"): _chuva_alvo = float(args.chuva); chuva = _chuva_alvo
	_musica()
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
			var mo := Morador.new(); raiz.add_child(mo)
			var a := randf() * TAU; var p: Vector2 = g[0] + Vector2(cos(a), sin(a)) * randf_range(4.0, g[1] * 0.8)
			for t in 20:
				if not perto_de_casa(p.x, p.y, 1.5): break
				a = randf() * TAU; p = g[0] + Vector2(cos(a), sin(a)) * randf_range(4.0, g[1] * 0.8)
			mo.position = Vector3(p.x, altura(p.x, p.y) + 0.3, p.y)
			mo.montar(self, 1000 + n, g[0], g[1]); n += 1
	_profissionais()
	_criancas()
	_lobos()
	_aranhas()
	_lodosos()
	_golem()
	fauna = Fauna.new(); raiz.add_child(fauna)
	# já começam algumas conversas na vila
	var vila := []
	for mo in raiz.get_children():
		if mo is Morador and Vector2(mo.position.x, mo.position.z).length() < 45.0: vila.append(mo)
	for k in range(0, mini(vila.size() - 1, 4), 2): vila[k].convidar(vila[k + 1])

# ---------- lobos ----------
# matilhas de 4 a 6 com um líder preto (maior): brancos só nas montanhas, marrons só nas florestas.
var hud: Hud
var heroina_desmaiada := false
var _tela_dano: ColorRect
var matilhas := []
var fauna: Fauna
var interacao: Interacao
var inventario: Inventario
var loja_ui: Loja
var mapa: Mapa
var menu: Menu
func _lobos() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 404
	var montanha := []; var mata := []
	for i in 12000:
		var q := Vector2(rng.randf_range(Regiao.X0 + 60, Regiao.X1 - 60), rng.randf_range(-Regiao.LIM + 60, Regiao.LIM - 60))
		if q.length() < 120.0 or reg.folga_caminho(q.x, q.y) < 12.0 or reg.agua(q.x, q.y) != 0.0: continue
		if perto_de_lugar(q.x, q.y, 30.0) or reg.campo_em(q.x, q.y) >= 0: continue
		var longe_barraca := true
		for b in barracas: if q.distance_to(b) < 60.0: longe_barraca = false
		if not longe_barraca: continue
		var h0 := reg.altura(q.x, q.y); var desn := 0.0
		for o in [Vector2(5, 0), Vector2(-5, 0), Vector2(0, 5), Vector2(0, -5)]:
			desn = maxf(desn, absf(reg.altura(q.x + o.x, q.y + o.y) - h0))
		if desn > 2.2: continue
		if h0 - reg.base(q.y) > 5.0: montanha.append(q)
		elif reg.floresta(q.x, q.y) > 0.6: mata.append(q)
	var escolhidos := []
	for lista in [[montanha, "branco", 22], [mata, "marrom", 36]]:
		var cands: Array = lista[0]; var feitos := 0
		cands.shuffle()
		for q in cands:
			if feitos >= lista[2]: break
			var ok := true
			for e in escolhidos: if q.distance_to(e) < 80.0: ok = false
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
		if feitos2 >= 14: break
		var ok := true
		for e in escolhidos: if q.distance_to(e) < 55.0: ok = false
		if not ok: continue
		escolhidos.append(q); feitos2 += 1
		_matilha(q, "marrom", rng, true)

func _matilha(c: Vector2, tipo: String, rng: RandomNumberGenerator, pequena := false) -> void:
	var n := 3 if pequena else rng.randi_range(4, 6)
	var g := {"casa": c, "membros": [], "alerta": false, "atacante": null, "tipo": tipo}
	# nível: marrons (floresta) 2–3, brancos (montanha) 4–6; o líder um nível acima do maior
	var nv_min := 2 if tipo == "marrom" else 4; var nv_max := 3 if tipo == "marrom" else 6
	if pequena: nv_min = 1; nv_max = 2                      # grupinhos de 3 de nível 1–2, sem líder
	for i in n:
		var lobo := Lobo.new(); lobo.grupo = g
		var lider := i == 0 and not pequena
		var a := TAU * i / n + rng.randf() * 0.4; var r := 0.0 if i == 0 else rng.randf_range(3.0, 6.0)
		var p := c + Vector2(cos(a), sin(a)) * r
		raiz.add_child(lobo); lobo.position = Vector3(p.x, altura_malha(p.x, p.y), p.y)
		lobo.vaga = TAU * i / n
		lobo.nivel = nv_max + 1 if lider else rng.randi_range(nv_min, nv_max)
		lobo.montar(self, "preto" if lider else tipo, lider, rng.randi())
		lobo.rotation.y = rng.randf() * TAU
		g.membros.append(lobo)
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

# vida zerou: tela escurece e a Rachel acorda na vila com a vida cheia
func _desmaiar() -> void:
	heroina_desmaiada = true
	for g in matilhas: g.alerta = false; g.atacante = null
	_tela_dano.color = Color(0, 0, 0, 1)
	var tw := _tela_dano.create_tween()
	tw.tween_property(_tela_dano, "modulate:a", 1.0, 1.0)
	tw.tween_callback(func():
		jogador.global_position = Vector3(-4, altura(-4, 48) + 0.3, 48); jogador.velocity = Vector3.ZERO
		hud.vida = hud.vida_max)
	tw.tween_interval(1.2)
	tw.tween_property(_tela_dano, "modulate:a", 0.0, 1.2)
	tw.tween_callback(func(): _tela_dano.color = Color(0.7, 0, 0, 1); heroina_desmaiada = false)

# lobo morto: XP (o líder dá um pouco mais) e deixa dentes e garras na bolsa
# ---------- monstros novos ----------
# aranhas: uma só por lugar, na mata fechada, longe umas das outras (nível 3–5)
func _aranhas() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 707
	var feitos: Array[Vector2] = []
	for i in 14000:
		if feitos.size() >= 42: break
		var q := Vector2(rng.randf_range(Regiao.X0 + 60, Regiao.X1 - 60), rng.randf_range(-Regiao.LIM + 60, Regiao.LIM - 60))
		if q.length() < 170.0 or reg.floresta(q.x, q.y) < 0.6 or reg.folga_caminho(q.x, q.y) < 10.0 or reg.agua(q.x, q.y) != 0.0: continue
		if perto_de_lugar(q.x, q.y, 25.0) or reg.altura(q.x, q.y) - reg.base(q.y) > 6.0: continue
		var ok := true
		for f in feitos: if q.distance_to(f) < 90.0: ok = false
		for g in matilhas: if q.distance_to(g.casa) < 40.0: ok = false
		if not ok: continue
		feitos.append(q)
		var a := Aranha.new(); a.grupo = {"casa": q, "membros": [a], "alerta": false, "tipo": "aranha"}
		raiz.add_child(a); a.position = Vector3(q.x, altura_malha(q.x, q.y), q.y)
		a.montar(self, rng.randi_range(3, 5), rng.randi()); a.rotation.y = rng.randf() * TAU
		matilhas.append(a.grupo)

# Lodosos: grupos de 3 (um grande e dois jovens) em trechos da beira do rio, do lago e da praia
func _lodosos() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 909
	var cands: Array[Vector2] = []
	var r := reg.rio
	for i in r.size() - 1:
		for u in [0.25, 0.75]:
			var a: Vector2 = r[i]; var b: Vector2 = r[i + 1]; var pt := a.lerp(b, u)
			var nrm := Vector2(-(b - a).normalized().y, (b - a).normalized().x) * (1.0 if rng.randf() < 0.5 else -1.0)
			var t: float = (float(i) + float(u)) / (r.size() - 1)
			cands.append(pt + nrm * (reg.largura_rio(t) * 0.5 + 4.0))
	for k in 6:
		var ang := TAU * k / 6.0 + 0.3
		cands.append(Vector2(Regiao.LAGO.x, Regiao.LAGO.y) + Vector2(cos(ang), sin(ang)) * (Regiao.LAGO.z + 5.0))
	for z0 in [-380.0, -290.0, -200.0, -120.0, -40.0, 50.0, 140.0, 220.0, 300.0]:
		var z := Regiao.Ws(absf(z0)) * signf(z0)
		var x := Regiao.Ws(380.0)
		while x < Regiao.X1 and reg.altura(x, z) > 1.0: x += 1.0
		cands.append(Vector2(x - 5.0, z))
	cands.shuffle()
	var feitos: Array[Vector2] = []
	for q in cands:
		if feitos.size() >= 22: break
		if q.length() < 160.0 or reg.dist_estrada(q.x, q.y) < 12.0 or perto_de_lugar(q.x, q.y, 18.0) or perto_de_casa(q.x, q.y, 10.0): continue
		if reg.agua(q.x, q.y) != 0.0 and altura(q.x, q.y) < reg.agua(q.x, q.y): continue
		var ok := true
		for f in feitos: if q.distance_to(f) < 70.0: ok = false
		if not ok: continue
		feitos.append(q)
		var g := {"casa": q, "membros": [], "alerta": false, "tipo": "lodoso"}
		for j in 3:
			var mo := Monstro.new(); mo.grupo = g
			var p := q + Vector2(cos(TAU * j / 3.0), sin(TAU * j / 3.0)) * (0.0 if j == 0 else 2.0)
			raiz.add_child(mo); mo.position = Vector3(p.x, altura_malha(p.x, p.y), p.y)
			mo.montar(self, "lodoso_g" if j == 0 else "lodoso_j", rng.randi_range(3, 4) if j == 0 else rng.randi_range(2, 3), rng.randi())
			mo.rotation.y = rng.randf() * TAU
			g.membros.append(mo)
		matilhas.append(g)
		_acampamento_lodoso(q, rng)

# cabaninha de juncos, varal de peixes e fogueirinha
func _acampamento_lodoso(c: Vector2, rng: RandomNumberGenerator) -> void:
	var y := altura_malha(c.x, c.y)
	var st := _st()
	var h := c + Vector2(3.0, 1.5).rotated(rng.randf() * TAU)
	cilindro(st, Vector3(h.x, altura_malha(h.x, h.y) - 0.1, h.y), 1.2, 0.05, 1.7, 7)
	_peca(st, mat("palha", 1.0, Color(0.75, 0.8, 0.55)), Vector3.ZERO)
	st = _st()
	var v0 := c + Vector2(-2.5, -1.5)
	for d in [Vector2(0, 0), Vector2(1.8, 0)]:
		var q: Vector2 = v0 + d; _caixa(st, Vector3(q.x, altura_malha(q.x, q.y) + 0.6, q.y), Vector3(0.08, 1.2, 0.08))
	_caixa(st, Vector3(v0.x + 0.9, altura_malha(v0.x, v0.y) + 1.15, v0.y), Vector3(1.9, 0.05, 0.05))
	_peca(st, mat("madeira"), Vector3.ZERO)
	var peixes := []
	for i in 4: peixes.append([Vector3(v0.x + 0.3 + i * 0.4, altura_malha(v0.x, v0.y) + 0.95, v0.y), Color(0.55, 0.62, 0.66), 0.22])
	_splats(peixes, Vector2(0.5, 1.0), false, 0.0)
	_fogo(Vector3(c.x + 1.0, y + 0.05, c.y - 2.5), 0.45, 0.6, 2)
	luzes.append(Vector3(c.x + 1.0, y + 0.4, c.y - 2.5))

# Grumo, o golem de terra (chefe): dá a volta no mapa inteiro, longe da vila, andando sem parar
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
	golem = Monstro.new(); golem.rota = rota; golem.nome = "Grumo, o Guardião do Vale"
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
			raiz.add_child(l); l.position = Vector3(p.x, altura_malha(p.x, p.y), p.y)
			l.montar(self, tp, ld, randi()); return l
	elif mo is Aranha:
		var nv: int = mo.nivel
		f = func() -> Node3D:
			var a := Aranha.new(); a.grupo = g
			raiz.add_child(a); a.position = Vector3(casa.x, altura_malha(casa.x, casa.y), casa.y)
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
		var tp: String = mo.tipo; var nv: int = mo.nivel
		f = func() -> Node3D:
			var lm := Monstro.new(); lm.grupo = g
			var a := randf() * TAU; var p := casa + Vector2(cos(a), sin(a)) * randf_range(0.0, 2.5)
			raiz.add_child(lm); lm.position = Vector3(p.x, altura_malha(p.x, p.y), p.y)
			lm.montar(self, tp, nv, randi()); return lm
	else: return
	var espera := VOLTA_CHEFE if (mo is Monstro and mo.tipo == "golem") else VOLTA_NORMAL
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
	var drops := []                       # [id, chance, mín, máx]
	if mo is Aranha: drops = [["presa_aranha", 0.4, 1, 1]]
	elif mo is Monstro and mo.tipo == "golem":
		drops = [["nucleo_golem", 1.0, 1, 1], ["espada_ferro", 0.35, 1, 1], ["bolsa_16", 0.35, 1, 1]]
		var moedas := randi_range(150, 400); bolsa.cobre += moedas; bolsa.mudou.emit()
		hud.avisar("+%s" % Bolsa.texto_dinheiro(moedas), Color(0.95, 0.75, 0.4))
		hud.avisar("Grumo, o Guardião do Vale foi derrotado!", Color(1.0, 0.82, 0.2))
	elif mo is Monstro: drops = [["escama_lodoso", 0.4, 1, 2 if mo.tipo == "lodoso_g" else 1]]
	for d in drops:
		if randf() > d[1]: continue
		var n := randi_range(d[2], d[3])
		var sobra := bolsa.pegar(d[0], n)
		var info: Dictionary = Bolsa.ITENS[d[0]]
		if n - sobra > 0: hud.avisar("+%d %s" % [n - sobra, info.nome], Bolsa.CORES[info.qual])
		if sobra > 0: hud.avisar("Suas bolsas estão cheias!", Color(1, 0.35, 0.3))

func lobo_morreu(l: Lobo) -> void:
	_agendar_volta(l)
	var ganho := Hud.xp_por_matar(l.nivel, hud.nivel)
	if ganho > 0.0: hud.ganhar_xp(ganho)
	if randf() > 0.4: return                                  # deixa dentes e garras em ~40% das vezes
	var n := randi_range(1, 2) if l.lider else 1
	var sobra := bolsa.pegar("dentes_garras", n)
	if n - sobra > 0: hud.avisar("+%d %s" % [n - sobra, Bolsa.ITENS["dentes_garras"].nome], Color(0.62, 0.62, 0.62))
	if sobra > 0: hud.avisar("Suas bolsas estão cheias!", Color(1, 0.35, 0.3))

# progresso salvo no aparelho (nível, XP, dinheiro e itens); nos testes com print não carrega nem salva
var bolsa := Bolsa.new()
var _salvar_em := -1.0
func _carregar_progresso() -> void:
	if args.has("shot") and not args.has("progresso"): return
	var d := bolsa.carregar()
	if not d.is_empty(): hud.definir_nivel(int(d.get("nivel", 1)), float(d.get("xp", 0.0)))
	jogador.trocar_equip("arma", bolsa.equip.arma); jogador.trocar_equip("escudo", bolsa.equip.escudo)
	var pedir := func(): _salvar_em = 1.0
	hud.mudou.connect(pedir); bolsa.mudou.connect(pedir)

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
		som.unit_size = 6.0; som.max_distance = 75.0; som.volume_db = -4.5; som.bus = "Efeitos"
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
func _tela() -> void:
	var cont := SubViewportContainer.new()
	cont.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cont.stretch = true; cont.stretch_shrink = REDUCAO
	cont.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new(); sm.shader = load("res://shaders/tela.gdshader"); cont.material = sm
	add_child(cont)
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
	_dia_noite(delta)
	_tick_veneno(delta)
	if jogador: _tick_voltas(delta)
	if hud and golem and is_instance_valid(golem):
		hud.chefe = golem if (golem.grupo.alerta and golem.estado != "morto" and golem.global_position.distance_to(jogador.global_position) < 60.0) else null
	if _salvar_em > 0.0:
		_salvar_em -= delta
		if _salvar_em <= 0.0: bolsa.salvar(hud.nivel, hud.xp)
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
	RenderingServer.global_shader_parameter_set("luz_ambiente", Vector3(c.r, c.g, c.b))
	RenderingServer.global_shader_parameter_set("noite", noite)
	var acesa := smoothstep(0.25, 0.6, noite)
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
	if jogador: _gotas.global_position = jogador.global_position + Vector3(0, 13, 0)
	_gotas.emitting = chuva > 0.15
	_mat_gotas.albedo_color.a = 0.45 * clampf((chuva - 0.1) / 0.9, 0.1, 1.0)     # chuva fraca no começo/fim
	if chuva > 0.01:
		if not _som_chuva.playing: _som_chuva.play()
		_som_chuva.volume_db = linear_to_db(chuva) - 4.0
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
	if jogador: _folhas.global_position = jogador.global_position + Vector3(0, 1.5, 0) - DIR_VENTO * 6.0
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

# um poste com lanterna em q, virado para "olha"
func _poste_em(q: Vector2, olha: Vector2) -> void:
		var d: Vector2 = (olha - q).normalized()
		_depois.append(func():
			var y := altura_malha(q.x, q.y)
			var mod := modelo_ps1("res://assets/modelos/poste.glb")
			var k := 2.6 / 0.977
			mod.scale = Vector3(k, k, k); mod.position = Vector3(q.x, y + 0.489 * k - 0.05, q.y)
			mod.rotation.y = atan2(-d.x, -d.y)             # lanterna (-Z do modelo) para a rua
			raiz.add_child(mod)
			_colisor_cilindro(Vector3(q.x, y, q.y), 0.16, 2.6)
			var lp := mod.global_transform * Vector3(0.065, 0.243, -0.181)
			luzes.append(lp + Vector3(0, -0.2, 0))
			var ch := _splats([[lp, Color(1.0, 0.82, 0.4), 0.22], [lp + Vector3(0, 0.04, 0), Color(1.0, 0.95, 0.7), 0.12]], Vector2(1, 1), false, 0.0, 0.0, true)
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
	# RUA PRINCIPAL: a estrada norte-sul atravessa a vila; casas dos dois lados, viradas para a rua, com
	# recuos e tamanhos um pouco diferentes. A praça do poço fica no meio (sem casas nos primeiros 15 m).
	var espec := {}                                       # vagas especiais: taverna e igreja
	for lado_rua in [[reg.estradas[0], 66.0], [reg.estradas[1], 70.0]]:
		var linha: PackedVector2Array = lado_rua[0]; var ate: float = lado_rua[1]
		var s_pos := 15.0
		while s_pos < ate:
			var pr := _ponto_na_linha(linha, s_pos)
			var pt: Vector2 = pr[0]; var tg: Vector2 = pr[1]
			var nrm := Vector2(-tg.y, tg.x)
			for lado in [-1.0, 1.0]:
				var w := rng.randf_range(4.6, 6.6); var d := rng.randf_range(4.0, 5.2); var h := rng.randf_range(2.6, 3.3)
				var parede: Material = null; var telhado: Material = null
				var e_taverna: bool = linha == reg.estradas[0] and lado < 0 and not espec.has("taverna")
				var e_igreja: bool = linha == reg.estradas[1] and lado > 0 and s_pos > 52.0 and not espec.has("igreja")
				if e_taverna: w = 10.0; d = 7.5; h = 5.2; espec["taverna"] = true
				if e_igreja: w = 7.5; d = 12.0; h = 5.0; parede = mat("pedra"); telhado = mat("madeira", 1.0, Color(0.55, 0.5, 0.55)); espec["igreja"] = true
				if not (e_taverna or e_igreja) and rng.randf() < 0.18: continue      # alguns vãos entre as casas (quintais)
				var recuo := 2.6 + d * 0.5 + rng.randf_range(1.8, 6.0)
				var c: Vector2 = pt + nrm * lado * recuo + tg * rng.randf_range(-1.2, 1.2)
				if perto_de_casa(c.x, c.y, maxf(w, d) * 0.5 + 0.8): continue
				var ang := atan2(pt.x - c.x, pt.y - c.y) + rng.randf_range(-0.18, 0.18)   # porta virada para a rua (quase reta)
				_casa(Vector3(c.x, 0, c.y), ang, w, d, h, parede, telhado)
				if e_igreja: _torre_igreja(ang)
			s_pos += rng.randf_range(10.5, 13.0)
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
	lugares.append([Vector2.ZERO, 22.0])

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

func _st() -> SurfaceTool:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES); return st

# ---------- água ----------
func _agua() -> void:
	var am := ShaderMaterial.new(); am.shader = load("res://shaders/agua.gdshader"); am.set_shader_parameter("neblina", NEBLINA)
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
	while z < Regiao.Ws(370.0):
		var x := Regiao.Ws(380.0)
		while x < Regiao.X1 and reg.altura(x, z) > 0.05: x += 1.0
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

# ---------- cidade grande: Altamar ----------
# no canto nordeste, entre as montanhas e o mar: muralha com torres e três portões (oeste, sul e o do porto, a leste),
# rua principal do portão oeste até o porto, praça com chafariz no meio, castelo encostado nas montanhas, catedral,
# quarteirões cheios de casas de pedra e sobrados, cais com navios. Espaço para banco, lojas e taverna depois.
var cidade_pos := Vector2.ZERO
var cidade_y := 0.0
func _cidade() -> void:
	var R: Rect2 = Regiao.CIDADE
	var c := R.get_center(); cidade_pos = c
	var y := Regiao.ALTURA_CIDADE; cidade_y = y
	var rng := RandomNumberGenerator.new(); rng.seed = 1234
	var pedra := mat("pedra"); var pedra_esc := mat("pedra", 1.0, Color(0.75, 0.75, 0.8))
	# muralha: trechos entre os portões, com ameias e torres
	var cantos := [R.position, Vector2(R.end.x, R.position.y), R.end, Vector2(R.position.x, R.end.y)]
	var portoes := [Vector2(R.position.x, c.y), Vector2(c.x, R.end.y), Vector2(R.end.x, c.y)]
	var alt := 9.0; var esp := 3.0
	var st := _st(); var st_am := _st()
	for k in 4:
		var a: Vector2 = cantos[k]; var b: Vector2 = cantos[(k + 1) % 4]
		var cortes := [0.0]
		for pt in portoes:
			var t: float = (pt - a).dot((b - a).normalized()) / a.distance_to(b)
			if Geometry2D.get_closest_point_to_segment(pt, a, b).distance_to(pt) < 1.0: cortes.append_array([t - 8.0 / a.distance_to(b), t + 8.0 / a.distance_to(b)])
		cortes.append(1.0)
		for s in range(0, cortes.size(), 2):
			var p0: Vector2 = a.lerp(b, cortes[s]); var p1: Vector2 = a.lerp(b, cortes[s + 1])
			var meio := (p0 + p1) * 0.5; var comp := p0.distance_to(p1); var ang := atan2(p1.x - p0.x, p1.y - p0.y)
			var mi_t := Transform3D(Basis(Vector3.UP, ang), Vector3(meio.x, y, meio.y))
			var bx := _st(); _caixa(bx, Vector3(0, alt * 0.5 - 1.0, 0), Vector3(esp, alt + 2.0, comp)); st.append_from(bx.commit(), 0, mi_t)
			var n := int(comp / 2.4)
			for i in n:
				var am := _st(); _caixa(am, Vector3(0, alt + 0.6, -comp * 0.5 + (i + 0.5) * comp / n), Vector3(esp + 0.2, 1.2, 1.1))
				st_am.append_from(am.commit(), 0, mi_t)
			_colisor_caixa(Vector3(meio.x, y - 1.0, meio.y), Vector3(esp, alt + 2.0, comp), ang)
	_peca(st, pedra, Vector3.ZERO); _peca(st_am, pedra, Vector3.ZERO)
	# torres nos cantos, ao longo da muralha e dos dois lados de cada portão
	var torres := cantos.duplicate()
	for k in 4:
		var a: Vector2 = cantos[k]; var b: Vector2 = cantos[(k + 1) % 4]
		var n := int(a.distance_to(b) / 110.0)
		for i in range(1, n): torres.append(a.lerp(b, float(i) / n))
	for pt in portoes:
		var lado := Vector2(0, 1) if absf(pt.x - R.position.x) < 1.0 or absf(pt.x - R.end.x) < 1.0 else Vector2(1, 0)
		torres.append(pt + lado * 11.0); torres.append(pt - lado * 11.0)
	st = _st(); var st_t := _st()
	for t in torres:
		var tv: Vector2 = t
		var perto := false
		for pt in portoes: if tv.distance_to(pt) < 9.0: perto = true
		if perto: continue
		cilindro(st, Vector3(tv.x, y - 1.0, tv.y), 4.6, 4.2, 15.0, 8, true)
		cilindro(st_t, Vector3(tv.x, y + 14.0, tv.y), 5.4, 0.0, 6.0, 8)
		_colisor_cilindro(Vector3(tv.x, y - 1.0, tv.y), 4.4, 15.0)
	_peca(st, pedra_esc, Vector3.ZERO); _peca(st_t, mat("madeira", 1.0, Color(0.45, 0.32, 0.42)), Vector3.ZERO)
	# arcos sobre os portões
	st = _st()
	for pt in portoes:
		var vert := absf(pt.x - R.position.x) < 1.0 or absf(pt.x - R.end.x) < 1.0
		_caixa(st, Vector3(pt.x, y + alt - 0.5, pt.y), Vector3(esp + 1.0, 3.0, 17.0) if vert else Vector3(17.0, 3.0, esp + 1.0))
	_peca(st, pedra_esc, Vector3.ZERO)
	# castelo encostado nas montanhas (norte), com torre de menagem
	var cas := Vector2(c.x, R.position.y + 45.0)
	st = _st()
	_caixa(st, Vector3(cas.x, y + 8.0, cas.y), Vector3(60.0, 18.0, 36.0))
	_caixa(st, Vector3(cas.x, y + 16.0, cas.y - 4.0), Vector3(22.0, 32.0, 20.0))
	for q in [Vector2(-30, -18), Vector2(30, -18), Vector2(-30, 18), Vector2(30, 18)]:
		cilindro(st, Vector3(cas.x + q.x, y - 1.0, cas.y + q.y), 5.5, 5.0, 26.0, 8, true)
	_peca(st, pedra_esc, Vector3.ZERO)
	st = _st()
	for q in [Vector2(-30, -18), Vector2(30, -18), Vector2(-30, 18), Vector2(30, 18)]:
		cilindro(st, Vector3(cas.x + q.x, y + 25.0, cas.y + q.y), 6.4, 0.0, 9.0, 8)
	cilindro(st, Vector3(cas.x, y + 32.0, cas.y - 4.0), 15.0, 0.0, 10.0, 4)
	_peca(st, mat("madeira", 1.0, Color(0.32, 0.36, 0.55)), Vector3.ZERO)
	_colisor_caixa(Vector3(cas.x, y - 1.0, cas.y), Vector3(62.0, 34.0, 38.0), 0.0)
	# catedral (noroeste) com torre
	var cat := Vector2(R.position.x + 110.0, R.position.y + 90.0)
	_casa(Vector3(cat.x, y, cat.y), 0.0, 18.0, 34.0, 13.0, pedra, mat("madeira", 1.0, Color(0.4, 0.38, 0.48)), true)
	st = _st(); cilindro(st, Vector3(cat.x, y - 1.0, cat.y + 20.0), 4.0, 3.6, 26.0, 8, true); _peca(st, pedra, Vector3.ZERO)
	st = _st(); cilindro(st, Vector3(cat.x, y + 25.0, cat.y + 20.0), 4.6, 0.0, 12.0, 8); _peca(st, mat("madeira", 1.0, Color(0.4, 0.38, 0.48)), Vector3.ZERO)
	_colisor_cilindro(Vector3(cat.x, y - 1.0, cat.y + 20.0), 4.0, 26.0)
	# praça com chafariz no meio da cidade
	st = _st(); cilindro(st, Vector3(c.x, y - 0.3, c.y), 6.0, 6.0, 1.0, 12, true); cilindro(st, Vector3(c.x, y, c.y), 1.0, 0.8, 3.2, 8, true)
	cilindro(st, Vector3(c.x, y + 3.0, c.y), 2.6, 2.6, 0.4, 10, true); _peca(st, pedra_esc, Vector3.ZERO)
	_colisor_cilindro(Vector3(c.x, y - 0.3, c.y), 6.0, 1.2)
	var agua_ch := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(10.4, 10.4); agua_ch.mesh = pm
	var am := ShaderMaterial.new(); am.shader = load("res://shaders/agua.gdshader"); am.set_shader_parameter("neblina", NEBLINA)
	agua_ch.material_override = am; agua_ch.position = Vector3(c.x, y + 0.62, c.y); raiz.add_child(agua_ch)
	# quarteirões: casas de pedra e sobrados ao longo de ruas a cada ~42 m (fora da rua principal, da rua norte–sul,
	# da praça, do castelo e da catedral)
	var paredes := [mat("parede"), pedra, mat("parede", 1.0, Color(0.95, 0.88, 0.75))]
	var telhados := [mat("madeira", 1.0, Color(0.6, 0.28, 0.2)), mat("madeira", 1.0, Color(0.38, 0.38, 0.45)), mat("madeira", 1.0, Color(0.5, 0.33, 0.25))]
	var feitas := 0
	var zr := R.position.y + 16.0
	while zr < R.end.y - 10.0:
		var xr := R.position.x + 14.0
		while xr < R.end.x - 10.0:
			var q := Vector2(xr + rng.randf_range(-1.5, 1.5), zr + rng.randf_range(-1.5, 1.5))
			xr += rng.randf_range(15.0, 19.0)
			if absf(q.y - c.y) < 13.0 or absf(q.x - c.x) < 11.0: continue          # ruas principais
			if q.distance_to(c) < 30.0 or q.distance_to(cas) < 48.0 or q.distance_to(cat) < 30.0: continue
			if fmod(q.x - R.position.x, 42.0) < 7.0 or fmod(q.y - R.position.y, 46.0) < 7.0: continue   # ruas menores
			var w := rng.randf_range(8.0, 12.0); var d := rng.randf_range(7.0, 10.0); var hh := rng.randf_range(5.0, 9.0)   # sobrados maiores
			# porta virada para a rua principal mais perto
			var ang := 0.0 if q.y < c.y else PI
			if absf(q.x - c.x) < absf(q.y - c.y) * 0.6: ang = PI * 0.5 if q.x < c.x else -PI * 0.5
			var k := rng.randi() % 3
			_casa(Vector3(q.x, y, q.y), ang, w, d, hh, paredes[k], telhados[(k + rng.randi()) % 3], true)
			feitas += 1
		zr += rng.randf_range(16.0, 19.0)
	# cais do porto: tábuas sobre estacas saindo do portão leste até o mar, com dois navios
	var cais0 := Vector2(R.end.x + 4.0, c.y)
	while cais0.x < Regiao.X1 - 60.0 and altura(cais0.x, c.y) > 1.9: cais0.x += 2.0      # começa onde a areia acaba
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
	for braco in [-40.0, 40.0]:                    # dois braços do cais
		for i in 20: _caixa(st, Vector3(xm + 10.0, yc, c.y + braco * float(i) / 20.0 * (1.0 if braco > 0.0 else 1.0)), Vector3(6.0, 0.25, 2.2))
	_peca(st, mat("madeira"), Vector3.ZERO)
	_colisor_caixa(Vector3((cais0.x + xm + 30.0) * 0.5, yc - 0.15, c.y), Vector3(18.0, 0.3, xm + 30.0 - cais0.x), PI / 2)
	for nav in [[xm + 26.0, c.y - 24.0], [xm + 26.0, c.y + 26.0]]:
		st = _st()
		_caixa(st, Vector3(0, 0.8, 0), Vector3(18.0, 2.4, 5.0)); _caixa(st, Vector3(-7.0, 2.4, 0), Vector3(4.0, 1.2, 4.6))
		_caixa(st, Vector3(9.5, 1.2, 0), Vector3(2.0, 1.6, 3.0))
		_peca(st, mat("madeira", 1.0, Color(0.6, 0.45, 0.35)), Vector3(nav[0], 0.0, nav[1]))
		st = _st(); _caixa(st, Vector3(0, 9.0, 0), Vector3(0.5, 16.0, 0.5)); _peca(st, mat("madeira"), Vector3(nav[0], 0.0, nav[1]))
		st = _st(); _quad(st, Vector3(0.4, 4.5, -4.0), Vector3(0.4, 4.5, 4.0), Vector3(0.4, 15.0, 3.0), Vector3(0.4, 15.0, -3.0), 1, 1)
		_peca(st, mat("", 1.0, Color(0.92, 0.88, 0.78)), Vector3(nav[0], 0.0, nav[1]))
	# postes de luz na rua principal e na praça
	for i in 12:
		var x := R.position.x + 25.0 + i * (R.size.x - 50.0) / 11.0
		if absf(x - c.x) < 14.0: continue
		for lado in [-1.0, 1.0]:
			var q := Vector2(x, c.y + lado * 9.5)
			_poste_em(q, Vector2(x, c.y))
	lugares.append([c, R.size.length() * 0.5 + 10.0])
	if args.has("perf"): print("CIDADE: %d casas" % feitas)

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
	_barracas()
	_postes()

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
				lo.global_position = Vector3(q.x, altura_malha(q.x, q.y), q.y); lo.rotation.y = PI * 0.5
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
		if args.has("novos"): bolsa.pegar("escama_lodoso", 7); bolsa.pegar("presa_aranha", 3)
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
	if args.has("perf"):           # teste: mede o custo do quadro (draw calls, triângulos, tempo de script)
		for rep in 5: get_tree().create_timer(float(args.get("perf_t", "3")) + rep * 1.5).timeout.connect(func():
			var P := Performance
			print("PERF draw=%d objetos=%d prim=%d  process=%.1fms physics=%.1fms  nos=%d" % [
				P.get_monitor(P.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), P.get_monitor(P.RENDER_TOTAL_OBJECTS_IN_FRAME),
				P.get_monitor(P.RENDER_TOTAL_PRIMITIVES_IN_FRAME), P.get_monitor(P.TIME_PROCESS) * 1000.0,
				P.get_monitor(P.TIME_PHYSICS_PROCESS) * 1000.0, P.get_monitor(P.OBJECT_NODE_COUNT)]))
	if args.has("mapa"): get_tree().create_timer(1.5).timeout.connect(func(): mapa.alternar())
	if args.has("vista"): menu.aplicar_distancia(float(args.vista))
	if args.has("menu"): get_tree().create_timer(1.5).timeout.connect(func(): menu._abrir_config() if args.menu == "config" else menu._abrir_principal())
	if args.has("monstro"):        # teste: um monstro parado na frente da câmera numa animação (--monstro=golem --manim=soco:0.6)
		var pj := Vector2(-30, 62); var tp: String = args.monstro
		if args.has("mpos"): var mp := String(args.mpos).split(","); pj = Vector2(float(mp[0]), float(mp[1]))
		jogador.global_position = Vector3(pj.x, altura(pj.x, pj.y) + 0.3, pj.y + float(args.get("dist", "6")))
		jogador.rotation.y = 0.0; jogador.mao.visible = false; jogador.set_physics_process(false)
		jogador.pescoco.rotation.x = float(args.get("inclina", "0"))
		var mo: Node3D
		if tp == "aranha": mo = Aranha.new()
		else: mo = Monstro.new()
		mo.grupo = {"casa": pj, "membros": [mo], "alerta": false}
		raiz.add_child(mo); mo.position = Vector3(pj.x, altura_malha(pj.x, pj.y), pj.y)
		if tp == "aranha": mo.montar(self, 4, 1)
		else: mo.montar(self, tp, 3, 1)
		mo.rotation.y = deg_to_rad(float(args.get("giro_m", "90")))
		mo.anim_fixa = String(args.get("manim", "andar"))
		if tp == "golem": golem = mo; mo.grupo.alerta = true
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
			"cidade": alvo = Vector2(Regiao.CIDADE.position.x - 90.0, cidade_pos.y + 25.0); olha = cidade_pos
			"praca": alvo = cidade_pos + Vector2(-40, 8); olha = cidade_pos + Vector2(0, -60)
			"porto_cidade": alvo = Vector2(Regiao.CIDADE.end.x + 22.0, cidade_pos.y + 30.0); olha = Vector2(Regiao.CIDADE.end.x + 120.0, cidade_pos.y - 10.0)
			"portao_leste": alvo = Vector2(Regiao.CIDADE.end.x + 30.0, cidade_pos.y + 4.0); olha = Vector2(Regiao.CIDADE.end.x - 40.0, cidade_pos.y)
			"alto": alvo = cidade_pos + Vector2(-260, 230); olha = cidade_pos
		jogador.global_position = Vector3(alvo.x, altura(alvo.x, alvo.y) + 0.3, alvo.y); _ultima = jogador.global_position
		var dd := olha - alvo; jogador.rotation.y = atan2(-dd.x, -dd.y)
		if String(args.ir) == "alto": jogador.global_position.y += 60.0; jogador.set_physics_process(false); jogador.pescoco.rotation.x = -0.35
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
	await get_tree().create_timer(float(args.get("espera", "2"))).timeout
	get_viewport().get_texture().get_image().save_png(args.shot)
	get_tree().quit()

# Modelos da Synty (pacote POLYGON Fantasy Kingdom, comprado pelo dono). Os arquivos ficam em res://arte/fk, uma
# pasta FORA do repositório público (vem de um repositório privado; o GitHub Actions baixa na hora de gerar o jogo).
# Cada modelo vira peças MeshInstance3D soltas na raiz do mundo com UM material só (a textura-atlas da Synty no
# shader do mundo: luz do dia/noite e neblina iguais ao resto); o _juntar_estaticos do mundo junta tudo por região.
# Colisão: a malha "_Collision" que vem com as construções prontas, ou uma caixa do tamanho do modelo.
class_name Synty

const PASTA := "res://arte/fk/modelos/"
const ATLAS := "res://arte/fk/texturas/PolygonFantasyKingdom_Texture_01_A.png"
static var _pecas := {}          # nome → [[malha, transform local], ...]
static var _caixas := {}         # nome → AABB (no espaço do modelo)
static var _mat: ShaderMaterial
static var _mats := {}            # tipo de superfície → material
const CEL := 96.0                 # tamanho do pedaço do mapa (m) em que as peças repetidas são agrupadas
const PERTO := 85.0               # até aqui a versão completa; depois a simplificada
static var _lote := {}            # [pedaço, malha, tipo, modo] → [malha, [transform, ...]]
# superfícies do castelo (shader "CastleSHD" no Unity): textura de tijolos que se repete; o resto usa o atlas
const TEXTURAS := {"castelo": "res://arte/fk/texturas/PolygonFantasyKingdon_Texture_Wall_Brick_01.png"}

# Segundo pacote: POLYGON Meadow Forest (natureza). Nome com o prefixo "MF:". Cada parte tem a sua textura (folhas
# recortadas pela transparência); o mapa nó → material saiu dos prefabs do pacote (arte/mf/mapa_materiais.json).
const PASTA_MF := "res://arte/mf/modelos/"
static var _mf_mapa = null
static var _mf_mats = null
static func _arq(nome: String) -> String:
	return PASTA_MF + nome.trim_prefix("MF:") + ".fbx" if nome.begins_with("MF:") else PASTA + nome + ".fbx"
static func existe(nome: String) -> bool:
	return ResourceLoader.exists(_arq(nome))
static func _tipo_mf(no: String) -> String:
	if _mf_mapa == null:
		_mf_mapa = JSON.parse_string(FileAccess.get_file_as_string("res://arte/mf/mapa_materiais.json"))
		_mf_mats = JSON.parse_string(FileAccess.get_file_as_string("res://arte/mf/materiais.json"))
	var mat := "PolygonNatureBiomesMeadow_Mat_01"
	if _mf_mapa.has(no): mat = _mf_mapa[no][0]
	elif "Grass_Short" in no: return "mf:Grass_Short_01.tga|1"        # (sem prefab: textura da grama pelo nome)
	elif "Grass_Med" in no or "Grass_Bush" in no: return "mf:Grass_Mid_01.tga|1"
	var info = _mf_mats.get(mat, null)
	if info == null or info.tex == null: return "mf:PolygonNatureBiomes_Meadow_Texture_01.png|0"
	return "mf:%s|%d" % [info.tex, 1 if info.alfa and not String(info.tex).begins_with("PolygonNature") else 0]

static func material(neblina: Color, tipo := "atlas") -> ShaderMaterial:
	if _mats.has(tipo): return _mats[tipo]
	var mt := ShaderMaterial.new(); mt.shader = load("res://shaders/ps1.gdshader")
	if tipo.begins_with("mf:"):
		var pz := tipo.trim_prefix("mf:").split("|")
		mt.set_shader_parameter("tex", load("res://arte/mf/texturas/" + pz[0])); mt.set_shader_parameter("corte", pz[1] == "1")
	else: mt.set_shader_parameter("tex", load(TEXTURAS.get(tipo, ATLAS)))
	if tipo == "atlas" and ResourceLoader.exists("res://arte/fk/texturas/PolygonFantasyKingdom_Texture_Emmisive.png"):   # janelas acesas à noite
		mt.set_shader_parameter("usa_brilho", true); mt.set_shader_parameter("tex_brilho", load("res://arte/fk/texturas/PolygonFantasyKingdom_Texture_Emmisive.png"))
	mt.set_shader_parameter("neblina", neblina)
	if tipo == "longe": mt.set_shader_parameter("usa_tex", false)
	if tipo == "tronco": mt.set_shader_parameter("usa_tex", false); mt.set_shader_parameter("cor", Color(0.52, 0.37, 0.25))
	if tipo == "personagem": mt.set_shader_parameter("sem_cor_vertice", true)          # versão de longe: só a cor dos vértices
	_mats[tipo] = mt
	return mt

static func _tipo(m: Material) -> String:
	var n := m.resource_name.to_lower() if m else ""
	return "atlas"                  # (o tijolo do castelo vai pelo nome do modelo: SM_Bld_Castle_*)

# peças (malha + transform relativo à raiz do arquivo) e a caixa que envolve o modelo
static func pecas(nome: String) -> Array:
	if _pecas.has(nome): return _pecas[nome]
	var lista := []; var cx := AABB(); var primeiro := true
	if existe(nome):
		var n: Node3D = load(_arq(nome)).instantiate()
		var base := n.transform.affine_inverse()
		var mf := nome.begins_with("MF:")
		for c in n.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = c
			if mf and "_LOD" in mi.name and not mi.name.ends_with("_LOD0"): continue      # só o nível mais detalhado
			var t: Transform3D = base * _global(mi, n)
			# uma malha por superfície (cada uma com o seu material: atlas ou tijolo do castelo)
			for si in mi.mesh.get_surface_count():
				var arr: Array = mi.mesh.surface_get_arrays(si)
				var tp := _tipo_mf(mi.name) if mf else ("castelo" if nome.begins_with("SM_Bld_Castle_") else _tipo(mi.mesh.surface_get_material(si)))
				# árvores do Meadow Forest: tronco e folhas na mesma malha (no Unity o shader separa pela cor do vértice:
				# verde e azul = 0 é madeira). Aqui viram duas malhas: folhas com a textura de folha, tronco com a casca
				# (bétula: a textura branca; as outras: marrom liso — o marrom do atlas fica quase preto com a nossa luz).
				var tronco := []
				if mf and "_Tree_" in mi.name and not "Branches" in mi.name and arr[Mesh.ARRAY_COLOR] != null:
					var sep := _separar_tronco(arr)
					if not sep[1].is_empty(): tronco = _sub(arr, sep[1]); arr = _sub(arr, sep[0])
				arr[Mesh.ARRAY_COLOR] = null           # a Synty guarda o "vento" nas cores dos vértices (deixava as árvores pretas)
				for ai in [Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS, Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]: arr[ai] = null
				var am := ArrayMesh.new(); am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
				lista.append([am, t, tp])
				if not tronco.is_empty():
					tronco[Mesh.ARRAY_COLOR] = null
					var amt := ArrayMesh.new(); amt.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tronco)
					lista.append([amt, t, "mf:Birch_Trunk_Texture.png|0" if "Birch" in mi.name else "tronco"])
			var b: AABB = t * mi.mesh.get_aabb()
			cx = b if primeiro else cx.merge(b); primeiro = false
		n.free()
	_pecas[nome] = lista; _caixas[nome] = cx
	return lista

# triângulos das folhas e do tronco (os três vértices com verde e azul ≈ 0 = madeira)
static func _separar_tronco(arr: Array) -> Array:
	var cor: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var idx = arr[Mesh.ARRAY_INDEX]
	if idx == null:
		idx = PackedInt32Array(); idx.resize(cor.size())
		for i in cor.size(): idx[i] = i
	var folhas := PackedInt32Array(); var tronco := PackedInt32Array()
	for i in range(0, idx.size(), 3):
		var madeira := true
		for j in 3:
			var c := cor[idx[i + j]]
			if c.g > 0.5 or c.b > 0.5: madeira = false
		var alvo := tronco if madeira else folhas
		alvo.append(idx[i]); alvo.append(idx[i + 1]); alvo.append(idx[i + 2])
	return [folhas, tronco]

# malha nova só com esses vértices (sem índice: cada triângulo com os seus três)
static func _sub(arr: Array, idx: PackedInt32Array) -> Array:
	var r := []; r.resize(Mesh.ARRAY_MAX)
	var v := PackedVector3Array(); var nm := PackedVector3Array(); var uv := PackedVector2Array(); var cr := PackedColorArray()
	var tem_n: bool = arr[Mesh.ARRAY_NORMAL] != null; var tem_uv: bool = arr[Mesh.ARRAY_TEX_UV] != null
	for i in idx:
		v.append(arr[Mesh.ARRAY_VERTEX][i])
		if tem_n: nm.append(arr[Mesh.ARRAY_NORMAL][i])
		if tem_uv: uv.append(arr[Mesh.ARRAY_TEX_UV][i])
		cr.append(arr[Mesh.ARRAY_COLOR][i])
	r[Mesh.ARRAY_VERTEX] = v; r[Mesh.ARRAY_COLOR] = cr
	if tem_n: r[Mesh.ARRAY_NORMAL] = nm
	if tem_uv: r[Mesh.ARRAY_TEX_UV] = uv
	return r

static func _global(no: Node3D, raiz: Node3D) -> Transform3D:      # transform até a raiz (fora da árvore)
	var t := no.transform; var p := no.get_parent()
	while p != null and p != raiz.get_parent():
		if p is Node3D: t = (p as Node3D).transform * t
		if p == raiz: break
		p = p.get_parent()
	return t

static func caixa(nome: String) -> AABB:
	pecas(nome); return _caixas.get(nome, AABB())

# põe o modelo no mundo. "centro": a posição é o centro da base (senão é a origem do arquivo).
# Devolve a caixa ocupada no chão (para os vizinhos).
static func por(m: Object, nome: String, pos: Vector3, ang: float, esc := 1.0, colisao := true, centro := true) -> void:
	por3(m, nome, pos, ang, Vector3.ONE * esc, colisao, centro)

# o mesmo com escala diferente em cada eixo (muralhas e pontes esticadas)
static func por3(m: Object, nome: String, pos: Vector3, ang: float, esc: Vector3, colisao := true, centro := true) -> void:
	var ps := pecas(nome)
	if ps.is_empty(): return
	var cx: AABB = _caixas[nome]
	var desl := Vector3.ZERO
	if centro: desl = -Vector3(cx.get_center().x, 0.0, cx.get_center().z)
	var t := Transform3D(Basis(Vector3.UP, ang) * Basis.from_scale(esc), pos) * Transform3D(Basis(), desl)
	# as peças vão para o lote do pedaço do mapa (juntadas no fim por finalizar(): perto a completa, longe a simples)
	var cel := Vector2i(floori(pos.x / CEL), floori(pos.z / CEL))
	# construções com versão de longe (ferramentas/longe_fk.gd): perto o modelo completo, longe a colisão pintada
	var lg := "res://arte/fk/longe/%s.res" % nome
	var tem_longe := ResourceLoader.exists(lg)
	for p in ps: _no_lote(cel, p[0], p[2], 1 if tem_longe else 0, t * (p[1] as Transform3D))
	if tem_longe: _no_lote(cel, load(lg), "longe", 2, t)
	if not colisao: return
	var corpo := StaticBody3D.new(); m.raiz.add_child(corpo)
	var col := nome + "_Collision"
	if existe(col):
		for p in pecas(col):
			var cs := CollisionShape3D.new(); var sh := ConcavePolygonShape3D.new()
			sh.set_faces((p[0] as Mesh).get_faces()); sh.backface_collision = true; cs.shape = sh
			cs.transform = t * (p[1] as Transform3D); corpo.add_child(cs)
	else:
		var cs := CollisionShape3D.new(); var bx := BoxShape3D.new()
		bx.size = cx.size * esc; cs.shape = bx
		cs.transform = Transform3D(Basis(Vector3.UP, ang), t * cx.get_center())
		corpo.add_child(cs)

# casas prontas do pacote (a porta fica para +Z, como nas casas antigas do jogo)
const CASAS := ["SM_Bld_Preset_House_01_A_Optimized", "SM_Bld_Preset_House_02_A_Optimized", "SM_Bld_Preset_House_03_Optimized",
	"SM_Bld_Preset_House_04_Optimized", "SM_Bld_Preset_House_05_Optimized", "SM_Bld_Preset_House_06_Optimized",
	"SM_Bld_Preset_House_07_Optimized", "SM_Bld_Preset_House_08_Optimized", "SM_Bld_Preset_House_09_A_Optimized",
	"SM_Bld_Preset_House_09_B_Optimized", "SM_Bld_Preset_House_09_C_Optimized", "SM_Bld_Preset_Hut_01_Optimized"]
# a casa que melhor ocupa w × d (entre as 3 mais parecidas, uma escolhida pela semente)
static func casa_para(w: float, d: float, semente: int) -> String:
	var notas := []
	for n in CASAS:
		var cx := caixa(n)
		if cx.size == Vector3.ZERO: continue
		notas.append([absf(cx.size.x - w) + absf(cx.size.z - d), n])
	if notas.is_empty(): return ""
	notas.sort_custom(func(a, b): return a[0] < b[0])
	return notas[absi(semente) % mini(3, notas.size())][1]

# o modelo inteiro numa malha só (uma superfície, material do atlas) para MultiMesh (árvores, arbustos, grama).
# "esc" muda o tamanho base; "variante" escolhe entre vários nomes.
static var _malhas := {}
static func malha(nome: String, neblina: Color, esc := 1.0) -> ArrayMesh:
	var k := "%s|%s" % [nome, esc]
	if _malhas.has(k): return _malhas[k]
	var por_tipo := {}
	for p in pecas(nome):
		if not por_tipo.has(p[2]): por_tipo[p[2]] = SurfaceTool.new(); por_tipo[p[2]].begin(Mesh.PRIMITIVE_TRIANGLES)
		por_tipo[p[2]].append_from(p[0], 0, Transform3D(Basis.from_scale(Vector3.ONE * esc), Vector3.ZERO) * (p[1] as Transform3D))
	if por_tipo.is_empty(): return null
	var am := ArrayMesh.new()
	for tp in por_tipo.keys():
		por_tipo[tp].commit(am); am.surface_set_material(am.get_surface_count() - 1, material(neblina, tp))
	_malhas[k] = am
	return am

# desenha as peças postas, por pedaço do mapa: cada peça repetida vira um MultiMesh (a malha vai uma vez só para a
# placa de vídeo) — perto a completa, longe a simplificada. Montar é instantâneo (antes juntava tudo: 12 s).
# modo: 0 sempre, 1 só perto, 2 só longe
# põe o modelo com a transformação exata (cenas montadas pela Synty). col: "colisao" (a malha _Collision do pacote),
# "malha" (a própria malha), "caixa" (caixa do tamanho do modelo), "tronco" (cilindro fino: árvores) ou "" (nada).
# vis: 0 sempre; 3 até 45 m; 4 até 95 m (objetos pequenos somem de longe: o celular agradece)
static var _faces := {}           # pedaço do mapa → faces de colisão (juntadas num corpo só por pedaço)
static var _corpos := {}          # pedaço do mapa → StaticBody3D das caixas
static func por_t(m: Object, nome: String, T: Transform3D, col := "", vis := 0) -> void:
	var ps := pecas(nome)
	if ps.is_empty(): return
	var cel := Vector2i(floori(T.origin.x / CEL), floori(T.origin.z / CEL))
	var cv := cel if vis == 0 else Vector2i(floori(T.origin.x / 24.0), floori(T.origin.z / 24.0))     # some junto com o grupinho dele
	for p in ps: _no_lote(cv, p[0], p[2], vis, T * (p[1] as Transform3D))
	if col == "": return
	if col == "colisao" and not existe(nome + "_Collision"): col = "malha"
	if col == "colisao" or col == "malha":
		if not _faces.has(cel): _faces[cel] = PackedVector3Array()
		var fs: PackedVector3Array = _faces[cel]
		for p in pecas(nome + "_Collision" if col == "colisao" else nome):
			var TT: Transform3D = T * (p[1] as Transform3D)
			for v in (p[0] as Mesh).get_faces(): fs.append(TT * v)
		_faces[cel] = fs
		return
	if not _corpos.has(cel):
		var cb := StaticBody3D.new(); m.raiz.add_child(cb); _corpos[cel] = cb
	var cx: AABB = _caixas[nome]
	var esc := Vector3(T.basis.x.length(), T.basis.y.length(), T.basis.z.length())
	var cs := CollisionShape3D.new()
	if col == "tronco":
		var cil := CylinderShape3D.new(); cil.radius = 0.35 * esc.x; cil.height = 4.0 * esc.y; cs.shape = cil
		cs.transform = Transform3D(Basis(), T.origin + Vector3(0, cil.height * 0.5, 0))
	else:
		var bx := BoxShape3D.new(); bx.size = (cx.size * esc).max(Vector3.ONE * 0.1); cs.shape = bx
		cs.transform = Transform3D(T.basis.orthonormalized(), T * cx.get_center())
	(_corpos[cel] as StaticBody3D).add_child(cs)

static func _no_lote(cel: Vector2i, malha: Mesh, tipo: String, modo: int, t: Transform3D) -> void:
	var k := [cel, malha.get_instance_id(), tipo, modo]
	if not _lote.has(k): _lote[k] = [malha, []]
	_lote[k][1].append(t)

static func finalizar(m: Object) -> void:
	for k in _lote.keys():
		var malha: Mesh = _lote[k][0]; var lista: Array = _lote[k][1]
		var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = malha; mm.instance_count = lista.size()
		for i in lista.size(): mm.set_instance_transform(i, lista[i])
		var mi := MultiMeshInstance3D.new(); mi.multimesh = mm; mi.material_override = material(m.NEBLINA, k[2])
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if k[3] == 1: mi.visibility_range_end = PERTO
		elif k[3] == 2: mi.visibility_range_begin = PERTO
		elif k[3] == 3: mi.visibility_range_end = 45.0
		elif k[3] == 4: mi.visibility_range_end = 95.0
		m.raiz.add_child(mi)
	_lote.clear()
	for cel in _faces.keys():
		var cb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var sh := ConcavePolygonShape3D.new()
		sh.set_faces(_faces[cel]); sh.backface_collision = true; cs.shape = sh; cb.add_child(cs); m.raiz.add_child(cb)
	_faces.clear(); _corpos.clear()

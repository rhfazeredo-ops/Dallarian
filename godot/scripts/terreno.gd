# Terreno da região em pedaços de 64 m:
#  - versão simples (células de 8 m) de todos os pedaços, sempre montada, para ver longe (some quando perto);
#  - versão detalhada (células de 2 m, com colisão) só dos pedaços perto do jogador, montada enquanto ele anda.
# As alturas detalhadas ficam guardadas por pedaço, para pôr grama, splats e árvores exatamente no chão.
extends Node3D
class_name Terreno

const PED := 64.0
const CEL := 32
const PASSO := PED / CEL
const RAIO := 140.0          # pedaços detalhados até aqui (distância do centro do pedaço)
const LONGE := 125.0         # a versão simples só aparece a partir daqui
var m
var reg: Regiao
var _alt := {}               # Vector2i → PackedFloat32Array (CEL+1)²
var ativos := {}
var _primeira := true

func montar(mundo) -> void:
	m = mundo; reg = mundo.reg
	_nx = int(ceil((Regiao.X1 - Regiao.X0) / PED)); _nz = int(ceil((Regiao.Z1 - Regiao.Z0) / PED))
	# terreno de longe do mapa inteiro: as alturas e cores vêm PRONTAS no APK (dados/terreno_longe.bin, gerado no
	# GitHub a cada versão); sem o arquivo (ou gerando), calcula tudo em paralelo em todos os núcleos
	if m.args.has("gerar_terreno"): _gerar_arquivo(); return
	_ler_pronto()
	var blocos := []
	for j in range(0, _nz, 2): for i in range(0, _nx, 2): blocos.append(Vector2i(i, j))
	var caixas := []
	for b in blocos: caixas.append([null])
	var grupo := WorkerThreadPool.add_group_task(func(idx: int): caixas[idx][0] = _bloco_arrays(blocos[idx]), blocos.size(), -1, true, "terreno de longe")
	var _t0 := Time.get_ticks_msec()
	WorkerThreadPool.wait_for_group_task_completion(grupo)
	var _t1 := Time.get_ticks_msec()
	for idx in blocos.size(): _simples_bloco_de(blocos[idx], caixas[idx][0])
	if m.args.has("carga"): print("CARGA  terreno calculo ", _t1 - _t0, " malhas ", Time.get_ticks_msec() - _t1, " blocos ", blocos.size())

const ARQ_PRONTO := "res://dados/terreno_longe.bin"
const VERSAO_PRONTO := 1
var _pronto := {}                 # Vector2i → [alturas, cores] dos pedaços de longe
func _ler_pronto() -> void:
	if m.args.has("sem_pronto") or not FileAccess.file_exists(ARQ_PRONTO): return
	var f := FileAccess.open_compressed(ARQ_PRONTO, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if f == null: return
	var d = f.get_var()
	if not d is Dictionary or int(d.get("versao", 0)) != VERSAO_PRONTO or int(d.get("nx", 0)) != _nx or int(d.get("nz", 0)) != _nz: return
	var hs: Array = d.hs; var cs: Array = d.cores
	for j in _nz: for i in _nx:
		var idx := j * _nx + i
		_pronto[Vector2i(i, j)] = [hs[idx], cs[idx]]

# roda no GitHub antes de exportar: calcula as grades de todos os pedaços de longe (em paralelo) e grava o arquivo
func _gerar_arquivo() -> void:
	var t0 := Time.get_ticks_msec()
	var n := _nx * _nz
	var caixas := []
	for i in n: caixas.append([null])
	var g := WorkerThreadPool.add_group_task(func(idx: int): caixas[idx][0] = _grade(Vector2i(idx % _nx, idx / _nx), 8, true), n, -1, true, "gerar terreno")
	WorkerThreadPool.wait_for_group_task_completion(g)
	var hs := []; var cs := []
	for c in caixas: hs.append(c[0][0]); cs.append(c[0][1])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://dados"))
	var f := FileAccess.open_compressed(ProjectSettings.globalize_path(ARQ_PRONTO), FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	f.store_var({"versao": VERSAO_PRONTO, "nx": _nx, "nz": _nz, "hs": hs, "cores": cs}); f.close()
	print("TERRENO PRONTO: %d pedaços em %d ms" % [n, Time.get_ticks_msec() - t0])
	m.get_tree().quit()

var _nx := 0
var _nz := 0
func _origem(k: Vector2i) -> Vector2: return Vector2(Regiao.X0 + k.x * PED, Regiao.Z0 + k.y * PED)
func pedaco(x: float, z: float) -> Vector2i:
	return Vector2i(int(floor((x - Regiao.X0) / PED)), int(floor((z - Regiao.Z0) / PED)))

var _mx := Mutex.new()            # o cache de alturas é lido/escrito também pelas obras em segundo plano
func alturas(k: Vector2i) -> PackedFloat32Array:
	_mx.lock(); var tem = _alt.get(k); _mx.unlock()
	if tem != null: return tem
	var o := _origem(k); var a := PackedFloat32Array(); a.resize((CEL + 1) * (CEL + 1))
	for j in CEL + 1: for i in CEL + 1: a[j * (CEL + 1) + i] = reg.altura(o.x + i * PASSO, o.y + j * PASSO)
	_mx.lock(); _alt[k] = a; _mx.unlock(); return a

# altura exata da malha detalhada (mesma divisão dos triângulos)
func altura_malha(x: float, z: float) -> float:
	var k := pedaco(x, z); var a := alturas(k); var o := _origem(k)
	var fx := (x - o.x) / PASSO; var fz := (z - o.y) / PASSO
	var i := clampi(int(floor(fx)), 0, CEL - 1); var j := clampi(int(floor(fz)), 0, CEL - 1)
	var u := clampf(fx - i, 0.0, 1.0); var v := clampf(fz - j, 0.0, 1.0)
	var ha := a[j * (CEL + 1) + i]; var hb := a[j * (CEL + 1) + i + 1]
	var hc := a[(j + 1) * (CEL + 1) + i + 1]; var hd := a[(j + 1) * (CEL + 1) + i]
	if u > v: return ha + (hb - ha) * u + (hc - hb) * v
	return ha + (hd - ha) * v + (hc - hd) * u

func normal_malha(x: float, z: float) -> Vector3:
	var e := 0.5
	return Vector3(-(altura_malha(x + e, z) - altura_malha(x - e, z)), 2.0 * e, -(altura_malha(x, z + e) - altura_malha(x, z - e))).normalized()

func _process(_d: float) -> void:
	if m.jogador == null: return
	var jp: Vector3 = m.jogador.global_position; var p := Vector2(jp.x, jp.z)
	var orc := 1000000 if _primeira else 1
	_primeira = false
	var c := pedaco(p.x, p.y); var r := int(ceil(RAIO / PED)) + 1
	var faltam := []
	for j in range(c.y - r, c.y + r + 1):
		for i in range(c.x - r, c.x + r + 1):
			var k := Vector2i(i, j)
			var d := (_origem(k) + Vector2(PED, PED) * 0.5).distance_to(p)
			if d < RAIO and not ativos.has(k) and i >= 0 and j >= 0 and i < _nx and j < _nz:
				faltam.append([d, k])
	faltam.sort_custom(func(a, b): return a[0] < b[0])
	for pr in obras.prontos():                                   # pedaços prontos em segundo plano: põe na tela
		var kr: Vector2i = pr[0]
		if ativos.has(kr) or (_origem(kr) + Vector2(PED, PED) * 0.5).distance_to(p) > RAIO + 50.0: continue
		ativos[kr] = _detalhado_de(kr, pr[1])
	for f in faltam:
		if orc > 100: ativos[f[1]] = _detalhado(f[1]); continue        # começo do jogo: na hora
		if obras.pendente(f[1]) or obras.cheio(): continue
		var kk: Vector2i = f[1]
		obras.pedir(kk, func(): return _malha_arrays(kk, CEL, false))
	for k in ativos.keys():
		if (_origem(k) + Vector2(PED, PED) * 0.5).distance_to(p) > RAIO + 50.0:
			ativos[k].queue_free(); ativos.erase(k)

func _malha(k: Vector2i, cel: int, desce: bool) -> ArrayMesh:
	var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _malha_arrays(k, cel, desce)); return mesh

# os arrays da malha de um pedaço (roda fora do quadro principal: só lê o mapa)
func _malha_arrays(k: Vector2i, cel: int, desce: bool) -> Array:
	var g := _grade(k, cel, desce)
	return _arrays_de_grade(k, cel, g[0], g[1])

# alturas e cores dos pontos da grade de um pedaço (a parte cara: muitas contas do relevo)
func _grade(k: Vector2i, cel: int, desce: bool) -> Array:
	var o := _origem(k); var passo := PED / cel
	var hs := PackedFloat32Array(); hs.resize((cel + 1) * (cel + 1))
	var a := alturas(k) if not desce else PackedFloat32Array()
	for j in cel + 1: for i in cel + 1:
		var x := o.x + i * passo; var z := o.y + j * passo
		var h := a[j * (CEL + 1) + i] if not desce else reg.altura(x, z) - 0.55
		if desce and (reg.dist_rio(x, z) < 16.0 or abs(Vector2(x - Regiao.LAGO.x, z - Regiao.LAGO.y).length()) < Regiao.LAGO.z + 8.0): h -= 2.5
		hs[j * (cel + 1) + i] = h
	var cores := []; cores.resize((cel + 1) * (cel + 1))
	for j in cel + 1: for i in cel + 1:
		var x := o.x + i * passo; var z := o.y + j * passo
		var hx := hs[j * (cel + 1) + min(i + 1, cel)] - hs[j * (cel + 1) + max(i - 1, 0)]
		var hz := hs[min(j + 1, cel) * (cel + 1) + i] - hs[max(j - 1, 0) * (cel + 1) + i]
		var ny := Vector3(-hx, 2.0 * passo, -hz).normalized().y
		cores[j * (cel + 1) + i] = reg.cor(x, z, hs[j * (cel + 1) + i], ny)
	return [hs, PackedColorArray(cores)]

# os triângulos do pedaço a partir da grade (rápido)
func _arrays_de_grade(k: Vector2i, cel: int, hs: PackedFloat32Array, cores: PackedColorArray) -> Array:
	var o := _origem(k); var passo := PED / cel
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cx := PED * 0.5
	for j in cel: for i in cel:
		var id := [j * (cel + 1) + i, j * (cel + 1) + i + 1, (j + 1) * (cel + 1) + i + 1, (j + 1) * (cel + 1) + i]
		var vs := []
		for q in 4:
			var ii: int = [i, i + 1, i + 1, i][q]; var jj: int = [j, j, j + 1, j + 1][q]
			vs.append(Vector3(ii * passo - cx, hs[id[q]], jj * passo - cx))
		for tri in [[0, 2, 1], [0, 3, 2]]:
			var nrm: Vector3 = (vs[tri[1]] - vs[tri[0]]).cross(vs[tri[2]] - vs[tri[0]]).normalized()
			if nrm.y < 0: nrm = -nrm
			for q in tri:
				st.set_normal(nrm); st.set_color(cores[id[q]])
				st.set_uv(Vector2(vs[q].x + o.x, vs[q].z + o.y) / 4.0); st.add_vertex(vs[q])
	return st.commit_to_arrays()

# versão simples em blocos de 2×2 pedaços (128 m): 4× menos objetos para desenhar ao longe
# os 4 pedaços simples de um bloco 2×2 juntos num só conjunto de arrays (roda fora do quadro principal)
func _bloco_arrays(b: Vector2i) -> Array:
	var centro := _origem(b) + Vector2(PED, PED)
	var vs := PackedVector3Array(); var ns := PackedVector3Array(); var cs := PackedColorArray(); var uvs := PackedVector2Array()
	for dj in 2:
		for di in 2:
			var k := Vector2i(b.x + di, b.y + dj)
			if k.x >= _nx or k.y >= _nz: continue
			var c := _origem(k) + Vector2(PED, PED) * 0.5 - centro
			var a: Array
			if _pronto.has(k): a = _arrays_de_grade(k, 8, _pronto[k][0], _pronto[k][1])     # veio pronto no APK
			else: a = _malha_arrays(k, 8, true)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			for q in v.size(): v[q] += Vector3(c.x, 0, c.y)
			vs.append_array(v); ns.append_array(a[Mesh.ARRAY_NORMAL]); cs.append_array(a[Mesh.ARRAY_COLOR]); uvs.append_array(a[Mesh.ARRAY_TEX_UV])
	var r := []; r.resize(Mesh.ARRAY_MAX)
	r[Mesh.ARRAY_VERTEX] = vs; r[Mesh.ARRAY_NORMAL] = ns; r[Mesh.ARRAY_COLOR] = cs; r[Mesh.ARRAY_TEX_UV] = uvs
	return r

func _simples_bloco_de(b: Vector2i, arrays: Array) -> void:
	if (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty(): return
	var centro := _origem(b) + Vector2(PED, PED)
	var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new(); mi.mesh = mesh; mi.material_override = m.mat("terreno")
	mi.position = Vector3(centro.x, 0, centro.y)
	mi.visibility_range_begin = LONGE - 35.0
	add_child(mi)

var obras := Obras.new()
func _detalhado(k: Vector2i) -> Node3D: return _detalhado_de(k, _malha_arrays(k, CEL, false))
func _detalhado_de(k: Vector2i, arrays: Array) -> Node3D:
	var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new(); mi.mesh = mesh; mi.material_override = m.mat("terreno")
	mi.position = Vector3(_origem(k).x + PED * 0.5, 0, _origem(k).y + PED * 0.5)
	var corpo := StaticBody3D.new(); var cs := CollisionShape3D.new()
	var forma := ConcavePolygonShape3D.new(); forma.set_faces(arrays[Mesh.ARRAY_VERTEX]); forma.backface_collision = true
	cs.shape = forma; corpo.add_child(cs); mi.add_child(corpo)
	add_child(mi); return mi


func _exit_tree() -> void: obras.esperar_tudo()          # nenhuma tarefa em segundo plano fica rodando ao fechar

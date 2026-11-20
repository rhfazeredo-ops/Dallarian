# Terreno da região em pedaços de 64 m:
#  - versão simples (células de 8 m) de todos os pedaços, sempre montada, para ver longe (some quando perto);
#  - versão detalhada (células de 2 m, com colisão) só dos pedaços perto do jogador, montada enquanto ele anda.
# As alturas detalhadas ficam guardadas por pedaço, para pôr grama, splats e árvores exatamente no chão.
extends Node3D
class_name Terreno

const PED := 64.0
const CEL := 32
const PASSO := PED / CEL
const RAIO := 170.0          # pedaços detalhados até aqui (distância do centro do pedaço)
const LONGE := 125.0         # a versão simples só aparece a partir daqui
var m
var reg: Regiao
var _alt := {}               # Vector2i → PackedFloat32Array (CEL+1)²
var ativos := {}
var _primeira := true

func montar(mundo) -> void:
	m = mundo; reg = mundo.reg
	var n := int(ceil(2.0 * Regiao.LIM / PED))
	for j in n: for i in n: _simples(Vector2i(i, j))

func _origem(k: Vector2i) -> Vector2: return Vector2(k.x * PED - Regiao.LIM, k.y * PED - Regiao.LIM)
func pedaco(x: float, z: float) -> Vector2i:
	return Vector2i(int(floor((x + Regiao.LIM) / PED)), int(floor((z + Regiao.LIM) / PED)))

func alturas(k: Vector2i) -> PackedFloat32Array:
	if _alt.has(k): return _alt[k]
	var o := _origem(k); var a := PackedFloat32Array(); a.resize((CEL + 1) * (CEL + 1))
	for j in CEL + 1: for i in CEL + 1: a[j * (CEL + 1) + i] = reg.altura(o.x + i * PASSO, o.y + j * PASSO)
	_alt[k] = a; return a

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
			if d < RAIO and not ativos.has(k) and i >= 0 and j >= 0 and i * PED < 2.0 * Regiao.LIM and j * PED < 2.0 * Regiao.LIM:
				faltam.append([d, k])
	faltam.sort_custom(func(a, b): return a[0] < b[0])
	for f in faltam:
		if orc <= 0: break
		ativos[f[1]] = _detalhado(f[1]); orc -= 1
	for k in ativos.keys():
		if (_origem(k) + Vector2(PED, PED) * 0.5).distance_to(p) > RAIO + 50.0:
			ativos[k].queue_free(); ativos.erase(k)

func _malha(k: Vector2i, cel: int, desce: bool) -> ArrayMesh:
	var o := _origem(k); var passo := PED / cel
	var hs := PackedFloat32Array(); hs.resize((cel + 1) * (cel + 1))
	var a := alturas(k) if not desce else PackedFloat32Array()
	for j in cel + 1: for i in cel + 1:
		var x := o.x + i * passo; var z := o.y + j * passo
		var h := a[j * (CEL + 1) + i] if not desce else reg.altura(x, z) - 0.35
		if desce and (reg.dist_rio(x, z) < 16.0 or abs(Vector2(x - Regiao.LAGO.x, z - Regiao.LAGO.y).length()) < Regiao.LAGO.z + 8.0): h -= 2.5
		hs[j * (cel + 1) + i] = h
	var cores := []; cores.resize((cel + 1) * (cel + 1))
	for j in cel + 1: for i in cel + 1:
		var x := o.x + i * passo; var z := o.y + j * passo
		var hx := hs[j * (cel + 1) + min(i + 1, cel)] - hs[j * (cel + 1) + max(i - 1, 0)]
		var hz := hs[min(j + 1, cel) * (cel + 1) + i] - hs[max(j - 1, 0) * (cel + 1) + i]
		var ny := Vector3(-hx, 2.0 * passo, -hz).normalized().y
		cores[j * (cel + 1) + i] = reg.cor(x, z, hs[j * (cel + 1) + i], ny)
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
	return st.commit()

func _simples(k: Vector2i) -> void:
	var mi := MeshInstance3D.new(); mi.mesh = _malha(k, 8, true); mi.material_override = m.mat("terreno")
	mi.position = Vector3(_origem(k).x + PED * 0.5, 0, _origem(k).y + PED * 0.5)
	mi.visibility_range_begin = LONGE
	add_child(mi)

func _detalhado(k: Vector2i) -> Node3D:
	var mi := MeshInstance3D.new(); mi.mesh = _malha(k, CEL, false); mi.material_override = m.mat("terreno")
	mi.position = Vector3(_origem(k).x + PED * 0.5, 0, _origem(k).y + PED * 0.5)
	var corpo := StaticBody3D.new(); var cs := CollisionShape3D.new()
	var forma: ConcavePolygonShape3D = mi.mesh.create_trimesh_shape(); forma.backface_collision = true
	cs.shape = forma; corpo.add_child(cs); mi.add_child(corpo)
	add_child(mi); return mi

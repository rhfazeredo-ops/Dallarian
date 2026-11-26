extends SceneTree
# Prepara Altamar a partir da cena Demo_01 do pacote Fantasy Kingdom (lida por tools/ler_cena_unity.py):
#  arte/altamar/cena.json — objetos dentro do recorte (sem o chão grande), em coordenadas da cena
#  arte/altamar/chao.res  — o chão grande (SM_Generic_*) numa malha só, cortada no recorte (um material por superfície)
#  arte/altamar/altura.res — Image (RF) com a altura do chão a cada 1 m dentro do recorte (para o terreno e o povo)
# Uso: godot --headless --path godot --script res://ferramentas/altamar_assar.gd
const RECORTE := Rect2(-140.0, -75.0, 240.0, 210.0)       # x, z na cena (o mundo = cena + Regiao.ALTAMAR_DESL)
const FAIXA := 12.0        # nos últimos 12 m da borda o chão é o terreno do jogo (emenda suave com o resto do mapa)

func _chao_grande(n: String) -> bool: return n.begins_with("SM_Generic_Ground") or n.begins_with("SM_Generic_Mountains")
func _conta_altura(n: String) -> bool: return _chao_grande(n) or n.begins_with("SM_Env_Ground")

func _initialize() -> void:
	var lista: Array = JSON.parse_string(FileAccess.get_file_as_string("res://arte/altamar/demo01.json"))
	var objs := []
	var sts := {}                                 # tipo de material → SurfaceTool do chão
	var W := int(RECORTE.size.x); var H := int(RECORTE.size.y)
	var alt := PackedFloat32Array(); alt.resize(W * H); alt.fill(-1.0e9)
	for o in lista:
		var t: Array = o.t
		var T := Transform3D(Basis(Vector3(t[0], t[1], t[2]), Vector3(t[3], t[4], t[5]), Vector3(t[6], t[7], t[8])), Vector3(t[9], t[10], t[11]))
		var nome: String = o.n
		var dentro := RECORTE.has_point(Vector2(T.origin.x, T.origin.z))
		if not _chao_grande(nome):
			if dentro: objs.append(o)
			if not (dentro and _conta_altura(nome)): continue
		for p in Synty.pecas(nome):
			var malha: ArrayMesh = p[0]; var TT: Transform3D = T * (p[1] as Transform3D)
			var arr := malha.surface_get_arrays(0)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]; var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]; var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			var tipo: String = p[2]
			if _chao_grande(nome) and not sts.has(tipo):
				sts[tipo] = SurfaceTool.new(); sts[tipo].begin(Mesh.PRIMITIVE_TRIANGLES)
			for k in range(0, idx.size(), 3):
				var a := TT * vs[idx[k]]; var b := TT * vs[idx[k + 1]]; var c := TT * vs[idx[k + 2]]
				var cm := (a + b + c) / 3.0
				if not RECORTE.has_point(Vector2(cm.x, cm.z)): continue
				if _chao_grande(nome) and RECORTE.grow(-FAIXA).has_point(Vector2(cm.x, cm.z)):
					var st: SurfaceTool = sts[tipo]
					for j in 3:
						var i := idx[k + j]
						st.set_normal((TT.basis * ns[i]).normalized()); st.set_uv(uvs[i] if uvs.size() > 0 else Vector2.ZERO)
						st.add_vertex(TT * vs[i])
				_rasterizar(alt, W, H, a, b, c)
	# buracos (sem chão): a altura do vizinho mais baixo, várias passadas
	for passada in 60:
		var mudou := false
		for z in H:
			for x in W:
				if alt[z * W + x] > -1.0e8: continue
				var m := 1.0e9
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var xx: int = x + d.x; var zz: int = z + d.y
					if xx >= 0 and zz >= 0 and xx < W and zz < H and alt[zz * W + xx] > -1.0e8: m = minf(m, alt[zz * W + xx])
				if m < 1.0e8: alt[z * W + x] = m; mudou = true
		if not mudou: break
	var img := Image.create_from_data(W, H, false, Image.FORMAT_RF, alt.to_byte_array())
	print("altura ", ResourceSaver.save(ImageTexture.create_from_image(img), "res://arte/altamar/altura.res"))
	var chao := ArrayMesh.new(); var tipos := []
	for tipo in sts.keys():
		(sts[tipo] as SurfaceTool).commit(chao); tipos.append(tipo)
	chao.set_meta("tipos", tipos)
	print("chao ", ResourceSaver.save(chao, "res://arte/altamar/chao.res"), " superfícies ", tipos)
	var f := FileAccess.open("res://arte/altamar/cena.json", FileAccess.WRITE); f.store_string(JSON.stringify(objs)); f.close()
	print("objetos ", objs.size())
	quit()

func _rasterizar(alt: PackedFloat32Array, W: int, H: int, a: Vector3, b: Vector3, c: Vector3) -> void:
	var o := RECORTE.position
	var x0 := maxi(int(floor(minf(a.x, minf(b.x, c.x)) - o.x)), 0); var x1 := mini(int(ceil(maxf(a.x, maxf(b.x, c.x)) - o.x)), W - 1)
	var z0 := maxi(int(floor(minf(a.z, minf(b.z, c.z)) - o.y)), 0); var z1 := mini(int(ceil(maxf(a.z, maxf(b.z, c.z)) - o.y)), H - 1)
	var den := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
	if absf(den) < 1e-6: return
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			var px := o.x + x + 0.5; var pz := o.y + z + 0.5
			var l1 := ((b.z - c.z) * (px - c.x) + (c.x - b.x) * (pz - c.z)) / den
			var l2 := ((c.z - a.z) * (px - c.x) + (a.x - c.x) * (pz - c.z)) / den
			var l3 := 1.0 - l1 - l2
			if l1 < -0.01 or l2 < -0.01 or l3 < -0.01: continue
			var y := l1 * a.y + l2 * b.y + l3 * c.y
			if y > alt[z * W + x]: alt[z * W + x] = y

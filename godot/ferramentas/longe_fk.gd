# Versões "de longe" das construções do Fantasy Kingdom: a malha de colisão que vem no pacote (~450 triângulos em vez
# de ~26 mil) pintada face a face com a cor do ponto mais perto do modelo completo (lida na textura-atlas).
# Grava res://arte/fk/longe/<nome>.res (ArrayMesh com cor por vértice). Roda uma vez quando entram modelos novos:
# godot --headless --path godot --script res://ferramentas/longe_fk.gd
extends SceneTree
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://arte/fk/longe")
	var atlas: Image = load(Synty.ATLAS).get_image(); if atlas.is_compressed(): atlas.decompress()
	var tijolo: Image = load(Synty.TEXTURAS.castelo).get_image(); if tijolo.is_compressed(): tijolo.decompress()
	var feitos := 0
	for f in DirAccess.get_files_at(Synty.PASTA):
		if not f.ends_with("_Collision.fbx"): continue
		var nome := f.get_basename().trim_suffix("_Collision")
		if not Synty.existe(nome): continue
		# pontos do modelo completo (com a cor de cada um), numa grade de 0,5 m para achar o mais perto rápido
		var grade := {}
		for p in Synty.pecas(nome):
			var a: Array = (p[0] as ArrayMesh).surface_get_arrays(0)
			var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]; var uvs: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
			var img: Image = tijolo if p[2] == "castelo" else atlas
			for i in vs.size():
				var v: Vector3 = (p[1] as Transform3D) * vs[i]
				var uv := uvs[i] if i < uvs.size() else Vector2.ZERO
				var c := img.get_pixel(clampi(int(fposmod(uv.x, 1.0) * img.get_width()), 0, img.get_width() - 1), clampi(int(fposmod(uv.y, 1.0) * img.get_height()), 0, img.get_height() - 1))
				var k := Vector3i((v / 0.5).floor())
				if not grade.has(k): grade[k] = []
				grade[k].append([v, c])
		var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for p in Synty.pecas(nome + "_Collision"):
			var a: Array = (p[0] as ArrayMesh).surface_get_arrays(0)
			var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]; var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
			for t in idx.size() / 3:
				var tri := []
				for j in 3: tri.append((p[1] as Transform3D) * vs[idx[t * 3 + j]])
				var centro: Vector3 = (tri[0] + tri[1] + tri[2]) / 3.0
				var c := _cor_perto(grade, centro)
				var nrm: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0]).normalized()
				for j in 3: st.set_color(c); st.set_normal(-nrm); st.add_vertex(tri[j])
		var am := st.commit()
		ResourceSaver.save(am, "res://arte/fk/longe/%s.res" % nome); feitos += 1
		print("LONGE ", nome)
	print("FEITOS ", feitos)
	quit()

func _cor_perto(grade: Dictionary, p: Vector3) -> Color:
	var k := Vector3i((p / 0.5).floor())
	for r in [1, 2, 4, 8]:
		var melhor: Color = Color(0.6, 0.6, 0.6); var md := INF
		for x in range(-r, r + 1):
			for y in range(-r, r + 1):
				for z in range(-r, r + 1):
					var l = grade.get(k + Vector3i(x, y, z))
					if l == null: continue
					for it in l:
						var d: float = p.distance_squared_to(it[0])
						if d < md: md = d; melhor = it[1]
		if md < INF: return melhor
	return Color(0.6, 0.6, 0.6)

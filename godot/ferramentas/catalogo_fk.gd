# Lê os modelos do Fantasy Kingdom (arte/fk/modelos) e grava arte/fk/catalogo.json: tamanho (AABB) e materiais.
extends SceneTree
func _initialize() -> void:
	var cat := {}; var mats := {}
	for f in DirAccess.get_files_at("res://arte/fk/modelos"):
		if not f.ends_with(".fbx"): continue
		var n: Node3D = load("res://arte/fk/modelos/" + f).instantiate(); root.add_child(n)
		var ab := AABB(); var primeiro := true; var ms := []
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var t: Transform3D = n.global_transform.affine_inverse() * mi.global_transform
			var b: AABB = t * mi.mesh.get_aabb()
			ab = b if primeiro else ab.merge(b); primeiro = false
			for s in mi.mesh.get_surface_count():
				var m: Material = mi.mesh.surface_get_material(s)
				var nome := m.resource_name if m else "?"
				if not nome in ms: ms.append(nome)
				mats[nome] = mats.get(nome, 0) + 1
		cat[f.get_basename()] = {"pos": [ab.position.x, ab.position.y, ab.position.z], "tam": [ab.size.x, ab.size.y, ab.size.z], "mat": ms}
		n.free()
	var fa := FileAccess.open("res://arte/fk/catalogo.json", FileAccess.WRITE); fa.store_string(JSON.stringify(cat, "\t"))
	print("MATERIAIS ", mats)
	quit()

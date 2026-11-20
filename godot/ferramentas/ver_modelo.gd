# Renderiza um GLB de 4 lados (e um close) numa folha PNG, para conferir modelos do Tripo.
# Uso: godot --path godot --script res://ferramentas/ver_modelo.gd -- --glb=/caminho/modelo.glb --saida=/caminho/folha.png [--ps1]
extends SceneTree

func _initialize() -> void:
	var a := {}
	for s in OS.get_cmdline_user_args():
		var p := s.trim_prefix("--").split("="); a[p[0]] = p[1] if p.size() > 1 else "1"
	var doc := GLTFDocument.new(); var st := GLTFState.new()
	if doc.append_from_file(a.glb, st) != OK: print("erro ao ler"); quit(); return
	var modelo: Node3D = doc.generate_scene(st)
	var vp := SubViewport.new(); vp.size = Vector2i(512, 640); vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false; root.add_child(vp)
	var we := WorldEnvironment.new(); var env := Environment.new(); env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.6, 0.68); env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.8, 0.85); env.ambient_light_energy = 0.9; we.environment = env; vp.add_child(we)
	var luz := DirectionalLight3D.new(); luz.rotation_degrees = Vector3(-35, 30, 0); luz.light_energy = 0.7; vp.add_child(luz)
	var piv := Node3D.new(); vp.add_child(piv); piv.add_child(modelo)
	await process_frame
	if a.has("ps1"):
		for n in modelo.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = n
			for i in mi.mesh.get_surface_count():
				var m: BaseMaterial3D = mi.mesh.surface_get_material(i)
				if m: m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var aabb := AABB(); var primeiro := true
	for n in modelo.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = n.global_transform * n.get_aabb()
		aabb = b if primeiro else aabb.merge(b); primeiro = false
	modelo.position = -aabb.get_center()
	var cam := Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = max(aabb.size.y, max(aabb.size.x, aabb.size.z)) * 1.1; vp.add_child(cam)
	cam.position = Vector3(0, 0, 10); cam.look_at(Vector3.ZERO)
	var folha := Image.create(512 * 5, 640, false, Image.FORMAT_RGB8)
	var vistas := [0.0, 90.0, 180.0, 270.0, 45.0]
	for i in vistas.size():
		piv.rotation_degrees.y = vistas[i]
		if i == 4: cam.size *= 0.4; cam.position.y = aabb.size.y * 0.33
		for k in 4: await process_frame
		var im := vp.get_texture().get_image(); im.convert(Image.FORMAT_RGB8)
		folha.blit_rect(im, Rect2i(0, 0, 512, 640), Vector2i(512 * i, 0))
	folha.save_png(a.saida); print("ok ", aabb); quit()

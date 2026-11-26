extends SceneTree
# Vista de cima de Altamar (a cena da Synty), 1 pixel = 1 m, para o mapa do jogo: arte/altamar/mapa.png.
# Uso (precisa de tela: xvfb): godot --path godot --script res://ferramentas/altamar_mapa.gd
func _initialize() -> void:
	var D := Regiao.ALTAMAR_DESL; var R := Regiao.CIDADE
	var raiz := Node3D.new(); root.add_child(raiz)
	var we := WorldEnvironment.new(); var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.3, 0.45, 0.25)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color.WHITE; env.ambient_light_energy = 0.6; we.environment = env; raiz.add_child(we)
	var sol := DirectionalLight3D.new(); sol.rotation_degrees = Vector3(-60, 40, 0); raiz.add_child(sol)
	RenderingServer.global_shader_parameter_set("neb_ini", 5000.0); RenderingServer.global_shader_parameter_set("neb_fim", 9000.0)
	var lista: Array = JSON.parse_string(FileAccess.get_file_as_string("res://arte/altamar/cena.json"))
	for o in lista:
		var t: Array = o.t
		var T := Transform3D(Basis(Vector3(t[0], t[1], t[2]), Vector3(t[3], t[4], t[5]), Vector3(t[6], t[7], t[8])), Vector3(t[9], t[10], t[11]) + D)
		if String(o.n).begins_with("SM_Item") or String(o.n).begins_with("FX_"): continue
		for p in Synty.pecas(o.n):
			var mi := MeshInstance3D.new(); mi.mesh = p[0]; mi.transform = T * (p[1] as Transform3D)
			mi.material_override = Synty.material(Color(0.6, 0.7, 0.9), "agua" if String(o.n).begins_with("SM_Env_Water") else p[2]); raiz.add_child(mi)
	var chao := MeshInstance3D.new(); chao.mesh = load("res://arte/altamar/chao.res"); chao.position = D; chao.material_override = Synty.material(Color(0.6, 0.7, 0.9), "atlas"); raiz.add_child(chao)
	var vp := SubViewport.new(); vp.size = Vector2i(int(R.size.x) * 2, int(R.size.y) * 2); vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(vp)
	vp.world_3d = root.world_3d
	var cam := Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = R.size.y; cam.far = 500.0
	vp.add_child(cam); cam.current = true
	cam.global_transform = Transform3D(Basis.from_euler(Vector3(-PI / 2, 0, 0)), Vector3(R.get_center().x, 200.0, R.get_center().y))
	for k in 6: await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image(); img.resize(int(R.size.x), int(R.size.y), Image.INTERPOLATE_LANCZOS)
	img.save_png("res://arte/altamar/mapa.png"); print("MAPA_ALTAMAR ", img.get_size())
	quit()

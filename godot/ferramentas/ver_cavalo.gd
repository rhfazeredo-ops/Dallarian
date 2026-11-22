# Folha com o cavalo rigado de lado em 6 momentos do passo (confere o rig automático e a animação).
# Uso: godot --path godot --script res://ferramentas/ver_cavalo.gd -- --glb=res://assets/modelos/cavalo_branco.glb --vel=3 --saida=/caminho/folha.png
extends SceneTree

func _initialize() -> void:
	var a := {}
	for s in OS.get_cmdline_user_args():
		var p := s.trim_prefix("--").split("="); a[p[0]] = p[1] if p.size() > 1 else "1"
	var vp := SubViewport.new(); vp.size = Vector2i(420, 360); vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var we := WorldEnvironment.new(); var env := Environment.new(); env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.6, 0.68); env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.85, 0.9); we.environment = env; vp.add_child(we)
	var luz := DirectionalLight3D.new(); luz.rotation_degrees = Vector3(-35, 30, 0); vp.add_child(luz)
	var rc := Node3D.new(); rc.name = "Cavalo"; vp.add_child(rc)
	var mod: Node3D = load(a.glb).instantiate(); mod.name = "Modelo"; rc.add_child(mod)
	RigCavalo.montar(mod, a.glb)
	var an := Node.new(); an.set_script(load("res://scripts/cavalo_anim.gd")); rc.add_child(an)
	an.vel = float(a.get("vel", "3"))
	var cam := Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = 1.15
	cam.position = Vector3(0, 0, 3); vp.add_child(cam); cam.current = true
	if a.has("frente"): cam.position = Vector3(3, 0, 0); cam.rotation_degrees.y = 90
	var folha := Image.create(420 * 6, 360, false, Image.FORMAT_RGBA8)
	await process_frame
	for q in 6:
		an._process(2.6 / maxf(an.vel, 0.1) / 6.0)          # 1/6 de passada por quadro
		for k in 3: await RenderingServer.frame_post_draw
		folha.blit_rect(vp.get_texture().get_image(), Rect2i(0, 0, 420, 360), Vector2i(q * 420, 0))
	folha.save_png(a.saida); quit()

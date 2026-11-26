# Folha com a heroína fazendo animações da biblioteca heroi.res: --anims=parado:0.5,golpe1:0.4 --saida=arq.png [--lado]
extends SceneTree
func _initialize() -> void:
	var a := {}
	for s in OS.get_cmdline_user_args():
		var p := s.trim_prefix("--").split("="); a[p[0]] = p[1] if p.size() > 1 else "1"
	var lista := String(a.get("anims", "parado:0")).split(",")
	var vp := SubViewport.new(); vp.size = Vector2i(320, 400); vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(vp)
	var we := WorldEnvironment.new(); var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.55, 0.6, 0.68)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.8, 0.8, 0.85); we.environment = env; vp.add_child(we)
	var luz := DirectionalLight3D.new(); luz.rotation_degrees = Vector3(-35, 30, 0); vp.add_child(luz)
	var mod: Node3D = load("res://assets/modelos/%s.glb" % a.get("modelo", "humana")).instantiate(); vp.add_child(mod)
	mod.rotation_degrees.y = 90.0 if a.has("lado") else 0.0       # +X (frente do modelo) → câmera em +Z vê o lado / de frente com -90
	if not a.has("lado"): mod.rotation_degrees.y = -90.0
	var ap := AnimationPlayer.new(); mod.add_child(ap); ap.root_node = NodePath("..")
	ap.add_animation_library("", load("res://arte/animacoes/heroi.res"))
	var cam := Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = 1.25; cam.position = Vector3(0, 0.5, 3); vp.add_child(cam); cam.current = true
	var folha := Image.create(320 * lista.size(), 400, false, Image.FORMAT_RGB8)
	for i in lista.size():
		var pp := lista[i].split(":")
		ap.play(pp[0]); ap.seek(float(pp[1]) * ap.get_animation(pp[0]).length, true)
		for k in 3: await process_frame
		await RenderingServer.frame_post_draw
		folha.blit_rect(vp.get_texture().get_image().convert_to(Image.FORMAT_RGB8) if false else _rgb(vp.get_texture().get_image()), Rect2i(0, 0, 320, 400), Vector2i(320 * i, 0))
	folha.save_png(a.saida); quit()
func _rgb(im: Image) -> Image: im.convert(Image.FORMAT_RGB8); return im

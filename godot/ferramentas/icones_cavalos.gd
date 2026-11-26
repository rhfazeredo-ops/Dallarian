extends SceneTree
# ícones das montarias: o cavalo da Synty de lado (3/4), cada um com a sua pelagem, fundo transparente
# uso: godot --path . -s ferramentas/icones_cavalos.gd   (com tela: xvfb-run)
func _init():
	RenderingServer.global_shader_parameter_set("neb_ini", 500.0); RenderingServer.global_shader_parameter_set("neb_fim", 900.0)
	root.transparent_bg = true
	var M = load("res://scripts/mundo.gd").new()
	var r = Node3D.new(); root.add_child(r)
	var c = Camera3D.new(); r.add_child(c); c.fov = 30.0
	c.look_at_from_position(Vector3(4.6, 2.2, -3.6), Vector3(0, 1.15, -0.65))      # do lado do sol
	for id in Bolsa.ITENS.keys():
		if Bolsa.ITENS[id].get("tipo_m", "") != "montaria": continue
		var cv: Node3D = M.cavalo(id); r.add_child(cv)
		for i in 4: await process_frame
		var im: Image = root.get_texture().get_image()
		var t := mini(im.get_width(), im.get_height())
		im = im.get_region(Rect2i((im.get_width() - t) / 2, (im.get_height() - t) / 2, t, t))
		im.resize(128, 128, Image.INTERPOLATE_LANCZOS)
		im.save_png("res://assets/ui/itens/%s.png" % id); print("ícone ", id)
		cv.free()
	quit()

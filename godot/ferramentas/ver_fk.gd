# Folha com modelos do Fantasy Kingdom vistos de frente (câmera em +Z olhando para -Z): --nomes=a,b,c --saida=x.png [--giro=graus]
extends SceneTree
var NEBLINA := Color(0.6, 0.65, 0.75)
var raiz: Node3D
func _initialize() -> void:
	var a := {}
	for s in OS.get_cmdline_user_args():
		var p := s.trim_prefix("--").split("="); a[p[0]] = p[1] if p.size() > 1 else "1"
	var nomes := String(a.get("nomes", "")).split(",")
	RenderingServer.global_shader_parameter_set("neb_ini", 500.0); RenderingServer.global_shader_parameter_set("neb_fim", 900.0)
	var W := 360; var H := 360
	var folha := Image.create(W * nomes.size(), H, false, Image.FORMAT_RGB8)
	for i in nomes.size():
		var vp := SubViewport.new(); vp.size = Vector2i(W, H); vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS; vp.own_world_3d = true; root.add_child(vp)
		raiz = Node3D.new(); vp.add_child(raiz)
		var we := WorldEnvironment.new(); var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.55, 0.65, 0.8); we.environment = env; raiz.add_child(we)
		Synty.por(self, nomes[i], Vector3.ZERO, deg_to_rad(float(a.get("giro", "0"))), 1.0, false)
		var cx: AABB = Synty.caixa(nomes[i]); var r := maxf(cx.size.length() * 0.6, 1.0)
		var cam := Camera3D.new(); raiz.add_child(cam)
		cam.position = Vector3(0, cx.size.y * 0.5 + r * 0.25, r * 1.5); cam.look_at(Vector3(0, cx.position.y + cx.size.y * 0.5, 0)); cam.current = true
		await process_frame; await process_frame; await process_frame
		var img := vp.get_texture().get_image(); img.convert(Image.FORMAT_RGB8)
		folha.blit_rect(img, Rect2i(0, 0, W, H), Vector2i(W * i, 0))
		vp.queue_free()
	folha.save_png(String(a.get("saida", "/tmp/fk.png"))); quit()

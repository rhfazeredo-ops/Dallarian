# Testa um personagem com esqueleto numa pose (braços abaixados, perna esquerda à frente, cotovelo dobrado)
# e salva frente + lado num PNG. Uso: --glb=... --saida=...
extends SceneTree
func _initialize() -> void:
	var a := {}
	for s in OS.get_cmdline_user_args():
		var p := s.trim_prefix("--").split("=", true, 1); a[p[0]] = p[1] if p.size() > 1 else "1"
	var doc := GLTFDocument.new(); var st := GLTFState.new(); doc.append_from_file(a.glb, st)
	var mod: Node3D = doc.generate_scene(st)
	var vp := SubViewport.new(); vp.size = Vector2i(400, 520); vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(vp)
	var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.55, 0.6, 0.68)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.85, 0.85, 0.9)
	var we := WorldEnvironment.new(); we.environment = env; vp.add_child(we)
	var piv := Node3D.new(); vp.add_child(piv); piv.add_child(mod)
	await process_frame
	var e: Skeleton3D = mod.find_children("*", "Skeleton3D", true, false)[0]
	var rot := func(b: String, eixo: Vector3, ang: float):
		var i := e.find_bone(b); if i < 0: return
		var pai := e.get_bone_parent(i)
		var pg: Transform3D = e.get_bone_global_pose(pai) if pai >= 0 else Transform3D.IDENTITY
		var g: Transform3D = pg * e.get_bone_global_rest(pai).affine_inverse() * e.get_bone_global_rest(i) if pai >= 0 else e.get_bone_global_rest(i)
		g.basis = Basis(eixo, ang) * g.basis
		var loc := pg.affine_inverse() * g
		e.set_bone_pose_rotation(i, loc.basis.get_rotation_quaternion())
	rot.call("L_Upperarm", Vector3(1, 0, 0), -0.32); rot.call("R_Upperarm", Vector3(1, 0, 0), 0.32)
	rot.call("L_Thigh", Vector3(0, 0, 1), 0.5); rot.call("R_Thigh", Vector3(0, 0, 1), -0.4)
	rot.call("R_Calf", Vector3(0, 0, 1), -0.7)
	rot.call("L_Forearm", Vector3(0, 0, 1), 0.9)
	rot.call("Head", Vector3(0, 1, 0), 0.4)
	var cam := Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = 1.1; vp.add_child(cam)
	var folha := Image.create(800, 520, false, Image.FORMAT_RGB8)
	for k in 2:
		piv.rotation_degrees.y = -90 if k == 0 else 0
		cam.position = Vector3(0, 0.49, 3); cam.look_at(Vector3(0, 0.49, 0))
		for f in 4: await process_frame
		var im := vp.get_texture().get_image(); im.convert(Image.FORMAT_RGB8); folha.blit_rect(im, Rect2i(0, 0, 400, 520), Vector2i(400 * k, 0))
	folha.save_png(a.saida); quit()

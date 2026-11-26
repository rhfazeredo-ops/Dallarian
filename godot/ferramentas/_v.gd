extends SceneTree
var NEBLINA := Color(0.6, 0.65, 0.75)
var raiz: Node3D
var jogador = null
func _initialize() -> void:
	RenderingServer.global_shader_parameter_set("neb_ini", 500.0); RenderingServer.global_shader_parameter_set("neb_fim", 900.0)
	var vp := SubViewport.new(); vp.size = Vector2i(1400, 360); vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(vp)
	raiz = Node3D.new(); vp.add_child(raiz)
	var we := WorldEnvironment.new(); var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.55, 0.65, 0.8); we.environment = env; raiz.add_child(we)
	var tipos := ["SM_Chr_Peasant_Male_01", "SM_Chr_Peasant_Female_01", "SM_Chr_Merchant_01", "SM_Chr_Soldier_Male_01", "SM_Chr_Nun_01", "SM_Chr_King_01", "SM_Chr_Blacksmith_Male_01", "SM_Chr_Mage_01"]
	for i in tipos.size():
		var c := Cidadao.new(); c.tipo = tipos[i]; c.fixo = true; raiz.add_child(c); c.position = Vector3(i * 1.4 - 4.9, 0, 0)
		c.m = self; c.montar(self, i)
		if i % 2 == 1: c._ap.play("andar")
	var cam := Camera3D.new(); raiz.add_child(cam); cam.position = Vector3(0, 1.2, 6.5); cam.look_at(Vector3(0, 0.9, 0)); cam.current = true
	for k in 20: await process_frame
	var img := vp.get_texture().get_image(); img.save_png("/tmp/claude-0/-home-user/7bcbdaaf-be8a-52f6-8c86-b8902bcf5b90/scratchpad/cid.png"); quit()

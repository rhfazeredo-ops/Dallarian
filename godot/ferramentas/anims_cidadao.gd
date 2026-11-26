# Grava as animações da Synty que os cidadãos usam (Base Locomotion) em res://arte/animacoes/synty/*.res
extends SceneTree
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://arte/animacoes/synty")
	var n := 0
	for f in DirAccess.get_files_at("res://_anim_src/synty"):
		if not f.ends_with(".fbx") or not (f.begins_with("A_Idle_Standing") or f.begins_with("A_Walk_F_")): continue
		var s: Node = load("res://_anim_src/synty/" + f).instantiate()
		var ap: AnimationPlayer = s.find_children("*", "AnimationPlayer", true, false)[0]
		var a: Animation = ap.get_animation(ap.get_animation_list()[0]).duplicate()
		ResourceSaver.save(a, "res://arte/animacoes/synty/%s.res" % f.get_basename()); n += 1
		s.free()
	print("ANIMS ", n); quit()

extends SceneTree
# Animações da Synty (Base Locomotion, FBX em _anim_src/synty, mesmos nomes de ossos) → personagens do Fantasy
# Kingdom, com a rotação COMPLETA de cada osso (o retarget.gd antigo só copiava a direção e perdia a torção: o andar
# e o correr ficavam tortos). Para cada quadro: D = rotação do osso no mundo em relação ao repouso da fonte;
# alvo = D · A · repouso do alvo, onde A gira a direção do osso no repouso do alvo até a da fonte (as poses de
# descanso não são iguais). Grava por cima das animações "calmo_*" de heroi_fk_*.res e de parado/andar dos cidadãos.
# Uso: godot --headless --path godot --script res://ferramentas/retarget_synty.gd
const PERSONAGENS := "res://arte/fk/personagens/FantasyKingdom_Characters.fbx"
const CLIPES := {"calmo_parado": ["A_Idle_Standing", true], "calmo_andar": ["A_Walk_F", true], "calmo_correr": ["A_Run_F", true],
	"calmo_disparada": ["A_Sprint_F", true], "calmo_andar_tras": ["A_Walk_BckStrafeB", true], "calmo_correr_tras": ["A_Run_BckStrafeB", true],
	"calmo_no_ar": ["A_InAir_FallShort", true], "calmo_queda": ["A_InAir_FallLarge", true],
	"calmo_pulo": ["A_Jump_Idle", false], "calmo_pulo_andando": ["A_Jump_Walking", false],
	"calmo_pulo_correndo": ["A_Jump_Running", false], "calmo_pulo_disparada": ["A_Jump_Sprinting", false],
	"calmo_aterrissa_leve": ["A_Land_IdleSoft", false], "calmo_aterrissa_media": ["A_Land_IdleMedium", false],
	"calmo_aterrissa_forte": ["A_Land_IdleHard", false],
	"calmo_comecar_andar": ["A_Idle_ToWalkF", false], "calmo_comecar_correr": ["A_Idle_ToRunF", false],
	"calmo_parar_andando": ["A_Walk_ToIdleF_RFoot", false], "calmo_parar_correndo": ["A_Run_ToIdleF_RFoot", false],
	"calmo_andar_sobe": ["A_Walk_Up25F", true], "calmo_andar_desce": ["A_Walk_Down25F", true],
	"calmo_correr_sobe": ["A_Run_Up25F", true], "calmo_correr_desce": ["A_Run_Down25F", true],
	"calmo_disparada_sobe": ["A_Sprint_Up25F", true], "calmo_disparada_desce": ["A_Sprint_Down25F", true]}
const CIDADAO := {"parado": "calmo_parado", "andar": "calmo_andar"}

func _initialize() -> void:
	var alvo: Node3D = load(PERSONAGENS).instantiate(); root.add_child(alvo)
	var skt: Skeleton3D = alvo.find_children("*", "Skeleton3D", true, false)[0]
	var caminho := String(alvo.get_path_to(skt))
	for gen in ["Masc", "Femn"]:
		var lib: AnimationLibrary = load("res://arte/animacoes/heroi_fk_%s.res" % gen)
		for nome in CLIPES.keys():
			var arq := "res://_anim_src/synty/%s_%s.fbx" % [CLIPES[nome][0], gen]
			if not ResourceLoader.exists(arq): print("FALTA ", arq); continue
			var a := _converter(arq, skt, caminho, CLIPES[nome][1])
			if a: lib.add_animation(nome, a)
		print("SALVO heroi ", gen, " ", ResourceSaver.save(lib, "res://arte/animacoes/heroi_fk_%s.res" % gen))
		var lc: AnimationLibrary = load("res://arte/animacoes/cidadao_%s.res" % gen)
		for n in CIDADAO.keys():
			if lib.has_animation(CIDADAO[n]): lc.add_animation(n, lib.get_animation(CIDADAO[n]).duplicate(true))
		print("SALVO cidadao ", gen, " ", ResourceSaver.save(lc, "res://arte/animacoes/cidadao_%s.res" % gen))
	quit()

func _globais(sk: Skeleton3D, repouso: bool) -> Array:          # transforms globais (no espaço do esqueleto) de todos os ossos
	var g := []; g.resize(sk.get_bone_count())
	for i in sk.get_bone_count():
		var loc := sk.get_bone_rest(i) if repouso else sk.get_bone_pose(i)
		var p := sk.get_bone_parent(i)
		g[i] = loc if p < 0 else (g[p] as Transform3D) * loc
	return g

func _mundo(n: Node) -> Transform3D:          # transform até a raiz, somando os pais (sem depender da árvore)
	var t := Transform3D(); var x: Node = n
	while x != null:
		if x is Node3D: t = (x as Node3D).transform * t
		x = x.get_parent()
	return t

func _filho(sk: Skeleton3D, i: int) -> int:
	var fs := sk.get_bone_children(i)
	return fs[0] if fs.size() > 0 else -1

func _converter(arq: String, skt: Skeleton3D, caminho: String, laco: bool) -> Animation:
	var f: Node3D = load(arq).instantiate(); root.add_child(f)
	var sks: Skeleton3D = f.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = f.find_children("*", "AnimationPlayer", true, false)[0]
	var orig: Animation = ap.get_animation(ap.get_animation_list()[0])
	var Ws := _mundo(sks).basis.orthonormalized(); var Wt := _mundo(skt).basis.orthonormalized()
	var rs := _globais(sks, true); var rt := _globais(skt, true)
	# ossos em comum e o alinhamento do repouso (direção do osso → direção do osso na fonte)
	var comuns := []; var alin := {}
	for i in skt.get_bone_count():
		var n := skt.get_bone_name(i); var j := sks.find_bone(n)
		if j < 0: continue
		comuns.append(i)
		var A := Basis.IDENTITY
		var fi := _filho(skt, i); var fj := sks.find_bone(skt.get_bone_name(fi)) if fi >= 0 else -1
		if fi >= 0 and fj >= 0:
			var dt := (Wt * ((rt[fi] as Transform3D).origin - (rt[i] as Transform3D).origin)).normalized()
			var ds := (Ws * ((rs[fj] as Transform3D).origin - (rs[j] as Transform3D).origin)).normalized()
			if dt.length() > 0.5 and ds.length() > 0.5 and dt.dot(ds) < 0.9999: A = Basis(Quaternion(dt, ds))
		alin[i] = A
	var hips_t := skt.find_bone("Hips"); var hips_s := sks.find_bone("Hips")
	var esc := (rt[hips_t] as Transform3D).origin.length() / maxf((rs[hips_s] as Transform3D).origin.length(), 0.001)
	var a := Animation.new(); a.length = orig.length; a.loop_mode = Animation.LOOP_LINEAR if laco else Animation.LOOP_NONE
	var trilhas := {}
	for i in comuns:
		var t := a.add_track(Animation.TYPE_ROTATION_3D); a.track_set_path(t, "%s:%s" % [caminho, skt.get_bone_name(i)]); trilhas[i] = t
	var tp := a.add_track(Animation.TYPE_POSITION_3D); a.track_set_path(tp, "%s:Hips" % caminho)
	ap.play(ap.get_animation_list()[0])
	var n_q := int(ceil(orig.length * 30.0)) + 1
	for q in n_q:
		var tempo := minf(q / 30.0, orig.length)
		ap.seek(tempo, true)
		var gs := _globais(sks, false)
		var gt := {}
		for i in comuns:
			var j := sks.find_bone(skt.get_bone_name(i))
			var D := (Ws * (gs[j] as Transform3D).basis.orthonormalized()) * (Ws * (rs[j] as Transform3D).basis.orthonormalized()).inverse()
			var Rt := Wt * (rt[i] as Transform3D).basis.orthonormalized()
			gt[i] = (Wt.inverse() * (D * (alin[i] as Basis) * Rt)).orthonormalized()
		for i in comuns:
			var p := skt.get_bone_parent(i)
			var pb: Basis = (gt[p] if gt.has(p) else (rt[p] as Transform3D).basis.orthonormalized()) if p >= 0 else Basis.IDENTITY
			a.rotation_track_insert_key(trilhas[i], tempo, (pb.inverse() * (gt[i] as Basis)).get_rotation_quaternion())
		# quadril: o deslocamento em relação ao repouso (na escala do alvo), no espaço do pai do quadril
		var dp := Ws * ((gs[hips_s] as Transform3D).origin - (rs[hips_s] as Transform3D).origin) * esc
		var pos_esq := (rt[hips_t] as Transform3D).origin + Wt.inverse() * dp
		var ph := skt.get_bone_parent(hips_t)
		var pt := (rt[ph] as Transform3D) if ph >= 0 else Transform3D()
		a.position_track_insert_key(tp, tempo, pt.affine_inverse() * pos_esq)
	f.queue_free()
	return a

# Converte animações do pacote "Sword and Shield Animations" (manequim do Unreal, FBX em _anim_src/, fora do git) e
# da Synty (Base Locomotion) para o esqueleto dos personagens do Fantasy Kingdom: heróis (heroi_fk_Masc/Femn.res)
# e cidadãos (--cidadao → cidadao_Masc/Femn.res). Cada osso recebe a direção do osso equivalente, quadro a quadro.
# Uso: godot --headless --path godot --script res://ferramentas/retarget.gd [-- --cidadao]
extends SceneTree

# osso → filho que dá a direção (para alinhar a pose de repouso com a pose T)
const DIR_S := {"upperarm_l": "lowerarm_l", "lowerarm_l": "hand_l", "hand_l": "middle_01_l", "upperarm_r": "lowerarm_r",
	"lowerarm_r": "hand_r", "hand_r": "middle_01_r", "thigh_l": "calf_l", "calf_l": "foot_l", "foot_l": "ball_l",
	"thigh_r": "calf_r", "calf_r": "foot_r", "foot_r": "ball_r", "clavicle_l": "upperarm_l", "clavicle_r": "upperarm_r"}
const DIR_T := {"L_Upperarm": "L_Forearm", "L_Forearm": "L_Hand", "L_Hand": "L_Mid1", "R_Upperarm": "R_Forearm",
	"R_Forearm": "R_Hand", "R_Hand": "R_Mid1", "L_Thigh": "L_Calf", "L_Calf": "L_Foot", "L_Foot": "L_ToeBase",
	"R_Thigh": "R_Calf", "R_Calf": "R_Foot", "R_Foot": "R_ToeBase", "L_Clavicle": "L_Upperarm", "R_Clavicle": "R_Upperarm"}
const ANIMS := {      # nome no jogo → arquivo, laço?
	"parado": ["Idle_CombatReady", true], "andar": ["Walk_Forward", true], "andar_tras": ["Walk_Back", true],
	"andar_esq": ["Walk_Left", true], "andar_dir": ["Walk_Right", true], "correr": ["Run_Forward", true],
	"correr_tras": ["Run_Back", true], "correr_esq": ["Run_Left", true], "correr_dir": ["Run_Right", true],
	"disparada": ["Run_Sprint_Forward", true], "pulo": ["Jump_InPlace_Jump", false], "no_ar": ["Jump_InPlace_Loop", true],
	"aterrissa": ["Jump_InPlace_Land", false], "bloqueio": ["Block_Loop", true], "bloqueio_golpe": ["Block_HitReaction01", false],
	"golpe1": ["Attack_InPlace_Slash_Diagonal", false], "golpe2": ["Attack_InPlace_Slash_Vertical", false],
	"golpe3": ["Attack_InPlace_Slash_Horizontal", false], "golpe_forte": ["Attack_Forward_PowerSlash01", false],
	"escudada": ["Shield_InPlace_QuickBash", false], "morte": ["Idle_Death01", false], "dano": ["Stagger_Back01", false],
	"rolar": ["Evade_Roll_Forward", false]}
# eixos no espaço da raiz do pacote: cima +Z, esquerda +X, frente −Y → nosso: cima +Y, frente +X, direita +Z
const C_SS := Basis(Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0))

# Synty "Base Locomotion" (andar sem armas, fora de combate): esqueleto Polygon, cima +Y, esquerda +X, frente +Z.
# A pose de referência é o próprio repouso do esqueleto (braços para baixo), não uma pose T.
const MAPA_SY := {"Hips": "Hip", "Spine_01": "Waist", "Spine_02": "Spine01", "Spine_03": "Spine02", "Neck": "NeckTwist01",
	"Head": "Head", "Clavicle_L": "L_Clavicle", "Shoulder_L": "L_Upperarm", "Elbow_L": "L_Forearm", "Hand_L": "L_Hand",
	"Clavicle_R": "R_Clavicle", "Shoulder_R": "R_Upperarm", "Elbow_R": "R_Forearm", "Hand_R": "R_Hand",
	"UpperLeg_L": "L_Thigh", "LowerLeg_L": "L_Calf", "Ankle_L": "L_Foot", "Ball_L": "L_ToeBase",
	"UpperLeg_R": "R_Thigh", "LowerLeg_R": "R_Calf", "Ankle_R": "R_Foot", "Ball_R": "R_ToeBase"}
const DIR_SY := {"Shoulder_L": "Elbow_L", "Elbow_L": "Hand_L", "Hand_L": "Finger_01", "Shoulder_R": "Elbow_R",
	"Elbow_R": "Hand_R", "Hand_R": "Finger_01_1", "UpperLeg_L": "LowerLeg_L", "LowerLeg_L": "Ankle_L", "Ankle_L": "Ball_L",
	"UpperLeg_R": "LowerLeg_R", "LowerLeg_R": "Ankle_R", "Ankle_R": "Ball_R", "Clavicle_L": "Shoulder_L", "Clavicle_R": "Shoulder_R"}
const ANIMS_SY := {"calmo_parado": ["A_Idle_Standing", true], "calmo_andar": ["A_Walk_F", true], "calmo_correr": ["A_Run_F", true],
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
var C := C_SS

var tgt: Skeleton3D
var t_rest := {}           # osso alvo → global rest
var ordem_t: Array[String] = []

var MAPA_A: Dictionary
var DIR_A: Dictionary
var DIR_TA: Dictionary = DIR_T          # direções dos ossos do ALVO (heróis: nomes do Tripo; cidadãos: nomes da Synty)
const PERSONAGENS := "res://arte/fk/personagens/FantasyKingdom_Characters.fbx"
const ANIMS_CID := {"parado": ["A_Idle_Standing", true], "andar": ["A_Walk_F", true]}
func _initialize() -> void:
	# --cidadao: os personagens do Fantasy Kingdom (mesmos nomes de ossos da Synty, eixos diferentes) → cidadao_<gen>.res
	if "--cidadao" in OS.get_cmdline_user_args():
		var id := {}
		for k in MAPA_SY.keys(): id[k] = k
		DIR_TA = DIR_SY.duplicate(); DIR_TA["Hand_R"] = "Finger_01_2"     # (nos personagens o dedo direito é "_2")
		for gen in ["Masc", "Femn"]:
			var lc := AnimationLibrary.new()
			_converter(lc, PERSONAGENS, id, DIR_SY, ANIMS_CID, Basis.IDENTITY, "synty/%s_" + gen, "repouso")
			print("SALVO cidadao ", gen, " ", ResourceSaver.save(lc, "res://arte/animacoes/cidadao_%s.res" % gen))
		quit(); return
	# --heroi_fk (padrão): os heróis (Cavaleira e Príncipe, personagens do Fantasy Kingdom) → heroi_fk_Masc/Femn.res:
	# espada e escudo (pacote RamsterZ, manequim do Unreal) convertidos + o andar da Synty direto (mesmo esqueleto)
	var mapa_ss := {"pelvis": "Hips", "spine_01": "Spine_01", "spine_02": "Spine_02", "spine_03": "Spine_03", "neck_01": "Neck",
		"head": "Head", "clavicle_l": "Clavicle_L", "upperarm_l": "Shoulder_L", "lowerarm_l": "Elbow_L", "hand_l": "Hand_L",
		"clavicle_r": "Clavicle_R", "upperarm_r": "Shoulder_R", "lowerarm_r": "Elbow_R", "hand_r": "Hand_R",
		"thigh_l": "UpperLeg_L", "calf_l": "LowerLeg_L", "foot_l": "Ankle_L", "ball_l": "Ball_L",
		"thigh_r": "UpperLeg_R", "calf_r": "LowerLeg_R", "foot_r": "Ankle_R", "ball_r": "Ball_R"}
	var id := {}
	for k in MAPA_SY.keys(): id[k] = k
	DIR_TA = DIR_SY.duplicate(); DIR_TA["Hand_R"] = "Finger_01_2"
	for gen in ["Masc", "Femn"]:
		var lh := AnimationLibrary.new()
		_converter(lh, PERSONAGENS, mapa_ss, DIR_S, ANIMS, C_SS, "SwordAndShield_%s", "")
		_converter(lh, PERSONAGENS, id, DIR_SY, ANIMS_SY, Basis.IDENTITY, "synty/%s_" + gen, "repouso")
		print("SALVO heroi ", gen, " ", ResourceSaver.save(lh, "res://arte/animacoes/heroi_fk_%s.res" % gen))
	quit()

func _converter(lib: AnimationLibrary, modelo: String, mapa: Dictionary, dirs: Dictionary, anims: Dictionary, c: Basis, molde: String, ref: String) -> void:
	C = c; MAPA_A = mapa; DIR_A = dirs; t_rest.clear(); ordem_t.clear()
	var herói: Node3D = load(modelo).instantiate(); root.add_child(herói)
	tgt = herói.find_children("*", "Skeleton3D", true, false)[0]
	var caminho := String(herói.get_path_to(tgt))
	for i in tgt.get_bone_count(): t_rest[tgt.get_bone_name(i)] = tgt.get_bone_global_rest(i)
	# ordem pai → filho dos ossos mapeados
	for i in tgt.get_bone_count():
		var n := tgt.get_bone_name(i)
		if n in mapa.values(): ordem_t.append(n)
	var inv := {}
	for k in mapa.keys(): inv[mapa[k]] = k
	var raiz_s := "root" if ref == "" else "Root"
	# pose de referência do pacote: a pose T (Sword and Shield) ou o repouso do esqueleto (Synty)
	var s_tp := {}
	if ref == "":
		var tp := _fonte("T_pose"); s_tp = _poses(tp[0])
	else:
		var f0 := _fonte(molde % anims.values()[0][0]); var sk0: Skeleton3D = f0[0]
		for i in sk0.get_bone_count(): s_tp[sk0.get_bone_name(i)] = sk0.get_bone_global_rest(i)
		f0[2].queue_free()
	var tp_raiz: Transform3D = (s_tp[raiz_s] as Transform3D).affine_inverse()
	for k in s_tp.keys(): s_tp[k] = tp_raiz * s_tp[k]          # tudo relativo à raiz (a raiz deita o esqueleto)
	# alinhamento do repouso: rotação que leva a direção do osso no nosso repouso até a da pose T (convertida)
	var alinha := {}
	for t in ordem_t:
		alinha[t] = Quaternion()
		if DIR_TA.has(t):
			var s: String = inv[t]
			var dt: Vector3 = (t_rest[DIR_TA[t]].origin - t_rest[t].origin).normalized()
			var ds: Vector3 = C * (s_tp[dirs[s]].origin - s_tp[s].origin).normalized()
			alinha[t] = Quaternion(dt, ds)
	var hip_t := "Hip" if t_rest.has("Hip") else "Hips"           # quadril do alvo (Tripo: Hip; Synty: Hips)
	var pelvis: String = inv[hip_t]
	var alt_s: float = (C * (s_tp[pelvis] as Transform3D).origin).y; var alt_t: float = t_rest[hip_t].origin.y
	for nome in anims.keys():
		var arq: String = anims[nome][0]
		var f := _fonte(molde % arq)
		var sk: Skeleton3D = f[0]; var ap: AnimationPlayer = f[1]
		var fonte: Animation = ap.get_animation(ap.get_animation_list()[0])
		var dur := fonte.length
		var anim := Animation.new(); anim.length = dur
		anim.loop_mode = Animation.LOOP_LINEAR if anims[nome][1] else Animation.LOOP_NONE
		var faixas := {}
		for t in ordem_t:
			var tr := anim.add_track(Animation.TYPE_ROTATION_3D); anim.track_set_path(tr, caminho + ":" + t); faixas[t] = tr
		var tr_hip := anim.add_track(Animation.TYPE_POSITION_3D); anim.track_set_path(tr_hip, caminho + ":" + hip_t)
		var n := int(round(dur * 30.0)) + 1
		ap.play(ap.get_animation_list()[0])
		for q in n:
			var tempo := minf(q / 30.0, dur)
			ap.seek(tempo, true); ap.advance(0.0)
			var s_pose := _poses(sk)
			var raiz_inv: Transform3D = (s_pose[raiz_s] as Transform3D).affine_inverse()     # tira o giro da raiz
			var g_t := {}
			for t in ordem_t:
				var s: String = inv[t]
				var gs: Transform3D = raiz_inv * s_pose[s]
				var ds: Basis = gs.basis.orthonormalized() * (s_tp[s] as Transform3D).basis.orthonormalized().inverse()
				var dt: Basis = C * ds * C.inverse()
				var b: Basis = dt * Basis(alinha[t]) * (t_rest[t] as Transform3D).basis.orthonormalized()
				g_t[t] = b
				var pai_i := tgt.get_bone_parent(tgt.find_bone(t))
				var pai_g := Basis()
				# pai: o mapeado mais próximo (os ossos de torção no meio ficam no repouso)
				var p := pai_i
				var cadeia := Basis()
				while p >= 0 and not g_t.has(tgt.get_bone_name(p)):
					p = tgt.get_bone_parent(p)
				if p >= 0:
					var pn := tgt.get_bone_name(p)
					# global do pai real = global do mapeado * (repouso relativo até o pai real)
					var rel: Basis = (t_rest[pn] as Transform3D).basis.orthonormalized().inverse() * (tgt.get_bone_global_rest(pai_i).basis.orthonormalized())
					pai_g = (g_t[pn] as Basis) * rel
				else:
					pai_g = tgt.get_bone_global_rest(pai_i).basis.orthonormalized() if pai_i >= 0 else Basis()
				var loc: Basis = pai_g.inverse() * b
				anim.rotation_track_insert_key(faixas[t], tempo, loc.get_rotation_quaternion())
			# quadril: sobe/desce e se mexe junto (em escala do herói)
			var hp: Vector3 = C * ((raiz_inv * s_pose[pelvis]).origin - (s_tp[pelvis] as Transform3D).origin) * (alt_t / alt_s)
			var hip_rest := tgt.get_bone_rest(tgt.find_bone(hip_t)).origin
			anim.position_track_insert_key(tr_hip, tempo, hip_rest + hp)
		lib.add_animation(nome, anim)
		print("ANIM ", nome, " ", dur, " s, ", n, " quadros")
		f[2].queue_free()
	herói.queue_free()

func _fonte(nome: String) -> Array:
	var s: Node3D = load("res://_anim_src/%s.fbx" % nome).instantiate(); root.add_child(s)
	if not s.find_children("*", "AnimationPlayer", true, false): push_error("sem animação: " + nome)
	var sk: Skeleton3D = s.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = s.find_children("*", "AnimationPlayer", true, false)[0]
	ap.play(ap.get_animation_list()[0]); ap.seek(0.0, true)
	return [sk, ap, s]

func _poses(sk: Skeleton3D) -> Dictionary:       # globais montadas das poses locais (o cache global não atualiza no seek)
	var d := {}; var g := {}
	for i in sk.get_bone_count():
		var pai := sk.get_bone_parent(i)
		var loc := sk.get_bone_pose(i)
		g[i] = (g[pai] as Transform3D) * loc if pai >= 0 else loc
		d[sk.get_bone_name(i)] = g[i]
	return d

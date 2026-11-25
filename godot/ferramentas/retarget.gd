# Converte animações do pacote "Sword and Shield Animations" (esqueleto do manequim do Unreal, FBX em _anim_src/,
# fora do git) para o esqueleto dos nossos heróis (o do NPC base do Tripo) e grava uma AnimationLibrary em
# res://assets/animacoes/heroi.res. Para cada quadro: a rotação de cada osso no mundo, relativa à pose T do pacote,
# é convertida de eixo (pacote: esquerda +X, frente +Z → nosso: frente +X, direita +Z) e aplicada sobre a pose de
# repouso do herói já "alinhada" com a pose T (cada osso de braço/perna gira até a direção do mesmo osso na pose T).
# Uso: godot --headless --path godot --script res://ferramentas/retarget.gd
extends SceneTree

const MAPA := {"pelvis": "Hip", "spine_01": "Waist", "spine_02": "Spine01", "spine_03": "Spine02", "neck_01": "NeckTwist01",
	"head": "Head", "clavicle_l": "L_Clavicle", "upperarm_l": "L_Upperarm", "lowerarm_l": "L_Forearm", "hand_l": "L_Hand",
	"clavicle_r": "R_Clavicle", "upperarm_r": "R_Upperarm", "lowerarm_r": "R_Forearm", "hand_r": "R_Hand",
	"thigh_l": "L_Thigh", "calf_l": "L_Calf", "foot_l": "L_Foot", "ball_l": "L_ToeBase",
	"thigh_r": "R_Thigh", "calf_r": "R_Calf", "foot_r": "R_Foot", "ball_r": "R_ToeBase"}
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
const C := Basis(Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0))

var tgt: Skeleton3D
var t_rest := {}           # osso alvo → global rest
var ordem_t: Array[String] = []

func _initialize() -> void:
	var herói: Node3D = load("res://assets/modelos/humana.glb").instantiate(); root.add_child(herói)
	tgt = herói.find_children("*", "Skeleton3D", true, false)[0]
	var caminho := String(herói.get_path_to(tgt))
	for i in tgt.get_bone_count(): t_rest[tgt.get_bone_name(i)] = tgt.get_bone_global_rest(i)
	# ordem pai → filho dos ossos mapeados
	for i in tgt.get_bone_count():
		var n := tgt.get_bone_name(i)
		if n in MAPA.values(): ordem_t.append(n)
	var inv := {}
	for k in MAPA.keys(): inv[MAPA[k]] = k
	# pose T do pacote
	var tp := _fonte("T_pose"); var sk_tp: Skeleton3D = tp[0]
	var s_tp := _poses(sk_tp)
	var tp_raiz: Transform3D = (s_tp["root"] as Transform3D).affine_inverse()
	for k in s_tp.keys(): s_tp[k] = tp_raiz * s_tp[k]          # tudo relativo à raiz (a raiz deita o esqueleto)
	# alinhamento do repouso: rotação que leva a direção do osso no nosso repouso até a da pose T (convertida)
	var alinha := {}
	for t in ordem_t:
		alinha[t] = Quaternion()
		if DIR_T.has(t):
			var s: String = inv[t]
			var dt: Vector3 = (t_rest[DIR_T[t]].origin - t_rest[t].origin).normalized()
			var ds: Vector3 = C * (s_tp[DIR_S[s]].origin - s_tp[s].origin).normalized()
			alinha[t] = Quaternion(dt, ds)
	var lib := AnimationLibrary.new()
	var alt_s: float = s_tp["pelvis"].origin.z; var alt_t: float = t_rest["Hip"].origin.y
	for nome in ANIMS.keys():
		var arq: String = ANIMS[nome][0]
		var f := _fonte("SwordAndShield_" + arq)
		var sk: Skeleton3D = f[0]; var ap: AnimationPlayer = f[1]
		var fonte: Animation = ap.get_animation(ap.get_animation_list()[0])
		var dur := fonte.length
		var anim := Animation.new(); anim.length = dur
		anim.loop_mode = Animation.LOOP_LINEAR if ANIMS[nome][1] else Animation.LOOP_NONE
		var faixas := {}
		for t in ordem_t:
			var tr := anim.add_track(Animation.TYPE_ROTATION_3D); anim.track_set_path(tr, caminho + ":" + t); faixas[t] = tr
		var tr_hip := anim.add_track(Animation.TYPE_POSITION_3D); anim.track_set_path(tr_hip, caminho + ":Hip")
		var n := int(round(dur * 30.0)) + 1
		ap.play(ap.get_animation_list()[0])
		for q in n:
			var tempo := minf(q / 30.0, dur)
			ap.seek(tempo, true); ap.advance(0.0)
			var s_pose := _poses(sk)
			var raiz_inv: Transform3D = (s_pose["root"] as Transform3D).affine_inverse()     # tira o giro da raiz
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
			var hp: Vector3 = C * ((raiz_inv * s_pose["pelvis"]).origin - (s_tp["pelvis"] as Transform3D).origin) * (alt_t / alt_s)
			var hip_rest := tgt.get_bone_rest(tgt.find_bone("Hip")).origin
			anim.position_track_insert_key(tr_hip, tempo, hip_rest + hp)
		lib.add_animation(nome, anim)
		print("ANIM ", nome, " ", dur, " s, ", n, " quadros")
		f[2].queue_free()
	DirAccess.make_dir_recursive_absolute("res://assets/animacoes")
	print("SALVO ", ResourceSaver.save(lib, "res://assets/animacoes/heroi.res"))
	quit()

func _fonte(nome: String) -> Array:
	var s: Node3D = load("res://_anim_src/%s.fbx" % nome).instantiate(); root.add_child(s)
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

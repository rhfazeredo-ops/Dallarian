# Dallarian em primeira pessoa, com animações de braços no estilo dos RPGs de ação em primeira pessoa:
# respiração parada, balanço ao andar/correr, armas que "atrasam" ao girar a câmera, combo de 3 golpes
# (diagonal da direita, diagonal da esquerda, de cima), golpe forte segurando o botão (puxa, solta e dá um
# tranco para a frente), bloqueio com o escudo (segurando) e escudada (atacar enquanto bloqueia).
# Os braços (luva + antebraço com braçadeira) seguram a espada (modelo do Tripo) e o escudo (provisório).
extends CharacterBody3D
class_name Jogador

const VEL := 4.4
const VEL_CORRER := 7.2
const PULO := 4.8
const GRAV := 13.0
const SENS_MOUSE := 0.0025
const SENS_TOQUE := 0.006
const SEGURAR_FORTE := 0.3     # segurar o ataque por mais que isso = golpe forte

var controles: Controles
var pescoco: Node3D            # gira para cima/baixo (olhar)
var cam: Camera3D              # recebe balanço e trancos
var mao: Node3D                # espaço dos braços (preso à câmera)
var piv_d: Node3D              # mão direita (cabo da espada)
var piv_e: Node3D              # mão esquerda (alça do escudo)
var braco_d: MeshInstance3D
var braco_e: MeshInstance3D

# MÃO DIREITA = [posição do cabo, direção da lâmina, normal da face da lâmina], no espaço da câmera
# (x direita, y cima, -z frente). A espada é montada a partir disso: lâmina = direção, guarda = perpendicular.
const MAO := {
	"repouso": [Vector3(0.34, -0.44, -0.56), Vector3(-0.02, 1.0, -0.1), Vector3(0.15, 0.0, 1.0)],
	"correr": [Vector3(0.36, -0.5, -0.5), Vector3(0.05, 1.0, -0.18), Vector3(0.2, 0.0, 1.0)],     # em pé também correndo
	"bloq": [Vector3(0.38, -0.52, -0.5), Vector3(0.2, 0.5, -0.85), Vector3(0.6, 0.0, 0.8)],
}
# GOLPES (copiados do vídeo de referência de espada e escudo em primeira pessoa, quadro a quadro):
#  - guarda: espada em pé à direita, escudo aparecendo embaixo à esquerda;
#  - preparação rápida que tira a espada da tela (para cima/para o lado);
#  - corte muito rápido (~0,1 s) atravessando a tela, a lâmina grande e de lado;
#  - a espada termina fora da tela e VOLTA SUBINDO por baixo, em pé, até a guarda.
# a/da = cabo e lâmina na preparação; dm = lâmina no meio do corte; b/db = fim; c = controle do caminho da mão.
const GOLPES := {
	# 1: diagonal de cima à direita até embaixo à esquerda
	"leve1": { "a": Vector3(0.5, 0.06, -0.46), "da": Vector3(0.5, 0.78, 0.36), "dm": Vector3(-0.55, 0.2, -0.82),
		"b": Vector3(-0.78, -0.58, -0.42), "db": Vector3(-0.82, -0.45, -0.35), "c": Vector3(0.12, -0.08, -0.78),
		"t": [0.32, 0.22, 0.12, 0.65], "tranco": Vector3(-1.5, 3.0, 0.05), "giro": -2.5 },
	# 2: horizontal da esquerda para a direita, perto da altura dos olhos: a lâmina fica DEITADA o golpe todo
	"leve2": { "a": Vector3(-0.55, -0.16, -0.42), "da": Vector3(-0.92, -0.02, 0.38), "dm": Vector3(0.86, -0.03, -0.5),
		"b": Vector3(0.75, -0.24, -0.4), "db": Vector3(0.95, -0.05, 0.3), "c": Vector3(-0.42, -0.22, -0.56),
		"t": [0.32, 0.22, 0.12, 0.65], "tranco": Vector3(-1.0, -3.0, 0.05), "giro": 3.0 },
	# 3: de cima para baixo pelo meio (fecha o combo)
	# (a lâmina fica EM PÉ, no plano vertical da tela, do começo ao fim)
	"leve3": { "a": Vector3(0.14, 0.08, -0.5), "da": Vector3(0.0, 0.9, 0.42), "dm": Vector3(0.0, 0.45, -0.89),
		"b": Vector3(0.08, -0.72, -0.5), "db": Vector3(0.0, -0.75, -0.66), "c": Vector3(0.12, 0.1, -0.72),
		"t": [0.34, 0.22, 0.13, 0.68], "tranco": Vector3(-5.0, 0.5, 0.08), "giro": 0.0 },
	# forte: a diagonal com preparação longa (segurando) e o corpo indo junto
	"forte": { "a": Vector3(0.55, 0.1, -0.4), "da": Vector3(0.55, 0.72, 0.42), "dm": Vector3(-0.5, 0.25, -0.83),
		"b": Vector3(-0.8, -0.62, -0.4), "db": Vector3(-0.85, -0.45, -0.3), "c": Vector3(0.1, -0.06, -0.84),
		"t": [0.45, 0.24, 0.16, 0.75], "tranco": Vector3(-5.0, 6.0, 0.32), "giro": -5.0 },
}
# poses da mão esquerda (escudo): [posição, rotação em graus]
const PE := {
	"e_repouso": [Vector3(-0.52, -0.56, -0.6), Vector3(80, 10, -22)],
	"e_golpe": [Vector3(-0.54, -0.6, -0.6), Vector3(78, 10, -26)],
	"e_correr": [Vector3(-0.52, -0.64, -0.5), Vector3(70, 20, -40)],
	"e_bloq": [Vector3(-0.12, -0.2, -0.46), Vector3(88, 0, -5)],
	"bash_prep": [Vector3(-0.2, -0.24, -0.38), Vector3(88, 10, -10)],
	"bash_fim": [Vector3(-0.06, -0.14, -0.78), Vector3(92, -5, 0)],
}
# escudada: [duração, pose da esquerda (ou "" = volta), tranco]
const BASH := [[0.08, "bash_prep", Vector3.ZERO], [0.1, "bash_fim", Vector3(-2, 0, 0.12)], [0.28, "", Vector3.ZERO]]

# estado da mão direita (sempre: a espada é montada daqui)
var _hp := Vector3(0.34, -0.44, -0.56); var _hd := Vector3(-0.02, 1.0, -0.1).normalized(); var _hn := Vector3(0.35, 0, 1).normalized()
var _fase := 0; var _sp := Vector3.ZERO; var _sd := Vector3.UP; var _sn := Vector3.BACK
var _acao := ""; var _passo_acao := 0; var _t_acao := 0.0
var _ini_e: Transform3D
var _combo := 0; var _proximo := false; var _ultimo_golpe := 0.0
var _segurando := 0.0; var _ataque_seg := false; var _forte_pronto := false
var _passo := 0.0; var _tempo := 0.0
var _balanco := Vector2.ZERO     # armas atrasam ao girar
var _tranco := Vector3.ZERO      # câmera: pitch, roll, avanço
var _parado := 0.0               # 0..1: quanto está parado (idle)
var _giro := 0.0                 # câmera: vira um pouco junto com o golpe (graus)
var _queda := 0.0; var _no_chao := true
var _pulo_pedido := 0.0; var _coyote := 0.0
var bloqueando := false
var alvo: Node3D = null            # mira travada (Tab / botão ALVO): a câmera segue esse inimigo
var bloqueios_desde_erguer := 0    # o 1º ataque depois de levantar o escudo é bloqueado inteiro
var congelar := -1.0             # teste: para a ação nesse ponto (0..1)
var pose_fixa := false           # teste: mãos paradas numa pose (mostrar_pose)
# montaria: o cavalo fica preso embaixo da Rachel (a câmera sobe para a altura da sela e os braços somem;
# vê-se o pescoço e a cabeça do cavalo balançando no galope). 60% mais rápido, como no WoW.
const VEL_MONTARIA := 1.6
const ALTURA_OLHOS := 1.62
const ALTURA_MONTADA := 2.5
var montado := false
var montaria_id := ""
var cavalo: Node3D
var _anim_cavalo: Node
var _corpo_cavalo: CollisionShape3D   # caixa do corpo do cavalo (acima do chão, para não prender em degraus)

# morte em primeira pessoa: a cabeça tomba de lado e cai até o chão (acelerando), os braços saem da tela e a
# câmera treme na batida; fica caída até reviver() (o mundo faz a tela vermelha, o "VOCÊ MORREU" e o renascer)
var morta := false
var _t_morte := 0.0
var _bateu := false
func morrer() -> void:
	desmontar(); morta = true; _t_morte = 0.0; _bateu = false; alvo = null
	velocity.x = 0.0; velocity.z = 0.0; _acao = ""
func reviver() -> void:
	morta = false; _t_morte = 0.0
	pescoco.position.y = ALTURA_OLHOS; pescoco.rotation = Vector3.ZERO
	mao.visible = true; mao.position = Vector3.ZERO
func _cair_morta(delta: float) -> void:
	_t_morte += delta
	var u := clampf(_t_morte / 0.95, 0.0, 1.0); var e := u * u
	pescoco.position.y = lerpf(ALTURA_OLHOS, 0.26, e)
	pescoco.rotation.z = lerpf(0.0, 1.3, e)                     # tomba para o lado
	pescoco.rotation.x = lerpf(pescoco.rotation.x, -0.12, minf(1.0, delta * 3.0))
	mao.position = Vector3(0.0, -0.7 * e, 0.15 * e)              # braços saem pela parte de baixo da tela
	if u >= 1.0 and not _bateu:
		_bateu = true; _tremor = 0.7; mao.visible = false
	_tremor = maxf(0.0, _tremor - delta * 2.5)
	var tr := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _tremor * _tremor * 0.03
	cam.position = tr; cam.rotation = Vector3.ZERO
	velocity.x = 0.0; velocity.z = 0.0
	if not is_on_floor(): velocity.y -= GRAV * delta
	move_and_slide()

func montar_em(id: String, modelo: Node3D) -> void:
	if montado: desmontar()
	montado = true; montaria_id = id; cavalo = modelo
	add_child(cavalo); cavalo.position = Vector3(0, 0, -float(cavalo.get_meta("sela_z", 0.1)))       # a sela fica embaixo da câmera
	_corpo_cavalo = CollisionShape3D.new(); var bx := BoxShape3D.new(); bx.size = Vector3(0.9, 1.3, 2.6)
	_corpo_cavalo.shape = bx; _corpo_cavalo.position = Vector3(0, 1.4, -0.35); add_child(_corpo_cavalo)
	for c in cavalo.get_children():
		if c.get_script() != null: _anim_cavalo = c; c.inclinar = -0.6
	mao.visible = false; alvo = null
	pescoco.position.y = ALTURA_MONTADA - 0.5          # "sobe" na sela (termina de subir no _physics_process)

func desmontar() -> void:
	if not montado: return
	montado = false; montaria_id = ""
	if cavalo: cavalo.queue_free()
	if _corpo_cavalo: _corpo_cavalo.queue_free(); _corpo_cavalo = null
	cavalo = null; _anim_cavalo = null
	mao.visible = true

func _ready() -> void:
	var cs := CollisionShape3D.new(); var cap := CapsuleShape3D.new(); cap.radius = 0.35; cap.height = 1.75
	cs.shape = cap; cs.position = Vector3(0, 0.875, 0); add_child(cs)
	floor_snap_length = 0.4; floor_max_angle = deg_to_rad(48)
	pescoco = Node3D.new(); pescoco.position = Vector3(0, 1.62, 0); add_child(pescoco)
	cam = Camera3D.new(); cam.fov = 70; cam.near = 0.04; cam.far = 900
	pescoco.add_child(cam); cam.current = true
	mao = Node3D.new(); cam.add_child(mao)
	_armas()
	piv_d.transform = _mao_t(_hp, _hd, _hn); piv_e.transform = _pose("e_repouso")

func _pose(n: String) -> Transform3D:
	var pe: Array = PE[n]
	return Transform3D(Basis.from_euler(pe[1] * (PI / 180.0)), pe[0])

# espada: eixo Y = lâmina, Z = normal da face, X = guarda (no plano do fio)
func _mao_t(p: Vector3, d: Vector3, n: Vector3) -> Transform3D:
	var y := d.normalized()
	var z := (n - y * n.dot(y))
	z = z.normalized() if z.length() > 0.001 else y.cross(Vector3.RIGHT).normalized()
	return Transform3D(Basis(y.cross(z), y, z), p)

func _normal_golpe(g: Dictionary) -> Vector3:
	var da: Vector3 = g.da.normalized(); var dm: Vector3 = g.dm.normalized(); var db: Vector3 = g.db.normalized()
	return (da.cross(dm).normalized() + dm.cross(db).normalized()).normalized()

# arco da lâmina: duas interpolações esféricas encadeadas (passa pela frente, sem atalho torto)
func _arco(da: Vector3, dm: Vector3, db: Vector3, u: float) -> Vector3:
	var x := da.normalized().slerp(dm.normalized(), u); var y := dm.normalized().slerp(db.normalized(), u)
	return x.slerp(y, u).normalized()

# ---------- armas e braços ----------
func _armas() -> void:
	var m: Node = get_tree().current_scene
	piv_d = Node3D.new(); mao.add_child(piv_d)
	# espada inicial de madeira (Tripo): eixo medido com tools/eixo-ferramenta.mjs — lâmina para -eixo,
	# guarda na direção do trecho mais largo, cabo em t≈0,33; 1,367 m no arquivo → 1 m (esp escala para 0,85 m)
	_esp = Node3D.new(); piv_d.add_child(_esp); _esp.scale = Vector3(0.85, 0.85, 0.85)
	trocar_equip("arma", "espada_treino")
	piv_d.add_child(_punho(m, false))
	# escudo inicial de madeira (Tripo): frente (com o umbo) em +X no arquivo, alça atrás; 0,97 m → 0,6 m
	piv_e = Node3D.new(); mao.add_child(piv_e)
	_esc = Node3D.new(); piv_e.add_child(_esc)
	trocar_equip("escudo", "escudo_madeira")
	var pe := _punho(m, true); pe.position = Vector3(0, -0.07, 0); piv_e.add_child(pe)
	braco_d = _antebraco(m); mao.add_child(braco_d)
	braco_e = _antebraco(m); mao.add_child(braco_e)

# troca o modelo da arma/escudo na mão conforme o item equipado (o "cabo na origem, lâmina em +Y" é a regra)
var _esp: Node3D
var _esc: Node3D
func trocar_equip(lugar: String, id: String) -> void:
	var m: Node = get_tree().current_scene
	var no := _esp if lugar == "arma" else _esc
	if no == null: return
	for c in no.get_children(): c.queue_free()
	if id == "": return
	var modelo: String = Bolsa.ITENS[id].get("modelo", "")
	if lugar == "arma" and modelo == "madeira":
		# espada de treino (Tripo): eixo medido com tools/eixo-ferramenta.mjs — lâmina para -eixo, guarda no trecho
		# mais largo, cabo em t≈0,33; 1,367 m no arquivo → 1 m (o nó escala para 0,85 m)
		var mod: Node3D = m.modelo_ps1("res://assets/modelos/espada_madeira.glb")
		var eixo := Vector3(0.257, -0.6737, 0.6929).normalized()
		var lam := -eixo
		var gua := Vector3(0.127, -0.687, -0.715); gua = (gua - lam * gua.dot(lam)).normalized()
		var face := gua.cross(lam)
		var cabo := Vector3(0.0356, -0.0789, 0.0842) + eixo * 0.33
		var r := Basis(gua, lam, face).transposed()
		var k := 1.0 / 1.367
		mod.transform = Transform3D(r.scaled(Vector3(k, k, k)), -(r * cabo) * k)
		no.add_child(mod)
	elif lugar == "arma" and modelo == "presa" and ResourceLoader.exists("res://assets/modelos/presa_da_mare.glb"):
		# Presa da Maré (Tripo, quando chegar): mesmo encaixe da espada de ferro, lâmina em +Y, 1 m
		var mod: Node3D = m.modelo_ps1("res://assets/modelos/presa_da_mare.glb")
		var bb := AABB()
		for mi in mod.find_children("*", "MeshInstance3D", true, false): bb = mi.get_aabb() if bb.size == Vector3.ZERO else bb.merge(mi.get_aabb())
		var k := 0.95 / maxf(bb.size.y, 0.01)
		var giro := 0.0          # lado liso da lâmina para a frente, os dentes virados para a Rachel
		mod.scale = Vector3(k, k, k); mod.rotation.y = giro
		var cabo := Vector3(bb.get_center().x, bb.position.y + bb.size.y * 0.2, bb.get_center().z)   # o arquivo não vem centrado
		mod.position = -(Basis(Vector3.UP, giro) * cabo) * k
		no.add_child(mod)
	elif lugar == "arma" and modelo == "malho" and ResourceLoader.exists("res://assets/modelos/malho_tronco.glb"):
		# Malho de Tronco (Tripo, quando chegar): cabo na mão, cabeça para cima, ~0,8 m
		var mod: Node3D = m.modelo_ps1("res://assets/modelos/malho_tronco.glb")
		var bb := AABB()
		for mi in mod.find_children("*", "MeshInstance3D", true, false): bb = mi.get_aabb() if bb.size == Vector3.ZERO else bb.merge(mi.get_aabb())
		var k := 0.8 / maxf(bb.size.y, 0.01)
		mod.scale = Vector3(k, k, k)
		var cabo := Vector3(bb.get_center().x, bb.position.y + bb.size.y * 0.15, bb.get_center().z)
		mod.position = -cabo * k
		no.add_child(mod)
	elif lugar == "arma" and (modelo == "ferro" or modelo == "presa" or modelo == "malho"):        # (presa: a de ferro até chegar o modelo)
		# espada de ferro (a primeira do Tripo): 0,51 m no arquivo → 1 m; cabo na origem, lâmina em +Y
		var mod: Node3D = m.modelo_ps1("res://assets/modelos/espada.glb")
		var k := 1.0 / 0.51
		mod.scale = Vector3(k, k, k); mod.rotation_degrees.y = 90
		mod.position = Vector3(-0.131, -0.075, 0) * k
		no.add_child(mod)
	elif lugar == "escudo" and modelo in ["ferro", "egide"] and ResourceLoader.exists("res://assets/modelos/escudo_%s.glb" % modelo):
		# escudos do Tripo (quando chegarem): mesmo encaixe do de madeira — frente em +X no arquivo, 0,6 m
		var esc: Node3D = m.modelo_ps1("res://assets/modelos/escudo_%s.glb" % modelo)
		var bb := AABB()
		for mi in esc.find_children("*", "MeshInstance3D", true, false): bb = mi.get_aabb() if bb.size == Vector3.ZERO else bb.merge(mi.get_aabb())
		var ke := 0.62 / maxf(maxf(bb.size.y, bb.size.z), 0.01)
		esc.scale = Vector3(ke, ke, ke); esc.rotation_degrees = Vector3(0, 0, 90)
		esc.position = Vector3(0, -bb.position.x * ke - 0.07, 0) - Vector3(bb.get_center().y, 0, bb.get_center().z).rotated(Vector3.FORWARD, 0) * 0.0
		no.add_child(esc)
	elif lugar == "escudo":
		# escudo de madeira (Tripo): frente (com o umbo) em +X no arquivo, alça atrás; 0,97 m → 0,6 m
		var esc: Node3D = m.modelo_ps1("res://assets/modelos/escudo_madeira.glb")
		var ke := 0.6 / 0.97
		esc.scale = Vector3(ke, ke, ke); esc.rotation_degrees = Vector3(0, 0, 90)   # +X do arquivo → +Y (frente)
		esc.position = Vector3(0, 0.223 * ke - 0.07, 0)                             # parte de trás na mão
		no.add_child(esc)

# luva de couro fechada (low poly)
func _punho(m: Node, esquerda: bool) -> MeshInstance3D:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	m._caixa(st, Vector3(0, 0, 0.0), Vector3(0.085, 0.1, 0.095))          # mão fechada no cabo
	m._caixa(st, Vector3(0, 0.0, -0.05), Vector3(0.075, 0.085, 0.03))      # dedos dobrados
	var mi := MeshInstance3D.new(); var mesh := ArrayMesh.new()
	st.set_material(m.mat("", 1.0, Color(0.33, 0.21, 0.14))); st.commit(mesh)
	mi.mesh = mesh
	if esquerda: mi.rotation_degrees = Vector3(0, 0, 90)
	return mi

# antebraço: braçadeira de couro com faixa de metal e pele no pulso (cilindro ao longo de +Y, 1 m)
func _antebraco(m: Node) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	m.cilindro(st, Vector3(0, 0.12, 0), 0.05, 0.062, 0.88, 7)
	st.set_material(m.mat("", 1.0, Color(0.27, 0.19, 0.14))); st.commit(mesh)
	st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	m.cilindro(st, Vector3(0, 0.0, 0), 0.042, 0.048, 0.12, 7)
	st.set_material(m.mat("", 1.0, Color(0.86, 0.6, 0.45))); st.commit(mesh)
	st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	m.cilindro(st, Vector3(0, 0.3, 0), 0.064, 0.064, 0.06, 7); m.cilindro(st, Vector3(0, 0.62, 0), 0.068, 0.068, 0.06, 7)
	st.set_material(m.mat("", 1.0, Color(0.72, 0.6, 0.32))); st.commit(mesh)
	var mi := MeshInstance3D.new(); mi.mesh = mesh; return mi

# põe o antebraço saindo da mão em direção ao ombro (fora da tela)
func _ajustar_braco(braco: MeshInstance3D, mao_pos: Vector3, ombro: Vector3) -> void:
	var dir := (ombro - mao_pos).normalized()
	var x := dir.cross(Vector3(0, 0, 1)).normalized()
	if x.length() < 0.1: x = Vector3(1, 0, 0)
	var z := x.cross(dir)
	braco.transform = Transform3D(Basis(x, dir, z).scaled(Vector3(1, 0.42, 1)), mao_pos)

# teste: "d=leve1_fim,e=e_bloq" → mãos paradas nessas poses
func mostrar_pose(txt: String) -> void:
	pose_fixa = true
	for parte in txt.split(","):
		var kv := parte.split("=")
		if kv[0] == "d":
			var g := kv[1].split(":")                       # golpe:fase:u  (ou repouso/correr/bloq)
			if MAO.has(g[0]):
				var mm: Array = MAO[g[0]]; piv_d.transform = _mao_t(mm[0], mm[1], mm[2])
			else:
				iniciar(g[0]); _fase = int(g[1]); congelar = float(g[2]); _tocar_golpe(0.0); piv_d.transform = _mao_t(_hp, _hd, _hn)
		else: piv_e.transform = _pose(kv[1])

# rastro da lâmina no corte (faixa clara que some rápido): deixa o movimento legível mesmo em FPS baixo
var _rastro: ImmediateMesh
var _rastro_pts := []          # [base, ponta, idade] no espaço de "mao"
func _rastro_criar() -> void:
	_rastro = ImmediateMesh.new()
	var mi := MeshInstance3D.new(); mi.mesh = _rastro
	var mt := StandardMaterial3D.new(); mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; mt.vertex_color_use_as_albedo = true
	mt.cull_mode = BaseMaterial3D.CULL_DISABLED; mt.no_depth_test = false
	mi.material_override = mt; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mao.add_child(mi)

func _rastro_atualizar(delta: float) -> void:
	if _rastro == null: _rastro_criar()
	for p in _rastro_pts: p[2] += delta
	while not _rastro_pts.is_empty() and _rastro_pts[0][2] > 0.11: _rastro_pts.pop_front()
	var cortando := GOLPES.has(_acao) and (_fase == 1 or (_fase == 2 and _t_acao < 0.03))
	if cortando:
		var t := piv_d.transform
		_rastro_pts.append([t * Vector3(0, 0.55, 0), t * Vector3(0, 0.84, 0), 0.0])
	_rastro.clear_surfaces()
	if _rastro_pts.size() < 2: return
	_rastro.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for p in _rastro_pts:
		var a := clampf(1.0 - p[2] / 0.11, 0.0, 1.0) * 0.6
		_rastro.surface_set_color(Color(0.95, 0.97, 1.0, 0.0)); _rastro.surface_add_vertex(p[0])
		_rastro.surface_set_color(Color(0.95, 0.97, 1.0, a)); _rastro.surface_add_vertex(p[1])
	_rastro.surface_end()

# ---------- entrada ----------
func _unhandled_input(e: InputEvent) -> void:
	if OS.has_feature("mobile") or DisplayServer.is_touchscreen_available(): return
	if e is InputEventMouseButton:
		if e.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED; return
		if e.button_index == MOUSE_BUTTON_LEFT and controles: controles.ataque_mouse = e.pressed
		if e.button_index == MOUSE_BUTTON_RIGHT and controles: controles.bloqueio_mouse = e.pressed
	elif e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if alvo == null: _girar(e.relative * SENS_MOUSE)
	elif e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

# ---------- travar a mira ----------
func _vivo(n: Node) -> bool:
	return n != null and is_instance_valid(n) and n.is_inside_tree() and n.get("estado") != "morto" and n.is_in_group("lobos")

func _trocar_alvo() -> void:
	if alvo != null: alvo = null; return
	var fr := -global_transform.basis.z
	var melhor: Node3D = null; var nota := 1e9
	for n in get_tree().get_nodes_in_group("lobos"):
		if not _vivo(n): continue
		var d: Vector3 = n.global_position - global_position; d.y = 0.0
		var dist := d.length()
		if dist > 30.0: continue
		var frente := fr.dot(d.normalized())
		var p := dist * (1.0 + (1.0 - frente) * 1.5)              # prefere quem está na frente e perto
		if p < nota: nota = p; melhor = n
	alvo = melhor

func _seguir_alvo(delta: float) -> void:
	if alvo == null: return
	if not _vivo(alvo) or alvo.global_position.distance_to(global_position) > 40.0:
		alvo = null; return
	var altura_alvo: float = 0.8
	if alvo.get("k") != null and alvo is Monstro: altura_alvo = alvo.k * 0.6
	var d: Vector3 = alvo.global_position + Vector3(0, altura_alvo, 0) - pescoco.global_position
	var yaw := atan2(-d.x, -d.z)
	var f := 1.0 - exp(-10.0 * delta)
	var antes := rotation.y
	rotation.y = lerp_angle(rotation.y, yaw, f)
	var pitch := atan2(d.y, Vector2(d.x, d.z).length())
	pescoco.rotation.x = lerpf(pescoco.rotation.x, clampf(pitch, deg_to_rad(-60), deg_to_rad(45)), f)
	_balanco += Vector2(-(wrapf(rotation.y - antes, -PI, PI)), 0.0) * 0.6

func _girar(d: Vector2) -> void:
	rotation.y -= d.x
	pescoco.rotation.x = clamp(pescoco.rotation.x - d.y, deg_to_rad(-85), deg_to_rad(85))
	_balanco += Vector2(-d.x, d.y) * 0.6

# ---------- ações ----------
func iniciar(nome: String) -> void:
	_acao = nome; _passo_acao = 0; _t_acao = 0.0; _fase = 0
	if GOLPES.has(nome): get_tree().call_group("lobos", "heroina_atacou", global_position, -global_transform.basis.z)
	_sp = _hp; _sd = _hd; _sn = _hn
	_ini_e = piv_e.transform

func _golpe_leve() -> void:
	if _acao == "" or _acao == "bash":
		if _tempo - _ultimo_golpe > 1.6: _combo = 0
		iniciar(["leve1", "leve2", "leve3"][_combo % 3]); _combo += 1; _ultimo_golpe = _tempo
	elif _acao.begins_with("leve"):
		_proximo = true                       # guarda o próximo golpe do combo

func _ataque(segurando: bool, bloqueando: bool, delta: float) -> void:
	if segurando and not _ataque_seg:          # apertou
		_segurando = 0.0; _forte_pronto = false
		if bloqueando and _acao == "": iniciar("bash")
	if segurando:
		_segurando += delta
		if not bloqueando and _segurando > SEGURAR_FORTE and not _forte_pronto and _acao == "":
			_forte_pronto = true; iniciar("forte")      # puxa a espada para trás e espera soltar
	if not segurando and _ataque_seg:          # soltou
		if not _forte_pronto and not bloqueando: _golpe_leve()
	_ataque_seg = segurando

# impacto: congela o golpe por um instante e treme a câmera (dá peso)
var _pausa := 0.0
var _tremor := 0.0
func impacto(seg: float) -> void:
	_pausa = seg; _tremor = max(_tremor, 0.8 if seg < 0.1 else 1.3)

# um golpe de espada: preparação → corte (arco) → seguir → volta
func _tocar_golpe(delta: float, base: Array = MAO["repouso"]) -> void:
	var g: Dictionary = GOLPES[_acao]; var tempos: Array = g.t
	var dur: float = tempos[_fase]
	var esperando := _acao == "forte" and _fase == 0 and _t_acao >= dur and _ataque_seg and _segurando < 1.4
	if _pausa > 0.0:
		_pausa -= delta; delta = 0.0               # instante de impacto: tudo para
	if not esperando: _t_acao += delta
	var u: float = clampf(_t_acao / dur, 0.0, 1.0)
	if congelar >= 0.0: u = congelar
	var ng := _normal_golpe(g)
	match _fase:
		0:   # preparação: o peso do corpo vai para trás — sobe rápido e DESACELERA no alto (carregando o golpe)
			var e := 1.0 - pow(1.0 - u, 2.6)
			_hp = _sp.lerp(g.a, e); _hd = _sd.slerp(g.da.normalized(), e); _hn = _sn.slerp(ng, e).normalized()
			_tranco = _tranco.lerp(Vector3(-g.tranco.x * 0.35, -g.tranco.y * 0.4, -0.05), 0.12)   # corpo inclina para trás
			_giro = lerp(_giro, -float(g.get("giro", 0.0)) * 0.6, 0.1)
			if esperando: _hp += Vector3(0.006, 0.004, 0.004) * sin(_tempo * 30.0)     # tremidinha segurando
		1:   # corte: começa pesado (devagar) e ACELERA até o fim — massa ganhando velocidade
			var e := pow(u, 2.2)
			var a: Vector3 = g.a; var c: Vector3 = g.c; var b: Vector3 = g.b
			_hp = a.lerp(c, e).lerp(c.lerp(b, e), e)
			_hd = _arco(g.da, g.dm, g.db, e); _hn = ng
			# o corpo vai junto: câmera avança e gira com a lâmina
			_tranco = _tranco.lerp(g.tranco * Vector3(0.6, 0.8, 1.0) * e, 0.35)
			_giro = lerp(_giro, float(g.get("giro", 0.0)) * e * 1.4, 0.35)
			if _t_acao + delta >= dur and congelar < 0.0:
				impacto(0.07 if _acao != "forte" else 0.12)
				get_tree().call_group("lobos", "golpe_da_heroina", global_position, -global_transform.basis.z, 1.6 if _acao == "forte" else 1.0)
		2:   # seguir: o embalo leva a lâmina além do corte e ela para devagar (peso)
			var b: Vector3 = g.b; var c: Vector3 = g.c
			var e := 1.0 - pow(1.0 - u, 3.0)
			_hp = b + (b - c).normalized() * 0.12 * e + Vector3(0, -0.06, 0) * e
			_hd = g.db.normalized().rotated(ng, 0.25 * e); _hn = ng
			_tranco = _tranco.lerp(g.tranco, 0.2)
		3:   # volta: desce para baixo da tela e SOBE em pé até a guarda (como no vídeo de referência)
			var baixo: Vector3 = base[0] + Vector3(0.02, -0.42, 0.06)
			if u < 0.45:
				var e := smoothstep(0.0, 0.45, u)
				_hp = _sp.lerp(baixo, e); _hd = _sd.slerp(Vector3(0.1, 1.0, -0.25).normalized(), e); _hn = _sn.slerp(base[2].normalized(), e).normalized()
			else:
				var k := clampf((u - 0.45) / 0.55, 0.0, 1.0)
				var e := 1.0 + 2.2 * pow(k - 1.0, 3.0) + 1.2 * pow(k - 1.0, 2.0)   # sobe rápido e assenta (passa um tiquinho e volta)
				_hp = baixo.lerp(base[0], e); _hd = Vector3(0.1, 1.0, -0.25).normalized().slerp(base[1].normalized(), e); _hn = base[2].normalized()
	if congelar >= 0.0: return
	if _t_acao >= dur and not esperando:
		# combo: o próximo golpe já sai do fim deste (sem voltar para a guarda)
		if _proximo and _fase >= 2:
			_proximo = false; _acao = ""; _golpe_leve(); return
		_fase += 1; _t_acao = 0.0; _sp = _hp; _sd = _hd; _sn = _hn
		if _fase >= 4: _acao = ""; _proximo = false

func _tocar_bash(delta: float, base_e: Transform3D) -> void:
	var k: Array = BASH[_passo_acao]; var dur: float = k[0]
	_t_acao += delta
	var u: float = clampf(_t_acao / dur, 0.0, 1.0)
	var e: float = u * u * (3.0 - 2.0 * u)
	var alvo: Transform3D = base_e if k[1] == "" else _pose(k[1])
	piv_e.transform = _ini_e.interpolate_with(alvo, e)
	if _passo_acao == 1 and u > 0.25: _tranco = _tranco.lerp(k[2], 0.5)
	if _t_acao >= dur:
		_passo_acao += 1; _t_acao = 0.0; _ini_e = piv_e.transform
		if _passo_acao >= BASH.size(): _acao = ""

# ---------- movimento e animação ----------
func _physics_process(delta: float) -> void:
	_tempo += delta
	if morta: _cair_morta(delta); return
	var dir := Vector2.ZERO; var correr := false; var bloquear := false; var atacar := false
	if controles:
		dir = controles.dir
		var olhar_d: Vector2 = controles.consumir_olhar() * SENS_TOQUE
		if controles.consumir_alvo(): _trocar_alvo()
		if alvo == null: _girar(olhar_d)
		if controles.consumir_pulo(): _pulo_pedido = 0.2     # guarda o pedido um pouquinho
		correr = controles.correndo(); bloquear = controles.bloqueando(); atacar = controles.atacando()
	_seguir_alvo(delta)
	if montado:
		if atacar: desmontar(); controles._seg["atacar"] = false; controles.ataque_mouse = false   # atacar desmonta (como no WoW)
		atacar = false; bloquear = false
	pescoco.position.y = move_toward(pescoco.position.y, ALTURA_MONTADA if montado else ALTURA_OLHOS, delta * 3.0)
	if bloquear and not bloqueando: bloqueios_desde_erguer = 0        # levantou o escudo agora
	bloqueando = bloquear
	correr = correr and dir.y < -0.3 and not bloquear
	var vel := VEL_CORRER if correr else (VEL * 0.55 if bloquear else VEL)
	if GOLPES.has(_acao): vel *= 0.45                # atacando: o corpo pesa, anda devagar
	if montado: vel *= VEL_MONTARIA
	correr = correr and not GOLPES.has(_acao)
	# pulo: funciona parado, andando ou correndo. Tolerâncias: o toque vale por 0,2 s e dá para pular até
	# 0,15 s depois de sair do chão (descendo morro o corpo "descola" um instante do chão irregular)
	_coyote = 0.15 if is_on_floor() else _coyote - delta
	_pulo_pedido -= delta
	if _pulo_pedido > 0.0 and _coyote > 0.0 and velocity.y <= 0.5:
		velocity.y = PULO; _pulo_pedido = 0.0; _coyote = 0.0
	# aceleração e freada suaves (antes a velocidade mudava de uma vez): a pé responde rápido; a cavalo tem "peso"
	var mov := transform.basis * Vector3(dir.x, 0, dir.y); mov.y = 0
	var alvo_v := Vector2(mov.x, mov.z) * vel
	var atual := Vector2(velocity.x, velocity.z)
	var k := (4.0 if alvo_v.length() > atual.length() else 6.0) if montado else (14.0 if alvo_v.length() > atual.length() else 18.0)
	if not is_on_floor(): k *= 0.35                      # no ar quase não muda a direção
	atual = atual.lerp(alvo_v, 1.0 - exp(-k * delta))
	velocity.x = atual.x; velocity.z = atual.y
	if not is_on_floor(): velocity.y -= GRAV * delta
	var vy := velocity.y
	move_and_slide()
	if is_on_floor() and not _no_chao and vy < -3.0: _queda = clamp(-vy * 0.012, 0.0, 0.12)   # afunda ao cair
	_no_chao = is_on_floor()
	_ataque(atacar, bloquear, delta)
	if _anim_cavalo: _anim_cavalo.vel = Vector2(velocity.x, velocity.z).length() if is_on_floor() else 0.0

	# base (sem ação): repouso, correndo ou bloqueando
	var base_d: Array = MAO["bloq" if bloquear else ("correr" if correr else "repouso")]
	var base_e := _pose("e_bloq" if bloquear else ("e_correr" if correr else "e_repouso"))
	var anda: float = Vector2(velocity.x, velocity.z).length() / VEL if is_on_floor() else 0.0
	var amp: float = (0.034 if correr else 0.016) * min(anda, 1.0)
	if montado:                            # montada: um balanço por passada do cavalo (calmo), mais suave
		var vh := Vector2(velocity.x, velocity.z).length()
		var passada := lerpf(lerpf(3.4, 4.6, smoothstep(3.0, 6.0, vh)), 5.8, smoothstep(8.5, 10.5, vh))   # igual ao cavalo
		_passo += delta * TAU * vh / passada if is_on_floor() else 0.0
		amp = 0.022 * minf(vh / 4.0, 1.0)
	else:
		_passo += delta * (12.0 if correr else 8.5) * min(anda, 1.0)
	# balanço do passo (figura de 8) + respiração
	var bob := Vector3(cos(_passo * 0.5) * amp, -abs(sin(_passo * 0.5)) * amp * 1.4 + sin(_tempo * 1.6) * 0.004, 0)
	_balanco = _balanco.lerp(Vector2.ZERO, 1.0 - exp(-9.0 * delta)); _balanco = _balanco.limit_length(0.12)
	var sway := Vector3(_balanco.x * 0.35, _balanco.y * 0.35, 0)
	var f := 1.0 - exp(-12.0 * delta)
	if pose_fixa: pass
	else:
		if GOLPES.has(_acao):
			_tocar_golpe(delta, base_d)
			piv_e.transform = piv_e.transform.interpolate_with(_pose("e_golpe"), f)
		else:
			_hp = _hp.lerp(base_d[0], f); _hd = _hd.slerp(base_d[1].normalized(), f); _hn = _hn.slerp(base_d[2].normalized(), f).normalized()
			if _acao == "bash": _tocar_bash(delta, base_e)
			else: piv_e.transform = piv_e.transform.interpolate_with(base_e, f)
		piv_d.transform = _mao_t(_hp, _hd, _hn)
	# idle (parado, sem golpe): respiração — os braços sobem e descem devagar, a espada balança de leve
	var parado_alvo := (1.0 - minf(anda, 1.0)) * (0.0 if GOLPES.has(_acao) or _acao == "bash" else 1.0)
	_parado = lerp(_parado, parado_alvo, 1.0 - exp(-3.0 * delta))
	var resp := sin(_tempo * 1.5)                         # ~4 s por respiração
	var idle_p := Vector3(sin(_tempo * 0.75) * 0.006, resp * 0.016, -resp * 0.006) * _parado
	var idle_r := Vector3(sin(_tempo * 1.5 + 0.7) * 0.022, sin(_tempo * 0.6) * 0.012, sin(_tempo * 0.75 + 1.3) * 0.03) * _parado
	mao.position = bob + sway + idle_p
	mao.rotation = Vector3(_balanco.y * 0.6, _balanco.x * 0.6, _balanco.x * 0.4) + idle_r
	# câmera: balanço da cabeça, queda, trancos dos golpes
	_queda = lerp(_queda, 0.0, 1.0 - exp(-7.0 * delta))
	_tranco = _tranco.lerp(Vector3.ZERO, 1.0 - exp(-10.0 * delta))
	_giro = lerp(_giro, 0.0, 1.0 - exp(-6.0 * delta))
	_tremor = max(0.0, _tremor - delta * 6.0)
	var tr := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _tremor * _tremor * 0.012
	cam.position = Vector3(0, -abs(sin(_passo * 0.5)) * amp * 0.9 - _queda, -_tranco.z) + tr
	cam.rotation = Vector3(deg_to_rad(_tranco.x), deg_to_rad(_giro), deg_to_rad(_tranco.y) + cos(_passo * 0.5) * amp * 0.25)
	_rastro_atualizar(delta)
	# braços: da mão até o ombro, fora da tela
	_ajustar_braco(braco_d, piv_d.position, Vector3(0.32, -0.62, 0.15))
	_ajustar_braco(braco_e, piv_e.transform * Vector3(0, -0.07, 0), Vector3(-0.34, -0.66, 0.15))

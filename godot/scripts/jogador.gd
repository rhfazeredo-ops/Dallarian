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

# poses da mão direita no espaço da câmera (x direita, y cima, -z frente):
# [posição do cabo, direção da lâmina, giro do fio em graus]
const PD := {
	"d_repouso": [Vector3(0.3, -0.36, -0.52), Vector3(-0.12, 0.8, -0.55), 0.0],
	"d_correr": [Vector3(0.34, -0.52, -0.42), Vector3(0.1, 0.25, -0.95), 20.0],
	"d_bloq": [Vector3(0.38, -0.52, -0.5), Vector3(0.2, 0.5, -0.85), 10.0],
	"leve1_prep": [Vector3(0.36, -0.14, -0.5), Vector3(0.3, 0.85, 0.42), 0.0],
	"leve1_fim": [Vector3(-0.12, -0.28, -0.56), Vector3(-0.95, -0.05, -0.3), 0.0],
	"leve2_prep": [Vector3(-0.1, -0.16, -0.5), Vector3(-0.45, 0.8, 0.4), 180.0],
	"leve2_fim": [Vector3(0.36, -0.3, -0.56), Vector3(0.95, -0.02, -0.3), 180.0],
	"leve3_prep": [Vector3(0.16, 0.0, -0.5), Vector3(0.05, 0.62, 0.78), 90.0],
	"leve3_fim": [Vector3(0.1, -0.24, -0.6), Vector3(0.2, -0.55, -0.8), 90.0],
	"forte_prep": [Vector3(0.42, -0.04, -0.42), Vector3(0.45, 0.7, 0.55), 0.0],
	"forte_fim": [Vector3(-0.18, -0.32, -0.6), Vector3(-0.9, -0.2, -0.35), 0.0],
}
# poses da mão esquerda (escudo): [posição, rotação em graus]
const PE := {
	"e_repouso": [Vector3(-0.5, -0.5, -0.6), Vector3(80, 10, -25)],
	"e_golpe": [Vector3(-0.6, -0.7, -0.55), Vector3(70, 15, -35)],
	"e_correr": [Vector3(-0.52, -0.64, -0.5), Vector3(70, 20, -40)],
	"e_bloq": [Vector3(-0.12, -0.2, -0.46), Vector3(88, 0, -5)],
	"bash_prep": [Vector3(-0.2, -0.24, -0.38), Vector3(88, 10, -10)],
	"bash_fim": [Vector3(-0.06, -0.14, -0.78), Vector3(92, -5, 0)],
}
# sequências: [duração, pose da direita (ou ""), pose da esquerda (ou ""), tranco da câmera [pitch, roll, avanço]]
const ACOES := {
	"leve1": [[0.12, "leve1_prep", "e_golpe", Vector3.ZERO], [0.13, "leve1_fim", "e_golpe", Vector3(-2.5, 3, 0.06)], [0.3, "", "", Vector3.ZERO]],
	"leve2": [[0.12, "leve2_prep", "e_golpe", Vector3.ZERO], [0.13, "leve2_fim", "e_golpe", Vector3(-2.5, -3, 0.06)], [0.3, "", "", Vector3.ZERO]],
	"leve3": [[0.14, "leve3_prep", "e_golpe", Vector3(1.5, 0, 0)], [0.13, "leve3_fim", "e_golpe", Vector3(-4, 0, 0.08)], [0.32, "", "", Vector3.ZERO]],
	"forte": [[0.32, "forte_prep", "e_golpe", Vector3(2, 2, -0.05)], [0.15, "forte_fim", "e_golpe", Vector3(-5, 5, 0.3)], [0.5, "", "", Vector3.ZERO]],
	"bash": [[0.08, "", "bash_prep", Vector3.ZERO], [0.1, "", "bash_fim", Vector3(-2, 0, 0.12)], [0.28, "", "", Vector3.ZERO]],
}

var _acao := ""; var _passo_acao := 0; var _t_acao := 0.0
var _ini_d: Transform3D; var _ini_e: Transform3D
var _combo := 0; var _proximo := false; var _ultimo_golpe := 0.0
var _segurando := 0.0; var _ataque_seg := false; var _forte_pronto := false
var _passo := 0.0; var _tempo := 0.0
var _balanco := Vector2.ZERO     # armas atrasam ao girar
var _tranco := Vector3.ZERO      # câmera: pitch, roll, avanço
var _queda := 0.0; var _no_chao := true
var congelar := -1.0             # teste: para a ação nesse ponto (0..1)
var pose_fixa := false           # teste: mãos paradas numa pose (mostrar_pose)

func _ready() -> void:
	var cs := CollisionShape3D.new(); var cap := CapsuleShape3D.new(); cap.radius = 0.35; cap.height = 1.75
	cs.shape = cap; cs.position = Vector3(0, 0.875, 0); add_child(cs)
	floor_snap_length = 0.4; floor_max_angle = deg_to_rad(48)
	pescoco = Node3D.new(); pescoco.position = Vector3(0, 1.62, 0); add_child(pescoco)
	cam = Camera3D.new(); cam.fov = 70; cam.near = 0.04; cam.far = 900
	pescoco.add_child(cam); cam.current = true
	mao = Node3D.new(); cam.add_child(mao)
	_armas()
	piv_d.transform = _pose("d_repouso"); piv_e.transform = _pose("e_repouso")

func _pose(n: String) -> Transform3D:
	if PE.has(n):
		var pe: Array = PE[n]
		return Transform3D(Basis.from_euler(pe[1] * (PI / 180.0)), pe[0])
	# espada: eixo Y = lâmina; X = guarda (girada em volta da lâmina pelo "giro do fio")
	var p: Array = PD[n]
	var y: Vector3 = p[1].normalized()
	var ref := Vector3(0, 0, -1) if abs(y.z) < 0.9 else Vector3(0, 1, 0)
	var x := ref.cross(y).normalized().rotated(y, deg_to_rad(p[2]))
	return Transform3D(Basis(x, y, x.cross(y)), p[0])

# ---------- armas e braços ----------
func _armas() -> void:
	var m: Node = get_tree().current_scene
	piv_d = Node3D.new(); mao.add_child(piv_d)
	# espada do Tripo (assets/modelos/espada.glb): 0,51 m no arquivo → 0,85 m; cabo na origem, lâmina em +Y
	var esp := Node3D.new(); piv_d.add_child(esp); esp.scale = Vector3(0.85, 0.85, 0.85)
	var mod: Node3D = m.modelo_ps1("res://assets/modelos/espada.glb")
	var k := 1.0 / 0.51
	mod.scale = Vector3(k, k, k); mod.rotation_degrees.y = 90
	mod.position = Vector3(-0.131, -0.075, 0) * k
	esp.add_child(mod)
	piv_d.add_child(_punho(m, false))
	# escudo redondo de madeira com borda de ferro (provisório, até o modelo do Tripo)
	piv_e = Node3D.new(); mao.add_child(piv_e)
	var esc := Node3D.new(); piv_e.add_child(esc); esc.scale = Vector3(0.75, 0.75, 0.75)
	var e := ArrayMesh.new()
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	m.cilindro(st, Vector3(0, 0, 0), 0.4, 0.4, 0.04, 10, true); st.set_material(m.mat("madeira")); st.commit(e)
	st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	m.cilindro(st, Vector3(0, -0.005, 0), 0.43, 0.43, 0.035, 10)
	m.cilindro(st, Vector3(0, 0.04, 0), 0.09, 0.05, 0.05, 6, true)
	st.set_material(m.mat("", 1.0, Color(0.38, 0.38, 0.42))); st.commit(e)
	var me := MeshInstance3D.new(); me.mesh = e; esc.add_child(me)
	var pe := _punho(m, true); pe.position = Vector3(0, -0.07, 0); piv_e.add_child(pe)
	braco_d = _antebraco(m); mao.add_child(braco_d)
	braco_e = _antebraco(m); mao.add_child(braco_e)

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
		if kv[0] == "d": piv_d.transform = _pose(kv[1])
		else: piv_e.transform = _pose(kv[1])

# ---------- entrada ----------
func _unhandled_input(e: InputEvent) -> void:
	if OS.has_feature("mobile") or DisplayServer.is_touchscreen_available(): return
	if e is InputEventMouseButton:
		if e.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED; return
		if e.button_index == MOUSE_BUTTON_LEFT and controles: controles.ataque_mouse = e.pressed
		if e.button_index == MOUSE_BUTTON_RIGHT and controles: controles.bloqueio_mouse = e.pressed
	elif e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_girar(e.relative * SENS_MOUSE)
	elif e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _girar(d: Vector2) -> void:
	rotation.y -= d.x
	pescoco.rotation.x = clamp(pescoco.rotation.x - d.y, deg_to_rad(-85), deg_to_rad(85))
	_balanco += Vector2(-d.x, d.y) * 0.6

# ---------- ações ----------
func iniciar(nome: String) -> void:
	_acao = nome; _passo_acao = 0; _t_acao = 0.0
	_ini_d = piv_d.transform; _ini_e = piv_e.transform

func _golpe_leve() -> void:
	if _acao == "" or _acao == "bash":
		if _tempo - _ultimo_golpe > 0.9: _combo = 0
		iniciar(["leve1", "leve2", "leve3"][_combo % 3]); _combo += 1; _ultimo_golpe = _tempo
	elif _acao.begins_with("leve") and _passo_acao >= 1:
		_proximo = true                       # encadeia o próximo golpe do combo

func _ataque(segurando: bool, bloqueando: bool, delta: float) -> void:
	if segurando and not _ataque_seg:          # apertou
		_segurando = 0.0; _forte_pronto = false
		if bloqueando:
			if _acao == "": iniciar("bash")
		elif _acao == "" or _acao.begins_with("leve"):
			pass
	if segurando:
		_segurando += delta
		if not bloqueando and _segurando > SEGURAR_FORTE and not _forte_pronto and _acao == "":
			_forte_pronto = true; iniciar("forte")      # puxa a espada para trás e espera soltar
	if not segurando and _ataque_seg:          # soltou
		if not _forte_pronto and not bloqueando: _golpe_leve()
	_ataque_seg = segurando

func _tocar_acao(delta: float, base_d: Transform3D, base_e: Transform3D) -> void:
	var seq: Array = ACOES[_acao]
	var k: Array = seq[_passo_acao]
	var dur: float = k[0]
	# golpe forte: fica na preparação enquanto o botão estiver apertado (até 1,2 s)
	var esperando := _acao == "forte" and _passo_acao == 0 and _t_acao >= dur and _ataque_seg and _segurando < 1.2
	if not esperando: _t_acao += delta
	var u: float = clamp(_t_acao / dur, 0.0, 1.0)
	if congelar >= 0.0:
		u = congelar; _t_acao = dur * u
	var e: float = u * u * (3.0 - 2.0 * u) if _passo_acao != 1 else 1.0 - pow(1.0 - u, 3.0)   # golpe: rápido no começo
	var alvo_d: Transform3D = base_d if k[1] == "" else _pose(k[1])
	var alvo_e: Transform3D = base_e if k[2] == "" else _pose(k[2])
	piv_d.transform = _ini_d.interpolate_with(alvo_d, e)
	piv_e.transform = _ini_e.interpolate_with(alvo_e, e)
	if _passo_acao == 1 and u > 0.25: _tranco = _tranco.lerp(k[3], 0.5)
	if congelar >= 0.0: return
	if _t_acao >= dur:
		_passo_acao += 1; _t_acao = 0.0
		_ini_d = piv_d.transform; _ini_e = piv_e.transform
		if _passo_acao >= seq.size() or (_proximo and _passo_acao == seq.size() - 1):
			var encadear := _proximo
			_acao = ""; _proximo = false
			if encadear: _golpe_leve()

# ---------- movimento e animação ----------
func _physics_process(delta: float) -> void:
	_tempo += delta
	var dir := Vector2.ZERO; var correr := false; var bloquear := false; var atacar := false
	if controles:
		dir = controles.dir
		_girar(controles.consumir_olhar() * SENS_TOQUE)
		if controles.consumir_pulo() and is_on_floor(): velocity.y = PULO
		correr = controles.correndo(); bloquear = controles.bloqueando(); atacar = controles.atacando()
	correr = correr and dir.y < -0.3 and not bloquear
	var vel := VEL_CORRER if correr else (VEL * 0.55 if bloquear else VEL)
	var mov := transform.basis * Vector3(dir.x, 0, dir.y); mov.y = 0
	velocity.x = mov.x * vel; velocity.z = mov.z * vel
	if not is_on_floor(): velocity.y -= GRAV * delta
	var vy := velocity.y
	move_and_slide()
	if is_on_floor() and not _no_chao and vy < -3.0: _queda = clamp(-vy * 0.012, 0.0, 0.12)   # afunda ao cair
	_no_chao = is_on_floor()
	_ataque(atacar, bloquear, delta)

	# base (sem ação): repouso, correndo ou bloqueando
	var base_d := _pose("d_bloq" if bloquear else ("d_correr" if correr else "d_repouso"))
	var base_e := _pose("e_bloq" if bloquear else ("e_correr" if correr else "e_repouso"))
	var anda: float = Vector2(velocity.x, velocity.z).length() / VEL if is_on_floor() else 0.0
	_passo += delta * (12.0 if correr else 8.5) * min(anda, 1.0)
	# balanço do passo (figura de 8) + respiração
	var amp: float = (0.034 if correr else 0.016) * min(anda, 1.0)
	var bob := Vector3(cos(_passo * 0.5) * amp, -abs(sin(_passo * 0.5)) * amp * 1.4 + sin(_tempo * 1.6) * 0.004, 0)
	_balanco = _balanco.lerp(Vector2.ZERO, 1.0 - exp(-9.0 * delta)); _balanco = _balanco.limit_length(0.12)
	var sway := Vector3(_balanco.x * 0.35, _balanco.y * 0.35, 0)
	if pose_fixa: pass
	elif _acao != "":
		_tocar_acao(delta, base_d, base_e)
	else:
		var f := 1.0 - exp(-12.0 * delta)
		piv_d.transform = piv_d.transform.interpolate_with(base_d, f)
		piv_e.transform = piv_e.transform.interpolate_with(base_e, f)
	mao.position = bob + sway
	mao.rotation = Vector3(_balanco.y * 0.6, _balanco.x * 0.6, _balanco.x * 0.4)
	# câmera: balanço da cabeça, queda, trancos dos golpes
	_queda = lerp(_queda, 0.0, 1.0 - exp(-7.0 * delta))
	_tranco = _tranco.lerp(Vector3.ZERO, 1.0 - exp(-10.0 * delta))
	cam.position = Vector3(0, -abs(sin(_passo * 0.5)) * amp * 0.9 - _queda, -_tranco.z)
	cam.rotation = Vector3(deg_to_rad(_tranco.x), 0, deg_to_rad(_tranco.y) + cos(_passo * 0.5) * amp * 0.25)
	# braços: da mão até o ombro, fora da tela
	_ajustar_braco(braco_d, piv_d.position, Vector3(0.32, -0.62, 0.15))
	_ajustar_braco(braco_e, piv_e.transform * Vector3(0, -0.07, 0), Vector3(-0.34, -0.66, 0.15))

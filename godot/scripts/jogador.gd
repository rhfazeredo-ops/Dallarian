# Dallarian em primeira pessoa: anda, olha, pula; espada do Tripo e escudo provisório na mão (low poly PS1).
extends CharacterBody3D
class_name Jogador

const VEL := 4.6
const PULO := 4.8
const GRAV := 13.0
const SENS_MOUSE := 0.0025
const SENS_TOQUE := 0.006

var controles: Controles
var cam: Camera3D
var mao: Node3D
var espada: Node3D
var escudo: Node3D
var _passo := 0.0
var _golpe := 0.0

func _ready() -> void:
	var cs := CollisionShape3D.new(); var cap := CapsuleShape3D.new(); cap.radius = 0.35; cap.height = 1.75
	cs.shape = cap; cs.position = Vector3(0, 0.875, 0); add_child(cs)
	floor_snap_length = 0.4; floor_max_angle = deg_to_rad(48)
	cam = Camera3D.new(); cam.position = Vector3(0, 1.62, 0); cam.fov = 70; cam.near = 0.05; cam.far = 400
	add_child(cam); cam.current = true
	mao = Node3D.new(); cam.add_child(mao)
	_armas()

func _armas() -> void:
	var m: Node = get_tree().current_scene
	# espada: lâmina, guarda, cabo e pomo
	espada = Node3D.new(); mao.add_child(espada)
	espada.position = Vector3(0.38, -0.42, -0.62); espada.rotation_degrees = Vector3(-40, -8, -14); espada.scale = Vector3(0.8, 0.8, 0.8)
	# modelo do Tripo (assets/modelos/espada.glb, 498 triângulos): 0,51 m no arquivo → 1,0 m na mão.
	# O cabo fica na origem do nó "espada" e a lâmina sobe em +Y; a guarda do modelo está no eixo Z → gira 90°.
	var mod: Node3D = m.modelo_ps1("res://assets/modelos/espada.glb")
	var k := 1.0 / 0.51
	mod.scale = Vector3(k, k, k); mod.rotation_degrees.y = 90
	mod.position = Vector3(-0.131, -0.075, 0) * k
	espada.add_child(mod)
	# escudo redondo de madeira com borda de ferro
	escudo = Node3D.new(); mao.add_child(escudo)
	escudo.position = Vector3(-0.62, -0.56, -0.62); escudo.rotation_degrees = Vector3(80, 10, -25); escudo.scale = Vector3(0.75, 0.75, 0.75)
	var e := ArrayMesh.new()
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	m.cilindro(st, Vector3(0, 0, 0), 0.4, 0.4, 0.04, 10, true); st.set_material(m.mat("madeira")); st.commit(e)
	st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	m.cilindro(st, Vector3(0, -0.005, 0), 0.43, 0.43, 0.035, 10)
	m.cilindro(st, Vector3(0, 0.04, 0), 0.09, 0.05, 0.05, 6, true)
	st.set_material(m.mat("", 1.0, Color(0.38, 0.38, 0.42))); st.commit(e)
	var me := MeshInstance3D.new(); me.mesh = e; escudo.add_child(me)
	for n in [me]: n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _unhandled_input(e: InputEvent) -> void:
	if OS.has_feature("mobile") or DisplayServer.is_touchscreen_available(): return
	if e is InputEventMouseButton and e.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif e.button_index == MOUSE_BUTTON_LEFT: atacar()
	elif e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_girar(e.relative * SENS_MOUSE)
	elif e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _girar(d: Vector2) -> void:
	rotation.y -= d.x
	cam.rotation.x = clamp(cam.rotation.x - d.y, deg_to_rad(-85), deg_to_rad(85))

func atacar() -> void:
	if _golpe <= 0.0: _golpe = 1.0

func _physics_process(delta: float) -> void:
	var dir := Vector2.ZERO
	if controles:
		dir = controles.dir
		_girar(controles.consumir_olhar() * SENS_TOQUE)
		if controles.consumir_pulo() and is_on_floor(): velocity.y = PULO
		if controles.consumir_ataque(): atacar()
	var mov := (transform.basis * Vector3(dir.x, 0, dir.y))
	mov.y = 0
	velocity.x = mov.x * VEL; velocity.z = mov.z * VEL
	if not is_on_floor(): velocity.y -= GRAV * delta
	move_and_slide()
	# balanço da mão ao andar e golpe da espada
	var anda: float = Vector2(velocity.x, velocity.z).length() / VEL if is_on_floor() else 0.0
	_passo += delta * 9.0 * anda
	mao.position = Vector3(cos(_passo * 0.5) * 0.02, -abs(sin(_passo * 0.5)) * 0.03, 0) * anda
	if _golpe > 0.0:
		_golpe = max(0.0, _golpe - delta * 3.2)
		var t := 1.0 - _golpe
		var arco := sin(t * PI)
		espada.rotation_degrees = Vector3(-40 + arco * 65, -8 + arco * 55, -14 - arco * 50)
		espada.position = Vector3(0.38 - arco * 0.3, -0.42 + arco * 0.05, -0.62 - arco * 0.1)

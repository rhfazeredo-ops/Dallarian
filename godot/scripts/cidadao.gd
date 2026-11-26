# Cidadão: personagem do pacote Fantasy Kingdom (Synty) andando pela cidade ou pela vila com as animações da Synty
# (Base Locomotion) — o esqueleto dos personagens do pacote é o mesmo das animações, então elas entram direto.
# Passeia entre pontos sorteados perto do "centro", para de vez em quando, desvia das casas. Longe da Rachel fica
# parado e escondido (leve no celular).
extends Node3D
class_name Cidadao

const ARQ := "res://arte/fk/personagens/FantasyKingdom_Characters.fbx"
const MULHERES := ["SM_Chr_Rider_01", "SM_Chr_Queen_01", "SM_Chr_Princess_01", "SM_Chr_Blacksmith_Female_01", "SM_Chr_Nun_01",
	"SM_Chr_Soldier_Female_01", "SM_Chr_Peasant_Female_01", "SM_Chr_FortuneTeller_01", "SM_Chr_Fairy_01"]
const ANIMS := {"parado": ["A_Idle_Standing", true], "andar": ["A_Walk_F", true]}
static var _cena: PackedScene
static var _libs := {}             # "Masc"/"Femn" → AnimationLibrary

var m
var tipo := "SM_Chr_Peasant_Male_01"
var centro := Vector2.ZERO
var raio := 30.0
var fixo := false                  # fica parado no lugar (guardas, vendedores)
var olhar := Vector2.ZERO
var _ap: AnimationPlayer
var _alvo := Vector2.ZERO
var _espera := 0.0
var _vel := 1.25
var _rng := RandomNumberGenerator.new()

static func existe() -> bool: return ResourceLoader.exists(ARQ)

# animações da Synty convertidas para os ossos dos personagens (ferramentas/retarget.gd -- --cidadao)
static func _lib(gen: String) -> AnimationLibrary:
	if _libs.has(gen): return _libs[gen]
	var arq := "res://arte/animacoes/cidadao_%s.res" % gen
	_libs[gen] = load(arq) if ResourceLoader.exists(arq) else AnimationLibrary.new()
	return _libs[gen]

func montar(mundo, semente: int) -> void:
	m = mundo; _rng.seed = semente
	if _cena == null: _cena = load(ARQ)
	var n: Node3D = _cena.instantiate(); add_child(n)
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = c
		if mi.name != tipo: mi.queue_free()
		else:
			mi.material_override = Synty.material(m.NEBLINA, "personagem")
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ap = AnimationPlayer.new(); n.add_child(_ap); _ap.root_node = NodePath("..")
	_ap.add_animation_library("", _lib("Femn" if tipo in MULHERES else "Masc"))
	_ap.play("parado"); _ap.seek(_rng.randf() * 1.5, true)
	_vel = _rng.randf_range(1.0, 1.45)
	_alvo = Vector2(position.x, position.z); _espera = _rng.randf_range(0.0, 4.0)
	if olhar != Vector2.ZERO: rotation.y = atan2(olhar.x - position.x, olhar.y - position.z)

func _physics_process(delta: float) -> void:
	if m == null or m.get("jogador") == null: return
	var dj: float = global_position.distance_to(m.jogador.global_position)
	visible = dj < 110.0
	_ap.active = dj < 70.0                                   # longe não anima
	if fixo or dj > 90.0: return
	var p := Vector2(position.x, position.z)
	if _espera > 0.0:
		_espera -= delta
		if _espera <= 0.0: _novo_alvo()
		return
	var d := _alvo - p
	if d.length() < 0.6:
		_espera = _rng.randf_range(2.0, 8.0); _ap.play("parado", 0.3); return
	var passo := d.normalized() * _vel * delta
	var q := p + passo
	if m.perto_de_casa(q.x, q.y, 0.6): _espera = 0.5; _alvo = p; return
	position = Vector3(q.x, m.reg.altura(q.x, q.y), q.y)
	rotation.y = lerp_angle(rotation.y, atan2(d.x, d.y), 1.0 - exp(-8.0 * delta))

func _novo_alvo() -> void:
	for t in 12:
		var a := _rng.randf() * TAU; var r := _rng.randf_range(4.0, raio)
		var q := centro + Vector2(cos(a), sin(a)) * r
		if not m.perto_de_casa(q.x, q.y, 1.5) and m.reg.agua(q.x, q.y) == 0.0:
			_alvo = q; _ap.play("andar", 0.3); _ap.speed_scale = _vel / 1.4; return
	_espera = 2.0

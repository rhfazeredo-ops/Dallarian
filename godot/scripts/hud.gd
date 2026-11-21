# HUD da personagem no canto superior direito (inspirado nos quadros de unidade dos MMOs, desenho nosso):
# retrato redondo da Rachel numa moldura dourada com um cantinho em degrau, e ao lado uma plaqueta com o
# nome, o nível e as barras de vida (verde) e mana (azul). O retrato é tirado do próprio modelo 3D dela.
# As molduras podem ser trocadas depois por arte (PNG) feita no ChatGPT.
extends Control
class_name Hud

var nome := "Rachel"
var nivel := 1
var vida := 100.0; var vida_max := 100.0
var mana := 100.0; var mana_max := 100.0
var _vida_vis := 1.0; var _mana_vis := 1.0
var retrato: Texture2D
var fonte: Font
const R := 54.0                      # raio do retrato
const OURO := Color(0.86, 0.68, 0.32)
const OURO_CLARO := Color(1.0, 0.86, 0.5)

func montar() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter = Control.MOUSE_FILTER_IGNORE
	fonte = ThemeDB.fallback_font
	_tirar_retrato()

# renderiza o rosto da Rachel uma vez numa tela escondida e guarda como imagem
func _tirar_retrato() -> void:
	var vp := SubViewport.new(); vp.size = Vector2i(256, 256); vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS; vp.own_world_3d = true; add_child(vp)
	var mod: Node3D = load("res://assets/modelos/dallarian.glb").instantiate(); vp.add_child(mod)
	mod.rotation_degrees.y = -90                      # o modelo olha para +X; assim olha para +Z (para a câmera)
	var luz := DirectionalLight3D.new(); luz.rotation_degrees = Vector3(-25, 35, 0); luz.light_energy = 1.1; vp.add_child(luz)
	var amb := WorldEnvironment.new(); var env := Environment.new(); env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.75, 0.72, 0.8); env.ambient_light_energy = 0.8
	amb.environment = env; vp.add_child(amb)
	var cam := Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = 0.2
	cam.position = Vector3(0.0, 0.385, 1.0); vp.add_child(cam); cam.current = true      # o modelo vai de y -0,49 a 0,49
	for n in mod.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n
		var orig: BaseMaterial3D = mi.mesh.surface_get_material(0)
		if orig:
			var mt := orig.duplicate() as BaseMaterial3D; mt.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			mi.material_override = mt
	for k in 4: await RenderingServer.frame_post_draw
	retrato = ImageTexture.create_from_image(vp.get_texture().get_image())
	vp.queue_free(); queue_redraw()

func _process(delta: float) -> void:
	_vida_vis = move_toward(_vida_vis, vida / vida_max, delta * 0.8)
	_mana_vis = move_toward(_mana_vis, mana / mana_max, delta * 0.8)
	queue_redraw()

func _draw() -> void:
	var tela := get_viewport_rect().size
	var c := Vector2(tela.x - 420.0, 30.0 + R)            # centro do retrato
	# plaqueta (fundo escuro com borda dourada fina): nome, nível e as duas barras
	var px := c.x + R * 0.55; var py := c.y - R * 0.62; var pw := 330.0
	draw_rect(Rect2(px, py, pw, 30), Color(0.08, 0.07, 0.08, 0.72))
	draw_string_outline(fonte, Vector2(px + R * 0.55 + 6, py + 23), nome, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 5, Color(0, 0, 0, 0.8))
	draw_string(fonte, Vector2(px + R * 0.55 + 6, py + 23), nome, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, OURO_CLARO)
	var nv := str(nivel); var wn := fonte.get_string_size(nv, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	draw_string_outline(fonte, Vector2(px + pw - wn - 10, py + 23), nv, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 5, Color(0, 0, 0, 0.8))
	draw_string(fonte, Vector2(px + pw - wn - 10, py + 23), nv, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, OURO_CLARO)
	_barra(Rect2(px + R * 0.45, py + 34, pw - R * 0.45, 26), _vida_vis, Color(0.42, 0.78, 0.22), Color(0.62, 0.92, 0.36), "%d / %d" % [vida, vida_max])
	_barra(Rect2(px + R * 0.45, py + 64, pw - R * 0.45, 16), _mana_vis, Color(0.16, 0.36, 0.82), Color(0.36, 0.58, 1.0), "")
	# retrato: círculo com o rosto, moldura dourada dupla e cantinho em degrau embaixo à direita
	var pts := PackedVector2Array(); var uvs := PackedVector2Array()
	for i in 48:
		var a := TAU * i / 48.0; var q := Vector2(cos(a), sin(a))
		pts.append(c + q * R); uvs.append(Vector2(0.5, 0.5) + q * 0.5)
	draw_colored_polygon(pts, Color(0.12, 0.16, 0.3), uvs)
	if retrato: draw_colored_polygon(pts, Color.WHITE, uvs, retrato)
	# canto em degrau (a moldura vira um "pingo" no canto inferior direito)
	var canto := PackedVector2Array([c + Vector2(R * 0.0, R), c + Vector2(R, R), c + Vector2(R, 0)])
	draw_colored_polygon(PackedVector2Array([c, canto[0], canto[1], canto[2]]), Color(0, 0, 0, 0))
	draw_arc(c, R + 2, PI * 0.5, PI * 2.0, 64, Color(0.1, 0.08, 0.05, 0.9), 9.0, true)
	draw_arc(c, R + 2, PI * 0.5, PI * 2.0, 64, OURO, 5.0, true)
	draw_polyline(PackedVector2Array([c + Vector2(R + 2, 0), c + Vector2(R + 2, R + 2), c + Vector2(0, R + 2)]), Color(0.1, 0.08, 0.05, 0.9), 9.0, true)
	draw_polyline(PackedVector2Array([c + Vector2(R + 2, 0), c + Vector2(R + 2, R + 2), c + Vector2(0, R + 2)]), OURO, 5.0, true)
	draw_polyline(PackedVector2Array([c + Vector2(R - 10, R - 2), c + Vector2(R - 2, R - 2), c + Vector2(R - 2, R - 10)]), OURO_CLARO, 2.5)
	draw_polyline(PackedVector2Array([c + Vector2(R - 18, R - 2), c + Vector2(R - 18, R - 10), c + Vector2(R - 10, R - 10), c + Vector2(R - 10, R - 18), c + Vector2(R - 2, R - 18)]), OURO_CLARO, 2.0)
	draw_arc(c, R - 3, 0, TAU, 64, Color(1, 0.9, 0.6, 0.35), 1.5, true)

func _barra(r: Rect2, frac: float, cor: Color, brilho: Color, texto: String) -> void:
	draw_rect(r.grow(2), Color(0.1, 0.08, 0.05, 0.9))
	draw_rect(r, Color(0.06, 0.06, 0.07, 0.85))
	var f := Rect2(r.position, Vector2(r.size.x * clampf(frac, 0, 1), r.size.y))
	draw_rect(f, cor)
	draw_rect(Rect2(f.position, Vector2(f.size.x, f.size.y * 0.35)), brilho)          # faixa de brilho em cima
	draw_rect(r.grow(1), OURO.darkened(0.25), false, 1.5)
	if texto != "":
		var w := fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		var pos := Vector2(r.position.x + (r.size.x - w) * 0.5, r.position.y + r.size.y * 0.5 + 6)
		draw_string_outline(fonte, pos, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 4, Color(0, 0, 0, 0.85))
		draw_string(fonte, pos, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 1, 1))

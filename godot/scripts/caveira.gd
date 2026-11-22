# caveirinha desenhada à mão em qualquer CanvasItem (marca de onde a Rachel morreu no mapa e na bússola)
class_name Caveira

static func desenhar(ci: CanvasItem, c: Vector2, r: float, cor: Color) -> void:
	var k := r / 10.0
	var esc := Color(0.08, 0.06, 0.06, 0.9)
	ci.draw_circle(c + Vector2(1.5, 1.5) * k, r + 1.5 * k, Color(0, 0, 0, 0.75))           # sombra/contorno
	ci.draw_circle(c + Vector2(0, -1.5) * k, r, cor)                                       # crânio
	ci.draw_rect(Rect2(c + Vector2(-5.5, 4.5) * k, Vector2(11, 6) * k), cor)               # queixo
	ci.draw_circle(c + Vector2(-3.8, -1.5) * k, 2.9 * k, esc)                              # olhos
	ci.draw_circle(c + Vector2(3.8, -1.5) * k, 2.9 * k, esc)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, 1.5) * k, c + Vector2(-1.6, 4.4) * k, c + Vector2(1.6, 4.4) * k]), esc)
	for i in 3: ci.draw_line(c + Vector2(-3.0 + i * 3.0, 6.5) * k, c + Vector2(-3.0 + i * 3.0, 10.0) * k, esc, maxf(1.0, k))   # dentes

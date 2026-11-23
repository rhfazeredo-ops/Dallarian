# Mede o rio do leste: nível da água x altura das margens ao longo do rio (para achar trecho "fosso").
extends SceneTree
func _initialize() -> void:
	var r := Regiao.new()
	for i in 41:
		var t := i / 40.0
		# ponto no rio pelo comprimento
		var tot := 0.0; var seg := []
		for k in r.rio2.size() - 1: seg.append(r.rio2[k].distance_to(r.rio2[k + 1])); tot += seg[k]
		var alvo := t * tot; var k := 0
		while k < seg.size() - 1 and alvo > seg[k]: alvo -= seg[k]; k += 1
		var a: Vector2 = r.rio2[k]; var b: Vector2 = r.rio2[k + 1]
		var p := a.lerp(b, clampf(alvo / seg[k], 0, 1)); var n := (b - a).normalized().orthogonal()
		var l := r.largura_rio2(t) * 0.5
		var agua := r.agua(p.x, p.y); var fundo := r.altura(p.x, p.y)
		var m1 := r.altura(p.x + n.x * (l + 3), p.y + n.y * (l + 3)); var m2 := r.altura(p.x - n.x * (l + 3), p.y - n.y * (l + 3))
		var m3 := r.altura(p.x + n.x * (l + 20), p.y + n.y * (l + 20))
		print("t=%.3f p=(%d,%d) agua=%.1f fundo=%.1f margem=%.1f/%.1f longe=%.1f dist_cid=%d" % [t, p.x, p.y, agua, fundo, m1, m2, m3, p.distance_to(Regiao.CIDADE_C)])
	quit()

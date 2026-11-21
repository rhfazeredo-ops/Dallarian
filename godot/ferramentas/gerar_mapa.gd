# Gera a imagem do mapa da região (assets/ui/mapa_base.png) a partir do mesmo terreno do jogo: cores do chão,
# relevo sombreado, água (rio, lago, mar, pântano), matas e estradas. Sem marcar lugares.
# Rodar: godot --headless --path . --script res://ferramentas/gerar_mapa.gd   (depois o tools/mapa_pergaminho.py)
extends SceneTree

const TAM := 768

func _init() -> void:
	var reg := Regiao.new()
	var im := Image.create(TAM, TAM, false, Image.FORMAT_RGB8)
	var m := Regiao.LIM / float(TAM) * 2.0
	var hs := PackedFloat32Array(); hs.resize(TAM * TAM)
	for j in TAM:
		for i in TAM:
			hs[j * TAM + i] = reg.altura(-Regiao.LIM + (i + 0.5) * m, -Regiao.LIM + (j + 0.5) * m)
	for j in TAM:
		for i in TAM:
			var x := -Regiao.LIM + (i + 0.5) * m; var z := -Regiao.LIM + (j + 0.5) * m
			var h := hs[j * TAM + i]
			var hx := hs[j * TAM + mini(i + 1, TAM - 1)] - hs[j * TAM + maxi(i - 1, 0)]
			var hz := hs[mini(j + 1, TAM - 1) * TAM + i] - hs[maxi(j - 1, 0) * TAM + i]
			var ny := Vector3(-hx, 2.0 * m, -hz).normalized().y
			var c := reg.cor(x, z, h, ny)
			# matas: copas em manchas (mais escuras em cima, com um brilho do lado da luz)
			var f := reg.floresta(x, z)
			if f > 0.45 and reg.agua(x, z) == 0.0 and h > 0.5:
				var n := reg.ruido.get_noise_2d(x * 2.4, z * 2.4)
				var k := smoothstep(0.45, 0.7, f)
				var copa := Color(0.2, 0.36, 0.17).lerp(Color(0.32, 0.48, 0.22), clampf(n * 1.5 + 0.5, 0.0, 1.0))
				c = c.lerp(copa, k)
			# relevo: luz vinda do noroeste
			var luz := clampf(1.0 + (-hx - hz) * 0.06, 0.7, 1.25)
			c = c * luz
			# água
			var nv := reg.agua(x, z)
			if nv != 0.0 and h < nv + 0.4: c = Color(0.27, 0.48, 0.66).lerp(Color(0.38, 0.6, 0.76), clampf((h - nv + 3.0) / 3.0, 0.0, 1.0))
			elif h < 0.05:
				if reg.zona_pantano(z) > 0.5 and x < 380.0: c = Color(0.28, 0.34, 0.26)
				else: c = Color(0.22, 0.42, 0.62).lerp(Color(0.36, 0.6, 0.74), clampf((h + 4.0) / 4.0, 0.0, 1.0))
			im.set_pixel(i, j, c)
	im.save_png("res://assets/ui/mapa_base.png")
	print("MAPA ok")
	quit()

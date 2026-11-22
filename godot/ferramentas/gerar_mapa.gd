# Gera a imagem do mapa da região (assets/ui/mapa_base.png) a partir do mesmo terreno do jogo: cores do chão,
# relevo sombreado, água (rio, lago, mar, pântano), matas e estradas. Sem marcar lugares.
# Rodar: godot --headless --path . --script res://ferramentas/gerar_mapa.gd   (depois o tools/mapa_pergaminho.py)
extends SceneTree

const TAM := 1520          # largura em pixels (a altura segue a proporção do mundo)

func _init() -> void:
	var reg := Regiao.new()
	var m := (Regiao.X1 - Regiao.X0) / float(TAM)
	var AL := int((Regiao.Z1 - Regiao.Z0) / m)
	var im := Image.create(TAM, AL, false, Image.FORMAT_RGB8)
	var hs := PackedFloat32Array(); hs.resize(TAM * AL)
	for j in AL:
		for i in TAM:
			hs[j * TAM + i] = reg.altura(Regiao.X0 + (i + 0.5) * m, Regiao.Z0 + (j + 0.5) * m)
	for j in AL:
		for i in TAM:
			var x := Regiao.X0 + (i + 0.5) * m; var z := Regiao.Z0 + (j + 0.5) * m
			var h := hs[j * TAM + i]
			var hx := hs[j * TAM + mini(i + 1, TAM - 1)] - hs[j * TAM + maxi(i - 1, 0)]
			var hz := hs[mini(j + 1, AL - 1) * TAM + i] - hs[maxi(j - 1, 0) * TAM + i]
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
				if reg.zona_pantano(z) > 0.5 and x < Regiao.COSTA - 150.0: c = Color(0.28, 0.34, 0.26)
				else: c = Color(0.22, 0.42, 0.62).lerp(Color(0.36, 0.6, 0.74), clampf((h + 4.0) / 4.0, 0.0, 1.0))
			# cidade: muralha redonda, canal em anel e casas em anéis (desenho simples)
			var dc := Vector2(x, z).distance_to(Regiao.CIDADE_C)
			if absf(dc - Regiao.CIDADE_R) < 4.0: c = Color(0.85, 0.83, 0.78)
			elif absf(dc - Regiao.CANAL) < 5.0: c = Color(0.3, 0.5, 0.7)
			elif dc < Regiao.CIDADE_R and dc > 12.0:
				for ra in [40.0, 58.0, 76.0, 116.0, 134.0, 158.0, 176.0, 200.0, 216.0]:
					if absf(dc - ra) < 4.0 and absf(Vector2(x, z).y - Regiao.CIDADE_C.y) > 8.0 and absf(Vector2(x, z).x - Regiao.CIDADE_C.x) > 8.0: c = Color(0.3, 0.38, 0.65)
			im.set_pixel(i, j, c)
	im.save_png("res://assets/ui/mapa_base.png")
	print("MAPA ok")
	quit()

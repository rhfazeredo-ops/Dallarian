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
			# cidade: muralha redonda, canal em anel e as cores dos bairros
			var dc := Vector2(x, z).distance_to(Regiao.CIDADE_C)
			var bairro := Regiao.distrito(x, z)
			var cores_b := {"praca": Color(0.75, 0.72, 0.66), "comercio": Color(0.4, 0.5, 0.78), "portao": Color(0.42, 0.52, 0.8),
				"velho": Color(0.7, 0.42, 0.3), "magos": Color(0.6, 0.42, 0.72), "porto": Color(0.5, 0.55, 0.62),
				"catedral": Color(0.82, 0.8, 0.74), "castelo": Color(0.65, 0.65, 0.7)}
			if cores_b.has(bairro) and Regiao.rua_cidade(x, z) > 8.0: c = cores_b[bairro] * (0.9 + 0.1 * float((int(dc / 8.0)) % 2))
			elif bairro != "" and bairro != "parque": c = Color(0.78, 0.75, 0.7)
			if absf(dc - Regiao.CIDADE_R) < 4.0: c = Color(0.88, 0.86, 0.8)
			elif absf(dc - Regiao.CANAL) < 5.0 or Vector2(x, z).distance_to(Regiao.LAGO_PARQUE) < 15.0: c = Color(0.3, 0.5, 0.7)
			elif absf(x - Regiao.FOSSO_X) < 8.0 and absf(z - Regiao.CIDADE_C.y) < 132.0: c = Color(0.3, 0.5, 0.7) if absf(z - Regiao.CIDADE_C.y) > 8.0 else Color(0.8, 0.78, 0.72)
			im.set_pixel(i, j, c)
	im.save_png("res://assets/ui/mapa_base.png")
	print("MAPA ok")
	quit()

# Imagem do relevo do mapa inteiro (sombreado + cor por altura): --saida=arq.png
extends SceneTree
func _initialize() -> void:
	var saida := "user://relevo.png"
	for a in OS.get_cmdline_user_args(): if a.begins_with("--saida="): saida = a.trim_prefix("--saida=")
	var r := Regiao.new(); var p := 4.0
	var w := int((Regiao.X1 - Regiao.X0) / p); var h := int((Regiao.Z1 - Regiao.Z0) / p)
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	for j in h:
		for i in w:
			var x := Regiao.X0 + i * p; var z := Regiao.Z0 + j * p
			var a := r.altura(x, z); var ax := r.altura(x + p, z); var az := r.altura(x, z + p)
			var luz := clampf(0.75 + ((a - ax) - (a - az)) * 0.12, 0.3, 1.3)
			var c := Color(0.2, 0.4, 0.75) if r.agua(x, z) else (Color(0.85, 0.8, 0.6) if a < 2.0 else Color(0.35, 0.6, 0.3).lerp(Color(0.6, 0.5, 0.35), clampf((a - 8.0) / 30.0, 0, 1)).lerp(Color(0.95, 0.95, 0.95), clampf((a - 45.0) / 25.0, 0, 1)))
			if r.dist_estrada(x, z) < 3.0: c = Color(0.8, 0.7, 0.5)
			img.set_pixel(i, j, c * luz)
	img.save_png(saida); print("RELEVO ok"); quit()

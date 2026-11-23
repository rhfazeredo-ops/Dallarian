# Imprime uma grade de alturas do terreno (para planejar obras): --x0 --x1 --z0 --z1 --passo
extends SceneTree
func _initialize() -> void:
	var a := {}
	for s in OS.get_cmdline_user_args():
		var p := s.trim_prefix("--").split("="); a[p[0]] = p[1] if p.size() > 1 else "1"
	var r := Regiao.new()
	var x0 := float(a.get("x0", "1450")); var x1 := float(a.get("x1", "1650")); var z0 := float(a.get("z0", "-1050")); var z1 := float(a.get("z1", "-850")); var ps := float(a.get("passo", "20"))
	var lin := "      "
	var x := x0
	while x <= x1: lin += "%6d" % x; x += ps
	print(lin)
	var z := z0
	while z <= z1:
		lin = "%6d" % z; x = x0
		while x <= x1:
			var h := r.altura(x, z); var w := r.agua(x, z)
			lin += ("%5.0f~" if w != 0.0 and h < w else "%6.0f") % h
			x += ps
		print(lin); z += ps
	quit()

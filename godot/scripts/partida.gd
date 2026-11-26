# Tela de PARTIDA do APK (a primeira cena): procura atualização, baixa o pacote do jogo e o carrega ANTES de
# qualquer outro script do jogo. Por isso este arquivo não cita nenhuma classe do jogo (Herois, CorpoHeroi...):
# o que já foi carregado fica na memória com o código velho, e a atualização não pegava (heróis, menus).
# Depois de aplicar o pacote, abre o menu de início (menu.tscn), que já vem todo do pacote novo.
# No site (web) não precisa: o navegador já pega a versão nova.
extends Control

const BASE := "https://github.com/rhfazeredo-ops/Dallarian/releases/download/apk/"
const PASTA := "user://atualizacao/"
var _texto: Label
var _barra: ProgressBar
var _baixando: HTTPRequest

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fundo := ColorRect.new(); fundo.color = Color(0.06, 0.05, 0.05); fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(fundo)
	if ResourceLoader.exists("res://assets/ui/tela_inicio.png"):
		var img := TextureRect.new(); img.texture = load("res://assets/ui/tela_inicio.png")
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(img)
		var sombra := ColorRect.new(); sombra.color = Color(0, 0, 0, 0.35); sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(sombra)
	var v := VBoxContainer.new(); v.set_anchors_and_offsets_preset(Control.PRESET_CENTER); v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.custom_minimum_size = Vector2(900, 200); v.position -= Vector2(450, 100); add_child(v)
	var t := Label.new(); t.text = "DALLARIAN"; t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 72); t.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3)); v.add_child(t)
	t.add_theme_constant_override("outline_size", 14); t.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_texto = Label.new(); _texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _texto.add_theme_font_size_override("font_size", 30)
	_texto.add_theme_constant_override("outline_size", 8); _texto.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_texto.text = "Abrindo..."; v.add_child(_texto)
	_barra = ProgressBar.new(); _barra.custom_minimum_size = Vector2(900, 26); _barra.visible = false; _barra.show_percentage = false; v.add_child(_barra)
	await get_tree().process_frame
	var embutida := _versao("res://versao.json")
	var args := OS.get_cmdline_user_args()
	if OS.has_feature("android") or args.has("--atualizar"): await _procurar(embutida)
	_usar_pacote(embutida)
	var falta := _classes_faltando()
	if not falta.is_empty():                # o APK é velho demais para este pacote (classe nova): pedir o APK novo
		print("ATUALIZACAO: o APK não conhece as classes ", falta)
		_texto.text = "Esta atualização precisa do APK novo.\nToque abaixo para baixar e instalar por cima\n(seus heróis e o progresso continuam)."
		var bt := Button.new(); bt.text = "BAIXAR APK NOVO"; bt.add_theme_font_size_override("font_size", 36); bt.custom_minimum_size = Vector2(900, 96)
		bt.pressed.connect(func(): OS.shell_open(BASE + "dallarian.apk")); v.add_child(bt)
		return
	Engine.set_meta("partida_ok", true)      # o menu não procura atualização de novo
	get_tree().change_scene_to_file("res://cenas/menu.tscn")

func _rede(h: HTTPRequest) -> void:          # só para testar no PC atrás de um proxy
	for x in OS.get_cmdline_user_args():
		if x.begins_with("--proxy="):
			var hp := x.trim_prefix("--proxy=").split(":"); h.set_https_proxy(hp[0], int(hp[1])); h.set_http_proxy(hp[0], int(hp[1]))
		if x.begins_with("--ca="):
			var c := X509Certificate.new(); c.load(x.trim_prefix("--ca=")); h.set_tls_options(TLSOptions.client(c))

func _versao(arq: String) -> int:
	if not FileAccess.file_exists(arq): return 0
	var d = JSON.parse_string(FileAccess.get_file_as_string(arq))
	return int(d.get("n", 0)) if d is Dictionary else 0

func _procurar(embutida: int) -> void:
	_texto.text = "Procurando atualização..."
	var tem := maxi(embutida, _versao(PASTA + "versao.json"))
	var h := HTTPRequest.new(); h.timeout = 8.0; add_child(h); _rede(h)
	if h.request(BASE + "versao.json") != OK: return
	var r: Array = await h.request_completed
	h.queue_free()
	print("ATUALIZACAO: versao.json resultado=%d código=%d" % [r[0], r[1]])
	if r[0] != HTTPRequest.RESULT_SUCCESS or r[1] != 200: _texto.text = "Sem conexão: abrindo a versão que você tem."; return
	var d = JSON.parse_string((r[3] as PackedByteArray).get_string_from_utf8())
	if not d is Dictionary or int(d.get("n", 0)) <= tem: return
	DirAccess.make_dir_recursive_absolute(PASTA)
	_texto.text = "Baixando atualização (versão %d)..." % int(d.n)
	_barra.visible = true
	_baixando = HTTPRequest.new(); _baixando.timeout = 900.0; _baixando.download_file = PASTA + "baixando.pck"
	_baixando.use_threads = true; add_child(_baixando); _rede(_baixando)
	if _baixando.request(BASE + "dallarian.pck") != OK: return
	var r2: Array = await _baixando.request_completed
	_baixando.queue_free(); _baixando = null; _barra.visible = false
	var ok: bool = r2[0] == HTTPRequest.RESULT_SUCCESS and r2[1] == 200
	if ok and d.has("tamanho"):
		var f := FileAccess.open(PASTA + "baixando.pck", FileAccess.READ)
		ok = f != null and f.get_length() == int(d.tamanho)
		if f: f.close()
	if not ok:
		DirAccess.remove_absolute(PASTA + "baixando.pck")
		_texto.text = "Não deu para baixar agora: abrindo a versão que você tem."; return
	DirAccess.rename_absolute(PASTA + "baixando.pck", PASTA + "jogo.pck")
	var f2 := FileAccess.open(PASTA + "versao.json", FileAccess.WRITE)
	if f2: f2.store_string(JSON.stringify({"n": int(d.n)})); f2.close()
	_texto.text = "Atualizado!"; print("ATUALIZACAO: baixou a versão %d" % int(d.n))

func _process(_d: float) -> void:
	if _baixando and _baixando.get_body_size() > 0:
		_barra.value = 100.0 * _baixando.get_downloaded_bytes() / _baixando.get_body_size()

# usa o pacote baixado só se ele for mais novo que o jogo que veio no APK (APK novo instalado por cima ganha)
func _usar_pacote(embutida: int) -> void:
	var arq := PASTA + "jogo.pck"
	for a in OS.get_cmdline_user_args(): if a.begins_with("--pacote="): arq = a.trim_prefix("--pacote=")     # teste
	if not FileAccess.file_exists(arq): return
	if not arq.begins_with("/") and _versao(PASTA + "versao.json") <= embutida: return
	if ProjectSettings.load_resource_pack(arq, true): _texto.text = "Abrindo..."; print("ATUALIZACAO: usando o pacote ", arq)

func _classes_faltando() -> Array:
	var cf := ConfigFile.new()
	if cf.load("res://.godot/global_script_class_cache.cfg") != OK: return []
	var falta := []
	for c in cf.get_value("", "list", []):
		var nome := String(c.get("class", ""))
		if nome == "": continue
		var sc := GDScript.new(); sc.source_code = "extends RefCounted\nfunc f():\n\treturn %s\n" % nome
		if sc.reload() != OK: falta.append(nome)
	return falta

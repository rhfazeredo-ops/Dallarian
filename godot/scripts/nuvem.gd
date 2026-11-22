# Save na nuvem (Supabase), perfil ANÔNIMO por aparelho: na primeira vez o jogo sorteia um id e um segredo
# (guardados só no aparelho, em user://perfil.json). O save continua no aparelho como antes e também vai para o banco
# pelas funções salvar_jogo/carregar_jogo, que só aceitam o segredo certo (a tabela não pode ser lida direto).
# Ao abrir o jogo, se o save da nuvem for mais novo que o do aparelho, ele é usado. Sem internet o jogo segue
# normal com o save local e tenta de novo depois.
# A chave abaixo é a "publishable" (pública, feita para ir dentro do app).
extends Node
class_name Nuvem

const URL := "https://vopbcslkjwumphjqmlbl.supabase.co"
const CHAVE := "sb_publishable_D3SLeM8s03XBBgOsBMoyoQ_gxNR09rl"
const INTERVALO := 30.0              # no máximo um envio a cada 30 s (o resto fica para o próximo)

signal save_baixado(dados: Dictionary)
var ligado := false                  # falou com o banco
var user_id := ""
var _pendente: Dictionary = {}
var _ultimo_envio := -1000.0
var _enviando := false
var log_ativo := false

func _log(t: String) -> void:
	if log_ativo: print("NUVEM: ", t)

func _agora() -> float: return Time.get_unix_time_from_system()

# faz uma requisição e devolve [código, corpo como Variant (ou texto)]
func _pedir(metodo: int, caminho: String, corpo = null, extra: PackedStringArray = []) -> Array:
	var h := HTTPRequest.new(); h.timeout = 15.0; add_child(h)
	var cab := PackedStringArray(["apikey: " + CHAVE, "Content-Type: application/json"])
	cab.append_array(extra)
	var err := h.request(URL + caminho, cab, metodo, "" if corpo == null else JSON.stringify(corpo))
	if err != OK: h.queue_free(); return [0, null]
	var r: Array = await h.request_completed
	h.queue_free()
	var txt: String = (r[3] as PackedByteArray).get_string_from_utf8()
	var dado = JSON.parse_string(txt) if txt != "" else null
	return [int(r[1]), dado if dado != null else txt]

const ARQ_PERFIL := "user://perfil.json"
var _segredo := ""
func _perfil() -> void:
	if user_id != "": return
	if FileAccess.file_exists(ARQ_PERFIL):
		var d = JSON.parse_string(FileAccess.get_file_as_string(ARQ_PERFIL))
		if d is Dictionary and d.has("id") and d.has("segredo"): user_id = d.id; _segredo = d.segredo; return
	var c := Crypto.new()
	var b := c.generate_random_bytes(16)
	b[6] = (b[6] & 0x0f) | 0x40; b[8] = (b[8] & 0x3f) | 0x80          # UUID versão 4
	var hx := b.hex_encode()
	user_id = "%s-%s-%s-%s-%s" % [hx.substr(0, 8), hx.substr(8, 4), hx.substr(12, 4), hx.substr(16, 4), hx.substr(20, 12)]
	_segredo = c.generate_random_bytes(32).hex_encode()
	var f := FileAccess.open(ARQ_PERFIL, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify({"id": user_id, "segredo": _segredo}))
	_log("perfil novo " + user_id)

# baixa o save da nuvem (vazio se não tem ou sem internet)
func baixar() -> Dictionary:
	_perfil()
	var r := await _pedir(HTTPClient.METHOD_POST, "/rest/v1/rpc/carregar_jogo", {"p_id": user_id, "p_segredo": _segredo})
	if r[0] == 200 and r[1] is Dictionary: ligado = true; return r[1]
	ligado = r[0] == 200
	_log("baixar: %d %s" % [r[0], str(r[1]).left(120)])
	return {}

# começo do jogo: entra e, se o save da nuvem for mais novo que o local, avisa (o mundo aplica)
func iniciar(local_salvo_em: float) -> void:
	var d := await baixar()
	if d.is_empty(): _log("sem save na nuvem"); return
	if float(d.get("salvo_em", 0.0)) > local_salvo_em + 1.0:
		_log("save da nuvem é mais novo: usando"); save_baixado.emit(d)

# guarda para enviar (o envio sai no máximo a cada INTERVALO segundos)
func enviar(dados: Dictionary, ja := false) -> void:
	_pendente = dados
	if ja: _ultimo_envio = -1000.0
	_tentar()

func _process(_d: float) -> void:
	if not _pendente.is_empty(): _tentar()

func _tentar() -> void:
	if _enviando or _pendente.is_empty() or _agora() - _ultimo_envio < INTERVALO: return
	_enviando = true; _ultimo_envio = _agora()
	var dados := _pendente; _pendente = {}
	_perfil()
	var r := await _pedir(HTTPClient.METHOD_POST, "/rest/v1/rpc/salvar_jogo", {"p_id": user_id, "p_segredo": _segredo, "p_dados": dados})
	if r[0] == 200 and r[1] == true: _log("save enviado"); ligado = true
	else:
		_log("envio falhou (%d) %s" % [r[0], str(r[1]).left(200)])
		if _pendente.is_empty(): _pendente = dados                # tenta de novo depois
	_enviando = false

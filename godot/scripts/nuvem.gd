# Save na nuvem (Supabase), com login ANÔNIMO: na primeira vez o jogo cria um perfil anônimo e guarda a sessão no
# aparelho (user://sessao.json); depois só renova a sessão. O save continua salvo no aparelho como antes e também
# vai para a tabela public.saves (um por jogador; as regras do banco só deixam cada um ler/gravar o próprio).
# Ao abrir o jogo, se o save da nuvem for mais novo que o do aparelho, ele é usado. Sem internet o jogo segue
# normal com o save local e tenta de novo depois.
# A chave abaixo é a "publishable" (pública, feita para ir dentro do app); quem protege os dados são as regras.
extends Node
class_name Nuvem

const URL := "https://vopbcslkjwumphjqmlbl.supabase.co"
const CHAVE := "sb_publishable_D3SLeM8s03XBBgOsBMoyoQ_gxNR09rl"
const ARQ_SESSAO := "user://sessao.json"
const INTERVALO := 30.0              # no máximo um envio a cada 30 s (o resto fica para o próximo)

signal save_baixado(dados: Dictionary)
var ligado := false                  # sessão válida
var user_id := ""
var _acesso := ""
var _refresh := ""
var _expira := 0.0
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
	if _acesso != "": cab.append("Authorization: Bearer " + _acesso)
	cab.append_array(extra)
	var err := h.request(URL + caminho, cab, metodo, "" if corpo == null else JSON.stringify(corpo))
	if err != OK: h.queue_free(); return [0, null]
	var r: Array = await h.request_completed
	h.queue_free()
	var txt: String = (r[3] as PackedByteArray).get_string_from_utf8()
	var dado = JSON.parse_string(txt) if txt != "" else null
	return [int(r[1]), dado if dado != null else txt]

func _guardar_sessao(d: Dictionary) -> bool:
	if not d.has("access_token"): return false
	_acesso = d.access_token; _refresh = d.get("refresh_token", _refresh)
	_expira = _agora() + float(d.get("expires_in", 3600)) - 120.0
	user_id = String(d.get("user", {}).get("id", user_id))
	var f := FileAccess.open(ARQ_SESSAO, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify({"refresh_token": _refresh, "user_id": user_id}))
	ligado = true
	return true

# entra: renova a sessão guardada ou cria um perfil anônimo novo
func entrar() -> bool:
	if FileAccess.file_exists(ARQ_SESSAO):
		var s = JSON.parse_string(FileAccess.get_file_as_string(ARQ_SESSAO))
		if s is Dictionary and s.has("refresh_token"):
			_refresh = s.refresh_token; user_id = String(s.get("user_id", ""))
			_acesso = ""
			var r := await _pedir(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=refresh_token", {"refresh_token": _refresh})
			if r[0] == 200 and r[1] is Dictionary and _guardar_sessao(r[1]): _log("sessão renovada " + user_id); return true
			_log("não renovou (%d)" % r[0])
			if r[0] == 0: return false                       # sem internet: não cria outro perfil
	_acesso = ""
	var r2 := await _pedir(HTTPClient.METHOD_POST, "/auth/v1/signup", {"data": {"jogo": "Dallarian"}})
	if r2[0] == 200 and r2[1] is Dictionary and _guardar_sessao(r2[1]): _log("perfil anônimo criado " + user_id); return true
	_log("login anônimo falhou (%d) %s" % [r2[0], str(r2[1]).left(200)])
	return false

func _garantir_sessao() -> bool:
	if ligado and _agora() < _expira: return true
	ligado = false
	return await entrar()

# baixa o save da nuvem (vazio se não tem)
func baixar() -> Dictionary:
	if not await _garantir_sessao(): return {}
	var r := await _pedir(HTTPClient.METHOD_GET, "/rest/v1/saves?select=dados&user_id=eq." + user_id)
	if r[0] == 200 and r[1] is Array and not r[1].is_empty(): return r[1][0].get("dados", {})
	_log("baixar: %d" % r[0])
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
	if await _garantir_sessao():
		var r := await _pedir(HTTPClient.METHOD_POST, "/rest/v1/saves?on_conflict=user_id", {"user_id": user_id, "dados": dados},
			PackedStringArray(["Prefer: resolution=merge-duplicates,return=minimal"]))
		if r[0] == 401: ligado = false
		if r[0] >= 300 or r[0] == 0:
			_log("envio falhou (%d) %s" % [r[0], str(r[1]).left(200)])
			if _pendente.is_empty(): _pendente = dados        # tenta de novo depois
		else: _log("save enviado")
	elif _pendente.is_empty(): _pendente = dados
	_enviando = false

# Heróis da conta (neste aparelho): a lista fica em user://herois.json. A Rachel é a heroína original (usa o save
# antigo user://progresso.json e o save na nuvem); cada herói novo tem o seu próprio save no aparelho.
class_name Herois

const ARQ := "user://herois.json"
const RACHEL := {"id": "rachel", "nome": "Rachel", "raca": "Humana", "classe": "Guerreira"}
static var ativo: Dictionary = RACHEL
static var menu_ok := false              # já passou pelo menu de início (inicio.gd)
static var pular_atualizacao := false
static func teste_masculino() -> void: ativo = {"id": "teste", "nome": "Aldric", "raca": "Humano", "classe": "Guerreiro"}

static func lista() -> Array:
	var l: Array = [RACHEL] if FileAccess.file_exists("user://progresso.json") else []   # a Rachel só se já tem save
	if FileAccess.file_exists(ARQ):
		var d = JSON.parse_string(FileAccess.get_file_as_string(ARQ))
		if d is Array:
			for h in d: if h is Dictionary and h.get("id", "") != "rachel": l.append(h)
	return l

static func salvar_lista(l: Array) -> void:
	var f := FileAccess.open(ARQ, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(l.filter(func(h): return h.id != "rachel")))

static func criar(nome: String, raca: String, classe: String) -> Dictionary:
	var h := {"id": "h%d" % Time.get_unix_time_from_system(), "nome": nome, "raca": raca, "classe": classe}
	var l := lista(); l.append(h); salvar_lista(l)
	return h

static func arquivo(h: Dictionary = ativo) -> String:
	return "user://progresso.json" if h.get("id", "rachel") == "rachel" else "user://progresso_%s.json" % h.id

static func nivel(h: Dictionary) -> int:
	var a := arquivo(h)
	if not FileAccess.file_exists(a): return 1
	var d = JSON.parse_string(FileAccess.get_file_as_string(a))
	return int(d.get("nivel", 1)) if d is Dictionary else 1

static func nome_existe(nome: String) -> bool:
	for h in lista(): if String(h.nome).to_lower() == nome.to_lower(): return true
	return false

static func masculino(h: Dictionary) -> bool: return String(h.get("raca", "Humana")) == "Humano"
# os dois heróis do jogo, escolhidos pelo dono: a Cavaleira loira e o Príncipe (pacote Fantasy Kingdom)
const PADRAO_F := "fk:SM_Chr_Rider_01"
const PADRAO_M := "fk:SM_Chr_Prince_01"
static func modelo(h: Dictionary) -> String:
	return PADRAO_M if masculino(h) else PADRAO_F

# último herói jogado (a seleção abre com ele escolhido)
static func guardar_ultimo(h: Dictionary) -> void:
	var f := FileAccess.open("user://ultimo_heroi.txt", FileAccess.WRITE)
	if f: f.store_string(String(h.get("id", "")))
static func indice_ultimo() -> int:
	if not FileAccess.file_exists("user://ultimo_heroi.txt"): return 0
	var id := FileAccess.get_file_as_string("user://ultimo_heroi.txt").strip_edges()
	var l := lista()
	for i in l.size(): if String(l[i].id) == id: return i
	return 0

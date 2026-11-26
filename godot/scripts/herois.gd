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

static func criar(nome: String, raca: String, classe: String, visual := "") -> Dictionary:
	var h := {"id": "h%d" % Time.get_unix_time_from_system(), "nome": nome, "raca": raca, "classe": classe}
	if visual != "": h["visual"] = visual
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
# heróis do pacote Modular Fantasy Hero (repositório de arte); sem ele, os modelos antigos do Tripo
static func modelo(h: Dictionary) -> String:
	if ResourceLoader.exists(CorpoHeroi.MH_ARQ):
		if h.has("visual"): return String(h.visual)
		if int(h.get("base", 0)) > 0: return ("mh:Male:%d" if masculino(h) else "mh:Female:%d") % int(h.base)
		return PADRAO_M if masculino(h) else PADRAO_F
	return modelo_glb(h)

# todos os personagens dos pacotes da Synty que servem de herói, por gênero, numerados na criação de herói:
# primeiro os 53/67 prontos do Modular Fantasy Hero, depois os do Fantasy Kingdom
const PADRAO_F := "fk:SM_Chr_Rider_01"     # escolhida pelo dono (a cavaleira loira)
const PADRAO_M := "fk:SM_Chr_Prince_01"    # escolhido pelo dono (o príncipe)
static var _cat := {}
static func catalogo(masc: bool) -> Array:
	if _cat.has(masc): return _cat[masc]
	var l := []
	var g := "Male" if masc else "Female"
	for i in CorpoHeroi.mh_bases(g).size(): l.append("mh:%s:%d" % [g, i + 1])
	if Cidadao.existe():
		for n in ["SM_Chr_Bartender_01", "SM_Chr_Blacksmith_Female_01", "SM_Chr_Blacksmith_Male_01", "SM_Chr_Fairy_01", "SM_Chr_FortuneTeller_01",
				"SM_Chr_Headsman_01", "SM_Chr_Hermit_01", "SM_Chr_Jester_01", "SM_Chr_King_01", "SM_Chr_Mage_01", "SM_Chr_Merchant_01", "SM_Chr_Monk_01",
				"SM_Chr_Nun_01", "SM_Chr_Peasant_Female_01", "SM_Chr_Peasant_Male_01", "SM_Chr_Priest_01", "SM_Chr_Prince_01", "SM_Chr_Princess_01",
				"SM_Chr_Queen_01", "SM_Chr_Rider_01", "SM_Chr_Soldier_Female_01", "SM_Chr_Soldier_Male_01"]:
			if (n in Cidadao.MULHERES) != masc: l.append("fk:" + n)
	_cat[masc] = l
	return l
static func modelo_glb(h: Dictionary) -> String:
	return "res://assets/modelos/humano.glb" if masculino(h) else "res://assets/modelos/humana.glb"
static func retrato(h: Dictionary) -> String:
	return "res://assets/ui/racas/1_m.png" if masculino(h) else "res://assets/ui/racas/1_f.png"

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

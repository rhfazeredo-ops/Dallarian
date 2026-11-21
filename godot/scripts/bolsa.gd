# Bolsa da Rachel: itens (nome → quantidade) e dinheiro. O dinheiro é guardado em COBRE:
# 100 cobre = 1 prata, 100 prata = 1 ouro. Também salva o progresso (nível, XP, dinheiro, itens) no aparelho.
extends RefCounted
class_name Bolsa

# itens do jogo: id → [nome, preço de venda em cobre, descrição]
const ITENS := {
	"dentes_garras": ["Dentes e garras de lobo", 12, "Um punhado de presas e garras. O ferreiro paga uns cobres."],
}
const ARQUIVO := "user://progresso.json"
signal mudou
var itens := {}
var cobre := 0

func pegar(id: String, qtd := 1) -> void:
	itens[id] = int(itens.get(id, 0)) + qtd; mudou.emit()

func vender(id: String, qtd: int) -> int:
	var tem := int(itens.get(id, 0)); qtd = mini(qtd, tem)
	if qtd <= 0: return 0
	itens[id] = tem - qtd
	if itens[id] == 0: itens.erase(id)
	var ganho: int = ITENS[id][1] * qtd
	cobre += ganho; mudou.emit()
	return ganho

static func texto_dinheiro(c: int) -> String:
	var ouro := c / 10000; var prata := (c / 100) % 100; var cob := c % 100
	var partes := []
	if ouro > 0: partes.append("%d ouro" % ouro)
	if prata > 0: partes.append("%d prata" % prata)
	if cob > 0 or partes.is_empty(): partes.append("%d cobre" % cob)
	return "  ".join(partes)

# [ouro, prata, cobre]
static func moedas(c: int) -> Array: return [c / 10000, (c / 100) % 100, c % 100]

func salvar(nivel: int, xp: float) -> void:
	var f := FileAccess.open(ARQUIVO, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify({"nivel": nivel, "xp": xp, "cobre": cobre, "itens": itens}))

func carregar() -> Dictionary:
	if not FileAccess.file_exists(ARQUIVO): return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO))
	if typeof(d) != TYPE_DICTIONARY: return {}
	cobre = int(d.get("cobre", 0))
	itens = {}
	var it: Dictionary = d.get("itens", {})
	for k in it.keys(): if ITENS.has(k): itens[k] = int(it[k])
	return d

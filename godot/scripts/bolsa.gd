# Inventário da Rachel no estilo do WoW: até 3 bolsas equipadas (de 10 a 50 espaços cada); cada espaço guarda
# uma pilha de um item. Começa com uma bolsa de 10. Dinheiro guardado em COBRE (100 cobre = 1 prata,
# 100 prata = 1 ouro). Também salva o progresso (nível, XP, dinheiro, bolsas) no aparelho.
extends RefCounted
class_name Bolsa

const MAX_BOLSAS := 3
# qualidade (cor do nome, como no WoW): lixo = cinza, comum = branco, incomum = verde, raro = azul
const CORES := {"lixo": Color(0.62, 0.62, 0.62), "comum": Color(1, 1, 1), "incomum": Color(0.12, 1.0, 0.0), "raro": Color(0.0, 0.44, 0.87)}
# itens: id → nome, venda (cobre), compra (cobre, 0 = não se compra), pilha, qualidade, espaços (bolsas), descrição
const ITENS := {
	# armas (como no Classic): dano mín–máx, velocidade (s por golpe), nível exigido
	"espada_treino": {"nome": "Espada de treino de madeira", "venda": 5, "compra": 0, "pilha": 1, "qual": "comum",
		"tipo": "arma", "subtipo": "Espada", "maos": "Uma mão", "dano_min": 2, "dano_max": 4, "velocidade": 1.8, "nivel": 1,
		"modelo": "madeira", "desc": "Madeira dura e farpas. Serve para aprender."},
	"espada_ferro": {"nome": "Espada de ferro", "venda": 38, "compra": 150, "pilha": 1, "qual": "comum",
		"tipo": "arma", "subtipo": "Espada", "maos": "Uma mão", "dano_min": 6, "dano_max": 11, "velocidade": 2.2, "nivel": 3,
		"modelo": "ferro", "desc": "Ferro batido na bigorna do Bram."},
	# escudos: armadura (reduz todo dano), valor de bloqueio (tirado quando bloqueia) e quanto o bloqueio ativo segura
	"escudo_madeira": {"nome": "Escudo de madeira", "venda": 5, "compra": 0, "pilha": 1, "qual": "comum",
		"tipo": "escudo", "subtipo": "Escudo", "armadura": 30, "bloqueio": 5, "bloqueio_ativo": 0.6, "nivel": 1,
		"modelo": "madeira", "desc": "Tábuas presas com tiras de couro."},
	"nucleo_golem": {"nome": "Coração de barro do Grumo", "venda": 250, "compra": 0, "pilha": 5, "qual": "incomum",
		"desc": "Ainda pulsa, morno. Dizem que guarda a força do vale."},
	# montarias (compradas no estábulo de Altamar): não ocupam a bolsa, vão para o menu do personagem
	"cavalo_branco": {"nome": "Cavalo branco malhado", "venda": 0, "compra": 80, "pilha": 1, "qual": "incomum", "tipo_m": "montaria", "cor": Color(0.94, 0.93, 0.9),
		"crina": Color(0.8, 0.78, 0.74), "desc": "Manso e elegante. Aumenta a velocidade em 60%."},
	"cavalo_marrom": {"nome": "Cavalo alazão", "venda": 0, "compra": 80, "pilha": 1, "qual": "incomum", "tipo_m": "montaria", "cor": Color(0.55, 0.22, 0.12),
		"crina": Color(0.3, 0.15, 0.08), "desc": "Forte e incansável. Aumenta a velocidade em 60%."},
	"cavalo_dourado": {"nome": "Cavalo dourado", "venda": 0, "compra": 80, "pilha": 1, "qual": "incomum", "tipo_m": "montaria", "cor": Color(0.8, 0.58, 0.3),
		"crina": Color(0.3, 0.17, 0.1), "desc": "Brilha como trigo ao sol. Aumenta a velocidade em 60%."},
	"cavalo_preto": {"nome": "Cavalo preto", "venda": 0, "compra": 80, "pilha": 1, "qual": "incomum", "tipo_m": "montaria", "cor": Color(0.18, 0.17, 0.19),
		"crina": Color(0.08, 0.07, 0.08), "desc": "Veloz como a noite. Aumenta a velocidade em 60%."},
	"frutinhas": {"nome": "Frutinhas silvestres", "venda": 1, "compra": 0, "pilha": 20, "qual": "comum", "cura": 5,
		"desc": "Frutinhas vermelhas colhidas no mato. Azedinhas, mas matam a fome."},
	# poções de vida (vendidas pelas freiras): curam uma parte da vida máxima
	"pocao_p": {"nome": "Poção de vida pequena", "venda": 5, "compra": 20, "pilha": 10, "qual": "comum", "cura_pct": 10,
		"desc": "Um frasquinho de chá de ervas benzido pelas irmãs. Sabor de mel e hortelã."},
	"pocao_m": {"nome": "Poção de vida média", "venda": 18, "compra": 75, "pilha": 10, "qual": "comum", "cura_pct": 20,
		"desc": "Água da fonte do mosteiro com raiz-de-cura. Fecha cortes e afasta o cansaço."},
	"pocao_g": {"nome": "Poção de vida grande", "venda": 38, "compra": 150, "pilha": 10, "qual": "incomum", "cura_pct": 30,
		"desc": "A receita mais antiga das irmãs, guardada a sete chaves. Põe de pé até um cavaleiro caído."},
	"escama_lodoso": {"nome": "Escama de Lodoso", "venda": 8, "compra": 0, "pilha": 20, "qual": "lixo",
		"desc": "Escamas escorregadias amarradas com alga. Ainda cheiram a rio."},
	"barbatana_lodoso": {"nome": "Barbatana de Lodoso", "venda": 10, "compra": 0, "pilha": 20, "qual": "lixo",
		"desc": "Uma barbatana espinhuda, ainda mole e pegajosa. Os pescadores usam para fazer cola."},
	"olho_lodoso": {"nome": "Olho de Lodoso", "venda": 16, "compra": 0, "pilha": 20, "qual": "lixo",
		"desc": "Grande, amarelo e com a pupila em fenda. Parece que ainda está olhando para você."},
	"perola_lama": {"nome": "Pérola da Lama", "venda": 90, "compra": 0, "pilha": 10, "qual": "incomum",
		"desc": "Uma pérola esverdeada que o xamã dos Lodosos guardava. Brilha fraquinho no escuro e é fria como a água do fundo do rio."},
	"presa_aranha": {"nome": "Presa de aranha-musgo", "venda": 15, "compra": 0, "pilha": 20, "qual": "lixo",
		"desc": "Uma presa curva que ainda pinga veneno. Cuidado ao guardar."},
	"dentes_garras": {"nome": "Dentes e garras de lobo", "venda": 12, "compra": 0, "pilha": 20, "qual": "lixo",
		"desc": "Um punhado de presas e garras amarradas. O ferreiro paga uns cobres."},
	"bolsa_10": {"nome": "Bolsa de couro pequena", "venda": 20, "compra": 80, "pilha": 1, "qual": "comum", "espacos": 10,
		"desc": "Bolsa de couro cru, costurada à mão."},
	"bolsa_16": {"nome": "Bolsa de couro", "venda": 75, "compra": 300, "pilha": 1, "qual": "comum", "espacos": 16,
		"desc": "Couro curtido e alça reforçada."},
	"bolsa_20": {"nome": "Bolsa de viajante", "venda": 200, "compra": 800, "pilha": 1, "qual": "comum", "espacos": 20,
		"desc": "Feita para longas estradas."},
	"bolsa_30": {"nome": "Mochila de caçador", "venda": 750, "compra": 3000, "pilha": 1, "qual": "incomum", "espacos": 30,
		"desc": "Mochila larga com fivelas de ferro."},
	"bolsa_40": {"nome": "Mochila reforçada", "venda": 2500, "compra": 10000, "pilha": 1, "qual": "incomum", "espacos": 40,
		"desc": "Lona dupla e cantos de couro."},
	"bolsa_50": {"nome": "Mochila do mercador", "venda": 7500, "compra": 30000, "pilha": 1, "qual": "raro", "espacos": 50,
		"desc": "Cabe uma feira inteira aqui dentro."},
}
const ARQUIVO := "user://progresso.json"
signal mudou
var bolsas := []                  # [{id, slots: [null ou [id, qtd]]}, ou null] — 3 lugares
var cobre := 0
var recompra := []                # últimos vendidos: [id, qtd, preço total]
var equip := {"arma": "espada_treino", "escudo": "escudo_madeira"}
var montarias := []                # ids das montarias que a Rachel tem
var montaria_sel := ""             # a escolhida no menu (a que aparece no botão de montar)
signal equipou(lugar: String, id: String)

func _init() -> void:
	bolsas = [_bolsa_nova("bolsa_10"), null, null]

static func _bolsa_nova(id: String) -> Dictionary:
	var s := []; s.resize(int(ITENS[id].espacos))
	return {"id": id, "slots": s}

static func info(id: String) -> Dictionary: return ITENS[id]
static func eh_bolsa(id: String) -> bool: return ITENS[id].has("espacos")
static func lugar_equip(id: String) -> String: return String(ITENS[id].get("tipo", ""))   # "arma", "escudo" ou ""

# equipa a arma/escudo do espaço (b, i); o que estava equipado volta para esse espaço
func equipar_item(b: int, i: int, nivel_heroi: int) -> String:
	var s = slot(b, i)
	if s == null: return ""
	var lugar := lugar_equip(s[0])
	if lugar == "": return ""
	if int(ITENS[s[0]].get("nivel", 1)) > nivel_heroi: return "Requer nível %d." % ITENS[s[0]].nivel
	var antigo = equip.get(lugar, "")
	equip[lugar] = s[0]
	bolsas[b].slots[i] = [antigo, 1] if antigo != "" else null
	equipou.emit(lugar, s[0]); mudou.emit()
	return ""

func espacos_total() -> int:
	var t := 0
	for b in bolsas: if b: t += b.slots.size()
	return t

func espacos_livres() -> int:
	var t := 0
	for b in bolsas:
		if b:
			for s in b.slots: if s == null: t += 1
	return t

func cabe(id: String, qtd: int) -> bool:
	var falta := qtd; var pilha: int = ITENS[id].pilha
	for b in bolsas:
		if b == null: continue
		for s in b.slots:
			if s == null: falta -= pilha
			elif s[0] == id: falta -= pilha - int(s[1])
			if falta <= 0: return true
	return falta <= 0

# guarda o item (completa as pilhas e depois os espaços vazios); devolve o que não coube
func pegar(id: String, qtd := 1) -> int:
	var pilha: int = ITENS[id].pilha
	for b in bolsas:
		if b == null: continue
		for s in b.slots:
			if qtd > 0 and s != null and s[0] == id and int(s[1]) < pilha:
				var n := mini(qtd, pilha - int(s[1])); s[1] = int(s[1]) + n; qtd -= n
	for b in bolsas:
		if b == null: continue
		for i in b.slots.size():
			if qtd > 0 and b.slots[i] == null:
				var n := mini(qtd, pilha); b.slots[i] = [id, n]; qtd -= n
	mudou.emit()
	return qtd

func slot(b: int, i: int):
	if b < 0 or b >= bolsas.size() or bolsas[b] == null: return null
	return bolsas[b].slots[i]

# consome 1 do espaço (frutinhas etc.): devolve quanto de vida cura (0 se não é consumível)
static func eh_consumivel(id: String) -> bool: return ITENS[id].has("cura") or ITENS[id].has("cura_pct")
static func texto_cura(id: String) -> String:
	var it: Dictionary = ITENS[id]
	return "Usar: recupera %d%% da vida." % int(it.cura_pct) if it.has("cura_pct") else "Usar: recupera %d de vida." % int(it.cura)
func consumir(b: int, i: int, vida_max := 100.0) -> int:
	var s = slot(b, i)
	if s == null or not eh_consumivel(s[0]): return 0
	var it: Dictionary = ITENS[s[0]]
	var cura: int = int(round(vida_max * float(it.cura_pct) / 100.0)) if it.has("cura_pct") else int(it.cura)
	s[1] = int(s[1]) - 1
	if int(s[1]) <= 0: bolsas[b].slots[i] = null
	mudou.emit()
	return cura

# vende a pilha inteira do espaço (como o clique direito no vendedor do WoW)
func vender_slot(b: int, i: int) -> int:
	var s = slot(b, i)
	if s == null: return 0
	var ganho: int = int(ITENS[s[0]].venda) * int(s[1])
	bolsas[b].slots[i] = null; cobre += ganho
	recompra.push_front([s[0], int(s[1]), ganho])
	if recompra.size() > 12: recompra.pop_back()
	mudou.emit()
	return ganho

func recomprar(k: int) -> String:
	if k >= recompra.size(): return ""
	var r: Array = recompra[k]
	if cobre < r[2]: return "Dinheiro insuficiente."
	if not cabe(r[0], r[1]): return "Suas bolsas estão cheias."
	cobre -= r[2]; pegar(r[0], r[1]); recompra.remove_at(k); mudou.emit()
	return ""

static func eh_montaria(id: String) -> bool: return ITENS[id].get("tipo_m", "") == "montaria"

func comprar(id: String) -> String:
	var preco: int = ITENS[id].compra
	if eh_montaria(id) and tem_montaria(id): return "Você já tem essa montaria."
	if cobre < preco: return "Dinheiro insuficiente."
	if not cabe(id, 1): return "Suas bolsas estão cheias."
	cobre -= preco; pegar(id, 1)
	return ""

# montaria: já aprendida ou ainda na bolsa (comprada e não usada)
func tem_montaria(id: String) -> bool:
	if id in montarias: return true
	for b in bolsas:
		if b == null: continue
		for s in b.slots: if s != null and s[0] == id: return true
	return false

# usar o cavalo da bolsa (toque duplo): some da bolsa e vira montaria (vai para o menu do personagem)
func aprender_montaria(b: int, i: int) -> String:
	var s = slot(b, i)
	if s == null or not eh_montaria(s[0]): return ""
	bolsas[b].slots[i] = null
	if not s[0] in montarias: montarias.append(s[0])
	mudou.emit()
	return s[0]

# equipa a bolsa que está no espaço (b, i) num lugar de bolsa vazio
func equipar_bolsa(b: int, i: int) -> String:
	var s = slot(b, i)
	if s == null or not eh_bolsa(s[0]): return ""
	var livre := bolsas.find(null)
	if livre < 0: return "Você já usa %d bolsas (o máximo)." % MAX_BOLSAS
	bolsas[b].slots[i] = null
	bolsas[livre] = _bolsa_nova(s[0]); mudou.emit()
	return ""

# tira uma bolsa equipada (só se estiver vazia e não for a única) e guarda nas outras
func desequipar_bolsa(k: int) -> String:
	if bolsas[k] == null: return ""
	var cheias := 0
	for b in bolsas: if b: cheias += 1
	if cheias <= 1: return "Você precisa de pelo menos uma bolsa."
	for s in bolsas[k].slots: if s != null: return "Esvazie a bolsa antes de tirá-la."
	var id: String = bolsas[k].id
	bolsas[k] = null
	if pegar(id, 1) > 0: bolsas[k] = _bolsa_nova(id); return "Não há espaço para guardar a bolsa."
	return ""

static func texto_dinheiro(c: int) -> String:
	var mo := moedas(c); var partes := []
	if mo[0] > 0: partes.append("%d ouro" % mo[0])
	if mo[1] > 0: partes.append("%d prata" % mo[1])
	if mo[2] > 0 or partes.is_empty(): partes.append("%d cobre" % mo[2])
	return "  ".join(partes)

static func moedas(c: int) -> Array: return [c / 10000, (c / 100) % 100, c % 100]

# grava no aparelho e devolve o que gravou (o mundo manda o mesmo para a nuvem)
func salvar(nivel: int, xp: float) -> Dictionary:
	var d := {"nivel": nivel, "xp": xp, "cobre": cobre, "bolsas": bolsas, "equip": equip, "montarias": montarias, "montaria_sel": montaria_sel,
		"salvo_em": Time.get_unix_time_from_system()}
	var f := FileAccess.open(ARQUIVO, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(d))
	return d

func carregar() -> Dictionary:
	if not FileAccess.file_exists(ARQUIVO): return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO))
	if typeof(d) != TYPE_DICTIONARY: return {}
	return aplicar(d)

# põe um save (do aparelho ou da nuvem) na bolsa
func aplicar(d: Dictionary) -> Dictionary:
	bolsas = [_bolsa_nova("bolsa_10"), null, null]
	cobre = int(d.get("cobre", 0))
	montarias = []
	for mt in d.get("montarias", []): if ITENS.has(mt): montarias.append(mt)
	montaria_sel = String(d.get("montaria_sel", "")) if String(d.get("montaria_sel", "")) in montarias else ""
	var eq: Dictionary = d.get("equip", {})
	for k in ["arma", "escudo"]: if ITENS.has(eq.get(k, "")): equip[k] = eq[k]
	if d.has("bolsas"):
		var bs: Array = d.bolsas
		for k in MAX_BOLSAS:
			bolsas[k] = null
			if k < bs.size() and bs[k] is Dictionary and ITENS.has(bs[k].get("id", "")):
				var nb := _bolsa_nova(bs[k].id)
				var ss: Array = bs[k].get("slots", [])
				for i in mini(ss.size(), nb.slots.size()):
					if ss[i] is Array and ITENS.has(ss[i][0]): nb.slots[i] = [ss[i][0], int(ss[i][1])]
				bolsas[k] = nb
		if bolsas[0] == null and bolsas[1] == null and bolsas[2] == null: bolsas[0] = _bolsa_nova("bolsa_10")
	elif d.has("itens"):                                  # progresso antigo (antes das bolsas)
		var it: Dictionary = d.itens
		for k in it.keys(): if ITENS.has(k): pegar(k, int(it[k]))
	return d

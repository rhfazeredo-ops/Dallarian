# Inventário da Rachel no estilo do WoW: até 3 bolsas equipadas (de 10 a 50 espaços cada); cada espaço guarda
# uma pilha de um item. Começa com uma bolsa de 10. Dinheiro guardado em COBRE (100 cobre = 1 prata,
# 100 prata = 1 ouro). Também salva o progresso (nível, XP, dinheiro, bolsas) no aparelho.
extends RefCounted
class_name Bolsa

const MAX_BOLSAS := 3
# qualidade (cor do nome, como no WoW): lixo = cinza, comum = branco, incomum = verde, raro = azul
const CORES := {"lixo": Color(0.62, 0.62, 0.62), "comum": Color(1, 1, 1), "incomum": Color(0.12, 1.0, 0.0), "raro": Color(0.0, 0.44, 0.87)}
# itens: id → nome, venda (cobre), compra (cobre, 0 = não se compra), pilha, qualidade, espaços (bolsas), descrição
const ILVL_MAX := 120
const QUAL_MULT := {"lixo": 0.8, "comum": 1.0, "incomum": 1.12, "raro": 1.25, "epico": 1.4}
const QUAL_SOBE := {"lixo": "comum", "comum": "incomum", "incomum": "raro", "raro": "raro"}
# ATRIBUTOS (quanto maior o item level, mais forte). Números cheios: ataque e defesa. Porcentagens: acerto
# crítico (chance de critar), dano crítico (quanto o crítico soma ao golpe), chance de bloqueio.
# arma: ataque = (1 + 0,36 × ilvl) × qualidade × peso (adaga leve 1,5 … martelo 3,0)
static func arma_por_ilvl(ilvl: int, qual: String, peso: float, subtipo: String, semente: int) -> Dictionary:
	ilvl = clampi(ilvl, 1, ILVL_MAX); var q := float(QUAL_MULT.get(qual, 1.0))
	var jeito: Array = JEITO_CRIT.get(subtipo, [0, 0])           # adagas critam mais; martelos e maças, mais forte
	var sorte := absi(semente) % 3                               # duas armas do mesmo nível não ficam idênticas
	return {"ataque": maxi(2, roundi((1.0 + 0.36 * ilvl) * q * peso)),
		"crit_chance": 3 + roundi(ilvl * 0.35 * q) + int(jeito[0]) + sorte,
		"crit_dano": 50 + roundi(ilvl * 4.0 * q) + int(jeito[1]) + sorte * 3,
		"nivel": maxi(1, ilvl - 5)}
const JEITO_CRIT := {"Adaga": [5, 0], "Faca": [4, 0], "Espada": [2, 5], "Machado": [1, 15], "Maça": [0, 25],
	"Martelo": [0, 35], "Lança": [2, 10], "Cajado": [1, 5], "Cetro": [1, 10]}
# escudo: defesa = (10 + 5 × ilvl) × qualidade; chance de bloqueio = 5% + ~0,6% por ilvl (bloqueio = golpe inteiro)
static func escudo_por_ilvl(ilvl: int, qual: String, semente: int) -> Dictionary:
	ilvl = clampi(ilvl, 1, ILVL_MAX); var q := float(QUAL_MULT.get(qual, 1.0))
	return {"defesa": roundi((10 + 5 * ilvl) * q), "chance_bloqueio": mini(40, 5 + roundi(ilvl * 0.6 * q) + absi(semente) % 2),
		"nivel": maxi(1, ilvl - 5)}

const ITENS_BASE := {
	# ITEM LEVEL (como no WoW, de 1 a 120): o nível do item define a força dele (Bolsa.arma_por_ilvl e
	# Bolsa.escudo_por_ilvl) e o nível exigido fica uns 5 abaixo. O Vale de Aldren (primeiro mapa) vai até ~15.
	# armas: ataque, acerto crítico (%), dano crítico (%), nível exigido
	# escudos: defesa (reduz todo dano), chance de bloqueio (%) e quanto o bloqueio ativo (segurar) segura
	"nucleo_golem": {"nome": "Coração de barro de Barrogar", "venda": 250, "compra": 0, "pilha": 5, "qual": "incomum",
		"desc": "Ainda pulsa, morno. Dizem que guarda a força do vale."},
	# montarias (compradas no estábulo de Altamar): não ocupam a bolsa, vão para o menu do personagem
	"cavalo_branco": {"nome": "Cavalo branco malhado", "venda": 0, "compra": 80, "pilha": 1, "qual": "incomum", "tipo_m": "montaria",
		"pelagem": "Horse_04", "desc": "Manso e elegante. Aumenta a velocidade em 60%."},
	"cavalo_marrom": {"nome": "Cavalo alazão", "venda": 0, "compra": 80, "pilha": 1, "qual": "incomum", "tipo_m": "montaria",
		"pelagem": "Horse_02", "desc": "Forte e incansável. Aumenta a velocidade em 60%."},
	"cavalo_dourado": {"nome": "Cavalo dourado", "venda": 0, "compra": 80, "pilha": 1, "qual": "incomum", "tipo_m": "montaria",
		"pelagem": "Horse_01", "desc": "Brilha como trigo ao sol. Aumenta a velocidade em 60%."},
	"cavalo_preto": {"nome": "Cavalo preto", "venda": 0, "compra": 80, "pilha": 1, "qual": "incomum", "tipo_m": "montaria",
		"pelagem": "Horse_06", "desc": "Veloz como a noite. Aumenta a velocidade em 60%."},
	"cavalo_baio": {"nome": "Cavalo baio de crina negra", "venda": 0, "compra": 120, "pilha": 1, "qual": "incomum", "tipo_m": "montaria",
		"pelagem": "Horse_03", "desc": "Criado nos pastos do vale. Aumenta a velocidade em 60%."},
	"cavalo_tordilho": {"nome": "Cavalo tordilho", "venda": 0, "compra": 120, "pilha": 1, "qual": "incomum", "tipo_m": "montaria",
		"pelagem": "Horse_05", "desc": "Cinza como a pedra da serra. Aumenta a velocidade em 60%."},
	"cavalo_pintado": {"nome": "Cavalo pintado", "venda": 0, "compra": 120, "pilha": 1, "qual": "incomum", "tipo_m": "montaria",
		"pelagem": "Horse_09", "desc": "Manchas brancas que nunca se repetem. Aumenta a velocidade em 60%."},
	"cavalo_guerra_baio": {"nome": "Corcel de guerra baio", "venda": 0, "compra": 400, "pilha": 1, "qual": "raro", "tipo_m": "montaria",
		"pelagem": "Horse_07", "desc": "Pintado para a batalha, não teme fogo nem aço. Aumenta a velocidade em 60%."},
	"cavalo_guerra_branco": {"nome": "Corcel de guerra branco", "venda": 0, "compra": 400, "pilha": 1, "qual": "raro", "tipo_m": "montaria",
		"pelagem": "Horse_08", "desc": "A marca vermelha dos cavaleiros de Altamar. Aumenta a velocidade em 60%."},
	"cavalo_guerra_cinza": {"nome": "Corcel de guerra cinzento", "venda": 0, "compra": 400, "pilha": 1, "qual": "raro", "tipo_m": "montaria",
		"pelagem": "Horse_10", "desc": "Cinza de cinzas, pintado com sangue. Aumenta a velocidade em 60%."},
	"unicornio": {"nome": "Unicórnio", "venda": 0, "compra": 2000, "pilha": 1, "qual": "raro", "tipo_m": "montaria",
		"pelagem": "Horse_Unicorn_01", "chifre": true, "desc": "Dizem que só aparece a quem tem o coração limpo. Aumenta a velocidade em 60%."},
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
	"pelo_lobo": {"nome": "Pelo de lobo", "venda": 14, "compra": 0, "pilha": 20, "qual": "lixo",
		"desc": "Um tufo de pelo grosso e quente. Os curtidores da vila sempre compram."},
	"veneno_aranha": {"nome": "Veneno de aranha-musgo", "venda": 18, "compra": 0, "pilha": 20, "qual": "lixo",
		"desc": "A bolsinha de veneno verde da aranha, ainda cheia. Não aperte."},
	"coroa_grao_lodoso": {"nome": "Coroa de Dentes do Grão-Lodoso", "venda": 160, "compra": 0, "pilha": 1, "qual": "incomum",
		"desc": "Uma coroa tosca de dentes de peixe gigante amarrados com alga. Os Lodosos se ajoelhavam diante dela."},
	"tridente_partido": {"nome": "Tridente Partido do Grão-Lodoso", "venda": 120, "compra": 0, "pilha": 1, "qual": "incomum",
		"desc": "As pontas de osso serrilhado do tridente do chefe, ainda sujas de lama. Os ferreiros de Altamar pagariam bem por elas."},
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

# ARMAS E ESCUDOS: os do pacote POLYGON Fantasy Kingdom (Synty). [id, modelo, nome, tipo, item level, qualidade,
# peso (golpe mais pesado = mais ataque; 0 = escudo), venda em cobre]. A força sai do item level (arma_por_ilvl /
# escudo_por_ilvl). Cada modelo existe em 3 níveis: o da tabela, "_2" (+6 ilvl) e "_3" (+12 ilvl), o mesmo modelo
# com o mesmo nome — só o item level (e a raridade) diz qual é o mais forte.
const ARMAS := [
	["esp_01", "SM_Wep_Sword_01", "Espada longa de cavaleiro", "Espada", 1, "comum", 2.2, 6],
	["esp_02", "SM_Wep_Sword_02", "Espada de soldado", "Espada", 2, "comum", 2.2, 12],
	["esp_03", "SM_Wep_Sword_03", "Espada de guarda", "Espada", 3, "comum", 2.2, 18],
	["esp_04", "SM_Wep_Sword_04", "Espada do capitão", "Espada", 3, "comum", 2.2, 18],
	["esp_05", "SM_Wep_Sword_05", "Lâmina larga", "Espada", 4, "comum", 2.2, 24],
	["esp_06", "SM_Wep_Sword_06", "Espada de patrulha", "Espada", 5, "comum", 2.2, 30],
	["esp_07", "SM_Wep_Sword_07", "Espada do juramento", "Espada", 6, "comum", 2.2, 36],
	["esp_08", "SM_Wep_Sword_08", "Espada lascada", "Espada", 7, "comum", 2.2, 42],
	["esp_09", "SM_Wep_Sword_09", "Espada de aprendiz", "Espada", 8, "incomum", 2.2, 72],
	["esp_10", "SM_Wep_Sword_10", "Espada de ferro forjado", "Espada", 8, "incomum", 2.2, 72],
	["esp_11", "SM_Wep_Sword_11", "Florete dourado", "Espada", 9, "incomum", 2.2, 81],
	["esp_12", "SM_Wep_Sword_12", "Florete de prata", "Espada", 10, "incomum", 2.2, 90],
	["esp_13", "SM_Wep_Sword_13", "Florete do duelista", "Espada", 11, "incomum", 2.2, 99],
	["esp_14", "SM_Wep_Sword_14", "Espada do falcão", "Espada", 12, "incomum", 2.2, 108],
	["esp_15", "SM_Wep_Sword_15", "Espada flamejante", "Espada", 13, "raro", 2.2, 156],
	["esp_16", "SM_Wep_Sword_16", "Espada do arauto real", "Espada", 13, "raro", 2.2, 156],
	["esp_17", "SM_Wep_Sword_17", "Espada do caos", "Espada", 14, "raro", 2.2, 168],
	["esp_18", "SM_Wep_Sword_18", "Espada sangrenta", "Espada", 15, "raro", 2.2, 180],
	["mch_01", "SM_Wep_Axe_01", "Machadinha de lenhador", "Machado", 1, "comum", 2.6, 6],
	["mch_02", "SM_Wep_Axe_02", "Machado de mão", "Machado", 2, "comum", 2.6, 12],
	["mch_03", "SM_Wep_Axe_03", "Machado de guerra", "Machado", 4, "comum", 2.6, 24],
	["mch_04", "SM_Wep_Axe_04", "Machado barbado", "Machado", 5, "comum", 2.6, 30],
	["mch_05", "SM_Wep_Axe_05", "Machado do norte", "Machado", 7, "comum", 2.6, 42],
	["mch_06", "SM_Wep_Axe_06", "Machado de lâmina dupla", "Machado", 8, "incomum", 2.6, 72],
	["mch_07", "SM_Wep_Axe_07", "Machado do carrasco", "Machado", 9, "incomum", 2.6, 81],
	["mch_08", "SM_Wep_Axe_08", "Machado de cerco", "Machado", 11, "incomum", 2.6, 99],
	["mch_09", "SM_Wep_Axe_09", "Machado do lobo", "Machado", 12, "raro", 2.6, 144],
	["mch_10", "SM_Wep_Axe_10", "Machado de bronze", "Machado", 14, "raro", 2.6, 168],
	["mch_11", "SM_Wep_Axe_11", "Machado do senhor da guerra", "Machado", 15, "raro", 2.6, 180],
	["mac_01", "SM_Wep_Mace_01", "Maça de ferro cravejada", "Maça", 1, "comum", 2.6, 6],
	["mac_02", "SM_Wep_Mace_02", "Maça do sacerdote", "Maça", 4, "comum", 2.6, 24],
	["mac_03", "SM_Wep_Mace_03", "Clava cravejada", "Maça", 7, "comum", 2.6, 42],
	["mac_04", "SM_Wep_Mace_04", "Maça de flanges", "Maça", 9, "incomum", 2.6, 81],
	["mac_05", "SM_Wep_Mace_05", "Maça de guerra", "Maça", 12, "raro", 2.6, 144],
	["mac_06", "SM_Wep_Mace_06", "Clava de madeira", "Maça", 15, "raro", 2.6, 180],
	["mar_01", "SM_Wep_Hammer_01", "Martelo de forja", "Martelo", 1, "comum", 3.0, 6],
	["mar_02", "SM_Wep_Hammer_02", "Martelo de guerra", "Martelo", 4, "comum", 3.0, 24],
	["mar_03", "SM_Wep_Hammer_03", "Martelo do pedreiro", "Martelo", 7, "comum", 3.0, 42],
	["mar_04", "SM_Wep_Hammer_04", "Martelo de bico", "Martelo", 9, "incomum", 3.0, 81],
	["mar_05", "SM_Wep_Hammer_05", "Martelo do cruzado", "Martelo", 12, "raro", 3.0, 144],
	["mar_06", "SM_Wep_Hammer_06", "Martelo do trovão", "Martelo", 15, "raro", 3.0, 180],
	["lan_01", "SM_Wep_Spear_01", "Lança de caça", "Lança", 1, "comum", 2.8, 6],
	["lan_02", "SM_Wep_Spear_02", "Lança de guarda", "Lança", 2, "comum", 2.8, 12],
	["lan_03", "SM_Wep_Spear_03", "Lança de infantaria", "Lança", 4, "comum", 2.8, 24],
	["lan_04", "SM_Wep_Spear_04", "Pique", "Lança", 5, "comum", 2.8, 30],
	["lan_05", "SM_Wep_Spear_05", "Lança de ponta larga", "Lança", 6, "comum", 2.8, 36],
	["lan_06", "SM_Wep_Spear_06", "Lança do batedor", "Lança", 7, "incomum", 2.8, 63],
	["lan_07", "SM_Wep_Spear_07", "Lança de cavalaria", "Lança", 9, "incomum", 2.8, 81],
	["lan_08", "SM_Wep_Spear_08", "Lança farpada", "Lança", 10, "incomum", 2.8, 90],
	["lan_09", "SM_Wep_Spear_09", "Alabarda", "Lança", 11, "incomum", 2.8, 99],
	["lan_10", "SM_Wep_Spear_10", "Lança da sentinela", "Lança", 12, "raro", 2.8, 144],
	["lan_11", "SM_Wep_Spear_11", "Lança da guarda real", "Lança", 14, "raro", 2.8, 168],
	["lan_12", "SM_Wep_Spear_12", "Lança do capitão", "Lança", 15, "raro", 2.8, 180],
	["caj_01", "SM_Wep_Staff_01", "Cajado de carvalho", "Cajado", 1, "comum", 2.8, 6],
	["caj_02", "SM_Wep_Staff_02", "Cajado do peregrino", "Cajado", 3, "comum", 2.8, 18],
	["caj_03", "SM_Wep_Staff_03", "Cajado do eremita", "Cajado", 4, "comum", 2.8, 24],
	["caj_04", "SM_Wep_Staff_04", "Cajado retorcido", "Cajado", 6, "comum", 2.8, 36],
	["caj_05", "SM_Wep_Staff_05", "Cajado do druida", "Cajado", 7, "comum", 2.8, 42],
	["caj_06", "SM_Wep_Staff_06", "Cajado do sábio", "Cajado", 9, "incomum", 2.8, 81],
	["caj_07", "SM_Wep_Staff_07", "Cajado de cristal", "Cajado", 10, "incomum", 2.8, 90],
	["caj_08", "SM_Wep_Staff_08", "Cajado do mago", "Cajado", 12, "incomum", 2.8, 108],
	["caj_09", "SM_Wep_Staff_09", "Cajado da lua", "Cajado", 13, "raro", 2.8, 156],
	["caj_10", "SM_Wep_Staff_10", "Cajado do arquimago", "Cajado", 15, "raro", 2.8, 180],
	["cet_01", "SM_Wep_Sceptre_01", "Cetro de bronze", "Cetro", 1, "comum", 2.2, 6],
	["cet_02", "SM_Wep_Sceptre_02", "Cetro do bispo", "Cetro", 3, "comum", 2.2, 18],
	["cet_03", "SM_Wep_Sceptre_03", "Cetro do conselheiro", "Cetro", 5, "comum", 2.2, 30],
	["cet_04", "SM_Wep_Sceptre_04", "Cetro de prata", "Cetro", 6, "comum", 2.2, 36],
	["cet_05", "SM_Wep_Sceptre_05", "Cetro do sol", "Cetro", 8, "incomum", 2.2, 72],
	["cet_06", "SM_Wep_Sceptre_06", "Cetro da rainha", "Cetro", 10, "incomum", 2.2, 90],
	["cet_07", "SM_Wep_Sceptre_07", "Cetro do rei", "Cetro", 11, "incomum", 2.2, 99],
	["cet_08", "SM_Wep_Sceptre_08", "Cetro estrelado", "Cetro", 13, "raro", 2.2, 156],
	["cet_09", "SM_Wep_Sceptre_09", "Cetro dourado", "Cetro", 15, "raro", 2.2, 180],
	["ada_01", "SM_Wep_Dagger_01", "Adaga de ferro", "Adaga", 1, "comum", 1.6, 6],
	["ada_02", "SM_Wep_Dagger_02", "Adaga do ladrão", "Adaga", 3, "comum", 1.6, 18],
	["ada_03", "SM_Wep_Dagger_03", "Adaga curva", "Adaga", 6, "comum", 1.6, 36],
	["ada_04", "SM_Wep_Dagger_04", "Adaga de lâmina fina", "Adaga", 8, "incomum", 1.6, 72],
	["ada_05", "SM_Wep_Dagger_05", "Adaga do assassino", "Adaga", 10, "incomum", 1.6, 90],
	["ada_06", "SM_Wep_Dagger_06", "Adaga cerimonial", "Adaga", 13, "raro", 1.6, 156],
	["ada_07", "SM_Wep_Dagger_07", "Adaga do nobre", "Adaga", 15, "raro", 1.6, 180],
	["fac_01", "SM_Wep_Knife_01", "Faca de cozinha", "Faca", 1, "comum", 1.5, 6],
	["fac_02", "SM_Wep_Knife_02", "Faca de esfolar", "Faca", 6, "comum", 1.5, 36],
	["fac_03", "SM_Wep_Knife_03", "Faca de caçador", "Faca", 10, "incomum", 1.5, 90],
	["fac_04", "SM_Wep_Knife_04", "Faca de açougueiro", "Faca", 15, "raro", 1.5, 180],
	["esc_01", "SM_Wep_Shield_01", "Escudo da cruz", "Escudo", 7, "incomum", 0.0, 63],
	["esc_02", "SM_Wep_Shield_02", "Escudo heráldico", "Escudo", 10, "incomum", 0.0, 90],
	["esc_03", "SM_Wep_Shield_03", "Escudo do cristal", "Escudo", 9, "incomum", 0.0, 81],
	["esc_04", "SM_Wep_Shield_04", "Escudo de aço da águia", "Escudo", 13, "raro", 0.0, 156],
	["esc_05", "SM_Wep_Shield_05", "Escudo de tábuas", "Escudo", 1, "comum", 0.0, 6],
	["esc_06", "SM_Wep_Shield_06", "Escudo redondo de madeira", "Escudo", 3, "comum", 0.0, 18],
	["esc_07", "SM_Wep_Shield_07", "Escudo redondo reforçado", "Escudo", 4, "comum", 0.0, 24],
	["esc_08", "SM_Wep_Shield_08", "Escudo de cravos", "Escudo", 11, "incomum", 0.0, 99],
	["esc_09", "SM_Wep_Shield_09", "Escudo de pedra", "Escudo", 15, "raro", 0.0, 180],
	["esc_10", "SM_Wep_Shield_10", "Escudo tribal de couro", "Escudo", 5, "comum", 0.0, 30],
]
const DESC_ARMA := {"Espada": "Aço bom de Altamar, equilibrado na mão.", "Machado": "Pesado na ponta: cada golpe racha escudo.",
	"Maça": "Cabeça de ferro que amassa elmo e osso.", "Martelo": "Lento, mas um golpe só derruba um homem de pé.",
	"Lança": "Mantém o inimigo longe da ponta.", "Cajado": "Madeira antiga que os magos dizem ouvir.",
	"Cetro": "Símbolo de poder, e ainda assim um bom porrete.", "Adaga": "Rápida e silenciosa.", "Faca": "Feita para o trabalho, serve para a briga.",
	"Escudo": "Madeira e ferro entre você e a morte."}
# itens antigos (modelos do Tripo) → os do pacote, para os saves que já existiam
const MIGRAR := {"espada_treino": "esp_09", "espada_ferro": "esp_10", "malho_tronco": "mac_01", "marreta_bigorna": "mar_01",
	"cutelo_rochedo": "mch_07", "presa_da_mare": "esp_15", "escudo_madeira": "esc_05", "escudo_ferro": "esc_07", "egide_guardia": "esc_01"}
const NIVEIS_ARMA := [[0, ""], [6, "_2"], [12, "_3"]]        # [ilvl a mais, final do id]
static var ITENS := _montar_itens()
static func _montar_itens() -> Dictionary:
	var d := ITENS_BASE.duplicate(true)
	for a in ARMAS:
		for nv in NIVEIS_ARMA:
			var id: String = a[0] + nv[1]; var ilvl: int = a[4] + nv[0]; var q: String = a[5]; var peso: float = a[6]
			var venda: int = a[7]
			for i in NIVEIS_ARMA.find(nv): q = QUAL_SOBE[q]
			venda = roundi(venda * float(ilvl + 2) / float(a[4] + 2) * (1.0 + 0.6 * NIVEIS_ARMA.find(nv)))
			if a[0] == "esp_09" and nv[0] == 0: ilvl = 1; q = "comum"; venda = 3      # a espada da heroína no começo
			var it := {"nome": a[2], "venda": venda, "compra": venda * 4, "pilha": 1, "qual": q, "subtipo": a[3], "ilvl": ilvl,
				"modelo": a[1], "desc": DESC_ARMA.get(a[3], "")}
			if a[3] == "Escudo":
				it.merge(escudo_por_ilvl(ilvl, q, id.hash())); it["tipo"] = "escudo"; it["bloqueio_ativo"] = 0.6 + 0.01 * ilvl
			else:
				it.merge(arma_por_ilvl(ilvl, q, peso, a[3], id.hash())); it["tipo"] = "arma"; it["maos"] = "Uma mão"
			d[id] = it
	return d
# arma ou escudo sorteado para o saque de um bicho desse nível (item level entre nível − 2 e nível + 4)
static func arma_aleatoria(nivel: int) -> String:
	var ok := []
	for id in ITENS.keys():
		var it: Dictionary = ITENS[id]
		if it.has("subtipo") and id != "esp_09" and int(it.ilvl) >= nivel - 2 and int(it.ilvl) <= nivel + 4: ok.append(id)
	return "" if ok.is_empty() else ok[randi() % ok.size()]
static func migrar(id: String) -> String: return MIGRAR.get(id, id)

static var ARQUIVO: String:                    # save do herói escolhido na seleção
	get: return Herois.arquivo()
signal mudou
var bolsas := []                  # [{id, slots: [null ou [id, qtd]]}, ou null] — 3 lugares
var cobre := 0
var recompra := []                # últimos vendidos: [id, qtd, preço total]
var equip := {"arma": "esp_09", "escudo": "esc_05"}
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
	for k in ["arma", "escudo"]: if ITENS.has(migrar(String(eq.get(k, "")))): equip[k] = migrar(String(eq[k]))
	if d.has("bolsas"):
		var bs: Array = d.bolsas
		for k in MAX_BOLSAS:
			bolsas[k] = null
			if k < bs.size() and bs[k] is Dictionary and ITENS.has(bs[k].get("id", "")):
				var nb := _bolsa_nova(bs[k].id)
				var ss: Array = bs[k].get("slots", [])
				for i in mini(ss.size(), nb.slots.size()):
					if ss[i] is Array and ITENS.has(migrar(String(ss[i][0]))): nb.slots[i] = [migrar(String(ss[i][0])), int(ss[i][1])]
				bolsas[k] = nb
		if bolsas[0] == null and bolsas[1] == null and bolsas[2] == null: bolsas[0] = _bolsa_nova("bolsa_10")
	elif d.has("itens"):                                  # progresso antigo (antes das bolsas)
		var it: Dictionary = d.itens
		for k in it.keys(): if ITENS.has(k): pegar(k, int(it[k]))
	return d

# Dallarian — Mapa novo (recriado do zero)

Pedido do dono: recriar TODO o mapa do zero, esquecendo o antigo; mudar a cidade e o vilarejo de lugar, mudar as
estradas; mapa dinâmico (relevo forte, áreas altas e baixas, muitos lugares para explorar, mundo com vida e
paisagens variadas). Usar SÓ peças do pacote POLYGON Fantasy Kingdom (repositório privado `dallarian-arte`).
Personagens (heróis, moradores, cavalos, monstros) continuam os mesmos. Sistemas que continuam: lojas, estábulo e
montarias, moradores, freiras (poções), ferreiro, estátuas da Guardiã (renascer), monstros, bússola, saque.

Tamanho igual: x de -1200 a 2600 (oeste → leste), z de -1200 a 1200 (norte → sul). O mar fica a leste.

## Regiões
| Região | Onde | Cara |
|---|---|---|
| Montanhas do Norte | z < -850 | serra alta com neve; pinheiral no sopé; mina |
| Planalto do Oeste (Bosque Sombrio) | x < -400 | 25 m mais alto, floresta fechada, lobos e aranhas, lago |
| Colinas do Centro | meio do mapa | morros, cristas, platôs com paredões; campos floridos nos vales |
| Vale do Rio | ao longo do rio | campos de trigo, fazendas, moinho |
| Pântano do Sul | z > 750 | baixo, alagado, árvores secas, Lodosos |
| Costa Leste | x > 2150 | praia, rochedos, porto de Altamar |

## Lugares principais (coordenadas aproximadas)
- **Vila do Vale** — centro (250, 420), num vale ao sul do centro, na beira do rio. Vila de estrada: rua principal
  leste–oeste com casas dos dois lados, praça com poço, taverna, ferraria, igreja pequena, moinho, campos ao redor.
- **Altamar (capital)** — retângulo x 1650–2200, z -200–350, na costa leste, em DEGRAUS:
  - nível do porto (≈3 m) a leste, com cais entrando no mar;
  - nível do mercado (≈10 m) no meio, com a praça do mercado;
  - nível alto (≈18 m) a oeste, com a catedral e os nobres;
  - castelo no topo de um morro no canto noroeste (≈30 m).
  - Portão Oeste com ponte e estátuas; avenida reta do portão até a praça; escadarias/rampas entre os níveis.
- **Estábulo** — fora do Portão Oeste (1570, 60).
- **Rio** — nasce no norte (650, -1150), desce pelo meio do mapa, passa a leste da vila e deságua no mar ao sul de
  Altamar (≈2250, 800).
- **Lago** — no Planalto do Oeste (-700, -300).

## Estradas
- Estrada Real: Vila → nordeste → ponte do rio → leste pelos vales → Portão Oeste de Altamar.
- Estrada do Norte: Vila → norte pelas colinas → mina nas montanhas.
- Estrada do Oeste: Vila → rampa do planalto → Bosque Sombrio e lago.
- Estrada do Sul: Vila → pântano.

## Ordem de trabalho
1. Geografia nova (regiao.gd): relevo, rio, lago, estradas, campos, cidade e vila nos lugares novos.
2. Altamar do zero (em degraus) com peças do pacote.
3. Vila nova.
4. Religar sistemas: lojas, estábulo, ferreiro, freiras, estátuas, moradores, monstros, bússola.
5. Paisagens por região, lugares para explorar, vida (viajantes, carroças, patrulhas, animais).

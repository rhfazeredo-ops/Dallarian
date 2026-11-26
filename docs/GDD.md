# Dallarian — Documento do jogo (GDD)

> **Rachel** é a heroína. **Dallarian** é o continente (e o nome do jogo).

> Documento vivo: cresce conforme o dono for contando a história. O que está marcado como **(proposta)**
> é sugestão do Claude, ainda não decidida.

## 1. Em uma frase
Um humano comum tenta se tornar cavaleiro, e herói, num mundo medieval fantasioso caótico, cheio de raças,
monstros, política e traição, onde ainda existem amor, amizade e gente boa pelo caminho.

## 2. Gênero e formato
- **3D, primeira pessoa, mundo aberto de exploração.**
- **Uma personagem só:** Rachel. A jogadora é ela o jogo inteiro.
- **Dallarian** é o nome do continente onde tudo acontece — e o nome do jogo.
- **Plataforma principal: celular** (Android); também no navegador. Tudo pensado para rodar leve.
- Motor: **Godot 4.5** (renderizador Compatibility).

## 3. A protagonista: Rachel
- **Humano.** Não tem sangue nobre, magia nem destino escrito. Quer ser cavaleiro, tenta ser herói.
- Começa fraco e inexperiente; cresce pelo que vive, aprende e escolhe.
- Tema central: **o que faz alguém ser herói num mundo onde quase ninguém é?**
- (proposta) Começa como escudeiro, ajudante ou aspirante e precisa provar seu valor para ser sagrado cavaleiro.

## 4. O mundo
- **Medieval fantasioso e caótico.**
- **Muitas raças diferentes** convivendo e brigando. Humanos não estão no topo.
- **Monstros** nas estradas, nas florestas, nas ruínas.
- **Política e traição:** reinos, casas nobres, ordens de cavalaria, guildas e cultos disputando poder.
  Alianças mudam; quem ajuda hoje pode trair amanhã.
- **Mas ainda há luz:** vilas onde as pessoas se ajudam, amizades verdadeiras, amor, famílias, tavernas cheias.
- **Vida social:** tramas entre os moradores (romances, rivalidades, dívidas, segredos) que o jogador
  descobre e nas quais pode se envolver.
- (a definir) Nome do mundo, reinos, raças, a grande ameaça/conflito, a história de fundo.

## 5. Tom
Épico e melancólico, sem perder o calor humano. Mundo duro, histórias pessoais. Escolhas com consequência.

## 6. O que o jogador faz (pilares)
1. **Explorar** um mundo aberto: estradas, vilas, florestas, montanhas, ruínas.
2. **Conviver:** conversar, ajudar ou atrapalhar as pessoas, entrar nas tramas sociais.
3. **Lutar:** espada e escudo, em primeira pessoa, contra monstros e gente.
4. **Crescer:** de aspirante a cavaleiro, por feitos, treino, equipamentos e reputação.
5. (proposta) **Escolher lados** na política, com consequências nas cidades e nas pessoas.

## 6.1 História principal e favores
- **História principal:** a jornada de Rachel para se tornar herói/cavaleiro, em capítulos pelo mundo.
- **Favores (missões extras):** as pessoas pedem ajuda no caminho: buscar algo, entregar uma carta, resolver
  uma briga, proteger alguém, achar um animal perdido, enfrentar um monstro que ronda a vila...
  Pequenos, humanos, ligados à vida de cada lugar.
- **O mundo comenta o sonho dele:** os moradores falam sobre o que ele quer ser.
  - Uns **zombam** ("um camponês querendo ser cavaleiro?"), outros **apoiam** e incentivam,
    alguns desconfiam, alguns se inspiram nele.
  - (proposta) As falas mudam com a **reputação** de Rachel: quanto mais favores e feitos, mais gente
    respeita; falhar, fugir ou trair faz a zombaria e a desconfiança voltarem.
  - (proposta) Comentários soltos ao passar perto das pessoas (sem precisar abrir conversa), como num mundo vivo.

## 7. Direção de arte
- **3D com cara de PlayStation 1, mas com estilo pintado:** poucos polígonos, texturas pequenas e
  pixeladas (sem suavização), vértices que "tremem", neblina na distância, resolução baixa, pontilhado.
- **Pixel splats** (Gaussian splats em estilo pixel art) para o que é "fofo": grama, folhas, copas de árvores,
  nuvens, neblina, fumaça, magia.
- **Filtro geral** que une tudo: paleta reduzida (~32 cores), sombras em blocos, pixels grandes.
- Referência de clima: vale com vila, campos dourados, pinheiros, céu de tempestade, poças refletindo o céu.
- Orçamento (triângulos): objetos 300–800 · casas 800–2.000 · personagens 1.000–2.500 ·
  texturas 128–256 px.
- Arte: ChatGPT (folhas com 4 vistas) → Tripo 3D (Multiview, Low Poly, GLB) → redução no projeto.
- Heróis jogáveis: mulher = a Cavaleira loira (SM_Chr_Rider_01) e homem = o Príncipe (SM_Chr_Prince_01), do pacote
  **POLYGON Fantasy Kingdom** (escolhidos pelo dono num catálogo com os 142 personagens dos pacotes), com as animações Sword and Shield (combate) e Base Locomotion (fora de combate) convertidas para o esqueleto deles.

## 7.1 A região inicial: Vale de Aldren (feita)
Primeiro mapa do continente de Dallarian; os próximos mapas se conectam a ele (saída do desfiladeiro do norte).

Região **retangular de 3,8 × 2,4 km** (formato de zona de MMO, mais larga que alta) com limites naturais, em `godot/scripts/regiao.gd`:
- **Limites:** montanhas ao norte (com um desfiladeiro fechado por uma paliçada — saída futura) e a oeste,
  mar a leste, pântano e morros escuros ao sul.
- **Rio em "S"** do norte ao pântano, com três pontes; **lago** com um **mosteiro numa ilha** (passarela).
- **Vila** no centro: rua principal norte-sul com casas dos dois lados (taverna no sul, igreja com torre no
  norte), praça do poço no cruzamento, ferraria; trilhas para um sítio a oeste (com horta), casas e horta a
  leste, a casa do pescador com píer no rio e uma casa afastada ao norte.
- **Fazendas** a oeste (campos de trigo e terra arada, cercas, celeiros vermelhos, moinho de vento).
- **Porto** de pescadores no litoral leste (píer, barcos), **ruínas** de uma torre num morro (nordeste),
  **serraria**, **acampamento de bandidos** (sudoeste), **caverna** no pé das montanhas a oeste.
- Floresta de carvalhos, bétulas e pinheiros (algumas copas de outono), árvores mortas no pântano.
- **Postes com lanterna** na rua principal e na praça (acendem de noite).
- **Acampamentos**: 5 barracas com fogueira, isoladas, longe da vila e umas das outras (ícone de tenda na bússola).
  Perto da barraca aparece **DESCANSAR**: a tela escurece e Rachel dorme até as 6h.
- **Moradores**: homens e mulheres de vários corpos (gorda, forte/alto, idosos que andam devagar) e duas crianças
  brincando de pega-pega perto da praça.

- **Vento** leve com rajadas: grama e árvores balançam mais, folhinhas voam, som de vento (mais forte na chuva).
- **Relógio** embaixo da bússola (sol de dia, lua de noite).
- **Beiradas da água:** ondas com espuma chegando na praia do mar, correnteza nas margens do rio, marolinhas no lago e na ilha.
- **Chuva:** de vez em quando (tempo bom 4–9 min, chuva 2–4 min): céu fecha, luz cinza-azulada, gotas e som de chuva.

## 7.1.1b Vida no mundo
- **Peixes** no rio e no lago (silhuetas escuras embaixo d'água): um grande e lento sozinho, ou cardumes de 4 a 6
  pequenos e rápidos que dão arrancadas (às vezes um pequeno sozinho).
- **Vegetação extra:** arbustos verdes, com flores brancas/amarelas, lilás ou frutinhas vermelhas (no campo, na
  beira da mata e nos jardins das casas), samambaias dentro da mata e **taboas/juncos** em touceiras na beira do
  rio, do lago e da ilha.
- **Pássaros** grandes voando alto (26–40 m), sozinhos, em dupla ou em trio em V; batem as asas e planam.

## 7.1.2 Inimigos: lobos
- Grupos de **no máximo 3 lobos** (2–3, com líder preto) + **14 grupinhos de 3 lobos marrons de nível 1–2** nas matas perto da vila (~130 lobos); correm 5,2 m/s (a Rachel corre 7,2): **líder preto** (maior, 6 de vida, morde mais forte), **brancos só
  nas montanhas/morros** e **marrons só nas florestas**; longe da vila, das estradas e dos acampamentos.
- Passeiam e farejam perto da toca; viram a Rachel a 20 m e a matilha toda caça. Cercam em roda (5,5 m, com espaço
  entre eles), só **um ataca de cada vez** e a matilha respira 1–2 s entre ataques. Desistem se ela se afastar.
- **Rosnam**: rosnado longo quando a matilha vê a Rachel, curtos ao atacar (líder mais grave).
- **Morte:** tranco para trás, as patas cedem (as da frente primeiro), deita e tomba devagar de lado.
- Em **fúria**: depois de morder ou apanhar não foge — fica colado na Rachel atacando (até 2 ao mesmo tempo).
- Animações: **correr** (trote/galope), **atacar** (agacha, salta e morde) e **esquivar** (pulo para o lado — quando
  a Rachel começa um golpe na frente deles, ou depois de morder).
- Escudo levantado de frente bloqueia a mordida. Lobo comum cai com 3 golpes leves (o forte vale 2); dá XP
  (15, líder 40). Vida da Rachel zerada: desmaia e acorda na vila.

- **Altamar**, a capital (canto leste, entre as montanhas e o mar), feita só com peças do POLYGON Fantasy Kingdom.
  Planta em **grade de ruas retas** (docs: regiao.gd RUAS): a **Avenida Real** vai do Portão Oeste à **ilha da
  catedral** (canal em anel, quatro pontes de pedra em arco), segue como **Rua do Porto** até o cais. Cada rua tem a
  **pista de pedrinhas** no meio (cavalos e carroças, no futuro) e **calçadas de lajotas** mais altas dos dois lados,
  com meio-fio; o povo anda só pelas calçadas. Casas **coladas umas nas outras** com a porta para a calçada e o miolo
  dos quarteirões cheio de casas de fundos. **Praça do mercado** retangular ao sul da ilha: chafariz, oito barracas
  com vendedores (LOJA e CONVERSAR; mercadoria em breve), lojas com placa dos dois lados (armas, armaduras, alquimia,
  alfaiate, joalheiro) e a **Taverna O Javali Dourado** (entra; o taverneiro Bartolomeu vende poções). Rua das Lojas
  ao sul (banco, estalagem, ferraria). **Catedral** virada para a avenida, com coro no mezanino e escada de pedra.
  Fortaleza no morro a noroeste (Rua do Castelo sobe até ela), torres dos magos a sudoeste, praça da justiça e jardim
  dos nobres ao norte, porto a leste.
- **A vila** também é redonda: casas em dois anéis em volta da praça do poço, viradas para o centro.

## 7.1.1 Dia e noite
- Relógio do jogo: 1 hora = 1 minuto real (o dia inteiro dura 24 min); começa às 9h.
- Pôr do sol alaranjado (17h30–20h30), noite azul-escura com estrelas e lua, lanternas e fogueiras iluminando
  em volta; amanhecer das 4h30 às 7h.
- Equipamento inicial da Rachel: **espada e escudo de madeira**.

## 7.1.2b Outros monstros
- **Aranha-musgo** (nível 3–5): uma só por lugar, 14 na mata fechada, longe umas das outras. Anda, corre rasteira,
  pica (30% de chance de envenenar: dano verde por alguns segundos), dá um bote de 5–7 m. Morre virando de barriga
  para cima. Drop: presa de aranha-musgo (40%).
- **Lodosos** (peixe-sapo, modelos do Tripo): 70 grupos de até 3 na praia, nos rios e no lago, cada um com
  acampamento (cabanas de palafita, varal, rede, tralhas, fogueira). Tipos: Jovem (lança, nível 2–4), Pescador
  (lança, 3–5), Xamã da Lama (cajado, 3–5) e o chefe Grão-Lodoso **Glorgo, o Rei da Lama** (tridente, nível 10) no fundo da Gruta dos Lodosos.
  Drops: escama 50%, barbatana 35%, olho 20%; Xamã: Pérola da Lama 12%; chefe: escamas, olhos e pérola 50%.
- **Chefe: Grumo, o Guardião do Vale** (golem de terra, 9 m — do tamanho das árvores, nível 8): dá a volta no mapa inteiro, longe da vila,
  sem parar; o chão treme perto dele. Soco e PANCADA com as duas mãos no chão (dano em área de 9 m, mais forte
  perto). Barra verde do golpe em cima da cabeça (enche até o instante do golpe) e barra de vida grande no alto da tela.
  Drops: Coração de barro do Grumo (sempre), dinheiro, chance de espada de ferro e bolsa de 16.
- **Na bússola:** o Grumo é a única criatura que aparece nela, em vermelho, quando a Rachel está a até 160 m (pulsa mais
  rápido quanto mais perto; fora da vista fica preso na ponta da bússola).
- **Renascer:** monstros normais voltam 5 min depois de morrer, no mesmo lugar (esperam a Rachel se afastar 45 m);
  o Grumo volta 1 hora depois, no ponto da volta mais longe da Rachel.

## 7.1.3 Progresso, dinheiro e loja
- **Níveis 1 a 30** (máximo por enquanto) com a **tabela de XP do WoW Classic** (400, 900, 1.400, 2.100… 44.300;
  499 mil no total). Cada nível dá +8 de vida e +5 de mana e enche as duas.
- XP por matar como no Classic: 45 + 5×nível do bicho, +5% por nível acima (até +4), menos se for mais fraco
  e nada se for "cinza". Lobos marrons nível 2–3, brancos 4–6, líder preto um nível acima. Descobrir local: 40 + 20×nível. Avisos curtos no lado esquerdo (+XP, itens, dinheiro).
- **Dinheiro:** ouro, prata e cobre (100 cobre = 1 prata, 100 prata = 1 ouro). Itens fracos do começo valem cobre.
- Lobo morto deixa **dentes e garras de lobo** em ~40% das vezes (líder: 1 ou 2) — vende por 12 cobre cada.
- **Ferreiro:** botões CRIAR (em breve), LOJA (vende itens: 1 ou todos) e CONVERSAR.
- **Inventário estilo WoW:** até **3 bolsas** equipadas (10 a 50 espaços); começa com uma de 10. Itens em pilhas
  (dentes e garras: 20 por espaço). Bolsas empilhadas no canto direito, barra com os 3 lugares de bolsa e o
  dinheiro; tocar num item mostra a dica (nome na cor da qualidade, descrição, preço) com EQUIPAR/VENDER.
- **Vendedor estilo WoW:** retrato e nome, mercadorias em 2 colunas (10 por página), abas COMPRAR e RECOMPRAR;
  vender = tocar no item da bolsa e em VENDER (pilha toda). O Bram vende bolsas de 10, 16, 20 e 30 espaços;
  as de 40 e 50 ficam para mercadores de cidade.
- O progresso (nível, XP, dinheiro, itens) fica salvo no aparelho.

## 7.1.4 Itens e combate (estilo WoW Classic)
- **Armas:** dano mín–máx, velocidade e dano por segundo. Espada de treino de madeira 2–4 (vel. 1,80; 1,7 DPS);
  Espada de ferro 6–11 (vel. 2,20; 3,9 DPS; requer nível 3; o Bram vende por 1 prata e 50 cobre).
- **Golpe:** dano da arma + bônus de força (4 + nível); golpe forte ×1,6; 5% de crítico (dobro, número amarelo).
- **Escudo de madeira:** 30 de armadura (redução Classic: armadura / (armadura + 400 + 85×nível do atacante) — uns 5%
  contra lobos de nível 2), 5 de bloqueio; só equipado tem 5% de chance de bloquear sozinho (tira 5 do dano).
  Segurando o escudo de frente: o 1º ataque depois de levantar é bloqueado inteiro; os seguintes perdem 60% + 5.
- **Lobos:** vida 30 + 12×nível (líder +15%); mordida (2 + 1,5×nível) a (4 + 2×nível).
- Números de combate sobem dos bichos (branco; crítico amarelo) e o dano levado aparece em vermelho no meio.
- Inventário: arma e escudo equipados na barra de baixo; dica com os status e EQUIPAR (troca com o equipado).

- **Travar a mira** (Tab no PC / botão de alvo no celular): a câmera segue o inimigo mais perto na frente, com um marcador
  vermelho e a vida dele em cima; andar para o lado faz a Rachel dar a volta nele. Apertar de novo (ou o alvo morrer /
  ficar a mais de 40 m) solta. Um X discreto no meio da tela mostra onde a espada bate.
- **Nenhum monstro na água:** nascem e renascem só em terra seca e não entram em rio, lago, canal, fosso ou mar.

## 7.1.5 Rio do leste, estábulo e montarias
- **Rio do leste:** nasce no alto das montanhas do norte, desce passando em frente ao portão oeste de Altamar,
  faz curvas pelo sul e deságua no mar. Para entrar na cidade pelo oeste é preciso atravessar a **Ponte dos Guardiões**.
- Logo depois do portão oeste fica a **taverna** (placa da caneca). O **estábulo** fica do lado de fora da cidade,
  do outro lado do rio, perto da estrada que chega na ponte: a casinha do cavalariço, o telheiro com cocheiras do
  lado e o cercado com quatro cavalos (branco malhado, alazão, preto e dourado). **Edric, o cavalariço**, fica parado na frente da casa.
- Edric tem LOJA e CONVERSAR. Cada cavalo custa 80 cobre e aumenta a velocidade em 60%.
- **Montarias como no WoW:** o cavalo comprado vai para a **bolsa**; **dois toques** nele viram montaria e aparece o
  recado "MONTARIA ADQUIRIDA" com o nome. No **menu do personagem** (botão ao lado do mapa; PC: tecla C), aba
  MONTARIAS, aperta-se **EQUIPAR** na montaria. O **botão do cavalo** (perto do escudo; PC: tecla V) mostra a barra
  "Montando..." de 1,5 s (andar ou atacar cancela) e a Rachel aparece já montada; apertar de novo desmonta.
  Atacar também desmonta. Cavalos modelados no Tripo, com rig automático: as patas andam em trote, o pescoço balança e o rabo mexe.
- Os dois rios têm juncos nas margens e peixes nadando.

## 7.1.6 Coleta: frutinhas silvestres
- Os arbustos com pontinhos vermelhos dão **frutinhas**: chegando perto aparece **COLETAR** (PC: F) e vêm 1 a 3
  **Frutinhas silvestres** para a bolsa (pilha de 20, vendem por 1 cobre). O arbusto fica sem frutinhas e elas
  voltam em 5 minutos.
- Na bolsa, tocar nas frutinhas mostra **CONSUMIR**: cada uma recupera **5 de vida** (para uma emergência).
- **Árvores frutíferas** (copa com frutinhas vermelhas e laranja), planejadas por região: soltas no vale e na beira
  da mata, pomares perto das fazendas e em volta da vila; nenhuma na montanha, no pântano ou na mata fechada.
  Também têm COLETAR. Arbustos de frutinha em todo o mapa, mais comuns na beira das matas.

## 7.1.7 Freiras e poções de vida
- **Irmã Celina** fica na frente da igreja da vila e **Irmã Odília** na escadaria da catedral de Altamar, com LOJA e
  CONVERSAR (diálogos de freira). Modelo do Tripo, parada orando com as mãos juntas.
- Vendem 3 poções (pilha de 10): **pequena** cura 10% da vida (20 cobre), **média** 20% (75 cobre), **grande** 30%
  (1 prata e 50 cobre). Na bolsa: CONSUMIR.

## 7.1.9 Morte e Estátuas da Guardiã
- Vida zerou: a câmera tomba de lado até o chão (como a Rachel caindo), a tela fica vermelha e aparece
  **VOCÊ MORREU**. Depois escurece e ela desperta **de frente para a Estátua da Guardiã** mais perto de onde caiu,
  com a vida cheia. Os monstros perdem o interesse.
- 12 estátuas (modelo do Tripo, chama azul acesa à noite): entrada sul da vila, meio da Estrada Real, praça de Altamar,
  Porto dos Pescadores, Moinho, Torre em Ruínas, antes do Acampamento de Bandidos, Caverna do Oeste, Desfiladeiro do
  Norte, margem do lago do mosteiro e duas nas terras do leste. Morreu, volta na mais perto.
- Onde a Rachel morreu aparece uma **caveirinha** branca no mapa e na bússola por **5 minutos**.

## 7.1.8 Estrada Real
- Estrada direta da saída leste da vila até a Ponte dos Guardiões, no portão oeste de Altamar (~1,7 km), com ponte
  no rio do vale e curva suave ao lado do morro. Iluminada: poste com lanterna a cada 18 m, alternando os lados.

## 7.1.10 Música
- Música do vale em todo lugar; dentro dos muros de Altamar entra a **música da cidade** (troca devagar em 3 s; a
  outra fica pausada e continua de onde parou). Música da cidade: "The White City Gates" (feita no Flow Music).

## 7.1.11 Save na nuvem e atualização automática (alfa)
- **Save:** perfil anônimo por aparelho no Supabase (projeto "dallarian", São Paulo): o celular sorteia um id e um
  segredo, guardados só nele. O save continua no aparelho e também vai para o banco (funções salvar_jogo e
  carregar_jogo, que só aceitam o segredo certo). Ao abrir, o mais novo vence. Login com Google fica para o beta.
- **Atualização automática:** o APK abre numa tela de início que confere o versao.json da Release; se houver versão
  nova, baixa só o pacote do jogo (dallarian.pck, ~32 MB) e abre já atualizado. Sem internet, abre o que tem.

## 7.2 Interface
- **Joystick fixo** no canto de baixo à esquerda (celular). Empurrando para cima além da borda aparece o botão
  **TRAVAR** logo acima: levando o dedo até ele, a Rachel corre sozinha para a frente (**AUTO**). Com a trava ligada o
  joystick só vira para os lados; puxar para trás ou tocar no AUTO desliga. Abrir bolsa, loja ou menu também para.
  PC: tecla R liga/desliga.
- **Bússola** no topo (girando com a câmera, N/NE/L/SE/S/SO/O/NO e graus). Locais aparecem como ícones: apagados
  quando ainda não descobertos (até 140 m), acesos depois de descobertos (até 400 m), com o aviso "LOCAL
  DESCOBERTO". Locais: Vila do Vale, Ferraria do Bram, Mosteiro da Ilha, Porto dos Pescadores, Píer do Rio,
  Torre em Ruínas, Serraria, Acampamento de Bandidos, Caverna do Oeste, Desfiladeiro do Norte (nomes provisórios).

- **Mapa** (botão ao lado do inventário; PC: tecla M): o vale inteiro desenhado a partir do terreno, sem lugares marcados
  (eles só aparecem na bússola); a Rachel é uma setinha dourada apontando para onde olha.

- **Gráfico** também tem **Nitidez** (leve, média, alta), **Pontilhado retrô** e **Tremido PS1** (os dois desligados por padrão).
- **Menu** (botão no canto de cima à esquerda; PC: Esc): CONTINUAR e CONFIGURAÇÕES → Gráfico → **distância de visão**
  (60 m até "Tudo"); o resto some numa névoa branca e o jogo fica mais leve. Salvo no aparelho. Monstros novos
  (aranhas, Lodosos) só a partir de ~160 m da vila.

## 8. Primeiros passos de produção
1. Base jogável: câmera em primeira pessoa, filtro PS1, chão e casas low poly, grama e árvores em splats,
   céu de tempestade, espada e escudo provisórios.
2. Primeira vila pequena com alguns moradores e uma conversa.
3. Primeiro combate contra um monstro.
4. Primeira missão curta que apresente Rachel e seu sonho de ser cavaleiro.

## 8.1 Ideias para depois
- **Magia de cura** (referência: vídeo de primeira pessoa com conjuração): mão esquerda se estica com a palma
  aberta para conjurar; ou mão fechada junto ao peito, brilhando, para se curar.

## 9. Perguntas em aberto
- Nome do mundo e dos reinos.
- Quais raças existem e como se relacionam.
- De onde vem Rachel (vila, família, passado) e por que quer ser cavaleiro.
- Qual é o grande conflito da história.
- Tem diálogos com escolhas? Romance? Companheiros?

## Saque
- Monstro morto fica no chão 3 min com os drops sorteados (chance menor para o item mais valioso). Mira nele de
  perto → contorno branco; tocar no corpo (PC: E) abre a janelinha (tocar no item / PEGAR TUDO / X). Some em 3 min.

## Praia
- Conchas (leque e caramujo), pedrinhas e caranguejos vermelhos (andam de lado, fogem da Rachel), só perto dela.

## Gruta dos Lodosos (DG aberta)
- Entrada na montanha do norte, a oeste do rio do leste (≈ 1545, -880). Túneis com teto, salas com acampamento,
  6 grupos de Lodosos (nível 4–6) e o Grão-Lodoso (nível 8) na câmara final; ele renasce 30 min depois de morto.
- Futuro: quest de um soldado de Altamar pedindo para matar o Grão-Lodoso.

## Item level
- De 1 a 120 (como no WoW). Arma: dano por segundo = (1 + 0,36 × ilvl) × qualidade (comum 1; incomum 1,12;
  raro 1,25; épico 1,4), golpe ±25%. Escudo: armadura (20 + 10 × ilvl) × q, bloqueio (4 + ilvl) × q.
  Nível exigido ≈ ilvl − 5. Vale de Aldren: ilvl 1–15.

## Monstros únicos
- **Barrogar, o Colosso do Vale** (golem de barro, nível 8) — dá a volta no mapa.
- **Glorgo, o Rei da Lama** (Grão-Lodoso, nível 10) — câmara final da Gruta dos Lodosos; renasce em 30 min.
  Habilidade **Cusparada Ácida**: 2 s carregando, gosma verde; só o escudo erguido bloqueia; senão ácido por 6 s.

## Início do jogo
- A Rachel nasce no portão oeste de Altamar, virada para a Ponte dos Guardiões (morrendo, volta na Estátua da
  Guardiã mais perto).

## Câmera e heróis
- Terceira pessoa (câmera atrás do herói). Animações do pacote Sword and Shield (comprado) convertidas para o
  esqueleto do NPC base (assets/animacoes/heroi.res); montado usa a pose por código (scripts/corpo.gd).
- Visual: sem filtro PS1 (o mapa será refeito no visual original da Synty, só com pacotes comprados).
- Sem bloqueio ativo: o botão do escudo dá escudada (metade do dano, empurra).
- Fora de combate: escudo nas costas, espada na cintura (esquerda), movimento sem armas (Synty). Atacar/defender
  saca (e o golpe sai em seguida); 10 s sem atacar nem defender guarda. Atacando o herói não anda.
- Heróis-base: Humana (a Rachel) e Humano, com roupa de nível 1; outros equipamentos vêm depois.

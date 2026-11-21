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

## 7.1 A região inicial (feita)
Região de 1,2 × 1,2 km com limites naturais, em `godot/scripts/regiao.gd`:
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

## 7.2 Interface
- **Bússola** no topo (girando com a câmera, N/NE/L/SE/S/SO/O/NO e graus). Locais aparecem como ícones: apagados
  quando ainda não descobertos (até 140 m), acesos depois de descobertos (até 400 m), com o aviso "LOCAL
  DESCOBERTO". Locais: Vila do Vale, Ferraria do Bram, Mosteiro da Ilha, Porto dos Pescadores, Píer do Rio,
  Torre em Ruínas, Serraria, Acampamento de Bandidos, Caverna do Oeste, Desfiladeiro do Norte (nomes provisórios).

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

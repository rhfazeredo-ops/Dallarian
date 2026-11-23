// Arma que veio colada no modelo do Tripo (lança, cajado, tridente): separa a peça solta da arma (a 2ª maior ilha
// de triângulos) em outro GLB, sem esqueleto, nas mesmas coordenadas do modelo. O corpo fica sem a arma. No jogo a
// arma vai num pivô na mão (monstro.gd), virada à parte: em pé andando, deitada para a frente na estocada — colada
// nos pesos da mão ela giraria junto com o braço e apontaria para trás no golpe.
// Uso: node tools/separar-arma.mjs entrada.glb corpo.glb arma.glb [n_da_peça=2]
import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';
import { prune } from '@gltf-transform/functions';
const [,, ent, saiCorpo, saiArma, nPeca = '2'] = process.argv;
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);
async function ilhas(doc) {
  const prim = doc.getRoot().listMeshes()[0].listPrimitives()[0];
  const pos = prim.getAttribute('POSITION'), idx = prim.getIndices().getArray(), nv = pos.getCount();
  const pai = new Int32Array(nv).map((_, i) => i);
  const raiz = (i) => { while (pai[i] !== i) { pai[i] = pai[pai[i]]; i = pai[i]; } return i; };
  for (let t = 0; t < idx.length; t += 3) { const a = raiz(idx[t]); pai[raiz(idx[t + 1])] = a; pai[raiz(idx[t + 2])] = a; }
  const chave = new Map(), v = [0, 0, 0];
  for (let i = 0; i < nv; i++) { pos.getElement(i, v); const k = v.map((x) => Math.round(x * 1e4)).join(',');
    if (chave.has(k)) pai[raiz(i)] = raiz(chave.get(k)); else chave.set(k, i); }
  const tam = new Map();
  for (let t = 0; t < idx.length; t += 3) { const r = raiz(idx[t]); tam.set(r, (tam.get(r) || 0) + 1); }
  const ordem = [...tam.entries()].sort((a, b) => b[1] - a[1]);
  return { prim, idx, raiz, alvo: ordem[+nPeca - 1][0], ordem };
}
for (const [arq, ficaArma] of [[saiCorpo, false], [saiArma, true]]) {
  const doc = await io.read(ent);
  const { prim, idx, raiz, alvo, ordem } = await ilhas(doc);
  if (!ficaArma) console.log('ilhas:', ordem.map((o) => o[1]).join(' '));
  const novo = [];
  for (let t = 0; t < idx.length; t += 3) if ((raiz(idx[t]) === alvo) === ficaArma) novo.push(idx[t], idx[t + 1], idx[t + 2]);
  prim.getIndices().setArray(new Uint32Array(novo));
  if (ficaArma) {                           // arma: sem esqueleto
    prim.setAttribute('JOINTS_0', null); prim.setAttribute('WEIGHTS_0', null);
    for (const n of doc.getRoot().listNodes()) n.setSkin(null);
    for (const s of doc.getRoot().listSkins()) s.dispose();
  }
  await doc.transform(prune());
  await io.write(arq, doc);
  console.log(arq.split('/').pop(), 'triângulos', novo.length / 3);
}

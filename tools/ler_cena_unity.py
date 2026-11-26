#!/usr/bin/env python3
"""Lê uma cena do Unity (YAML, .unity) de um pacote da Synty e grava a lista de objetos com a transformação no
mundo, já convertida para o Godot: [{"n": nome do prefab, "t": [bx.x,bx.y,bx.z, by..., bz..., origem...]}].
Uso: ler_cena_unity.py cena.unity pasta_do_pacote_extraído saida.json
(pasta_do_pacote_extraído: cada guid numa pasta com "pathname" e "asset", como sai do .unitypackage)
Unity é mão esquerda e importa o FBX negando X; o Godot importa o FBX como está. Então M_godot = Fx · M_unity · Fx."""
import sys, os, re, json, glob
import numpy as np

cena, pacote, saida = sys.argv[1], sys.argv[2], sys.argv[3]

def docs(txt):
    for m in re.finditer(r'^--- !u!(\d+) &(-?\d+)( stripped)?\n(.*?)(?=^--- |\Z)', txt, re.S | re.M):
        yield int(m.group(1)), int(m.group(2)), bool(m.group(3)), m.group(4)

def vec(s, chave, n):
    m = re.search(chave + r': \{([^}]*)\}', s)
    if not m: return None
    d = dict(kv.split(': ') for kv in m.group(1).split(', '))
    return [float(d[c]) for c in 'xyzw'[:n]]

def trs(p, q, s):
    x, y, z, w = q
    R = np.array([[1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w)],
                  [2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w)],
                  [2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y)]])
    M = np.eye(4); M[:3, :3] = R * np.array(s); M[:3, 3] = p
    return M

# guid → caminho do asset (prefab, fbx) no pacote
g2p = {}
for d in glob.glob(os.path.join(pacote, '*')):
    try: g2p[os.path.basename(d)] = open(os.path.join(d, 'pathname')).read().strip()
    except Exception: pass

# padrão da raiz de cada prefab (quando a cena não sobrescreve posição/rotação/escala)
raiz_padrao = {}
def padrao(guid):
    if guid in raiz_padrao: return raiz_padrao[guid]
    r = {'p': [0, 0, 0], 'q': [0, 0, 0, 1], 's': [1, 1, 1], 'id': None}
    arq = os.path.join(pacote, guid, 'asset')
    if os.path.exists(arq):
        for tipo, fid, st, corpo in docs(open(arq, encoding='utf-8', errors='ignore').read()):
            if tipo == 4 and re.search(r'm_Father: \{fileID: 0\}', corpo):
                r = {'p': vec(corpo, 'm_LocalPosition', 3), 'q': vec(corpo, 'm_LocalRotation', 4), 's': vec(corpo, 'm_LocalScale', 3), 'id': fid}
                break
    raiz_padrao[guid] = r
    return r

txt = open(cena, encoding='utf-8', errors='ignore').read()
trans, desm, inst = {}, {}, {}
for tipo, fid, st, corpo in docs(txt):
    if tipo == 4 and st:
        m = re.search(r'm_PrefabInstance: \{fileID: (-?\d+)', corpo); desm[fid] = int(m.group(1))
    elif tipo == 4:
        pai = int(re.search(r'm_Father: \{fileID: (-?\d+)', corpo).group(1))
        trans[fid] = (trs(vec(corpo, 'm_LocalPosition', 3), vec(corpo, 'm_LocalRotation', 4), vec(corpo, 'm_LocalScale', 3)), pai)
    elif tipo == 1001:
        pai = int(re.search(r'm_TransformParent: \{fileID: (-?\d+)', corpo).group(1))
        guid = re.search(r'm_SourcePrefab: \{fileID: \d+, guid: (\w+)', corpo).group(1)
        pd = padrao(guid)
        p, q, s = list(pd['p']), list(pd['q']), list(pd['s'])
        mods = re.findall(r'target: \{fileID: (-?\d+), guid: \w+, type: 3\}\n\s+propertyPath: (m_Local\w+)\.(\w)\n\s+value: (\S+)', corpo)
        # a raiz: o alvo que é a Transform raiz do prefab (ou o que tem mais posição/rotação)
        alvos = {}
        for alvo, prop, c, v in mods: alvos.setdefault(alvo, []).append((prop, c, v))
        raiz = str(pd['id']) if pd['id'] is not None and str(pd['id']) in alvos else (max(alvos, key=lambda a: len(alvos[a])) if alvos else None)
        for prop, c, v in alvos.get(raiz, []):
            i = 'xyzw'.index(c); fv = float(v)
            if prop == 'm_LocalPosition': p[i] = fv
            elif prop == 'm_LocalRotation': q[i] = fv
            elif prop == 'm_LocalScale': s[i] = fv
        ativo = not re.search(r'propertyPath: m_IsActive\n\s+value: 0', corpo)
        nome = os.path.splitext(os.path.basename(g2p.get(guid, guid)))[0]
        inst[fid] = (trs(p, q, s), pai, nome, ativo)

cache = {}
def mundo_t(fid):           # transform da cena (comum ou "stripped" = raiz de um prefab)
    if fid == 0: return np.eye(4)
    if fid in cache: return cache[fid]
    if fid in desm: r = mundo_i(desm[fid])
    elif fid in trans:
        M, pai = trans[fid]; r = mundo_t(pai) @ M
    else: r = np.eye(4)
    cache[fid] = r; return r
def mundo_i(iid):
    M, pai, _, _ = inst[iid]
    return mundo_t(pai) @ M

Fx = np.diag([-1.0, 1, 1, 1])
lista = []; nomes = {}
for iid, (M, pai, nome, ativo) in inst.items():
    if not ativo: continue
    G = Fx @ mundo_i(iid) @ Fx
    b = G[:3, :3]; o = G[:3, 3]
    lista.append({'n': nome, 't': [round(float(v), 4) for v in list(b[:, 0]) + list(b[:, 1]) + list(b[:, 2]) + list(o)]})
    nomes[nome] = nomes.get(nome, 0) + 1
json.dump(lista, open(saida, 'w'))
pos = np.array([l['t'][9:] for l in lista])
print('objetos', len(lista), 'tipos', len(nomes))
print('caixa min', pos.min(0).round(1), 'max', pos.max(0).round(1))
for n, c in sorted(nomes.items(), key=lambda x: -x[1])[:25]: print(c, n)

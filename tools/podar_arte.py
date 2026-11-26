#!/usr/bin/env python3
"""Antes de exportar: apaga de godot/arte os modelos e texturas dos pacotes que o jogo não usa (o pacote inteiro
deixava o download com ~300 MB). Usado = nome citado nos scripts (com ou sem "MF:"), mais a colisão e a versão de longe.
Texturas do Meadow Forest: só as que algum material usado pede; mapas de normal nunca (o shader não usa)."""
import os, re, json, glob, sys
raiz = sys.argv[1] if len(sys.argv) > 1 else 'godot'
txt = ''.join(open(f, encoding='utf-8').read() for f in glob.glob(f'{raiz}/scripts/*.gd'))
nomes = set(re.findall(r'"(?:MF:)?(SM_[A-Za-z0-9_]+)"', txt)) | {'FantasyKingdom_Characters'}
# Altamar: a cena da Synty (arte/altamar/cena.json) usa os modelos pelo nome da lista
cena = f'{raiz}/arte/altamar/cena.json'
if os.path.exists(cena): nomes |= {o['n'] for o in json.load(open(cena))}
usados = set()
for n in nomes: usados |= {n, n + '_Collision'}
apagados = 0
for pasta in [f'{raiz}/arte/fk/modelos', f'{raiz}/arte/mf/modelos']:
    for f in glob.glob(pasta + '/*.fbx'):
        if os.path.basename(f)[:-4] not in usados: os.remove(f); apagados += 1
mf = f'{raiz}/arte/mf'
if os.path.exists(mf + '/materiais.json'):
    mats = json.load(open(mf + '/materiais.json')); mapa = json.load(open(mf + '/mapa_materiais.json'))
    tex = {'PolygonNatureBiomes_Meadow_Texture_01.png', 'Grass_Short_01.tga', 'Grass_Mid_01.tga'}
    for no, ml in mapa.items():
        if any(no.startswith(n) for n in nomes):
            for m in ml:
                if mats.get(m, {}).get('tex'): tex.add(mats[m]['tex'])
    for f in glob.glob(mf + '/texturas/*'):
        if os.path.basename(f) not in tex: os.remove(f); apagados += 1
for f in glob.glob(f'{raiz}/arte/fk/texturas/*'):
    if 'Normal' in f: os.remove(f); apagados += 1
print('podar_arte: apagados', apagados, 'arquivos; modelos citados', len(nomes))

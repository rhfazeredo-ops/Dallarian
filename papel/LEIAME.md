# Dallarian 2D (papercraft)

- `jogo/` — o jogo (página única + `art/`). Mexeu aqui e enviou ao `main`: o workflow "Jogo 2D no Supabase"
  chama a função `publicar-papel`, que copia esta pasta para o bucket público `papel` e grava `versao.json`.
- `apk/` — lançador Android (Capacitor). Ao abrir, confere o `versao.json` no Supabase, baixa o `index.html`
  novo (a arte vem direto do bucket) e roda. Sem internet, abre a cópia que veio dentro do APK.
  APK: https://github.com/rhfazeredo-ops/Dallarian/releases/download/apk-2d/dallarian-2d.apk
- Editor de mapas: artifact "Dallarian – Editor de Mapas" (mesmo código, com o editor ligado).

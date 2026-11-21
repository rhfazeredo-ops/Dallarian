# Acabamento do mapa: tons quentes de pergaminho, granulado de papel, borda escura gasta e moldura.
# Uso: python3 tools/mapa_pergaminho.py godot/assets/ui/mapa_base.png godot/assets/ui/mapa.png
import sys, numpy as np
from PIL import Image, ImageFilter
im = Image.open(sys.argv[1]).convert('RGB')
a = np.asarray(im).astype(float) / 255.0
h, w, _ = a.shape
papel = np.array([0.93, 0.86, 0.7])
a = a * 0.82 + papel * a.mean(axis=2, keepdims=True) * 0.18          # puxa para o tom de pergaminho
rng = np.random.default_rng(3)
grao = rng.normal(0, 1, (h // 2, w // 2)); grao = np.kron(grao, np.ones((2, 2)))[:h, :w]
a *= (1.0 + grao[..., None] * 0.025)
yy, xx = np.mgrid[0:h, 0:w]; d = np.maximum(abs(xx - w / 2) / (w / 2), abs(yy - h / 2) / (h / 2))
vinheta = np.clip((d - 0.78) / 0.22, 0, 1) ** 1.6
a = a * (1 - vinheta[..., None] * 0.55) + np.array([0.35, 0.25, 0.14]) * vinheta[..., None] * 0.3
out = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))
out = out.resize((w // 2, h // 2), Image.LANCZOS).resize((w, h), Image.NEAREST)   # pixels grandes (cara do jogo)
out.save(sys.argv[2])

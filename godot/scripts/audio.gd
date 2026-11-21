# Mixagem do jogo: canais (buses) separados com tratamento próprio, montados no começo.
#  Master   — limitador no fim (nada estoura, volume final consistente)
#  Musica   — EQ que tira um pouco dos médios (abre espaço para as vozes); abaixa sozinha durante as falas
#  Voz      — compressor leve + leve ambiência de sala (soa "no mundo", não colada no ouvido)
#  Efeitos  — reverb curto de espaço aberto (martelo, passos, ambiente)
class_name Audio

static var _duck := 0.0          # 0..1: quanto a música está abaixada
static var falando := false

static func montar() -> void:
	if AudioServer.get_bus_index("Musica") >= 0: return
	var lim := AudioEffectHardLimiter.new(); lim.ceiling_db = -1.0
	AudioServer.add_bus_effect(0, lim)
	var mus := _bus("Musica", -3.0)
	var eq := AudioEffectEQ6.new()
	eq.set_band_gain_db(2, -2.5); eq.set_band_gain_db(3, -2.0)        # 1 kHz e 3 kHz: espaço para as vozes
	AudioServer.add_bus_effect(mus, eq)
	var voz := _bus("Voz", 0.0)
	var comp := AudioEffectCompressor.new(); comp.threshold = -18.0; comp.ratio = 2.5; comp.attack_us = 8000; comp.release_ms = 150
	AudioServer.add_bus_effect(voz, comp)
	var sala := AudioEffectReverb.new(); sala.room_size = 0.18; sala.damping = 0.7; sala.wet = 0.07; sala.dry = 1.0; sala.spread = 0.6
	AudioServer.add_bus_effect(voz, sala)
	var fx := _bus("Efeitos", -1.0)
	var rv := AudioEffectReverb.new(); rv.room_size = 0.35; rv.damping = 0.55; rv.wet = 0.12; rv.dry = 1.0; rv.predelay_msec = 25
	AudioServer.add_bus_effect(fx, rv)

static func _bus(nome: String, vol: float) -> int:
	AudioServer.add_bus(); var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, nome); AudioServer.set_bus_send(i, "Master"); AudioServer.set_bus_volume_db(i, vol)
	return i

# chamado todo quadro: abaixa a música ~9 dB enquanto alguém fala (e volta devagar)
static func atualizar(delta: float) -> void:
	var i := AudioServer.get_bus_index("Musica")
	if i < 0: return
	_duck = move_toward(_duck, 1.0 if falando else 0.0, delta * (4.0 if falando else 1.2))
	AudioServer.set_bus_volume_db(i, -3.0 - 9.0 * _duck)

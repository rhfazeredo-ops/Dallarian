# Roda um Callable a cada quadro (f(delta) -> bool); quando ele devolve false, apaga o pai (ex.: a bola de cuspe).
extends Node
var f: Callable
func _process(delta: float) -> void:
	if not f.is_valid() or not f.call(delta): get_parent().queue_free()

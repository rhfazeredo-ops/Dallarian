# Obras em segundo plano: monta os pedaços do mundo (chão, grama, terreno) nos outros núcleos do processador
# (WorkerThreadPool) e entrega o resultado no quadro principal, que só põe na tela. Antes cada pedaço era montado
# inteiro no meio de um quadro (10 a 90 ms) e o jogo dava trancos enquanto a Rachel andava.
# Uso: pedir(chave, func) → a função roda fora do quadro (só pode LER dados do mapa, nunca mexer em nós da cena);
# prontos() devolve [[chave, resultado], ...] das que terminaram.
class_name Obras

const MAX_JUNTAS := 3
var _tarefas := {}                   # chave → [id da tarefa, [resultado]]

func pendente(chave) -> bool: return _tarefas.has(chave)
func cheio() -> bool: return _tarefas.size() >= MAX_JUNTAS

func pedir(chave, f: Callable) -> void:
	var caixa := [null]
	var id := WorkerThreadPool.add_task(func(): caixa[0] = f.call(), false, "obra do mundo")
	_tarefas[chave] = [id, caixa]

# espera todas terminarem (antes de fechar o jogo ou apagar o sistema)
func esperar_tudo() -> void:
	for chave in _tarefas.keys(): WorkerThreadPool.wait_for_task_completion(_tarefas[chave][0])
	_tarefas.clear()

func prontos() -> Array:
	var r := []
	for chave in _tarefas.keys():
		var t: Array = _tarefas[chave]
		if WorkerThreadPool.is_task_completed(t[0]):
			WorkerThreadPool.wait_for_task_completion(t[0])
			r.append([chave, t[1][0]]); _tarefas.erase(chave)
	return r

# empacota [[Transform3D, Color, (custom float)], ...] no formato do buffer do MultiMesh (12 + 4 + 4 floats)
static func empacotar(itens: Array, custom: bool) -> PackedFloat32Array:
	var passo := 20 if custom else 16
	var b := PackedFloat32Array(); b.resize(itens.size() * passo)
	var i := 0
	for it in itens:
		var t: Transform3D = it[0]; var c: Color = it[1]
		b[i] = t.basis.x.x; b[i + 1] = t.basis.y.x; b[i + 2] = t.basis.z.x; b[i + 3] = t.origin.x
		b[i + 4] = t.basis.x.y; b[i + 5] = t.basis.y.y; b[i + 6] = t.basis.z.y; b[i + 7] = t.origin.y
		b[i + 8] = t.basis.x.z; b[i + 9] = t.basis.y.z; b[i + 10] = t.basis.z.z; b[i + 11] = t.origin.z
		b[i + 12] = c.r; b[i + 13] = c.g; b[i + 14] = c.b; b[i + 15] = c.a
		if custom:
			b[i + 16] = float(it[2]) if it.size() > 2 else 0.0; b[i + 17] = float(it[3]) if it.size() > 3 else 0.0
			b[i + 18] = 0.0; b[i + 19] = 0.0
		i += passo
	return b

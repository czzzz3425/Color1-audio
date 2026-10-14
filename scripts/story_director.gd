extends Node
## 统一对话队列：等待完整气泡退场，再播放下一段。

var _queue: Array[Dictionary] = []
var _active: Node
var _external_busy := false


func _ready() -> void:
	DialogueManager.dialogue_started.connect(func(_resource): _external_busy = true)
	DialogueManager.dialogue_ended.connect(func(_resource): _external_busy = false)


func is_busy() -> bool:
	return is_instance_valid(_active) or _external_busy or not get_tree().get_nodes_in_group("dialogue_balloon").is_empty()


func request(source: Node, resource: DialogueResource, cue: String, on_started: Callable = Callable(), on_finished: Callable = Callable(), on_cancelled: Callable = Callable(), can_start: Callable = Callable()) -> bool:
	if resource == null or (cue != "" and not resource.cues.has(cue)):
		return false
	_queue.append({"source": weakref(source), "room": weakref(GameState.current_room) if is_instance_valid(GameState.current_room) else null,
		"resource": resource, "cue": cue, "started": on_started, "finished": on_finished, "cancelled": on_cancelled, "can_start": can_start})
	return true


func _process(_delta: float) -> void:
	if is_busy():
		return
	while not _queue.is_empty():
		var entry: Dictionary = _queue.pop_front()
		var source: Node = entry.source.get_ref()
		var room_ref: WeakRef = entry.room
		if not is_instance_valid(source) or not source.is_inside_tree() or (room_ref != null and (room_ref.get_ref() == null or room_ref.get_ref() != GameState.current_room)):
			_call_if_valid(entry.cancelled)
			continue
		if entry.can_start.is_valid() and not entry.can_start.call():
			_call_if_valid(entry.cancelled)
			continue
		_active = DialogueManager.show_dialogue_balloon(entry.resource, entry.cue)
		_active.tree_exited.connect(_on_balloon_exited.bind(entry.finished), CONNECT_ONE_SHOT)
		_call_if_valid(entry.started)
		return


func _on_balloon_exited(callback: Callable) -> void:
	_active = null
	_call_if_valid(callback)


func _call_if_valid(callback: Callable) -> void:
	if callback.is_valid():
		callback.call()

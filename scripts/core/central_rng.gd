class_name CentralRng
extends RefCounted

var rng_seed: int = 0
var _state: int = 0

func _init(seed_value: int = GameConstants.DEFAULT_SEED) -> void:
	reseed(seed_value)

func reseed(seed_value: int) -> void:
	rng_seed = seed_value
	# A small, explicit 32-bit LCG keeps replays stable across engine instances and
	# platforms. Every random decision in the prototype goes through this state.
	_state = seed_value & 0xFFFFFFFF

func randi_range(minimum: int, maximum: int) -> int:
	if maximum <= minimum:
		return minimum
	var span: int = maximum - minimum + 1
	return minimum + (_next_u32() % span)

func randf() -> float:
	return float(_next_u32()) / 4294967296.0

func choose_index(size: int) -> int:
	if size <= 1:
		return 0
	return self.randi_range(0, size - 1)

func shuffle(items: Array) -> void:
	for index: int in range(items.size() - 1, 0, -1):
		var swap_index: int = self.randi_range(0, index)
		var temporary: Variant = items[index]
		items[index] = items[swap_index]
		items[swap_index] = temporary

func _next_u32() -> int:
	_state = (_state * 1664525 + 1013904223) & 0xFFFFFFFF
	return _state

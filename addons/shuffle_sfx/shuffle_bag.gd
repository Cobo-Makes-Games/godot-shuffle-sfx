class_name ShuffleBag
extends RefCounted
## Deals indices 0..count-1 like a shuffled deck: every index once before any
## repeats, and a new deck never starts with the index that was dealt last, so
## the same item never comes up twice in a row (with two or more items).

var count: int = 0
var _deck: Array[int] = []
var _last: int = -1
var _rng: RandomNumberGenerator


func _init(item_count: int, rng: RandomNumberGenerator = null) -> void:
	count = maxi(0, item_count)
	_rng = rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		_rng.randomize()


## The next index, or -1 when the bag is empty (count 0).
func next() -> int:
	if count == 0:
		return -1
	if _deck.is_empty():
		_refill()
	_last = _deck.pop_back()
	return _last


## The index dealt last (-1 before the first deal).
func last() -> int:
	return _last


## Forget the current deck; the next deal starts a fresh shuffle.
func reset() -> void:
	_deck.clear()


func _refill() -> void:
	for i: int in count:
		_deck.append(i)
	# Fisher-Yates, dealing from the back.
	for i: int in range(count - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var swap: int = _deck[i]
		_deck[i] = _deck[j]
		_deck[j] = swap
	# The first card of the new deck (dealt from the back) must differ from the last one dealt.
	if count > 1 and _deck[-1] == _last:
		var swap: int = _deck[0]
		_deck[0] = _deck[-1]
		_deck[-1] = swap

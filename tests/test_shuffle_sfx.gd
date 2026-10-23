extends SceneTree
## Headless checks: godot --headless --path . --script tests/test_shuffle_sfx.gd
## Exits 0 when every check passes, 1 otherwise, printing each result.

var failures: int = 0


func check(ok: bool, label: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1


func _initialize() -> void:
	_test_bag()
	await _test_player()
	print("%d failure(s)" % failures)
	quit(1 if failures > 0 else 0)


func _test_bag() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	for size: int in [1, 2, 3, 11]:
		var bag: ShuffleBag = ShuffleBag.new(size, rng)
		var previous: int = -1
		var repeats: int = 0
		var counts: Array[int] = []
		counts.resize(size)
		counts.fill(0)
		var complete: bool = true
		for deck: int in 1000:
			var seen: Dictionary = {}
			for card: int in size:
				var value: int = bag.next()
				if value == previous:
					repeats += 1
				previous = value
				seen[value] = true
				counts[value] += 1
			complete = complete and seen.size() == size
		if size > 1:
			check(repeats == 0, "bag of %d: no item twice in a row over %d deals" % [size, size * 1000])
		check(complete, "bag of %d: every deck deals each item exactly once" % size)
		check(counts.min() == 1000 and counts.max() == 1000, "bag of %d: every item dealt equally often" % size)
	check(ShuffleBag.new(0).next() == -1, "empty bag deals -1")


func _cue(id: StringName, variants: int, cooldown: float, max_voices: int, priority: int = 0) -> ShuffleSfxCue:
	var cue: ShuffleSfxCue = ShuffleSfxCue.new()
	cue.id = id
	cue.cooldown = cooldown
	cue.max_voices = max_voices
	cue.priority = priority
	for i: int in variants:
		var wav: AudioStreamWAV = AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_8_BITS
		wav.mix_rate = 8000
		var data: PackedByteArray = PackedByteArray()
		data.resize(8000 * 5)  # five seconds, so voices stay busy during the test
		wav.data = data
		cue.variants.append(wav)
	return cue


func _test_player() -> void:
	var sfx: ShuffleSfxPlayer = ShuffleSfxPlayer.new()
	sfx.seed = 3
	sfx.voices = 6
	sfx.reserved_voices = 2
	sfx.important_priority = 4
	sfx.cues = [_cue(&"pickup", 11, 0.09, 2), _cue(&"hit", 3, 0.0, 8), _cue(&"hurt", 2, 0.0, 4, 5)]
	root.add_child(sfx)
	await process_frame

	check(not sfx.play(&"missing"), "unknown cue is skipped")
	check(sfx.play(&"pickup", 0.0, 10.0), "first pickup plays")
	check(sfx.check(&"pickup", 10.05) == "cooldown", "a pickup 0.05 s later is inside the 0.09 s cooldown")
	check(sfx.play(&"pickup", 0.0, 10.1), "a pickup 0.1 s later plays")
	check(sfx.check(&"pickup", 10.3) == "voices", "a third pickup at once is over its 2-voice limit")
	check(sfx.last_variant(&"pickup") != -1, "the player remembers the variant it played")

	# 2 pickups sound; hits fill the 4 unreserved voices (6 - 2 reserved).
	check(sfx.play(&"hit", 0.0, 11.0) and sfx.play(&"hit", 0.0, 11.0), "two hits fill the ordinary voices")
	check(sfx.check(&"hit", 11.0) == "budget", "a third hit is out of ordinary voices (2 kept for important sounds)")
	check(sfx.play(&"hurt", 0.0, 11.0), "an important sound still plays on a reserved voice")
	check(sfx.play(&"hurt", 0.0, 11.0), "a second important sound uses the last reserved voice")
	check(sfx.check(&"hurt", 11.0) == "budget", "with every voice busy even important sounds are skipped")
	check(sfx.active_voices() == 6, "six voices sounding")
	sfx.stop_all()
	check(sfx.active_voices() == 0, "stop_all frees every voice")

	var stats: Dictionary = sfx.stats()
	check(stats.played == 6, "played count is 6 (got %d)" % stats.played)
	sfx.queue_free()
	await process_frame

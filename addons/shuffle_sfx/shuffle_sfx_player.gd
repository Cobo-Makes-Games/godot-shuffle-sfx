@icon("res://addons/shuffle_sfx/icon.svg")
class_name ShuffleSfxPlayer
extends Node
## Plays sound effects that you hear hundreds of times without them grating:
## each cue's recordings come in a shuffled order that never repeats the last
## one, a per-cue cooldown and voice limit thin out bursts, and a few voices are
## kept free for important sounds so a busy moment never drops the one that matters.
##
##   $Sfx.play(&"pickup")
##
## Rules from Mytheria's mixer (cobomakesgames.com/blog/pickup-sound/).

## Emitted when a play is skipped: reason is "unknown", "cooldown", "voices" or "budget".
signal dropped(id: StringName, reason: String)

@export var cues: Array[ShuffleSfxCue] = []
## How many sounds this player can play at once, across all cues.
@export_range(1, 64) var voices: int = 24
## Voices only plays with priority >= important_priority may use.
@export_range(0, 32) var reserved_voices: int = 4
@export_range(0, 10) var important_priority: int = 4
## Set a seed for a repeatable order (tests, replays). 0 = random.
@export var seed: int = 0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _by_id: Dictionary = {}
var _bags: Dictionary = {}
var _last_played: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
## The cue id each player is sounding (&"" when free).
var _playing: Array[StringName] = []
var _stats: Dictionary = {"played": 0, "dropped": 0}


func _ready() -> void:
	if seed != 0:
		_rng.seed = seed
	else:
		_rng.randomize()
	for i: int in voices:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "Voice%d" % i
		add_child(player)
		player.finished.connect(_on_finished.bind(i))
		_players.append(player)
		_playing.append(&"")
	rebuild()


## Re-read `cues` after changing it at runtime.
func rebuild() -> void:
	_by_id.clear()
	_bags.clear()
	for cue: ShuffleSfxCue in cues:
		if cue == null or cue.id == &"":
			continue
		_by_id[cue.id] = cue
		_bags[cue.id] = ShuffleBag.new(cue.variants.size(), _rng)


## Plays one variant of the cue. Returns false (and emits `dropped`) when the
## cue is unknown, inside its cooldown, at its voice limit, or out of voices.
## `now` is in seconds; leave it at -1 to use the engine clock.
func play(id: StringName, volume_db_offset: float = 0.0, now: float = -1.0) -> bool:
	var refusal: String = check(id, now)
	if not refusal.is_empty():
		_stats.dropped += 1
		dropped.emit(id, refusal)
		return false
	var cue: ShuffleSfxCue = _by_id[id]
	var slot: int = _playing.find(&"")
	var variant: int = (_bags[id] as ShuffleBag).next()
	var player: AudioStreamPlayer = _players[slot]
	player.stream = cue.variants[variant]
	player.bus = cue.bus
	player.volume_db = cue.volume_db + volume_db_offset
	player.pitch_scale = pow(2.0, _rng.randf_range(-cue.pitch_cents, cue.pitch_cents) / 1200.0)
	_playing[slot] = id
	_last_played[id] = _clock(now)
	_stats.played += 1
	player.play()
	return true


## Why play(id) would be skipped right now ("" = it would play).
func check(id: StringName, now: float = -1.0) -> String:
	var cue: ShuffleSfxCue = _by_id.get(id)
	if cue == null or cue.variants.is_empty():
		return "unknown"
	if _clock(now) - float(_last_played.get(id, -INF)) < cue.cooldown:
		return "cooldown"
	var active: int = 0
	var same: int = 0
	for playing: StringName in _playing:
		if playing != &"":
			active += 1
			if playing == id:
				same += 1
	if same >= cue.max_voices:
		return "voices"
	var limit: int = voices if cue.priority >= important_priority else maxi(0, voices - reserved_voices)
	if active >= limit or _playing.find(&"") == -1:
		return "budget"
	return ""


## The variant index this cue played last (-1 if never).
func last_variant(id: StringName) -> int:
	var bag: ShuffleBag = _bags.get(id)
	return bag.last() if bag != null else -1


## Stops every voice.
func stop_all() -> void:
	for i: int in _players.size():
		_players[i].stop()
		_playing[i] = &""


## Counts of plays and skips since the player started.
func stats() -> Dictionary:
	return _stats.duplicate()


func active_voices() -> int:
	return _playing.size() - _playing.count(&"")


func _on_finished(slot: int) -> void:
	_playing[slot] = &""


func _clock(now: float) -> float:
	return now if now >= 0.0 else Time.get_ticks_usec() / 1000000.0

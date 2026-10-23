extends Control
## Shuffle SFX demo: five generated "plop" variants. Press Pick up to hear one;
## Burst plays eight at once, and the 0.09 s cooldown and 2-voice limit keep it soft.

@onready var sfx: ShuffleSfxPlayer = $Sfx
@onready var log_label: Label = $Box/Log
var lines: PackedStringArray = []


func _ready() -> void:
	var cue: ShuffleSfxCue = ShuffleSfxCue.new()
	cue.id = &"plop"
	cue.cooldown = 0.09
	cue.max_voices = 2
	cue.volume_db = -6.0
	for i: int in 5:
		cue.variants.append(_plop(420.0 + i * 55.0))
	sfx.cues = [cue]
	sfx.rebuild()
	sfx.dropped.connect(func(id: StringName, reason: String) -> void: _say("skipped (%s)" % reason))
	$Box/One.pressed.connect(_one)
	$Box/Burst.pressed.connect(_burst)


func _one() -> void:
	if sfx.play(&"plop"):
		_say("variant %d" % sfx.last_variant(&"plop"))


func _burst() -> void:
	for i: int in 8:
		if sfx.play(&"plop"):
			_say("variant %d" % sfx.last_variant(&"plop"))
		await get_tree().create_timer(0.03).timeout


func _say(text: String) -> void:
	lines.append(text)
	if lines.size() > 12:
		lines.remove_at(0)
	log_label.text = "\n".join(lines)


## A short decaying sine with a falling pitch: a soft generated plop.
func _plop(frequency: float) -> AudioStreamWAV:
	var rate: int = 22050
	var length: int = int(rate * 0.18)
	var data: PackedByteArray = PackedByteArray()
	data.resize(length * 2)
	var phase: float = 0.0
	for n: int in length:
		var t: float = float(n) / rate
		phase += TAU * frequency * (1.0 - t * 1.6) / rate
		var sample: float = sin(phase) * exp(-t * 28.0) * min(1.0, t * 400.0)
		data.encode_s16(n * 2, int(clampf(sample, -1.0, 1.0) * 30000.0))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav

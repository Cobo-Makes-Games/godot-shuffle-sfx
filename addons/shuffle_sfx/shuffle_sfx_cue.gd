@tool
class_name ShuffleSfxCue
extends Resource
## One sound effect with several recordings ("variants"). ShuffleSfxPlayer plays
## the variants in a shuffled order that never repeats the last one, and limits
## how often and how many at once the cue can play.

## The name you play it by: player.play(&"pickup").
@export var id: StringName = &""
## The recordings. Two or more give the no-repeat shuffle something to do.
@export var variants: Array[AudioStream] = []
## Seconds after a play during which another play of this cue is skipped.
## A short cooldown (around 0.05 to 0.1 s) turns a burst of pickups into a few soft plays.
@export_range(0.0, 2.0, 0.005, "or_greater") var cooldown: float = 0.0
## How many of this cue may sound at the same time.
@export_range(1, 32) var max_voices: int = 2
## Plays at this priority or above may use the player's reserved voices.
@export_range(0, 10) var priority: int = 0
@export_range(-60.0, 12.0, 0.1) var volume_db: float = 0.0
## Random pitch spread, in cents, either way. 0 keeps every recording as recorded.
@export_range(0.0, 1200.0, 1.0) var pitch_cents: float = 0.0
@export var bus: StringName = &"Master"

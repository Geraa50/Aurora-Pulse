extends Node
## Central audio controller for calm background music and short UI/game SFX.

# Без явной аннотации AudioStream — иначе GDScript 4.4 ругается на
# `MUSIC is AudioStreamWAV` ниже: «Expression is of type 'AudioStream' so it
# can't be of type 'AudioStreamWAV'». preload и так выводит конкретный тип.
const MUSIC = preload("res://assets/audio/music/aurora_ambient_loop.wav")
const SFX: Dictionary = {
	&"tile_tap": preload("res://assets/audio/sfx/tile_tap.wav"),
	&"tile_blocked": preload("res://assets/audio/sfx/tile_blocked.wav"),
	&"triple_match": preload("res://assets/audio/sfx/triple_match.wav"),
	&"triple_fail": preload("res://assets/audio/sfx/triple_fail.wav"),
	&"ui_button": preload("res://assets/audio/sfx/ui_button.wav"),
	&"level_complete": preload("res://assets/audio/sfx/level_complete.wav"),
}

const SFX_POOL_SIZE: int = 8

@export var music_volume_db: float = -24.0
@export var sfx_volume_db: float = -12.0

var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	randomize()
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.volume_db = music_volume_db
	_music_player.stream = MUSIC
	add_child(_music_player)

	if MUSIC is AudioStreamWAV:
		var wav := MUSIC as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.mix_rate * wav.get_length())

	for i in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "SfxPlayer%d" % i
		player.volume_db = sfx_volume_db
		add_child(player)
		_sfx_players.append(player)


func play_music() -> void:
	if not _music_player.playing:
		_music_player.play()


func stop_music() -> void:
	_music_player.stop()


func play_sfx(name: StringName, pitch_jitter: float = 0.035) -> void:
	if not SFX.has(name):
		return
	var player := _free_sfx_player()
	player.stop()
	player.stream = SFX[name]
	player.volume_db = sfx_volume_db
	player.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	player.play()


func _free_sfx_player() -> AudioStreamPlayer:
	for player in _sfx_players:
		if not player.playing:
			return player
	return _sfx_players[0]

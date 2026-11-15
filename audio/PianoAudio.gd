extends Node
## Procedural piano. Every sound is synthesized in GDScript at start-up:
## a G4 (392.00 Hz) click note and a small set of sampled pitches that a slow
## sequencer replays as a looping, relaxed background piece in G major.
## No audio files are required. To use recordings instead, assign
## `click_override` and/or `music_override` before the node enters the tree.

const NOTE_G4_HZ: float=392.0
const CLICK_MIX_RATE: int=32000
const BUS_NAME: StringName=&"Piano"
const TEMPO_BPM: float=54.0
const LOOP_BEATS: float=32.0
## MIDI pitches rendered once; other notes are repitched from the nearest one.
const BASE_NOTES: Array[int]=[43,50,57,64,71,78]

@export var click_override: AudioStream
@export var music_override: AudioStream
@export_range(-40.0,6.0) var music_volume_db: float=-10.0
@export_range(-40.0,6.0) var click_volume_db: float=-4.0

var enabled: bool=false
var samples_ready: bool=false
var clicks_played: int=0
var notes_played: int=0
var _music_player: AudioStreamPlayer
var _click_player: AudioStreamPlayer
var _music_voice: AudioStreamPlaybackPolyphonic
var _click_voice: AudioStreamPlaybackPolyphonic
var _click_stream: AudioStream
var _samples: Dictionary={}
var _rendered: Array=[]
var _render_lock:=Mutex.new()
var _task_id: int=-1
var _abort: bool=false
var _score: Array=[]
var _beat: float=-0.75
var _cursor: int=0
var _fade: Tween
var _rng:=RandomNumberGenerator.new()

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_ensure_bus()
	_music_player=_make_player("Music")
	_click_player=_make_player("Click")
	_build_score()
	set_process(false)
	if enabled:_start()

func _make_player(player_name: String) -> AudioStreamPlayer:
	var player:=AudioStreamPlayer.new()
	player.name=player_name
	player.bus=BUS_NAME
	var stream:=AudioStreamPolyphonic.new()
	stream.polyphony=32
	player.stream=stream
	add_child(player)
	return player

func _ensure_bus() -> void:
	if AudioServer.get_bus_index(BUS_NAME)!=-1:return
	AudioServer.add_bus()
	var index:=AudioServer.bus_count-1
	AudioServer.set_bus_name(index,BUS_NAME)
	AudioServer.set_bus_send(index,&"Master")
	var reverb:=AudioEffectReverb.new()
	reverb.room_size=0.74
	reverb.damping=0.55
	reverb.spread=0.9
	reverb.hipass=0.12
	reverb.dry=0.92
	reverb.wet=0.2
	AudioServer.add_bus_effect(index,reverb)

func set_enabled(value: bool) -> void:
	if enabled==value:return
	enabled=value
	if not is_inside_tree():return
	if enabled:_start()
	else:_stop()

func _start() -> void:
	if _fade!=null and _fade.is_valid():_fade.kill()
	if music_override!=null:
		_music_player.stream=music_override
		_music_player.volume_db=-40.0
		_music_player.play()
		_fade=create_tween()
		_fade.tween_property(_music_player,"volume_db",music_volume_db,3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		_music_player.volume_db=-30.0
		_music_voice=_open_voice(_music_player)
		_fade=create_tween()
		_fade.tween_property(_music_player,"volume_db",0.0,3.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_click_voice=_open_voice(_click_player)
	_beat=-0.75
	_cursor=0
	if click_override!=null:_click_stream=click_override
	if not samples_ready and _task_id==-1:
		_abort=false
		_rendered.clear()
		_rendered.resize(BASE_NOTES.size()+1)
		_task_id=WorkerThreadPool.add_group_task(_render_job,_rendered.size(),-1,false,"Piano synthesis")
	set_process(true)

func _open_voice(player: AudioStreamPlayer) -> AudioStreamPlaybackPolyphonic:
	if not player.playing:player.play()
	return player.get_stream_playback() as AudioStreamPlaybackPolyphonic

func _stop() -> void:
	if _fade!=null and _fade.is_valid():_fade.kill()
	_fade=create_tween()
	_fade.tween_property(_music_player,"volume_db",-60.0,0.3)
	_fade.tween_callback(_silence)

func _silence() -> void:
	if enabled:return
	_music_player.stop()
	_click_player.stop()
	_music_voice=null
	_click_voice=null
	if _task_id==-1:set_process(false)

## Plays the piano G note used by every button.
func play_click() -> void:
	if not enabled or _click_stream==null or not is_inside_tree():return
	if _click_voice==null:_click_voice=_open_voice(_click_player)
	if _click_voice==null:return
	_click_voice.play_stream(_click_stream,0.0,click_volume_db,1.0,AudioServer.PLAYBACK_TYPE_DEFAULT,BUS_NAME)
	clicks_played+=1

func _process(delta: float) -> void:
	if _task_id!=-1 and WorkerThreadPool.is_group_task_completed(_task_id):
		WorkerThreadPool.wait_for_group_task_completion(_task_id)
		_task_id=-1
		_install_samples()
	if not enabled or not samples_ready or music_override!=null or _music_voice==null:return
	_beat+=minf(delta,0.1)*TEMPO_BPM/60.0
	while _cursor<_score.size() and _score[_cursor][0]<=_beat:
		var event: Array=_score[_cursor]
		_cursor+=1
		# Melody notes are occasionally left out so each pass sounds slightly different.
		if event[3] and _rng.randf()<0.14:continue
		_play_note(event[1],event[2]*_rng.randf_range(0.86,1.06))
	if _beat>=LOOP_BEATS:
		_beat-=LOOP_BEATS
		_cursor=0

func _play_note(midi: int,velocity: float) -> void:
	var base: int=BASE_NOTES[0]
	for candidate in BASE_NOTES:
		if absi(candidate-midi)<absi(base-midi):base=candidate
	var stream: AudioStream=_samples.get(base)
	if stream==null:return
	var pitch:=pow(2.0,float(midi-base)/12.0)
	_music_voice.play_stream(stream,0.0,music_volume_db+linear_to_db(clampf(velocity,0.05,1.0)),pitch,AudioServer.PLAYBACK_TYPE_DEFAULT,BUS_NAME)
	notes_played+=1

func _build_score() -> void:
	# Eight slow bars: G - Em7 - Cmaj7 - Dsus4 - G/B - Cadd9 - Am7 - D7sus4.
	# The click note (G) belongs to or gently suspends every chord.
	var left: Array=[
		[43,50,55,59,62,59,55,50],
		[40,47,52,55,59,55,52,47],
		[48,55,60,64,67,64,60,55],
		[50,57,62,67,69,66,62,57],
		[47,55,59,62,67,62,59,55],
		[48,55,60,62,64,62,60,55],
		[45,52,57,60,64,60,57,52],
		[50,57,60,62,67,62,60,57]]
	var right: Array=[
		[[0.0,71],[2.0,74]],
		[[0.0,67],[2.5,76],[3.0,74]],
		[[0.0,76],[2.0,71]],
		[[0.0,69],[3.0,66]],
		[[0.0,74],[2.0,79]],
		[[0.0,76],[1.5,74],[2.5,71]],
		[[0.0,72],[2.0,69]],
		[[0.0,69],[2.0,71]]]
	_score.clear()
	for bar in left.size():
		for step in 8:
			var accent:=0.44 if step==0 else 0.36 if step==4 else 0.29
			_score.append([bar*4.0+step*0.5,left[bar][step],accent,false])
		for note in right[bar]:
			_score.append([bar*4.0+note[0]+0.02,note[1],0.62,true])
	_score.sort_custom(func(a: Array,b: Array) -> bool:return a[0]<b[0])

func _render_job(index: int) -> void:
	# Runs on worker threads; touches only local data and the guarded result list.
	var data: PackedByteArray
	var rate: int=CLICK_MIX_RATE
	if index==0:
		data=_render_tone(NOTE_G4_HZ,2.6,rate,7)
	else:
		var midi: int=BASE_NOTES[index-1]
		rate=16000 if midi<56 else 24000
		data=_render_tone(_midi_to_hz(midi),clampf(4.6-midi*0.03,2.2,3.6),rate,5)
	_render_lock.lock()
	_rendered[index]=[data,rate]
	_render_lock.unlock()

func _midi_to_hz(midi: int) -> float:
	return 440.0*pow(2.0,float(midi-69)/12.0)

## Additive piano-like tone: slightly inharmonic partials, detuned string pairs
## for warmth, faster decay for higher partials and a soft hammer attack.
func _render_tone(frequency: float,seconds: float,rate: int,partial_count: int) -> PackedByteArray:
	var count:=int(seconds*rate)
	var mix:=PackedFloat32Array()
	mix.resize(count)
	var base_decay:=1.1+frequency/330.0
	for k in range(1,partial_count+1):
		if _abort:break
		var partial:=frequency*k*sqrt(1.0+0.00035*k*k)
		if partial>rate*0.45:break
		var gain:=pow(float(k),-1.35)
		var decay:=base_decay*(1.0+0.55*(k-1))
		var detunes: Array=[-0.0009,0.0011] if k<=2 else [0.0]
		for detune: float in detunes:
			# Two-pole resonator: one multiply per sample instead of a sin() call.
			var omega:=TAU*partial*(1.0+detune)/rate
			var coefficient:=2.0*cos(omega)
			var damping:=exp(-decay/rate)
			var previous:=sin(-omega)
			var older:=sin(-2.0*omega)
			var level:=gain/detunes.size()
			for i in count:
				var value:=coefficient*previous-older
				older=previous
				previous=value
				mix[i]+=value*level
				level*=damping
	var peak:=0.0001
	for i in count:peak=maxf(peak,absf(mix[i]))
	var attack:=maxi(1,int(0.006*rate))
	var release:=maxi(1,int(0.14*rate))
	var data:=PackedByteArray()
	data.resize(count*2)
	for i in count:
		var value:=mix[i]/peak*0.86
		if i<attack:
			var rise:=sin(float(i)/attack*PI*0.5)
			value*=rise*rise
		if i>=count-release:value*=float(count-i)/release
		data.encode_s16(i*2,int(clampf(value,-1.0,1.0)*32767.0))
	return data

func _install_samples() -> void:
	for index in _rendered.size():
		var entry: Variant=_rendered[index]
		if not entry is Array:continue
		var stream:=AudioStreamWAV.new()
		stream.format=AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate=entry[1]
		stream.stereo=false
		stream.data=entry[0]
		if index==0:
			if click_override==null:_click_stream=stream
		else:_samples[BASE_NOTES[index-1]]=stream
	_rendered.clear()
	samples_ready=not _samples.is_empty()
	if not enabled:set_process(false)

func _exit_tree() -> void:
	_abort=true
	if _task_id!=-1:
		WorkerThreadPool.wait_for_group_task_completion(_task_id)
		_task_id=-1

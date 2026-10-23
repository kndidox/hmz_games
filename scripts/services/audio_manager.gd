extends Node

# AudioManager: sintetiza procedimentalmente y reproduce efectos de sonido originales

var sfx_volume: float = 1.0
var muted: bool = false

var _sounds: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
const MAX_PLAYERS := 6
const SAMPLE_RATE := 22050

func _ready() -> void:
	init_sounds()
	_init_players()

func init_sounds() -> void:
	if _sounds.size() > 0:
		return
	_sounds["pop"] = _generate_pop_sound()
	_sounds["click"] = _generate_click_sound()
	_sounds["game_over"] = _generate_game_over_sound()
	_sounds["new_record"] = _generate_new_record_sound()

func _init_players() -> void:
	for i in range(MAX_PLAYERS):
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)

func has_sound(name: String) -> bool:
	return _sounds.has(name)

func get_sound(name: String) -> AudioStreamWAV:
	return _sounds.get(name, null)

func play_sfx(name: String, pitch_variance: float = 0.0) -> void:
	if muted or sfx_volume <= 0.0:
		return
	var stream: AudioStreamWAV = get_sound(name)
	if stream == null:
		return
	
	# Buscar reproductor disponible
	for player in _players:
		if not player.playing:
			player.stream = stream
			player.volume_db = linear_to_db(sfx_volume)
			if pitch_variance > 0.0:
				player.pitch_scale = randf_range(1.0 - pitch_variance, 1.0 + pitch_variance)
			else:
				player.pitch_scale = 1.0
			player.play()
			return
	
	# Si todos están ocupados, usar el primero
	if _players.size() > 0:
		var player := _players[0]
		player.stream = stream
		player.volume_db = linear_to_db(sfx_volume)
		player.pitch_scale = 1.0
		player.play()

func set_sfx_volume(val: float) -> void:
	sfx_volume = clampf(val, 0.0, 1.0)

func set_muted(val: bool) -> void:
	muted = val

# --- Generadores Procedurales de Ondas de Sonido ---

func _create_wav(byte_data: PackedByteArray) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = byte_data
	return wav

func _generate_pop_sound() -> AudioStreamWAV:
	var duration := 0.12
	var total_samples := int(SAMPLE_RATE * duration)
	var byte_data := PackedByteArray()
	byte_data.resize(total_samples * 2)
	
	var phase := 0.0
	for i in range(total_samples):
		var t := float(i) / float(total_samples)
		# Tono rápido descendente (800 Hz a 180 Hz)
		var freq := lerpf(800.0, 180.0, t)
		phase += (TAU * freq) / float(SAMPLE_RATE)
		# Caída exponencial de volumen
		var amp := (1.0 - t) * (1.0 - t)
		var sample := sin(phase) * amp * 28000.0
		var sample_int := int(clampf(sample, -32767.0, 32767.0))
		byte_data.encode_s16(i * 2, sample_int)
		
	return _create_wav(byte_data)

func _generate_click_sound() -> AudioStreamWAV:
	var duration := 0.04
	var total_samples := int(SAMPLE_RATE * duration)
	var byte_data := PackedByteArray()
	byte_data.resize(total_samples * 2)
	
	var phase := 0.0
	for i in range(total_samples):
		var t := float(i) / float(total_samples)
		var freq := 1200.0
		phase += (TAU * freq) / float(SAMPLE_RATE)
		var amp := exp(-t * 25.0)
		var sample := sin(phase) * amp * 20000.0
		var sample_int := int(clampf(sample, -32767.0, 32767.0))
		byte_data.encode_s16(i * 2, sample_int)
		
	return _create_wav(byte_data)

func _generate_game_over_sound() -> AudioStreamWAV:
	var duration := 0.6
	var total_samples := int(SAMPLE_RATE * duration)
	var byte_data := PackedByteArray()
	byte_data.resize(total_samples * 2)
	
	var notes := [370.0, 330.0, 260.0]
	var samples_per_note := total_samples / notes.size()
	
	for n in range(notes.size()):
		var freq: float = notes[n]
		var phase := 0.0
		for i in range(samples_per_note):
			var idx := n * samples_per_note + i
			var t := float(i) / float(samples_per_note)
			phase += (TAU * freq) / float(SAMPLE_RATE)
			var amp := (1.0 - t * 0.8)
			var sample := sin(phase) * amp * 22000.0
			var sample_int := int(clampf(sample, -32767.0, 32767.0))
			byte_data.encode_s16(idx * 2, sample_int)
			
	return _create_wav(byte_data)

func _generate_new_record_sound() -> AudioStreamWAV:
	var duration := 0.55
	var total_samples := int(SAMPLE_RATE * duration)
	var byte_data := PackedByteArray()
	byte_data.resize(total_samples * 2)
	
	# C5 (523), E5 (659), G5 (784)
	var notes := [523.25, 659.25, 783.99]
	var samples_per_note := total_samples / notes.size()
	
	for n in range(notes.size()):
		var freq: float = notes[n]
		var phase := 0.0
		for i in range(samples_per_note):
			var idx := n * samples_per_note + i
			var t := float(i) / float(samples_per_note)
			phase += (TAU * freq) / float(SAMPLE_RATE)
			# Triángulo o seno armónico para sonido brillante
			var amp := (1.0 - t * 0.5)
			var sample := (sin(phase) + 0.3 * sin(phase * 2.0)) * amp * 18000.0
			var sample_int := int(clampf(sample, -32767.0, 32767.0))
			byte_data.encode_s16(idx * 2, sample_int)
			
	return _create_wav(byte_data)

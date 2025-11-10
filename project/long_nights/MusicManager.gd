extends Node
## MusicManager - Handles dynamic music based on time of day
## Features: Day/Night music transitions, Bloodmoon music, volume controls
## Controls: - (volume down), + (volume up), = (mute toggle)

# Audio players for crossfading
var player_a: AudioStreamPlayer
var player_b: AudioStreamPlayer
var current_player: AudioStreamPlayer
var fading_player: AudioStreamPlayer

# Music tracks
var day_music: AudioStream
var night_music: AudioStream
var bloodmoon_music: AudioStream
var sky_day_music: AudioStream  # Sky ruins day music

# State
enum MusicTrack { NONE, DAY, NIGHT, BLOODMOON, SKY_DAY }
var current_track := MusicTrack.NONE
var target_track := MusicTrack.NONE
var is_crossfading := false
var crossfade_duration := 3.0  # 3 seconds crossfade
var crossfade_time := 0.0

# Volume settings
var master_volume := 0.7  # 0.0 to 1.0
var is_muted := false
var volume_before_mute := 0.7
const VOLUME_STEP = 0.1

# Day/night time thresholds (in hours, 0-23)
const DAY_START_HOUR = 6   # 6 AM - sunrise
const TWILIGHT_HOUR = 18   # 6 PM - twilight/sunset
const NIGHT_START_HOUR = 19  # 7 PM - full night
const DAWN_HOUR = 5  # 5 AM - dawn

var in_game := false  # Only play music when in-game

# Sky ruins threshold
const SKY_HEIGHT_THRESHOLD = 100.0  # Y >= 100 = sky ruins
var _is_in_sky_zone := false  # Track which zone player is in (prevents rapid switching)
var _zone_change_timer := 0.0
const ZONE_CHANGE_DELAY = 5.0  # Stay in zone for 5 seconds before switching music


func _ready() -> void:
	# Load music tracks
	day_music = load("res://assets/music/forestDay.ogg")
	night_music = load("res://assets/music/forestNight.ogg")
	bloodmoon_music = load("res://assets/music/bloodMoon.ogg")
	sky_day_music = load("res://assets/music/skyDay.ogg")

	# Create two audio players for crossfading
	player_a = AudioStreamPlayer.new()
	player_a.name = "MusicPlayerA"
	player_a.bus = "Master"
	add_child(player_a)

	player_b = AudioStreamPlayer.new()
	player_b.name = "MusicPlayerB"
	player_b.bus = "Master"
	add_child(player_b)

	current_player = player_a

	# Connect to TimeManager signals
	if TimeManager:
		TimeManager.hour_changed.connect(_on_hour_changed)
		TimeManager.bloodmoon_started.connect(_on_bloodmoon_started)
		TimeManager.bloodmoon_ended.connect(_on_bloodmoon_ended)

	# Setup audio player connections
	player_a.finished.connect(_on_music_finished.bind(player_a))
	player_b.finished.connect(_on_music_finished.bind(player_b))

	print("🎵 MusicManager initialized (Day/Night/Bloodmoon)")


func start_music():
	"""Called when player enters the game"""
	in_game = true
	# Initialize zone state based on player's starting position
	var player_y = _get_player_y_position()
	_is_in_sky_zone = player_y >= SKY_HEIGHT_THRESHOLD
	# Determine what music should be playing based on current time
	_update_music_for_time(TimeManager.current_hour)


func stop_music():
	"""Called when player exits to menu"""
	in_game = false
	if current_player.playing:
		current_player.stop()
	if fading_player and fading_player.playing:
		fading_player.stop()


var _height_check_timer := 0.0
const HEIGHT_CHECK_INTERVAL = 1.0  # Check height every second


func _process(delta: float) -> void:
	if not in_game:
		return

	# Check if player has moved between sky/ground (with hysteresis)
	_height_check_timer += delta
	if _height_check_timer >= HEIGHT_CHECK_INTERVAL:
		_height_check_timer = 0.0
		
		# Check current zone
		var player_y = _get_player_y_position()
		var currently_in_sky = player_y >= SKY_HEIGHT_THRESHOLD
		
		# If zone changed, start timer
		if currently_in_sky != _is_in_sky_zone:
			_zone_change_timer += HEIGHT_CHECK_INTERVAL
			
			# Only switch music if player has stayed in new zone for ZONE_CHANGE_DELAY
			if _zone_change_timer >= ZONE_CHANGE_DELAY:
				_is_in_sky_zone = currently_in_sky
				_zone_change_timer = 0.0
				_update_music_for_time(TimeManager.current_hour)
		else:
			# Reset timer if player returns to previous zone
			_zone_change_timer = 0.0

	# Handle crossfading
	if is_crossfading:
		crossfade_time += delta

		var progress = min(crossfade_time / crossfade_duration, 1.0)

		# Fade out old player, fade in new player
		if fading_player:
			fading_player.volume_db = _linear_to_db((1.0 - progress) * master_volume)

		if current_player:
			current_player.volume_db = _linear_to_db(progress * master_volume)

		if progress >= 1.0:
			# Crossfade complete
			is_crossfading = false
			if fading_player:
				fading_player.stop()
				fading_player = null
			current_track = target_track


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return

	# Volume controls
	if event.keycode == KEY_MINUS or event.keycode == KEY_KP_SUBTRACT:
		adjust_volume(-VOLUME_STEP)
		get_viewport().set_input_as_handled()

	elif event.keycode == KEY_PLUS or event.keycode == KEY_KP_ADD or event.keycode == KEY_EQUAL:
		adjust_volume(VOLUME_STEP)
		get_viewport().set_input_as_handled()

	elif event.keycode == KEY_EQUAL and event.shift_pressed:  # Shift+= is often +
		adjust_volume(VOLUME_STEP)
		get_viewport().set_input_as_handled()


func adjust_volume(delta: float) -> void:
	"""Adjust music volume"""
	if is_muted:
		# Unmute if adjusting volume
		is_muted = false
		master_volume = volume_before_mute

	master_volume = clamp(master_volume + delta, 0.0, 1.0)

	# Apply to current players
	if current_player:
		current_player.volume_db = _linear_to_db(master_volume)
	if fading_player:
		fading_player.volume_db = _linear_to_db(master_volume)

	print("🎵 Music volume: ", int(master_volume * 100), "%")


func toggle_mute() -> void:
	"""Toggle mute"""
	is_muted = !is_muted

	if is_muted:
		volume_before_mute = master_volume
		if current_player:
			current_player.volume_db = -80  # Effectively muted
		if fading_player:
			fading_player.volume_db = -80
		print("🔇 Music muted")
	else:
		master_volume = volume_before_mute
		if current_player:
			current_player.volume_db = _linear_to_db(master_volume)
		if fading_player:
			fading_player.volume_db = _linear_to_db(master_volume)
		print("🔊 Music unmuted")


func _on_hour_changed(hour: int) -> void:
	if not in_game:
		return
	_update_music_for_time(hour)


func _on_bloodmoon_started() -> void:
	if not in_game:
		return
	print("🩸 Bloodmoon music starting")
	_crossfade_to(MusicTrack.BLOODMOON)


func _on_bloodmoon_ended() -> void:
	if not in_game:
		return
	print("🌙 Bloodmoon ended, returning to time-based music")
	_update_music_for_time(TimeManager.current_hour)


func _get_player_y_position() -> float:
	"""Get the player's current Y position"""
	var player = get_tree().get_first_node_in_group("player")
	if player:
		return player.global_position.y
	return 0.0


func _update_music_for_time(hour: int) -> void:
	"""Determine what music should play based on time"""
	# Bloodmoon overrides everything
	if TimeManager.is_bloodmoon:
		if current_track != MusicTrack.BLOODMOON:
			_crossfade_to(MusicTrack.BLOODMOON)
		return

	# Day music: 6 AM to 6 PM
	if hour >= DAY_START_HOUR and hour < TWILIGHT_HOUR:
		# Play sky music if in sky ruins during day (using tracked zone state)
		if _is_in_sky_zone:
			if current_track != MusicTrack.SKY_DAY:
				_crossfade_to(MusicTrack.SKY_DAY)
		else:
			if current_track != MusicTrack.DAY:
				_crossfade_to(MusicTrack.DAY)

	# Night music: 7 PM to 5 AM
	elif hour >= NIGHT_START_HOUR or hour < DAWN_HOUR:
		if current_track != MusicTrack.NIGHT:
			_crossfade_to(MusicTrack.NIGHT)


func _crossfade_to(new_track: MusicTrack) -> void:
	"""Start crossfading to a new track"""
	if new_track == current_track and current_player.playing:
		return  # Already playing this track

	target_track = new_track

	# Get the music stream for the new track
	var new_stream: AudioStream = null
	match new_track:
		MusicTrack.DAY:
			new_stream = day_music
			print("🌅 Crossfading to day music")
		MusicTrack.NIGHT:
			new_stream = night_music
			print("🌙 Crossfading to night music")
		MusicTrack.BLOODMOON:
			new_stream = bloodmoon_music
			print("🩸 Crossfading to bloodmoon music")
		MusicTrack.SKY_DAY:
			new_stream = sky_day_music
			print("☁️ Crossfading to sky ruins day music")

	if new_stream == null:
		return

	# Setup crossfade
	var new_player = player_b if current_player == player_a else player_a

	new_player.stream = new_stream
	new_player.volume_db = _linear_to_db(0.0)  # Start silent
	new_player.play()

	# If current player is playing, fade it out
	if current_player.playing:
		fading_player = current_player
		is_crossfading = true
		crossfade_time = 0.0
	else:
		# No crossfade needed, just start new track
		current_player = new_player
		current_player.volume_db = _linear_to_db(master_volume)
		current_track = target_track

	current_player = new_player


func _linear_to_db(linear: float) -> float:
	"""Convert linear volume (0-1) to decibels"""
	if linear <= 0.0:
		return -80.0  # Effectively silent
	return 20.0 * log(linear) / log(10.0)


# Called when a track finishes playing
func _on_music_finished(player: AudioStreamPlayer) -> void:
	"""Loop the current track"""
	if player == current_player and in_game:
		player.play()

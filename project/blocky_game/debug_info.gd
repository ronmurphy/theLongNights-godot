extends Node

@onready var _terrain : VoxelTerrain = get_parent().get_node(^"VoxelTerrain")

const NETWORK_REPORT_INTERVAL = 1.0

var _network_report_time := NETWORK_REPORT_INTERVAL
var _network_stats := []
var _debug_visible := false  # Start hidden
var _fps_visible := false  # FPS display toggle


func _ready() -> void:
	# Hide debug info by default
	DDD.set_text("_visible", false)


func _input(event: InputEvent) -> void:
	# Toggle debug info with F3
	if event.is_action_pressed("ui_text_completion_query"):  # F3 key
		_debug_visible = !_debug_visible
		if not _debug_visible:
			# Clear all debug text
			DDD.set_text("_visible", false)
		else:
			DDD.set_text("_visible", true)


func _process(delta: float):
	# Update FPS if enabled (independent of debug info)
	if _fps_visible:
		var fps = Engine.get_frames_per_second()
		DDD.set_text("FPS", str(fps))

	# Only update debug info if visible
	if not _debug_visible:
		return

	var sm := OS.get_static_memory_usage()
	DDD.set_text("Static memory", _format_memory(sm))

	_show_voxel_stats()

	var mp := get_tree().get_multiplayer()
	if mp.has_multiplayer_peer():
		if mp.is_server():
			_network_report_time -= delta
			if _network_report_time <= 0.0:
				_network_report_time = NETWORK_REPORT_INTERVAL
				_gather_and_send_network_stats(mp)
		_show_network_stats(mp)


func _show_voxel_stats():
	var global_stats := VoxelEngine.get_stats()
	for p in global_stats:
		var pool_stats = global_stats[p]
		for k in pool_stats:
			DDD.set_text(str(p, "_", k), pool_stats[k])

	#var terrain_stats := _terrain.get_statistics()


static func connection_status_to_string(cs: int) -> String:
	match cs:
		MultiplayerPeer.CONNECTION_DISCONNECTED:
			return "Disconnected"
		MultiplayerPeer.CONNECTION_CONNECTING:
			return "Connecting"
		MultiplayerPeer.CONNECTION_CONNECTED:
			return "Connected"
		_:
			return "Unknown"


func _show_network_stats(mp: MultiplayerAPI):
	var local_peer := mp.multiplayer_peer
	
	DDD.set_text("Connection status", 
		connection_status_to_string(local_peer.get_connection_status()))
	
	var local_peer_id := local_peer.get_unique_id()
	
	for peer_stats in _network_stats:
		var peer_id = peer_stats[0]
		var peer_rtt = peer_stats[1]
		var peer_packet_loss = peer_stats[2]
		var key : String
		if peer_id == local_peer_id:
			key = str("Local peer ", peer_id)
		else:
			key = str("Remote peer ", peer_id)
		DDD.set_text(key, str("RTT: ", peer_rtt, "ms | Packet loss: ", peer_packet_loss))


func _gather_and_send_network_stats(mp: MultiplayerAPI):
	# Godot still has a peer assigned even when you don't setup multiplayer at all...
	if mp.multiplayer_peer is OfflineMultiplayerPeer:
		return

	var stats := []
	
	var peer_ids := mp.get_peers()
	var mp_peer : ENetMultiplayerPeer = mp.multiplayer_peer
	for peer_id in peer_ids:
		var peer := mp_peer.get_peer(peer_id)
		stats.append([
			peer_id,
			peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME),
			peer.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS)
		])
	
	# print("Gathered network stats: ", stats)
	rpc(&"receive_network_stats", stats)
	_network_stats = stats


@rpc("authority", "call_remote", "unreliable", 0)
func receive_network_stats(stats: Array):
	_network_stats = stats


static func _format_memory(m):
	var mb = m / 1000000
	var mbr = m % 1000000
	return str(mb, ".", mbr, " Mb")


func set_fps_visible(visible: bool) -> void:
	_fps_visible = visible
	if not visible:
		# Clear FPS text when hidden
		DDD.set_text("FPS", "")

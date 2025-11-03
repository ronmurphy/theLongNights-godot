extends "../item.gd"

const Rocket = preload("./rocket.gd")
const RocketScene = preload("./rocket.tscn")

const SERVER_PEER_ID = 1

@onready var _world : Node = get_node("/root/Main/Game")

var _next_rocket_id := 1


func use(trans: Transform3D, stack_count: int = 1):
	# Check altitude - can't fire rockets below y=-200 (air too thin!)
	if trans.origin.y < -200:
		print("Cannot fire rocket below y=-200 - air too thin!")
		return
	
	var mp := get_tree().get_multiplayer()
	if mp.has_multiplayer_peer() and not mp.is_server():
		rpc_id(SERVER_PEER_ID, &"receive_use", trans, stack_count)
	else:
		_use(trans, stack_count)


# Only the server may call this
func _use(trans: Transform3D, stack_count: int = 1):
	_spawn_rocket(_next_rocket_id, trans.origin, -trans.basis.z.normalized(), stack_count)
	_next_rocket_id += 1


func _spawn_rocket(id: int, pos: Vector3, dir: Vector3, stack_count: int):
	var rocket : Rocket = RocketScene.instantiate()
	rocket.position = pos
	# Name must match on client and server
	rocket.name = str("Rocket", id)
	rocket.stack_bonus = stack_count  # Set stack bonus for damage
	_world.add_child(rocket)
	print("Launch rocket at ", rocket.position, " | Stack bonus: +", stack_count, " damage")
	rocket.set_direction(dir)
	
	var mp := get_tree().get_multiplayer()
	if mp.has_multiplayer_peer() and mp.is_server():
		# Send rocket to clients
		rpc(&"receive_spawn_rocket", id, pos, dir, stack_count)


@rpc("any_peer", "call_remote", "reliable", 0)
func receive_use(trans: Transform3D, stack_count: int = 1):
	_use(trans, stack_count)


@rpc("authority", "call_remote", "reliable", 0)
func receive_spawn_rocket(id: int, position: Vector3, direction: Vector3, stack_count: int):
	# Get round-trip time so we can compensate for network delay.
	var mp := get_tree().get_multiplayer()
	var peer_id := mp.get_remote_sender_id()
	var mp_peer : ENetMultiplayerPeer = mp.multiplayer_peer
	var peer := mp_peer.get_peer(peer_id)
	var rtt_seconds := peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME) / 1000.0
	
	_spawn_rocket(id, position + (rtt_seconds / 2.0) * direction, direction, stack_count)

	# We could also play some effects when shooting so the player can have immediate feedback,
	# and would help hiding the fact the rocket is spawning a bit late?


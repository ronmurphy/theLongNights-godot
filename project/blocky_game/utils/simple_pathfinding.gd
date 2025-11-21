extends Node
class_name SimplePathfinding

## Simple A* pathfinding for voxel terrain
## Optimized for performance with configurable search limits

## Maximum nodes to search before giving up (prevents performance spikes)
const MAX_SEARCH_NODES = 300

## Maximum path length in blocks
const MAX_PATH_LENGTH = 50

## How far to raycast down to find ground
const GROUND_CHECK_DEPTH = 5

## Node class for A* algorithm
class PathNode:
	var position: Vector3i
	var g_cost: float = 0.0  # Distance from start
	var h_cost: float = 0.0  # Estimated distance to goal
	var f_cost: float = 0.0  # Total cost (g + h)
	var parent: PathNode = null

	func _init(pos: Vector3i):
		position = pos

	func calculate_f_cost():
		f_cost = g_cost + h_cost


## Find path from start to goal using A* algorithm
## Returns: Array of Vector3 waypoints, or empty array if no path found
static func find_path(start_pos: Vector3, goal_pos: Vector3, terrain: Node) -> Array:
	# Convert to integer voxel coordinates
	var start = Vector3i(floor(start_pos.x), floor(start_pos.y), floor(start_pos.z))
	var goal = Vector3i(floor(goal_pos.x), floor(goal_pos.y), floor(goal_pos.z))

	# Early exit if start == goal
	if start == goal:
		return [goal_pos]

	# Check if terrain is valid
	if not terrain:
		push_warning("SimplePathfinding: No terrain provided")
		return []

	var voxel_tool = terrain.get_voxel_tool()
	if not voxel_tool:
		push_warning("SimplePathfinding: Could not get voxel tool")
		return []

	# Find actual ground positions for start and goal
	var ground_start = _find_ground_position(start, voxel_tool)
	var ground_goal = _find_ground_position(goal, voxel_tool)

	if ground_start == Vector3i.ZERO or ground_goal == Vector3i.ZERO:
		return []  # Can't find valid ground

	# A* algorithm
	var open_list: Array[PathNode] = []
	var closed_set: Dictionary = {}  # position -> bool
	var nodes: Dictionary = {}  # position -> PathNode

	# Create start node
	var start_node = PathNode.new(ground_start)
	start_node.h_cost = _heuristic(ground_start, ground_goal)
	start_node.calculate_f_cost()
	open_list.append(start_node)
	nodes[ground_start] = start_node

	var search_count = 0

	while open_list.size() > 0 and search_count < MAX_SEARCH_NODES:
		search_count += 1

		# Get node with lowest f_cost
		var current = _get_lowest_f_cost_node(open_list)
		open_list.erase(current)
		closed_set[current.position] = true

		# Check if we reached the goal
		if current.position == ground_goal:
			return _reconstruct_path(current)

		# Check all neighbors
		var neighbors = _get_walkable_neighbors(current.position, voxel_tool)
		for neighbor_pos in neighbors:
			if closed_set.has(neighbor_pos):
				continue  # Already evaluated

			# Calculate costs
			var tentative_g = current.g_cost + _distance(current.position, neighbor_pos)

			# Check if this is a better path
			var neighbor_node: PathNode
			if nodes.has(neighbor_pos):
				neighbor_node = nodes[neighbor_pos]
				if tentative_g >= neighbor_node.g_cost:
					continue  # Not a better path
			else:
				neighbor_node = PathNode.new(neighbor_pos)
				neighbor_node.h_cost = _heuristic(neighbor_pos, ground_goal)
				nodes[neighbor_pos] = neighbor_node
				open_list.append(neighbor_node)

			# Update node
			neighbor_node.g_cost = tentative_g
			neighbor_node.parent = current
			neighbor_node.calculate_f_cost()

	# No path found
	return []


## Find ground position below given position
static func _find_ground_position(pos: Vector3i, voxel_tool) -> Vector3i:
	# Check current position first
	if _is_walkable(pos, voxel_tool):
		return pos

	# Search down
	for y_offset in range(GROUND_CHECK_DEPTH):
		var check_pos = Vector3i(pos.x, pos.y - y_offset, pos.z)
		if _is_walkable(check_pos, voxel_tool):
			return check_pos

	# Search up (in case position is below ground)
	for y_offset in range(1, GROUND_CHECK_DEPTH):
		var check_pos = Vector3i(pos.x, pos.y + y_offset, pos.z)
		if _is_walkable(check_pos, voxel_tool):
			return check_pos

	return Vector3i.ZERO  # No valid ground found


## Check if a position is walkable (solid ground, air above)
static func _is_walkable(pos: Vector3i, voxel_tool) -> bool:
	# Check for solid ground at position
	voxel_tool.set_channel(VoxelBuffer.CHANNEL_TYPE)
	var ground_voxel = voxel_tool.get_voxel(pos)

	# 0 = air, non-zero = solid
	if ground_voxel == 0:
		return false  # No ground

	# Check if there's space above for entity to stand (2 blocks high)
	var above_1 = voxel_tool.get_voxel(Vector3i(pos.x, pos.y + 1, pos.z))
	var above_2 = voxel_tool.get_voxel(Vector3i(pos.x, pos.y + 2, pos.z))

	if above_1 != 0 or above_2 != 0:
		return false  # Not enough headroom

	return true


## Get walkable neighbor positions (4-directional, no diagonals)
static func _get_walkable_neighbors(pos: Vector3i, voxel_tool) -> Array:
	var neighbors = []
	var directions = [
		Vector3i(1, 0, 0),   # East
		Vector3i(-1, 0, 0),  # West
		Vector3i(0, 0, 1),   # South
		Vector3i(0, 0, -1),  # North
	]

	for dir in directions:
		var neighbor_pos = pos + dir

		# Check same level
		if _is_walkable(neighbor_pos, voxel_tool):
			neighbors.append(neighbor_pos)
			continue

		# Check one block up (step climbing)
		var up_pos = neighbor_pos + Vector3i(0, 1, 0)
		if _is_walkable(up_pos, voxel_tool):
			neighbors.append(up_pos)
			continue

		# Check one block down (step down)
		var down_pos = neighbor_pos + Vector3i(0, -1, 0)
		if _is_walkable(down_pos, voxel_tool):
			neighbors.append(down_pos)

	return neighbors


## Manhattan distance heuristic
static func _heuristic(from: Vector3i, to: Vector3i) -> float:
	return abs(from.x - to.x) + abs(from.y - to.y) + abs(from.z - to.z)


## Euclidean distance for actual cost
static func _distance(from: Vector3i, to: Vector3i) -> float:
	var dx = from.x - to.x
	var dy = from.y - to.y
	var dz = from.z - to.z
	return sqrt(dx*dx + dy*dy + dz*dz)


## Get node with lowest f_cost from list
static func _get_lowest_f_cost_node(nodes: Array) -> PathNode:
	var lowest = nodes[0]
	for i in range(1, nodes.size()):
		if nodes[i].f_cost < lowest.f_cost:
			lowest = nodes[i]
	return lowest


## Reconstruct path from goal node back to start
static func _reconstruct_path(goal_node: PathNode) -> Array:
	var path = []
	var current = goal_node

	while current != null:
		# Convert Vector3i back to Vector3 and add 0.5 to center on block
		var world_pos = Vector3(current.position.x + 0.5, current.position.y, current.position.z + 0.5)
		path.push_front(world_pos)
		current = current.parent

	# Simplify path by removing unnecessary waypoints
	path = _simplify_path(path)

	return path


## Simplify path by removing waypoints in straight lines
static func _simplify_path(path: Array) -> Array:
	if path.size() <= 2:
		return path

	var simplified = [path[0]]  # Always keep start

	for i in range(1, path.size() - 1):
		var prev = path[i - 1]
		var current = path[i]
		var next = path[i + 1]

		# Check if current is on a straight line between prev and next
		var dir1 = (current - prev).normalized()
		var dir2 = (next - current).normalized()

		# If directions are very similar, skip this waypoint
		if dir1.dot(dir2) < 0.99:  # Not a straight line
			simplified.append(current)

	simplified.append(path[path.size() - 1])  # Always keep goal

	return simplified


## Quick check if there's a direct line of sight between two positions
static func has_line_of_sight(from: Vector3, to: Vector3, terrain: Node) -> bool:
	if not terrain:
		return false

	var voxel_tool = terrain.get_voxel_tool()
	if not voxel_tool:
		return false

	# Simple raycast to check if path is clear
	var direction = (to - from).normalized()
	var distance = from.distance_to(to)

	# Cast ray slightly above ground to avoid hitting ground blocks
	var ray_start = from + Vector3(0, 0.5, 0)
	var ray_end = to + Vector3(0, 0.5, 0)

	voxel_tool.set_channel(VoxelBuffer.CHANNEL_TYPE)
	var hit = voxel_tool.raycast(ray_start, direction, distance)

	return hit == null  # No obstacles if raycast returns null


## Check if moving in a direction would lead to a dangerous edge/cliff
## Returns true if it's safe, false if it's a dangerous edge
static func is_safe_to_walk(from: Vector3, direction: Vector3, terrain: Node, check_distance: float = 2.0) -> bool:
	if not terrain:
		return true  # Fail-safe: assume safe if can't check

	var voxel_tool = terrain.get_voxel_tool()
	if not voxel_tool:
		return true  # Fail-safe

	# Check position ahead
	var check_pos = from + (direction.normalized() * check_distance)
	var voxel_pos = Vector3i(floor(check_pos.x), floor(check_pos.y), floor(check_pos.z))

	# Check if there's ground below the target position
	voxel_tool.set_channel(VoxelBuffer.CHANNEL_TYPE)

	for y_offset in range(GROUND_CHECK_DEPTH):
		var ground_check = Vector3i(voxel_pos.x, voxel_pos.y - y_offset, voxel_pos.z)
		var voxel = voxel_tool.get_voxel(ground_check)
		if voxel != 0:  # Found ground
			return true

	# No ground found within check depth - dangerous edge!
	return false


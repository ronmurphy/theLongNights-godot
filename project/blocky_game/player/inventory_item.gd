
const TYPE_BLOCK = 0
const TYPE_ITEM = 1

var type := TYPE_BLOCK
var id := 0
var count := 1  # Stack count for consumables (torches), 1 = infinite for tools/weapons

# Skyshard enhancement system
var skyshard_count := 0  # Number of skyshards infused (max 5 per power unlock)
var skyshard_power := ""  # Legacy: Single power (kept for backwards compatibility)

# Power Harmonization system (fusion)
var skyshard_powers := []  # Array of power dictionaries: [{"name": "glide", "strength": 1.0}, ...]
# strength: 1.0 = Major (100%), 0.6 = Minor (60%)

# TODO Can't type hint self
func duplicate():
	var d = get_script().new()
	d.type = type
	d.id = id
	d.count = count
	d.skyshard_count = skyshard_count
	d.skyshard_power = skyshard_power
	d.skyshard_powers = skyshard_powers.duplicate(true)

	# Copy metadata (for custom tooltips and terrain expansion types)
	for meta_key in get_meta_list():
		d.set_meta(meta_key, get_meta(meta_key))

	return d


## Get all active power names (handles both legacy single power and new multi-power)
func get_all_powers() -> Array[String]:
	var powers: Array[String] = []

	# Legacy single power support
	if skyshard_power != "":
		powers.append(skyshard_power)

	# New multi-power support
	for power_data in skyshard_powers:
		if power_data.has("name") and power_data["name"] != "":
			powers.append(power_data["name"])

	return powers


## Check if has a specific power (legacy or new system)
func has_power(power_name: String) -> bool:
	return power_name in get_all_powers()


## Get power strength (1.0 for major, 0.6 for minor, 0.0 if not present)
func get_power_strength(power_name: String) -> float:
	# Legacy single power = always major
	if skyshard_power == power_name:
		return 1.0

	# Check new multi-power system
	for power_data in skyshard_powers:
		if power_data.get("name") == power_name:
			return power_data.get("strength", 1.0)

	return 0.0

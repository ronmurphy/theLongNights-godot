
const TYPE_BLOCK = 0
const TYPE_ITEM = 1

var type := TYPE_BLOCK
var id := 0
var count := 1  # Stack count for consumables (torches), 1 = infinite for tools/weapons

# Skyshard enhancement system
var skyshard_count := 0  # Number of skyshards infused (max 5 per power unlock)
var skyshard_power := ""  # Chosen power name (empty = not chosen yet)

# TODO Can't type hint self
func duplicate():
	var d = get_script().new()
	d.type = type
	d.id = id
	d.count = count
	d.skyshard_count = skyshard_count
	d.skyshard_power = skyshard_power
	return d

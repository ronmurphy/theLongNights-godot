
const TYPE_BLOCK = 0
const TYPE_ITEM = 1

var type := TYPE_BLOCK
var id := 0
var count := 1  # Stack count for consumables (torches), 1 = infinite for tools/weapons

# TODO Can't type hint self
func duplicate():
	var d = get_script().new()
	d.type = type
	d.id = id
	d.count = count
	return d

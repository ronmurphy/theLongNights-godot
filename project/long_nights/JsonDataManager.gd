extends Node

## Central cache for all JSON data
var _json_cache: Dictionary = {}  # {key: parsed_data}

## Known JSON file paths
const JSON_PATHS = {
	"entities": "res://assets/art/entities/entities.json",
	"recipes": "res://assets/data/recipes_database.json",
	"blueprints": "res://assets/data/blueprints.json",
	"companion_intro": "res://assets/data/dialogues/companion_intro.json",
	"personalityQuiz": "res://assets/data/personalityQuiz.json",
	"tutorialScripts": "res://assets/data/tutorialScripts.json",
	"plans": "res://assets/data/plans.json",
	"companion_introduction": "res://assets/data/companion_introduction.json"
}

func get_data(key: String) -> Dictionary:
	"""Get cached JSON data by key. Loads from disk on first request."""
	if _json_cache.has(key):
		return _json_cache[key]

	if not JSON_PATHS.has(key):
		push_error("JsonDataManager: Unknown key '%s'" % key)
		return {}

	var path = JSON_PATHS[key]
	var data = _load_json_file(path)
	_json_cache[key] = data
	return data

func _load_json_file(path: String) -> Dictionary:
	"""Load and parse JSON file from disk."""
	if not ResourceLoader.exists(path):
		push_error("JsonDataManager: File not found: %s" % path)
		return {}

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("JsonDataManager: Cannot open file: %s" % path)
		return {}

	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	if error:
		push_error("JsonDataManager: Parse error in %s" % path)
		return {}

	return json.data if json.data is Dictionary else {}

func clear_cache(key: String = "") -> void:
	"""Clear specific cache or all caches (for testing)."""
	if key.is_empty():
		_json_cache.clear()
	elif _json_cache.has(key):
		_json_cache.erase(key)

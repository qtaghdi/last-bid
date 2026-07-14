class_name CharacterAssetResolver
extends RefCounted

const CHARACTER_ROOT: String = "res://assets/characters"

static var _portrait_cache: Dictionary = {}

static func portrait_path(character_id: StringName) -> String:
	var normalized_id: String = String(character_id).strip_edges().to_lower()
	if (
		normalized_id.is_empty()
		or normalized_id.contains("/")
		or normalized_id.contains("\\")
		or normalized_id.contains("..")
	):
		return ""
	return "%s/%s/portrait.png" % [CHARACTER_ROOT, normalized_id]

static func load_portrait(character_id: StringName) -> Texture2D:
	var path: String = portrait_path(character_id)
	if path.is_empty():
		return null
	if _portrait_cache.has(path):
		return _portrait_cache[path] as Texture2D
	if not ResourceLoader.exists(path, "Texture2D"):
		_portrait_cache[path] = null
		return null
	var texture: Texture2D = ResourceLoader.load(path, "Texture2D") as Texture2D
	_portrait_cache[path] = texture
	return texture

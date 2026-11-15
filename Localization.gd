extends RefCounted
## Registers language catalogs with Godot's translation server.
const LANGUAGE_CODES: Array[String] = ["es", "en"]
var locale: String = "es"
var catalogs: Dictionary = {}
var migration: Dictionary = {}
var translations: Array[Translation] = []

func initialize() -> void:
	for code in LANGUAGE_CODES:
		var path: String="res://locales/%s.json" % code
		var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
		if not parsed is Dictionary:
			push_error("Invalid localization catalog: "+path)
			continue
		catalogs[code]=parsed
		var translation:=Translation.new()
		translation.locale=code
		for key in parsed:
			translation.add_message(StringName(key),StringName(str(parsed[key])))
		translations.append(translation)
		TranslationServer.add_translation(translation)
	var legacy: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://locales/save_migration.json"))
	if legacy is Dictionary: migration=legacy
	set_language("es")

func set_language(code: String) -> void:
	locale=code if LANGUAGE_CODES.has(code) else "es"
	TranslationServer.set_locale(locale)

func migrate_action_keys(values: Dictionary) -> Dictionary:
	var result: Dictionary=values.duplicate(true)
	for entry in migration.get("actions",[]):
		if result.has(entry.previous):
			if not result.has(entry.current): result[entry.current]=result[entry.previous]
			result.erase(entry.previous)
	return result

func dispose() -> void:
	for translation in translations:
		TranslationServer.remove_translation(translation)
	translations.clear()

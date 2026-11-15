extends RefCounted
## Loads the first available texture from a list of candidate paths.
## Imported resources are preferred; raw files are decoded at runtime so newly
## dropped images work before the editor has imported them.

static func load_texture(paths: PackedStringArray) -> Texture2D:
	for path in paths:
		if ResourceLoader.exists(path):
			var resource: Resource=load(path)
			if resource is Texture2D:return resource
		elif FileAccess.file_exists(path):
			var image:=Image.new()
			var error: int=OK
			if path.get_extension().to_lower()=="svg":
				error=image.load_svg_from_string(FileAccess.get_file_as_string(path),2.0)
			else:
				error=image.load(path)
			if error==OK and not image.is_empty():
				return ImageTexture.create_from_image(image)
	return null

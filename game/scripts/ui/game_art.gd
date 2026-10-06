class_name GameArt
extends RefCounted

## Centralized existing artwork under res://Images only.
## Paths use the real filenames in that folder. Nothing is invented.

const SCREEN := {
	"splash": "res://Images/Dollar Mania_ Run, Win, Repeat (1).png",
	"dashboard": "res://Images/Golden Road to the Money City.png",
	"gameplay": "res://Images/Neon Casino Fortune Awaits.png",
}

## Game slug → exact existing image path in res://Images.
const GAMES := {
	"fruit-spin": "res://Images/Gemini_Generated_Image_oi6udxoi6udxoi6u (1).jpg",
	"diamond-spin": "res://Images/Gemini_Generated_Image_j3cjemj3cjemj3cj.jpg",
	"lucky-dollar": "res://Images/Gemini_Generated_Image_y1akewy1akewy1ak.jpg",
	"scratch-mania": "res://Images/Gemini_Generated_Image_n9kkyan9kkyan9kk.jpg",
	"lucky-wheel": "res://Images/Gemini_Generated_Image_hrgg6thrgg6thrgg (1).jpg",
	"coin-flip": "res://Images/Gemini_Generated_Image_ejtmm3ejtmm3ejtm.jpg",
	"treasure-box": "res://Images/Gemini_Generated_Image_8qlcn08qlcn08qlc.jpg",
	"cash-match": "res://Images/Gemini_Generated_Image_fejdc5fejdc5fejd.jpg",
	"diamond-drop": "res://Images/Gemini_Generated_Image_j3cjemj3cjemj3cj.jpg",
	"bonus-burst": "res://Images/Gemini_Generated_Image_b6l6ksb6l6ksb6l6.jpg",
	"jackpot-wheel": "res://Images/Gemini_Generated_Image_oi6udxoi6udxoi6u.jpg",
	"mystery-box": "res://Images/Gemini_Generated_Image_8qlcn08qlcn08qlc.jpg",
	"dollar-rush": "res://Images/Gemini_Generated_Image_n9kkyan9kkyan9kk (4).jpg",
	"fishing": "res://Images/Gemini_Generated_Image_qed0ijqed0ijqed0.jpg",
	"target-blast": "res://Images/Gemini_Generated_Image_b6l6ksb6l6ksb6l6.jpg",
	"aeroplane-rush": "res://Images/Gemini_Generated_Image_hrgg6thrgg6thrgg (1).jpg",
	"bottle-blast": "res://Images/Gemini_Generated_Image_n9kkyan9kkyan9kk (2).jpg",
	"golden-fortune": "res://Images/Gemini_Generated_Image_n9kkyan9kkyan9kk (4).jpg",
	"lucky-spin": "res://Images/Gemini_Generated_Image_y1akewy1akewy1ak.jpg",
	"prize-spinner": "res://Images/Gemini_Generated_Image_n9kkyan9kkyan9kk (2).jpg",
	"higher-card": "res://Images/Gemini_Generated_Image_n9kkyan9kkyan9kk (3).jpg",
	"dice": "res://Images/Gemini_Generated_Image_n9kkyan9kkyan9kk (1).jpg",
	"lucky-number": "res://Images/Gemini_Generated_Image_hrgg6thrgg6thrgg.jpg",
}

## Keep BANNERS as an alias so older callers keep working.
const BANNERS := GAMES


static func screen_path(kind: String) -> String:
	return str(SCREEN.get(kind, ""))


static func path_for(slug: String) -> String:
	return str(GAMES.get(slug, ""))


static func banner(slug: String) -> Texture2D:
	var art := texture(path_for(slug))
	if art != null:
		return art
	# Keep the card visible even if a game-specific asset fails.
	return screen_texture("gameplay")


static func screen_texture(kind: String) -> Texture2D:
	return texture(screen_path(kind))


static func texture(path: String) -> Texture2D:
	if path.strip_edges() == "":
		return null
	if ResourceLoader.exists(path):
		var resource := load(path)
		if resource is Texture2D:
			return resource
	# Fallback for editor/runtime edge cases where the import remap is slow.
	if FileAccess.file_exists(path):
		var image := Image.new()
		var err := image.load(path)
		if err == OK:
			return ImageTexture.create_from_image(image)
	push_warning("GameArt could not load texture: %s" % path)
	return null


static func verify_mapping() -> Array[String]:
	var report: Array[String] = []
	for kind in SCREEN.keys():
		var path := screen_path(str(kind))
		var ok := ResourceLoader.exists(path)
		report.append("%s → %s [%s]" % [str(kind), path, "OK" if ok else "MISSING"])
		print("SCREEN ", report[report.size() - 1])
	for slug in GAMES.keys():
		var path := path_for(str(slug))
		var ok := ResourceLoader.exists(path)
		report.append("%s → %s [%s]" % [str(slug), path, "OK" if ok else "MISSING"])
		print("GAME ", report[report.size() - 1])
	return report

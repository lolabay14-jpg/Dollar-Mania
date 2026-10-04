class_name GameArt
extends RefCounted

## Existing banner files in res://Images. Paths stay where they were added.

const BANNERS := {
	"fruit-spin": "res://Images/Gemini_Generated_Image_oi6udxoi6udxoi6u (1).jpg",
	"lucky-wheel": "res://Images/Gemini_Generated_Image_hrgg6thrgg6thrgg (1).jpg",
	"prize-spinner": "res://Images/Gemini_Generated_Image_n9kkyan9kkyan9kk (2).jpg",
	"jackpot-wheel": "res://Images/Gemini_Generated_Image_oi6udxoi6udxoi6u.jpg",
	"lucky-dollar": "res://Images/Gemini_Generated_Image_y1akewy1akewy1ak.jpg",
	"lucky-spin": "res://Images/Gemini_Generated_Image_y1akewy1akewy1ak.jpg",
	"golden-fortune": "res://Images/Gemini_Generated_Image_n9kkyan9kkyan9kk (4).jpg",
	"dollar-rush": "res://Images/Gemini_Generated_Image_n9kkyan9kkyan9kk (4).jpg",
	"fishing": "res://Images/Gemini_Generated_Image_qed0ijqed0ijqed0.jpg",
	"higher-card": "res://Images/Gemini_Generated_Image_n9kkyan9kkyan9kk (3).jpg",
	"scratch-mania": "res://Images/Gemini_Generated_Image_n9kkyan9kkyan9kk.jpg",
	"dice": "res://Images/Gemini_Generated_Image_n9kkyan9kkyan9kk (1).jpg",
	"lucky-number": "res://Images/Gemini_Generated_Image_hrgg6thrgg6thrgg.jpg",
	"coin-flip": "res://Images/Gemini_Generated_Image_ejtmm3ejtmm3ejtm.jpg",
	"treasure-box": "res://Images/Gemini_Generated_Image_8qlcn08qlcn08qlc.jpg",
	"cash-match": "res://Images/Gemini_Generated_Image_fejdc5fejdc5fejd.jpg",
	"diamond-drop": "res://Images/Gemini_Generated_Image_j3cjemj3cjemj3cj.jpg",
	"bonus-burst": "res://Images/Gemini_Generated_Image_b6l6ksb6l6ksb6l6.jpg",
}


static func banner(slug: String) -> Texture2D:
	var path := str(BANNERS.get(slug, ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	var resource := load(path)
	return resource if resource is Texture2D else null

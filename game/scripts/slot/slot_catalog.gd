class_name SlotCatalog
extends RefCounted

## All slot rules live here so payouts and difficulty can change without touching UI.
## Virtual credits only. These numbers are not real-money odds.

static func games() -> Array:
	return [lucky_dollar(), golden_fortune(), dollar_rush()]


static func get_game(game_id: String) -> Dictionary:
	for game in games():
		if str(game["id"]) == game_id:
			return game.duplicate(true)
	return {}


static func lucky_dollar() -> Dictionary:
	return {
		"id": "lucky-dollar",
		"name": "Lucky Dollar",
		"blurb": "Classic 3-reel slot.",
		"difficulty": "EASY",
		"min_bet": 1,
		"max_bet": 100,
		"bet_step": 1,
		"stop_times": [0.85, 1.25, 1.65],
		"art": ["coin", "dollar", "star"],
		"accent": Color("F5C542"),
		"weights": {"coin": 26, "dollar": 22, "star": 16, "diamond": 10, "seven": 7, "bonus": 3},
		"three_kind": {"coin": 3, "dollar": 5, "star": 8, "diamond": 14, "seven": 25, "bonus": 40},
		"pair": {"coin": 1, "dollar": 2, "star": 2, "bonus": 4},
	}


static func golden_fortune() -> Dictionary:
	return {
		"id": "golden-fortune",
		"name": "Golden Fortune",
		"blurb": "Harder reels with richer special symbols.",
		"difficulty": "MEDIUM",
		"min_bet": 5,
		"max_bet": 500,
		"bet_step": 5,
		"stop_times": [1.05, 1.5, 2.0],
		"art": ["diamond", "seven", "bonus"],
		"accent": Color("E2B15A"),
		"weights": {"coin": 30, "dollar": 24, "star": 16, "diamond": 8, "seven": 5, "bonus": 2},
		"three_kind": {"coin": 3, "dollar": 5, "star": 10, "diamond": 18, "seven": 30, "bonus": 50},
		"pair": {"dollar": 2, "diamond": 4, "seven": 6, "bonus": 8},
	}


static func dollar_rush() -> Dictionary:
	return {
		"id": "dollar-rush",
		"name": "Dollar Rush",
		"blurb": "Faster spins with higher risk and reward.",
		"difficulty": "HARD",
		"min_bet": 10,
		"max_bet": 1000,
		"bet_step": 10,
		"stop_times": [0.55, 0.8, 1.05],
		"art": ["bonus", "seven", "coin"],
		"accent": Color("3DDC97"),
		"weights": {"coin": 28, "dollar": 18, "star": 14, "diamond": 8, "seven": 6, "bonus": 5},
		"three_kind": {"coin": 2, "dollar": 5, "star": 8, "diamond": 16, "seven": 30, "bonus": 60},
		"pair": {"dollar": 2, "star": 3, "seven": 5, "bonus": 8},
	}


static func display_name(symbol_id: String) -> String:
	match symbol_id:
		"coin":
			return "Coin"
		"dollar":
			return "Dollar"
		"star":
			return "Star"
		"diamond":
			return "Diamond"
		"seven":
			return "Seven"
		"bonus":
			return "Bonus"
		_:
			return symbol_id

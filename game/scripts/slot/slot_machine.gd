class_name SlotMachine
extends RefCounted

## Pure spin math. The screen only animates the grid this returns.
## The center row of each reel is the payline.

static func spin(rules: Dictionary, bet: int) -> Dictionary:
	var grid := roll(rules)
	var outcome := evaluate(rules, grid, bet)
	outcome["grid"] = grid
	return outcome


static func roll(rules: Dictionary) -> Array:
	var grid: Array = []
	for _reel in 3:
		var column: Array = []
		for _row in 3:
			column.append(random_symbol(rules))
		grid.append(column)
	return grid


static func random_symbol(rules: Dictionary) -> String:
	var weights: Dictionary = rules["weights"]
	var total := 0
	for symbol_id in weights.keys():
		total += int(weights[symbol_id])
	if total <= 0:
		return "coin"
	var pick := randi_range(1, total)
	var cursor := 0
	for symbol_id in weights.keys():
		cursor += int(weights[symbol_id])
		if pick <= cursor:
			return str(symbol_id)
	return "coin"


static func evaluate(rules: Dictionary, grid: Array, bet: int) -> Dictionary:
	var line: Array[String] = []
	for reel in grid:
		line.append(str(reel[1]))
	if line[0] == line[1] and line[1] == line[2]:
		var triple := int(rules["three_kind"].get(line[0], 0))
		if triple > 0:
			return _win(bet, triple, "Three %s" % SlotCatalog.display_name(line[0]), [0, 1, 2])
	var pairs: Dictionary = rules.get("pair", {})
	for symbol_id in pairs.keys():
		var matched: Array[int] = []
		for index in 3:
			if line[index] == str(symbol_id):
				matched.append(index)
		if matched.size() == 2:
			return _win(bet, int(pairs[symbol_id]), "Two %s" % SlotCatalog.display_name(str(symbol_id)), matched)
	return {
		"won": false,
		"payout": 0,
		"multiplier": 0,
		"title": "No win",
		"highlights": [],
	}


static func _win(bet: int, multiplier: int, title: String, reels: Array) -> Dictionary:
	return {
		"won": true,
		"payout": bet * multiplier,
		"multiplier": multiplier,
		"title": "%s  ·  %dx" % [title, multiplier],
		"highlights": reels,
	}

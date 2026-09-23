class_name CustomerLines

## What a customer says out loud at the mirror, in their own voice. The tailor's notepad
## carries the fix (DressCode notes); these lines only say what is wrong, by the temper of
## the occasion: a wedding frets, a funeral keeps its voice down, business is short with
## you and a party is loud. `{value}` is the offending colour, pattern or cloth. Each list
## has two or three variants, picked by a seed the caller moves on per ask, so the same
## customer doesn't say the same thing twice running.

## Ways a design breaks the brief, one spoken list each.
enum Kind {
	JACKET_COLOR,
	JACKET_NEEDS_PATTERN,
	JACKET_PATTERN,
	JACKET_CLOTH,
	TROUSERS_MATCH,
	TROUSERS_PATTERN,
	SHIRT_COLOR,
	SHIRT_PATTERN,
	OVER_BUDGET,
}

## Spreads the kinds apart, so two objections on the same ask don't all take variant 0.
const KIND_SALT := 7

## Kind -> occasion -> variants.
const LINES := {
	Kind.JACKET_COLOR:
	{
		Enums.Occasion.WEDDING:
		[
			"{value}, at a wedding? The bride's mother will notice.",
			"{value}. In the photographs. For forty years.",
			"Can I stand up there in {value}? I don't think I can.",
		],
		Enums.Occasion.FUNERAL:
		[
			"{value}, to a funeral? My aunt would never forgive me.",
			"Not {value}. Not for this.",
			"He'd have laughed at {value}. The rest of them won't.",
		],
		Enums.Occasion.BUSINESS:
		[
			"{value}. The board would laugh me out of the room.",
			"No. {value} says estate agent.",
			"{value}. Not in the boardroom.",
		],
		Enums.Occasion.PARTY:
		[
			"{value}? I'd look like the man who reads the meter.",
			"Who wears {value} to a party? My father. That's who.",
		],
	},
	Kind.JACKET_NEEDS_PATTERN:
	{
		Enums.Occasion.WEDDING:
		[
			"It's so plain. They'll think I didn't try.",
			"Plain as a bus ticket. Is that all right? It isn't, is it.",
		],
		Enums.Occasion.FUNERAL:
		[
			"Plain. He'd have hated plain.",
			"He never wore a plain thing in his life. I won't start at his funeral.",
		],
		Enums.Occasion.BUSINESS:
		[
			"Too plain. Nobody remembers plain.",
			"Plain. I'd look like the new clerk in accounts.",
		],
		Enums.Occasion.PARTY:
		[
			"A plain jacket at a party. I'd vanish into the wallpaper.",
			"Plain? Nobody asks plain to dance.",
		],
	},
	Kind.JACKET_PATTERN:
	{
		Enums.Occasion.WEDDING:
		[
			"{value}? What if it goes funny in the photographs?",
			"{value} at a wedding. Is that done? I don't think that's done.",
		],
		Enums.Occasion.FUNERAL:
		[
			"{value}. People would look at the suit instead of him.",
			"Not {value}. Something quieter.",
		],
		Enums.Occasion.BUSINESS:
		[
			"{value}. Wrong message.",
			"{value}? I sell bonds, not racehorses.",
		],
		Enums.Occasion.PARTY:
		[
			"{value} is for Mondays.",
			"{value}. You'd nod off looking at me.",
		],
	},
	Kind.JACKET_CLOTH:
	{
		Enums.Occasion.WEDDING:
		[
			"That cloth would have me sweating through the vows.",
			"{value}? I'll faint before the rings come out.",
		],
		Enums.Occasion.FUNERAL:
		[
			"{value}. I'll be standing in a churchyard for an hour.",
			"Not this cloth. The chapel is cold and the vicar talks.",
		],
		Enums.Occasion.BUSINESS:
		[
			"{value}. I'm at a desk ten hours a day in this.",
			"Wrong cloth. It'll look slept in by eleven.",
		],
		Enums.Occasion.PARTY:
		[
			"{value}? I'll be dancing in this. For hours.",
			"I'd boil in {value} by the second song.",
		],
	},
	Kind.TROUSERS_MATCH:
	{
		Enums.Occasion.WEDDING:
		[
			"These trousers belong to another jacket. Somebody will say so.",
			"The trousers don't match. Will anyone notice? They'll notice.",
		],
		Enums.Occasion.FUNERAL:
		[
			"The trousers don't match. They'd see it at the graveside.",
			"Odd trousers. Not today.",
		],
		Enums.Occasion.BUSINESS:
		[
			"Trousers don't match. That's two suits.",
			"Odd trousers. Looks like a Saturday.",
		],
		Enums.Occasion.PARTY:
		[
			"The trousers came from a different party.",
			"Odd trousers? Only if I meant it. I didn't mean it.",
		],
	},
	Kind.TROUSERS_PATTERN:
	{
		Enums.Occasion.WEDDING:
		[
			"The trousers are doing something the jacket isn't.",
			"Two patterns fighting. At the wedding breakfast, of all places.",
		],
		Enums.Occasion.FUNERAL:
		[
			"Those trousers would talk through the eulogy.",
			"The trousers are louder than the jacket.",
		],
		Enums.Occasion.BUSINESS:
		[
			"Trousers are too busy.",
			"Jacket says one thing, trousers another.",
		],
		Enums.Occasion.PARTY:
		[
			"The trousers are shouting over the jacket.",
			"Two patterns at once. Even I think that's a lot.",
		],
	},
	Kind.SHIRT_COLOR:
	{
		Enums.Occasion.WEDDING:
		[
			"A {value} shirt. What if I clash with the flowers?",
			"{value}? Someone will ask if I dressed in the dark.",
		],
		Enums.Occasion.FUNERAL:
		[
			"A {value} shirt. I couldn't.",
			"{value}, under that? I'd look like I'd come from a party.",
		],
		Enums.Occasion.BUSINESS:
		[
			"{value} shirt. No.",
			"A {value} shirt in a meeting? Next.",
		],
		Enums.Occasion.PARTY:
		[
			"A {value} shirt! It's a party, not the dentist's.",
			"{value}? I wear {value} to the office.",
		],
	},
	Kind.SHIRT_PATTERN:
	{
		Enums.Occasion.WEDDING:
		[
			"{value} on the shirt. Is that too much? It feels like too much.",
			"Not {value}. My hands are shaking enough as it is.",
		],
		Enums.Occasion.FUNERAL:
		[
			"{value}. Not on the day.",
			"A {value} shirt would catch the eye. I'd rather it didn't.",
		],
		Enums.Occasion.BUSINESS:
		[
			"{value}. Too loud for the office.",
			"Not {value}. The chairman wears {value}.",
		],
		Enums.Occasion.PARTY:
		[
			"{value}? The shirt's half the fun.",
			"Not {value}. I've a name to keep up.",
		],
	},
}
## Money talks the same at every occasion.
const BUDGET_LINES := [
	"That's more than I've got. Quite a lot more.",
	"I can't pay that. Not this month.",
	"At that price I'd have to sell the car.",
]
## A yes, by occasion.
const HAPPY := {
	Enums.Occasion.WEDDING:
	[
		"Yes. I'll take it before I change my mind.",
		"That's it. Can I try it on again at home, to be sure?",
	],
	Enums.Occasion.FUNERAL:
	[
		"Yes. That will do. Thank you.",
		"That's right. He'd have approved of the lapels.",
	],
	Enums.Occasion.BUSINESS:
	[
		"Good. Ring me when it's ready.",
		"Fine. Send the bill to the office.",
	],
	Enums.Occasion.PARTY:
	[
		"Now that's a suit. Somebody pour me a drink.",
		"Yes! Wrap it. No, don't wrap it, I'll wear it.",
	],
}
## A yes in the colour they asked for, by occasion.
const HAPPY_LIKED := {
	Enums.Occasion.WEDDING:
	[
		"{value}, like I asked. My brother can keep his.",
		"You found me {value}. Wrap it before I ask for something else.",
	],
	Enums.Occasion.FUNERAL:
	[
		"{value}. He always said I should wear {value}.",
		"{value}, as I asked. That's right for him.",
	],
	Enums.Occasion.BUSINESS:
	[
		"{value}. Good. Ring me when it's ready.",
		"{value}, as asked. Send the bill to the office.",
	],
	Enums.Occasion.PARTY:
	[
		"There's my {value}! They'll hear me coming.",
		"Look at that {value}. I'm wearing it home.",
	],
}


## What they say about one objection. `value` is the colour, pattern or cloth word.
static func say(kind: int, occasion: int, value: String, voice_seed: int) -> String:
	var pool: Array = BUDGET_LINES
	if kind != Kind.OVER_BUDGET:
		var by_occasion: Dictionary = LINES.get(kind, {})
		pool = by_occasion.get(occasion, [])
	return _pick(pool, voice_seed + kind * KIND_SALT, value)


## What they say to a suit they'll take; `liked` is the colour word they asked for, or "".
static func happy(occasion: int, voice_seed: int, liked := "") -> String:
	var by_occasion: Dictionary = HAPPY_LIKED if liked != "" else HAPPY
	return _pick(by_occasion.get(occasion, []), voice_seed, liked)


## How many variants a kind has for an occasion (for tests).
static func variants(kind: int, occasion: int) -> int:
	if kind == Kind.OVER_BUDGET:
		return BUDGET_LINES.size()
	var by_occasion: Dictionary = LINES.get(kind, {})
	return (by_occasion.get(occasion, []) as Array).size()


static func _pick(pool: Array, voice_seed: int, value: String) -> String:
	if pool.is_empty():
		return ""
	var line := str(pool[posmod(voice_seed, pool.size())]).format({"value": value})
	# `{value}` can open any sentence ("No. Brown says estate agent."), so each gets its
	# capital after the word goes in.
	var out := line.substr(0, 1).to_upper()
	for i in range(1, line.length()):
		var starts := i >= 2 and line[i - 1] == " " and line[i - 2] in [".", "?", "!"]
		out += line[i].to_upper() if starts else line[i]
	return out

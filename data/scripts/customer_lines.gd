class_name CustomerLines

## What a customer says out loud at the mirror, in their own voice. The tailor's notepad
## carries the fix (DressCode notes); these lines only say what is wrong, by the temper of
## the occasion: a wedding frets, a funeral keeps its voice down, business is short with
## you and a party is loud. `{value}` is the offending colour, pattern or cloth. Each list
## has six variants. The shop remembers the last MEMORY lines spoken this session (by any
## customer) and picks one nobody has said lately, so the same line doesn't come round
## again for a while.
##
## Every line has to make sense on its own, next to the notepad's shorthand: no unnamed
## "he", no aunt, no chairman. The player never meets them.

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

## Spreads the kinds apart, so two objections on the same ask don't all start at variant 0.
const KIND_SALT := 7
## How many spoken lines the shop remembers before one may come round again.
const MEMORY := 60

## Kind -> occasion -> variants.
const LINES := {
	Kind.JACKET_COLOR:
	{
		Enums.Occasion.WEDDING:
		[
			"{value}, at a wedding? Is that allowed? I don't think it's allowed.",
			"{value}. In the photographs. For forty years.",
			"Can I stand up there in {value}? I don't think I can.",
			"Everyone will be in something else and I'll be in {value}.",
			"{value}. What if I'm the only one? I'll be the only one.",
			"I'll be at the front, in {value}. Where everyone can see.",
		],
		Enums.Occasion.FUNERAL:
		[
			"Not {value}. Not for this.",
			"{value}, to a funeral? I'd never hear the end of it.",
			"{value}. People would talk after.",
			"I can't stand at a graveside in {value}.",
			"{value}. No. Something that keeps quiet.",
			"Not {value}. I'd rather nobody noticed me.",
		],
		Enums.Occasion.BUSINESS:
		[
			"{value}. The board would laugh me out of the room.",
			"No. {value} says estate agent.",
			"{value}. Not in the boardroom.",
			"{value}? I'm asking for money, not a round of drinks.",
			"No {value}. I'd lose the account by lunch.",
			"{value}. I'd look like I'd come to fix the lift.",
		],
		Enums.Occasion.PARTY:
		[
			"{value}? I'd look like the man who reads the meter.",
			"{value}? I'd be mistaken for a waiter.",
			"Who wears {value} to a party? Nobody I'd dance with.",
			"{value}! I'm going to a party, not a board meeting.",
			"In {value} I'd be holding up the wall all night.",
			"{value}? I want to be seen from the other side of the room.",
		],
	},
	Kind.JACKET_NEEDS_PATTERN:
	{
		Enums.Occasion.WEDDING:
		[
			"It's so plain. They'll think I didn't try.",
			"Plain as a bus ticket. Is that all right? It isn't, is it.",
			"Plain. What if I'm mistaken for an usher?",
			"It's very plain. Should it be this plain? I'll look like I forgot.",
			"Nothing on it at all. I'll disappear into the pews.",
			"Plain. On the one day I'm meant to look like I tried.",
		],
		Enums.Occasion.FUNERAL:
		[
			"Plain. It looks like I took the first thing in the wardrobe.",
			"Too plain. I want it to look chosen.",
			"Plain. I'd look like I'd come with the hearse.",
			"It's very plain. I wanted a little care in it.",
			"Plain. It looks borrowed.",
			"Plain. It looks like a uniform on me.",
		],
		Enums.Occasion.BUSINESS:
		[
			"Too plain. Nobody remembers plain.",
			"Plain. I'd look like the new clerk in accounts.",
			"Plain. Forgotten by the second handshake.",
			"No pattern. Looks cheap across a desk.",
			"Plain. I'm selling, not filing.",
			"Too plain. It says junior.",
		],
		Enums.Occasion.PARTY:
		[
			"A plain jacket at a party. I'd vanish into the wallpaper.",
			"Plain? Nobody asks plain to dance.",
			"Plain! I could wear this to have a tooth out.",
			"Where's the pattern? It's a party, not a job interview.",
			"It's plain. I want people to point at me across the room.",
			"Plain. Nobody will spot me from the bar.",
		],
	},
	Kind.JACKET_PATTERN:
	{
		Enums.Occasion.WEDDING:
		[
			"{value}? What if it goes funny in the photographs?",
			"{value} at a wedding. Is that done? I don't think that's done.",
			"{value}. Everyone will ask why. I won't know what to say.",
			"{value}. The whole church will be looking at my back.",
			"{value}? I'll be up at the front in that.",
			"Not {value}. I'll be nervous enough without it.",
		],
		Enums.Occasion.FUNERAL:
		[
			"{value}. People will be looking at me, not the service.",
			"Not {value}. Something quieter.",
			"{value}. It's too cheerful for the day.",
			"I can't sit in the front pew in {value}.",
			"{value}. Somebody would say something at the wake.",
			"Not {value}. I don't want to be remembered for the suit.",
		],
		Enums.Occasion.BUSINESS:
		[
			"{value}. Wrong message.",
			"{value}? I sell bonds, not racehorses.",
			"{value}. They'll think I'm there to sell them a car.",
			"No {value}. Too much for a Tuesday.",
			"{value}. Not across a desk from a client.",
			"{value}? I'd never get past the doorman.",
		],
		Enums.Occasion.PARTY:
		[
			"{value} is for Mondays.",
			"{value}. You'd nod off looking at me.",
			"{value}? That's what I wear to the bank.",
			"{value}. Have you ever been to a party?",
			"{value}. I'd look like I came straight from work.",
			"Not {value}. I want a bit of noise in it.",
		],
	},
	Kind.JACKET_CLOTH:
	{
		Enums.Occasion.WEDDING:
		[
			"{value}? What if it creases before the photographs?",
			"Not {value}. I'm in it from the church to the last dance.",
			"{value}, for the vows? Is that right? It isn't, is it.",
			"That cloth would have me sweating through the vows.",
			"{value}. It feels wrong. I can't say why, but it does.",
			"{value}? Someone at the reception will touch my sleeve and know.",
		],
		Enums.Occasion.FUNERAL:
		[
			"{value}. I'll be standing in a churchyard for an hour.",
			"Not this cloth. The chapel is cold and the service is long.",
			"{value}. It isn't right for the day.",
			"Not {value}. It has to last the service and the wake.",
			"{value}. It looks like I've come from the garden.",
			"Not {value}. I'll be kneeling on stone.",
		],
		Enums.Occasion.BUSINESS:
		[
			"{value}. I'm at a desk ten hours a day in this.",
			"Wrong cloth. It'll look slept in by eleven.",
			"{value}? It'll be shapeless by Thursday.",
			"No {value}. It has to survive a train and three meetings.",
			"{value}. Looks like I own a boat. I don't.",
			"{value}. Not for the office.",
		],
		Enums.Occasion.PARTY:
		[
			"{value}? I'll be dancing in this. For hours.",
			"I'd boil in {value} by the second song.",
			"{value}. Someone will spill a drink on it and it'll show.",
			"Not {value}. I'll be on the dance floor till two.",
			"{value}? It'll be a rag by midnight.",
			"{value}. That's a cloth for sitting still in.",
		],
	},
	Kind.TROUSERS_MATCH:
	{
		Enums.Occasion.WEDDING:
		[
			"These trousers belong to another jacket. Somebody will say so.",
			"The trousers don't match. Will anyone notice? They'll notice.",
			"Odd trousers. In every photograph, from the waist down.",
			"The trousers aren't the same. Is that on purpose? It can't be.",
			"Two halves of two suits. Today of all days.",
			"The trousers are wrong. I'll be standing all day. They'll see.",
		],
		Enums.Occasion.FUNERAL:
		[
			"The trousers don't match. They'd see it at the graveside.",
			"Odd trousers. Not today.",
			"The trousers are from another suit. Not for this.",
			"They don't match. It looks thrown together.",
			"Mismatched. Somebody would notice at the wake.",
			"The trousers are different. I'd rather it all matched, today.",
		],
		Enums.Occasion.BUSINESS:
		[
			"Trousers don't match. That's two suits.",
			"Odd trousers. Looks like a Saturday.",
			"Jacket and trousers disagree. Fix it.",
			"Mismatched. Looks like I lost half a suit.",
			"The trousers aren't the jacket's. Sloppy.",
			"Odd trousers. The client will see before I sit down.",
		],
		Enums.Occasion.PARTY:
		[
			"The trousers came from a different party.",
			"Odd trousers? Only if I meant it. I didn't mean it.",
			"Did the trousers get lost on the way to another jacket?",
			"The trousers don't match. Everyone will think I lost a bet.",
			"Two halves of two suits. Even at a party, no.",
			"Odd trousers. I'll end up in the paper for the wrong reason.",
		],
	},
	Kind.TROUSERS_PATTERN:
	{
		Enums.Occasion.WEDDING:
		[
			"The trousers are doing something the jacket isn't.",
			"Two patterns fighting. At the wedding breakfast, of all places.",
			"{value} trousers? Is that allowed at a wedding?",
			"The {value} on the trousers. People will look down. I know it.",
			"{value} on the legs and not the jacket. Is that a mistake?",
			"Why are the trousers {value}? The jacket isn't.",
		],
		Enums.Occasion.FUNERAL:
		[
			"Those trousers would talk through the eulogy.",
			"The trousers are louder than the jacket.",
			"{value} trousers. Not at a graveside.",
			"Not {value} on the trousers. Keep it quiet.",
			"The trousers draw the eye. I'd rather nothing did.",
			"{value} on the trousers. It looks like a mistake.",
		],
		Enums.Occasion.BUSINESS:
		[
			"Trousers are too busy.",
			"Jacket says one thing, trousers another.",
			"{value} trousers. Golf, not business.",
			"The trousers don't agree with the jacket. No.",
			"No {value} on the trousers. Looks like odds and ends.",
			"{value} legs. I'd look like a bookmaker.",
		],
		Enums.Occasion.PARTY:
		[
			"The trousers are shouting over the jacket.",
			"Two patterns at once. Even I think that's a lot.",
			"{value} trousers! Now the jacket looks shy.",
			"The trousers and the jacket aren't speaking. At a party.",
			"{value} legs. I'd look like a deckchair.",
			"Loud is good. Two kinds of loud is a mess.",
		],
	},
	Kind.SHIRT_COLOR:
	{
		Enums.Occasion.WEDDING:
		[
			"A {value} shirt. What if I clash with the flowers?",
			"{value}? Someone will ask if I dressed in the dark.",
			"A {value} shirt. Will it look wrong next to the bridesmaids?",
			"{value}. What if it looks like I spilled something?",
			"Not a {value} shirt. I'd worry about it all through the vows.",
			"{value}? Is that what people wear now? I don't think it is.",
		],
		Enums.Occasion.FUNERAL:
		[
			"A {value} shirt. I couldn't.",
			"{value}, under that? I'd look like I'd come from a party.",
			"Not {value}. Not today.",
			"A {value} shirt at a graveside. People would whisper.",
			"{value}. Too bright for the church.",
			"{value}. I'd be the only colour in the room.",
		],
		Enums.Occasion.BUSINESS:
		[
			"{value} shirt. No.",
			"A {value} shirt in a meeting? Next.",
			"{value}. They'd think I'd come from the races.",
			"Not {value}. People know me in that building.",
			"Nobody signs anything opposite a {value} shirt.",
			"{value}. Too soft for the office.",
		],
		Enums.Occasion.PARTY:
		[
			"A {value} shirt! It's a party, not the dentist's.",
			"{value}? I wear {value} to the office.",
			"{value}. I'd look like the one who's driving.",
			"A {value} shirt at a party? Give it to a bank clerk.",
			"{value}? Nobody buys a drink for a {value} shirt.",
			"Not {value}. I've worn {value} every day this week.",
		],
	},
	Kind.SHIRT_PATTERN:
	{
		Enums.Occasion.WEDDING:
		[
			"{value} on the shirt. Is that too much? It feels like too much.",
			"Not {value}. My hands are shaking enough as it is.",
			"{value}? Will it do something odd in the photographs?",
			"A {value} shirt at a wedding. Nobody said that was allowed.",
			"{value}. I'll spend the whole service looking down at it.",
			"Is {value} right for a wedding? I keep looking at it.",
		],
		Enums.Occasion.FUNERAL:
		[
			"{value}. Not on the day.",
			"A {value} shirt would catch the eye. I'd rather it didn't.",
			"No {value}. Not at a funeral.",
			"{value} at a graveside. As if I'd forgotten where I was going.",
			"The {value} shows at the cuffs. People would notice.",
			"{value}. It's a shirt for a summer lunch.",
		],
		Enums.Occasion.BUSINESS:
		[
			"{value}. Too loud for the office.",
			"Not {value}. It looks like I've come off a yacht.",
			"{value}. Wrong for a meeting.",
			"A {value} shirt across the table? They'd stop listening.",
			"{value}. I'd look like I sell ice cream.",
			"No {value}. Keep the shirt out of it.",
		],
		Enums.Occasion.PARTY:
		[
			"{value}? The shirt's half the fun.",
			"Not {value}. I've a name to keep up.",
			"{value}. My shirt should be the loudest thing in the room.",
			"{value}! I've got a shirt like that for funerals.",
			"{value}. Is that a shirt for a party or a Sunday?",
			"{value}? Nobody remembers {value} at two in the morning.",
		],
	},
}
## Money talks the same at every occasion.
const BUDGET_LINES := [
	"That's more than I've got. Quite a lot more.",
	"I can't pay that. Not this month.",
	"At that price I'd have to sell the car.",
	"That's two months' rent.",
	"How much? I'd be eating bread till Easter.",
	"I'd have to ask the bank. The bank would say no.",
]
## A yes, by occasion.
const HAPPY := {
	Enums.Occasion.WEDDING:
	[
		"Yes. I'll take it before I change my mind.",
		"That's it. Can I try it on again at home, to be sure?",
		"Yes. I think yes. Yes.",
		"That's the one. I'll stop biting my nails now.",
		"Yes. Cross that off the list. Only forty things left.",
		"That's right. That's exactly right. Isn't it? It is.",
	],
	Enums.Occasion.FUNERAL:
	[
		"Yes. That will do. Thank you.",
		"That's right. Nobody will look twice at it.",
		"Yes. Thank you for taking the time.",
		"That's the one. I'll collect it myself.",
		"Good. It won't be in anyone's way.",
		"Yes. It'll do for the day and after.",
	],
	Enums.Occasion.BUSINESS:
	[
		"Good. Ring me when it's ready.",
		"Fine. Send the bill to the office.",
		"That'll do. Friday?",
		"Right. Done. What do I sign?",
		"Good. That looks like money.",
		"Yes. Wrap it. I've a train at four.",
	],
	Enums.Occasion.PARTY:
	[
		"Now that's a suit. Somebody pour me a drink.",
		"Yes! Wrap it. No, don't wrap it, I'll wear it.",
		"That's it. They'll hear about this suit on the next street.",
		"Yes. I'll be the last one to leave in that.",
		"Look at it. I'm going to need a bigger party.",
		"That's the one. Tell nobody where I got it.",
	],
}
## A yes in the colour they asked for, by occasion.
const HAPPY_LIKED := {
	Enums.Occasion.WEDDING:
	[
		"{value}, like I asked. Wrap it before I ask for something else.",
		"You found me {value}. I can breathe again.",
		"{value}. That's the one I saw in my head. Yes.",
		"{value}, and it fits. I didn't think I'd get both.",
		"It's {value}. As I pictured it. Don't change a thing.",
		"{value}. Yes. Before somebody tells me otherwise.",
	],
	Enums.Occasion.FUNERAL:
	[
		"{value}, as I asked. Thank you.",
		"{value}. That's right for the day.",
		"Yes. {value}, and nothing loud about it.",
		"{value}. It'll do what it has to.",
		"That's the {value} I meant. Thank you for listening.",
		"{value}. Good. Nobody will remark on it.",
	],
	Enums.Occasion.BUSINESS:
	[
		"{value}. Good. Ring me when it's ready.",
		"{value}, as asked. Send the bill to the office.",
		"{value}. Correct. Friday?",
		"Right, {value}. That's the brief. Done.",
		"{value}. Looks like I close deals. Good.",
		"{value}, first time. Somebody listens. Wrap it.",
	],
	Enums.Occasion.PARTY:
	[
		"There's my {value}! They'll hear me coming.",
		"Look at that {value}. I'm wearing it home.",
		"{value}! I asked for {value} and here it is.",
		"{value}, like I said. The whole room's going to see this.",
		"That {value} could stop traffic. Good.",
		"{value}. Pour me something, I'm celebrating.",
	],
}

## Line ids ("slot/index") spoken this session by anyone, oldest first, at most MEMORY.
static var _recent: Array[String] = []


## What they say about one objection. `value` is the colour, pattern or cloth word.
## `voice_seed` only breaks ties among lines nobody has said lately.
static func say(kind: int, occasion: int, value: String, voice_seed: int) -> String:
	var pool: Array = BUDGET_LINES
	var slot := "%d/_" % kind
	if kind != Kind.OVER_BUDGET:
		var by_occasion: Dictionary = LINES.get(kind, {})
		pool = by_occasion.get(occasion, [])
		slot = "%d/%d" % [kind, occasion]
	return _pick(pool, slot, voice_seed + kind * KIND_SALT, value)


## What they say to a suit they'll take; `liked` is the colour word they asked for, or "".
static func happy(occasion: int, voice_seed: int, liked := "") -> String:
	var by_occasion: Dictionary = HAPPY_LIKED if liked != "" else HAPPY
	var slot := "%s/%d" % ["liked" if liked != "" else "happy", occasion]
	return _pick(by_occasion.get(occasion, []), slot, voice_seed, liked)


## How many variants a kind has for an occasion (for tests).
static func variants(kind: int, occasion: int) -> int:
	if kind == Kind.OVER_BUDGET:
		return BUDGET_LINES.size()
	var by_occasion: Dictionary = LINES.get(kind, {})
	return (by_occasion.get(occasion, []) as Array).size()


## Forget what has been said (for tests).
static func reset() -> void:
	_recent.clear()


static func _pick(pool: Array, slot: String, voice_seed: int, value: String) -> String:
	if pool.is_empty():
		return ""
	var index := _choose(pool.size(), slot, voice_seed)
	var id := "%s/%d" % [slot, index]
	_recent.erase(id)
	_recent.append(id)
	while _recent.size() > MEMORY:
		_recent.pop_front()
	var line := str(pool[index]).format({"value": value})
	# `{value}` can open any sentence ("No. Brown says estate agent."), so each gets its
	# capital after the word goes in.
	var out := line.substr(0, 1).to_upper()
	for i in range(1, line.length()):
		var starts := i >= 2 and line[i - 1] == " " and line[i - 2] in [".", "?", "!"]
		out += line[i].to_upper() if starts else line[i]
	return out


## The first variant from the seed on that nobody has said lately; if all have been, the
## one said longest ago.
static func _choose(count: int, slot: String, voice_seed: int) -> int:
	var start := posmod(voice_seed, count)
	var oldest := start
	var oldest_at := _recent.size()
	for i in count:
		var index := (start + i) % count
		var at := _recent.find("%s/%d" % [slot, index])
		if at < 0:
			return index
		if at < oldest_at:
			oldest_at = at
			oldest = index
	return oldest

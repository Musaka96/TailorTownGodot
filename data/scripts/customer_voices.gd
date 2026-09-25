class_name CustomerVoices

## The sort of person a customer is, and how that sort talks at the mirror. A customer's
## sort comes from their name (PEOPLE), so a regular keeps it from visit to visit and
## nothing new goes in the save. FOLK is everyone else: they speak the occasion lines in
## CustomerLines (a wedding frets, a funeral keeps its voice down). Every other sort
## speaks for itself whatever the occasion, so its lines must stand up at a wedding, a
## funeral, a board meeting and a party alike. `{event}` is "the wedding", "the funeral",
## "the meeting" or "the party" when a line needs to say where they're going.
##
## The rules from CustomerLines hold here too: every line makes sense on its own, with no
## "he", no relatives and nobody the player never meets. A place or a stranger described
## in the line itself (the violinist at the Palais) is fine. See docs/CUSTOMER_CAST.md for
## who these people are.

enum Sort { FOLK, SOCIETY, BUSINESS, ELDER, FASHION, WEARY, THESPIAN, ROMANTIC }

## Who is which sort. Names missing here (old saves, the tutorial) are FOLK.
const PEOPLE := {
	"Mr. Ellison": Sort.FOLK,
	"Mr. Okafor": Sort.FOLK,
	"Mr. Delgado": Sort.FOLK,
	"Ms. Byrne": Sort.FOLK,
	"Mr. Abara": Sort.FOLK,
	"Ms. Kowalski": Sort.FOLK,
	"Ms. Oyelaran": Sort.FOLK,
	"Ms. Castellanos": Sort.FOLK,
	"Ms. Duarte": Sort.FOLK,
	"Ms. Quigley": Sort.FOLK,
	"Ms. Whitcombe": Sort.SOCIETY,
	"Mr. Fitzgerald": Sort.SOCIETY,
	"Ms. Harrington": Sort.SOCIETY,
	"Lady Ashcombe": Sort.SOCIETY,
	"Lord Tewkesbury": Sort.SOCIETY,
	"Dr. Vance": Sort.BUSINESS,
	"Ms. Nadeem": Sort.BUSINESS,
	"Mr. Tanaka": Sort.BUSINESS,
	"Mr. Sandoval": Sort.BUSINESS,
	"Dr. Whitlock": Sort.BUSINESS,
	"Dr. Moreau": Sort.ELDER,
	"Dr. Achebe": Sort.ELDER,
	"Mr. Pemberton": Sort.ELDER,
	"Mr. Pettigrew": Sort.ELDER,
	"Mrs. Applegarth": Sort.ELDER,
	"Mr. Fenwick": Sort.ELDER,
	"Ms. Portobello": Sort.FASHION,
	"Ms. Ito": Sort.FASHION,
	"Ms. Laurent": Sort.FASHION,
	"Mr. Zanetti": Sort.FASHION,
	"Mr. Halloran": Sort.WEARY,
	"Mr. Lindqvist": Sort.WEARY,
	"Mr. Novak": Sort.WEARY,
	"Ms. Farrow": Sort.WEARY,
	"Mr. Dimmock": Sort.WEARY,
	"Mr. Bellamy": Sort.THESPIAN,
	"Ms. Delacourt": Sort.THESPIAN,
	"Mr. Montague": Sort.THESPIAN,
	"Mr. Rossi": Sort.ROMANTIC,
	"Miss Hartley": Sort.ROMANTIC,
	"Mr. Penrose": Sort.ROMANTIC,
}

## The styles a sort tends to ask for (Enums.Style), and how often it does. A sort with
## none takes whatever the dice say.
const STYLE_LEAN := {
	Sort.SOCIETY: [Enums.Style.OLDSCHOOL, Enums.Style.CLASSIC],
	Sort.BUSINESS: [Enums.Style.CLASSIC, Enums.Style.MODERN],
	Sort.ELDER: [Enums.Style.OLDSCHOOL],
	Sort.FASHION: [Enums.Style.FASHION, Enums.Style.MODERN],
	Sort.THESPIAN: [Enums.Style.OLDSCHOOL, Enums.Style.FASHION],
}
const LEAN_CHANCE := 0.6

## `{event}`, by occasion.
const EVENT := {
	Enums.Occasion.WEDDING: "the wedding",
	Enums.Occasion.FUNERAL: "the funeral",
	Enums.Occasion.BUSINESS: "the meeting",
	Enums.Occasion.PARTY: "the party",
}

## Sort -> CustomerLines.Kind -> variants. OVER_BUDGET lives in BUDGET below.
const LINES := {
	Sort.SOCIETY:
	{
		CustomerLines.Kind.JACKET_COLOR:
		[
			"{value}. My chauffeur wears {value}.",
			"Oh. {value}. How brave of you to show me.",
			"{value}? One would be taken for the land agent.",
			"I had a footman in {value} once. Nobody's had a footman since.",
			"Not {value}, dear. People would think we'd sold the house.",
			"{value}. There's a room in the east wing that colour. Nobody goes in.",
		],
		CustomerLines.Kind.JACKET_NEEDS_PATTERN:
		[
			"Plain. How very democratic.",
			"Nothing on it at all? One might as well go in a dressing gown.",
			"Plain cloth is for people who have to be somewhere at nine.",
			"It's terribly plain. Is there a shortage?",
			"Plain. I own forty suits and not one of them is plain.",
			"Plain. I'd be introduced twice and forgotten both times.",
		],
		CustomerLines.Kind.JACKET_PATTERN:
		[
			"{value}. That's what they wear at the races. In the cheap enclosure.",
			"Oh, {value}. We had a bookmaker who dressed like that. Had.",
			"{value}? No, dear. Not on me.",
			"{value} is for people who own one horse.",
			"{value}. I'd be asked to fetch the car round.",
			"I think {value} is something one grows out of, like ponies.",
		],
		CustomerLines.Kind.JACKET_CLOTH:
		[
			"{value}. It feels like a department store.",
			"{value}. Touch it. No, go on. There.",
			"{value}? I've had curtains in finer stuff.",
			"{value}. Put it back where you found it, there's a dear.",
			"One hears {value} when one sits down. One shouldn't.",
			"Nanny made me wear {value}. I was seven and it itched.",
		],
		CustomerLines.Kind.TROUSERS_MATCH:
		[
			"The trousers seem to have come from somebody else's family.",
			"Odd trousers. People will think I dressed in the dark, or worse, myself.",
			"These don't match. At home we'd ring for someone about this.",
			"The trousers and the jacket haven't been introduced.",
			"Mismatched. That's how one dresses for the country, and this isn't the country.",
			"Different trousers. Somebody at dinner would say nothing, very loudly.",
		],
		CustomerLines.Kind.TROUSERS_PATTERN:
		[
			"{value} on the legs. Like a sofa.",
			"The trousers are having a better time than the jacket.",
			"{value} trousers. Golf, dear. Golf.",
			"I'm not sure the trousers were invited.",
			"{value}. From the waist down I'd look like a hotel.",
			"Both halves are talking at once. At dinner that would be rude.",
		],
		CustomerLines.Kind.SHIRT_COLOR:
		[
			"A {value} shirt. We used to give those to the gardener.",
			"{value}? Heavens. Is it meant to be {value}, or has it been washed?",
			"No {value} shirt. I've a reputation, though I forget for what.",
			"{value}. That's a shirt for someone with a bicycle.",
			"Not {value}. It would make my face look its age.",
			"A {value} shirt. Whatever next. A wristwatch?",
		],
		CustomerLines.Kind.SHIRT_PATTERN:
		[
			"{value} on the shirt. Like a picnic.",
			"{value}. Shirts should be seen and not heard.",
			"A {value} shirt. I'd be asked if I'm with the band.",
			"No {value}. I'd spend all evening pretending I hadn't noticed.",
			"{value}? The cuffs would show. The cuffs always show.",
			"{value}. We leave that sort of thing to the seaside.",
		],
	},
	Sort.BUSINESS:
	{
		CustomerLines.Kind.JACKET_COLOR:
		[
			"{value}. No.",
			"{value} doesn't close deals.",
			"{value}? Next.",
			"{value} reads as junior. I've spent twelve years not being junior.",
			"Not {value}. I'll be sat opposite someone deciding if I'm serious.",
			"Half the Exchange wears {value}. Strike it.",
		],
		CustomerLines.Kind.JACKET_NEEDS_PATTERN:
		[
			"Plain. Forgettable. Next.",
			"Needs a stripe. A stripe says I've read the figures.",
			"Plain. Clerks wear plain.",
			"Nothing on it. Nobody pays for nothing.",
			"Too plain. I'd be one of forty grey suits in a lift.",
			"Plain. I didn't come in here to blend.",
		],
		CustomerLines.Kind.JACKET_PATTERN:
		[
			"{value}. Wrong signal.",
			"{value}. They'll think I've a second job.",
			"No {value}. The bank has a view on {value}.",
			"{value}? Strike it.",
			"{value}. It reads as weekend. I don't have weekends.",
			"{value}. I'd be explaining the suit instead of the numbers.",
		],
		CustomerLines.Kind.JACKET_CLOTH:
		[
			"{value}. Won't survive a Tuesday.",
			"Wrong cloth. It'll crease on the train and I'll look like the train.",
			"{value}? I sit for eleven hours a day. It won't.",
			"No {value}. It needs to last the quarter.",
			"{value}. Looks cheap across a desk. Cheap is catching.",
			"{value}. I haven't the time to send it out every week.",
		],
		CustomerLines.Kind.TROUSERS_MATCH:
		[
			"Trousers don't match. Fix.",
			"Two suits. I ordered one.",
			"Odd trousers. Someone will ask. Nobody should have to ask.",
			"Mismatch. It's the detail they remember.",
			"The trousers are off. I noticed. So will they.",
			"Match them. I've no time to explain my legs.",
		],
		CustomerLines.Kind.TROUSERS_PATTERN:
		[
			"Trousers too busy. Quieter.",
			"{value} legs. No.",
			"Jacket and trousers want different things. I know how that ends.",
			"{value} on the trousers. Reads as a golf day.",
			"The trousers are pitching something the jacket isn't.",
			"No {value} below the waist. Nobody trusts it.",
		],
		CustomerLines.Kind.SHIRT_COLOR:
		[
			"{value} shirt. No.",
			"A {value} shirt says I've got the afternoon off.",
			"Not {value}. I'd look like I'd been up all night. I have, at my desk.",
			"{value}. Too soft. I'm not asking nicely in there.",
			"{value}? Out.",
			"No {value}. The shirt should be the last thing anyone notices.",
		],
		CustomerLines.Kind.SHIRT_PATTERN:
		[
			"{value}. Too loud.",
			"{value} shirt. Holiday. I don't take them.",
			"No {value}. Plain collar, clean cuff.",
			"{value}. They'd look at the shirt and miss the figure on page four.",
			"Not {value}. I'm negotiating, not boating.",
			"A {value} shirt, at my level. No.",
		],
	},
	Sort.ELDER:
	{
		CustomerLines.Kind.JACKET_COLOR:
		[
			"{value}? Oh, no. I had a {value} one in nineteen-oh-four and I was sick on a boat in it.",
			"{value}. My eyes aren't what they were, but I can still see that.",
			"Not {value}, dear. I'd look like the sofa.",
			"{value}. Hm. Is that what the young ones wear? You needn't tell me.",
			"I was married in {value}. Let that one stay where it is.",
			"{value}? I'd look like I'd come about the drains.",
		],
		CustomerLines.Kind.JACKET_NEEDS_PATTERN:
		[
			"It's very plain. I had a herringbone once. Lovely thing. The moths had it.",
			"Plain? At my age you want a bit of something on it.",
			"Plain. People will think I've died already.",
			"Nothing on it. I'd fade into the armchair.",
			"Plain. I wore plain for forty years at the post office. Nobody ever found me at parties.",
			"Oh, it's plain. I'd like one more suit with a bit of pattern. Just the one.",
		],
		CustomerLines.Kind.JACKET_PATTERN:
		[
			"{value}. That makes my eyes swim. Sit me down.",
			"{value}? Oh, dear. No. Oh, dear.",
			"Not {value}. The bank manager wore {value}. I never trusted the bank manager.",
			"{value}. I'd get lost in it.",
			"{value}. I've seen two old friends buried in {value}. Something else.",
			"{value}. With my hands the way they are, I'd look like I was humming.",
		],
		CustomerLines.Kind.JACKET_CLOTH:
		[
			"{value}. It's thin. I feel the cold now. I never used to.",
			"{value}? It won't see me through the winter. Well. Let's see me through the winter first.",
			"Not {value}. My knees would know.",
			"{value}. It scratches. Everything scratches now.",
			"{value}. My old suit's forty years and still going. This one wouldn't be.",
			"No, not {value}, dear. Feel my hands. I need something warmer.",
		],
		CustomerLines.Kind.TROUSERS_MATCH:
		[
			"These trousers aren't from this jacket. I'd know, and I don't know much these days.",
			"The trousers don't match. I'd only go and wear them with the wrong one anyway.",
			"Odd trousers. I did that once by accident, at a christening.",
			"They don't match, dear. My eyes are bad, not gone.",
			"Different trousers. People would think I'd lost track again.",
			"Odd trousers. No. Some things ought to match.",
		],
		CustomerLines.Kind.TROUSERS_PATTERN:
		[
			"{value} trousers. I'd look like a picnic rug.",
			"The trousers are busy. I'm not busy. I'm never busy now.",
			"{value}? On these old legs?",
			"All that {value} going on down there. I'd trip over it.",
			"The jacket and the trousers don't agree. I've been to weddings like that.",
			"Not {value} on the legs, dear. I spend most of the day sitting on them.",
		],
		CustomerLines.Kind.SHIRT_COLOR:
		[
			"A {value} shirt. We didn't have {value} shirts. We had shirts.",
			"{value}. It would wash me out, and I'm washed out enough.",
			"Not {value}. I spill my soup, dear. It'd show.",
			"{value}? I'd look like I was in hospital.",
			"{value}. My collar stud would never forgive me.",
			"{value}. I've never worn {value} in my life and I'm not starting at the end of it.",
		],
		CustomerLines.Kind.SHIRT_PATTERN:
		[
			"{value} on a shirt? When did that start?",
			"{value}. It moves when I look at it.",
			"Not {value}. I can't find my buttons on a pattern.",
			"{value}. That's for the young.",
			"A {value} shirt. I'd need my glasses to see if I'd done it up.",
			"{value}? No, dear. Just a shirt. A shirt that's a shirt.",
		],
	},
	Sort.FASHION:
	{
		CustomerLines.Kind.JACKET_COLOR:
		[
			"{value}? Darling, {value} died in the spring. I went to the funeral.",
			"{value}. I'd rather be seen in a coal sack. A coal sack is at least a statement.",
			"No. {value} is what you wear when you've given up.",
			"{value}! In Paris they'd stop serving me.",
			"{value}. A colour for people who stand at the back of photographs.",
			"{value}? I can't. Look, my arm won't go in.",
		],
		CustomerLines.Kind.JACKET_NEEDS_PATTERN:
		[
			"Plain? Plain! Did something happen to the loom?",
			"It's naked. Put something on it.",
			"Plain is for accountants and the dead.",
			"Where's the pattern? I came in for a riot and you've given me a Tuesday.",
			"Plain. I'll be mistaken for someone sensible.",
			"No pattern. I'd have to be interesting all by myself, and it's late in the week for that.",
		],
		CustomerLines.Kind.JACKET_PATTERN:
		[
			"{value}. Sweetheart, that's last year's. Last year's is worse than never.",
			"{value}? Insurance men wear {value}.",
			"Not {value}. Everyone's in {value}. I saw a dog in {value}.",
			"{value}. It doesn't say anything. I want a suit that won't shut up.",
			"{value}. It's what a bank would wear to a party.",
			"{value}? Take it away before somebody sees me near it.",
		],
		CustomerLines.Kind.JACKET_CLOTH:
		[
			"{value}. It just hangs there. I need cloth that moves when I do.",
			"{value}? It's like a school blazer. I was expelled from school.",
			"Not {value}. It has no opinion about anything.",
			"{value}. It'll never catch the light. I stand where the light is.",
			"{value}. Feel it. It's like shaking hands with a bank.",
			"{value}? I'm not dressing for a walk in the Lakes.",
		],
		CustomerLines.Kind.TROUSERS_MATCH:
		[
			"Odd trousers. Unless we're calling it a look. Are we? No.",
			"The trousers don't match. Next season, maybe. This season, no.",
			"Two suits at once. That isn't daring, that's laundry.",
			"Mismatched by accident is the one thing I can't forgive.",
			"Those trousers belong to a different story.",
			"The trousers are from another suit. Everyone at the Palais would see it.",
		],
		CustomerLines.Kind.TROUSERS_PATTERN:
		[
			"{value} trousers, fine, but then commit. The jacket isn't committing.",
			"The trousers have ideas and the jacket hasn't. I've seen that marriage.",
			"{value} legs. It's a start. It isn't an ending.",
			"Two patterns, darling. Even I need somewhere to rest my eyes.",
			"The trousers are louder than I am. Nobody is louder than I am.",
			"{value} below, nothing above. I'd look like I dressed on a staircase.",
		],
		CustomerLines.Kind.SHIRT_COLOR:
		[
			"A {value} shirt? Who hurt you?",
			"{value}. That's a shirt for paying the gas bill in.",
			"No, no, no. {value} makes me look like porridge.",
			"{value}. I burn {value} shirts. There's a small ceremony.",
			"{value}? People will think I've been ill.",
			"Not {value}. The shirt is where I keep my personality.",
		],
		CustomerLines.Kind.SHIRT_PATTERN:
		[
			"{value}. It's trying. Trying isn't enough.",
			"{value}? That's a pattern for a tea towel.",
			"Not {value}. It's too polite. I'm not polite.",
			"{value}. I've seen curtains in that. Lovely curtains.",
			"{value} on the shirt? The shirt should start the conversation, not ask about the weather.",
			"{value}. Wrong. I can't say why. I feel it in my teeth.",
		],
	},
	Sort.WEARY:
	{
		CustomerLines.Kind.JACKET_COLOR:
		[
			"{value}. Fine. No. Not fine. I don't know why I said fine.",
			"{value}. It's the colour of the dentist's waiting room.",
			"Not {value}. I've spent enough of my life in {value}.",
			"{value}. Nobody will look at me. But they'll look at that.",
			"{value}. It looks like I tried and it didn't work.",
			"No {value}. I wore {value} for eleven years at the Ministry. It's still in me somewhere.",
		],
		CustomerLines.Kind.JACKET_NEEDS_PATTERN:
		[
			"Plain. Like everything.",
			"Plain. Even I noticed, and I don't notice things any more.",
			"It's plain. I didn't think I'd mind. I mind.",
			"Plain. I'd be a grey shape in a grey queue.",
			"Something on it. Anything. One thing about me should be happening.",
			"Plain. That's the suit I already am.",
		],
		CustomerLines.Kind.JACKET_PATTERN:
		[
			"{value}. That's a pattern for someone who still has plans.",
			"{value}. No. I haven't got the energy for {value}.",
			"{value}. People would ask me about it. Then I'd have to talk.",
			"Not {value}. It looks like I'm going somewhere.",
			"{value}? I saw that on someone once. They were whistling. I don't trust it.",
			"{value}. Mm. No. Sorry. No.",
		],
		CustomerLines.Kind.JACKET_CLOTH:
		[
			"{value}. It'll give up before I do, which is saying something.",
			"{value}. I sit a lot. It won't like that.",
			"Not {value}. I'd feel it all day. I already feel most things all day.",
			"{value}. It's thin. Like my excuses for not going out.",
			"{value}. No. I haven't the strength to iron.",
			"{value}. I'd just be cold in it. I'm usually cold.",
		],
		CustomerLines.Kind.TROUSERS_MATCH:
		[
			"The trousers don't match. Of course they don't.",
			"Odd trousers. That would be the one thing anyone says to me all year.",
			"They don't match. I'd see it every time I looked down. I look down a lot.",
			"Two halves. Like the rest of me.",
			"Match them. Please. Let something match.",
			"Odd trousers. I nearly didn't say. I'm saying.",
		],
		CustomerLines.Kind.TROUSERS_PATTERN:
		[
			"The trousers are doing more than I am.",
			"{value} legs. Why would my legs be {value}. Where are they going.",
			"The trousers are busy. I'm not.",
			"{value}. On the bottom half. No.",
			"Both halves want attention. I haven't any to spare.",
			"Not {value} trousers. People would look down, then up, and then there I'd be.",
		],
		CustomerLines.Kind.SHIRT_COLOR:
		[
			"A {value} shirt. Hm. No.",
			"{value}. That shirt thinks it's going to a party. It isn't.",
			"Not {value}. It makes my face look the way it is.",
			"{value}. Someone would tell me I look well. Then I'd have to answer.",
			"{value}. I haven't worn {value} since before. Before all this.",
			"{value}. No. I'd only stain it with tea.",
		],
		CustomerLines.Kind.SHIRT_PATTERN:
		[
			"{value}. Too cheerful. I'd be letting it down.",
			"{value}. I'd spend the day apologising to the shirt.",
			"No {value}. Just a shirt. Something that doesn't ask anything of me.",
			"{value}? I'd have to keep my jacket on. I keep it on anyway.",
			"{value}. It's lively. One of us should be.",
			"Not {value}. Let's not.",
		],
	},
	Sort.THESPIAN:
	{
		CustomerLines.Kind.JACKET_COLOR:
		[
			"{value}? I played a corpse in {value} at Bradford. Twice nightly.",
			"{value}! No. The back row would never see me.",
			"{value}. A colour for understudies.",
			"Not {value}. {value} is for butlers in the second act, and butlers have no lines.",
			"{value}. The gallery would throw things. Rightly.",
			"{value}? At the Lyceum I'd have walked off. There's nobody to walk off from now.",
		],
		CustomerLines.Kind.JACKET_NEEDS_PATTERN:
		[
			"Plain! A plain suit is a costume for someone with no entrance.",
			"Nothing on it. The critics would say I'd telephoned it in, and I haven't a telephone.",
			"Plain. I'd be playing the part of Person at Bus Stop.",
			"Plain cloth under the lights looks like a mistake. I've been a mistake. Once. Leeds.",
			"Give it something. Give it a second act.",
			"Plain. I have been plain before. Nineteen-twelve. Nobody came.",
		],
		CustomerLines.Kind.JACKET_PATTERN:
		[
			"{value}. That pattern would upstage me, and nobody upstages me.",
			"{value}? I'd be taken for the comic, and the comic always dies in the first scene.",
			"Not {value}. Under the limes it would dance about like a drunk.",
			"{value}. It says farce. I do tragedy. I do anything, these days.",
			"{value}? Take it away. It's giving me notes.",
			"{value}. My dresser would have fainted. My dresser's in Canada now.",
		],
		CustomerLines.Kind.JACKET_CLOTH:
		[
			"{value}. It won't hang right when I kneel, and I kneel at least once an evening.",
			"{value}? It rustles. My great speech is a whisper.",
			"Not {value}. I sweat like a horse under the lights.",
			"{value}. Like a stage curtain. From the cheap side.",
			"{value}. A cloth for walk-ons.",
			"{value}? The costume room at Hull had better.",
		],
		CustomerLines.Kind.TROUSERS_MATCH:
		[
			"The trousers are from a different production.",
			"Odd trousers. A costume change gone wrong. I've seen that end careers.",
			"The trousers don't match. The front row would see. The front row always sees.",
			"Two suits. I'm one person. I used to be several a night, but one person.",
			"Mismatched. My public expects better. What there is of it.",
			"These trousers belong to another actor. A worse one.",
		],
		CustomerLines.Kind.TROUSERS_PATTERN:
		[
			"The trousers are trying to steal the scene.",
			"{value} legs. I'd be playing the clown. I did, once. Never again.",
			"{value} trousers. Nobody looks at an actor's legs unless the face has failed.",
			"The jacket speaks the verse and the trousers mime along. Dreadful.",
			"Not {value} below. The audience should be looking at my face.",
			"{value}? The trousers want top billing. They can't have it.",
		],
		CustomerLines.Kind.SHIRT_COLOR:
		[
			"A {value} shirt! Do you want me dead in the reviews?",
			"{value}. Under the lights it would go the colour of cold tea.",
			"Not {value}. It would take the colour out of my face, and I use my face.",
			"{value}. I wore {value} in the Scottish play. It was a disaster, and not only the shirt.",
			"A {value} shirt. That's for the chorus.",
			"{value}? No. My cuffs are half the performance.",
		],
		CustomerLines.Kind.SHIRT_PATTERN:
		[
			"{value} on the shirt. It would fight my hands.",
			"{value}. Distracting. I need them watching my eyes.",
			"Not {value}. It says matinée.",
			"{value}? It would twinkle during the death scene.",
			"{value}. A shirt for the usher.",
			"No {value}. The shirt must never have a bigger part than me.",
		],
	},
	Sort.ROMANTIC:
	{
		CustomerLines.Kind.JACKET_COLOR:
		[
			"{value}? The violinist at the Palais would look straight through me.",
			"{value}. I've walked past the same bakery every day for a month. Not in {value}.",
			"Not {value}. If I ever say hello, it won't be in {value}.",
			"{value}. Is it a colour people fall in love with? I don't think it is.",
			"{value}. It's what I was wearing the day I didn't say anything.",
			"{value}. The one who sells violets at the station deserves better than {value}.",
		],
		CustomerLines.Kind.JACKET_NEEDS_PATTERN:
		[
			"Plain. I'd be the one in the corner nobody asks to dance. Again.",
			"Plain. They'd never know I was there. They already don't.",
			"It needs something. Something that makes a person turn round.",
			"Plain. Like a letter I never sent.",
			"Nothing on it at all. How would anyone remember me?",
			"Plain. I want to be noticed once. Just once, across a room.",
		],
		CustomerLines.Kind.JACKET_PATTERN:
		[
			"{value}. It looks like I'm trying too hard. I am. Nobody can know.",
			"{value}? Would you look twice at {value}? Be honest.",
			"Not {value}. Nobody ever wrote a poem about {value}.",
			"{value}. It's for someone who talks about the weather. I only talk about the weather.",
			"{value}. No. When they finally look up, it can't be at {value}.",
			"{value}. It's a pattern for being friends.",
		],
		CustomerLines.Kind.JACKET_CLOTH:
		[
			"{value}. What if they touch my sleeve? They won't. But what if.",
			"{value}? I'll be standing under a lamppost for hours in this.",
			"Not {value}. It'd crumple if I knelt, and I might kneel. One day.",
			"{value}. It feels ordinary. I can't be ordinary in front of them.",
			"{value}. I'd sweat through it before the end of the street.",
			"{value}. It has to survive a great deal of walking past a window.",
		],
		CustomerLines.Kind.TROUSERS_MATCH:
		[
			"The trousers don't match. They'd notice. They notice everything except me.",
			"Odd trousers. I rehearse what I'll say for weeks. I can't rehearse around trousers.",
			"They don't match. Nothing about me should give them a reason.",
			"Two suits. I can barely manage being one person in front of them.",
			"Mismatched. Like me and the one at the library, probably.",
			"Odd trousers. If this is the day, it can't be odd trousers.",
		],
		CustomerLines.Kind.TROUSERS_PATTERN:
		[
			"The trousers are saying all the things I can't.",
			"{value} trousers. Too bold. I'm not bold. I've tried.",
			"{value} on the legs. They'd see me coming and cross the road.",
			"The trousers have more nerve than I do.",
			"Not {value}. They'd laugh. Kindly, but they'd laugh.",
			"{value} below the waist. What would I even say about it?",
		],
		CustomerLines.Kind.SHIRT_COLOR:
		[
			"A {value} shirt. Nobody ever fell for a {value} shirt.",
			"{value}? It makes me look like somebody's cousin.",
			"Not {value}. The one at the library wears {value}. We can't match. That's too much.",
			"{value}. That's the colour I go when they look at me. The shirt needn't as well.",
			"{value}. No. I want to look like I've got a secret. A good one.",
			"{value}. I'll be at the tram stop at eight. Not in {value}.",
		],
		CustomerLines.Kind.SHIRT_PATTERN:
		[
			"{value}. Too busy. I want them looking at my face. If they ever look.",
			"{value}? That's a shirt for someone who's already married.",
			"Not {value}. It's the tablecloth at the café where I sit and don't say anything.",
			"{value}. It would say something about me. I'd rather say it myself. I won't, but I'd rather.",
			"{value}. It isn't a shirt for a first word.",
			"No {value}. I'll be fiddling with my cuffs enough as it is.",
		],
	},
}

## What each sort says when the price is past their budget.
const BUDGET := {
	Sort.SOCIETY:
	[
		"Money. How tiresome. Could you send it to my man? My man will send it back.",
		"That much? I'd have to sell a painting. The good one's gone already.",
		"I don't carry money. People used to carry it for me.",
		"The figure seems rather high. Everything does, lately.",
		"Put it on the account. There is an account, isn't there? There was.",
		"That's more than the roof would cost, and the roof leaks.",
	],
	Sort.BUSINESS:
	[
		"Over budget. I don't go over budget. It's my one rule.",
		"That's past the figure. Bring it under.",
		"No. I approved a number. That isn't it.",
		"I've costed this. You haven't.",
		"Too dear. I didn't get where I am by paying the first price.",
		"That's more than I pay my clerk. In a month.",
	],
	Sort.ELDER:
	[
		"How much? I paid two guineas for my wedding suit.",
		"Oh. That's my pension for the month. And the next.",
		"That's too dear for me, dear. It only has to last me a while. Not long.",
		"I've got a bit put by. Not that much.",
		"In my day that bought a bicycle. I had a bicycle.",
		"That much? I'd have to go without the coal.",
	],
	Sort.FASHION:
	[
		"That much? Fine. No, not fine. I've spent the rent on hats.",
		"I can't. I owe three tailors already. You'd be the fourth.",
		"Oh, that's cruel. Beautiful things shouldn't cost money.",
		"Darling, I'm rich in every way except that one.",
		"It's over what I've got. I spend everything I've got on looking like I've got a lot.",
		"That price? I'd have to eat less. I already eat less.",
	],
	Sort.WEARY:
	[
		"That much. For a suit. For me.",
		"I can't. I could, but I'd have to want to.",
		"Too dear. I don't go out enough to spend that.",
		"That's a lot of money to look like this.",
		"No. The money's for the rent. The rent's for a room I sit in.",
		"Over what I've got. Most things are.",
	],
	Sort.THESPIAN:
	[
		"Ah. That figure. My agent would have fainted, if I still had an agent.",
		"I haven't been paid that much since the old Queen.",
		"Too dear. Might I pay in tickets? There's a matinée. There's always a matinée.",
		"That much? I'd have to play the pantomime horse again. The back half.",
		"I'm between engagements. Have been for some years.",
		"The price is a tragedy. I know tragedy.",
	],
	Sort.ROMANTIC:
	[
		"That much? I'm saving for a ring. I can't save for a suit as well.",
		"I can't. I spent it on flowers. I didn't give them the flowers.",
		"Too dear. There's a ring in a window on Cleary Street. That's where the money goes.",
		"Over what I've got. Could I pay the rest when I'm married? I'm not engaged. Or introduced.",
		"That price. I'll write a letter instead. I never send them, but letters are cheap.",
		"That's the whole jar on the mantelpiece. The jar is for later. For when it works out.",
	],
}

## A yes, by sort.
const HAPPY := {
	Sort.SOCIETY:
	[
		"Yes. That will do nicely. Send it round.",
		"Oh, that's rather good. Don't tell anyone I said so.",
		"Yes. I'll wear it to dinner. There'll only be me, but I'll wear it.",
		"Very well. You may tell people you dressed me.",
		"That's it. I've looked for something wrong with it. I can't find anything.",
		"Good. Wrap it in tissue. A great deal of tissue.",
	],
	Sort.BUSINESS:
	[
		"Good. Ring the office.",
		"Done. Invoice me.",
		"That'll do. Friday, latest.",
		"Yes. First thing today that's gone to plan.",
		"Right. Good. I'll be back when I've a minute. I never have a minute.",
		"Good work. Don't let it go to the price.",
	],
	Sort.ELDER:
	[
		"Oh, that's lovely. That's lovely. Can I sit down a moment?",
		"Yes. That'll see me out.",
		"That's a good suit. I'll wear it Sundays. And Tuesdays, I think.",
		"Oh yes. People will hold doors for me in that. They do anyway, but still.",
		"Lovely. Now, what was I here for? Oh. This. Lovely.",
		"Yes, dear. That's the one. Wrap it up properly, I'm on the bus.",
	],
	Sort.FASHION:
	[
		"Yes. Oh, yes. Nobody touch me.",
		"That's it. That's the suit they'll write about.",
		"Finally. Somebody in this town has eyes.",
		"Yes! I'm going to walk very slowly past the Gazette office.",
		"Oh, it's wicked. Wrap it in black paper.",
		"Yes. I'll have to change my name to go with it.",
	],
	Sort.WEARY:
	[
		"That'll do. Everything does, eventually.",
		"Fine. Good. That's good. I'll wear it somewhere. I'll find somewhere.",
		"Yes. It looks like someone who gets up in the morning.",
		"All right. Yes. Thank you. People don't usually bother.",
		"That's the one. I might even go out in it.",
		"Yes. I looked in the mirror just then. I don't, usually.",
	],
	Sort.THESPIAN:
	[
		"Yes! Lights! I'm going on!",
		"That's the one. Hand me my cloak. I haven't got a cloak. Hand me the suit.",
		"Bravo. You may take a bow. A small one.",
		"Yes. I'll wear it to the stage door. Somebody might know me.",
		"There. That's a suit for a curtain call.",
		"Perfect. And now, my exit.",
	],
	Sort.ROMANTIC:
	[
		"That's it. That's the suit I say hello in.",
		"Yes. Tomorrow. I'll do it tomorrow. In this.",
		"This is the one. Wrap it carefully. It's going to be important.",
		"Yes. Now I've got no excuse. Oh no.",
		"That's it. If they don't look now, they never will. They might not. But now they might.",
		"Yes. I'll wear it past the window. Just the once. Or every day.",
	],
}

## A yes in the colour they asked for, by sort.
const HAPPY_LIKED := {
	Sort.SOCIETY:
	[
		"{value}. Exactly as I said. How refreshing.",
		"{value}, and you listened. Most people nod and do as they like.",
		"There's the {value}. Send it round to the house.",
		"{value}. Yes. I shall be seen in this.",
		"You found the {value}. I'd almost stopped asking people for things.",
		"{value}. Good. One likes to be obeyed now and then.",
	],
	Sort.BUSINESS:
	[
		"{value}, per the brief. Good.",
		"{value}. On spec and on time. Invoice me.",
		"{value}, as agreed. You'd be wasted in my office.",
		"{value}. Correct. That's rare. Friday?",
		"There's the {value}. Done.",
		"{value}. You listened. I'll send people.",
	],
	Sort.ELDER:
	[
		"{value}. Like the one I had before the war. The moths had that one too.",
		"{value}! Oh, you remembered. I forget what I tell people.",
		"{value}, like I asked. My hands are shaking. They always do, but more.",
		"There's my {value}. I'll be buried in that one, I expect. Not yet, mind.",
		"{value}. That's the colour I meant. You're a good sort.",
		"{value}. I've looked for {value} in every shop on the Row.",
	],
	Sort.FASHION:
	[
		"{value}! My {value}! I told you. Didn't I tell you?",
		"{value}, darling. As requested. You can come to my next party.",
		"That {value} is going to start fights.",
		"{value}. You understood me. Almost nobody does.",
		"{value}. I'm going to stand in a window in this.",
		"There's my {value}. Now the whole street has to look at me.",
	],
	Sort.WEARY:
	[
		"{value}. You remembered. I didn't think anyone was listening.",
		"{value}. That's what I said. Somebody heard it.",
		"{value}. Right. Yes. That's a suit, isn't it.",
		"{value}, like I asked. I'd forgotten I'd asked.",
		"{value}. I used to like {value}. Before. Well. I still do, apparently.",
		"{value}. Well. There's a thing that went right.",
	],
	Sort.THESPIAN:
	[
		"{value}! Just as I saw it in my mind's eye.",
		"{value}. Exactly the costume. You have a gift for the theatre.",
		"There's my {value}. The last time I wore {value}, they stood up for me.",
		"{value}. The critics will have to be kind.",
		"{value}. Yes. I'm ready for my close-up. Is that what they say now?",
		"{value}. I've waited years for someone to cast me in that.",
	],
	Sort.ROMANTIC:
	[
		"{value}, like I asked. The violinist at the Palais likes {value}. I asked around.",
		"{value}. It's perfect. Please don't tell anyone why.",
		"{value}. They wore a {value} scarf the day I first saw them.",
		"{value}. Now I only have to be brave. That's the cheap part, apparently.",
		"There's my {value}. The tram stop won't know what hit it.",
		"{value}. Exactly. I'll be the one in {value}, if they ever ask.",
	],
}


## Their sort, from their name (FOLK if the name isn't on the list).
static func sort_of(display_name: String) -> int:
	return int(PEOPLE.get(display_name, Sort.FOLK))


## The style they ask for: often the ones their sort likes, else `style` unchanged.
static func lean_style(sort: int, style: int, rng: RandomNumberGenerator) -> int:
	var lean: Array = STYLE_LEAN.get(sort, [])
	if lean.is_empty() or rng.randf() >= LEAN_CHANCE:
		return style
	return int(lean[rng.randi() % lean.size()])


## The lines a sort has for one objection, or [] (FOLK, or a kind it doesn't cover).
static func objections(sort: int, kind: int) -> Array:
	if kind == CustomerLines.Kind.OVER_BUDGET:
		return BUDGET.get(sort, [])
	return (LINES.get(sort, {}) as Dictionary).get(kind, [])


## A sort's yes lines (`liked`: in the colour they asked for), or [] for FOLK.
static func yes_lines(sort: int, liked: bool) -> Array:
	return (HAPPY_LIKED if liked else HAPPY).get(sort, [])

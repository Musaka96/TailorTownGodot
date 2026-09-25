# TailorTown — The Cast

> **Status: lines BUILT (2026-09-25), looks PLANNED.** Who walks through the door. Each
> customer is a *sort* of person, and the sort decides how they talk at the mirror.
> Code: `data/scripts/customer_voices.gd` (**CustomerVoices**). The occasion voices in
> `customer_lines.gd` are now the voice of one sort, the ordinary folk.
> Writing rules: [WRITING_STYLE_GUIDE.md](WRITING_STYLE_GUIDE.md).

## How it works
- A customer's sort comes from their **name** (`CustomerVoices.PEOPLE`). Mr. Dimmock is
  always the one who has given up, visit after visit. Regulars keep their voice for free,
  and nothing new goes in the save. A name not on the list (old saves, the tutorial's
  customer) counts as **FOLK**.
- **FOLK** speak by the occasion, as before: a wedding frets, a funeral keeps its voice
  down. **Every other sort speaks as itself, whatever the occasion.** Their lines must work
  at all four occasions. `{event}` is available ("the wedding", "the funeral", "the
  meeting", "the party") for a line that needs to say where they're going.
- Six variants per objection, per yes and per budget line, in every sort. The shop's
  60-line memory covers every sort, so no line comes round again soon.
- Some sorts lean toward a style (`STYLE_LEAN`, 60% of the time). A duchess mostly asks for
  Old School or Classic, and a fashion person for Fashion or Modern. Budget, occasion and
  everything else are rolled as before. **Sorts do not touch the economy yet** (see Ideas).
- `tools/test_notes.gd` keeps every sort to the stranger rule: no "he", no relatives,
  nobody the player never meets. A stranger described inside the line is fine ("the one who
  sells violets at the station").

## The sorts

Share of names today: FOLK 10 · SOCIETY 5 · BUSINESS 5 · ELDER 6 · FASHION 4 · WEARY 5 ·
THESPIAN 3 · ROMANTIC 3 (41 names).

### Folk
Everyone else on the Row: people with one good suit and a reason to need it. Their lines
change with the occasion, not the person.
*Ellison, Okafor, Delgado, Byrne, Abara, Kowalski, Oyelaran, Castellanos, Duarte, Quigley.*

### High society
Old money, going quietly broke. Never raises its voice and never says anything kind by
accident. Rude by way of good manners, and lonelier than it lets on: the east-wing room
nobody goes into, dinner for one in the new suit, an account that "was" there.
- "Odd trousers. People will think I dressed in the dark, or worse, myself."
- "Put it on the account. There is an account, isn't there? There was."
- **Look:** long face, heavy lids held half-shut, eyebrows raised a little. Neat grey or
  silver hair, swept back. Glasses rare; a monocle if one is ever made.
*Whitcombe, Fitzgerald, Harrington, Lady Ashcombe, Lord Tewkesbury.*

### Business
Clipped, numbers first, no articles when it can manage without them. Everything is a
signal to someone across a desk. The crack in it is time: no weekends, no minute, up all
night "at my desk".
- "{value} reads as junior. I've spent twelve years not being junior."
- "Right. Good. I'll be back when I've a minute. I never have a minute."
- **Look:** short tidy hair, a hard parting. Narrow, level brows, small mouth. Glasses often.
*Vance, Nadeem, Tanaka, Sandoval, Whitlock.*

### Elders (the old dears)
Slow, sweet, easily sidetracked. Prices from before the war, the moths that took the good
herringbone, a pension that won't stretch. Death is in the room, and they are the only
ones allowed to joke about it.
- "Plain. People will think I've died already."
- "There's my {value}. I'll be buried in that one, I expect. Not yet, mind."
- **Look:** white or grey hair, thin on top or a soft cloud. Round glasses more often than
  not. Big eyes, low brows, the blush the owner loves. Grandpa face-style rulebook.
*Moreau, Achebe, Pemberton, Pettigrew, Mrs. Applegarth, Fenwick.*

### Fashion
Loud and quick, contemptuous of plain. They make up their rules as they go and say "darling".
Every suit is a statement or it's nothing. Under it, money trouble ("I've spent the rent
on hats") and the odd flash of wanting to be understood.
- "{value}? Darling, {value} died in the spring. I went to the funeral."
- "No pattern. I'd have to be interesting all by myself, and it's late in the week for that."
- **Look:** the most dramatic new hairstyles (a quiff, a sharp bob, slicked and shining).
  Arched, asymmetric brows, small sharp nose, wide mouth. Coloured glasses frames.
*Portobello, Ito, Laurent, Zanetti.*

### The weary (the one who has given up)
The owner's reference: heavy half-shut lids, flat mouth, hair they stopped fighting.
Monotone and short. They don't care, and then they do, a little, and it comes out anyway.
They are the sad heart of the cast and the one whose yes should land hardest.
- "Plain. Even I noticed, and I don't notice things any more."
- "Yes. It looks like someone who gets up in the morning."
- **Look:** `paper_noble`-style bored lids, small pupils, a short mouth,
  brows raised but not arched. Messy dark hair, grown out. Never glasses. A slight slump
  in the idle, if the rig ever allows one.
*Halloran, Lindqvist, Novak, Farrow, Dimmock.*

### The thespian
A stage actor whose last good notice was before the war. Everything is a scene, a critic,
a curtain call. Grand in the voice, down at heel in the facts: between engagements "for
some years", the dresser gone to Canada, nobody left to walk off from.
- "Plain. I have been plain before. Nineteen-twelve. Nobody came."
- "Yes. I'll wear it to the stage door. Somebody might know me."
- **Look:** long swept hair or a grand widow's peak, a big mouth, high brows. A cravat
  if the wardrobe ever gets one.
*Bellamy, Delacourt, Montague.*

### The romantic
Every suit is for someone they have never spoken to: the violinist at the Palais, the one
who sells violets at the station, the one at the library. Funny first, then sad: the
flowers they bought and didn't give, the jar on the mantelpiece "for when it works out".
- "The trousers don't match. They'd notice. They notice everything except me."
- "Yes. Now I've got no excuse. Oh no."
- **Look:** soft, slightly overdone hair (a curl that won't stay). Big eyes, cheeks always
  on. Brows angled up at the inner ends.
*Rossi, Miss Hartley, Penrose.*

Face briefs in the cut-paper rulebook's terms (FACE_STYLE_GUIDE §5): only features vary, every
face keeps the shared open-eyed idle except the weary's heavy lid.

## Writing a new line
1. Say it in the sort's mouth, then read it at a funeral and at a party. If it only works
   at one, it belongs to FOLK, or needs `{event}`.
2. One idea per line. The sad ones are sad because they are plain: "That much. For a suit.
   For me." Never explain the sadness.
3. `{value}` can be a colour ("navy"), a pattern ("glen check") or a cloth ("worsted
   wool"). Check the line reads with all three kinds its slot can get.
4. Run `tools/check_writing.gd` and `tools/test_notes.gd`.

## Ideas not built yet
- **Looks by sort.** When the new heads, hairstyles and face styles land, give each sort a
  pool (`STYLE_LEAN`'s twin: `LOOK` → face style, hair ids, hair-colour range, glasses
  chance). The **Look** notes above are the brief for those pools.
- **Loyalty lines.** A regular's lines could shift as their stars grow. Mr. Dimmock at ★3
  says "I wore the last one to my own birthday. First time I've gone." The warmest pay-off
  the weary sort can have.
- **Counter and pickup voice.** The greeting taste line, the waiting collector, the
  walk-out and the street-pitch yes/no are still the same for everyone. They are the next
  surfaces to voice by sort.
- **Economy hooks** (need the owner's call): society pays more but pays late; business
  asks for rush more often; elders tip in sweets; fashion people bring a friend.

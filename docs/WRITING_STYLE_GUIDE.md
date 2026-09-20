# TailorTown Writing Style Guide

Every word the player reads — mentor speeches, Pops's letters, handbook entries, upgrade
descriptions, customer barks, station prompts, newspaper copy, store text — is written to
these rules.

This guide is **enforceable**: `tools/check_writing.gd` scans the player-facing files
against the rules marked **[CHECK]** and fails the run on a violation. Rules marked
**[JUDGE]** are read by a human at review. The evidence behind every rule is in
`RESEARCH_ai_writing_tells.md`; this is the short version you actually work from.

**What this guide is for.** Not beating a detector — those don't work. Liang et al.
(Stanford, *Patterns* 2023) ran seven GPT detectors over essays by non-native English
speakers and got a **61.3% false-positive rate**. The goal is the opposite and simpler:
prose with a person in it. A machine writes the *average* of everything ever written about
tailoring. We are writing about one shop.

---

## 1. Identity — who is allowed to sound like what

This game is a tailor's shop on the Row, some time between the wars, and its prose is
**English trade speech**: concrete, dry, a little impatient, funnier than it lets on. The
register is a craftsman explaining a job to someone who is in the way.

Six voices, and nothing may drift between them:

| Voice | Where | Sounds like |
|---|---|---|
| **Mr. Hemming** | `globals/tutorial.gd` | A master tailor mid-job. Imperatives, trade nouns, exclamations. "Mind the length!" "Loud checks at a board meeting? Never." Slightly impatient with you, because that is what teaching sounds like. |
| **Pops (Barnaby Thimble)** | `globals/story.gd` | Handwriting. Short paragraphs, no headings, digressions, a flat instruction where a moral belongs. Never sentimental on purpose; the feeling arrives sideways, in a detail. |
| **The narrator of found things** | `globals/story.gd` keepsakes | Camera, not commentary. States what is there and one fact too many. "The handles are worn to the shape of a hand that is not yours yet." |
| **The Tailor's Gazette** | `data/news/*.tres`, `ui/newspaper.gd` | A period local paper with column inches to fill. Understated, faintly arch, occasionally about nothing. |
| **Customers** | `entities/customer/`, `ui/customer_request.gd` | Fragments. Each one wants something specific and slightly unreasonable. Not all of them are nice. |
| **The shop itself** (UI, prompts, minigame feedback) | `ui/`, `stations/` | Verb first, no personality, no jokes. "Follow the chalk." The UI is the only voice allowed to be plain. |

**[JUDGE]** Strip the speaker's name off any line and it must still be obvious who said
it. If Hemming's line would work in Percy's mouth, one of them isn't written yet.

---

## 2. The nine rules

### 2.1 Cut the participial tail **[CHECK]**

If the last clause of a sentence starts with an `-ing` verb and explains the effect of
what came before, delete it. This is the single loudest structural tell, and Wikipedia's
AI-cleanup guide flags it by name.

> **BAD** — `data/scripts/handbook.gd`
> "It rose with 1920s finance and the power suits of the 1980s, lending height and
> authority."
>
> **GOOD**
> "It rose with 1920s finance and again with the power suits of the 1980s. It adds
> height. That is most of why anyone wears it."

### 2.2 Never restate the thesis at the end **[JUDGE]**

Delete the last sentence of any letter, article, keepsake or description and check
whether it improved. It usually does. A model ends by telling you what it meant; a person
ends because they've stopped.

> **BAD** — `docs/STEAM_PAGE.md`
> "How cleanly you cut and how steadily you sew becomes the quality of the piece, and the
> quality of the piece is what the client pays for."
>
> **GOOD**
> "Cut it badly and the client pays you less for it."

### 2.3 One idea per line **[JUDGE]**

A line carrying a fact *and* a feeling *and* a joke is three lines, or three speakers.

### 2.4 Vary sentence length on purpose **[JUDGE]**

In any block of six or more sentences, at least one under five words and one over twenty.
Check the spread, not the average. Lines that are all 11–16 words give a character no
breath — this is "burstiness", and it happens to be both a detection signal and real
craft advice.

> **BAD** — three sentences at 16/14/12 words, same shape
> "I've been working this shop for nearly thirty years now, and I've seen a great many
> things. The customers have changed, but the work itself has stayed much the same.
> You'll find that patience is the most important tool you own."
>
> **GOOD**
> "Thirty years. Customers change, work doesn't. Patience — that's the tool, and it's the
> one thing you can't order on the phone."

### 2.5 Break the triad **[JUDGE]**

Three of anything is the model's default rhythm: three adjectives, three items, three
clauses. Half the time, make it two or four. `check_writing.gd` reports every `a, b and c`
in player text as a warning; the warning list is the to-do list, not a ban.

> **BAD** — "sober colours, a hard-wearing cloth and a quiet pattern"
> **GOOD** — "sober colours and a cloth that works hard"

### 2.6 Ration the em dash **[CHECK]**

The em dash is this game's house connective and it stays. But GPT-4.1 uses it at **3.28×**
the human rate, and three in one sentence is a run-on wearing a costume.

- **Three or more in a single string** is an error. Split the sentence.
- **Two** is a warning — usually one should be a full stop.
- **In dialogue, the em dash means interruption only** (`"But I—"`). Trailing off is `…`.
  Never use it for parenthesis inside speech.

> **BAD** — `docs/STEAM_PAGE.md`
> "Smooth the wrinkles out on the pressing board — linger and you scorch it — and hang it
> on the rack — the jacket, shirt and trousers of one order find each other there…"
>
> **GOOD**
> "Press the wrinkles out; linger and you scorch it. Then hang it on the rack. The jacket,
> shirt and trousers of one order find each other there."

### 2.7 Replace mood words with facts **[CHECK]**

`cosy`, `warm`, `charming`, `quaint`, `whimsical`, `timeless`, `vibrant`, `bustling` are
banned in player-facing text. They are the cozy genre's vocabulary *and* the model's
default register, which is exactly why they can't be ours. Name the thing that makes it
cosy instead.

> **BAD** — "A cosy old sewing machine, full of character."
> **GOOD** — "A Singer with a cracked bobbin cover and someone's initials scratched into
> the bed."

### 2.8 Nobody names their own feeling **[JUDGE]**

Characters do not announce emotions. Convert to behaviour, to an object, or to silence.
Pops's letters already do this correctly — "That roof beat me. I put buckets under it for
two winters" — and it is the reason they land.

### 2.9 No joke gets a second clause **[JUDGE]**

If the punchline needs explaining, the punchline is wrong. `street_pitch.gd` is the model
for the whole game: "My ankles are none of your business." Nothing after it.

---

## 3. Per-surface rules

### 3.1 Pops's letters — `globals/story.gd` **[CHECK]**

Handwriting has no headings, no bullets, no bold, no emoji, no markdown. It has
paragraphs, digressions, and a signature. **End on a mundane instruction or mid-thought,
never on a moral.** The current letters are the benchmark: "The benches go back where the
light falls, not where there is room."

A PS may carry more weight than the letter. Use that.

### 3.2 The Gazette — `data/news/*.tres`, `tools/build_news.gd` **[CHECK]**

It is a period artefact with column inches to fill, not a blog post. No bullet lists, no
bold lead-ins, no title-case subheads, no emoji. It is allowed to be about nothing — "Little
stirs but the shears" is the correct register. Budget, across the article set: one pun
nobody would print today, one correction notice, one classified with abbreviated nonsense
in it.

### 3.3 The Handbook — `data/scripts/handbook.gd` **[JUDGE]**

**The entries must not share a skeleton.** This is the file's standing risk and its
current failing: all thirteen pattern entries run ¶1 technical definition → ¶2 history →
closing adjective-pair verdict ("Subtle and textured", "Bold and full of character",
"Smart, British and surprisingly versatile", "Striking and fashion-forward"). All four
occasion entries run abstract thesis → semicolon contrast → epigram ("Understated wins.",
"Have some fun."). Individually they read well; as a set they read generated, which is
precisely what Doshi & Hauser measured (*Science Advances* 2024): LLM-assisted writing
scores better per piece and measurably more similar across pieces.

Fix by **varying the shape, not the words**. Across any chapter:
- at least one entry that is a single sentence
- at least one that opens on the history, not the definition
- at least one that gives a rule instead of a description ("Never before six.")
- at most half ending on a verdict at all

Give an entry a job beyond flavour — a number, a rule the player can act on — and it stops
drifting into mush.

### 3.4 The mentor — `globals/tutorial.gd` **[JUDGE]**

- **Start with the verb.** No framing sentence before the instruction. "Now, the heart of
  the trade" is a throat-clear; cut it and open on "Every customer has an occasion."
- **Bold no more than two terms per speech.** Emphasis spray is a formatting tell and it
  stops working at the third `[b]`. Bold the noun the player must find on screen, not
  every noun in the sentence.
- Hemming is allowed to be brusque, to repeat himself, and to not explain a joke.

### 3.5 Customer barks — `entities/customer/street_pitch.gd` **[JUDGE]**

Four words beats a sentence. At least three barks in any table are jokes that never
explain themselves, and at least one customer per table is rude, wrong, or unhelpful.
Cozy without friction is the AI-shaped failure.

### 3.6 UI microcopy and station prompts — `ui/`, `stations/` **[CHECK]**

Verb first. No bold-colon lead-ins (`**Tip:** …`). No bullet list where two short
sentences work. **Trade language, not product language**: not "Unlock Premium Textiles"
but "Bellweather will take your call now"; not "Reputation: Excellent" but "Word's getting
round."

Glyphs (`★ ☆ ✓ 🔒`) are icons and stay — they are typography, not emoji. Emoji as
*formatting* (✅ 🚀 ✨ 🧠) is banned everywhere.

### 3.7 Store and marketing copy — `docs/STEAM_PAGE.md` **[JUDGE]**

The store page is where the tells concentrate, because promotional register is the
model's home turf. Same rules, applied harder: no "not just X, but Y", no closing thesis
restatement, and the em-dash count comes down. Keep the specifics — "three slips and it's
ruined", "the last half-metre of a good cloth is gone" — and cut the balanced
antithesis pairs that summarise them afterwards.

---

## 4. The word list **[CHECK]**

Banned in player-facing text. Assembled from Kobak et al. (*Science Advances* 2025, 14.2M
PubMed abstracts — `delves` at 28× excess, `underscores` 13.8×, `showcasing` 10.7×),
Juzek & Ward 2025, and the Wikipedia AI-cleanup list.

**Verbs** — delve, delves, delving, underscore(s), showcase(s)/showcasing, foster(ing),
bolster, leverage, elevate(s), embark, garner. Plus the copula-avoidance cluster: *serves
as / stands as / functions as* for **is**, and *boasts / features / offers* for **has**.
Write "is" and "has".

**Adjectives** — meticulous, intricate, vibrant, bustling, pivotal, comprehensive,
seamless, nuanced, profound, timeless, invaluable, renowned, groundbreaking, unwavering,
whimsical, quaint, cosy/cozy *(as a mood claim)*, charming, delightful.

**Nouns** — tapestry, testament, realm, journey *(figurative)*, interplay, intricacies,
complexities, symphony, beacon, cornerstone, treasure trove, plethora, myriad, essence.

**Connectives** — additionally, moreover, furthermore, undoubtedly, arguably, ultimately,
notably, crucially.

**Phrases** — "not just X, but Y", "it's not X, it's Y", "more than just", "a testament
to", "nestled in", "in the heart of", "it's worth noting", "in conclusion", "at the end of
the day", "here's the thing", "let's be honest", "whether you're X or Y", "from X to Y",
"a reminder that", "plays a crucial role", "and that's what makes it special".

**Typography** — curly quotes `’ “ ”` in player text (the game is straight-quoted
throughout), `**bold**` markdown, emoji as formatting, `---` breaks inside prose.

Use as a grep list, not a law. Any of these can be the right word. The rule is: **if you
didn't reach for it, it doesn't stay.** The list also rots — `delve` is already declining
in the wild while "not just X, but Y" rises — so §2 matters more than §4.

---

## 5. The pass every new text gets

1. Run `tools/check_writing.gd`. Fix every ERROR; read every WARNING and decide.
2. Any sentence ending in `, -ing …` → cut the clause.
3. Delete the last sentence. Put it back only if it's missed.
4. Three adjectives in a row → keep one.
5. A character naming a feeling → replace with a physical action.
6. **Read it aloud.** Every tell in this guide survives silent reading and dies out loud.
7. Second pass, always. These are first-draft artefacts, and the second draft is the job.

---

## 6. The standing backlog

What the audit of 2026-09-20 found. The game's prose is in good shape — the lexical scan
came back empty across all twelve prose files, and there is not one "not just X, but Y" in
the game — so what's left is structural:

| # | Where | What | Size |
|---|---|---|---|
| 1 | `data/scripts/handbook.gd` | 13 pattern entries and 4 occasion entries share one skeleton each (§3.3). Vary the shapes. | M |
| 2 | `docs/STEAM_PAGE.md` | 68 em dashes, one sentence carrying three; closing thesis restatements at the end of three sections (§2.2, §2.6). | S |
| 3 | `data/scripts/handbook.gd:78` | Participial tail, "…, lending height and authority" (§2.1). | XS |
| 4 | `globals/tutorial.gd` | Framing sentences before instructions; `[b]` spray, up to six per speech (§3.4). | S |
| 5 | `data/news/*.tres` | 20 articles, all the same length and shape. Needs a correction notice, a classified, one that is three words long. | S |
| 6 | everywhere | 9 rule-of-three lists flagged by the checker (§2.5). | XS |

---

## 7. Compliance

- **[CHECK]** rules → `tools/check_writing.gd` (headless, part of the dev loop). Run:
  `godot --headless --path . --script res://tools/check_writing.gd`. Report in
  `.dev/writing_check.log`; non-zero exit on any violation. A line that must break a rule
  takes a `# writing-check-ignore` comment with the reason.
- **[JUDGE]** rules are read at review. The two that catch the most: *strip the name and
  see if you can still tell who is speaking*, and *read it aloud*.
- **Definition of done for any text change:** `check_writing.gd` passes, the new text was
  read aloud once, and the entry doesn't share a skeleton with its neighbours.

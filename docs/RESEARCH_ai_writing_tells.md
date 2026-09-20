# Research — the tells that make prose read as AI-written

Written 2026-09-20. Source material for `WRITING_STYLE_GUIDE.md`, which is the
short enforceable version. This doc is the evidence: what the corpus studies
actually measured, what craft writers actually do, and what the detectors are
worth (not much).

## 0. The honest framing up front

The goal of this document is **voice quality, not detector evasion.**

The evidence that automated AI detectors are unreliable is strong and consistent:

- Liang et al. (Stanford), *Patterns* 2023, ran **seven** GPT detectors over **91 TOEFL essays by
  non-native English speakers** and measured an **average false-positive rate of 61.3%**; more than
  **90%** of the essays were flagged by at least one detector, while the same detectors were
  near-perfect on US 8th-grade essays. The authors' conclusion: "the design of many GPT detectors
  inherently discriminates against non-native authors, particularly those exhibiting restricted
  linguistic diversity and word choice."
  *(primary research — https://www.sciencedirect.com/science/article/pii/S2666389923001307)*
- Human detection is barely above chance. A summary of the literature in *The Conversation* notes
  that readers "were unable to distinguish" AI from human short stories (2021), editorial experts
  could not identify AI-written abstracts (2023), and **94% of undergraduate exam scripts written by
  ChatGPT went undetected** (2024). Participants relying on the em-dash heuristic scored "only
  marginally better than chance." Machine classifiers hit 80–98% but nobody can explain *why*, which
  makes them useless as a writing target. *(journalism, well-sourced —
  https://theconversation.com/too-many-em-dashes-weird-words-like-delves-spotting-text-written-by-chatgpt-is-still-more-art-than-science-259629)*

So: **do not write to beat a detector.** Write so that a player who has read ten thousand chat
replies this year does not feel the familiar shape under your shopkeeper's dialogue. The tells below
are useful because they are genuinely *bad writing habits* that happen to be statistically
concentrated in LLM output — not because a tool scores them.

One more honest caveat, and it is an important one for fiction: the statistical tells were mostly
measured on **expository/academic/assistant prose**. Boggia (2026) found that in the *narrative*
genre LLMs actually **undershoot** the human rate of the "not X, but Y" figure (4.1 vs 7.5 per
10,000 words), while overshooting badly in oratory (33.5 vs 14.9). Genre matters. A tell that is
loud in a Wikipedia article can be quiet or absent in a short story — and vice versa.
*(primary research — https://arxiv.org/abs/2607.21498)*

---

## 1. Executive summary — the tells ranked by loudness

Ranked by how fast a reader who has seen a lot of LLM text will clock it, in a *game writing*
context specifically.

| # | Tell | Why it's loud in games |
|---|---|---|
| **1** | **Uniform voice.** Every NPC uses the same register, same sentence length, same politeness level, same vocabulary tier. | Games give you many speakers side by side. Sameness is instantly visible in a way it isn't in an essay. |
| **2** | **The summary-restatement tail.** Every paragraph, letter or item description ends by telling the reader what it meant ("…a reminder that some things are worth mending"). | Nothing else in games does this. Human item descriptions just stop. |
| **3** | **Participial tails.** "…, creating a sense of warmth." "…, further enhancing its significance." Wikipedia's AI-cleanup guide lists these "present participle endings" as a core marker. | A single one in an item tooltip is enough. |
| **4** | **"It's not X, it's Y" / "not just X, but Y" (epanorthosis).** | The single most memed AI construction; players will quote it back at you. |
| **5** | **On-the-nose dialogue.** Characters naming their own emotions and subtext out loud. | Directly opposed to how every respected game writer works. |
| **6** | **Marker vocabulary.** *delve, tapestry, testament, underscore, boasts, nestled, meticulous, vibrant, bustling, intricate, showcase, pivotal, crucial.* | These are absolute — one "nestled" in a shop description does the damage. |
| **7** | **Rule of three everywhere.** Three adjectives, three clauses, three list items, always. | Rhythm becomes metronomic across a whole script. |
| **8** | **Low burstiness.** Every sentence 12–18 words. No fragments, no one-word lines. | Dialogue especially: real speech is jagged. |
| **9** | **Em-dash density + bold lead-ins + emoji + title-case headers.** | UI copy and in-world newspapers are where this leaks. |
| **10** | **Sensory checklists.** Sight + sound + smell, dutifully, in one paragraph. | Cozy games are the worst offenders because the genre invites it. |
| **11** | **Hedge-stacking and compulsive both-sidesing.** "Some say… though others find…" | Kills characters' opinions; a shopkeeper with no opinions is not a character. |
| **12** | **Over-explained jokes.** The punchline followed by a clause that explains the punchline. | Fatal in a cozy game, where the jokes are the texture. |

A single instance of any of these is coincidence. The Wikipedia AI-cleanup project's own meta-rule is
the right one: *"These signs cluster together in AI text, forming an identifiable 'voice' across
disparate topics. One indicator may be coincidental; multiple indicators together suggest AI
generation."* *(community-curated reference —
https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing)*

---

## 2. Lexical tells

### 2.1 The corpus evidence

**Kobak, Márquez, Horvát & Lauren, "Delving into LLM-assisted writing in biomedical publications
through excess vocabulary," *Science Advances* (2025); preprint arXiv:2406.07016.**
*(primary research — https://www.science.org/doi/10.1126/sciadv.adt3813 ·
https://arxiv.org/abs/2406.07016 · open copy https://pmc.ncbi.nlm.nih.gov/articles/PMC12219543/)*

Method, borrowed from COVID "excess mortality": take **14.2 million PubMed abstracts, 2010–2024**,
linearly extrapolate each word's frequency from 2021–2022 (skipping 2023, already contaminated), and
measure the gap against observed 2024 frequency.

Findings:

- Hundreds of **style words** spiked abruptly in 2024. The 2024 excess vocabulary was
  **~66% verbs and ~14–18% adjectives** — in sharp contrast with the COVID-era excess vocabulary,
  which was *"almost entirely content words."* That inversion is the signature: LLM influence shows
  up as **manner of saying**, not subject matter.
- Frequency ratios: **`delves` r = 28.0**, **`underscores` r = 13.8**, **`showcasing` r = 10.7.**
- Large absolute gaps on common words: `potential`, `findings`, `crucial`.
- A compact 10-word marker set the authors highlight:
  *across, additionally, comprehensive, crucial, enhancing, exhibited, insights, notably,
  particularly, within.*
- Headline estimate: **at least 13.5% of 2024 abstracts** were LLM-processed (≈200,000 papers/yr),
  rising to ~40% in some subcorpora.

**Juzek & Ward, "Why Does ChatGPT 'Delve' So Much?", COLING 2025; arXiv:2412.11385.**
*(primary research — https://arxiv.org/abs/2412.11385 ·
https://aclanthology.org/2025.coling-main.426/)*

Isolates **21 focal words** (named in the abstract: *delve, intricate, underscore*) and then asks
where they come from. Result: *"We fail to find evidence that lexical overrepresentation is caused
by model architecture, algorithm choices, or training data,"* while model testing is *"consistent
with RLHF playing a role."* Practical upshot for a writer: these words are not a subject-matter
artefact you can dodge by changing topic. They are a **taste artefact baked into the model's
preferences**, so they will show up in a tailor-shop letter as readily as in an abstract.

**Yakura, Lopez-Lopez et al., "Empirical evidence of Large Language Model's influence on human spoken
communication," arXiv:2409.01754.** *(primary research — https://arxiv.org/abs/2409.01754)*

**740,249 hours** of speech — **360,445 YouTube academic talks** and **771,591 podcast episodes** —
show an abrupt post-ChatGPT rise in ChatGPT-preferred words: **delve, comprehend, boast, swift,
meticulous**. Relevant because it kills the "but people talk like that now" defence only halfway:
people *do* increasingly talk like that, but the shift is itself traceable to the model. For a period
setting (a tailor's shop), the words still read wrong.

**Washington Post analysis of 328,744 publicly shared ChatGPT messages (gpt-4o, May 2024 – July
2025).** *(journalism — paywalled at
https://www.washingtonpost.com/technology/interactive/2025/how-detect-chatgpt-em-dash/ ; accessible
summaries: https://www.rte.ie/brainstorm/2025/1128/1545935-chatgpt-ai-writing-text-detection-words-phrases-emojis/
and https://www.bostonglobe.com/2025/11/13/business/chatgpt-writing-style-clues/)*

- `delve` is **declining** as models get tuned against it; current favourites are **`core`** and
  **`modern`**.
- **"not just X, but Y"** is *rising*.
- ✅ (white check mark) used **11×** more than humans; 🧠 and 🔹 **10×** more.
- By July 2025, **70% of all messages contained at least one emoji**, about a third contained ✅.
- Em-dash use still climbing.

Takeaway: **the word list rots.** Treat any banned-word list as a snapshot, not a law. The structural
tells (§3–§5) are far more durable than the lexical ones.

### 2.2 In a game-writing context

**BAD — item description**

> A meticulously crafted bolt of vibrant crimson wool, nestled among the shop's more humble fabrics.
> Its intricate weave stands as a testament to the enduring craft of the old mills.

Five markers in two sentences: *meticulously, vibrant, nestled, intricate, stands as a testament to,
enduring.* Note also "stands as a" — Wikipedia's guide flags **copula avoidance** specifically:
LLMs replace *is* with *"serves as a," "stands as," "marks," "functions as,"* and replace *has* with
*"features," "boasts," "maintains," "offers."*

**GOOD**

> Crimson wool, 14oz, from the Marley mills before they shut. Smells faintly of lanolin. The bolt is
> two yards short of what the label says — Grandpa never got round to fixing the label.

Concrete noun, a number, a smell that is a *fact* rather than a mood, and a detail that carries
character and plot. Nothing is described as being a testament to anything.

**BAD — shop sign / UI**

> Welcome to your bustling new shop! Delve into a vibrant world of tailoring.

**GOOD**

> HEMMING & SON — Alterations, Repairs, Mourning Wear.
> (Ring bell. Twice, if it's raining.)

---

## 3. Syntactic and structural tells

### 3.1 Epanorthosis — "not X, but Y"

**Boggia, "Artificial Epanorthosis: Why large language models overuse a classical rhetorical figure,
and how to mitigate it," arXiv:2607.21498 (2026).**
*(primary research — https://arxiv.org/abs/2607.21498)*

Epanorthosis = *"a further straightening"* — returning to a statement to correct it. The paper's
detector matches these surface templates verbatim:

- `Not X. Y` (sentence-split)
- `Not X, but Y`
- `Not only X but Y`
- `X, or rather, Y`
- `It is not X, it is Y`

Rates, per 10,000 words:

| Genre | LLM | Human baseline | Index |
|---|---|---|---|
| Oratory | 33.5 | 14.9 | **2.2× overshoot** (p=0.03) |
| Argument | — | — | overshoot |
| Journalism | 2.0 | 2.4 | parity |
| Encyclopedic | 1.4 | 1.2 | parity |
| **Narrative** | **4.1** | **7.5** | **undershoot** |
| Informal Q&A | 1.3 | 8.2 | 0.2× undershoot |

The paper proposes an **Epanorthosis Index** = model density ÷ human baseline for that genre, and
argues the target is *calibration to the human rate, not elimination.* A single one-line prompt
instruction cut the rate ~70% in their tests.

Two practical lessons:

1. The figure itself is fine — humans use it in narrative *more* than models do. What marks AI is the
   **promotional/inspirational** deployment: "It's not a coat. It's a promise."
2. The danger zone for a game is exactly the promotional register: shop taglines, achievement text,
   tutorial pep-talks, newspaper ad copy.

**BAD — mentor dialogue**

> "This isn't just a needle, apprentice. It's a conversation between your hands and the cloth."

**GOOD**

> "Hold it like you'd hold a wasp you don't want to kill."

### 3.2 The rule of three

Listed in Wikipedia's AI-writing guide as a style marker: compulsive triads of adjectives, clauses,
or list items. The tell is not one triad — it's that *every* enumeration is a triad.

**BAD**

> The workroom was warm, quiet, and full of the smell of pressed linen.

**GOOD**

> The workroom was warm. Too warm, with the iron on.

Pick two, or one, or four. Vary it. If you find three of anything, break it on purpose half the time.

### 3.3 Participial tails ("the -ing tail")

Wikipedia's guide calls these **"superficial analysis"** markers: *"present participle endings:
'further enhancing its significance'"*, *"vague attributions: 'highlighting their historical and
pedagogical significance'."* This is, for game prose, probably **the highest-value single cut**.

**BAD — tooltip**

> Pressing the seam flattens the fabric, creating a crisp finish that elevates the garment.

**GOOD**

> Press the seam. Flat seams sell.

**Rule: if a sentence's last clause begins with a present participle and explains the effect of what
just happened — delete the clause.** In almost every case the sentence is better and shorter.

### 3.4 "From X to Y" openers, and other framing scaffolds

Openers that survey a range before saying anything: "From the humblest button to the finest silk
lining, tailoring is…". Related family in the Wikipedia guide: **"Challenges and Legacy" /
"Future Outlook" section-shaped thinking**, and the formula *"Despite its…, faces several
challenges…"* followed by a vague positive close.

**BAD — in-world newspaper**

> From bustling market stalls to quiet back-street ateliers, the town's garment trade is
> experiencing a remarkable renaissance.

**GOOD**

> Three tailors on Weft Street. Two of them are Hemmings. The third is the one people go to.

### 3.5 Burstiness and sentence-length uniformity

Detection theory, and why it happens to be good craft advice.
*(vendor-documented, treat as theory not neutral research —
https://gptzero.me/news/perplexity-and-burstiness-what-is-it/)*

- **Perplexity**: how surprising the next word is. Models pick high-probability words by
  construction, so their output has low perplexity.
- **Burstiness**: defined by GPTZero as **the standard deviation of sentence lengths divided by the
  mean**. Human writing has high burstiness — long sentences next to three-word ones. AI output
  clusters.

The craft translation is simple and is good advice regardless of detectors: **measure the standard
deviation of your sentence lengths in any block of game text.** If your NPC's lines are all 11–16
words, the character has no breath.

**BAD**

> "I've been working this shop for nearly thirty years now, and I've seen a great many things."
> "The customers have changed, but the work itself has stayed much the same."
> "You'll find that patience is the most important tool you own."

Three lines, 16/14/12 words, identical shape.

**GOOD**

> "Thirty years."
> "Customers change. Work doesn't."
> "Patience. That's the tool. Everything else you can buy in Mallow Street for two and six, but
> patience they don't stock."

### 3.6 Excessive parallelism and "Here's the thing:" hooks

Parallel structure is a tool; models use it as a default gait. Watch for consecutive sentences with
matching syntax, and for the conversational-hook opener ("Here's the thing:", "The truth is:",
"Let's be honest:") — an assistant-register habit that has no business in a 1950s tailor's mouth.

---

## 4. Rhetorical and discourse tells

### 4.1 The LAMP taxonomy — what professional writers actually delete

**Chakrabarty, Laban, Wu, Xiong et al., "Can AI writing be salvaged? Mitigating Idiosyncrasies and
Improving Human-AI Alignment in the Writing Process through Edits," arXiv:2409.14509.**
*(primary research — https://arxiv.org/abs/2409.14509)*

Professional writers were hired to edit LLM-generated creative paragraphs. They independently
converged on a **seven-category taxonomy** of undesirable idiosyncrasies, then produced the **LAMP
corpus: 1,057 LLM paragraphs edited to that taxonomy**. GPT-4o, Claude 3.5 Sonnet and Llama-3.1-70b
did not differ meaningfully — *"revealing common limitations across model families."*

| Category | Definition (paper's own wording) | Share of edits |
|---|---|---|
| Awkward word choice and phrasing | *"misused or disproportionate use of certain words"*, unclear pronouns, passive voice | **28%** |
| Poor sentence structure | improper transitions, run-ons, over-complex constructions | **20%** |
| Unnecessary / redundant exposition | *"excessive, repetitive, or implied information"* — restating the obvious; violates show-don't-tell | **18%** |
| Cliché | *"phrases, ideas, or sentences overused to the point of losing their original impact"* | **17%** |
| Purple prose | *"excessively elaborate writing that disrupts narrative flow"* | — |
| Lack of specificity and detail | *"reliance on broad generalizations"* | — |
| Tense inconsistency | *"inadvertent shifts between past, present, and future tenses"* | — |

A cliché example the editors struck:
> "The realization that she was alone here, truly alone, settled over her like a heavy blanket."

That "truly alone" intensifier-repetition plus simile-of-weight is an extremely common LLM move and
worth blacklisting by shape, not by wording.

**The single most game-relevant row is "unnecessary/redundant exposition" at 18%.** This is the
engine behind the summary-restatement ending, the explained joke, and the stated emotion.

### 4.2 Summary-restatement endings

**BAD — end of a letter from Grandpa**

> …so take care of the place, and take care of yourself.
>
> In the end, a shop is only ever the people who walk into it. That, I think, is the real
> inheritance.

**GOOD**

> …so take care of the place.
>
> The kettle sticks. Lift, then turn.
>
> — G.

The second one hurts more, because it trusts the reader.

**Rule: never end a piece of in-world text with a sentence that tells the reader what the piece
meant.** Cut the last paragraph of any letter, newspaper column or journal entry and check whether
it still lands. It usually lands harder.

### 4.3 Hedge-stacking and compulsive both-sidesing

*The Conversation* lists hedging ("often," "generally") among the commonly-cited tells, alongside
"redundancy," "overreliance on lists," and a *"polished, neutral tone."*
Wikipedia's guide flags **"vague associations"** — *"in connection with / connected to / associated
with / particularly associated"* replacing direct statements.

Characters must have opinions. Neutrality is an assistant's safety behaviour, not a personality.

**BAD**

> "Some tailors prefer a hand-rolled hem, though others find the machine finish perfectly
> serviceable. It really depends on the garment."

**GOOD**

> "Machine hem. On a wedding dress." *(long pause)* "Well. It's her wedding."

### 4.4 Over-signposting and framing sentences

The habit of announcing what is about to be said before saying it. In tutorials this is deadly,
because the player is waiting.

**BAD — tutorial**

> Let's talk about cutting. Cutting is an important part of tailoring, and getting it right will help
> you throughout the game. Here's how it works: hold the shears and follow the chalk line.

**GOOD**

> Follow the chalk. Slow is fine. Wobbly is not.

### 4.5 Explaining the joke

**BAD**

> "Mrs. Ashby wants it taken in again. Third time this month." *(He sighs.)* "She's not losing
> weight; she just likes being measured."

**GOOD**

> "Mrs. Ashby wants it taken in. Again."
> "Is she—"
> "She is not losing weight."

### 4.6 Naming the emotion instead of showing behaviour

This is screenwriting's **"on-the-nose dialogue"**: *"lines where characters say exactly what they
think, feel, or intend without any subtext or nuance,"* which *"negatively impacts the authenticity
of a character because it explicitly lays out their thoughts and feelings without allowing for
interpretation."* *(craft, secondary/listicle tier —
https://nofilmschool.com/on-the-nose-dialogue ·
https://industrialscripts.com/on-the-nose-dialogue/)*

Jon Ingold's rule in *Sparkling Dialogue* (AdventureX 2018) is the game-specific version: think about
**what is unsaid**, and don't ask characters questions they already know the answers to.
*(craft source, notes by Robert Yang —
https://www.blog.radiator.debacle.us/2018/11/notes-on-sparking-dialogue-great.html)*

**BAD**

> "I feel overwhelmed by how much needs fixing in this shop. It reminds me of how much I miss him."

**GOOD**

> "There's a hole in the roof." *(beat)* "He'd have patched it with a coat."

---

## 5. Punctuation and typography tells

Sources: Wikipedia AI-cleanup guide (community-curated, unusually concrete); Washington Post corpus
(journalism); McGill OSS on em-dashes (science communication).

**Wikipedia's formatting/markup list, near-verbatim:**
- Excessive boldface and em dashes
- Title case in unusual places
- Curly quotation marks and apostrophes (’ “ ” instead of ' " )
- Headings containing only subheadings; skipped heading levels
- Emoji as formatting
- Thematic breaks (`---`) between sections
- Markdown leaking into a non-Markdown context

**Em dashes specifically.** Independent measurement cited by McGill's Office for Science and Society
puts **GPT-4.1 at 3.28× the human em-dash rate in standard essays**; the phenomenon has been
nicknamed the "ChatGPT hyphen."
*(science communication, citing independent researcher Freeburg —
https://www.mcgill.ca/oss/article/critical-thinking-student-contributors-technology/why-did-llms-steal-our-em-dashes)*
Note the honest counterpoint from *The Conversation*: readers using em-dash spotting performed "only
marginally better than chance." **The em dash is a real statistical signal and a bad human
heuristic.** Don't ban it; ration it.

**Emoji.** ✅ at **11×** human rate; 🧠 and 🔹 at **10×**; **70%** of gpt-4o messages carried at least
one by mid-2025 (Washington Post). A "🚀 **Big News!**" header in an in-world newspaper is a period
violation *and* an AI tell.

### Game-specific rules

| Context | Rule |
|---|---|
| Item descriptions | At most one em dash per *screen*, not per line. Prefer a full stop or a comma. |
| Dialogue | Em dash = interruption only (`"But I—"`). Ellipsis = trailing off. Don't use em dash for parenthesis in speech. |
| In-world newspapers | Use period-correct typography: small caps, rules, bylines. No bold lead-ins, no bullet lists, no emoji, no title-case subheads unless the era used them. |
| UI microcopy | No bold-colon lead-ins (`**Tip:** …`). No bullet list where two short sentences work. Sentence case for buttons unless the whole UI is caps. |
| Letters | Handwriting doesn't have headers. No section titles inside a letter. |
| Tutorials | One instruction per line. Never a bulleted three-item list of tips. |

**BAD — tutorial panel**

> **🧵 Getting Started with Tailoring**
>
> - **Measure:** Take the customer's measurements carefully — accuracy matters here.
> - **Cut:** Follow the chalk line to cut your fabric — precision creates a better fit.
> - **Sew:** Stitch the pieces together, creating a finished garment.

Every tell at once: emoji header, title case, bold lead-ins, bullets where prose belongs, rule of
three, em dashes, two participial tails.

**GOOD**

> Measure her. Write it down; you will forget.
> Cut on the chalk.
> Sew. Then press, or it looks homemade.

---

## 6. Voice tells specific to fiction and dialogue

### 6.1 Everyone sounds the same

This is the loudest tell in a game because the player meets twenty speakers. It is also the
best-evidenced *mechanism*: Doshi & Hauser, *Science Advances* (2024), gave writers LLM story ideas
and found the resulting stories were rated "more creative, better written, and more enjoyable" —
**and were more similar to each other** than human-only stories, a *"social dilemma where writers are
individually better off, but collectively a narrower scope of novel content is produced."*
*(primary research — https://www.science.org/doi/10.1126/sciadv.adn5290)*

Applied to one game script: every NPC drifts toward the same competent median.

**Fix: give every named character a written idiolect sheet before you write a line.** At minimum:
- one word they always use and one they never use
- typical line length (3 words? 25?)
- do they finish their sentences?
- do they ask questions, or only answer?
- one grammatical error or regionalism that is theirs alone

Then read all of a character's lines in isolation, with the name stripped, and check you can still
tell who it is.

### 6.2 Dialogue that is too grammatical

Real speech has fragments, restarts, and things dropped mid-clause. LLM dialogue is punctuated like
prose. The Narrative Dept's guidance on barks — *"short lines of dialog yelled in the background"* —
shows the target register: *"I've been shot!"*, *"Morning"*, *"Move it, buddy"*, *"Cockles and
mussels!"*, *"You buying today or what?"* — and warns against writing them *"in a void,"* which
produces *"grinding, uninspiring grunt work."*
*(craft source — https://www.thenarrativedept.com/blog/barks)*

Their framing is useful: **barks are the game's way of talking back.** Work out the silent question
the player is asking ("Is this open?" "What's for sale?") and answer *that*, in character.

**BAD — shop barks**

> "Good morning! Welcome to the shop. Please let me know if you need any assistance today."
> "I'm afraid we're closed at the moment. Please come back tomorrow."

**GOOD**

> "Mornin'."
> "Don't touch the silk."
> "We're shut. …Fine. One thing."
> "That's Mrs. Ashby's. Don't."

### 6.3 Uniform politeness

Models are RLHF'd to be agreeable; characters inherit it. Nobody is rude, nobody interrupts, nobody
refuses. Deliberately budget rudeness: at least one NPC who will not help you, one who talks over
you, one who gives a wrong answer confidently.

### 6.4 Sensory-detail checklists

The cozy-genre trap: sight, sound, *and* smell in one paragraph, every paragraph.

**BAD**

> Golden afternoon light spilled across the worn floorboards, the soft whir of the machine mixing
> with the warm scent of pressed cotton.

**GOOD**

> The machine needs oiling. You can hear it in the bobbin.

One sense, chosen because it carries information. Anton Chekhov's broken-bottle-glint principle,
applied to a sewing room.

### 6.5 "Warm, cozy" filler adjectives

`warm, cozy, gentle, soft, quaint, charming, whimsical, bustling, vibrant, humble, inviting,
delightful, rustic, timeless`. These are mood-assertions, not descriptions. They tell the player how
to feel instead of causing the feeling. Replace an adjective with a **fact** wherever possible:
not "a cozy chair" but "the chair with the cushion someone sewed a cat onto, badly."

### 6.6 Named emotions instead of behaviour

The LAMP category "unnecessary/redundant exposition" (18% of expert edits) in its purest form.

| Named emotion (BAD) | Behaviour (GOOD) |
|---|---|
| She looked nervous. | She kept re-pinning the same seam. |
| He was clearly proud of the work. | He turned the jacket so the lining showed. |
| The customer seemed disappointed. | "Mm." She put it back on the rack, facing the wall. |

---

## 7. What human game writers do instead

### 7.1 Specificity over evocation

Kentucky Route Zero's prose is characterised by *"characters' deadpan reactions to bizarre events"*
balancing *"Appalachian plain speak with speculative fiction"*, with the fantastical *"rooted in
seemingly mundane struggles… predatory lending and bizarre financial machinery."* The poetry is in
the mundane, not in the adjectives.
*(criticism — https://www.critical-distance.com/2019/09/26/kentucky-route-zero/ ; academic —
https://philarchive.org/archive/STEIML-3)*

### 7.2 Structure as characterisation

Jon Ingold, *Sparkling Dialogue* (AdventureX 2018), via Robert Yang's notes:
- Give the player **Accept / Reject / Deflect**: *"Accept: follow the current topic, answer their
  question, be cooperative. Reject: go on the attack, you've had enough of this nonsense. Deflect:
  escape the confrontation or change subject."*
- *"Use a loop when the conversation is circling around in its current intensity / stakes, and then
  leave the loop when the conversation has escalated."*
- **Trapdoors**: let the player skip ahead; refusing to engage is a valid conversational move.
- *"Your use of branching structure is a form of characterization."*
- Don't over-explain; don't ask characters things they already know.
*(craft source — https://www.blog.radiator.debacle.us/2018/11/notes-on-sparking-dialogue-great.html)*

### 7.3 Writing is more than dialogue

Hannah Nicklin, *Writing for Games: Theory and Practice* (Routledge, 2022) defines the writer's remit
as *"the building of characters, worlds, plot, structure, pacing, cadence, dialogue, UI text, choice
text, exposition, characterisation, and character journeys,"* and narrative design as *"game design
with story at its heart, where you are the advocate for the story in the design of the game."* The
inclusion of **UI text and choice text** in the writer's remit is the relevant part here: tooltips
and button labels are voice surfaces, not neutral ones.
*(craft source — https://www.routledge.com/Writing-for-Games-Theory-and-Practice/Nicklin/p/book/9781032023052 ·
review by Emily Short https://emshort.blog/2022/07/05/writing-for-games-theory-practice-hannah-nicklin/)*

### 7.4 Rewriting is the craft

Disco Elysium: roughly a million words over five years, with **~70% of the content rewritten at least
once** and some scenes going through four or five versions; Kurvitz ran a "mass editing" process
where writers, translators, artists and strangers marked anything confusing or unrealistic.
*(secondary, interview-derived — https://moonshakebooks.com/2022/06/11/helen-hindpere-disco-elysium-narrative-analysis/)*
Whatever the exact figures, the principle is the durable one: **LLM prose is first-draft-shaped, and
first drafts are what these tells are made of.** The anti-AI move is not a word list; it's a second
pass.

### 7.5 Wordless specificity

*Unpacking* tells a full life story with **no words at all**, purely through which objects a person
owns and where they put them. For a shopkeeping game, the lesson is that a chipped mug in the right
place beats a paragraph about home.
*(general criticism — https://en.wikipedia.org/wiki/Cozy_game ; *Strange Horticulture* uses item
descriptions as puzzle data, which forces them to be concrete: https://en.wikipedia.org/wiki/Strange_Horticulture)*

### 7.6 Microcopy principles worth stealing

From general UX-writing practice (**listicle/blog tier — flagged as such**:
https://uxwritinghub.com/mobile-games-microcopy/ ·
https://www.smashingmagazine.com/2024/06/how-improve-microcopy-ux-writing-tips-non-ux-writers/):
- **One microcopy item = one idea. One entity = one term.** (Don't call it "fabric" here and
  "textile" there.)
- Interactive elements start with an **active verb**.
- Copy must be *"concise and useful, while fitting in with the narrative design of the game."*

---

## 8. Banned / suspect word and phrase list

Assembled from: Kobak et al. 2025 (PubMed excess vocabulary), Juzek & Ward 2025 (focal words),
Yakura et al. (spoken corpus), Wikipedia:Signs of AI writing, Washington Post corpus.

**Use as a grep list, not a law.** Any of these can be the right word. The rule is: *if you
didn't reach for it, it doesn't stay.*

### Verbs (the largest excess class — ~66% of 2024 excess style words)
`delve`, `delves`, `delving`, `underscore(s)`, `showcase(s)`, `showcasing`, `highlight(s)`,
`emphasize/emphasizing`, `foster(ing)`, `garner`, `enhance/enhancing`, `bolster(ed)`, `align with`,
`leverage`, `navigate` (figurative), `boast(s)`, `elevate(s)`, `unlock`, `embark`, `weave/weaving`,
`comprehend`, `exhibited`, `reflect(ing)`, `serve(s) as`, `stand(s) as`, `mark(s)`, `function(s) as`,
`feature(s)`, `maintain(s)`, `offer(s)`

> Note the copula-avoidance cluster at the end: *serves as / stands as / marks / functions as* for
> **is**, and *features / boasts / maintains / offers* for **has**. Just write "is" and "has."

### Adjectives
`meticulous(ly)`, `intricate`, `vibrant`, `bustling`, `crucial`, `pivotal`, `comprehensive`,
`robust`, `seamless`, `nuanced`, `profound`, `rich`, `enduring`, `timeless`, `invaluable`,
`valuable`, `renowned`, `groundbreaking`, `diverse`, `myriad`, `unwavering`, `quaint`, `whimsical`,
`cozy`, `warm` (as a mood claim), `humble`, `charming`, `delightful`, `key`, `notable`,
`significant`, `core`, `modern`, `swift`

### Nouns
`tapestry`, `testament`, `landscape` (figurative), `realm`, `journey` (figurative), `interplay`,
`intricacies`, `insights`, `complexities`, `nuance`, `symphony`, `beacon`, `cornerstone`,
`treasure trove`, `array`, `plethora`, `resilience`, `essence`, `haven`, `sanctuary`, `findings`,
`potential`, `implication`, `complexity`

### Adverbs / connectives
`additionally` (esp. sentence-initial), `moreover`, `furthermore`, `notably`, `particularly`,
`crucially`, `importantly`, `ultimately`, `undoubtedly`, `arguably`, `across`, `within`, `overall`,
`in essence`

### Set phrases and frames
`it's worth noting that`, `it's important to note`, `navigate the complexities of`,
`a testament to`, `stands as a testament`, `a tapestry of`, `a symphony of`, `nestled in/among`,
`in the heart of`, `at the end of the day`, `in conclusion`, `in today's world`,
`when it comes to`, `dive into`, `delve into`, `unlock the secrets of`, `a treasure trove of`,
`plays a crucial role`, `marks a pivotal moment`, `represents a significant shift`,
`setting the stage for`, `contributing to the`, `reflecting broader`,
`whether you're X or Y`, `from X to Y`, `not just X, but Y`, `it's not X, it's Y`,
`this isn't just a X — it's a Y`, `here's the thing`, `let's be honest`, `the truth is`,
`more than just`, `a reminder that`, `and that's what makes it special`

### Punctuation / typography
`—` (ration it), curly `’ “ ”` in body text you intend to be plain, `**Bold lead-in:**` in lists,
`Title Case Headers`, emoji as formatting (esp. ✅ 🧠 🔹 🚀 ✨), `---` thematic breaks inside prose,
bullet lists in dialogue or letters.

---

## 9. Structural rules (the checklist)

Apply to every line of game text before it ships.

1. **Cut the participial tail.** If the final clause starts with an `-ing` verb and explains the
   effect of the sentence, delete it.
2. **Never restate the thesis at the end.** Delete the last sentence of any letter, article, journal
   entry or description and see if it improves. It usually does.
3. **One idea per line of dialogue.** If a line contains a fact *and* a feeling *and* a joke, split
   it across three lines or three characters.
4. **Vary sentence length deliberately.** In any block of 6+ sentences, include at least one under 5
   words and one over 20. Check the spread, not the average.
5. **Break the triad.** If you wrote three of anything, make it two or four half the time.
6. **Budget the em dash.** One per screen of text, maximum. In dialogue it means interruption only.
7. **Replace mood-adjectives with facts.** "Cozy" → the specific thing that makes it cozy.
8. **Nobody names their own emotion.** Convert to behaviour, object, or silence.
9. **No joke gets a second clause.** If the punchline needs explaining, the punchline is wrong.
10. **Every named character gets an idiolect sheet** before their first line. Strip the names and
    check you can still tell them apart.
11. **At least one character is unhelpful.** Budget rudeness, refusal, and being wrong.
12. **One sense per description**, chosen for information, not coverage.
13. **No framing sentence before the answer.** Tutorials start with the verb.
14. **No bold lead-ins, bullets or emoji in in-world text.** In-world documents obey their era's
    typography, not Markdown's.
15. **Use concrete nouns and real numbers.** "14oz wool," "two and six," "third time this month."
16. **Read it aloud.** Every tell in this document survives silent reading and dies out loud.
17. **Second pass, always.** Tells are first-draft artefacts. (§7.4)

---

## 10. For a cozy shopkeeping game specifically

The cozy genre is the **worst-case habitat** for these tells, because the genre's surface features
(warmth, comfort, gentle stakes, small pleasures) are exactly the register LLMs default to. "Warm
afternoon light," "a quiet moment of calm," "the simple joy of a job well done" — these are
simultaneously the genre's vocabulary and the model's.

So the differentiator cannot be *mood*. It has to be **specificity and restraint**.

### Ten rules for this project

1. **Every object has a history, not an atmosphere.** Not "a cozy old sewing machine" but "a Singer
   99K with a cracked bobbin cover and someone's initials scratched into the bed."
2. **Numbers are your friend.** Prices, ounces, yardages, dates, times, door numbers, "three and
   six." Numbers cannot be generated warmly; they are either right or wrong, and rightness reads as
   craft.
3. **Customers want specific, slightly unreasonable things.** "Let it out an inch, but don't tell my
   husband" beats "a customer needs an alteration." *Strange Horticulture* works because item
   descriptions are *puzzle data* — which forces them to be concrete. Give your item text a job
   beyond flavour and it will stop drifting into flavour-text mush.
4. **Let the shop be slightly broken.** Cozy without friction is AI-shaped. The kettle sticks. The
   bell rings twice. The third drawer doesn't open.
5. **The grandfather should be specific and a bit annoying.** A dead relative who was purely wise and
   warm is the least human thing you can write. Give him one bad habit the player has to clean up
   after — literally, in the renovation.
6. **Barks over speeches.** Four words beats a sentence. Build the shopkeeper's voice out of
   fragments the player hears a hundred times, and make at least three of them jokes that never
   explain themselves.
7. **The newspaper is a period artefact, not a blog post.** Bylines, classified ads with abbreviated
   nonsense, a correction notice, a headline with a pun nobody would print today. No bullet lists.
   No bold lead-ins. Set it in the era's typography.
8. **The letters are handwriting.** No headings, no structure, digressions, crossings-out, a PS that
   carries the actual emotional payload. End mid-thought or on a mundane instruction, never on a
   moral.
9. **Tutorial text is imperative and short.** "Follow the chalk." Not "Let's learn about cutting!"
   The mentor's know-how lines should sound like a person who is slightly impatient with you, which
   is also how real teaching sounds.
10. **Reputation/economy UI: use trade language, not product language.** Not "Customer Satisfaction:
    Excellent" but "Word's getting round." Not "Unlock Premium Textiles" but "Bellweather will take
    your call now."

### The five-minute audit for any new text in this project

```
grep -inE "delve|tapestry|testament|nestled|meticulous|vibrant|bustling|intricate|
           showcase|underscore|boasts|whimsical|timeless|a symphony of|
           it's not just|not just a|more than just|a reminder that|
           worth noting|ultimately|in conclusion|at the end of the day" <file>
```
Then, by eye:
- any sentence ending in `, -ing …` → cut the clause
- any final sentence that summarises → cut the sentence
- more than one `—` on screen → replace with `.` or `,`
- three adjectives in a row → keep one
- any character naming their own feeling → replace with a physical action
- read the whole file aloud; anything you stumble over in a *pleasing* way, keep

---

## 11. Further reading

### Primary research — lexical
- Kobak et al., *Delving into LLM-assisted writing in biomedical publications through excess
  vocabulary*, Science Advances (2025) — https://www.science.org/doi/10.1126/sciadv.adt3813
  (preprint: https://arxiv.org/abs/2406.07016 ; open:
  https://pmc.ncbi.nlm.nih.gov/articles/PMC12219543/)
- Juzek & Ward, *Why Does ChatGPT "Delve" So Much?*, COLING 2025 —
  https://aclanthology.org/2025.coling-main.426/ · https://arxiv.org/abs/2412.11385
- Yakura, Lopez-Lopez et al., *Empirical evidence of Large Language Model's influence on human spoken
  communication* — https://arxiv.org/abs/2409.01754
- Gray, *Delving into PubMed records: some terms in medical writing have drastically changed after
  the arrival of ChatGPT* (medRxiv preprint) —
  https://www.medrxiv.org/content/10.1101/2024.05.14.24307373

### Primary research — structure and style
- Boggia, *Artificial Epanorthosis: Why large language models overuse a classical rhetorical figure,
  and how to mitigate it* (2026) — https://arxiv.org/abs/2607.21498
- Chakrabarty et al., *Can AI writing be salvaged? … through Edits* (LAMP corpus, seven-category
  taxonomy) — https://arxiv.org/abs/2409.14509
- Doshi & Hauser, *Generative AI enhances individual creativity but reduces the collective diversity
  of novel content*, Science Advances (2024) — https://www.science.org/doi/10.1126/sciadv.adn5290
- *Beyond checkmate: exploring the creative chokepoints in AI text* —
  https://arxiv.org/abs/2501.19301

### Detection reliability and bias
- Liang et al., *GPT detectors are biased against non-native English writers*, Patterns (2023) —
  https://www.sciencedirect.com/science/article/pii/S2666389923001307 ·
  https://arxiv.org/abs/2304.02819
- The Markup, *AI Detection Tools Falsely Accuse International Students of Cheating* (journalism) —
  https://themarkup.org/machine-learning/2023/08/14/ai-detection-tools-falsely-accuse-international-students-of-cheating
- *The Conversation*, *Too many em-dashes? Weird words like 'delves'?* (journalism, well-sourced) —
  https://theconversation.com/too-many-em-dashes-weird-words-like-delves-spotting-text-written-by-chatgpt-is-still-more-art-than-science-259629
- GPTZero, *What is perplexity & burstiness for AI detection?* (vendor documentation — treat as
  theory, not neutral evidence) — https://gptzero.me/news/perplexity-and-burstiness-what-is-it/

### Practical tell catalogues
- **Wikipedia:Signs of AI writing** — the most concrete and continuously updated catalogue in
  existence; community-curated rather than peer-reviewed, but backed by thousands of real cleanup
  cases — https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing
- Washington Post, *What are the clues that ChatGPT wrote something? We analyzed its style*
  (328,744 messages; paywalled) —
  https://www.washingtonpost.com/technology/interactive/2025/how-detect-chatgpt-em-dash/
  (accessible summary: https://www.rte.ie/brainstorm/2025/1128/1545935-chatgpt-ai-writing-text-detection-words-phrases-emojis/)
- McGill OSS, *Why Did LLMs Steal Our Em-Dashes?* — https://www.mcgill.ca/oss/article/critical-thinking-student-contributors-technology/why-did-llms-steal-our-em-dashes

### Game writing craft
- Emily Short's Interactive Storytelling (blog; see the *Conversation* article index) —
  https://emshort.blog/ · https://emshort.blog/how-to-play/writing-if/my-articles/conversation/
- Robert Yang's notes on Jon Ingold's *Sparkling Dialogue* (AdventureX 2018) —
  https://www.blog.radiator.debacle.us/2018/11/notes-on-sparking-dialogue-great.html
- The Narrative Dept, *How to write for video games, Level One: Barks* —
  https://www.thenarrativedept.com/blog/barks
- Hannah Nicklin, *Writing for Games: Theory and Practice* (Routledge, 2022) —
  https://www.writingfor.games/ ; Emily Short's review —
  https://emshort.blog/2022/07/05/writing-for-games-theory-practice-hannah-nicklin/
- Game Developer, *The best narrative talks from GDC* —
  https://www.gamedeveloper.com/marketing/the-best-narrative-talks-from-gdc
- Game Developer, *8 Key Principles of Writing Effective Game Dialogue* (industry blog tier) —
  https://www.gamedeveloper.com/game-platforms/8-key-principles-of-writing-effective-game-dialogue
- Critical Distance, *Kentucky Route Zero* criticism roundup —
  https://www.critical-distance.com/2019/09/26/kentucky-route-zero/
- Stenros/Steiner (PhilArchive), *It's More Like a Tendency: Trajectories of the Literary in Kentucky
  Route Zero* — https://philarchive.org/archive/STEIML-3
- Moonshake Books, *Robert Kurvitz & Helen Hindpere: Disco Elysium* narrative analysis (secondary) —
  https://moonshakebooks.com/2022/06/11/helen-hindpere-disco-elysium-narrative-analysis/

### Microcopy (listicle / blog tier — flagged)
- UX Writing Hub, *5 UX Writing Case Studies of Mobile Games Microcopy* —
  https://uxwritinghub.com/mobile-games-microcopy/
- Smashing Magazine, *How To Improve Your Microcopy* —
  https://www.smashingmagazine.com/2024/06/how-improve-microcopy-ux-writing-tips-non-ux-writers/
- No Film School / Industrial Scripts on on-the-nose dialogue —
  https://nofilmschool.com/on-the-nose-dialogue · https://industrialscripts.com/on-the-nose-dialogue/

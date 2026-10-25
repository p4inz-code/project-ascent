class_name TauntLines
extends RefCounted
## PIP's lines (STRONG mode only). They mock the PLAY, never the person, and every roast is built so the
## player walks away feeling BIGGER: the longer they suffer, the more the lines turn into a flex
## ("everyone else quit at 20"), and a clear is celebrated loudly. Source and review notes:
## docs/TAUNT_LINES_review.md. Placeholders: {n} deaths this level, {pct} progress at death.
##
## Banned (tests/test_taunts.gd scans every line): motherfucker, son of a bitch, any mother / family /
## parent reference, slurs, gendered insults, bastard, real people, self-harm.

const BANNED := ["motherfucker", "son of a bitch", "mother", "mom", "father", "dad", "parent", "family", "sister",
	"brother", "bitch", "cunt", "bastard", "nigg", "fagg", "retard", "slut", "whore", "kill yourself", "suicide",
	"die in a fire", "trump", "biden", "elon"]
## Words the Language setting bleeps in BLEEPED mode.
const SWEARS := ["fucking", "fuck", "shit", "shitty", "ass", "damn", "hell", "ass-kickings"]

const T1 := ["Noted.", "That was a choice.", "The floor remains undefeated.", "Interesting. Wrong, but interesting.",
	"Respawning. Dignity not included.", "One.", "I will pretend I did not see that."]

const T2 := ["Death number {n}. I am keeping a spreadsheet.", "You and this spot are becoming close friends.",
	"Bold strategy. Let us see if it pays off. (It did not.)", "Have you tried not dying? Just an idea."]
const T2_CAUSE := {
	"spikes": ["The spikes did not even move. That is the part that hurts."],
	"fall": ["Gravity: 1. You: still 0."],
	"fire": ["It was literally glowing. Literally."],
	"lava": ["That is lava. It is hot. Everyone knows this."],
	"crusher": ["It went down. You were under it. Physics is not a mystery."],
	"chase": ["The thing behind you is better at being behind you than you are at being ahead."],
	"enemy": ["Beaten by something with no legs. Hm."],
	"ice": ["Ice is slippery. Shocking, I know."],
}

const T3 := ["{n} deaths. At this point the level is just a pet that bites you.", "I have seen toasters with better timing.",
	"You are not stuck. You are committing to the bit.", "My sensors say skill issue. My sensors never lie.",
	"You jumped early, you jumped late, and you jumped like you hate your own thumbs.",
	"Is your controller plugged in, or is that on purpose?",
	"Most people would have quit by now. You did not. I noticed."]
const T3_CAUSE := {
	"spikes": ["Spikes. Stationary. Same place as last time. Damn."],
	"fall": ["You walked off the edge like it owed you money."],
	"fire": ["Orange. Loud. Hissing. You saw it, right? Right?"],
	"lava": ["Swan dive into the hot stuff, take {n}. Judges say: ten out of ten for commitment."],
	"crusher": ["Crushing is its entire job and you let it have it."],
	"enemy": ["Killed by a drone. I am putting that in your biography."],
	"ice": ["The ice did not push you. You did the sliding. You did that."],
}

const T4 := ["{n} deaths. Holy shit, that is actually impressive.",
	"Damn. You died to that? A toddler would have dodged that out of spite.",
	"You are fucking up this section with real dedication.",
	"I have seen ass-kickings with more dignity than this.",
	"That was not a mistake, that was a performance. Standing ovation, for fuck's sake.",
	"Your thumbs are filing a complaint. Against you.",
	"Everyone else quit before this. You are still here. Idiot. Respect."]
const T4_CAUSE := {
	"spikes": ["Spikes. Not moving. Exactly where they were. And still, shit."],
	"fall": ["You stepped off the edge like gravity needed the help. Fuck."],
	"fire": ["Fire. Orange. Loud. Fuck me, you walked into it."],
	"lava": ["Face first into the hot shit again. Bravo."],
	"crusher": ["It crushes. That is its whole job. You were the job."],
	"chase": ["Time ran out because you spent it dying. Efficient as hell."],
	"enemy": ["Killed by a fucking drone. I am framing this."],
	"ice": ["Slippery tiles. Shocking. Slide, slide, shit."],
}
const T4_PROGRESS := ["{pct} percent and you ate shit. Beautiful."]

const T5 := ["{n}. Fucking {n}. I stopped counting at twelve and kept counting anyway.",
	"You have reached the part of the game where I have no shits left to give and you have no tries left to waste.",
	"The level is not hard. You are just consistently, creatively, spectacularly wrong. Every. Fucking. Time.",
	"Do you want this, or do you want to feed the spikes? I cannot tell, and neither can the spikes.",
	"That death was so bad I am sending it to the other AIs for fun.",
	"Go ahead, try again. I am not mad. I am recording this for science. Shitty science.",
	"This spot has your name on it. Not literally. Yet.",
	"Stubborn idiot. Keep going.", "Absolute disaster. Beautiful. Again.",
	"Holy fuck, you got further. I am as surprised as you are. Do not get cocky.",
	"Ninety-seven percent of players never see this section. Look at you, suffering in the elite lounge."]
const T5_SAME_SPOT := ["Same spot. Again. The spot loves you.", "If this was a relationship, the spot would have a restraining order."]
const T5_CLOSE := ["{pct} percent. So close it is insulting.", "{pct} percent and you fucked it. That is a special kind of talent."]

## The ego payoffs: a clear is celebrated, in proportion to how much it hurt.
const CLEAR_EASY := ["Cleared. In {n} tries. I will allow it.", "Clean. Do not let it go to your head. Let it go to your head a little."]
const CLEAR_STREAK_MID := ["...Fine. That was clean.", "You did that. On purpose. I saw it."]
const CLEAR_STREAK_HARD := ["Holy shit, you did it. Do not tell anyone I was impressed.",
	"{n} tries. Most players never get that. You are not most players.",
	"There. THAT is what it looks like when somebody refuses to quit. Fucking legend."]
const BOSS_DEFEATED := ["The boss is dead. Your dignity? Intact, actually. Well done."]
const NEAR_WIN := ["So close to winning. Please do not choke. ...You did not choke."]


## The tier for this death. Harder levels (15+) reach the harsh tiers sooner.
static func tier_for(attempts: int, level: int) -> int:
	var hard := level >= 15
	var t4_at := 10 if hard else 15
	var t3_at := 6 if hard else 7
	var t2_at := 3
	if attempts >= t4_at + 5:
		return 5
	if attempts >= t4_at:
		return 4
	if attempts >= t3_at:
		return 3
	if attempts >= t2_at:
		return 2
	return 1


## Every line of every pool, for the language scan.
static func all_lines() -> Array:
	var out: Array = []
	for pool in [T1, T2, T3, T4, T4_PROGRESS, T5, T5_SAME_SPOT, T5_CLOSE, CLEAR_EASY, CLEAR_STREAK_MID,
			CLEAR_STREAK_HARD, BOSS_DEFEATED, NEAR_WIN]:
		out.append_array(pool)
	for d in [T2_CAUSE, T3_CAUSE, T4_CAUSE]:
		for k in d:
			out.append_array(d[k])
	return out


## Lines that mention a banned word (whole words only for the short ones).
static func violations(lines: Array) -> Array:
	var bad: Array = []
	for l in lines:
		var low := String(l).to_lower()
		for w in BANNED:
			var found := false
			if w.length() <= 4:
				var rx := RegEx.new()
				rx.compile("\\b" + w + "\\b")
				found = rx.search(low) != null
			else:
				found = low.contains(w)
			if found:
				bad.append("%s  <- '%s'" % [l, w])
	return bad


## The pool for a death. `cause` may be empty; `pct` < 0 means unknown.
static func pool_for(tier: int, cause: String, pct: float, same_spot: bool) -> Array:
	var pool: Array = []
	match tier:
		1:
			pool = T1.duplicate()
		2:
			pool = T2.duplicate()
			pool.append_array(T2_CAUSE.get(cause, []))
			pool.append_array(T2_CAUSE.get(cause, []))
		3:
			pool = T3.duplicate()
			pool.append_array(T3_CAUSE.get(cause, []))
			pool.append_array(T3_CAUSE.get(cause, []))
		4:
			pool = T4.duplicate()
			pool.append_array(T4_CAUSE.get(cause, []))
			pool.append_array(T4_CAUSE.get(cause, []))
			if pct >= 0.0:
				pool.append_array(T4_PROGRESS)
		_:
			pool = T5.duplicate()
			pool.append_array(T4_CAUSE.get(cause, []))
			if same_spot:
				pool.append_array(T5_SAME_SPOT)
				pool.append_array(T5_SAME_SPOT)
			if pct >= 90.0:
				pool.append_array(T5_CLOSE)
				pool.append_array(T5_CLOSE)
	return pool


static func fill(line: String, n: int, pct: float) -> String:
	return line.replace("{n}", str(n)).replace("{pct}", str(int(round(pct))) if pct >= 0.0 else "?")


## BLEEPED language: swear words become asterisks of the same length.
static func bleep(text: String) -> String:
	var out := text
	for w in SWEARS:
		var rx := RegEx.new()
		rx.compile("(?i)\\b" + w + "\\b")
		out = rx.sub(out, "*".repeat(w.length()), true)
	return out


static func clear_line(attempts: int, level: int, boss: bool) -> String:
	if boss:
		return BOSS_DEFEATED[0]
	var pool: Array
	var tier := tier_for(attempts, level)
	if attempts <= 2:
		pool = CLEAR_EASY
	elif tier <= 3:
		pool = CLEAR_STREAK_MID
	else:
		pool = CLEAR_STREAK_HARD
	return pool[randi() % pool.size()]

extends Node
class_name DialogueLibrary

const FOREST_PLAYERS_SPAWN := [
	{"speaker":"sidekick", "text":"Whoa. Okay. That was... not a normal elevator ride."},
	{"speaker":"sidekick", "text":"One second we’re looking at Grandma’s fading book, and the next we’re here. You’re seeing this too, partner?"},
	{"speaker":"detective", "text":"Stay sharp, partner. We aren't just in a forest. We’ve been pulled into the Alamat ng Pinya. The Legend of Pina."},
	{"speaker":"detective", "text":"And if Grandma was right, the story is actively dying around us."},
	{"speaker":"sidekick", "text":"It feels empty. Like life has been sucked out of it."},
	{"speaker":"detective", "text":"Because the text is vanishing. To restore the story, we can't just read the pages; we have to solve the mystery of why Pina disappeared."}
]

const FOREST_PLAYERS_WALK := [
	{"speaker":"sidekick", "text":"So, what’s the plan? We just walk around until we find her?"},
	{"speaker":"detective", "text":"No. We look for the evidence. The story is fragmented."},
	{"speaker":"detective", "text":"To understand the truth, we need to find five specific things scattered across these five zones."},
	{"speaker":"sidekick", "text":"Five things? Like clues?"},
	{"speaker":"detective", "text":"Artifacts. A Tiara. A Ladle. A Scroll. A Pineapple. And... an Eye."},
	{"speaker":"sidekick", "text":"An eye? That’s creepy. And a pineapple? What does fruit have to do with a missing girl?"},
	{"speaker":"detective", "text":"That’s the question, isn’t it? The old legend mentions a mother’s frustration. A curse."},
	{"speaker":"sidekick", "text":"Grandma mentioned that. Something about 'a thousand eyes'?"},
	{"speaker":"detective", "text":"Exactly. 'I wish you would grow a thousand eyes so you could find what you’re looking for.'"},
	{"speaker":"detective", "text":"We need to find out if that was just a figure of speech... or if it’s the key to where Pina went."}
]

const PINAS_HOUSE_ENTER := [
	{"speaker":"detective", "text":"This must be Pina's house."},
	{"speaker":"sidekick",  "text":"The kitchen looks messy... the cooking tools are scattered everywhere."},
	{"speaker":"detective", "text":"Maybe we should look for them. They might give us a clue."}
]

const PINAS_HOUSE_FIRST_ASWANG_WARNING := [
	{"speaker":"detective", "text":"The Aswang grows restless... We need to keep moving."}
]

const PINAS_HOUSE_NOTE_CLICKED := [
	{"speaker":"sidekick",  "text":"There's an equation written here."},
	{"speaker":"detective", "text":"Hmm... looks like a puzzle."},
	{"speaker":"sidekick",  "text":"How are we supposed to solve this?"},
	{"speaker":"detective", "text":"Check the Investigation Ledger. It might explain how the puzzle works."}
]

const PINAS_HOUSE_TOOLS_DONE := [
	{"speaker":"sidekick",  "text":"Now that the tools are cleared, I see something here."},
	{"speaker":"detective", "text":"It looks like a note."}
]

const PINAS_HOUSE_RIDDLE_REVEAL := [
	{"speaker":"detective", "text":"Good. The equation is solved."},
	{"speaker":"sidekick",  "text":"A riddle appeared... it must be pointing us somewhere in the kitchen."}
]

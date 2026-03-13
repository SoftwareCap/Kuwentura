extends Node
class_name DialogueLibrary

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

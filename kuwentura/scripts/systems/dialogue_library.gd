extends Node
class_name DialogueLibrary

const PINAS_HOUSE_ENTER := [
	{"speaker":"detective", "text":"This mess… doesn’t look accidental."},
	{"speaker":"detective", "text":"Someone was cooking here…"},
	{"speaker":"sidekick",  "text":"Yeah… but why leave everything like this?"},
	{"speaker":"sidekick",  "text":"Maybe they left something behind?"}
]

const PINAS_HOUSE_FIRST_ASWANG_WARNING := [
	{"speaker":"detective", "text":"Aswang! Let’s hurry up before it gets to us."}
]

const PINAS_HOUSE_NOTE_CLICKED := [
	{"speaker":"detective", "text":"I don’t think this is just random numbers…"},
	{"speaker":"sidekick",  "text":"Maybe the ledger can help us figure it out."}
]

const PINAS_HOUSE_NUMBERS_ONLY := [
	{"speaker":"detective", "text":"Numbers only... Aswang will attack again if we mess up."}
]

const PINAS_HOUSE_WRONG_ANSWER := [
	{"speaker":"detective", "text":"Wrong answer... Let's try again."}
]

const PINAS_HOUSE_AFTER_PUZZLE1 := [
	{"speaker":"detective", "text":"Wait… something in this house isn’t right…"},
	{"speaker":"sidekick",  "text":"Some things are missing!"},
]

extends Node
class_name DialogueLibrary

const PINAS_HOUSE_ENTER := [
	{"speaker":"detective", "text":"This mess… doesn’t look accidental."},
	{"speaker":"detective", "text":"Someone was cooking here…"},
	{"speaker":"sidekick",  "text":"Yeah… but why leave everything like this?"},
	{"speaker":"sidekick",  "text":"Maybe they left something behind?"}
]

const PINAS_HOUSE_NOTE_CLICKED := [
	{"speaker":"detective", "text":"I don’t think this is just random numbers…"},
	{"speaker":"sidekick",  "text":"Maybe the ledger can help us figure it out."}
]

const PINAS_HOUSE_NUMBERS_ONLY := [
	{"speaker":"detective", "text":"We’re looking for numbers only."},
	{"speaker":"detective", "text":"Let’s solve it step by step."}
]

const PINAS_HOUSE_WRONG_ANSWER := [
	{"speaker":"detective", "text":"Hmm… that doesn’t seem right."},
	{"speaker":"detective", "text":"Maybe we just made a small mistake."}
]

const PINAS_HOUSE_AFTER_PUZZLE1 := [
	{"speaker":"detective", "text":"Wait… something in this house isn’t right…"},
	{"speaker":"sidekick",  "text":"Some things are missing!"},
]

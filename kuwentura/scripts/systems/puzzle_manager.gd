extends Node

#==============================================================================
# PUZZLE MANAGER - Zone Challenge Data & Deterministic Selection
#==============================================================================
# Each zone has asymmetric gameplay requiring communication between
# Detective (Host) and Sidekick to solve challenges.
#==============================================================================

#------------------------------------------------------------------------------
# Zone Challenge Data - Complete puzzle configurations
#------------------------------------------------------------------------------
const PUZZLE_DATA = {
	"pinas_house": {
	"type": "algebra",
	"name": "Pina's House",
	"theme": "The Ladle",
	"narrative": "Clear the kitchen, uncover the Hidden Number Note, and solve for x to reveal the riddle that leads to the clue.",

	"host_view": {
		"title": "Hidden Number Note",
		"description": "You see a note with a single algebra equation and a hidden riddle waiting to be revealed.",
		"sees": ["One equation with x", "A hidden riddle after solving"],
		"task": "Solve the equation and reveal the riddle"
	},

	"sidekick_view": {
		"title": "Hidden Number Note",
		"description": "You see the same note and must solve for the missing value of x.",
		"sees": ["One equation with x", "One answer input"],
		"task": "Solve for x and reveal the next clue"
	},

	"ledger": {
	"title": "Finding the Missing Number",
	"instruction": "Undo what was done to x.\nMove the number first.\nThen divide if needed.",
	"example": "Example: 2x - 8 = 2\nStep 1: Add 8 to both sides.\nNow it becomes 2x = 10.\nStep 2: Divide both sides by 2.\nNow it becomes x = 5."
	},

	"variations": [
		{
			"id": 1,
			"difficulty": "Easy",
			"title": "Hidden Number Note",
			"equation": "x + 4 = 9",
			"solution": 5,
			"answer_format": "x=5",
			"riddle": "Where pots and pans quietly stay, a hidden clue now waits your way."
		},
		{
			"id": 2,
			"difficulty": "Easy",
			"title": "Hidden Number Note",
			"equation": "x - 3 = 6",
			"solution": 9,
			"answer_format": "x=9",
			"riddle": "Look where cooking tools are kept, the next secret there is left."
		},
		{
			"id": 3,
			"difficulty": "Medium",
			"title": "Hidden Number Note",
			"equation": "2x = 10",
			"solution": 5,
			"answer_format": "x=5",
			"riddle": "Open the place where kitchen things rest, inside it hides the village’s test."
		},
		{
			"id": 4,
			"difficulty": "Medium",
			"title": "Hidden Number Note",
			"equation": "2x - 8 = 2",
			"solution": 5,
			"answer_format": "x=5",
			"riddle": "Not on the floor and not by the door, search where kitchen tools sleep once more."
		},
		{
			"id": 5,
			"difficulty": "Hard",
			"title": "Hidden Number Note",
			"equation": "3x + 2 = 14",
			"solution": 4,
			"answer_format": "x=4",
			"riddle": "A quiet cupboard holds the key, open it to learn Pina’s mystery."
		}
	],

	"reward": {
		"clue": "Ladle",
		"note": "We use our eyes to find things, but Pina never used hers…"
	},

	"consequence": {
		"enemy": "Aswang",
		"behavior": "Watches from outside, thumping on window",
		"escalation": "Thumping grows stronger with delays and mistakes",
		"failure": "Aswang shatters window and breaks in"
	}
	},
	
	"backyard_path": {
		"type": "conversion",
		"name": "Backyard Path",
		"theme": "The Stature of the Lost",
		"narrative": "Deduce that a 'new plant' in the garden is actually Pina using spatial math.",
		
		"host_view": {
			"title": "Spirit Vision",
			"description": "You see a shimmering Spirit of Pina standing in the garden.",
			"sees": ["Spirit Height in centimeters", "Ghostly apparition of Pina"],
			"task": "Communicate the spirit's height to your partner"
		},
		
		"sidekick_view": {
			"title": "Garden Investigation",
			"description": "You see a strange new plant with unusual growth patterns.",
			"sees": ["Plant height in Dali (finger-widths)", "Physical plant in soil"],
			"task": "Convert plant height to cm and compare with spirit height"
		},
		
		"ledger": {
			"title": "Traditional Measurements",
			"formula": "1 Dali = 2 cm",
			"instruction": "To convert Dali to centimeters, multiply by 2.",
			"example": "60 Dali × 2 = 120 cm"
		},
		
		"variations": [
			{
				"id": 1,
				"spirit_height_cm": 120,
				"plant_height_dali": 60,
				"solution": 120,
				"confirmation": "120 cm Spirit = 120 cm Plant"
			},
			{
				"id": 2,
				"spirit_height_cm": 90,
				"plant_height_dali": 45,
				"solution": 90,
				"confirmation": "90 cm Spirit = 90 cm Plant"
			}
		],
		
		"reward": {
			"clue": "Pineapple_Sapling",
			"revelation": "Pina didn't run away; she became the garden."
		},
		
		"consequence": {
			"enemy": "Tikbalang",
			"behavior": "Rests in mango tree while fog spreads",
			"escalation": "Fog thickens the longer players take",
			"failure": "Fog becomes heavy cloud covering entire backyard"
		}
	},
	
	"old_well": {
		"type": "coordinates",
		"name": "Old Well",
		"theme": "The Eye Message",
		"narrative": "Decipher the message etched on the well using coordinate geometry.",
		
		"host_view": {
			"title": "Coordinate Plane",
			"description": "You see a graph on the floor forming a coordinate plane.",
			"sees": ["Grid with X and Y axes", "Plotting area"],
			"task": "Plot the coordinates your partner calls out to reveal the shape"
		},
		
		"sidekick_view": {
			"title": "Etched Bricks",
			"description": "You see Roman numerals etched on every brick of the well.",
			"sees": ["Roman numeral coordinates", "Well brick markings"],
			"task": "Read the Roman numerals and convert them for your partner"
		},
		
		"ledger": {
			"title": "Coordinate Geometry",
			"instruction": "Coordinates (X, Y) represent position on a plane. X = horizontal, Y = vertical.",
			"roman_guide": {
				"I": 1, "II": 2, "III": 3, "IV": 4, "V": 5,
				"VI": 6, "VII": 7, "VIII": 8
			},
			"example": "(II, IV) = (2, 4)"
		},
		
		"variations": [
			{
				"id": 1,
				"roman_numerals": ["(II, IV)", "(III, V)", "(V, VI)", "(VII, V)", "(VIII, IV)", "(VII, III)", "(V, II)", "(III, III)", "(II, IV)"],
				"coordinates": [Vector2(2, 4), Vector2(3, 5), Vector2(5, 6), Vector2(7, 5), Vector2(8, 4), Vector2(7, 3), Vector2(5, 2), Vector2(3, 3), Vector2(2, 4)],
				"shape": "Eye",
				"solution": [Vector2(2, 4), Vector2(3, 5), Vector2(5, 6), Vector2(7, 5), Vector2(8, 4), Vector2(7, 3), Vector2(5, 2), Vector2(3, 3), Vector2(2, 4)]
			},
			{
				"id": 2,
				"roman_numerals": ["(III, III)", "(IV, IV)", "(V, V)", "(VI, IV)", "(VII, III)", "(VI, II)", "(V, I)", "(IV, II)", "(III, III)"],
				"coordinates": [Vector2(3, 3), Vector2(4, 4), Vector2(5, 5), Vector2(6, 4), Vector2(7, 3), Vector2(6, 2), Vector2(5, 1), Vector2(4, 2), Vector2(3, 3)],
				"shape": "Eye",
				"solution": [Vector2(3, 3), Vector2(4, 4), Vector2(5, 5), Vector2(6, 4), Vector2(7, 3), Vector2(6, 2), Vector2(5, 1), Vector2(4, 2), Vector2(3, 3)]
			}
		],
		
		"reward": {
			"clue": "Eye_Symbol",
			"revelation": "She had eyes but chose not to see."
		},
		
		"consequence": {
			"enemy": "Siyokoy",
			"behavior": "Splashes screen occasionally",
			"escalation": "Splashes blur vision, forcing rapid communication",
			"failure": "Big wave erases the entire plot"
		}
	},
	
	"storage_hut": {
		"type": "volume",
		"name": "Storage Hut",
		"theme": "The Wish Scroll",
		"narrative": "Calculate volumetric measurements to find which container holds the Mother's Wish Scroll.",
		
		"host_view": {
			"title": "Spirit Water Lines",
			"description": "You see containers with glowing spirit water indicating fill levels.",
			"sees": ["Spirit water level (target volume)", "Symbolic dimension labels"],
			"task": "Identify which container's calculated volume matches the spirit water line"
		},
		
		"sidekick_view": {
			"title": "Container Dimensions",
			"description": "You see the physical dimensions of containers in the hut.",
			"sees": ["Length, width, height measurements", "Radius measurements for cylinders"],
			"task": "Calculate volumes and find which matches your partner's spirit water line"
		},
		
		"ledger": {
			"title": "Volume Formulas",
			"formulas": {
				"rectangular": "V = L × W × H",
				"cylinder": "V = π × r² × H"
			},
			"pi": 3.14,
			"instruction": "Calculate each container's volume. The correct one matches the spirit water level."
		},
		
		"variations": [
			{
				"id": 1,
				"target_volume": 240,
				"containers": [
					{"id": 1, "name": "Rectangular Box A", "type": "rectangular", "l": 6, "w": 5, "h": 8, "volume": 240, "is_correct": true},
					{"id": 2, "name": "Cylinder B", "type": "cylinder", "r": 3, "h": 9, "volume": 254.34, "is_correct": false},
					{"id": 3, "name": "Rectangular Box C", "type": "rectangular", "l": 7, "w": 4, "h": 8, "volume": 224, "is_correct": false},
					{"id": 4, "name": "Cylinder D", "type": "cylinder", "r": 2.5, "h": 10, "volume": 196.25, "is_correct": false},
					{"id": 5, "name": "Cylinder E", "type": "cylinder", "r": 4, "h": 6.5, "volume": 326.56, "is_correct": false}
				],
				"solution": 240,
				"correct_container": 1
			},
			{
				"id": 2,
				"target_volume": 314,
				"containers": [
					{"id": 1, "name": "Rectangular Box A", "type": "rectangular", "l": 10, "w": 6, "h": 5.2, "volume": 312, "is_correct": false},
					{"id": 2, "name": "Cylinder B", "type": "cylinder", "r": 5, "h": 4, "volume": 314, "is_correct": true},
					{"id": 3, "name": "Rectangular Box C", "type": "rectangular", "l": 8, "w": 5, "h": 7.5, "volume": 300, "is_correct": false},
					{"id": 4, "name": "Cylinder D", "type": "cylinder", "r": 3.5, "h": 8, "volume": 307.72, "is_correct": false},
					{"id": 5, "name": "Rectangular Box E", "type": "rectangular", "l": 9, "w": 4, "h": 8.1, "volume": 291.6, "is_correct": false}
				],
				"solution": 314,
				"correct_container": 2
			}
		],
		
		"reward": {
			"clue": "Wish_Scroll",
			"note": "I wished you had many eyes, so you could find what you seek without always relying on others."
		},
		
		"consequence": {
			"enemy": "Sigbin",
			"behavior": "Circles the hut, darkening the area",
			"escalation": "Shadows deepen making edges harder to distinguish",
			"failure": "Sigbin plunges hut into darkness, glowing red eyes appear"
		}
	},
	
	"abandoned_house": {
		"type": "arithmetic",
		"name": "Abandoned House",
		"theme": "The Cabinet Lock",
		"narrative": "Use arithmetic sequence to unlock the cabinet hiding Pina's Tiara.",
		
		"host_view": {
			"title": "Lock Combination",
			"description": "You see a number combination on the cabinet lock with one number missing.",
			"sees": ["Number sequence with blank", "Lock mechanism"],
			"task": "Read the sequence and find the pattern with your partner"
		},
		
		"sidekick_view": {
			"title": "Pattern Solver",
			"description": "You can input numbers on the lock to test combinations.",
			"sees": ["Number input pad", "Sequence display"],
			"task": "Calculate the missing number and input it to unlock"
		},
		
		"ledger": {
			"title": "Arithmetic Sequences",
			"formula": "aₙ = a₁ + (n-1)d",
			"instruction": "Find the common difference (d) between terms, then calculate the missing value.",
			"example": "In 2, 5, 8, ?, 14... the difference is 3, so missing number is 11"
		},
		
		"variations": [
			{
				"id": 1,
				"sequence": [3, 6, 9, 12, null, 18],
				"display": "3 – 6 – 9 – 12 – □ – 18",
				"missing_index": 4,
				"common_difference": 3,
				"solution": 15,
				"completed": [3, 6, 9, 12, 15, 18]
			},
			{
				"id": 2,
				"sequence": [12, 41, 70, null, 128, 157],
				"display": "12 – 41 – 70 – □ – 128 – 157",
				"missing_index": 3,
				"common_difference": 29,
				"solution": 99,
				"completed": [12, 41, 70, 99, 128, 157]
			}
		],
		
		"reward": {
			"clue": "Tiara",
			"symbolism": "Treated like a princess, she never learned to look."
		},
		
		"consequence": {
			"enemy": "Tikbalang",
			"behavior": "Fog spreads as players hesitate",
			"escalation": "Fog thickens with time",
			"failure": "Heavy fog cloud covers the entire area"
		}
	}
}

#------------------------------------------------------------------------------
# Public API
#------------------------------------------------------------------------------

func get_puzzle_for_zone(zone_id: String) -> Dictionary:
	"""Get complete puzzle data for a zone, selected deterministically from seed."""
	if not PUZZLE_DATA.has(zone_id):
		push_warning("[PuzzleManager] Unknown zone: " + zone_id)
		return {}

	var zone_data: Dictionary = PUZZLE_DATA[zone_id]
	var variations: Array = zone_data.get("variations", [])

	if variations.is_empty():
		push_warning("[PuzzleManager] No variations found for zone: " + zone_id)
		return {}

	# Get seed from GameState (derived from session seed)
	var puzzle_seed: int = GameState.get_puzzle_seed(zone_id)

	# Select variation based on seed
	var rng := RandomNumberGenerator.new()
	rng.seed = puzzle_seed
	var variation_index: int = rng.randi_range(0, variations.size() - 1)
	var selected: Dictionary = variations[variation_index]

	var equation_text: String = str(selected.get("equation", "x = ?"))
	var solution_x: int = int(selected.get("solution", 0))
	var difficulty: String = str(selected.get("difficulty", "Easy"))
	var answer_format: String = str(selected.get("answer_format", "x=0"))
	var riddle_text: String = str(selected.get("riddle", ""))

	return {
		"zone_id": zone_id,
		"type": zone_data.get("type", ""),
		"name": zone_data.get("name", ""),
		"theme": zone_data.get("theme", ""),
		"narrative": zone_data.get("narrative", ""),
		"host_view": zone_data.get("host_view", {}),
		"sidekick_view": zone_data.get("sidekick_view", {}),
		"ledger": zone_data.get("ledger", {}),
		"reward": zone_data.get("reward", {}),
		"consequence": zone_data.get("consequence", {}),
		"variation_id": selected.get("id", 1),
		"difficulty": difficulty,
		"title": selected.get("title", "Hidden Number Note"),
		"equation": equation_text,
		"solution": solution_x,
		"answer_format": answer_format,
		"riddle": riddle_text
	}


func _generate_conversion_puzzle(zone_id: String, _seed: int) -> Dictionary:
	var rng = RandomNumberGenerator.new()
	rng.seed = _seed

	# Pina's spirit height in cm
	var spirit_height = rng.randi_range(100, 150)
	var dali_value = spirit_height / 2.0  # 1 Dali = 2 cm

	return {
		"zone_id": zone_id,
		"type": "conversion",
		"conversion_rate": 2,  # 1 Dali = 2 cm
		"spirit_height_cm": spirit_height,
		"plant_height_dali": dali_value,
		"solution": spirit_height,
		"host_view": {"sees_spirit_height": true, "spirit_height": spirit_height},
		"sidekick_view":
		{"sees_plant_dali": true, "plant_dali": dali_value, "formula": "1 Dali = 2 cm"}
	}


func _generate_coordinate_puzzle(_zone_id: String, _seed: int) -> Dictionary:
	# Eye shape coordinates (fixed pattern but scaled)
	var base_coords = [
		Vector2(0, 0),
		Vector2(1, 1),
		Vector2(2, 2),
		Vector2(3, 1),
		Vector2(4, 0),
		Vector2(3, -1),
		Vector2(2, -2),
		Vector2(1, -1)
	]

	var rng = RandomNumberGenerator.new()
	rng.seed = seed
	var offset = rng.randi_range(1, 5)
	var scale = rng.randi_range(1, 3)

	var coords = []
	for point in base_coords:
		coords.append(Vector2((point.x + offset) * scale, (point.y + offset) * scale))

	return {
		"zone_id": _zone_id,
		"type": "coordinates",
		"coordinates": coords,
		"shape": "eye",
		"solution": coords,
		"host_view": {"sees_grid": true, "plot_points": true},
		"sidekick_view": {"sees_roman_numerals": true, "coordinates_raw": coords}
	}


func _generate_volume_puzzle(_zone_id: String, _seed: int) -> Dictionary:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed

	# Generate container dimensions
	var containers = []
	var correct_index = rng.randi_range(0, 2)

	for i in range(3):
		var l = rng.randi_range(3, 10)
		var w = rng.randi_range(3, 10)
		var h = rng.randi_range(5, 15)
		var volume = l * w * h

		# Add noise to wrong answers
		if i != correct_index:
			volume += rng.randi_range(-5, 5)

		containers.append(
			{
				"id": i,
				"length": l,
				"width": w,
				"height": h,
				"volume": volume,
				"is_correct": i == correct_index
			}
		)

	return {
		"zone_id": _zone_id,
		"type": "volume",
		"containers": containers,
		"correct_container": correct_index,
		"solution": containers[correct_index].volume,
		"formulas": {"rectangular": "V = L × W × H", "cylinder": "V = π × r² × H"},
		"host_view":
		{"sees_spirit_water_lines": true, "target_volume": containers[correct_index].volume},
		"sidekick_view": {"sees_dimensions": true, "containers_data": containers}
	}


func _generate_arithmetic_puzzle(_zone_id: String, _seed: int) -> Dictionary:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed

	# Generate arithmetic sequence
	var start = rng.randi_range(1, 10)
	var diff = rng.randi_range(2, 5)
	var missing_index = rng.randi_range(1, 3)  # Which position is missing

	var sequence = []
	for i in range(4):
		var value = start + (i * diff)
		if i == missing_index:
			sequence.append(null)  # Missing value
		else:
			sequence.append(value)

	var solution = start + (missing_index * diff)

	return {
		"zone_id": _zone_id,
		"type": "arithmetic",
		"sequence": sequence,
		"common_difference": diff,
		"missing_index": missing_index,
		"solution": solution,
		"formula": "aₙ = a₁ + (n-1)d",
		"host_view": {"sees_lock_combination": true, "sequence_display": sequence},
		"sidekick_view": {"can_input": true, "sequence_input": sequence}
	}


func validate_answer(_zone_id: String, player_answer: Variant, puzzle_data: Dictionary) -> bool:
	"""Validate player's answer against puzzle solution."""
	if not puzzle_data.has("solution"):
		return false
	
	var solution = puzzle_data.solution
	var puzzle_type = puzzle_data.get("type", "")
	
	match puzzle_type:
		"algebra":
			if player_answer is Dictionary:
				return (
					player_answer.get("x") == solution.x and
					player_answer.get("y") == solution.y and
					player_answer.get("z") == solution.z
				)
		"conversion", "arithmetic", "volume":
			return player_answer == solution
		"coordinates":
			if player_answer is Array and solution is Array:
				if player_answer.size() != solution.size():
					return false
				for i in range(solution.size()):
					if player_answer[i] != solution[i]:
						return false
				return true
			return player_answer == solution
		_:
			return false
	
	return false


func get_zone_info(zone_id: String) -> Dictionary:
	"""Get static zone info without generating a variation."""
	if not PUZZLE_DATA.has(zone_id):
		return {}
	var data = PUZZLE_DATA[zone_id]
	return {
		"name": data.name,
		"type": data.type,
		"theme": data.theme,
		"narrative": data.narrative,
		"variation_count": data.variations.size(),
		"reward": data.reward,
		"consequence": data.consequence
	}


func get_all_zones() -> Array:
	"""Return list of all zone IDs."""
	return PUZZLE_DATA.keys()


func get_ledger_info(zone_id: String) -> Dictionary:
	"""Get ledger/hint information for a zone."""
	if not PUZZLE_DATA.has(zone_id):
		return {}
	return PUZZLE_DATA[zone_id].ledger


func get_consequence_info(zone_id: String) -> Dictionary:
	"""Get consequence/failure information for a zone."""
	if not PUZZLE_DATA.has(zone_id):
		return {}
	return PUZZLE_DATA[zone_id].consequence

#------------------------------------------------------------------------------
# View Builders
#------------------------------------------------------------------------------

func _build_host_view(zone_data: Dictionary, variation: Dictionary) -> Dictionary:
	"""Construct the complete host view for a puzzle variation."""
	var view = zone_data.host_view.duplicate()
	view["type"] = zone_data.type
	
	match zone_data.type:
		"algebra":
			view["equations"] = variation.equations
			view["symbol_map"] = variation.symbol_map
			
		"conversion":
			view["spirit_height_cm"] = variation.spirit_height_cm
			
		"coordinates":
			view["coordinates"] = variation.coordinates
			view["shape"] = variation.shape
			
		"volume":
			view["target_volume"] = variation.target_volume
			view["containers"] = _filter_containers_for_host(variation.containers)
			
		"arithmetic":
			view["sequence_display"] = variation.display
			view["sequence_array"] = variation.sequence
	
	return view


func _build_sidekick_view(zone_data: Dictionary, variation: Dictionary) -> Dictionary:
	"""Construct the complete sidekick view for a puzzle variation."""
	var view = zone_data.sidekick_view.duplicate()
	view["type"] = zone_data.type
	
	match zone_data.type:
		"algebra":
			# Replace variables with boxes in equations
			var hidden = []
			for eq in variation.equations:
				hidden.append(eq.replace("x", "□").replace("y", "□").replace("z", "□"))
			view["hidden_equations"] = hidden
			view["known_value"] = "z = %d" % variation.solution.z
			
		"conversion":
			view["plant_height_dali"] = variation.plant_height_dali
			view["conversion_rate"] = 2
			
		"coordinates":
			view["roman_numerals"] = variation.roman_numerals
			view["roman_guide"] = zone_data.ledger.roman_guide
			
		"volume":
			view["containers"] = variation.containers
			view["formulas"] = zone_data.ledger.formulas
			view["pi"] = zone_data.ledger.pi
			
		"arithmetic":
			view["sequence_display"] = variation.display
			view["common_difference"] = variation.common_difference
			view["formula"] = zone_data.ledger.formula
	
	return view


func _filter_containers_for_host(containers: Array) -> Array:
	"""Host sees containers with symbolic labels, not full dimensions."""
	var filtered = []
	for c in containers:
		filtered.append({
			"id": c.id,
			"name": c.name,
			"type": c.type,
			"symbolic_label": "Container %d" % c.id,
			"is_correct": c.is_correct
		})
	return filtered

#------------------------------------------------------------------------------
# Debug Helpers
#------------------------------------------------------------------------------

func debug_print_zone(zone_id: String) -> void:
	"""Print complete zone data for debugging."""
	var puzzle = get_puzzle_for_zone(zone_id)
	if puzzle.is_empty():
		print("[PuzzleManager] Zone not found: " + zone_id)
		return
	
	print("\n" + "=".repeat(50))
	print("ZONE: %s (%s)" % [puzzle.zone_name, zone_id])
	print("Theme: %s" % puzzle.theme)
	print("Type: %s | Variation: %d" % [puzzle.type, puzzle.variation_id])
	print("=".repeat(50))
	
	print("\n📖 NARRATIVE:")
	print("  %s" % puzzle.narrative)
	
	print("\n🎭 HOST VIEW:")
	print(JSON.stringify(puzzle.host_view, "\t"))
	
	print("\n🎭 SIDEKICK VIEW:")
	print(JSON.stringify(puzzle.sidekick_view, "\t"))
	
	print("\n📚 LEDGER:")
	print(JSON.stringify(puzzle.ledger, "\t"))
	
	print("\n✅ SOLUTION: %s" % str(puzzle.solution))
	
	print("\n🎁 REWARD:")
	print("  Clue: %s" % puzzle.reward.clue)
	
	print("\n⚠️  CONSEQUENCE:")
	print("  Enemy: %s" % puzzle.consequence.enemy)
	print("  Failure: %s" % puzzle.consequence.failure)
	
	print("=".repeat(50) + "\n")


func debug_test_all_zones() -> void:
	"""Test and print all zones."""
	for zone_id in get_all_zones():
		debug_print_zone(zone_id)

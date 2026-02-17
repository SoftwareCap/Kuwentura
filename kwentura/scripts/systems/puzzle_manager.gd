extends Node

# Puzzle templates - questions stay same, numbers change
const PUZZLE_TEMPLATES = {
	"pinas_house":
	{
		"type": "algebra",
		"description": "Find the ladle using x + y = 10, y - z = 2, z = 3",
		"generate": "_generate_algebra_puzzle"
	},
	"backyard_path":
	{
		"type": "conversion",
		"description": "Convert Dali to cm: 1 Dali = 2 cm",
		"generate": "_generate_conversion_puzzle"
	},
	"old_well":
	{
		"type": "coordinates",
		"description": "Plot coordinates to form an eye shape",
		"generate": "_generate_coordinate_puzzle"
	},
	"storage_hut":
	{
		"type": "volume",
		"description": "Calculate volume to find the Wish Scroll",
		"generate": "_generate_volume_puzzle"
	},
	"abandoned_house":
	{
		"type": "arithmetic",
		"description": "Complete the arithmetic sequence",
		"generate": "_generate_arithmetic_puzzle"
	}
}


func get_puzzle_for_zone(_zone_id: String, _seed: int) -> Dictionary:
	if not PUZZLE_TEMPLATES.has(_zone_id):
		return {}

	var template = PUZZLE_TEMPLATES[_zone_id]
	var generator = Callable(self, template.generate)
	return generator.call(_zone_id, seed)


func _generate_algebra_puzzle(zone_id: String, _seed: int) -> Dictionary:
	# Use seed to generate deterministic but varying numbers
	var rng = RandomNumberGenerator.new()
	rng.seed = seed

	# Generate values where x + y = sum, y - z = diff, z = base
	var base = rng.randi_range(2, 5)  # z value
	var diff = rng.randi_range(1, 4)  # y - z
	var y = base + diff
	var sum = rng.randi_range(y + 2, y + 8)  # x + y
	var x = sum - y

	return {
		"zone_id": zone_id,
		"type": "algebra",
		"variables": {"x": x, "y": y, "z": base},
		"equations": ["x + y = %d" % sum, "y - z = %d" % diff, "z = %d" % base],
		"solution": {"x": x, "y": y, "z": base},
		"answer_format": "Ladle is x = %d" % x,
		"host_view": {"symbols": "x=Ladle, y=Pan, z=Pot", "values_visible": false},
		"sidekick_view":
		{
			"equations": ["□ + □ = %d" % sum, "□ - □ = %d" % diff, "□ = %d" % base],
			"messy_kitchen": true
		}
	}


func _generate_conversion_puzzle(zone_id: String, _seed: int) -> Dictionary:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed

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


func validate_answer(_zone_id: String, player_answer, puzzle_data: Dictionary) -> bool:
	if not puzzle_data.has("solution"):
		return false

	var solution = puzzle_data.solution

	match puzzle_data.type:
		"algebra":
			if player_answer is Dictionary:
				return (
					player_answer.get("x") == solution.x
					and player_answer.get("y") == solution.y
					and player_answer.get("z") == solution.z
				)
		"conversion", "volume", "arithmetic":
			return player_answer == solution
		"coordinates":
			return player_answer == solution
		_:
			return false

	return false

class_name PackDefinition
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var machine_id: String = ""
@export var container_ids: Array[String] = []
@export var prize_ids: Array[String] = []
@export var cover_art_path: String = ""


func uses_containers() -> bool:
	return not container_ids.is_empty()


func get_containers() -> Array[ContainerDefinition]:
	var result: Array[ContainerDefinition] = []
	for cid in container_ids:
		var c := PrizeCatalog.get_container(cid)
		if c:
			result.append(c)
	return result


func pick_random_container() -> ContainerDefinition:
	var containers := get_containers()
	if containers.is_empty():
		return null
	if _all_spawn_weights_equal(containers):
		return containers[randi() % containers.size()]
	var total_weight := 0.0
	for container in containers:
		total_weight += maxf(container.spawn_weight, 0.001)
	var roll := randf() * total_weight
	for container in containers:
		roll -= maxf(container.spawn_weight, 0.001)
		if roll <= 0.0:
			return container
	return containers[containers.size() - 1]


func get_prizes() -> Array[PrizeDefinition]:
	var result: Array[PrizeDefinition] = []
	for pid in prize_ids:
		var prize := PrizeCatalog.get_prize(pid)
		if prize:
			result.append(prize)
	return result


func pick_random_prize() -> PrizeDefinition:
	var prizes := get_prizes()
	if prizes.is_empty():
		return null
	if _all_prize_weights_equal(prizes):
		return prizes[randi() % prizes.size()]
	var total_weight := 0.0
	for prize in prizes:
		total_weight += maxf(prize.weight, 0.001)
	var roll := randf() * total_weight
	for prize in prizes:
		roll -= maxf(prize.weight, 0.001)
		if roll <= 0.0:
			return prize
	return prizes[prizes.size() - 1]


func get_containing_prizes() -> Array[PrizeDefinition]:
	var seen: Dictionary = {}
	var result: Array[PrizeDefinition] = []
	for container in get_containers():
		var prize := container.get_prize()
		if prize == null or seen.has(prize.id):
			continue
		seen[prize.id] = true
		result.append(prize)
	for prize in get_prizes():
		if prize == null or seen.has(prize.id):
			continue
		seen[prize.id] = true
		result.append(prize)
	return result


func get_machine() -> CraneMachineDefinition:
	return StarterContent.get_machine(machine_id)


func _all_spawn_weights_equal(containers: Array[ContainerDefinition]) -> bool:
	if containers.is_empty():
		return true
	var first := containers[0].spawn_weight
	for container in containers:
		if not is_equal_approx(container.spawn_weight, first):
			return false
	return true


func _all_prize_weights_equal(prizes: Array[PrizeDefinition]) -> bool:
	if prizes.is_empty():
		return true
	var first := prizes[0].weight
	for prize in prizes:
		if not is_equal_approx(prize.weight, first):
			return false
	return true

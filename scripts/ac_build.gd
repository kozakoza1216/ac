extends Resource
class_name ACBuild

## One assembled machine: a head, core, arms, legs, FCS, booster,
## generator and radiator, plus the derived totals used to judge whether
## the combination is viable at all (overweight / EN deficit / overheat)
## before it ever gets wired into the player controller's movement stats.

@export var build_name: String = ""

@export var head: HeadPart
@export var core: CorePart
@export var arms: ArmsPart
@export var legs: LegsPart
@export var fcs: FcsPart
@export var booster: BoosterPart
@export var generator: GeneratorPart
@export var radiator: RadiatorPart


func total_ap() -> int:
	var sum := 0
	if head:
		sum += head.ap
	if core:
		sum += core.ap
	if arms:
		sum += arms.ap
	if legs:
		sum += legs.ap
	return sum


## Weight the legs have to carry -- everything except the legs themselves.
func carried_weight() -> float:
	var sum := 0.0
	for part in [head, core, arms, fcs, booster, generator, radiator]:
		if part:
			sum += part.weight
	return sum


func load_ratio() -> float:
	if not legs or legs.load_capacity <= 0.0:
		return INF
	return carried_weight() / legs.load_capacity


func is_overweight() -> bool:
	return load_ratio() > 1.0


## Sum of every part's steady-state EN load (the booster's boost-time
## drain is excluded -- that only applies while actively boosting).
func total_en_consumption() -> float:
	var sum := 0.0
	for part in [head, core, arms, legs, fcs, booster, radiator]:
		if part:
			sum += part.en_load
	return sum


func en_balance() -> float:
	if not generator:
		return -total_en_consumption()
	return generator.en_output - total_en_consumption()


func has_en_deficit() -> bool:
	return en_balance() < 0.0


## (generator heat + booster boost heat) * 2 <= radiator cooling --
## the source material's own documented rule of thumb.
func total_heat() -> float:
	var sum := 0.0
	if generator:
		sum += generator.heat
	if booster:
		sum += booster.boost_heat
	return sum


func is_overheating() -> bool:
	var cooling := radiator.cooling_performance if radiator else 0.0
	return total_heat() * 2.0 > cooling


## Empty array means the build is viable; otherwise each entry names one
## problem (missing part, overweight, EN deficit, or overheating).
func validate() -> Array[String]:
	var problems: Array[String] = []
	for part_name in ["head", "core", "arms", "legs", "fcs", "booster", "generator", "radiator"]:
		if get(part_name) == null:
			problems.append("%s is not equipped" % part_name)
	if legs and is_overweight():
		problems.append("overweight: carrying %.0f / %.0f load capacity" % [carried_weight(), legs.load_capacity])
	if generator and has_en_deficit():
		problems.append("EN deficit: %.0f output vs %.0f consumption" % [generator.en_output, total_en_consumption()])
	if radiator and is_overheating():
		problems.append("overheating: %.0f heat vs %.0f cooling (needs heat*2 <= cooling)" % [total_heat(), radiator.cooling_performance])
	return problems

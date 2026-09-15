extends Node

## Loads a couple of sample ACBuild resources and reports their computed
## totals, both to the console and an on-screen Label -- a quick way to
## sanity-check the parts system without any gameplay wired up yet.

@export var builds: Array[ACBuild] = []

@onready var output_label: Label = get_node_or_null("%Output")


func _ready() -> void:
	var lines: Array[String] = []
	for build in builds:
		lines.append(_describe_build(build))
	var text := "\n\n".join(lines)
	print(text)
	if output_label:
		output_label.text = text


func _describe_build(build: ACBuild) -> String:
	var problems := build.validate()
	var status := "OK" if problems.is_empty() else "PROBLEMS:\n  - " + "\n  - ".join(problems)
	return "%s\n  AP: %d\n  Carried weight: %.0f / %.0f (load %.0f%%)\n  EN: %.0f output vs %.0f consumption (balance %+.0f)\n  Heat: %.0f x2 vs %.0f cooling\n  %s" % [
		build.build_name,
		build.total_ap(),
		build.carried_weight(),
		build.legs.load_capacity if build.legs else 0.0,
		build.load_ratio() * 100.0,
		build.generator.en_output if build.generator else 0.0,
		build.total_en_consumption(),
		build.en_balance(),
		build.total_heat(),
		build.radiator.cooling_performance if build.radiator else 0.0,
		status,
	]

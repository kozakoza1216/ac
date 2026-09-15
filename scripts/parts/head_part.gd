extends Resource
class_name HeadPart

## Head part (頭部パーツ). Governs sensors/radar; contributes AP, weight,
## EN load and defense to the assembled AC. Stats sourced from the
## Armored Core Last Raven parts reference; where the source lists a
## paired NX/LR value, the first (NX) figure is used for simplicity.

@export var part_name: String = ""
@export var maker: String = ""
@export var price: int = 0

@export var ap: int = 0
@export var weight: float = 0.0
@export var en_load: float = 0.0
@export var real_defense: float = 0.0
@export var energy_defense: float = 0.0
@export var stability: float = 0.0

@export var has_night_vision: bool = false
@export var has_bio_sensor: bool = false

class_name PhysicsLayers

## Layer bit masks — must match project.godot [layer_names] (layer N = 1 << (N - 1)).

const PRIZES := 1 << 0
const CLAW := 1 << 1
const CABINET := 1 << 3

const PRIZE_COLLIDE_WITH := PRIZES | CLAW | CABINET
const CLAW_COLLIDE_WITH := PRIZES | CABINET
const CABINET_COLLIDE_WITH := PRIZES | CLAW

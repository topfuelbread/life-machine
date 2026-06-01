# Crane Machine

See also: [[Roadmap]] · `scripts/data/crane_machine_definition.gd`

- 1 contains n [[Prize]]
- triggers view switch (1)from 2D to 3D, or (2) opens tiny window for 3D mini game
- can contain 1 or more packs
- scene_path → Godot scene (e.g. `res://main.tscn`)
- claw_profile_id → [[Claw Profile]]
- play_cost + coin_currency_id → `GameState.consume_play`
- gantry_min / gantry_max / chute_position / start_gantry → cabinet layout

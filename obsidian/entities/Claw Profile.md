# Claw Profile

See: `scripts/data/claw_profile_definition.gd` · [[Crane Machine]]

Each [[Crane Machine]] references one claw profile. Profiles control:

- Payout probability and weak/strong grip torque
- When the solenoid weakens during ascend (`weak_grip_delay`)
- Prong open/close speeds and grab timing
- Hoist drop/ascend speeds and max depth
- Whether an empty claw skips the prize chute

Built-in profiles (starter content):

| id | Feel |
| --- | --- |
| `standard_rigged` | Classic weak grip after ~0.3s |
| `loose_arcade` | Higher payout, slower weak grip |
| `snap_grip` | Fast close, very early weak grip (unused by default machines) |

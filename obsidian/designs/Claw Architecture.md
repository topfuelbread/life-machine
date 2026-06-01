# Claw architecture

Reference: [Unity claw blog](https://www.artstation.com/blogs/spacecentipede/44XqB/claw-crane-machine-game-learning-unity-with-ai-01)

## Hierarchy (matches Unity)

```
ClawAssembly (RigidBody3D, cable joint)
└── ClawCenter (ClawRig)
    ├── Claw_01_center → SegmentA → SegmentB (+ finger colliders)
    ├── Claw_02_center → …
    └── Claw_03_center → …
```

## ClawArmController (kinematic, not physics hinges)

| State | Segment A | Segment B |
| --- | --- | --- |
| Open | 0° | 60° |
| Close | 0° | 110° |

Rotation speed: 180°/s. Weak grip = partial close blend.

Scripts: `claw_rig.gd`, `claw_arm_controller.gd`, `crane_controller.gd`

# 📅 June’s PC Crane Game Plan (2026.05.31)

> Implementation phases: [[Roadmap]] · Crane rig: [[Claw Architecture]]

## 🎨 Game Development Stack & Tech Specs

- **Game Engine:** Godot 4.x
    
- **Item Template Size:** 2048×2048 px
    
- **3D Modeling:** Blender
    
- **Audio:** Audacity (Focus on **ASMR** audio vibes)
    
- **Prototyping:** Figma (For testing the "look" and UI flow)
    
- **Backend:** Used for collecting user stats to help with game balancing.
    
    > 🌟 _Note: Be transparent with data collection to earn player trust._
    

## 🏗️ Core Design Elements

The game contains:

- **Crane Machine:** Base game + DLC packs.
    
- **# of Plays:** Paid? Free by x time? Passive? (Consumes something to play).
    
- **Prizes:** Need to be highly **DESIREABLE** (수집욕구 자극 / Stimulates desire to collect).
    
    - Cloth pieces for customization (Figure, Player)
        
    - Interior pieces
        
    - Other kinds of collectibles (Quotes, backgrounds)
        
- **Dashboard / Display Board:** A space for the **USER** to put together and showcase items.
    
- **Collector Book:** For visualizing and tracking won prizes.
    
- **Achievements & Daily Quests**
    
- **Coins:** Specific currency per machine.
    

### 🎨 Art Style & Direction

- **Medium:** 2D? 3D? Pixel? (For the crane game itself).
    
- **Complexity:** Should be simple enough because a **large number of prizes** need to be created.
    
- **Content Model:** New item packs delivered via DLC? Or free updates?
    
- **Theme:** Unboxing aesthetic.
    

## 🕹️ Play System

_Impacts user engagement and overall interest._

```
+------------------------+
|       [⚙️ Crane]        | --> Play Style: Crane (for now)
|  (O) (O) (O) (O) (O)   | --> Prizes: Refill period, Weight/Difficulty, # of items, Box/Card/Capsule
|========================|
|     [🎫 Pay Sys]       | --> Pay System: Pay by ticket? Unlimited plays? Timed? Practice mode?
+------------------------+
           |
           v
   [Machine Setting] ------> Game Balance / Guaranteed Pull?
                             *Interaction with machine: Shake, Nudge*
```

## 🖼️ Feature Design: Display Area

> 💡 **Core Concept:** "Free-form sticker style." Everything is a prize here, including cabinets and the background itself.

### 📱 UI & Interaction States

1. **Navigation:** Tabs for `[Bag]` / `[Inventory]` / `[Storage]`
    
2. **While Dragging an Item ("EDIT Mode"):**
    
    - `Mouse Wheel` or `Q` / `S` ↑↓: Zoom in / out
        
    - **Confirm / Attach:** Places the item
        
    - **Move / Rotate** item
        
    - **Put away / Remove**
        
    - **Change Layer Order**
        
3. **While Hovering:**
    
    - **Lock:** Cannot move
        
    - **Click:** Enter "EDIT" mode
        
    - **Put Away** button
        
4. **Presets:** Save, Load, and Preview layouts.
    
5. **Social:** Screenshot / Share features.
    
    - _Idea:_ Special photo frames for sharing ✨
        

### 🎁 Prize Types

- Doll parts
    
- Collector parts & Room decoration:
    
    - Cabinet
        
    - Board
        
    - Wallpaper, Frame
        
    - Ceiling lights, Effects
        
    - Quotes
        
    - _Vibe:_ Cyworld-esque! Y2K aesthetics
        

## 📖 Feature Design: Collector's Book / Storage

### 📑 Item Properties (Metadata)

- **Number:** (ID; Primary Key)
    
- **# Obtained** / **# Owned**
    
- **Variety / Version**
    
- **Type:** Doll, Clothes, Decoration (Deco)
    
- **Rarity**
    

### ⚡ Actions & Systems

- **Sort options:** Sort by Last Acquired, Name, Rarity, # Obtained.
    
- **Recycle System:** Recycle unwanted items for tokens.
    

## 🚀 Additional Systems & Future Ideas

- **Genre Pivot?** What if this is a store-management simulator? (**IDLE** game with passive income, expanding machine counts).
    
- **Security:** No anti-cheat needed; monetize purely through DLCs.
    
- **Platform Support:** Steam Deck support & Steam Workshop integration?
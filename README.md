# Grid Tactics Prototype

Turn-based tactical combat prototype built in Godot using GDScript.

This project explores tactical combat centered around movement, facing, stamina, directional coverage, territorial control, battlefield pressure, terrain-aware navigation, formation-based engagements, readable AI behavior, and sequential battlefield presentation.

The goal is to create battles where:
- positioning matters before attacks happen
- terrain shapes battlefield flow
- defensive lines can hold or collapse
- movement itself creates tactical vulnerability
- chokepoints and navigation matter tactically
- AI behaves consistently within terrain constraints
- enemy actions remain readable and visually understandable

Rather than focusing on raw stat trading, the prototype emphasizes:
- formation integrity
- controlled advances
- retreat pressure
- lane denial
- territorial defense
- readable battlefield threat
- terrain-aware tactical positioning
- navigable battlefield control
- sequential combat readability

---

# Current Features

## Core Combat

- Turn-based grid combat
- 8-directional facing system
- Directional coverage/interception zones
- Stamina-based reaction attacks
- Delayed coverage reactions after movement confirmation
- Coverage reactions calculated from actual traversed movement paths
- Movement stamina costs
- Difficulty-scaled stamina recovery
- Modular support-action system
- Attack, heal, regeneration, wait, and facing confirmation flow
- Context-sensitive action confirmation menus
- Mouse and keyboard tactical controls
- Auto-end turn when all units on the active team are exhausted
- Multi-team turn support (`player`, `enemy`, `neutral`, etc.)
- Sequential enemy turn presentation
- Delayed enemy action pacing
- Attack timing synced with visible HP updates
- Enemy-turn input locking

## Movement and Pathing

- Cursor-traced movement paths
- Hovered path previews
- Path-based movement validation
- Multiple valid routes to the same destination
- Dangerous path tiles highlighted before movement confirmation
- Coverage reactions calculated from actual movement path traversal
- Deterministic pathfinding behavior for debugging and testing
- Terrain-aware AI pathfinding
- Traversable path-cost AI targeting
- River and wall-aware navigation
- AI path evaluation using actual reachable routes
- Traffic-aware movement handling
- Chokepoint-aware movement behavior
- Animated sequential AI movement
- Tile-by-tile enemy movement presentation
- Future-path directional facing
- AI facing based on continued navigable routes

## Unit Types

- Fighter
- Tank
- Duelist
- Lancer
- Archer
- Healer

## Tactical Systems

- Terrain interaction
- Blocked movement tiles
- Movement costs
- Ranged attack validation
- Healing charge system
- Regeneration support
- Modular support-action architecture
- Directional interception
- Formation pressure
- Chokepoint gameplay
- Fallback-line gameplay
- Coverage-based positional control
- Territorial AI leash systems
- Home-position defensive behavior
- Path-based interception detection
- Terrain-driven engagement flow
- Bridge and lane-control gameplay
- Stamina-driven battlefield pacing
- Direction-aware enemy presentation
- Sequential battlefield readability systems

## AI Systems

- Modular AI profile architecture
- Per-unit AI behavior assignment
- Mixed AI behaviors supported within the same faction
- Territory-aware defensive AI
- Data-driven AI profile system
- Terrain-aware enemy navigation
- Path-cost target evaluation
- Coverage-aware movement resolution
- Shared AI movement helper system
- Ranged positioning AI
- Support/healer AI
- Terrain-aware ranged movement evaluation
- Reachable-target attack positioning
- AI action-result reporting architecture
- Decoupled AI logic and presentation layer
- Future-path facing evaluation

### Current AI Profiles

#### Barbarian

- Aggressively pursues nearest reachable enemy
- Uses traversable path cost instead of raw grid distance
- Attacks whenever possible
- Ignores coverage danger
- Respects terrain/pathing restrictions
- Uses actual navigable routes
- Faces toward future navigable movement routes

#### Defender

- Guards a persistent home position
- Operates inside a configurable leash radius
- Attacks enemies inside assigned territory
- Returns home when enemies leave territory
- Restores original facing direction while idle
- Never chases endlessly across the map
- Uses terrain-aware movement evaluation
- Faces toward future navigable movement routes while advancing

#### Cautious Ranged

- Maintains preferred attack distance
- Attempts to avoid direct frontline engagement
- Uses terrain-aware pathfinding
- Prioritizes reachable attack positions
- Repositions before attacking when possible
- Uses actual traversable routes for movement evaluation
- Does not rely on directional coverage facing

#### Support Healer

- Prioritizes injured allies
- Uses heal charges strategically
- Searches for reachable healing positions
- Uses terrain-aware navigation
- Avoids unnecessary frontline exposure
- Falls back to movement behavior when no healing target exists

## Editor Features

- Terrain painting
- Rectangle fill tool
- Unit placement/removal
- Save/load map slots
- Rectangle terrain/unit movement
- Team assignment
- Facing assignment
- AI profile assignment
- Editor UI overlays
- Unit selection mode
- Defender leash editing
- Home tile visualization
- Selected-unit drag movement
- Area drag movement
- Live leash-range previews
- Global defender territory debug overlay (`F7`)
- Persistent defender home/leash serialization
- Rapid tutorial-map prototyping workflow

## UI Features

- Movement tile display
- Path preview display
- Dangerous tile highlighting
- Coverage overlays
- Attack range display
- Heal range display
- Turn indicator
- Stamina display
- Hover-based tactical cursor
- Mouse and keyboard cursor synchronization
- Keyboard grid navigation (`WASD` / Arrow Keys)
- Tactical unit cycling (`TAB`)
- Context-sensitive action menus
- Attack / wait / cancel nested confirmation flow
- Hover-based attack previews
- Real-time HP damage preview bars
- Threat range inspection for enemy units
- Defender territory overlays
- Live movement destination previews
- Hover-based unit inspection panel
- Compact HP/stamina battlefield UI
- Real-time hovered unit display
- Selected enemy threat inspection UI
- Terrain-combat readability improvements
- Sequential enemy movement readability
- Attack lunge animations
- Delayed HP update presentation
- Enemy action pacing pauses
- Hidden facing during movement animations
- Future-path AI facing presentation

---

# Design Goals

This prototype is focused on creating tactical battles where:

- movement creates vulnerability
- terrain shapes tactical decisions
- defensive lines matter
- stamina limits repeated reactions
- formations naturally emerge from play
- retreating and advancing both require planning
- danger zones are readable before committing
- battlefield control matters more than raw damage
- AI behaviors create faction identity
- territory ownership influences combat flow
- positioning matters before attacks happen
- navigable routes matter more than geometric proximity
- chokepoints create meaningful tactical pressure
- enemy actions remain visually understandable
- battlefield flow can be read at a glance

The combat system draws inspiration from tactical RPGs and strategy games, but replaces unlimited counterattacks with stamina-limited directional coverage and reaction systems.

The long-term goal is to create battles that feel:
- readable
- positional
- pressure-driven
- terrain-aware
- tactically expressive
- formation-focused
- visually understandable

rather than purely statistical.

---

# Planned Features

## AI Expansion

- Disciplined AI
- Formation AI
- Patrol AI
- Escort AI
- Advanced ranged positioning AI
- Support/healer AI
- Objective-defense AI
- Multi-layer territory ownership
- Reinforcement behaviors
- AI coordination systems
- Safe-path evaluation
- Terrain-preference AI
- Coverage-avoidance logic
- Formation cohesion behavior
- AI fallback line behavior

## Tactical Systems

- Additional terrain types
- Cavalry and breakthrough mechanics
- Morale/pressure systems
- Shieldwall or formation bonuses
- Unit traits and faction specialties
- Objective-based combat
- Ambush and stealth systems
- Patrol routes
- Dynamic defensive lines
- Engineer/barricade systems
- Destructible battlefield fortifications
- Temporary deployable terrain
- Expanded battlefield readability systems
- Sprite-based combat presentation

---

# Current Status

Early prototype / active development.

Systems, balance, AI behavior, editor tooling, map design, tactical pacing, and presentation systems are experimental and subject to change as the tactical framework evolves.

Recent development has focused heavily on:
- terrain-aware pathfinding
- modular AI architecture
- territory-aware defender behavior
- tactical readability
- hover/inspection UI systems
- editor workflow improvements
- scalable tactical systems
- debugging and visualization tools
- ranged/support AI behaviors
- AI terrain-aware targeting
- movement/path refactoring
- modular action/support systems
- coverage path traversal logic
- tutorial encounter design
- codebase cleanup and system normalization
- sequential AI movement presentation
- attack timing synchronization
- future-path AI facing
- AI/presentation layer separation
- battlefield readability improvements
- keyboard tactical controls
- nested action-menu flow
- contextual confirmation UI
- hover-preview combat visualization
- enemy-turn input locking

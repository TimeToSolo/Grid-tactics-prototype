# Grid Tactics Prototype

Turn-based tactical combat prototype built in Godot using GDScript.

This project explores tactical combat centered around movement, facing, stamina, directional coverage, territorial control, battlefield pressure, terrain-aware navigation, formation-based engagements, readable AI behavior, sequential battlefield presentation, layered mission scripting, and editor-driven campaign design.

The goal is to create battles where:
- positioning matters before attacks happen
- terrain shapes battlefield flow
- defensive lines can hold or collapse
- movement itself creates tactical vulnerability
- chokepoints and navigation matter tactically
- AI behaves consistently within terrain constraints
- enemy actions remain readable and visually understandable
- missions evolve dynamically through staged objectives and reinforcements
- campaign encounters support cinematic pacing and retreat gameplay

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
- dynamic mission flow
- pressure-based positioning
- campaign-style encounter structure

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
- Real-time movement/facing/action preview flow
- Unified pending-action architecture
- Consistent invalid-state handling across gameplay systems

---

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
- Reinforcement slide-in movement presentation
- Hidden facing during movement animations
- Future-path directional facing
- AI facing based on continued navigable routes
- Path-based interception detection
- Real reachable-route evaluation for AI decisions

---

## Unit Types

- Fighter
- Tank
- Duelist
- Lancer
- Archer
- Healer

---

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
- Territorial AI leash
- Home-position defensive behavior
- Path-based interception detection
- Terrain-driven engagement flow
- Bridge and lane-control gameplay
- Stamina-driven battlefield pacing
- Direction-aware enemy presentation
- Sequential battlefield readability systems
- Real-time movement/facing/action preview flow
- Unified pending-action architecture
- Consistent invalid-state handling across gameplay systems
- Data-driven layered mission objectives
- Multi-stage mission flow
- Dynamic reinforcement spawning
- Objective-event resolution system
- Campaign mission architecture
- Modular gameplay system architecture
- Decoupled gameplay/query/render systems
- Shared action-confirmation pipeline
- Delayed movement finalization architecture
- Coverage resolution after confirmed actions
- Future-facing directional prediction systems
- Terrain-aware AI route evaluation
- Reachable-route tactical evaluation
- Deterministic pathfinding behavior
- Unified stamina preview architecture
- Pending-action state management system

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
- Actual traversable-route evaluation
- Invalid-state AI movement protection
- Shared AI movement finalization system
- Terrain-aware healer positioning
- Defensive leash-return behavior
- Path-based directional facing prediction

### Current AI Profiles

#### Barbarian

- Aggressively pursues nearest reachable enemy
- Uses traversable path cost instead of raw grid distance
- Attacks whenever possible
- Ignores coverage danger
- Respects terrain/pathing restrictions
- Uses actual navigable routes
- Faces toward future navigable movement routes
- Uses terrain-aware route evaluation
- Uses post-move attack reevaluation

#### Defender

- Guards a persistent home position
- Operates inside a configurable leash radius
- Attacks enemies inside assigned territory
- Returns home when enemies leave territory
- Restores original facing direction while idle
- Never chases endlessly across the map
- Uses terrain-aware movement evaluation
- Faces toward future navigable movement routes while advancing
- Uses persistent leash/home serialization
- Uses terrain-aware return-home evaluation

#### Cautious Ranged

- Maintains preferred attack distance
- Attempts to avoid direct frontline engagement
- Uses terrain-aware pathfinding
- Prioritizes reachable attack positions
- Repositions before attacking when possible
- Uses actual traversable routes for movement evaluation
- Does not rely on directional coverage facing
- Evaluates retreat positioning dynamically
- Uses movement-aware ranged positioning

#### Support Healer

- Prioritizes injured allies
- Uses heal charges strategically
- Searches for reachable healing positions
- Uses terrain-aware navigation
- Avoids unnecessary frontline exposure
- Falls back to movement behavior when no healing target exists
- Uses terrain-aware healer approach logic
- Supports heal and regeneration actions

## Campaign and Mission Systems

- Campaign mission browser
- Mission flow controller
- Repository-based campaign map loading
- Mission state architecture
- Data-driven objective definitions
- Layered mission objective stages
- Objective stage progression
- Dynamic objective transitions
- Reinforcement-stage spawning
- Event-driven mission progression
- Campaign victory/defeat flow
- Modular mission-result evaluation
- Serialized mission objective data
- Mission scripting foundation
- Objective-zone serialization
- Editor-driven mission authoring
- Layered objective editing workflow
- Dynamic mission-event architecture

## Editor Features

- Terrain painting
- Rectangle fill tool
- Unit placement/removal
- Save/load map slots
- Campaign-level save/load workflow
- Rectangle terrain/unit movement
- Team assignment
- Facing assignment
- AI profile assignment
- Reinforcement placement mode
- Reinforcement stage assignment
- Reinforcement visualization overlays
- Editor UI overlays
- Unit selection mode
- Defender leash editing
- Home tile visualization
- Selected-unit drag movement
- Area drag movement
- Live leash-range previews
- Global defender territory debug overlay (`F7`)
- Persistent defender home/leash serialization
- Objective-stage editor
- Layered objective authoring
- Objective stage add/remove tools
- Objective stage navigation
- Objective type editing
- Objective parameter editing
- Objective completion-event editing
- Persistent objective serialization
- Objective-zone editing
- Objective-zone visualization overlays
- Reinforcement-stage visualization
- Editor-side objective data generation
- Rapid tutorial-map prototyping workflow
- Shared editor-state architecture
- Modular editor rendering systems
- Editor-specific input controller architecture

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
- Future-path AI facing presentation
- Reinforcement spawn presentation
- Objective editor UI
- Mission-stage inspection UI
- Real-time stamina preview display
- Pending-action confirmation previews
- Unified action-confirmation menu flow

----

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
- mission objectives evolve dynamically during battle
- tactical encounters support cinematic campaign flow
- terrain and pathing create naturally evolving battle lines
- battlefield readability remains clear even during large engagements
- AI decisions feel understandable rather than random
- pressure and positioning matter more than burst damage
- movement routes matter as much as destinations
- defensive territory creates meaningful strategic identity
- retreat gameplay feels tense rather than scripted
- battle pacing supports campaign storytelling
- objective flow creates evolving tactical scenarios
- enemy reinforcements create shifting battlefield states
- unit roles emerge naturally through positioning and terrain
- tactical information remains readable at a glance
- campaign encounters feel handcrafted rather than procedural
- tactical systems remain modular and expandable during development

The combat system draws inspiration from tactical RPGs and strategy games, but replaces unlimited counterattacks with:
- stamina-limited directional coverage
- delayed movement confirmation
- path-based interception systems
- terrain-aware movement pressure
- future-facing battlefield control
- movement-driven vulnerability
- readable enemy threat presentation

Rather than emphasizing raw stat optimization, the project focuses on:
- battlefield control
- tactical positioning
- formation cohesion
- territorial pressure
- navigable terrain flow
- readable tactical information
- layered objective progression
- campaign-style encounter pacing
- meaningful retreat and fallback gameplay
- movement commitment and risk evaluation

The long-term goal is to create battles that feel:
- readable
- positional
- pressure-driven
- terrain-aware
- tactically expressive
- formation-focused
- visually understandable
- campaign-driven
- sequentially readable
- strategically navigable
- mechanically coherent
- movement-focused
- dynamically evolving
- tension-oriented
- cinematic without sacrificing clarity

rather than:
- purely statistical
- animation-chaotic
- damage-race focused
- solved by raw unit trading
- dependent on hidden AI behavior
- dominated by unavoidable counterattacks
- reliant on excessive randomness

# Grid Tactics Prototype

Turn-based tactical combat prototype built in Godot using GDScript.

This project explores tactical combat centered around movement, facing, stamina, directional coverage, and battlefield pressure. The goal is to create battles where positioning matters before attacks happen, defensive lines can hold or collapse, and movement itself creates tactical vulnerability.

Rather than focusing on raw stat trading, the prototype emphasizes formation integrity, controlled advances, retreat pressure, lane denial, and readable battlefield threat.

---

# Current Features

## Core Combat

- Turn-based grid combat
- 8-directional facing system
- Directional coverage/interception zones
- Stamina-based reaction attacks
- Delayed coverage reactions after movement confirmation
- Movement stamina costs
- Attack, heal, regeneration, wait, and facing confirmation flow
- Auto-end turn when all units on the active team are exhausted
- Multi-team turn support (`player`, `enemy`, `neutral`, etc.)

## Movement and Pathing

- Cursor-traced movement paths
- Hovered path previews
- Path-based movement validation
- Multiple valid routes to the same destination
- Dangerous path tiles highlighted before movement confirmation
- Coverage reactions calculated from actual movement path traversal
- Deterministic pathfinding behavior for debugging and testing

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
- Directional interception
- Formation pressure
- Choke point gameplay
- Fallback-line gameplay
- Coverage-based positional control

## AI Systems

- Modular AI profile architecture
- Per-unit AI behavior assignment
- Mixed AI behaviors supported within the same faction

### Current AI Profiles

#### Barbarian

- Aggressively pursues nearest enemy
- Attacks whenever possible
- Ignores coverage danger
- Respects movement/facing restrictions

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

## UI Features

- Movement tile display
- Path preview display
- Dangerous tile highlighting
- Coverage overlays
- Attack range display
- Heal range display
- Turn indicator
- Stamina display
- Confirmation prompts
- Threat range inspection for enemy units

---

# Design Goals

This prototype is focused on creating tactical battles where:

- movement creates vulnerability
- defensive lines matter
- stamina limits repeated reactions
- formations naturally emerge from play
- retreating and advancing both require planning
- danger zones are readable before committing
- battlefield control matters more than raw damage
- AI behaviors create faction identity

The combat system draws inspiration from tactical RPGs and strategy games, but replaces unlimited counterattacks with stamina-limited directional coverage and reaction systems.

The long-term goal is to create battles that feel readable, positional, and pressure-driven rather than purely statistical.

---

# Controls

| Input | Action |
|---|---|
| Left Click | Select / Move / Choose target |
| Right Click | Cancel / Deselect |
| W | Confirm Wait |
| Y | Confirm Attack |
| H | Confirm Heal |
| R | Confirm Regeneration |
| N | Cancel Action |
| T | End Turn |
| C | Toggle Coverage Display |
| F | Rotate Editor Facing |
| A | Cycle Editor AI Profile |

---

# Planned Features

## AI Expansion

- Chokepoint-holder AI
- Disciplined AI
- Formation AI
- Ranged positioning AI
- Support/healer AI
- Objective-defense AI

## Tactical Systems

- Additional terrain types
- Cavalry and breakthrough mechanics
- Morale/pressure systems
- Shieldwall or formation bonuses
- Unit traits and faction specialties
- Objective-based combat

## Presentation

- Camera controls
- Larger maps
- Combat animations
- Better UI polish
- Sound and visual feedback
- Scenario progression

---

# Tech

- Engine: Godot
- Language: GDScript

---

# Repository Goals

This repository is being used to:

- learn Git and GitHub workflow
- prototype tactical combat systems
- experiment with battlefield-control mechanics
- explore AI behavior design
- build a long-term portfolio project

---

# Current Status

Early prototype / active development.

Systems, balance, AI behavior, and map design are experimental and subject to change as the tactical framework evolves.

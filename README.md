# Grid Tactics Prototype

Turn-based tactical combat prototype built in Godot using GDScript.

This project explores tactical combat built around movement, facing, stamina, coverage zones, and formation pressure. The goal is to create battles where positioning matters before attacks happen, defensive lines can hold or collapse, and movement choices create real vulnerability.

## Current Features

### Core Combat

- Turn-based grid movement
- 8-directional facing
- Directional coverage zones
- Stamina-based counterattacks
- Delayed coverage reactions after movement confirmation
- Movement stamina costs
- Attack, heal, regen, wait, and facing confirmation flow
- Auto-end turn when all player units are exhausted

### Movement and Pathing

- Cursor-traced movement paths
- Hovered path preview
- Movement range validation by path length/cost
- Multiple possible routes to the same tile
- Dangerous path tiles highlighted before confirming movement
- Coverage reactions based on the actual path traveled, not just start/end position

### Unit Types

- Tank
- Duelist
- Lancer
- Archer
- Healer

### Tactical Systems

- Terrain interaction
- Blocked tiles
- Movement costs
- Ranged attack checks
- Healing charges
- Regeneration support
- Directional interception
- Choke point and fallback-line gameplay

### UI Features

- Movement tile display
- Path preview display
- Dangerous tile highlighting
- Coverage overlays
- Attack range display
- Heal range display
- Turn indicator
- Stamina display
- Confirmation prompts

## Design Goals

This prototype is focused on creating tactical battles where:

- movement creates vulnerability
- defensive lines matter
- stamina limits repeated reactions
- formations naturally emerge from play
- retreating and advancing both require planning
- danger zones are readable before committing to a move

The combat system is inspired by tactical RPGs, but replaces unlimited counterattacks with stamina-based reactions and directional coverage.

## Controls

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

## Planned Features

- Enemy AI behaviors and personalities
- More terrain types
- Cavalry / breakthrough mechanics
- Map objectives
- Morale or pressure systems
- Faction identity
- Larger maps with camera controls
- Better UI polish
- Scenario progression

## Tech

- Engine: Godot
- Language: GDScript

## Repository Goals

This repository is being used to:

- learn Git and GitHub workflow
- prototype tactical combat systems
- experiment with battlefield design concepts
- build a long-term portfolio project

## Current Status

Early prototype / active development. Systems and balance are experimental and subject to change.

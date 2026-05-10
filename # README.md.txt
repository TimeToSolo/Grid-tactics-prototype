# Grid Tactics Prototype

Turn-based tactical combat prototype built in Godot.

This project is focused on creating a tactical combat system centered around:
- directional control
- stamina-based reactions
- battlefield formations
- tactical retreats
- coverage zones
- combined arms gameplay

Instead of traditional unlimited counterattacks, units use stamina to react to nearby threats. This creates situations where formations can gradually become exhausted and collapse under pressure.

---

## Current Features

### Core Combat
- 8-direction movement and facing
- directional coverage zones
- stamina-based counter system
- movement affecting combat effectiveness
- attack confirmation system
- facing-based defensive control

### Unit Types
- Tank
- Duelist
- Lancer
- Archer
- Healer

### Tactical Systems
- terrain interaction
- movement costs
- choke point gameplay
- ranged attack falloff
- directional interception
- fallback line gameplay

### UI Features
- coverage overlays
- attack range display
- movement previews
- turn indicator
- stamina display
- confirmation prompts

---

## Design Goals

The primary goal of the project is to create:
- readable tactical combat
- believable battlefield behavior
- meaningful positioning
- strong formation gameplay
- tactical pressure without excessive complexity

The system is heavily inspired by the idea that:
- movement should create vulnerability
- defensive lines should matter
- exhaustion should matter
- formations should naturally emerge from gameplay

---

## Planned Features

- AI behaviors and personalities
- additional terrain types
- cavalry and breakthrough mechanics
- map objectives
- morale and pressure systems
- faction identity
- improved UI polish
- larger maps with camera controls

---

## Controls

| Key | Action |
|---|---|
| Left Click | Select / Move |
| Right Click | Cancel |
| W | Confirm Wait |
| Y | Confirm Attack |
| H | Confirm Heal |
| N | Cancel Action |
| T | End Turn |
| C | Toggle Coverage Display |

---

## Tech

- Engine: :contentReference[oaicite:0]{index=0}
- Language: GDScript

---

## Repository Goals

This repository is being used to:
- learn Git and GitHub workflow
- prototype tactical combat systems
- experiment with battlefield design concepts
- build a long-term portfolio project

---

## Current Status

Early prototype / active development.
Systems and balance are heavily experimental.
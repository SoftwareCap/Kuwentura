# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Kuwentura** — 2D asymmetric co-op detective mobile game (Godot 4.5, GDScript). Philippine folklore-inspired. Two players investigate mystery of "Pina" across 5 zones.

- **Detective (Player 1 / Host)**: Visual exploration, clue pickup, movement
- **Sidekick (Player 2 / Client)**: Audio cues, puzzle assistance — no movement control

## Running the Game

No build scripts. Pure Godot project.

1. Open `kuwentura/project.godot` in Godot 4.5+ (Forward Plus renderer)
2. Press **F5** to run
3. For multiplayer testing: run two editor instances — Instance 1 hosts (becomes Detective), Instance 2 joins via `127.0.0.1`

**Export**: Android APK via `export_presets.cfg`.

## Architecture

### Core Singletons (Autoloads)

All defined in `project.godot`. The critical ones:

| Singleton | File | Role |
|-----------|------|------|
| `GameState` | `scripts/systems/game_state.gd` | Central progression: zones, clues, puzzle seeds, roles |
| `LocalSaveManager` | `scripts/systems/local_save_manager.gd` | PRIMARY save — JSON to `user://kwentura_save.json` |
| `OfflineNetworkManager` | `scripts/systems/offline_network_manager.gd` | ENet UDP multiplayer (Direct IP / Hotspot / QR) |
| `PuzzleManager` | `scripts/systems/puzzle_manager.gd` | Deterministic puzzle generation & validation |
| `DialogueSystem` | `scripts/systems/dialogue_system.gd` | Narrative dialogue delivery |
| `ClueManager` | `scripts/systems/clue_manager.gd` | Clue collection state |
| `FirebaseAuth` / `FirebaseManager` | `scripts/systems/firebase_*.gd` | Optional cloud backup (non-blocking, secondary) |

### Three-System Design

1. **Local-First Save (primary)**: FileAccess → JSON → `user://kwentura_save.json`. Works 100% offline. Auto-saves every 30s, keeps 3 backup versions.
2. **Offline Multiplayer**: ENet UDP. Host = Detective (Player 1), Client = Sidekick (Player 2). Host validates all puzzle submissions.
3. **Optional Cloud Backup**: Firebase REST API. Non-blocking, async, secondary to local.

### Game Flow

```
Main Menu → Detective Lobby (host) / Sidekick Join (client)
         → Opening Cutscene
         → Forest Hub (zone selection)
         → Zone (puzzle + clues)
         → Back to Hub (repeat for all 5 zones)
         → Climax: Altar Deduction → Bakunawa encounter
```

### Zone System

5 zones, each with a unique puzzle and collectible clue:

| Zone | Puzzle Type | Clue |
|------|------------|------|
| Pina's House | Algebra (solve for x) | Ladle |
| Backyard Path | Visual | Pineapple Sapling |
| Old Well | Logic | Eye Symbol |
| Storage Hut | Interactive | Wish Scroll |
| Abandoned House | Sequential | Tiara |

### Multiplayer Pattern

- RPC calls: **reliable** for game state, **unreliable** for movement
- Host authority model — Detective host validates all state changes
- `OfflineNetworkManager` handles peer discovery, role assignment, sync

### Puzzle System

- Seeded via `session_seed` for determinism across both clients
- 5 difficulty variations per zone
- `PuzzleManager` owns all puzzle data (equations, solutions, riddles)
- Host validates submissions

## Script Organization

```
kuwentura/scripts/
├── systems/        # Core singletons (game_state, save, network, puzzle, dialogue, firebase)
├── world/
│   ├── game.gd         # Main game controller
│   ├── hub/            # Forest Hub (zone_portal, finish_zone_indicator)
│   └── zones/          # One folder per zone
├── mainMenu/       # main_menu, detective_lobby, sidekick_waiting, post_game_lobby
├── player/         # player.gd — movement, animation, network sync
├── puzzles/        # Zone-specific puzzle implementations
├── ui/             # dialogue_box, loading_screen
├── controls/       # touch_controls, settings, audio, inside_zone
├── cutscenes/      # opening_cutscene.gd
└── Main.gd         # Entry point scene controller
```

## Code Conventions

- `snake_case` for functions and variables, `PascalCase` for class/node names
- Private methods prefixed with `_`
- Type hints used throughout GDScript
- Autoloads accessed directly by singleton name (e.g., `GameState.current_zone`)

## Key Files

- `AGENTS.md` — comprehensive architecture docs with Mermaid diagrams, RPC patterns, UI patterns, save flow, troubleshooting (read this for deep dives)
- `kuwentura/project.godot` — autoload definitions, input mappings, display config (1240×1080, canvas_items stretch)
- `export_presets.cfg` — Android export configuration

# OCS VR: the Godot project

Immersive training for **AP CSP Unit 4** (Computer Systems and Networks), built in **Godot 4.7.2** for the **Meta Quest**: students build a computer, then a network, and each mission's score is saved to the team's Flask backend ([OCSVR/ocs_backend](https://github.com/OCSVR/ocs_backend)).

The work follows the team build plan (`OCSVR_Training_Plan.md` section 5 in the team Drive): laptop first, then the Quest.

## Open it

1. Install **Godot 4.7.2 standard** (not .NET). Setup guides with the exact versions are in the team Drive: `OCSVR_Godot_Setup_Windows.md` and `OCSVR_Godot_Setup_macOS.md`.
2. Clone this repo and open `project.godot` from Godot's project manager (**Import**).
3. Press **Play** (F5). The "Identify components" mission opens. (The step 1 sandbox is `scenes/workbench.tscn`; open it and press F6 to play just that scene.)

## Status

| Build-plan step | State |
|---|---|
| 1. Laptop workbench + one snap task | **Done:** drag the RAM stick into the RAM slot with the mouse |
| 2. One full mission ("Identify components") with hints and a success panel | **Done:** CPU, RAM, SSD and keyboard into their places, checklist and hints on a 3D panel, score/time/attempts on success |
| OpenXR, Quest export preset, vendors plugin | Being set up by Aryan's side; they get added here |

## How it fits together

| File | Job |
|---|---|
| `scenes/room.tscn` | The room every mission uses: light, floor, table, standing camera, grab layer (`scripts/room.gd`) |
| `scenes/build_computer/identify_components.tscn` | Module 1, mission 1: a motherboard with CPU socket, RAM slot and M.2 slot, a USB spot for the keyboard, the four parts, and the info panel |
| `scripts/missions/identify_components.gd` | The mission: Intro → Active (on first grab) → Success (every slot filled). 100 points, minus 10 per wrong drop; emits `mission_completed(module_id, score, duration_s, attempts)` |
| `scripts/ui/info_panel.gd` | A 3D panel (SubViewport on a quad) for intros, checklists, hints and results |
| `scenes/workbench.tscn` | Step 1's sandbox: one RAM slot and one RAM stick |
| `scripts/grabbable_part.gd` | A part you can pick up. Knows its `part_type`; on a drop it picks the one slot that judges it (so a keyboard over three slots is one mistake, not three); goes home if not installed |
| `scripts/snap_zone.gd` | A slot (`Area3D`) with a `hint`. It judges a dropped part: right type → installs it and emits `snapped`; wrong type → emits `rejected` |
| `scripts/input/mouse_grabber.gd` | The laptop's grab/drop layer: press, carry, release. The only script that knows about the mouse |
| `scripts/workbench.gd` | Step 1's controller: updates the sign |
| `tests/run_tests.gd` | Headless checks (below) |

The VR rules from the build plan, and where they show up:

1. **Real scale, 1 unit = 1 m.** The RAM stick is 0.133 m long; the table top is 0.9 m high.
2. **Standing player.** The camera is at 1.6 m eye height. Both numbers get replaced by the step 0 headset measurements.
3. **3D, not 2D.** Every part is a 3D object.
4. **UI on 3D panels.** The mission panel is a SubViewport drawn on a quad, tilted toward the player; part names are `Label3D`s. No `CanvasLayer` UI, since it doesn't show in the headset.
5. **One input layer.** Parts and SnapZones only see `grab()` and `drop()`. A controller or hand grabber replaces `MouseGrabber` without touching the game.
6. **No camera moving on its own.** The camera is placed once.
7. **Model setup.** Each part is a body with logic and a simple collision shape, with its mesh as a child named `Mesh`, so a `.glb` model swaps in by replacing that child.
8. **Origin at the snap point.** The RAM stick's origin is its bottom edge, and each SnapZone has a `SnapPoint` marker.

## Run the checks

From the repo folder, with `godot` meaning your Godot 4.7.2 binary:

```bash
godot --headless --import
godot --headless --script res://tests/run_tests.gd
```

They load the scenes, move parts the way a grabber does (through the real mouse grabber and camera), step physics, and check the snap rules and the whole mission: a perfect run scores 100 with the right time, wrong drops show the slot's hint and cost 10 points each, and a big part over several slots counts once. Exit code 0 means all passed.

## Rules for contributing

- Work on a branch and open a pull request into `main`; Aryan merges.
- Keep Godot at **4.7.2** so `project.godot` and the scene files don't churn between versions.
- `.godot/`, `/android/` and `build/` are ignored: every computer makes its own.

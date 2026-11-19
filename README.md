# OCS VR: the Godot project

Immersive training for **AP CSP Unit 4** (Computer Systems and Networks), built in **Godot 4.7.2** for the **Meta Quest**: students build a computer, then a network, and each mission's score is saved to the team's Flask backend ([OCSVR/ocs_backend](https://github.com/OCSVR/ocs_backend)).

The work follows the team build plan (`OCSVR_Training_Plan.md` section 5 in the team Drive): laptop first, then the Quest.

## Open it

1. Install **Godot 4.7.2 standard** (not .NET). Setup guides with the exact versions are in the team Drive: `OCSVR_Godot_Setup_Windows.md` and `OCSVR_Godot_Setup_macOS.md`.
2. Clone this repo and open `project.godot` from Godot's project manager (**Import**).
3. Press **Play** (F5). The workbench opens.

## Status

| Build-plan step | State |
|---|---|
| 1. Laptop workbench + one snap task | **Done:** drag the RAM stick into the RAM slot with the mouse |
| 2. One full mission ("Identify components") with hints and a success panel | Next |
| OpenXR, Quest export preset, vendors plugin | Being set up by Aryan's side; they get added here |

## How it fits together

| File | Job |
|---|---|
| `scenes/workbench.tscn` | The room: floor, table, motherboard, RAM slot, RAM stick, camera, instruction sign |
| `scripts/grabbable_part.gd` | A part you can pick up. Knows its `part_type`; goes back home if dropped outside its slot |
| `scripts/snap_zone.gd` | A slot (`Area3D`). When a part is dropped on it: right type → installs it and emits `snapped`; wrong type → emits `rejected` |
| `scripts/input/mouse_grabber.gd` | The laptop's grab/drop layer: press, carry, release. The only script that knows about the mouse |
| `scripts/workbench.gd` | Step 1's controller: wires the camera and updates the sign |
| `tests/run_tests.gd` | Headless checks (below) |

The VR rules from the build plan, and where they show up:

1. **Real scale, 1 unit = 1 m.** The RAM stick is 0.133 m long; the table top is 0.9 m high.
2. **Standing player.** The camera is at 1.6 m eye height. Both numbers get replaced by the step 0 headset measurements.
3. **3D, not 2D.** Every part is a 3D object.
4. **UI on 3D panels.** The instruction sign is a `Label3D`; step 2 adds proper SubViewport panels. No `CanvasLayer` UI, since it doesn't show in the headset.
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

They load the workbench, move parts the way a grabber does (including through the real mouse grabber and camera), step physics, and check that the right part snaps, a wrong part is rejected, and a missed drop goes home. Exit code 0 means all passed.

## Rules for contributing

- Work on a branch and open a pull request into `main`; Aryan merges.
- Keep Godot at **4.7.2** so `project.godot` and the scene files don't churn between versions.
- `.godot/`, `/android/` and `build/` are ignored: every computer makes its own.

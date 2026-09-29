# DesktopFly on this Mac

Built on 29 September 2026 from
[DesktopFly v1.1.0](https://github.com/DenisSergeevitch/desktop-fly), upstream
commit `32b00011e83c3dc85fa3ea0b3934155b04f1635d`.

## Start and control

Open `dist/DesktopFly.app` in Finder, or double-click `Start DesktopFly.command`.
The app is self-contained: its connection tables travel inside the bundle.
It runs as a menu-bar app, without a Dock icon.

Click **🪰** in the macOS menu bar for:

- **Pause / Resume** and **Quit**.
- **Follow Cursor**, enabled at launch. Move slowly or hold the cursor still;
  the fly approaches and stops about 150 screen points away. A sudden nearby
  movement still activates the neural escape pathway.
- **Drop Sugar…** enters placement mode. Click once on the fly's display to
  place a golden sugar cube; that click is captured, so it does not click the
  application underneath. Escape or right-click cancels. Normal click-through
  behavior and the previous app's focus are restored after placement.
- **Clear Sugar** removes the food. Up to five portions can be present; placing
  a sixth replaces the oldest. Uneaten food expires after three active minutes.
- **Show/Hide Brain** to inspect the live neural visualization.
- **Escape Test (loom)** to stimulate the escape pathway.
- **Energy Saver (30 fps)**, on by default. Turn it off to request 60 fps.
- **Move to Next Display** when another display is connected.

Move the cursor quickly toward the fly or click nearby to startle it. The desktop
overlay lets clicks pass through to the application underneath. It can walk,
groom, fly, land on window edges, and sleep when the user is inactive.

Only the first fly uses the neural simulation. Extra flies use the upstream
scripted behavior. Keep one fly for the intended small-circuit experiment.

## What is running

The app simulates a 668-neuron FlyWire brain circuit and a separate 1,045-neuron
MaleCNS leg circuit: 1,713 modeled neurons total. The within-dataset connection
tables are derived from measured anatomy. Neuron dynamics, sensory conversion,
the interface between the two specimens, and body mechanics are models.

The brain viewer draws 23,210 soma locations; those displayed points are not
all simulated neurons. This is not the full 139k/166k connectome.

Cursor following and sugar feeding are programmed pet rules, not learned
behavior or a biological MN9 feeding circuit. During pursuit/feeding, procedural
steering and leg animation take over body motion while the neural simulations
continue. Escape and sleep retain priority. Turn **Follow Cursor** off and
**Clear Sugar** to return to the original neural/body behavior.

The first fly chooses the nearest sugar over the cursor, walks within 22 points,
and takes four seconds of uninterrupted feeding to finish a portion. The cube
shrinks as it eats. Escape pauses consumption; partly eaten food can be resumed.
The menu status reports following/eating/recovery and the number of portions
eaten. These counters and food are session-only. Display changes clear old food.

## Local changes

- Default overlay rendering requests 30 fps instead of 120; the neural/body
  loop still advances at its existing fixed rates. Actual rendering depends
  on system load.
- Disabled full-screen multisample antialiasing to reduce graphics overhead.
- The optional brain viewer is constructed only when requested, and stops
  playback when hidden through the menu.
- Added a self-contained app bundle, ad-hoc code signature, and launcher.
- Added bundled-resource lookup while retaining the original command-line
  data lookup, plus an accessibility label for the menu control.
- Added cursor following, sugar placement/consumption, and a pet status line.
  Their state changes run on the existing 120 Hz simulation loop. Pause freezes
  pursuit and feeding as well as the original simulation.

This is a local build, not an Apple-notarized distribution. It has not been
installed as a login item. No full connectome or microscopy volumes were
downloaded. Runtime code uses local data and macOS APIs; no cloud service or
Python environment is required.

## Verification

The packaged executable was tested from `/private/tmp`, outside the source
folder, to verify that it uses its own bundled data. The native suites cover
circuit diagnostics, 23 original behavior checks, 18 locomotor checks, and
20 pet checks. Run the new suite with `./DesktopFly --pettest`.
Results are saved in `simtest.log`, `behaviortest.log`, `locomotortest.log`,
and `pettest.log`. Pet checks include the live coordinator, a cursor jab through
the neural escape pathway, pause, display changes, and 30/60 fps equivalence.
The Windows model mirrors the behavior and has 15 pet checks in `npm test`;
its OS integration has not been tested on a Windows machine.

`codesign --verify --strict dist/DesktopFly.app` and the bundle plist check
pass. Rebuild with `./package-app.sh`; the original `./build.sh` still produces
the command-line executable. Quit the running app before rebuilding it.

Short live resource measurements are in `resource-final.log`; these are not
an overnight battery, thermal, or memory-leak test. The measured machine
reports Apple M5 and 16 GiB unified memory.

The initial build sample, before adding pet behavior, at 11:27–11:28 IST recorded approximately **271 MB** memory
and **17.1–20.9% of one CPU core** across three timed intervals. The app bundle
occupies approximately **2.7 MB** on disk; the entire local checkout is about
**7.3 MB**. These readings include the pet's native 3D rendering, with the
brain viewer unopened. macOS `top` reports process CPU on a scale where
100% is one core, not the whole machine.

## Attribution and data terms

Original code: DenisSergeevitch/DesktopFly, MIT. FlyWire-derived data:
CC BY-NC 4.0. MaleCNS-derived data: CC BY 4.0. Original licenses and source
attribution are preserved in `LICENSE`, `data/DATA_LICENSE.md`, and
`data/LOCOMOTOR_PROVENANCE.md`, and are included in the app bundle.

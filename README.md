# Nocturne

A bilingual educational game about the spacecraft, rovers and scientific instruments that remain on the Moon, Mars and in deep space. Nocturne, a fictional cyan mouse with orange glasses, helps school-age learners explore the science and history behind this hardware.

Prepared for NASA Space Apps Challenge 2026, Andahuaylas, Peru, by the Nebula Drift team. Challenge: **Abandoned but not Forgotten: Storytelling about NASA's Discarded Equipment on the Moon and Mars**. This repository does not claim organizer approval or award eligibility.

## Play locally

1. Install the standard edition of [Godot 4.3](https://godotengine.org/download/archive/4.3-stable/). No .NET SDK or add-on is required.
2. Clone or download this repository and import `project.godot`. Let the editor import the assets.
3. Press F5. Care for Nocturne to unlock Stories; the existing Demo controls can help reviewers explore the progression.
4. Open **Stories** and choose a mission. The four HTML games open in your default browser. Switch back to Godot to choose another mission.

To try a browser game directly, open its `index.html` from the table below. These are self-contained games; web fonts and external reference links require internet. The Godot application itself has not been exported as a browser build.

| Adventure | Source | Learning focus |
| --- | --- | --- |
| El espejo silencioso / The Silent Mirror | [HTML](stories/html/silent_mirror/index.html) | Lunar retroreflectors and round-trip light travel time |
| Oppy: Una aventura en Marte | [HTML](stories/html/oppy/index.html) | Rover exploration, images, observations and solar energy |
| Voyager 1 | [HTML](stories/html/voyager_one/index.html) | Spacecraft journeys, flybys and scientific exploration |
| Guardianes del Legado / Keepers of the Legacy | [HTML](stories/html/small_discoveries/index.html) | Recognizing and documenting space heritage |

Each adventure has a three-medal learning passport, hints and persistent browser progress. The mouse is an imaginary companion, not a historical passenger. Stories also includes the earlier eight-chapter native reader. No accessory-unlocking system is claimed in this release.

## Implementation

- Godot: GDScript, scenes, shaders, 3D mouse, 2D interface, physics, care, dialogue and saves.
- Browser adventures: HTML, CSS, JavaScript, Canvas/SVG and synthesized Web Audio.
- Art: supplied mouse model, Blender source in `source_art/Mouse.blend`, runtime rig/materials and an AI-generated laboratory background. The Blender source predates runtime glasses and procedural facial controls; those are in `character/`.
- Localization: Godot catalogs in `locales/en.json` and `locales/es.json`; the supplied HTML games retain their own embedded bilingual dictionaries.
- Saves: Godot writes to `user://`; browser games use local storage. The internal `LumenMouse` application ID remains unchanged for save compatibility. No player saves are included.

## Science, credits and licensing

Read [NASA sources and their use](docs/NASA_SOURCES.md), [AI disclosure](docs/AI_USE.md), [credits and provenance](docs/CREDITS.md), and [submission checklist](docs/SUBMISSION.md).

The root code is available under [Apache-2.0](LICENSE), with existing MIT-licensed browser components and their notices preserved under [licenses](licenses). NASA and other external resources retain their own terms. This project is independent and does not imply NASA endorsement.

## Validation and limitations

The preceding game revision passed library checks in Godot 4.3 on Windows and browser tests covering mission unlocks, hints, medals, storage, English/Spanish and narrow screens. Browser unlock events were simulated; full adventures have not been played end to end. No physical Android testing or APK is provided. NASA image requests and speech depend on network access and installed voices.

After importing, run `godot --path . --script res://LibraryTest.gd` for library navigation, isolated HTML extraction and localization checks. Historical tests remain in the repository; do not interpret their presence as evidence that every test passed on this release. See [validation](docs/VALIDATION.md).

Contributions are welcome: see [CONTRIBUTING.md](CONTRIBUTING.md).

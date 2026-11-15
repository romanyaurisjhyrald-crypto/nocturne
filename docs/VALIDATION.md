# Validation

Public packaging removes editor caches, personal data and an unused legacy sky image. It preserves gameplay and storage identifiers, updates the displayed name, and adds a localized generated-background disclosure.

Historical browser checks: four pages, seventeen embedded scripts, unlock deduplication, incorrect-answer hints, medals, persistence, both languages, narrow panels and initial gameplay rendering. Mission events were simulated, not full playthroughs. Historical native check: LibraryTest.gd passed on Godot 4.3 / Windows.

Publication checks and results are recorded in the release commit description. No Android device test, complete playthrough or official competition approval is claimed.

## Public-source verification on November 15, 2026

- Clean editor import: Godot 4.3, Compatibility renderer, Windows.
- LibraryTest.gd: passed, with no engine errors. Checks five separate entries, isolated HTML extraction, invalid ID rejection, native-reader navigation, reopening, English/Spanish and portrait scrolling.
- tools/validate_source.py: matching catalogs and seventeen JavaScript scripts parsed successfully.
- Existing MIT/OFL notices were preserved verbatim; the root Apache-2.0 license is unchanged.
- The historical full integration suite was not rerun. Full browser playthroughs and physical mobile-device validation remain outstanding.

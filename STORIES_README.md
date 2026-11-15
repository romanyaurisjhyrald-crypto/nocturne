# Space Guardians integration

This revision uses the supplied Git/MouseNocturne project as its base, preserving Boot, teaching mode, the chalkboard, trust unlocks, demo controls and the mouse. It does not replace them with an earlier project.

Stories now hosts a native Godot adaptation of the supplied HTML: eight chapters, English/Spanish catalogs, chapter selector, previous/next, scrolling text, NASA image requests and installed-system-voice narration. Back and Escape return through the existing study mode. Closing the reader stops speech. Original HTML opens the unchanged supplied file in the default browser; it does not run inside a WebView.

The exact original is stories/space_guardians.html. The export include filter includes HTML and chapter JSON. No additional browser plugin is required. The text remains available offline. NASA images require internet, and narration requires an installed voice for the selected language. Existing care save compatibility is preserved; story chapter position lasts for the current session only.

Tests ran in Godot 4.3 on Windows. Eight chapters, language changes, navigation, returning/reopening and portrait layout passed. The live NASA image request did not succeed in this environment; offline handling was exercised. Browser speech and native file launching were not manually verified. No Android device test was performed.

The native adaptation keeps the supplied prose. It is not a scientific fact-check of the HTML. Consult NASA sources for educational review.

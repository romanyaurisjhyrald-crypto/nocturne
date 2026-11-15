# Project rules

- Write all source code, identifiers, file and folder names, comments, internal
  errors and commit messages in English.
- Keep all player-facing text outside gameplay logic in `locales/en.json` and
  `locales/es.json`. Translation keys must be English snake_case identifiers.
- Maintain matching catalog keys and complete English and Spanish translations.
- Keep Spanish available in Settings and persist the selected language.
- Use English action and emotion identifiers in all gameplay metadata.
- Keep backward compatibility with existing saves through data-driven migration.
- Preserve the current character, UI layout and Stories integration unless a
  requested change explicitly requires otherwise.
- Explain changes to the user in Spanish. Any displayed code must follow these rules.

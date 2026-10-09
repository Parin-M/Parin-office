# Parin Office — Flutter

Parin Office is an adaptive Android office workspace built with Flutter for phones and tablets. Its visual direction uses ideas common to modern component systems—consistent color tokens, clear hierarchy, rounded surfaces, responsive navigation, accessible controls and reduced-motion support—reimplemented as native Flutter widgets rather than copying a React/Tailwind codebase.

## Included in this build

- Adaptive navigation for phones, tablets and wider layouts.
- An in-app Parin brand mark and generated Android launcher/adaptive icons.
- 128 named color palettes with family filtering and instant preview; semantic color tokens normalize accents, controls and surfaces across Light, Dark and true-black AMOLED.
- Adaptive phone/tablet navigation, branded in-app mark, and generated Android launcher/adaptive/monochrome icons.
- 16 selectable locales, explicit RTL direction for Persian, Arabic and Hebrew, and initialized localized date formatting.
- Optional blue-light warm overlay with persisted enable/disable and adjustable strength.
- Searchable settings with persistent toggles, high contrast, text scale, editor font/line-spacing controls, dashboard personalization, settings export and reset.
- Local draft recovery, recent-document history, optional confirmation before recent-item removal, and opt-in haptics/animations.
- PDF creation and the existing PDF editor integration.
- **Embedded offline Office engine:** DOCX, XLSX, and PPTX are parsed, edited, laid out, and serialized on the device by the bundled Dart engine/editor packages. Editing does not call a document server, cloud conversion service, or login endpoint.
- **Word editor (DOCX):** paginated document canvas; text editing and formatting; tables and cell operations; pictures and other supported visuals; headers/footers; footnotes/endnotes; comments; hyperlinks; lists; equations; rulers; find/replace; undo/redo; print and PDF export.
- **Excel editor (XLSX):** virtualized spreadsheet canvas; cell editing and formula bar; formula recalculation; number formats; merges; freeze panes; charts; drawings; data validation; filters and sorting; find/replace; undo/redo; print and PDF export. Legacy **XLS** files continue through the compatibility editor.
- **PowerPoint editor (PPTX):** editable slide stage with move/resize/rotate handles; text, tables, pictures, charts and z-order; animations and slide transitions supported by the engine; presenter/slideshow controls; notes; undo/redo; print and PDF export.

## Scope and import-fidelity notes

The OOXML editing path is fully on-device: documents remain local unless the user deliberately shares or exports them. The embedded engine is a new third-party package and is not Microsoft Office or LibreOffice; file fidelity is feature-dependent. Formats such as DOCX/XLSX/PPTX are supported by this engine, but VBA/macros, Power Query/Power Pivot, ActiveX, some uncommon formula functions, some uncommon font/image encodings, and vendor-specific extensions are not equivalent to desktop Microsoft Office. Legacy XLS still uses the compatibility editor. Keep a copy of critical originals and verify mission-critical complex files in a full office suite before relying on the output.

The engine packages are MIT-licensed, but newly released software can still contain format edge cases; regression tests cover local open/save of representative DOCX/XLSX/PPTX files, not every Office feature or file. There is no cloud sync, collaboration service, OCR service, or AI service in the offline editor path.

The blue-light tint is an optional in-app overlay. It does not change the device display's system-level color temperature, and it can be disabled or set to zero strength.

## Build

The CI workflow uses Flutter 3.47, generates launcher image assets, creates Android adaptive icons, runs analysis and tests, then builds universal and per-ABI APKs.

```bash
python3 tool/generate_launcher_assets.py
flutter pub get
dart run flutter_launcher_icons
flutter analyze --no-fatal-infos
flutter test
flutter build apk --release --split-per-abi --no-tree-shake-icons
flutter build apk --release --no-tree-shake-icons
```

The on-device OOXML engine and its bundled font assets are included in the app build. APK size may therefore grow with genuine editing/rendering functionality; the project does not artificially pad releases.

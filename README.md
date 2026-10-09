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
- **Word editor:** rich-text editing with bold/italic/underline/strike, font size and color controls, headings, alignment, lists, links, undo/redo, search, find/replace, word count, page size/orientation/margins, focus mode, zoom and DOCX export.
- **Excel editor:** open XLSX and legacy XLS, edit cells through a grid/formula bar, evaluate formulas, format cell text and fills, find/replace, insert rows/columns, add worksheets, freeze panes, filters, column charts, CSV export and XLSX save.
- **PowerPoint editor:** extract text from imported PPTX slides into editable title/body fields, create/duplicate/delete/reorder slides, change slide backgrounds and accent colors, choose slide layouts, preview slides and export a multi-slide PPTX.

## Scope and import-fidelity notes

These are native, offline editing workspaces, not a claim of full Microsoft Office equivalence. Word import currently reconstructs an editable text document from paragraph text, so arbitrary source pictures, embedded objects, tables, comments, tracked changes and complex section formatting are not round-tripped. PowerPoint import extracts slide text and rebuilds a supported title/body slide model; original animations, transitions, speaker notes, media, SmartArt, charts and complex object geometry are not preserved. Excel uses an actual workbook engine with formula evaluation and style editing; unsupported Excel functions or advanced workbook objects may not recalculate or round-trip exactly. Keep a copy of critical originals and verify complex documents in a full office suite before relying on the output.

Cloud sync, app lock, AI/OCR services, VBA/macros, collaborative editing and full-fidelity OOXML round-trip for every feature are not included in this offline build.

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

The project does not artificially pad the APK to an arbitrary size; release size should grow only when real engines, fonts and offline assets are added.

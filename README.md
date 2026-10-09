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
- Starter DOCX, PPTX and XLSX creation using Open XML package parts; spreadsheet entries are created from comma-separated or tab-separated rows.

## Scope notes

The Word, PowerPoint and Excel create actions export starter files using the formats' container structures. This is not yet a full Microsoft Office replacement, and importing/editing every feature in arbitrary existing DOCX/PPTX/XLSX documents remains future work. Cloud sync, app lock, AI/OCR services and advanced formula/revision engines are not presented as working features in this build.

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

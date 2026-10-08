Parin Office — Flutter rebuild

Parin Office is a professional adaptive office workspace being rebuilt in Flutter for Android phones and tablets.

New direction

- Clean Flutter/Dart application shell replacing the legacy Kotlin prototype.
- Phone and tablet adaptive navigation.
- Office-style ribbon workspace.
- 128 generated color themes.
- System, Light, Dark and AMOLED modes.
- 16 locale choices with RTL for Persian, Arabic and Hebrew.
- Real PDF editing integration through dart_pdf_editor.
- Dedicated Word, PowerPoint and Excel workspace surfaces.

Full Office target

Word: layout, pagination, styles, sections, tables, headers/footers, fields, comments, tracked changes, images and print layout.
PowerPoint: slide canvas, shapes, connectors, themes, masters, media, tables, charts, transitions and presentation mode.
Excel: virtualized grid, formulas, styling, merged cells, conditional formatting, filtering, sorting, freeze panes, validation, named ranges, charts and print areas.
PDF: advanced annotations, forms, signatures, redaction, OCR, page management and exports.

Build

The project targets Flutter 3.47. file_picker 13.x now exposes FilePicker.pickFiles() and FilePicker.saveFile() directly; the old FilePicker.platform API is no longer used.

CI runs flutter pub get, flutter analyze, flutter test, split APK builds for arm64-v8a, armeabi-v7a and x86_64, and a universal APK build.

The 300 MB minimum is not created with meaningless padding. Larger release size should come from real compatibility engines, fonts, offline OCR/model assets and useful binaries.

CI checkpoint: current Flutter compiler fixes verified in branch.

CI checkpoint: analyzer info messages are non-fatal; errors and warnings remain fatal.

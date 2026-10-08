# Parin Office

Parin Office is a Kotlin + Jetpack Compose Android office suite project.

## Main branch

The main branch now contains:
- A new minimal Parin Office launcher icon.
- PDF rendering/export foundation with pen, text, free-highlight and selective eraser primitives.
- PDF text search/word-selection integration points using the current Android PdfRenderer APIs.
- DOCX/PPTX/XLSX OOXML access and editing foundation.
- Storage Access Framework integration and recent-document persistence.
- Light, flat, Windows-Phone-inspired UI.
- 16-language localization architecture.
- Command/undo-redo infrastructure and document capability model.
- CI and GitHub Release workflow with ABI split configuration for armeabi-v7a, arm64-v8a and x86_64.

## Full Office target

Development is now moving from the foundation toward a full mobile office editor:
- Word: layout engine, styles, sections, tables, lists, images, headers/footers, comments, track changes, fields, pagination and print preview.
- PowerPoint: slide canvas, shapes, connectors, groups, themes, masters, media, tables, charts, transitions and presentation mode.
- Excel: virtualized grid, formulas/evaluation, styling, merged cells, validation, filtering, sorting, freeze panes, charts and print layout.
- PDF: exact text selection/highlighting, annotation object lifecycle, search navigation, forms, signatures, redaction, page organizer and advanced export.
- Shared platform: clipboard, find/replace, accessibility, RTL, autosave, crash recovery, safe document transactions, migrations and versioned data.

The project deliberately uses modular engines so improving one format does not require replacing the application shell or breaking user documents.

## Release safety

Production APK updates must use the same long-lived signing key. Never generate a new production key for every version. CI must only publish a release after the build and package verification steps pass.

## Current status

The repository is being actively expanded. A genuine 100%-feature-equivalent replacement for desktop Microsoft Office is a large engineering program; the current work is implementing that target incrementally rather than claiming unfinished features are already complete.
\nFlutter rebuild CI checkpoint.\n
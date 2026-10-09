# Parin Office — Flutter

Parin Office is an adaptive, **offline-first Android office suite** for phones and tablets. The interface uses a Windows Phone / Metro-inspired visual language: square-cornered cards, compact typography, clear accent blocks and a contextual ribbon inspired by Google Docs.

## Included in this build

- **Metro UI** layout with compact top menus, format-specific ribbons, responsive editing canvas, optional side panel and phone/tablet layouts. Workspace has been removed from the bottom navigation; Home, Recent and Settings remain.
- **128 named color palettes**, grouped and searchable, with persistent Light, Liquid Glass, Dark and true-black AMOLED appearance options.
- Android adaptive icons with a separate pure-white monochrome glyph for Android 13+ themed icons. The asset generator validates that adaptive and monochrome layers remain inside safe bounds.
- 16 selectable locales, explicit RTL direction for Persian, Arabic and Hebrew, searchable settings, accessible contrast and text scaling, optional blue-light overlay, local draft recovery, recent documents and preferences export.
- **Embedded offline Office engine:** DOCX, XLSX and PPTX are parsed, edited, laid out and serialized on the device. No document server, conversion service, login or cloud upload is required for editing.
- **Word (DOCX):** document canvas and rulers, font and size selection, bold/italic/underline/strike, text color/highlight, paragraph alignment, heading styles, lists, tables, hyperlinks, page breaks, footnotes/endnotes, table of contents, review comments, find/replace, spell-check hook, page size/orientation, undo/redo, print and PDF export. The Word side-notes pane is hidden by default.
- **Excel (XLSX):** virtualized spreadsheet canvas, cell selection and formula bar, recalculation, number formats, worksheets, freeze panes, find/replace, chart tools, CSV export, PDF export, undo/redo and formatting options exposed by the engine. Legacy **XLS** continues through the compatibility editor.
- **PowerPoint (PPTX):** slide canvas, editable objects with handles, tables, speaker notes, slideshow controls, object animations, and slide transitions. The ribbon exposes transition effect/direction/duration, manual or timed advance, apply-to-all, animation preset/trigger/direction/duration/delay and animation preview. Availability depends on the engine's support for each OOXML feature.
- **PDF tools:** print via the Android system print dialog; merge multiple PDFs with an option to include the current file; split/extract page ranges; rotate selected pages; add page numbers or watermarks; convert selectable-text PDFs into editable DOCX, XLSX and PPTX. Scanned/image-only PDFs require OCR, which is not included in this offline converter.
- **PDF security tools:** protect a PDF with AES-256, remove an existing password after supplying the valid password, or change the password. Each operation creates a new output instead of silently overwriting the source.
- **Custom fonts:** import licensed `.ttf` or `.otf` files into app-private storage and select the font in Word formatting. Fonts remain on-device.
- **Printing and motion:** Office documents are converted locally to PDF then sent to Android's system print dialog. Ribbon changes and page navigation use short transitions, respecting the global animations setting.
- **Useful Help Center:** searchable guides by Word, Excel, PowerPoint and PDF, including formulas, page layout, slide transitions vs object animations, local saving, passwords and keyboard shortcuts.
- **Settings → About:** GitHub source link, creator credit to P Mashalchian, a note that ChatGPT assisted development, and the project's GPL-3.0 open-source license.

## Compatibility and security notes

The embedded engine is not Microsoft Office or LibreOffice; the degree of fidelity depends on the document features the engine supports. VBA/macros, Power Query/Power Pivot, ActiveX, uncommon formula functions and some vendor-specific extensions are not guaranteed to round-trip exactly. Legacy XLS uses the compatibility editor. Keep a backup of important originals and verify mission-critical files in a full office suite.

PDF password removal and password changes require the current valid password. Protecting a PDF does not recover a lost password. PDF output is a new file; source documents are not automatically overwritten.


PDF merging, page tools and text extraction use Syncfusion's PDF library. Confirm the applicable Syncfusion license before redistributing this build; third-party license terms apply.

The Office editors operate on local file bytes. Cloud sync, server collaboration, OCR and AI document services are not part of the offline editing path. Review third-party package terms before redistributing builds; the PDF-security dependency has its own licensing terms.

## Build and validation

The CI workflow uses Flutter 3.47, generates launcher images, validates adaptive/monochrome layers, creates Android icons, runs analysis and tests, then builds universal and per-ABI APKs.

```bash
python3 tool/generate_launcher_assets.py
python3 tool/test_launcher_assets.py
flutter pub get
dart run flutter_launcher_icons
flutter analyze --no-fatal-infos
flutter test
flutter build apk --release --split-per-abi --no-tree-shake-icons
flutter build apk --release --no-tree-shake-icons
```

APK size may grow as genuine offline editing/rendering code and fonts are bundled; releases are not artificially padded.

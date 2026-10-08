# Parin Office — full implementation program

The target is a production-grade mobile office suite, not a viewer with a text box.

## Platform layer
- Immutable document snapshots and transactional writes.
- Command-based mutations with bounded undo/redo.
- Autosave checkpoints and crash recovery.
- Capability-driven toolbars.
- Accessibility, keyboard navigation and RTL layout.
- Versioned internal document model and migration rules.

## PDF
- Text search and result navigation.
- Exact word/selection highlighting.
- Native annotation objects where supported by Android.
- Ink, free-text, shapes, stamps, links, forms, signatures and redaction.
- Annotation IDs mapped to commands so update/delete/undo are deterministic.
- Thumbnails, page organizer, rotation, crop, continuous scroll and presentation mode.

## Word
- Full paragraph/run model.
- Styles and theme resolution.
- Sections, page geometry, headers, footers and fields.
- Tables, merged cells, lists, images and wrapping.
- Comments, tracked changes, bookmarks, links and references.
- Pagination and print preview.

## PowerPoint
- Slide canvas, zoom/pan and selection model.
- Text boxes, shapes, connectors, groups and alignment.
- Themes, masters and layouts.
- Tables, charts, SVG/images and media.
- Notes, transitions and presentation mode.
- Export to PDF and images.

## Excel
- Virtualized grid and multi-sheet navigation.
- Formula parser/evaluator.
- Formatting, merged cells and conditional formatting.
- Filters, sorting, freeze panes, validation and protection.
- Named ranges, charts and print layout.

## Compatibility
Never silently flatten an editable document. Rasterization/flattening must be an explicit export operation.

## Release safety
Production updates must reuse the same signing identity. versionCode is monotonically increasing and semantic version tags drive releases.

## Verification checkpoint
Compiler-fix validation checkpoint.

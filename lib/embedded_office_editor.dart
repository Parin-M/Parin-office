import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:quds_office_editor/quds_office_editor.dart';
import 'help_center.dart';

/// On-device OOXML editor. All document bytes stay in this process; no
/// network endpoint, conversion service, or account is needed to edit files.
class EmbeddedOfficeEditorPage extends StatefulWidget {
  const EmbeddedOfficeEditorPage({
    super.key,
    required this.bytes,
    required this.fileName,
  });

  final Uint8List bytes;
  final String fileName;

  @override
  State<EmbeddedOfficeEditorPage> createState() => _EmbeddedOfficeEditorPageState();
}

class _EmbeddedOfficeEditorPageState extends State<EmbeddedOfficeEditorPage> {
  WordEditorController? _word;
  SheetEditorController? _sheet;
  SlideEditorController? _slides;
  bool _started = false;
  bool _loading = true;
  bool _saving = false;
  bool _showing = false;
  bool _sidebarOpen = false;
  bool _starred = false;
  String _ribbonTab = 'Home';
  String? _error;
  String _progress = 'Opening document locally…';

  String get _extension => widget.fileName.split('.').last.toLowerCase();
  bool get _isWord => _word != null;
  bool get _isSheet => _sheet != null;
  bool get _isSlides => _slides != null;
  bool get _isWide => MediaQuery.sizeOf(context).width >= 820;

  void _formatRun(String format, [String? value]) {
    final word = _word;
    if (word == null) return;
    word.applyRunFormat((properties) {
      switch (format) {
        case 'bold':
          properties.bold = !properties.bold;
          break;
        case 'italic':
          properties.italic = !properties.italic;
          break;
        case 'underline':
          properties.underline = properties.underline == WmlUnderline.single
              ? WmlUnderline.none
              : WmlUnderline.single;
          break;
        case 'strike':
          properties.strike = !properties.strike;
          break;
        case 'font':
          properties.asciiFont = value ?? 'Arial';
          properties.csFont = value ?? 'Arial';
          break;
        case 'size':
          properties.fontSizeHalfPoints = (int.tryParse(value ?? '') ?? 11) * 2;
          break;
        case 'color':
          properties.color = value ?? '202124';
          break;
        case 'highlight':
          properties.highlight = value;
          break;
      }
    });
  }

  void _alignParagraph(String value) {
    final word = _word;
    if (word == null) return;
    final alignment = switch (value) {
      'center' => WmlJustification.center,
      'right' => WmlJustification.right,
      'justify' => WmlJustification.justify,
      _ => WmlJustification.left,
    };
    word.applyParagraphFormat((paragraph) {
      paragraph.justification = alignment;
    });
  }

  OfficeController? get _controller {
    if (_word != null) return _word;
    if (_sheet != null) return _sheet;
    return _slides;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final direction = Directionality.of(context);
    final theme = Theme.of(context).brightness == Brightness.dark
        ? OfficeTheme.dark
        : OfficeTheme.light;
    final surface = OfficeSurfaceConfig(
      theme: theme,
      textDirection: direction,
      strings: direction == TextDirection.rtl
          ? OfficeStrings.arabic
          : OfficeStrings.english,
      formFactor: MediaQuery.sizeOf(context).width >= 700
          ? OfficeFormFactor.tablet
          : OfficeFormFactor.phone,
      showRulers: true,
      showFormulaBar: true,
      showGridHeaders: true,
      showGridlines: true,
      showSlideHandles: true,
      enableUndo: true,
      autofocus: false,
      interactiveRulers: true,
      showNotesPane: _extension == 'pptx',
    );

    switch (_extension) {
      case 'docx':
        _word = WordEditorController(config: surface);
        break;
      case 'xlsx':
        _sheet = SheetEditorController(config: surface);
        break;
      case 'pptx':
        _slides = SlideEditorController(config: surface);
        break;
      default:
        _error = 'The offline engine supports DOCX, XLSX, and PPTX here. '
            'Legacy XLS files use the compatibility editor.';
        _loading = false;
        return;
    }
    _controller?.addListener(_onControllerChanged);
    unawaited(_loadDocument());
  }

  Future<void> _loadDocument() async {
    try {
      final bytes = widget.bytes;
      if (bytes.isNotEmpty) {
        final progress = (OfficeOpenProgress value) {
          if (!mounted) return;
          setState(() => _progress = value.stage);
        };
        if (_word != null) {
          await _word!.loadBytesAsync(bytes, onProgress: progress);
        } else if (_sheet != null) {
          await _sheet!.loadBytesAsync(bytes, onProgress: progress);
        } else if (_slides != null) {
          await _slides!.loadBytesAsync(bytes, onProgress: progress);
        }
      } else if (_word != null) {
        _word!.insertHeading(text: 'New document');
      }
    } catch (error) {
      _error = 'This file could not be opened by the offline engine.\n$error';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerChanged);
    _word?.dispose();
    _sheet?.dispose();
    _slides?.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final controller = _controller;
    if (controller == null || _saving) return;
    setState(() => _saving = true);
    try {
      final output = await controller.saveBytesAsync();
      final base = widget.fileName.replaceAll(RegExp(r'\.(docx|xlsx|pptx)$', caseSensitive: false), '');
      final fileName = '${_safeName(base)}.$_extension';
      final saved = await FilePicker.saveFile(
        fileName: fileName,
        bytes: output,
        mimeType: switch (_extension) {
          'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          _ => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        },
        dialogTitle: 'Save edited $_extension file',
      );
      if (mounted && saved != null) {
        _controller?.markClean();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved on this device.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save document: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _shareAsPdf() async {
    final controller = _controller;
    if (controller == null || _saving) return;
    setState(() => _saving = true);
    try {
      final officeBytes = await controller.saveBytesAsync();
      final pdfBytes = await Future<Uint8List>.sync(
        () => OfficePdfExport.fromBytes(officeBytes, title: widget.fileName),
      );
      final name = widget.fileName.replaceAll(RegExp(r'\.(docx|xlsx|pptx)$', caseSensitive: false), '');
      await FilePicker.saveFile(
        fileName: '${_safeName(name)}.pdf',
        bytes: pdfBytes,
        mimeType: 'application/pdf',
        dialogTitle: 'Export PDF',
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF export failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _chooseFontOrSize(String title, List<String> options, ValueChanged<String> onPicked) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            for (final option in options)
              ListTile(title: Text(option), onTap: () => Navigator.pop(ctx, option)),
          ],
        ),
      ),
    );
    if (result != null) onPicked(result);
  }

  Future<void> _chooseTextColor({required bool highlight}) async {
    const colors = <(String, String)>[
      ('Black', '202124'), ('Grey', '5F6368'), ('Blue', '1A73E8'),
      ('Red', 'D93025'), ('Orange', 'E37400'), ('Green', '188038'),
      ('Purple', '9334E6'), ('Pink', 'D01884'), ('Yellow', 'FFFF00'),
      ('Light blue', 'D2E3FC'), ('Light green', 'CEEAD6'), ('Remove', ''),
    ];
    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final item in colors)
              ActionChip(
                avatar: item.$2.isEmpty
                    ? const Icon(Icons.format_clear_rounded, size: 16)
                    : CircleAvatar(backgroundColor: Color(int.parse('FF' + item.$2, radix: 16)), radius: 8),
                label: Text(item.$1),
                onPressed: () => Navigator.pop(ctx, item.$2),
              ),
          ]),
        ),
      ),
    );
    if (result == null) return;
    if (highlight) {
      if (result.isEmpty) {
        _word?.applyRunFormat((p) => p.highlight = null);
      } else {
        _word?.applyRunFormat((p) => p.highlight = result);
      }
    } else if (result.isNotEmpty) {
      _word?.applyRunFormat((p) => p.color = result);
    }
  }

  Future<void> _insertHyperlink() async {
    final label = TextEditingController();
    final url = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Insert hyperlink'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: label, decoration: const InputDecoration(labelText: 'Link text')),
          const SizedBox(height: 8),
          TextField(controller: url, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'URL')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Insert')),
        ],
      ),
    );
    if (accepted == true && label.text.trim().isNotEmpty && url.text.trim().isNotEmpty) {
      _word?.insertHyperlink(text: label.text.trim(), target: url.text.trim());
    }
    label.dispose();
    url.dispose();
  }

  Future<void> _addComment() async {
    final text = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add review comment'),
        content: TextField(controller: text, minLines: 2, maxLines: 5, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add comment')),
        ],
      ),
    );
    if (accepted == true && text.text.trim().isNotEmpty) {
      _word?.insertComment(text: text.text.trim());
    }
    text.dispose();
  }

  Future<void> _executeAction(String action) async {
    final controller = _controller;
    if (controller == null) return;
    switch (action) {
      case 'save':
        await _save();
        break;
      case 'pdf':
        await _shareAsPdf();
        break;
      case 'print':
        if (controller.canPrint) controller.requestPrint();
        break;
      case 'undo':
        controller.undo();
        break;
      case 'redo':
        controller.redo();
        break;
      case 'find':
        controller.requestFind();
        break;
      case 'replace':
        controller.requestReplace();
        break;
      case 'selectAll':
        controller.selectAll();
        break;
      case 'toggleSidebar':
        setState(() => _sidebarOpen = !_sidebarOpen);
        break;
      case 'bold':
      case 'italic':
      case 'underline':
      case 'strike':
        _formatRun(action);
        break;
      case 'font':
        await _chooseFontOrSize('Font family', const ['Arial', 'Aptos', 'Calibri', 'Times New Roman', 'Courier New'],
            (v) => _formatRun('font', v));
        break;
      case 'fontSize':
        await _chooseFontOrSize('Font size', const ['8', '9', '10', '11', '12', '14', '16', '18', '20', '24', '28', '36', '48', '72'],
            (v) => _formatRun('size', v));
        break;
      case 'fontColor':
        await _chooseTextColor(highlight: false);
        break;
      case 'highlight':
        await _chooseTextColor(highlight: true);
        break;
      case 'alignLeft':
        _alignParagraph('left');
        break;
      case 'alignCenter':
        _alignParagraph('center');
        break;
      case 'alignRight':
        _alignParagraph('right');
        break;
      case 'justify':
        _alignParagraph('justify');
        break;
      case 'bulletList':
        _word?.toggleList(numbered: false);
        break;
      case 'numberedList':
        _word?.toggleList(numbered: true);
        break;
      case 'heading1':
        _word?.applyHeading(1);
        break;
      case 'heading2':
        _word?.applyHeading(2);
        break;
      case 'table':
        if (_word != null) _word!.insertTable(rows: 3, columns: 3);
        if (_slides != null) _slides!.insertTable(rows: 3, cols: 3);
        break;
      case 'pageBreak':
        _word?.insertPageBreak();
        break;
      case 'footnote':
        _word?.insertFootnote();
        break;
      case 'endnote':
        _word?.insertFootnote(endnote: true);
        break;
      case 'toc':
        _word?.insertTableOfContents();
        break;
      case 'hyperlink':
        await _insertHyperlink();
        break;
      case 'comment':
        await _addComment();
        break;
      case 'pageA4':
        _word?.setPageSize(WmlPageSize.a4());
        break;
      case 'pageLetter':
        _word?.setPageSize(WmlPageSize.letter());
        break;
      case 'landscape':
        _word?.setPageLandscape(true);
        break;
      case 'portrait':
        _word?.setPageLandscape(false);
        break;
      case 'spell':
        controller.requestSpellCheck();
        break;
      case 'freezeRow':
        _sheet?.freezeTopRow();
        break;
      case 'freezeColumn':
        _sheet?.freezeFirstColumn();
        break;
      case 'recalculate':
        _sheet?.recalculateWorkbook();
        break;
      case 'startShow':
        _slides?.startShow(from: _slides!.activeSlideIndex);
        setState(() => _showing = true);
        break;
      case 'previousSlide':
        _slides?.showPrevious();
        break;
      case 'nextSlide':
        _slides?.showNext();
        break;
      case 'toggleHiddenSlide':
        if (_slides != null) _slides!.toggleSlideHidden(_slides!.activeSlideIndex);
        break;
      case 'configureTransition':
        await _configureTransition();
        break;
      case 'configureAnimation':
        await _configureAnimation();
        break;
      case 'previewTransition':
        _slides?.previewTransition();
        break;
      case 'previewAnimations':
        _slides?.previewAnimations();
        break;
      case 'stopShow':
        _slides?.endShow();
        setState(() => _showing = false);
        break;
      case 'help':
        await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => HelpCenterPage(initialFormat: _extension),
        ));
        break;
    }
  }

  List<String> _menuOptions(String menu) => switch (menu) {
    'File' => const ['save', 'pdf', 'print'],
    'Edit' => const ['undo', 'redo', 'find', 'replace', 'selectAll'],
    'View' => const ['toggleSidebar'],
    'Insert' when _isWord => const ['heading1', 'heading2', 'table', 'pageBreak', 'footnote', 'endnote', 'toc', 'hyperlink', 'comment'],
    'Insert' when _isSheet => const ['freezeRow', 'freezeColumn', 'recalculate'],
    'Insert' when _isSlides => const ['table', 'startShow', 'previousSlide', 'nextSlide', 'configureTransition', 'configureAnimation'],
    'Format' when _isWord => const ['bold', 'italic', 'underline', 'strike', 'font', 'fontSize', 'fontColor', 'highlight', 'alignLeft', 'alignCenter', 'alignRight', 'justify', 'bulletList', 'numberedList', 'pageA4', 'pageLetter', 'landscape', 'portrait'],
    'Format' when _isSheet => const ['freezeRow', 'freezeColumn', 'recalculate'],
    'Tools' when _isWord => const ['spell', 'toc', 'comment', 'pdf'],
    'Tools' when _isSheet => const ['recalculate', 'freezeRow', 'freezeColumn', 'pdf'],
    'Tools' when _isSlides => const ['startShow', 'previousSlide', 'nextSlide', 'configureTransition', 'configureAnimation', 'previewTransition', 'previewAnimations', 'toggleHiddenSlide', 'pdf'],
    'Transitions' when _isSlides => const ['configureTransition', 'previewTransition'],
    'Animations' when _isSlides => const ['configureAnimation', 'previewAnimations'],
    'Help' => const ['help'],
    _ => const [],
  };

  String _actionLabel(String action) => switch (action) {
    'save' => 'Save / download',
    'pdf' => 'Export as PDF',
    'print' => 'Print',
    'undo' => 'Undo',
    'redo' => 'Redo',
    'find' => 'Find',
    'replace' => 'Find and replace',
    'selectAll' => 'Select all',
    'toggleSidebar' => _sidebarOpen ? 'Hide side panel' : 'Show side panel',
    'bold' => 'Bold',
    'italic' => 'Italic',
    'underline' => 'Underline',
    'strike' => 'Strikethrough',
    'font' => 'Font family…',
    'fontSize' => 'Font size…',
    'fontColor' => 'Text color…',
    'highlight' => 'Highlight color…',
    'alignLeft' => 'Align left',
    'alignCenter' => 'Align center',
    'alignRight' => 'Align right',
    'justify' => 'Justify',
    'bulletList' => 'Bulleted list',
    'numberedList' => 'Numbered list',
    'heading1' => 'Heading 1',
    'heading2' => 'Heading 2',
    'table' => 'Insert 3 × 3 table',
    'pageBreak' => 'Page break',
    'footnote' => 'Insert footnote',
    'endnote' => 'Insert endnote',
    'toc' => 'Table of contents',
    'hyperlink' => 'Insert hyperlink',
    'comment' => 'Add review comment',
    'pageA4' => 'A4 page size',
    'pageLetter' => 'Letter page size',
    'landscape' => 'Landscape page',
    'portrait' => 'Portrait page',
    'spell' => 'Spell check',
    'freezeRow' => 'Freeze top row',
    'freezeColumn' => 'Freeze first column',
    'recalculate' => 'Recalculate formulas',
    'startShow' => 'Start slideshow',
    'previousSlide' => 'Previous slide',
    'nextSlide' => 'Next slide',
    'configureTransition' => 'Slide transition settings…',
    'configureAnimation' => 'Object animation settings…',
    'previewTransition' => 'Preview transition',
    'previewAnimations' => 'Preview animations',
    'toggleHiddenSlide' => 'Hide / show current slide',
    'stopShow' => 'Stop slideshow',
    _ => action,
  };

  Widget _toolButton(String label, IconData icon, VoidCallback? onPressed, {bool selected = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: IconButton(
          tooltip: label,
          onPressed: onPressed,
          style: IconButton.styleFrom(
            visualDensity: VisualDensity.compact,
            minimumSize: const Size(34, 34),
            padding: const EdgeInsets.all(7),
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            backgroundColor: selected ? Theme.of(context).colorScheme.primary.withAlpha(24) : Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
          ),
          icon: Icon(icon, size: 19),
        ),
      );

  Widget _toolDivider() => Container(
    width: 1,
    height: 23,
    margin: const EdgeInsets.symmetric(horizontal: 5),
    color: Theme.of(context).colorScheme.outlineVariant,
  );

  Widget _dropdownTool(String label, String value, List<String> items, ValueChanged<String> onPicked, {double width = 90}) =>
      PopupMenuButton<String>(
        tooltip: label,
        onSelected: onPicked,
        itemBuilder: (_) => items.map((item) => PopupMenuItem(value: item, child: Text(item))).toList(),
        child: Container(
          height: 31,
          width: width,
          padding: const EdgeInsetsDirectional.only(start: 8, end: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(children: [
            Expanded(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
            const Icon(Icons.arrow_drop_down, size: 17),
          ]),
        ),
      );


  Future<void> _editSpeakerNotes() async {
    final slides = _slides;
    if (slides == null) return;
    final notes = TextEditingController(text: slides.speakerNotes);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Speaker notes'),
        content: TextField(
          controller: notes,
          minLines: 4,
          maxLines: 9,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Notes for the presenter; not shown as slide content.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save notes')),
        ],
      ),
    );
    if (accepted == true) slides.setSpeakerNotes(notes.text);
    notes.dispose();
  }

  Future<void> _configureTransition({bool applyAllDefault = false}) async {
    final controller = _slides;
    if (controller == null) return;
    final current = controller.slide.transition;
    var kind = current.kind;
    var direction = current.direction;
    var duration = current.durationMs.toDouble().clamp(100.0, 2500.0);
    var clickAdvance = current.advanceOnClick;
    var autoAdvance = current.advanceAfterMs != null;
    var advanceAfter = (current.advanceAfterMs ?? 5000).toDouble().clamp(1000.0, 20000.0);
    var applyAll = applyAllDefault;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, refresh) => AlertDialog(
          title: const Text('Slide transitions'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<PmlTransitionKind>(
                  initialValue: kind,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Transition effect'),
                  items: PmlTransitionKind.values.map((value) => DropdownMenuItem(
                    value: value, child: Text(value.name),
                  )).toList(),
                  onChanged: (value) { if (value != null) refresh(() => kind = value); },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<PmlTransitionDir>(
                  initialValue: direction,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Direction'),
                  items: PmlTransitionDir.values.map((value) => DropdownMenuItem(
                    value: value, child: Text(value.name),
                  )).toList(),
                  onChanged: (value) { if (value != null) refresh(() => direction = value); },
                ),
                const SizedBox(height: 12),
                Row(children: [
                  const Expanded(child: Text('Duration')),
                  Text(duration.round().toString() + ' ms'),
                ]),
                Slider(value: duration, min: 100, max: 2500, divisions: 24,
                  onChanged: (value) => refresh(() => duration = value)),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Advance on click'),
                  value: clickAdvance,
                  onChanged: (value) => refresh(() => clickAdvance = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Advance automatically'),
                  value: autoAdvance,
                  onChanged: (value) => refresh(() => autoAdvance = value),
                ),
                if (autoAdvance) ...[
                  Row(children: [
                    const Expanded(child: Text('Wait before next slide')),
                    Text((advanceAfter / 1000).toStringAsFixed(1) + ' s'),
                  ]),
                  Slider(value: advanceAfter, min: 1000, max: 20000, divisions: 19,
                    onChanged: (value) => refresh(() => advanceAfter = value)),
                ],
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Apply to all slides'),
                  value: applyAll,
                  onChanged: (value) => refresh(() => applyAll = value ?? false),
                ),
                const Text('Preview the effect before presenting. Keep motion subtle for dense or formal decks.'),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            OutlinedButton(
              onPressed: () {
                controller.setSlideTransition(PmlSlideTransition(
                  kind: kind,
                  direction: direction,
                  durationMs: duration.round(),
                  advanceOnClick: clickAdvance,
                  advanceAfterMs: autoAdvance ? advanceAfter.round() : null,
                ), applyToAll: applyAll, preview: true);
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Apply and preview'),
            ),
          ],
        ),
      ),
    );
    if (accepted == true && mounted) setState(() {});
  }

  Future<void> _configureAnimation() async {
    final controller = _slides;
    if (controller == null) return;
    if (controller.selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a text box, picture, or shape before adding an animation.')),
      );
      return;
    }
    final existingIndex = controller.selectedAnimationIndex;
    final existing = controller.selectedAnimation;
    var preset = existing?.preset ?? PmlAnimPreset.fade;
    var trigger = existing?.trigger ?? PmlAnimTrigger.onClick;
    var direction = existing?.direction ?? PmlTransitionDir.left;
    var duration = (existing?.durationMs ?? 500).toDouble().clamp(100.0, 4000.0);
    var delay = (existing?.delayMs ?? 0).toDouble().clamp(0.0, 5000.0);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, refresh) => AlertDialog(
          title: Text(existing == null ? 'Add object animation' : 'Edit object animation'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<PmlAnimPreset>(
                  initialValue: preset,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Effect'),
                  items: PmlAnimPreset.values.map((value) => DropdownMenuItem(
                    value: value, child: Text(value.name),
                  )).toList(),
                  onChanged: (value) { if (value != null) refresh(() => preset = value); },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<PmlAnimTrigger>(
                  initialValue: trigger,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Start'),
                  items: PmlAnimTrigger.values.map((value) => DropdownMenuItem(
                    value: value, child: Text(value.name),
                  )).toList(),
                  onChanged: (value) { if (value != null) refresh(() => trigger = value); },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<PmlTransitionDir>(
                  initialValue: direction,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Direction'),
                  items: PmlTransitionDir.values.map((value) => DropdownMenuItem(
                    value: value, child: Text(value.name),
                  )).toList(),
                  onChanged: (value) { if (value != null) refresh(() => direction = value); },
                ),
                const SizedBox(height: 12),
                Row(children: [const Expanded(child: Text('Duration')), Text(duration.round().toString() + ' ms')]),
                Slider(value: duration, min: 100, max: 4000, divisions: 39,
                  onChanged: (value) => refresh(() => duration = value)),
                Row(children: [const Expanded(child: Text('Delay')), Text(delay.round().toString() + ' ms')]),
                Slider(value: delay, min: 0, max: 5000, divisions: 50,
                  onChanged: (value) => refresh(() => delay = value)),
                const Text('On click waits for the presenter; With previous and After previous build a timed sequence.'),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Apply animation')),
          ],
        ),
      ),
    );
    if (accepted != true || !mounted) return;
    if (existingIndex != null) {
      controller.updateShapeAnimation(existingIndex, trigger: trigger, direction: direction,
        durationMs: duration.round(), delayMs: delay.round());
    } else {
      controller.addShapeAnimation(preset, trigger: trigger, direction: direction, durationMs: duration.round());
      final addedIndex = controller.slide.animations.length - 1;
      if (addedIndex >= 0) controller.updateShapeAnimation(addedIndex, delayMs: delay.round());
    }
    setState(() {});
  }

  Widget _ribbonTabs() {
    final tabs = _isWord
        ? const ['Home', 'Insert', 'Layout', 'Review', 'View']
        : _isSheet
            ? const ['Home', 'Insert', 'Formulas', 'Data', 'View']
            : const ['Home', 'Insert', 'Design', 'Transitions', 'Animations', 'Slide show'];
    final theme = Theme.of(context);
    return Container(
      height: 37,
      color: theme.colorScheme.surface,
      alignment: AlignmentDirectional.centerStart,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.only(start: 12, end: 12),
        child: Row(children: [
          for (final tab in tabs)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 5),
              child: InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () => setState(() => _ribbonTab = tab),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: _ribbonTab == tab ? theme.colorScheme.primary.withAlpha(20) : Colors.transparent,
                    border: Border(bottom: BorderSide(
                      color: _ribbonTab == tab ? theme.colorScheme.primary : Colors.transparent,
                      width: 2,
                    )),
                  ),
                  child: Text(tab, style: TextStyle(
                    color: _ribbonTab == tab ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                    fontWeight: _ribbonTab == tab ? FontWeight.w800 : FontWeight.w500,
                    fontSize: 12,
                  )),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  List<Widget> _toolbarActions() {
    final controller = _controller;
    if (controller == null) return const [];
    if (_isSlides && _ribbonTab == 'Transitions') return [
      _toolButton('Choose transition effect and timing', Icons.swap_horiz_rounded, _configureTransition),
      _toolButton('Preview current transition', Icons.preview_rounded, () { _slides?.previewTransition(); setState(() {}); }),
      _toolButton('Apply transition to all slides', Icons.library_add_check_outlined, () => _configureTransition(applyAllDefault: true)),
    ];
    if (_isSlides && _ribbonTab == 'Animations') return [
      _toolButton('Add or edit selected object animation', Icons.animation_rounded, _configureAnimation),
      _toolButton('Preview object animations', Icons.play_circle_outline_rounded, () { _slides?.previewAnimations(); setState(() {}); }),
      _toolButton('Remove selected animation', Icons.delete_outline_rounded, () {
        final index = _slides?.selectedAnimationIndex;
        if (index != null) { _slides?.removeShapeAnimation(index); setState(() {}); }
      }),
      _toolButton('Find an object', Icons.search_rounded, () => _executeAction('find')),
    ];
    if (_isSlides && _ribbonTab == 'Slide show') return [
      _toolButton('Start slide show', Icons.slideshow_rounded, () => _executeAction('startShow')),
      _toolButton('Previous animation or slide', Icons.skip_previous_rounded, () => _executeAction('previousSlide')),
      _toolButton('Next animation or slide', Icons.skip_next_rounded, () => _executeAction('nextSlide')),
      _toolButton('Hide/show current slide', Icons.visibility_off_outlined, () => _executeAction('toggleHiddenSlide')),
      _toolButton('Stop slide show', Icons.stop_circle_outlined, () => _executeAction('stopShow')),
    ];
    if (_isSlides && _ribbonTab == 'Design') return [
      _dropdownTool('Slide background', 'Choose color', const ['FFFFFF', '101426', 'EAF1FF', 'E7F7F1', 'FFF4E3', 'F8EAF4'],
        (hex) { _slides?.applyMasterBackground(hex); setState(() {}); }, width: 140),
      _toolButton('Preview transition', Icons.preview_rounded, () => _slides?.previewTransition()),
      _toolButton('Transition settings', Icons.swap_horiz_rounded, _configureTransition),
    ];
    if (_isSlides && _ribbonTab == 'Insert') return [
      _toolButton('Insert 3 × 3 table on slide', Icons.table_chart_outlined, () => _slides?.insertTable(rows: 3, cols: 3)),
      _toolButton('Find in presentation', Icons.search_rounded, () => _executeAction('find')),
      _toolButton('Add animation', Icons.animation_rounded, _configureAnimation),
      _toolButton('Edit speaker notes', Icons.notes_rounded, _editSpeakerNotes),
    ];
    if (_isWord && _ribbonTab == 'Insert') return [
      _toolButton('Insert table', Icons.table_chart_outlined, () => _executeAction('table')),
      _toolButton('Insert page break', Icons.insert_page_break_outlined, () => _executeAction('pageBreak')),
      _toolButton('Insert footnote', Icons.notes_rounded, () => _executeAction('footnote')),
      _toolButton('Insert endnote', Icons.note_add_outlined, () => _executeAction('endnote')),
      _toolButton('Table of contents', Icons.format_list_numbered_rounded, () => _executeAction('toc')),
      _toolButton('Hyperlink', Icons.link_rounded, () => _executeAction('hyperlink')),
      _toolButton('Review comment', Icons.comment_outlined, () => _executeAction('comment')),
    ];
    if (_isWord && _ribbonTab == 'Layout') return [
      _toolButton('A4 page size', Icons.description_outlined, () => _executeAction('pageA4')),
      _toolButton('US Letter page size', Icons.article_outlined, () => _executeAction('pageLetter')),
      _toolButton('Landscape page', Icons.stay_current_landscape_outlined, () => _executeAction('landscape')),
      _toolButton('Portrait page', Icons.stay_current_portrait_outlined, () => _executeAction('portrait')),
      _toolButton('Table of contents', Icons.format_list_numbered_rounded, () => _executeAction('toc')),
    ];
    if (_isWord && _ribbonTab == 'Review') return [
      _toolButton('Spell check', Icons.spellcheck_rounded, () => _executeAction('spell')),
      _toolButton('Add comment', Icons.comment_outlined, () => _executeAction('comment')),
      _toolButton('Find', Icons.search_rounded, () => _executeAction('find')),
      _toolButton('Find and replace', Icons.find_replace_rounded, () => _executeAction('replace')),
    ];
    if (_isWord && _ribbonTab == 'View') return [
      _toolButton('Show/hide document outline', Icons.view_sidebar_outlined, () => _executeAction('toggleSidebar')),
      _toolButton('Select all', Icons.select_all_rounded, () => _executeAction('selectAll')),
      _toolButton('Help for Word', Icons.help_outline_rounded, () => _executeAction('help')),
    ];
    if (_isSheet && _ribbonTab != 'Home') return [
      _toolButton('Recalculate formulas', Icons.calculate_outlined, () => _executeAction('recalculate')),
      _toolButton('Freeze top row', Icons.vertical_align_top_rounded, () => _executeAction('freezeRow')),
      _toolButton('Freeze first column', Icons.vertical_align_center_rounded, () => _executeAction('freezeColumn')),
      _toolButton('Find', Icons.search_rounded, () => _executeAction('find')),
      _toolButton('Find and replace', Icons.find_replace_rounded, () => _executeAction('replace')),
      _toolButton('Select all cells', Icons.select_all_rounded, () => _executeAction('selectAll')),
      _toolButton('Export to PDF', Icons.picture_as_pdf_outlined, () => _executeAction('pdf')),
      _toolButton('Help for Excel', Icons.help_outline_rounded, () => _executeAction('help')),
    ];
    final result = <Widget>[
      _toolButton('Undo', Icons.undo_rounded, controller.canUndo ? () => _executeAction('undo') : null),
      _toolButton('Redo', Icons.redo_rounded, controller.canRedo ? () => _executeAction('redo') : null),
      _toolButton('Print', Icons.print_outlined, controller.canPrint ? () => _executeAction('print') : null),
      _toolDivider(),
      _toolButton('Find', Icons.search_rounded, () => _executeAction('find')),
      _toolButton('Replace', Icons.find_replace_rounded, () => _executeAction('replace')),
    ];
    if (_word != null) {
      result.addAll([
        _toolDivider(),
        _dropdownTool('Font family', _word!.activeRunProps.asciiFont,
          const ['Arial', 'Aptos', 'Calibri', 'Times New Roman', 'Courier New'],
          (v) => _formatRun('font', v), width: 118),
        _dropdownTool('Font size', _word!.activeRunProps.fontSizePoints.round().toString(),
          const ['8', '9', '10', '11', '12', '14', '16', '18', '20', '24', '28', '36', '48', '72'],
          (v) => _formatRun('size', v), width: 58),
        _toolDivider(),
        _toolButton('Bold', Icons.format_bold_rounded, () => _formatRun('bold'), selected: _word!.activeRunProps.bold),
        _toolButton('Italic', Icons.format_italic_rounded, () => _formatRun('italic'), selected: _word!.activeRunProps.italic),
        _toolButton('Underline', Icons.format_underlined_rounded, () => _formatRun('underline'), selected: _word!.activeRunProps.underline != WmlUnderline.none),
        _toolButton('Strikethrough', Icons.strikethrough_s_rounded, () => _formatRun('strike'), selected: _word!.activeRunProps.strike),
        _toolDivider(),
        _toolButton('Text color', Icons.format_color_text_rounded, () => _chooseTextColor(highlight: false)),
        _toolButton('Highlight color', Icons.border_color_rounded, () => _chooseTextColor(highlight: true)),
        _dropdownTool('Paragraph style', 'Normal / heading', const ['Normal', 'Heading 1', 'Heading 2', 'Heading 3'], (v) {
          if (v == 'Normal') {
            _word?.applyStyle('Normal');
          } else {
            _word?.applyHeading(int.parse(v.substring('Heading '.length)));
          }
        }, width: 126),
        PopupMenuButton<String>(
          tooltip: 'Paragraph alignment',
          onSelected: (v) => _alignParagraph(v),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'left', child: Text('Align left')),
            PopupMenuItem(value: 'center', child: Text('Center')),
            PopupMenuItem(value: 'right', child: Text('Align right')),
            PopupMenuItem(value: 'justify', child: Text('Justify')),
          ],
          child: const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.format_align_left_rounded, size: 20)),
        ),
        _toolButton('Bulleted list', Icons.format_list_bulleted_rounded, () => _word?.toggleList(numbered: false)),
        _toolButton('Numbered list', Icons.format_list_numbered_rounded, () => _word?.toggleList(numbered: true)),
        _toolDivider(),
        _toolButton('Insert table', Icons.table_chart_outlined, () => _executeAction('table')),
        _toolButton('Page break', Icons.insert_page_break_outlined, () => _executeAction('pageBreak')),
        _toolButton('Hyperlink', Icons.link_rounded, () => _executeAction('hyperlink')),
      ]);
    } else if (_sheet != null) {
      result.addAll([
        _toolDivider(),
        _toolButton('Freeze top row', Icons.vertical_align_top_rounded, () => _executeAction('freezeRow')),
        _toolButton('Freeze first column', Icons.vertical_align_center_rounded, () => _executeAction('freezeColumn')),
        _toolButton('Recalculate formulas', Icons.calculate_outlined, () => _executeAction('recalculate')),
      ]);
    } else if (_slides != null) {
      result.addAll([
        _toolDivider(),
        _toolButton('Previous slide', Icons.skip_previous_rounded, () => _executeAction('previousSlide')),
        _toolButton('Next slide', Icons.skip_next_rounded, () => _executeAction('nextSlide')),
        _toolButton(_showing ? 'Next slide' : 'Start slideshow', _showing ? Icons.skip_next_rounded : Icons.slideshow_rounded,
          () => _executeAction(_showing ? 'nextSlide' : 'startShow')),
      ]);
    }
    return result;
  }

  Widget _header() {
    final theme = Theme.of(context);
    final accent = _isWord ? const Color(0xFF4285F4) : _isSheet ? const Color(0xFF188038) : const Color(0xFFE37400);
    final icon = _isWord ? Icons.description_outlined : _isSheet ? Icons.grid_on_rounded : Icons.slideshow_rounded;
    return Container(
      height: 59,
      padding: const EdgeInsetsDirectional.fromSTEB(8, 3, 10, 3),
      color: theme.colorScheme.surface,
      child: Row(children: [
        _toolButton('Back', Icons.arrow_back_rounded, () => Navigator.of(context).maybePop()),
        Container(
          width: 37, height: 41,
          decoration: BoxDecoration(color: accent.withAlpha(25), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: accent, size: 26),
        ),
        const SizedBox(width: 9),
        Expanded(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.fileName, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500)),
            Row(children: [
              Icon(_saving ? Icons.sync_rounded : (_controller?.isDirty == true ? Icons.edit_outlined : Icons.cloud_done_outlined),
                size: 13, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Flexible(child: Text(
                _saving ? 'Saving…' : (_controller?.isDirty == true ? 'Unsaved changes' : 'Saved on this device'),
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              )),
            ]),
          ],
        )),
        _toolButton(_starred ? 'Remove star' : 'Star document', _starred ? Icons.star_rounded : Icons.star_border_rounded,
          () => setState(() => _starred = !_starred), selected: _starred),
        if (_isWide)
          OutlinedButton.icon(
            onPressed: _loading || _saving || _error != null ? null : _shareAsPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: const Text('PDF'),
            style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 10)),
          ),
        const SizedBox(width: 5),
        FilledButton.icon(
          onPressed: _loading || _saving || _error != null ? null : _save,
          icon: _saving ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save_outlined, size: 18),
          label: Text(_isWide ? 'Save' : ''),
          style: FilledButton.styleFrom(minimumSize: const Size(40, 37), padding: const EdgeInsets.symmetric(horizontal: 9), visualDensity: VisualDensity.compact),
        ),
      ]),
    );
  }

  Widget _menuBar() {
    final menus = <String>['File', 'Edit', 'View', 'Insert', 'Format', 'Tools', 'Help'];
    return Container(
      height: 34,
      color: Theme.of(context).colorScheme.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.only(start: 50, end: 10),
        child: Row(children: menus.map((menu) => PopupMenuButton<String>(
          tooltip: menu,
          onSelected: (value) => unawaited(_executeAction(value)),
          itemBuilder: (_) => _menuOptions(menu).map((action) => PopupMenuItem<String>(
            value: action, child: Text(_actionLabel(action)),
          )).toList(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
            child: Text(menu, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface)),
          ),
        )).toList()),
      ),
    );
  }

  Widget _toolbar() => Container(
    height: 48,
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
    ),
    child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: _toolbarActions())),
  );

  Widget _sideEntry(String label, IconData icon, VoidCallback action) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: action,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(children: [
              Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
              const Icon(Icons.chevron_right_rounded, size: 17),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _sidebar() {
    final theme = Theme.of(context);
    final title = _isWord ? 'Document outline' : _isSheet ? 'Sheet tools' : 'Presentation tools';
    return Container(
      width: 224,
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 15, 8, 10),
          child: Row(children: [
            Expanded(child: Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
            _toolButton('Hide side panel', Icons.chevron_left_rounded, () => setState(() => _sidebarOpen = false)),
          ]),
        ),
        if (_isWord) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Text('Use heading styles to organize this document.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.4)),
          ),
          const SizedBox(height: 12),
          _sideEntry('Find in document', Icons.search_rounded, () => _executeAction('find')),
          _sideEntry('Heading 1', Icons.title_rounded, () => _executeAction('heading1')),
          _sideEntry('Insert table', Icons.table_chart_outlined, () => _executeAction('table')),
          _sideEntry('Page size · A4', Icons.stay_current_portrait_outlined, () => _executeAction('pageA4')),
          _sideEntry('Add review comment', Icons.comment_outlined, () => _executeAction('comment')),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              _word!.laidOut.pages.length.toString() + ' page(s)',
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ] else if (_isSheet) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Text('Workbook tools', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          const SizedBox(height: 12),
          _sideEntry('Recalculate formulas', Icons.calculate_outlined, () => _executeAction('recalculate')),
          _sideEntry('Freeze top row', Icons.vertical_align_top_rounded, () => _executeAction('freezeRow')),
          _sideEntry('Freeze first column', Icons.vertical_align_center_rounded, () => _executeAction('freezeColumn')),
          _sideEntry('Find in workbook', Icons.search_rounded, () => _executeAction('find')),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text('Cell ' + _sheet!.selectionAddress, style: theme.textTheme.labelSmall),
          ),
        ] else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Text('Slide canvas and thumbnails are available in the workspace.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.4)),
          ),
          const SizedBox(height: 12),
          _sideEntry('Start slideshow', Icons.slideshow_rounded, () => _executeAction('startShow')),
          _sideEntry('Previous slide', Icons.skip_previous_rounded, () => _executeAction('previousSlide')),
          _sideEntry('Next slide', Icons.skip_next_rounded, () => _executeAction('nextSlide')),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text('Slide ' + (_slides!.activeSlideIndex + 1).toString(), style: theme.textTheme.labelSmall),
          ),
        ],
      ]),
    );
  }

  Widget _documentSurface() {
    if (_word != null) {
      return QudsWordEditor(
        controller: _word!,
        toolbarBuilder: (context, controller) => const SizedBox.shrink(),
        statusBarBuilder: (context, controller) => const SizedBox.shrink(),
      );
    }
    if (_sheet != null) {
      return QudsSheetEditor(controller: _sheet!, frozenRows: 0, frozenCols: 0);
    }
    if (_slides != null) {
      return QudsSlideEditor(controller: _slides!);
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      body: SafeArea(
        child: Column(children: [
          _header(),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          _menuBar(),
          _ribbonTabs(),
          _toolbar(),
          Expanded(
            child: _error != null
                ? Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.description_outlined, size: 52),
                          const SizedBox(height: 14),
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          const Text(
                            'No upload or server conversion was attempted. The original file has not been overwritten.',
                            textAlign: TextAlign.center,
                          ),
                        ]),
                      ),
                    ),
                  )
                : _loading
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 14),
                        Text(_progress),
                      ]))
                    : Row(children: [
                        if (_sidebarOpen && _isWide) _sidebar(),
                        Expanded(child: Container(
                          color: theme.colorScheme.surfaceContainerLowest,
                          child: _documentSurface(),
                        )),
                      ]),
          ),
          Container(
            height: 29,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
            ),
            child: Row(children: [
              if (!_sidebarOpen && _isWide)
                _toolButton('Show side panel', Icons.menu_open_rounded, () => setState(() => _sidebarOpen = true)),
              Icon(controller?.isDirty == true ? Icons.edit_outlined : Icons.cloud_done_outlined,
                  size: 14, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(child: Text(
                [
                  controller?.isDirty == true ? 'Unsaved changes' : 'All changes saved on device',
                  if (_isWord) 'Word',
                  if (_isSheet) 'Sheet ' + (_sheet!.activeSheetIndex + 1).toString() + ' · ' + _sheet!.selectionAddress,
                  if (_isSlides) 'Slide ' + (_slides!.activeSlideIndex + 1).toString(),
                  'Offline engine',
                ].join('   •   '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              )),
            ]),
          ),
        ]),
      ),
    );
  }
}

String _safeName(String value) {
  final cleaned = value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();
  return cleaned.isEmpty ? 'Parin-Office' : cleaned;
}
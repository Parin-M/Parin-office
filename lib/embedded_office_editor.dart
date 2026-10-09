import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:quds_office_editor/quds_office_editor.dart';

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
  String? _error;
  String _progress = 'Opening document locally…';
  late final TextEditingController _documentTitle;
  bool _outlineOpen = true;

  @override
  void initState() {
    super.initState();
    _documentTitle = TextEditingController(
      text: widget.fileName.replaceFirst(RegExp(r'\.[^.]+$'), ''),
    );
  }

  String get _extension => widget.fileName.split('.').last.toLowerCase();

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
      showNotesPane: true,
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
    _documentTitle.dispose();
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
      final base = _documentTitle.text.trim().isEmpty
          ? widget.fileName.replaceAll(RegExp(r'\.(docx|xlsx|pptx)$', caseSensitive: false), '')
          : _documentTitle.text.trim();
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

  void _action(String action) {
    final controller = _controller;
    if (controller == null) return;
    switch (action) {
      case 'find':
        controller.requestFind();
        break;
      case 'replace':
        controller.requestReplace();
        break;
      case 'spell':
        controller.requestSpellCheck();
        break;
      case 'select':
        controller.selectAll();
        break;
      case 'print':
        controller.requestPrint();
        break;
      case 'undo':
        controller.undo();
        break;
      case 'redo':
        controller.redo();
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
      case 'present':
        _slides?.startShow(from: _slides!.activeSlideIndex);
        setState(() => _showing = true);
        break;
      case 'previous':
        _slides?.showPrevious();
        break;
      case 'next':
        _slides?.showNext();
        break;
      case 'stopShow':
        _slides?.endShow();
        setState(() => _showing = false);
        break;
    }
  }

  List<Widget> _toolbarActions() {
    final controller = _controller;
    if (controller == null) return const [];
    final common = <Widget>[
      IconButton(
        tooltip: 'Undo',
        onPressed: controller.canUndo ? () => _action('undo') : null,
        icon: const Icon(Icons.undo_rounded),
      ),
      IconButton(
        tooltip: 'Redo',
        onPressed: controller.canRedo ? () => _action('redo') : null,
        icon: const Icon(Icons.redo_rounded),
      ),
      IconButton(
        tooltip: 'Find',
        onPressed: controller.canFind ? () => _action('find') : null,
        icon: const Icon(Icons.search_rounded),
      ),
      IconButton(
        tooltip: 'Replace',
        onPressed: () => _action('replace'),
        icon: const Icon(Icons.find_replace_rounded),
      ),
    ];
    if (_word != null) {
      common.add(IconButton(
        tooltip: 'Spell check',
        onPressed: () => _action('spell'),
        icon: const Icon(Icons.spellcheck_rounded),
      ));
    }
    if (_sheet != null) {
      common.addAll([
        IconButton(
          tooltip: 'Freeze top row',
          onPressed: () => _action('freezeRow'),
          icon: const Icon(Icons.vertical_align_top_rounded),
        ),
        IconButton(
          tooltip: 'Freeze first column',
          onPressed: () => _action('freezeColumn'),
          icon: const Icon(Icons.vertical_align_center_rounded),
        ),
        IconButton(
          tooltip: 'Recalculate workbook',
          onPressed: () => _action('recalculate'),
          icon: const Icon(Icons.calculate_outlined),
        ),
      ]);
    }
    if (_slides != null) {
      common.addAll([
        if (!_showing)
          IconButton(
            tooltip: 'Start slideshow',
            onPressed: () => _action('present'),
            icon: const Icon(Icons.slideshow_rounded),
          )
        else ...[
          IconButton(
            tooltip: 'Previous animation or slide',
            onPressed: () => _action('previous'),
            icon: const Icon(Icons.skip_previous_rounded),
          ),
          IconButton(
            tooltip: 'Next animation or slide',
            onPressed: () => _action('next'),
            icon: const Icon(Icons.skip_next_rounded),
          ),
          IconButton(
            tooltip: 'Exit slideshow',
            onPressed: () => _action('stopShow'),
            icon: const Icon(Icons.stop_circle_outlined),
          ),
        ],
      ]);
    }
    return common;
  }

  Widget _menuIcon(IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 18), const SizedBox(width: 12), Text(label)],
      );

  List<PopupMenuEntry<String>> _menuItems(String menu) {
    final items = <PopupMenuEntry<String>>[];
    void add(String key, IconData icon, String label) {
      items.add(PopupMenuItem<String>(value: key, child: _menuIcon(icon, label)));
    }
    switch (menu) {
      case 'File':
        add('save', Icons.save_outlined, 'Save a copy');
        add('pdf', Icons.picture_as_pdf_outlined, 'Export as PDF');
        add('print', Icons.print_outlined, 'Print');
        items.add(const PopupMenuDivider());
        add('about', Icons.info_outline, 'Document and engine info');
        break;
      case 'Edit':
        add('undo', Icons.undo_rounded, 'Undo');
        add('redo', Icons.redo_rounded, 'Redo');
        items.add(const PopupMenuDivider());
        add('find', Icons.search_rounded, 'Find');
        add('replace', Icons.find_replace_rounded, 'Find and replace');
        add('select', Icons.select_all_rounded, 'Select all');
        break;
      case 'View':
        add('outline', Icons.segment_rounded, _outlineOpen ? 'Hide document panel' : 'Show document panel');
        add('print', Icons.print_outlined, 'Print layout');
        if (_sheet != null) {
          add('freezeTop', Icons.vertical_align_top_rounded, 'Freeze top row');
          add('freezeColumn', Icons.vertical_align_center_rounded, 'Freeze first column');
        }
        if (_slides != null) add('present', Icons.slideshow_rounded, 'Start presentation');
        break;
      case 'Insert':
        if (_word != null) {
          add('insertTable', Icons.table_chart_outlined, 'Insert 3 × 3 table');
          add('pageBreak', Icons.insert_page_break_outlined, 'Page break');
          add('sectionBreak', Icons.view_agenda_outlined, 'Section break');
          add('toc', Icons.format_list_numbered_rounded, 'Table of contents');
        } else if (_sheet != null) {
          add('insertRow', Icons.add_rounded, 'Insert row below');
          add('insertColumn', Icons.view_column_outlined, 'Insert column');
          add('insertTable', Icons.table_rows_outlined, 'Create table from selection');
          add('sheetComment', Icons.comment_outlined, 'Add cell comment');
        } else if (_slides != null) {
          add('insertTable', Icons.table_chart_outlined, 'Insert table');
          add('slideSection', Icons.view_agenda_outlined, 'Add slide section');
        }
        break;
      case 'Format':
        if (_word != null) {
          add('toc', Icons.format_list_numbered_rounded, 'Insert table of contents');
          add('pageBreak', Icons.insert_page_break_outlined, 'Page break');
          add('sectionBreak', Icons.view_agenda_outlined, 'Section break');
        } else if (_sheet != null) {
          add('merge', Icons.table_rows_outlined, 'Merge and center');
          add('sortAsc', Icons.arrow_upward_rounded, 'Sort ascending');
          add('sortDesc', Icons.arrow_downward_rounded, 'Sort descending');
          add('removeDuplicates', Icons.filter_alt_off_outlined, 'Remove duplicates');
          add('rtlSheet', Icons.format_textdirection_r_to_l, 'Toggle sheet direction');
        } else if (_slides != null) {
          add('masterBackground', Icons.palette_outlined, 'Set master background to white');
        }
        break;
      case 'Tools':
        add('find', Icons.search_rounded, 'Find');
        add('replace', Icons.find_replace_rounded, 'Find and replace');
        if (_word != null) add('spell', Icons.spellcheck_rounded, 'Spell check');
        if (_sheet != null) {
          add('recalculate', Icons.calculate_outlined, 'Recalculate formulas');
          add('removeDuplicates', Icons.filter_alt_off_outlined, 'Remove duplicates in selection');
          add('sheetComment', Icons.comment_outlined, 'Edit cell comment');
        }
        if (_slides != null) add('present', Icons.slideshow_rounded, 'Start presentation');
        break;
      case 'Extensions':
        add('about', Icons.offline_bolt_outlined, 'Offline engine and capabilities');
        break;
      case 'Help':
        add('about', Icons.help_outline_rounded, 'Keyboard and feature guide');
        add('repairInfo', Icons.build_outlined, 'File compatibility notes');
        break;
    }
    return items;
  }

  Widget _menuBar() {
    const menus = <String>['File', 'Edit', 'View', 'Insert', 'Format', 'Tools', 'Extensions', 'Help'];
    return Container(
      height: 38,
      padding: const EdgeInsetsDirectional.only(start: 52, end: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFFFF),
        border: Border(bottom: BorderSide(color: Color(0xFFE3E7ED))),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final menu in menus)
            PopupMenuButton<String>(
              tooltip: menu,
              padding: EdgeInsets.zero,
              onSelected: _runCommand,
              itemBuilder: (_) => _menuItems(menu),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                child: Text(menu, style: const TextStyle(color: Color(0xFF3C4043), fontSize: 13, fontWeight: FontWeight.w500)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _toolButton(String label, IconData icon, String command, {bool enabled = true}) {
    return Tooltip(
      message: label,
      child: TextButton(
        onPressed: enabled && !_loading && _error == null ? () => _runCommand(command) : null,
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF3C4043),
          disabledForegroundColor: const Color(0xFFADB4BD),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          minimumSize: const Size(38, 38),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [Icon(icon, size: 18), const SizedBox(width: 5), Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))],
        ),
      ),
    );
  }

  Widget _toolbar() {
    final items = <Widget>[
      _toolButton('Undo', Icons.undo_rounded, 'undo', enabled: _controller?.canUndo == true),
      _toolButton('Redo', Icons.redo_rounded, 'redo', enabled: _controller?.canRedo == true),
      _toolButton('Print', Icons.print_outlined, 'print'),
      const _RibbonDivider(),
      _toolButton('Find', Icons.search_rounded, 'find'),
      _toolButton('Replace', Icons.find_replace_rounded, 'replace'),
      const _RibbonDivider(),
      if (_word != null) ...[
        _toolButton('Table', Icons.table_chart_outlined, 'insertTable'),
        _toolButton('Page break', Icons.insert_page_break_outlined, 'pageBreak'),
        _toolButton('Contents', Icons.format_list_numbered_rounded, 'toc'),
        _toolButton('Spell check', Icons.spellcheck_rounded, 'spell'),
      ],
      if (_sheet != null) ...[
        _toolButton('Row +', Icons.add_rounded, 'insertRow'),
        _toolButton('Column +', Icons.view_column_outlined, 'insertColumn'),
        _toolButton('Merge', Icons.table_rows_outlined, 'merge'),
        _toolButton('Freeze row', Icons.vertical_align_top_rounded, 'freezeTop'),
        _toolButton('Freeze col.', Icons.vertical_align_center_rounded, 'freezeColumn'),
        _toolButton('Recalculate', Icons.calculate_outlined, 'recalculate'),
      ],
      if (_slides != null) ...[
        _toolButton('Table', Icons.table_chart_outlined, 'insertTable'),
        _toolButton('Sections', Icons.view_agenda_outlined, 'slideSection'),
        _toolButton('Present', Icons.slideshow_rounded, 'present'),
      ],
      const _RibbonDivider(),
      _toolButton(_outlineOpen ? 'Hide panel' : 'Outline', Icons.segment_rounded, 'outline'),
      _toolButton('PDF', Icons.picture_as_pdf_outlined, 'pdf'),
    ];
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FA),
        border: Border(bottom: BorderSide(color: Color(0xFFE3E7ED))),
      ),
      child: ListView(scrollDirection: Axis.horizontal, children: items),
    );
  }

  Widget _documentHeader(BuildContext context) {
    final (IconData icon, Color accent) = switch (_extension) {
      'docx' => (Icons.article_outlined, const Color(0xFF4285F4)),
      'xlsx' => (Icons.table_chart_outlined, const Color(0xFF188038)),
      'pptx' => (Icons.slideshow_outlined, const Color(0xFFD56A1D)),
      _ => (Icons.description_outlined, const Color(0xFF5F6368)),
    };
    return Container(
      height: 67,
      padding: const EdgeInsetsDirectional.fromSTEB(12, 7, 14, 6),
      color: const Color(0xFFFFFFFF),
      child: Row(
        children: [
          IconButton(tooltip: 'Back', onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF5F6368))),
          Container(
            width: 40,
            height: 44,
            decoration: BoxDecoration(color: accent.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: accent, size: 25),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _documentTitle,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontSize: 17, color: Color(0xFF202124)),
                    decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.only(top: 3, bottom: 4), border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, filled: false),
                  ),
                ),
                Row(children: [
                  Icon(_controller?.isDirty == true ? Icons.edit_outlined : Icons.offline_pin_outlined, size: 12,
                      color: _controller?.isDirty == true ? const Color(0xFFB06000) : const Color(0xFF188038)),
                  const SizedBox(width: 4),
                  Text(_controller?.isDirty == true ? 'Unsaved changes · save locally' : 'Saved locally · offline',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF5F6368))),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(tooltip: 'Undo', onPressed: _controller?.canUndo == true ? () => _runCommand('undo') : null, icon: const Icon(Icons.undo_rounded, color: Color(0xFF5F6368))),
          IconButton(tooltip: 'Redo', onPressed: _controller?.canRedo == true ? () => _runCommand('redo') : null, icon: const Icon(Icons.redo_rounded, color: Color(0xFF5F6368))),
          const SizedBox(width: 6),
          OutlinedButton.icon(
            onPressed: _loading || _saving || _error != null ? null : () => _runCommand('pdf'),
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 17),
            label: const Text('Export'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF3C4043), side: const BorderSide(color: Color(0xFFDADCE0)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _loading || _saving || _error != null ? null : () => _runCommand('save'),
            icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined, size: 17),
            label: const Text('Save'),
            style: FilledButton.styleFrom(
              foregroundColor: Colors.white, backgroundColor: const Color(0xFF1A73E8),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _outlinePanel(BuildContext context) {
    final type = _word != null ? 'Document outline' : _sheet != null ? 'Workbook' : 'Slides';
    return Container(
      width: 248,
      decoration: const BoxDecoration(color: Color(0xFFF8F9FA), border: Border(right: BorderSide(color: Color(0xFFE3E7ED)))),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(type, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF3C4043)))),
              IconButton(visualDensity: VisualDensity.compact, tooltip: 'Hide panel', onPressed: () => setState(() => _outlineOpen = false),
                  icon: const Icon(Icons.chevron_left_rounded, size: 20, color: Color(0xFF5F6368))),
            ]),
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFE3E7ED)),
            const SizedBox(height: 14),
            if (_word != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFDADCE0)), borderRadius: BorderRadius.circular(12)),
                child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.segment_rounded, color: Color(0xFF5F6368), size: 19),
                  SizedBox(height: 10),
                  Text('Document outline', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF3C4043), fontSize: 12)),
                  SizedBox(height: 5),
                  Text('Headings are organized here as you structure your document.', style: TextStyle(color: Color(0xFF5F6368), fontSize: 12, height: 1.4)),
                ]),
              ),
              const SizedBox(height: 10),
              _sidebarAction(Icons.format_list_numbered_rounded, 'Insert table of contents', 'toc'),
              _sidebarAction(Icons.table_chart_outlined, 'Insert table', 'insertTable'),
              _sidebarAction(Icons.insert_page_break_outlined, 'Page break', 'pageBreak'),
            ],
            if (_sheet != null) ...[
              _sidebarMetric('Selected cell', _sheet!.selectionAddress, Icons.grid_on_rounded),
              const SizedBox(height: 10),
              _sidebarAction(Icons.vertical_align_top_rounded, 'Freeze top row', 'freezeTop'),
              _sidebarAction(Icons.vertical_align_center_rounded, 'Freeze first column', 'freezeColumn'),
              _sidebarAction(Icons.table_rows_outlined, 'Merge and center', 'merge'),
              _sidebarAction(Icons.calculate_outlined, 'Recalculate formulas', 'recalculate'),
              _sidebarAction(Icons.filter_alt_off_outlined, 'Remove duplicates', 'removeDuplicates'),
            ],
            if (_slides != null) ...[
              _sidebarMetric('Current slide', (_slides!.activeSlideIndex + 1).toString(), Icons.slideshow_rounded),
              const SizedBox(height: 10),
              _sidebarAction(Icons.slideshow_rounded, 'Start presentation', 'present'),
              _sidebarAction(Icons.table_chart_outlined, 'Insert table', 'insertTable'),
              _sidebarAction(Icons.view_agenda_outlined, 'Add slide section', 'slideSection'),
            ],
            const Spacer(),
            const Text('Everything is processed on this device. No file upload or account required.',
                style: TextStyle(color: Color(0xFF5F6368), fontSize: 11, height: 1.4)),
          ],
        ),
      ),
    );
  }

  Widget _sidebarMetric(String label, String value, IconData icon) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFDADCE0)), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(icon, color: const Color(0xFF5F6368), size: 19),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(color: Color(0xFF5F6368), fontSize: 12))),
          Text(value, style: const TextStyle(color: Color(0xFF202124), fontWeight: FontWeight.w700, fontSize: 12)),
        ]),
      );

  Widget _sidebarAction(IconData icon, String label, String command) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: InkWell(
          onTap: _loading || _error != null ? null : () => _runCommand(command),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
            child: Row(children: [
              Icon(icon, size: 17, color: const Color(0xFF5F6368)),
              const SizedBox(width: 9),
              Expanded(child: Text(label, style: const TextStyle(color: Color(0xFF3C4043), fontSize: 12))),
            ]),
          ),
        ),
      );

  Widget _statusBar() {
    final controller = _controller;
    final status = controller?.isDirty == true
        ? 'Modified · save to keep your changes'
        : _loading
            ? _progress
            : _error != null
                ? 'Unable to open'
                : 'Ready';
    final detail = _word != null
        ? 'Word document'
        : _sheet != null
            ? 'Sheet ' + (_sheet!.activeSheetIndex + 1).toString() + ' · ' + _sheet!.selectionAddress
            : _slides != null
                ? 'Slide ' + (_slides!.activeSlideIndex + 1).toString()
                : 'Office document';
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(color: Color(0xFFFFFFFF), border: Border(top: BorderSide(color: Color(0xFFE3E7ED)))),
      child: Row(children: [
        Icon(controller?.isDirty == true ? Icons.circle : Icons.check_circle_outline, size: 13,
            color: controller?.isDirty == true ? const Color(0xFFE37400) : const Color(0xFF188038)),
        const SizedBox(width: 6),
        Text(status, style: const TextStyle(fontSize: 11, color: Color(0xFF5F6368))),
        const Spacer(),
        Text(detail + ' · Offline engine', style: const TextStyle(fontSize: 11, color: Color(0xFF5F6368))),
      ]),
    );
  }

  Future<void> _showEngineInfo({bool repair = false}) async {
    final text = repair
        ? 'Parin Office edits OOXML locally. If a file contains unsupported vendor-specific features, open a copy in a desktop Office suite and save a compatible DOCX, XLSX or PPTX version before importing it. The original file is never uploaded or overwritten by this editor.'
        : 'Parin Office uses an embedded Dart Office engine to open, edit and save DOCX, XLSX and PPTX on this device. It provides a paginated document canvas, spreadsheet formulas, slide objects, undo/redo, find/replace and PDF export. VBA/macros, Power Query and every proprietary Office extension are not guaranteed.';
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(repair ? 'Compatibility notes' : 'About the offline engine'),
        content: Text(text),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
      ),
    );
  }

  Future<void> _addSheetComment() async {
    if (_sheet == null) return;
    final textController = TextEditingController();
    final comment = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Comment on ' + _sheet!.selectionAddress),
        content: TextField(controller: textController, autofocus: true, minLines: 2, maxLines: 5,
            decoration: const InputDecoration(hintText: 'Write a note about this cell')),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(textController.text), child: const Text('Save comment')),
        ],
      ),
    );
    textController.dispose();
    if (comment != null) {
      _sheet!.setCellComment(comment);
      if (mounted) setState(() {});
    }
  }

  void _runCommand(String action) {
    if (action == 'outline') {
      setState(() => _outlineOpen = !_outlineOpen);
      return;
    }
    if (action == 'save') {
      _save();
      return;
    }
    if (action == 'pdf') {
      _shareAsPdf();
      return;
    }
    if (action == 'about' || action == 'repairInfo') {
      _showEngineInfo(repair: action == 'repairInfo');
      return;
    }
    if (action == 'sheetComment') {
      _addSheetComment();
      return;
    }
    switch (action) {
      case 'insertTable':
        if (_word != null) _word!.insertTable(rows: 3, columns: 3);
        if (_sheet != null) _sheet!.addTable();
        if (_slides != null) {
          _slides!.insertTable(rows: 3, cols: 3, arabic: Directionality.of(context) == TextDirection.rtl);
        }
        break;
      case 'pageBreak':
        _word?.insertPageBreak();
        break;
      case 'sectionBreak':
        _word?.insertSectionBreak();
        break;
      case 'toc':
        _word?.insertTableOfContents();
        break;
      case 'insertRow':
        _sheet?.insertSheetRows(after: true, count: 1);
        break;
      case 'insertColumn':
        _sheet?.insertSheetCols(after: true, count: 1);
        break;
      case 'merge':
        _sheet?.mergeAndCenter();
        break;
      case 'removeDuplicates':
        _sheet?.removeDuplicatesInSelection();
        break;
      case 'freezeTop':
        _sheet?.freezeTopRow();
        break;
      case 'freezeColumn':
        _sheet?.freezeFirstColumn();
        break;
      case 'recalculate':
        _sheet?.recalculateWorkbook();
        break;
      case 'sortAsc':
        _sheet?.sortSelection(ascending: true);
        break;
      case 'sortDesc':
        _sheet?.sortSelection(ascending: false);
        break;
      case 'rtlSheet':
        _sheet?.toggleSheetRightToLeft();
        break;
      case 'slideSection':
        _slides?.addSlideSection('Section');
        break;
      case 'masterBackground':
        _slides?.applyMasterBackground('FFFFFF');
        break;
      case 'spell':
      case 'find':
      case 'replace':
      case 'select':
      case 'print':
      case 'undo':
      case 'redo':
      case 'present':
      case 'previous':
      case 'next':
      case 'stopShow':
        _action(action);
        break;
    }
    if (mounted) setState(() {});
  }

  Widget _editorCanvas() {
    if (_error != null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.description_outlined, size: 52, color: Color(0xFF5F6368)),
              const SizedBox(height: 14),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              const Text('No upload or server conversion was attempted. The original file has not been overwritten.', textAlign: TextAlign.center),
            ]),
          ),
        ),
      );
    }
    if (_loading) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 14),
        Text(_progress),
      ]));
    }
    return switch (_extension) {
      'docx' => QudsWordEditor(controller: _word!),
      'xlsx' => QudsSheetEditor(controller: _sheet!, frozenRows: 0, frozenCols: 0),
      'pptx' => QudsSlideEditor(controller: _slides!),
      _ => const Center(child: Text('Unsupported document format')),
    };
  }


  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F4),
      body: SafeArea(
        child: Column(
          children: [
            _documentHeader(context),
            _menuBar(),
            _toolbar(),
            Expanded(
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  children: [
                    if (_outlineOpen)
                      Directionality(
                        textDirection: direction,
                        child: _outlinePanel(context),
                      ),
                    Expanded(
                      child: Container(
                        color: const Color(0xFFF1F3F4),
                        child: _editorCanvas(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _statusBar(),
          ],
        ),
      ),
    );
  }
}

class _RibbonDivider extends StatelessWidget {
  const _RibbonDivider();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: Container(width: 1, height: 28, color: const Color(0xFFDADCE0)),
      );
}


String _safeName(String value) {
  final cleaned = value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();
  return cleaned.isEmpty ? 'Parin-Office' : cleaned;
}

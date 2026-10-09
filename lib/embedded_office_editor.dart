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
    _documentTitle = TextEditingController(text: widget.fileName.replaceFirst(RegExp(r'\.[^.]+

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
      final base = _documentTitle.text.trim().isEmpty ? widget.fileName.replaceAll(RegExp(r'\.(docx|xlsx|pptx)
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

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              'On-device editing • $_extension'.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Document actions',
            onSelected: _action,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'find', child: Text('Find')),
              PopupMenuItem(value: 'replace', child: Text('Find and replace')),
              PopupMenuItem(value: 'select', child: Text('Select all')),
              PopupMenuItem(value: 'spell', child: Text('Spell check')),
              PopupMenuItem(value: 'print', child: Text('Print')),
            ],
          ),
          IconButton(
            tooltip: 'Export as PDF',
            onPressed: _loading || _saving || _error != null ? null : _shareAsPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
          IconButton(
            tooltip: 'Save to file',
            onPressed: _loading || _saving || _error != null ? null : _save,
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _error != null
          ? Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.description_outlined, size: 52),
                      const SizedBox(height: 14),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      const Text(
                        'No upload or server conversion was attempted. The original file has not been overwritten.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          : _loading
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 14),
                      Text(_progress),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Material(
                      color: Theme.of(context).colorScheme.surface,
                      child: SizedBox(
                        height: 52,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          children: _toolbarActions(),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: switch (_extension) {
                        'docx' => QudsWordEditor(controller: _word!),
                        'xlsx' => QudsSheetEditor(
                            controller: _sheet!,
                            frozenRows: 0,
                            frozenCols: 0,
                          ),
                        'pptx' => QudsSlideEditor(controller: _slides!),
                        _ => const Center(child: Text('Unsupported document format')),
                      },
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      child: Text(
                        [
                          controller?.isDirty == true ? 'Unsaved changes' : 'Ready',
                          if (_word != null) 'Word',
                          if (_sheet != null) 'Sheet ${_sheet!.activeSheetIndex + 1} • ${_sheet!.selectionAddress}',
                          if (_slides != null) 'Slide ${_slides!.activeSlideIndex + 1}',
                          'Offline engine',
                        ].join('  •  '),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ],
                ),
    );
  }
}

String _safeName(String value) {
  final cleaned = value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();
  return cleaned.isEmpty ? 'Parin-Office' : cleaned;
}
), ''));
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

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              'On-device editing • $_extension'.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Document actions',
            onSelected: _action,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'find', child: Text('Find')),
              PopupMenuItem(value: 'replace', child: Text('Find and replace')),
              PopupMenuItem(value: 'select', child: Text('Select all')),
              PopupMenuItem(value: 'spell', child: Text('Spell check')),
              PopupMenuItem(value: 'print', child: Text('Print')),
            ],
          ),
          IconButton(
            tooltip: 'Export as PDF',
            onPressed: _loading || _saving || _error != null ? null : _shareAsPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
          IconButton(
            tooltip: 'Save to file',
            onPressed: _loading || _saving || _error != null ? null : _save,
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _error != null
          ? Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.description_outlined, size: 52),
                      const SizedBox(height: 14),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      const Text(
                        'No upload or server conversion was attempted. The original file has not been overwritten.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          : _loading
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 14),
                      Text(_progress),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Material(
                      color: Theme.of(context).colorScheme.surface,
                      child: SizedBox(
                        height: 52,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          children: _toolbarActions(),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: switch (_extension) {
                        'docx' => QudsWordEditor(controller: _word!),
                        'xlsx' => QudsSheetEditor(
                            controller: _sheet!,
                            frozenRows: 0,
                            frozenCols: 0,
                          ),
                        'pptx' => QudsSlideEditor(controller: _slides!),
                        _ => const Center(child: Text('Unsupported document format')),
                      },
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      child: Text(
                        [
                          controller?.isDirty == true ? 'Unsaved changes' : 'Ready',
                          if (_word != null) 'Word',
                          if (_sheet != null) 'Sheet ${_sheet!.activeSheetIndex + 1} • ${_sheet!.selectionAddress}',
                          if (_slides != null) 'Slide ${_slides!.activeSlideIndex + 1}',
                          'Offline engine',
                        ].join('  •  '),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ],
                ),
    );
  }
}

String _safeName(String value) {
  final cleaned = value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();
  return cleaned.isEmpty ? 'Parin-Office' : cleaned;
}
, caseSensitive: false), '') : _documentTitle.text.trim();
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

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              'On-device editing • $_extension'.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Document actions',
            onSelected: _action,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'find', child: Text('Find')),
              PopupMenuItem(value: 'replace', child: Text('Find and replace')),
              PopupMenuItem(value: 'select', child: Text('Select all')),
              PopupMenuItem(value: 'spell', child: Text('Spell check')),
              PopupMenuItem(value: 'print', child: Text('Print')),
            ],
          ),
          IconButton(
            tooltip: 'Export as PDF',
            onPressed: _loading || _saving || _error != null ? null : _shareAsPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
          IconButton(
            tooltip: 'Save to file',
            onPressed: _loading || _saving || _error != null ? null : _save,
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _error != null
          ? Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.description_outlined, size: 52),
                      const SizedBox(height: 14),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      const Text(
                        'No upload or server conversion was attempted. The original file has not been overwritten.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          : _loading
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 14),
                      Text(_progress),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Material(
                      color: Theme.of(context).colorScheme.surface,
                      child: SizedBox(
                        height: 52,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          children: _toolbarActions(),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: switch (_extension) {
                        'docx' => QudsWordEditor(controller: _word!),
                        'xlsx' => QudsSheetEditor(
                            controller: _sheet!,
                            frozenRows: 0,
                            frozenCols: 0,
                          ),
                        'pptx' => QudsSlideEditor(controller: _slides!),
                        _ => const Center(child: Text('Unsupported document format')),
                      },
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      child: Text(
                        [
                          controller?.isDirty == true ? 'Unsaved changes' : 'Ready',
                          if (_word != null) 'Word',
                          if (_sheet != null) 'Sheet ${_sheet!.activeSheetIndex + 1} • ${_sheet!.selectionAddress}',
                          if (_slides != null) 'Slide ${_slides!.activeSlideIndex + 1}',
                          'Offline engine',
                        ].join('  •  '),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ],
                ),
    );
  }
}

String _safeName(String value) {
  final cleaned = value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();
  return cleaned.isEmpty ? 'Parin-Office' : cleaned;
}
), ''));
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

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              'On-device editing • $_extension'.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Document actions',
            onSelected: _action,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'find', child: Text('Find')),
              PopupMenuItem(value: 'replace', child: Text('Find and replace')),
              PopupMenuItem(value: 'select', child: Text('Select all')),
              PopupMenuItem(value: 'spell', child: Text('Spell check')),
              PopupMenuItem(value: 'print', child: Text('Print')),
            ],
          ),
          IconButton(
            tooltip: 'Export as PDF',
            onPressed: _loading || _saving || _error != null ? null : _shareAsPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
          IconButton(
            tooltip: 'Save to file',
            onPressed: _loading || _saving || _error != null ? null : _save,
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _error != null
          ? Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.description_outlined, size: 52),
                      const SizedBox(height: 14),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      const Text(
                        'No upload or server conversion was attempted. The original file has not been overwritten.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          : _loading
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 14),
                      Text(_progress),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Material(
                      color: Theme.of(context).colorScheme.surface,
                      child: SizedBox(
                        height: 52,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          children: _toolbarActions(),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: switch (_extension) {
                        'docx' => QudsWordEditor(controller: _word!),
                        'xlsx' => QudsSheetEditor(
                            controller: _sheet!,
                            frozenRows: 0,
                            frozenCols: 0,
                          ),
                        'pptx' => QudsSlideEditor(controller: _slides!),
                        _ => const Center(child: Text('Unsupported document format')),
                      },
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      child: Text(
                        [
                          controller?.isDirty == true ? 'Unsaved changes' : 'Ready',
                          if (_word != null) 'Word',
                          if (_sheet != null) 'Sheet ${_sheet!.activeSheetIndex + 1} • ${_sheet!.selectionAddress}',
                          if (_slides != null) 'Slide ${_slides!.activeSlideIndex + 1}',
                          'Offline engine',
                        ].join('  •  '),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ],
                ),
    );
  }
}

String _safeName(String value) {
  final cleaned = value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();
  return cleaned.isEmpty ? 'Parin-Office' : cleaned;
}

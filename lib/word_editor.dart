import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import 'office_editor_codec.dart';

class WordEditorPage extends StatefulWidget {
  const WordEditorPage({super.key, required this.bytes, required this.fileName});
  final Uint8List bytes;
  final String fileName;

  @override
  State<WordEditorPage> createState() => _WordEditorPageState();
}

class _WordEditorPageState extends State<WordEditorPage> {
  late final quill.QuillController _controller;
  late final TextEditingController _title;
  String _pageSize = 'A4';
  String _margins = 'Normal';
  bool _landscape = false;
  bool _focusMode = false;
  bool _saving = false;
  double _zoom = 1;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(
      text: widget.fileName.replaceAll(RegExp(r'\.(docx?|DOCX?)$'), ''),
    );
    _controller = quill.QuillController.basic();
    final initial = OfficeEditorCodec.extractWordText(widget.bytes);
    final body = initial.isEmpty
        ? 'Start writing your document here.\n\nSelect text and use the toolbar to format it.'
        : initial;
    _controller.document = quill.Document.fromJson(<dynamic>[
      {'insert': '${body.trimRight()}\n'},
    ]);
    _controller.addListener(_onDocumentChanged);
  }

  void _onDocumentChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onDocumentChanged);
    _controller.dispose();
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final bytes = OfficeEditorCodec.createWordFromDelta(
        delta: _controller.document.toDelta().toJson(),
        pageSize: _pageSize,
        landscape: _landscape,
        margins: _margins,
      );
      final outputName = '${_safeName(_title.text, 'Document')}.docx';
      final saved = await FilePicker.saveFile(
        fileName: outputName,
        bytes: bytes,
        mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        dialogTitle: 'Save Word document',
      );
      if (mounted && saved != null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Word document saved.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save Word document: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _findReplace() async {
    final find = TextEditingController();
    final replace = TextEditingController();
    final apply = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Find and replace'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: find, autofocus: true, decoration: const InputDecoration(labelText: 'Find text')),
          const SizedBox(height: 10),
          TextField(controller: replace, decoration: const InputDecoration(labelText: 'Replace with')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Replace all')),
        ],
      ),
    );
    if (apply == true && find.text.isNotEmpty) {
      final plain = _controller.document.toPlainText().replaceAll(find.text, replace.text);
      _controller.document = quill.Document.fromJson(<dynamic>[
        {'insert': '${plain.trimRight()}\n'},
      ]);
    }
    find.dispose();
    replace.dispose();
  }

  Future<void> _pageSetup() async {
    var page = _pageSize;
    var margins = _margins;
    var landscape = _landscape;
    final apply = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, update) => AlertDialog(
        title: const Text('Page setup'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            initialValue: page,
            decoration: const InputDecoration(labelText: 'Paper size'),
            items: const ['A4', 'Letter', 'A5']
                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                .toList(),
            onChanged: (v) { if (v != null) update(() => page = v); },
          ),
          DropdownButtonFormField<String>(
            initialValue: margins,
            decoration: const InputDecoration(labelText: 'Margins'),
            items: const ['Narrow', 'Normal', 'Wide']
                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                .toList(),
            onChanged: (v) { if (v != null) update(() => margins = v); },
          ),
          SwitchListTile(
            value: landscape,
            onChanged: (v) => update(() => landscape = v),
            title: const Text('Landscape orientation'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Apply')),
        ],
      )),
    );
    if (apply == true) {
      setState(() {
        _pageSize = page;
        _margins = margins;
        _landscape = landscape;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plain = _controller.document.toPlainText().trimRight();
    final words = plain.isEmpty ? 0 : plain.split(RegExp(r'\s+')).length;
    final width = (_pageSize == 'A5' ? 510.0 : 760.0) * (_landscape ? 1.22 : 1);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: TextField(
          controller: _title,
          decoration: const InputDecoration(hintText: 'Document name', border: InputBorder.none, filled: false),
          style: theme.textTheme.titleMedium,
        ),
        actions: [
          IconButton(tooltip: 'Find and replace', onPressed: _findReplace, icon: const Icon(Icons.find_replace)),
          IconButton(tooltip: 'Page setup', onPressed: _pageSetup, icon: const Icon(Icons.tune)),
          IconButton(
            tooltip: 'Save as DOCX',
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: Column(children: [
        if (!_focusMode)
          Container(
            width: double.infinity,
            color: theme.colorScheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: quill.QuillSimpleToolbar(
              controller: _controller,
              config: const quill.QuillSimpleToolbarConfig(
                multiRowsDisplay: true,
                showAlignmentButtons: true,
                showFontFamily: true,
                showFontSize: true,
                showColorButton: true,
                showBackgroundColorButton: true,
                showHeaderStyle: true,
                showListNumbers: true,
                showListBullets: true,
                showListCheck: true,
                showIndent: true,
                showLink: true,
                showUndo: true,
                showRedo: true,
                showSearchButton: true,
              ),
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          color: theme.colorScheme.surfaceContainerLow,
          child: Row(children: [
            Text(_pageSize, style: theme.textTheme.labelMedium),
            const SizedBox(width: 10),
            Text(_landscape ? 'Landscape' : 'Portrait', style: theme.textTheme.labelMedium),
            const SizedBox(width: 10),
            Text('$words words • ${plain.length} chars', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const Spacer(),
            IconButton(
              tooltip: _focusMode ? 'Exit focus mode' : 'Focus mode',
              onPressed: () => setState(() => _focusMode = !_focusMode),
              icon: Icon(_focusMode ? Icons.center_focus_strong : Icons.center_focus_weak),
            ),
            SizedBox(width: 116, child: Slider(value: _zoom, min: 0.75, max: 1.25, divisions: 10, onChanged: (v) => setState(() => _zoom = v))),
          ]),
        ),
        Expanded(child: Container(
          color: theme.colorScheme.surfaceContainerLowest,
          child: Center(child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Transform.scale(
              scale: _zoom,
              alignment: Alignment.topCenter,
              child: Container(
                constraints: const BoxConstraints(minHeight: 700),
                width: width,
                padding: EdgeInsets.all(_margins == 'Narrow' ? 42 : _margins == 'Wide' ? 86 : 64),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: const [BoxShadow(color: Color(0x18000000), blurRadius: 18, offset: Offset(0, 8))],
                ),
                child: quill.QuillEditor.basic(
                  controller: _controller,
                  config: const quill.QuillEditorConfig(
                    padding: EdgeInsets.zero,
                    placeholder: 'Start typing…',
                  ),
                ),
              ),
            ),
          )),
        )),
      ]),
    );
  }
}

String _safeName(String value, String fallback) {
  final cleaned = value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();
  return cleaned.isEmpty ? fallback : cleaned;
}

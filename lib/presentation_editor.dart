import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'office_editor_codec.dart';

class PresentationEditorPage extends StatefulWidget {
  const PresentationEditorPage({super.key, required this.bytes, required this.fileName});
  final Uint8List bytes;
  final String fileName;
  @override State<PresentationEditorPage> createState() => _PresentationEditorPageState();
}

class _PresentationEditorPageState extends State<PresentationEditorPage> {
  late final TextEditingController _presentationTitle;
  late final TextEditingController _slideTitle;
  late final TextEditingController _slideBody;
  late List<PresentationSlideDraft> _slides;
  int _selected = 0;
  bool _saving = false;
  String _accentHex = '2869F6';
  final List<(String, String)> _accents = const [
    ('Blue', '2869F6'), ('Violet', '7255DE'), ('Teal', '008D91'),
    ('Green', '198754'), ('Coral', 'E65B52'), ('Amber', 'B87500'),
  ];
  final List<(String, String)> _backgrounds = const [
    ('White', 'FFFFFF'), ('Midnight', '101426'), ('Ice', 'EAF1FF'),
    ('Mint', 'E7F7F1'), ('Sand', 'FFF4E3'), ('Berry', 'F8EAF4'),
  ];

  PresentationSlideDraft get _current => _slides[_selected];

  @override
  void initState() {
    super.initState();
    _presentationTitle = TextEditingController(text: widget.fileName.replaceAll(RegExp(r'\.(pptx?|PPTX?)$'), ''));
    _slides = OfficeEditorCodec.extractPresentation(widget.bytes);
    _slideTitle = TextEditingController(text: _current.title);
    _slideBody = TextEditingController(text: _current.body);
  }

  @override
  void dispose() {
    _presentationTitle.dispose();
    _slideTitle.dispose();
    _slideBody.dispose();
    super.dispose();
  }

  void _commitText() {
    _current.title = _slideTitle.text;
    _current.body = _slideBody.text;
  }

  void _selectSlide(int index) {
    _commitText();
    setState(() => _selected = index);
    _slideTitle.text = _current.title;
    _slideBody.text = _current.body;
  }

  void _addSlide() {
    _commitText();
    setState(() {
      _slides.insert(_selected + 1, PresentationSlideDraft(title: 'New slide', body: 'Add your key points here.'));
      _selected++;
    });
    _slideTitle.text = _current.title;
    _slideBody.text = _current.body;
  }

  void _duplicateSlide() {
    _commitText();
    setState(() {
      _slides.insert(_selected + 1, _current.copy());
      _selected++;
    });
    _slideTitle.text = _current.title;
    _slideBody.text = _current.body;
  }

  void _deleteSlide() {
    _commitText();
    if (_slides.length == 1) {
      setState(() {
        _current.title = 'Presentation title';
        _current.body = '';
      });
    } else {
      setState(() {
        _slides.removeAt(_selected);
        _selected = (_selected - 1).clamp(0, _slides.length - 1);
      });
    }
    _slideTitle.text = _current.title;
    _slideBody.text = _current.body;
  }

  void _moveSlide(int delta) {
    _commitText();
    final target = _selected + delta;
    if (target < 0 || target >= _slides.length) return;
    setState(() {
      final slide = _slides.removeAt(_selected);
      _slides.insert(target, slide);
      _selected = target;
    });
    _slideTitle.text = _current.title;
    _slideBody.text = _current.body;
  }

  Future<void> _save() async {
    if (_saving) return;
    _commitText();
    setState(() => _saving = true);
    try {
      final title = _presentationTitle.text.trim().isEmpty ? 'Parin Presentation' : _presentationTitle.text.trim();
      final bytes = OfficeEditorCodec.createPresentation(title: title, slides: _slides, accentHex: _accentHex);
      final path = await FilePicker.saveFile(
        fileName: '${_safeName(title)}.pptx',
        bytes: bytes,
        mimeType: 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        dialogTitle: 'Save PowerPoint',
      );
      if (mounted && path != null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Presentation saved.')));
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save PowerPoint: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Color _color(String hex) => Color(int.parse('FF$hex', radix: 16));

  @override
  Widget build(BuildContext context) {
    _commitText();
    final theme = Theme.of(context);
    final darkBackground = _current.backgroundHex == '101426';
    final bgColor = _color(_current.backgroundHex);
    final titleColor = darkBackground ? Colors.white : _color(_accentHex);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _presentationTitle,
          decoration: const InputDecoration(hintText: 'Presentation name', border: InputBorder.none, filled: false),
          style: theme.textTheme.titleMedium,
        ),
        actions: [
          IconButton(tooltip: 'Move slide up', onPressed: () => _moveSlide(-1), icon: const Icon(Icons.keyboard_arrow_up)),
          IconButton(tooltip: 'Move slide down', onPressed: () => _moveSlide(1), icon: const Icon(Icons.keyboard_arrow_down)),
          IconButton(tooltip: 'Duplicate slide', onPressed: _duplicateSlide, icon: const Icon(Icons.copy_outlined)),
          IconButton(tooltip: 'Delete slide', onPressed: _deleteSlide, icon: const Icon(Icons.delete_outline)),
          IconButton(
            tooltip: 'Save PowerPoint',
            onPressed: _saving ? null : _save,
            icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: Row(children: [
        SizedBox(
          width: 154,
          child: Column(children: [
            Padding(padding: const EdgeInsets.all(8), child: SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _addSlide, icon: const Icon(Icons.add), label: const Text('Slide')))),
            Expanded(child: ListView.builder(
              itemCount: _slides.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.fromLTRB(8, 3, 8, 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _selectSlide(index),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _selected == index ? theme.colorScheme.primary.withAlpha(20) : theme.colorScheme.surface,
                      border: Border.all(color: _selected == index ? theme.colorScheme.primary : theme.colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(height: 54, width: double.infinity, color: _color(_slides[index].backgroundHex), alignment: Alignment.center,
                        child: Text('${index + 1}', style: TextStyle(color: _slides[index].backgroundHex == '101426' ? Colors.white : Colors.black, fontWeight: FontWeight.w900))),
                      const SizedBox(height: 5),
                      Text(_slides[index].title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ),
              ),
            )),
          ]),
        ),
        VerticalDivider(width: 1, color: theme.colorScheme.outlineVariant),
        Expanded(child: ListView(padding: const EdgeInsets.all(18), children: [
          Text('Accent color', style: theme.textTheme.labelLarge),
          const SizedBox(height: 7),
          Wrap(spacing: 7, runSpacing: 7, children: [
            for (final (name, hex) in _accents)
              ChoiceChip(
                avatar: CircleAvatar(backgroundColor: _color(hex), radius: 8),
                label: Text(name),
                selected: _accentHex == hex,
                onSelected: (_) => setState(() => _accentHex = hex),
              ),
          ]),
          const SizedBox(height: 14),
          Text('Slide background', style: theme.textTheme.labelLarge),
          const SizedBox(height: 7),
          Wrap(spacing: 7, runSpacing: 7, children: [
            for (final (name, hex) in _backgrounds)
              ChoiceChip(
                avatar: CircleAvatar(backgroundColor: _color(hex), radius: 8),
                label: Text(name),
                selected: _current.backgroundHex == hex,
                onSelected: (_) => setState(() => _current.backgroundHex = hex),
              ),
          ]),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _current.layout,
            decoration: const InputDecoration(labelText: 'Slide layout'),
            items: const ['Title and content', 'Title only', 'Section header', 'Blank']
                .map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
            onChanged: (value) { if (value != null) setState(() => _current.layout = value); },
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _slideTitle,
            onChanged: (value) => _current.title = value,
            decoration: const InputDecoration(labelText: 'Slide title', prefixIcon: Icon(Icons.title)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _slideBody,
            onChanged: (value) => _current.body = value,
            minLines: 7,
            maxLines: 14,
            decoration: const InputDecoration(labelText: 'Content', alignLabelWithHint: true, hintText: 'Write each bullet on a new line. Prefix bullet lines with • or - .'),
          ),
          const SizedBox(height: 16),
          Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Slide preview', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 10),
            AspectRatio(aspectRatio: 16 / 9, child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8), border: Border.all(color: theme.colorScheme.outlineVariant)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_current.title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: titleColor, height: 1.1)),
                const SizedBox(height: 14),
                Expanded(child: Text(_current.body, style: TextStyle(color: darkBackground ? const Color(0xFFE8ECF4) : const Color(0xFF29354A), height: 1.4), overflow: TextOverflow.fade)),
              ]),
            )),
          ]))),
        ])),
      ]),
    );
  }
}

String _safeName(String value) {
  final cleaned = value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();
  return cleaned.isEmpty ? 'Presentation' : cleaned;
}

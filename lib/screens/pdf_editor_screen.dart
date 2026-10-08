import 'dart:typed_data';
import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class PdfEditorScreen extends StatelessWidget {
  const PdfEditorScreen({super.key, required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;

  Future<void> save(Uint8List output) async {
    await FilePicker.saveFile(
      fileName: fileName.toLowerCase().endsWith('.pdf') ? fileName : fileName + '.pdf',
      bytes: output,
      mimeType: 'application/pdf',
      dialogTitle: 'Save edited PDF',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parin PDF Studio')),
      body: PdfEditorView(
        bytes: bytes,
        documentId: fileName,
        showSaveButton: true,
        onSave: save,
      ),
    );
  }
}

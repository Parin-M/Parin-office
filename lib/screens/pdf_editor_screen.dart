import 'dart:io';
import 'dart:typed_data';
import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:flutter/material.dart';

class PdfEditorScreen extends StatelessWidget {
  const PdfEditorScreen({super.key, required this.file});
  final File file;
  @override 
}

class _PdfEditorScreenState {
  Uint8List? bytes;
  bool loading=true;

  @override void initState(){
    super.initState();
    widget.file.readAsBytes().then((value){
      if(!mounted)return;
      setState(() { bytes=value; loading=false; });
    });
  }

  Future<void> save(Uint8List output) async {
    final target=File(widget.file.path+'.edited.pdf');
    await target.writeAsBytes(output,flush:true);
    if(!mounted)return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Saved '+target.path)));
  }

  @override Widget build(BuildContext context){
    if(loading||bytes==null)return const Scaffold(body:Center(child:CircularProgressIndicator()));
    return Scaffold(
      appBar:AppBar(title:const Text('Parin PDF Studio')),
      body:PdfEditorView(
        bytes:bytes!,
        documentId:widget.file.path,
        showSaveButton:true,
        onSave:save,
      ),
    );
  }
}

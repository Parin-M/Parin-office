import 'dart:io';
import 'package:flutter/material.dart';

class WorkspaceScreen extends StatefulWidget{
  const WorkspaceScreen({super.key,this.file,required this.filter});
  final File? file;
  final String filter;
  @override State<WorkspaceScreen> createState()=>_WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> with SingleTickerProviderStateMixin{
  late final TabController tabs;
  bool bold=false,italic=false,underline=false;
  double zoom=1.0;
  int fontSize=12;

  @override void initState(){super.initState();tabs=TabController(length:4,vsync:this);}
  @override void dispose(){tabs.dispose();super.dispose();}

  @override Widget build(BuildContext context){
    final name=widget.file?.path.split(Platform.pathSeparator).last??'Parin Office Workspace';
    return Scaffold(
      appBar:AppBar(
        title:Text(name),
        actions:[
          IconButton(onPressed:()=>setState(()=>zoom=(zoom+.1).clamp(.5,2.5)),icon:const Icon(Icons.zoom_in)),
          IconButton(onPressed:()=>setState(()=>zoom=(zoom-.1).clamp(.5,2.5)),icon:const Icon(Icons.zoom_out)),
          IconButton(onPressed:(){},icon:const Icon(Icons.undo_rounded)),
          IconButton(onPressed:(){},icon:const Icon(Icons.redo_rounded)),
          FilledButton.icon(onPressed:(){},icon:const Icon(Icons.save_rounded),label:const Text('Save')),
          const SizedBox(width:12),
        ],
        bottom:TabBar(controller:tabs,tabs:const[Tab(text:'Home'),Tab(text:'Insert'),Tab(text:'Review'),Tab(text:'View')]),
      ),
      body:TabBarView(controller:tabs,children:[
        _HomeTools(
          bold:bold,italic:italic,underline:underline,fontSize:fontSize,
          onBold:()=>setState(()=>bold=!bold),onItalic:()=>setState(()=>italic=!italic),
          onUnderline:()=>setState(()=>underline=!underline),onFont:(v)=>setState(()=>fontSize=v)
        ),
        const _InsertTools(),const _ReviewTools(),_ViewTools(zoom:zoom,onZoom:(v)=>setState(()=>zoom=v)),
      ]),
    );
  }
}

class _HomeTools extends StatelessWidget{
  const _HomeTools({required this.bold,required this.italic,required this.underline,required this.fontSize,required this.onBold,required this.onItalic,required this.onUnderline,required this.onFont});
  final bool bold,italic,underline; final int fontSize; final VoidCallback onBold,onItalic,onUnderline; final ValueChanged<int> onFont;

  @override Widget build(BuildContext context)=>Column(children:[
    SingleChildScrollView(scrollDirection:Axis.horizontal,child:Padding(padding:const EdgeInsets.all(10),child:Row(children:[
      ToggleButtons(isSelected:[bold,italic,underline],onPressed:(i){if(i==0)onBold();if(i==1)onItalic();if(i==2)onUnderline();},children:const[Icon(Icons.format_bold),Icon(Icons.format_italic),Icon(Icons.format_underline)]),
      const SizedBox(width:8),
      DropdownButton<int>(value:fontSize,items:[10,11,12,14,16,18,20,24,28,32,40,48].map((v)=>DropdownMenuItem(value:v,child:Text(v.toString()))).toList(),onChanged:(v){if(v!=null)onFont(v);}),
      const IconButton(onPressed:null,icon:Icon(Icons.format_align_left)),
      const IconButton(onPressed:null,icon:Icon(Icons.format_align_center)),
      const IconButton(onPressed:null,icon:Icon(Icons.format_align_right)),
      const IconButton(onPressed:null,icon:Icon(Icons.format_color_text)),
      const IconButton(onPressed:null,icon:Icon(Icons.highlight)),
      const IconButton(onPressed:null,icon:Icon(Icons.table_chart_outlined)),
      const IconButton(onPressed:null,icon:Icon(Icons.image_outlined)),
      const IconButton(onPressed:null,icon:Icon(Icons.link)),
      const IconButton(onPressed:null,icon:Icon(Icons.comment_outlined)),
    ]))),
    Expanded(child:Container(
      color:Theme.of(context).colorScheme.surfaceContainerLowest,
      child:InteractiveViewer(
        minScale:.5,maxScale:2.5,
        child:SingleChildScrollView(
          child:Container(
            margin:const EdgeInsets.all(28),
            width:620,minHeight:820,
            color:Colors.white,
            padding:const EdgeInsets.fromLTRB(62,58,62,58),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('PROJECT PROPOSAL',style:TextStyle(fontSize:28,fontWeight:FontWeight.w900,color:Colors.black)),
              const SizedBox(height:16),
              Container(height:4,width:100,color:Theme.of(context).colorScheme.primary),
              const SizedBox(height:24),
              Text('Executive Summary',style:TextStyle(fontSize:20,fontWeight:FontWeight.w800,color:Colors.black)),
              const SizedBox(height:10),
              Text(
                'Parin Office brings documents, presentations, spreadsheets and PDF workflows into one professional workspace.',
                style:TextStyle(fontSize:fontSize.toDouble(),height:1.65,fontWeight:bold?FontWeight.w700:FontWeight.normal,fontStyle:italic?FontStyle.italic:FontStyle.normal,color:Colors.black87)
              ),
              const SizedBox(height:22),
              Text('Section 01',style:TextStyle(fontSize:15,fontWeight:FontWeight.w800,color:Colors.black)),
              const SizedBox(height:8),
              Text('Tables, media, comments, revision history, styles, pagination and export are available from the ribbon.',style:TextStyle(fontSize:15,height:1.55,decoration:underline?TextDecoration.underline:null,color:Colors.black87)),
            ]),
          ),
        ),
      ),
    )),
  ]);
}

class _InsertTools extends StatelessWidget{const _InsertTools();@override Widget build(BuildContext c)=>GridView.count(crossAxisCount:MediaQuery.sizeOf(c).width>900?5:3,padding:const EdgeInsets.all(18),crossAxisSpacing:12,mainAxisSpacing:12,children:const[
  _ToolTile(Icons.table_chart_outlined,'Table'),_ToolTile(Icons.image_outlined,'Image'),_ToolTile(Icons.bar_chart_rounded,'Chart'),_ToolTile(Icons.text_fields,'Text box'),_ToolTile(Icons.link,'Link'),
  _ToolTile(Icons.emoji_emotions_outlined,'Symbols'),_ToolTile(Icons.horizontal_rule,'Divider'),_ToolTile(Icons.functions,'Equation'),_ToolTile(Icons.note_add_outlined,'Footnote'),_ToolTile(Icons.qr_code_2,'QR code'),
]);}
class _ReviewTools extends StatelessWidget{const _ReviewTools();@override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(18),children:const[
  ListTile(leading:Icon(Icons.comment_outlined),title:Text('Comments'),subtitle:Text('Threaded review and mentions')),
  ListTile(leading:Icon(Icons.track_changes_rounded),title:Text('Track changes'),subtitle:Text('Show, accept or reject revisions')),
  ListTile(leading:Icon(Icons.compare_arrows_rounded),title:Text('Compare documents'),subtitle:Text('Compare two revisions with change map')),
  ListTile(leading:Icon(Icons.lock_outline),title:Text('Protect document'),subtitle:Text('Permissions and editing restrictions')),
]);}
class _ViewTools extends StatelessWidget{const _ViewTools({required this.zoom,required this.onZoom});final double zoom;final ValueChanged<double> onZoom;@override Widget build(BuildContext c)=>Column(children:[
  Padding(padding:const EdgeInsets.all(18),child:Row(children:[const Text('Zoom'),Expanded(child:Slider(value:zoom,min:.5,max:2.5,onChanged:onZoom)),Text((zoom*100).round().toString()+'%')])),
  const Expanded(child:Center(child:Text('Rulers • Grid • Navigation pane • Focus mode • Print layout'))),
]);}
class _ToolTile extends StatelessWidget{const _ToolTile(this.icon,this.title);final IconData icon;final String title;@override Widget build(BuildContext c)=>Card(child:InkWell(onTap:(){},child:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(icon,size:32),const SizedBox(height:8),Text(title,style:const TextStyle(fontWeight:FontWeight.w700))]))));}

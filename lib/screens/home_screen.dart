import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../app/app_state.dart';
import '../app/i18n.dart';
import 'pdf_editor_screen.dart';
import 'workspace_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.state});
  final AppState state;
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> openFile() async {
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf','docx','pptx','xlsx']);
    if (!mounted || files.isEmpty) return;
    final file = files.first;
    final ext = (file.extension ?? file.name.split('.').last).toLowerCase();
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ext == 'pdf'
          ? PdfEditorScreen(bytes: bytes, fileName: file.name)
          : WorkspaceScreen(bytes: bytes, fileName: file.name, filter: 'opened'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = (String key) => AppI18n.t(widget.state.locale, key);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parin Office'),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded)),
          const Padding(padding: EdgeInsets.only(right: 12), child: CircleAvatar(child: Icon(Icons.person_outline))),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
                sliver: SliverToBoxAdapter(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Your professional workspace', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Text('Write, calculate, present, annotate and publish from one app.', style: Theme.of(context).textTheme.bodyLarge),
                    ])),
                    FilledButton.icon(onPressed: openFile, icon: const Icon(Icons.add_rounded), label: Text(t('open'))),
                  ]),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                sliver: SliverGrid(
                  delegate: SliverChildListDelegate([
                    _DocCard(t('pdf'),'Annotate • sign • redact',Icons.picture_as_pdf_rounded,const Color(0xFFE84257),openFile),
                    _DocCard(t('word'),'Write • layout • review',Icons.article_rounded,const Color(0xFF2674D9),openFile),
                    _DocCard(t('powerpoint'),'Design • animate • present',Icons.slideshow_rounded,const Color(0xFFF77A21),openFile),
                    _DocCard(t('excel'),'Formula • chart • analyze',Icons.grid_on_rounded,const Color(0xFF119B69),openFile),
                  ]),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 390, mainAxisExtent: 166, crossAxisSpacing: 14, mainAxisSpacing: 14,
                  ),
                ),
              ),
              SliverPadding(padding: const EdgeInsets.fromLTRB(22, 22, 22, 10), sliver: SliverToBoxAdapter(child: Text(t('quick'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)))),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                sliver: SliverToBoxAdapter(child: Wrap(spacing: 10, runSpacing: 10, children: [
                  _Quick(Icons.note_add_outlined,t('new')), _Quick(Icons.document_scanner_outlined,t('scan')),
                  _Quick(Icons.auto_awesome_outlined,'AI Assistant'), _Quick(Icons.compare_arrows_rounded,'Compare'),
                  _Quick(Icons.merge_type_rounded,'Merge & split'), _Quick(Icons.picture_as_pdf_outlined,'PDF tools'),
                  _Quick(Icons.lock_outline,'Protect'), _Quick(Icons.cloud_upload_outlined,'Cloud sync'),
                ])),
              ),
              SliverPadding(padding: const EdgeInsets.fromLTRB(22, 26, 22, 10), sliver: SliverToBoxAdapter(child: Card(
                child: Padding(padding: const EdgeInsets.all(22), child: Wrap(spacing: 42, runSpacing: 18, children: const [
                  _Metric(Icons.speed_rounded,'Fast canvas','GPU-first workspace'),
                  _Metric(Icons.offline_bolt_outlined,'Offline-first','No network required'),
                  _Metric(Icons.security_outlined,'Private','Local-first controls'),
                  _Metric(Icons.devices_other_rounded,'Adaptive','Phone + tablet'),
                ])),
              ))),
            ],
          );
        },
      ),
    );
  }
}

class _DocCard extends StatelessWidget {
  const _DocCard(this.title,this.subtitle,this.icon,this.color,this.onTap);
  final String title,subtitle; final IconData icon; final Color color; final VoidCallback onTap;
  @override Widget build(BuildContext context)=>Card(clipBehavior:Clip.antiAlias,child:InkWell(onTap:onTap,child:Padding(padding:const EdgeInsets.all(18),child:Row(children:[
    Container(width:60,height:60,decoration:BoxDecoration(color:color.withOpacity(.12),borderRadius:BorderRadius.circular(18)),child:Icon(icon,color:color,size:31)),
    const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.center,children:[
      Text(title,style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w900)),const SizedBox(height:5),Text(subtitle)
    ])),const Icon(Icons.chevron_right_rounded)
  ]))));
}
class _Quick extends StatelessWidget{const _Quick(this.icon,this.label);final IconData icon;final String label;@override Widget build(BuildContext c)=>ActionChip(avatar:Icon(icon,size:18),label:Text(label),onPressed:(){ });}
class _Metric extends StatelessWidget{const _Metric(this.icon,this.title,this.value);final IconData icon;final String title,value;@override Widget build(BuildContext c)=>Row(mainAxisSize:MainAxisSize.min,children:[Icon(icon,size:24),const SizedBox(width:10),Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontWeight:FontWeight.w800)),Text(value)])]);}

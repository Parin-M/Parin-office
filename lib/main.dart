import 'dart:typed_data';
import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main(){WidgetsFlutterBinding.ensureInitialized();runApp(const ParinOfficeApp());}

enum AppearanceMode{system,light,dark,amoled}

class ThemePreset{
 const ThemePreset({required this.name,required this.primary,required this.secondary,required this.background});
 final String name;final Color primary,secondary,background;
}

class ThemeCatalog{
 static final presets=List<ThemePreset>.generate(128,(i){
  final hue=(i*137.508)%360;
  return ThemePreset(
   name:'Theme '+(i+1).toString(),
   primary:HSVColor.fromAHSV(1,hue,.78,.95).toColor(),
   secondary:HSVColor.fromAHSV(1,(hue+155)%360,.64,.86).toColor(),
   background:HSVColor.fromAHSV(1,hue,.035,.985).toColor());
 });
 static ThemeData build(ThemePreset p,Brightness b,bool amoled){
  final base=ColorScheme.fromSeed(seedColor:p.primary,brightness:b);
  final scheme=base.copyWith(primary:p.primary,secondary:p.secondary,surface:amoled?Colors.black:base.surface);
  return ThemeData(
   useMaterial3:true,colorScheme:scheme,brightness:b,
   scaffoldBackgroundColor:amoled?Colors.black:p.background,
   appBarTheme:const AppBarTheme(centerTitle:false,scrolledUnderElevation:0),
   cardTheme:CardThemeData(elevation:0,shape:RoundedRectangleBorder(borderRadius:BorderRadius.all(Radius.circular(22)))),
   inputDecorationTheme:const InputDecorationTheme(border:OutlineInputBorder()),
  );
 }
}

class AppState extends ChangeNotifier{
 Locale locale=const Locale('en');
 AppearanceMode mode=AppearanceMode.system;
 int themeIndex=11;
 bool autosave=true,animations=true,haptics=true,compactRibbon=false,diagnostics=false;

 Future<void>load()async{
  final p=await SharedPreferences.getInstance();
  final raw=p.getString('locale');
  if(raw!=null){final parts=raw.split('-');locale=parts.length>1?Locale(parts[0],parts[1]):Locale(parts[0]);}
  mode=AppearanceMode.values.firstWhere((x)=>x.name==p.getString('mode'),orElse:()=>AppearanceMode.system);
  themeIndex=(p.getInt('theme')??11).clamp(0,127);
  autosave=p.getBool('autosave')??true;
  animations=p.getBool('animations')??true;
  haptics=p.getBool('haptics')??true;
  compactRibbon=p.getBool('compact')??false;
  diagnostics=p.getBool('diagnostics')??false;
  notifyListeners();
 }
 Future<void>setLocale(Locale v)async{locale=v;notifyListeners();final p=await SharedPreferences.getInstance();await p.setString('locale',v.toLanguageTag());}
 Future<void>setMode(AppearanceMode v)async{mode=v;notifyListeners();final p=await SharedPreferences.getInstance();await p.setString('mode',v.name);}
 Future<void>setTheme(int v)async{themeIndex=v;notifyListeners();final p=await SharedPreferences.getInstance();await p.setInt('theme',v);}
 Future<void>setFlag(String key,bool v)async{
  if(key=='autosave')autosave=v;
  if(key=='animations')animations=v;
  if(key=='haptics')haptics=v;
  if(key=='compact')compactRibbon=v;
  if(key=='diagnostics')diagnostics=v;
  notifyListeners();
  final p=await SharedPreferences.getInstance();
  await p.setBool(key,v);
 }
 Brightness get brightness{
  switch(mode){
   case AppearanceMode.system:return WidgetsBinding.instance.platformDispatcher.platformBrightness;
   case AppearanceMode.light:return Brightness.light;
   case AppearanceMode.dark:
   case AppearanceMode.amoled:return Brightness.dark;
  }
 }
 ThemePreset get preset=>ThemeCatalog.presets[themeIndex];
 bool get amoled=>mode==AppearanceMode.amoled;
}

class L10n{
 static const locales=[
  Locale('fa'),Locale('en'),Locale('da'),Locale('de'),Locale('de','CH'),Locale('ar'),Locale('hi'),Locale('he'),
  Locale('es'),Locale('it'),Locale('sv'),Locale('fi'),Locale('no'),Locale('is'),Locale('el'),Locale('tr')];
 static const names=['فارسی','English','Dansk','Deutsch','Schweizerdeutsch','العربية','हिन्दी','עברית','Español','Italiano','Svenska','Suomi','Norsk','Íslenska','Ελληνικά','Türkçe'];
 static String text(Locale l,String key){
  const en={'home':'Home','recent':'Recent','workspace':'Workspace','settings':'Settings','open':'Open file','pdf':'PDF','word':'Word','powerpoint':'PowerPoint','excel':'Excel','quick':'Quick actions','themes':'Themes','language':'Language','appearance':'Appearance','general':'General','editor':'Editor','security':'Privacy & security','performance':'Performance','accessibility':'Accessibility','light':'Light','dark':'Dark','amoled':'AMOLED','system':'System'};
  const fa={'home':'خانه','recent':'اخیر','workspace':'Workspace','settings':'تنظیمات','open':'باز کردن فایل','pdf':'PDF','word':'Word','powerpoint':'PowerPoint','excel':'Excel','quick':'عملیات سریع','themes':'تم‌ها','language':'زبان','appearance':'ظاهر','general':'عمومی','editor':'ویرایشگر','security':'حریم خصوصی و امنیت','performance':'کارایی','accessibility':'دسترسی‌پذیری','light':'روشن','dark':'تاریک','amoled':'AMOLED','system':'سیستم'};
  const ar={'home':'الرئيسية','recent':'الأخيرة','workspace':'مساحة العمل','settings':'الإعدادات','open':'فتح ملف','pdf':'PDF','word':'Word','powerpoint':'PowerPoint','excel':'Excel','quick':'إجراءات سريعة','themes':'السمات','language':'اللغة','appearance':'المظهر','general':'عام','editor':'المحرر','security':'الخصوصية والأمان','performance':'الأداء','accessibility':'إمكانية الوصول','light':'فاتح','dark':'داكن','amoled':'AMOLED','system':'النظام'};
  return l.languageCode=='fa'?fa[key]??en[key]!:l.languageCode=='ar'?ar[key]??en[key]!:en[key]!;
 }
 static bool rtl(Locale l)=>l.languageCode=='fa'||l.languageCode=='ar'||l.languageCode=='he';
}

class ParinOfficeApp extends StatefulWidget{const ParinOfficeApp({super.key});@override State<ParinOfficeApp>createState()=>_ParinOfficeAppState();}
class _ParinOfficeAppState extends State<ParinOfficeApp>{
 final state=AppState();bool ready=false;
 @override void initState(){super.initState();state.load().whenComplete(()=>setState(()=>ready=true));}
 @override void dispose(){state.dispose();super.dispose();}
 @override Widget build(BuildContext context){
  if(!ready)return const MaterialApp(home:Scaffold(body:Center(child:CircularProgressIndicator())));
  return AnimatedBuilder(animation:state,builder:(context,_){
   return MaterialApp(
    debugShowCheckedModeBanner:false,title:'Parin Office',locale:state.locale,supportedLocales:L10n.locales,
    theme:ThemeCatalog.build(ThemeCatalog.presets[state.themeIndex],state.brightness,state.amoled),
    builder:(context,child)=>Directionality(textDirection:L10n.rtl(state.locale)?TextDirection.rtl:TextDirection.ltr,child:child!),
    home:Shell(state:state));
  });
 }
}

class Shell extends StatefulWidget{const Shell({super.key,required this.state});final AppState state;@override State<Shell>createState()=>_ShellState();}
class _ShellState extends State<Shell>{
 int index=0;
 @override Widget build(BuildContext context){
  final t=(String k)=>L10n.text(widget.state.locale,k);
  final items=[(Icons.home_rounded,t('home')),(Icons.description_outlined,t('recent')),(Icons.dashboard_customize_outlined,t('workspace')),(Icons.settings_outlined,t('settings'))];
  final pages=[Dashboard(state:widget.state),const RecentPage(),const WorkspaceHome(),SettingsPage(state:widget.state)];
  return LayoutBuilder(builder:(context,c){
   if(c.maxWidth>=900)return Scaffold(body:Row(children:[
    SizedBox(width:270,child:NavigationRail(
     extended:true,selectedIndex:index,onDestinationSelected:(v)=>setState(()=>index=v),
     leading:Padding(padding:const EdgeInsets.all(18),child:Row(children:[
      Container(width:42,height:42,decoration:BoxDecoration(color:widget.state.preset.primary,borderRadius:BorderRadius.circular(14)),child:const Icon(Icons.auto_awesome_rounded,color:Colors.white)),
      const SizedBox(width:10),const Text('Parin Office',style:TextStyle(fontWeight:FontWeight.w900,fontSize:20))
     ])),
     destinations:items.map((x)=>NavigationRailDestination(icon:Icon(x.$1),label:Text(x.$2))).toList())),
    const VerticalDivider(width:1),Expanded(child:pages[index])]));
   return Scaffold(body:pages[index],bottomNavigationBar:NavigationBar(selectedIndex:index,onDestinationSelected:(v)=>setState(()=>index=v),destinations:items.map((x)=>NavigationDestination(icon:Icon(x.$1),label:x.$2)).toList()));
  });
 }
}

class Dashboard extends StatelessWidget{
 const Dashboard({super.key,required this.state});final AppState state;
 Future<void>openFile(BuildContext context)async{
  final files=await FilePicker.pickFiles(type:FileType.custom,allowedExtensions:const['pdf','docx','pptx','xlsx']);
  if(!context.mounted||files.isEmpty)return;
  final f=files.first;final bytes=await f.readAsBytes();if(!context.mounted)return;
  final ext=(f.extension??'').toLowerCase();
  Navigator.of(context).push(MaterialPageRoute(builder:(_)=>ext=='pdf'?PdfPage(bytes:bytes,name:f.name):OfficePage(bytes:bytes,name:f.name)));
 }
 @override Widget build(BuildContext context){
  final t=(String k)=>L10n.text(state.locale,k);
  return Scaffold(appBar:AppBar(title:const Text('Parin Office'),actions:[IconButton(onPressed:(){},icon:const Icon(Icons.search_rounded)),IconButton(onPressed:(){},icon:const Icon(Icons.notifications_none_rounded)),const Padding(padding:EdgeInsets.only(right:14),child:CircleAvatar(child:Icon(Icons.person_outline)))]),
   body:CustomScrollView(slivers:[
    SliverPadding(padding:const EdgeInsets.fromLTRB(22,24,22,12),sliver:SliverToBoxAdapter(child:Row(crossAxisAlignment:CrossAxisAlignment.end,children:[
     Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Professional workspace',style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.w900)),const SizedBox(height:5),Text('Write, calculate, present, annotate and publish.',style:Theme.of(context).textTheme.bodyLarge)])),
     FilledButton.icon(onPressed:()=>openFile(context),icon:const Icon(Icons.add_rounded),label:Text(t('open')))]))),
    SliverPadding(padding:const EdgeInsets.symmetric(horizontal:22),sliver:SliverGrid(delegate:SliverChildListDelegate([
     _DocTile(t('pdf'),'Annotate • sign • search',Icons.picture_as_pdf_rounded,const Color(0xFFE64B5F),()=>openFile(context)),
     _DocTile(t('word'),'Compose • format • review',Icons.article_rounded,const Color(0xFF2878D8),()=>openFile(context)),
     _DocTile(t('powerpoint'),'Design • animate • present',Icons.slideshow_rounded,const Color(0xFFF57A22),()=>openFile(context)),
     _DocTile(t('excel'),'Formula • chart • analyze',Icons.grid_on_rounded,const Color(0xFF159D6B),()=>openFile(context)),
    ]),gridDelegate:const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent:400,mainAxisExtent:158,crossAxisSpacing:14,mainAxisSpacing:14))),
    SliverPadding(padding:const EdgeInsets.fromLTRB(22,26,22,10),sliver:SliverToBoxAdapter(child:Text(t('quick'),style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w900)))),
    SliverPadding(padding:const EdgeInsets.symmetric(horizontal:22),sliver:SliverToBoxAdapter(child:Wrap(spacing:10,runSpacing:10,children:const[
     Chip(avatar:Icon(Icons.note_add_outlined,size:18),label:Text('New')),Chip(avatar:Icon(Icons.document_scanner_outlined,size:18),label:Text('Scan')),Chip(avatar:Icon(Icons.auto_awesome_outlined,size:18),label:Text('AI Assist')),Chip(avatar:Icon(Icons.compare_arrows_rounded,size:18),label:Text('Compare')),Chip(avatar:Icon(Icons.merge_type_rounded,size:18),label:Text('Merge / Split')),Chip(avatar:Icon(Icons.lock_outline,size:18),label:Text('Protect')),Chip(avatar:Icon(Icons.cloud_sync_outlined,size:18),label:Text('Sync'))]))),
    SliverPadding(padding:const EdgeInsets.fromLTRB(22,26,22,35),sliver:SliverToBoxAdapter(child:Card(child:Padding(padding:const EdgeInsets.all(22),child:Wrap(spacing:38,runSpacing:20,children:const[
     _Metric(Icons.devices_other_rounded,'Adaptive','Phone + Tablet'),_Metric(Icons.offline_bolt_outlined,'Offline-first','Local editing'),_Metric(Icons.palette_outlined,'Themes','128 presets'),_Metric(Icons.security_outlined,'Privacy','Local controls')
    ]))))),
   ]));
 }
}
class _DocTile extends StatelessWidget{const _DocTile(this.title,this.subtitle,this.icon,this.color,this.onTap);final String title,subtitle;final IconData icon;final Color color;final VoidCallback onTap;@override Widget build(BuildContext c)=>Card(clipBehavior:Clip.antiAlias,child:InkWell(onTap:onTap,child:Padding(padding:const EdgeInsets.all(18),child:Row(children:[Container(width:58,height:58,decoration:BoxDecoration(color:color.withAlpha(30),borderRadius:BorderRadius.circular(18)),child:Icon(icon,color:color,size:30)),const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.center,children:[Text(title,style:Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w900)),const SizedBox(height:5),Text(subtitle)])),const Icon(Icons.chevron_right_rounded)]))));}
class _Metric extends StatelessWidget{const _Metric(this.icon,this.title,this.value);final IconData icon;final String title,value;@override Widget build(BuildContext c)=>Row(mainAxisSize:MainAxisSize.min,children:[Icon(icon),const SizedBox(width:9),Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontWeight:FontWeight.w800)),Text(value)])]);}

class PdfPage extends StatelessWidget{
 const PdfPage({super.key,required this.bytes,required this.name});final Uint8List bytes;final String name;
 Future<void>save(Uint8List output)async{await FilePicker.saveFile(fileName:name,bytes:output,mimeType:'application/pdf',dialogTitle:'Save edited PDF');}
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(name)),body:PdfEditorView(bytes:bytes,documentId:name,onSave:save,showSaveButton:true));
}

class OfficePage extends StatelessWidget{
 const OfficePage({super.key,required this.bytes,required this.name});final Uint8List bytes;final String name;
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(name)),body:OfficeWorkbench(fileName:name));
}

class OfficeWorkbench extends StatefulWidget{const OfficeWorkbench({super.key,required this.fileName});final String fileName;@override State<OfficeWorkbench>createState()=>_OfficeWorkbenchState();}
class _OfficeWorkbenchState extends State<OfficeWorkbench>{
 int tab=0;bool bold=false,italic=false,underline=false;double zoom=1;
 final names=['Home','Insert','Review','View'];
 @override Widget build(BuildContext c)=>Column(children:[
  SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:List.generate(names.length,(i)=>Padding(padding:const EdgeInsets.symmetric(horizontal:5),child:ChoiceChip(label:Text(names[i]),selected:tab==i,onSelected:(_)=>setState(()=>tab=i)))))),
  const Divider(height:1),Expanded(child:switch(tab){0=>_wordCanvas(c),1=>_insert(c),2=>_review(c),_=>_view(c)})
 ]);
 Widget _wordCanvas(BuildContext c)=>Column(children:[
  Padding(padding:const EdgeInsets.all(10),child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
   ToggleButtons(isSelected:[bold,italic,underline],onPressed:(i){if(i==0)bold=!bold;if(i==1)italic=!italic;if(i==2)underline=!underline;setState((){});},children:const[Icon(Icons.format_bold),Icon(Icons.format_italic),Icon(Icons.format_underline)]),
   const IconButton(onPressed:null,icon:Icon(Icons.format_align_left)),const IconButton(onPressed:null,icon:Icon(Icons.format_align_center)),const IconButton(onPressed:null,icon:Icon(Icons.format_align_right)),
   const IconButton(onPressed:null,icon:Icon(Icons.table_chart_outlined)),const IconButton(onPressed:null,icon:Icon(Icons.image_outlined)),const IconButton(onPressed:null,icon:Icon(Icons.link)),const IconButton(onPressed:null,icon:Icon(Icons.comment_outlined)),const IconButton(onPressed:null,icon:Icon(Icons.track_changes_rounded)),
  ]))),
  Expanded(child:Container(color:Theme.of(c).colorScheme.surfaceContainerLowest,child:InteractiveViewer(minScale:.5,maxScale:2.5,child:Center(child:Transform.scale(scale:zoom,child:Container(width:620,height:820,color:Colors.white,padding:const EdgeInsets.all(58),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   Text('PROJECT PROPOSAL',style:TextStyle(color:Colors.black,fontSize:28,fontWeight:FontWeight.w900,fontStyle:italic?FontStyle.italic:FontStyle.normal,decoration:underline?TextDecoration.underline:null)),
   const SizedBox(height:18),Container(width:110,height:5,color:Theme.of(c).colorScheme.primary),const SizedBox(height:24),
   Text('Executive Summary',style:TextStyle(color:Colors.black,fontSize:20,fontWeight:bold?FontWeight.w900:FontWeight.w700)),
   const SizedBox(height:12),Text('This is the new Parin Office workspace. The document remains central while tools stay within one gesture.',style:TextStyle(color:Colors.black87,fontSize:14,height:1.65)),
   const SizedBox(height:20),Text('Tables • media • styles • comments • revisions • layout • export',style:const TextStyle(color:Colors.black87,fontSize:14)),
  ])))))))
 ]);
 Widget _insert(BuildContext c)=>GridView.count(crossAxisCount:MediaQuery.sizeOf(c).width>900?5:3,padding:const EdgeInsets.all(18),crossAxisSpacing:12,mainAxisSpacing:12,children:const[
  _Feature(Icons.table_chart_outlined,'Table'),_Feature(Icons.image_outlined,'Image'),_Feature(Icons.bar_chart_rounded,'Chart'),_Feature(Icons.text_fields,'Text box'),_Feature(Icons.functions,'Equation'),
  _Feature(Icons.link,'Hyperlink'),_Feature(Icons.qr_code_2,'QR code'),_Feature(Icons.emoji_emotions_outlined,'Symbols'),_Feature(Icons.note_add_outlined,'Footnote'),_Feature(Icons.auto_awesome,'Smart tools')
 ]);
 Widget _review(BuildContext c)=>ListView(padding:const EdgeInsets.all(18),children:const[
  ListTile(leading:Icon(Icons.comment_outlined),title:Text('Comments'),subtitle:Text('Threads, mentions and resolution')),
  ListTile(leading:Icon(Icons.track_changes_rounded),title:Text('Track changes'),subtitle:Text('Accept, reject and filter revisions')),
  ListTile(leading:Icon(Icons.compare_arrows_rounded),title:Text('Compare'),subtitle:Text('Compare document revisions')),
  ListTile(leading:Icon(Icons.lock_outline),title:Text('Protect'),subtitle:Text('Permissions and editing restrictions'))
 ]);
 Widget _view(BuildContext c)=>Column(children:[
  Padding(padding:const EdgeInsets.all(18),child:Row(children:[const Text('Zoom'),Expanded(child:Slider(value:zoom,min:.5,max:2.5,onChanged:(v)=>setState(()=>zoom=v))),Text((zoom*100).round().toString()+'%')])),
  const Expanded(child:Center(child:Text('Rulers • Grid • Navigation pane • Focus mode • Print layout')))
 ]);
}

class _Feature extends StatelessWidget{const _Feature(this.icon,this.title);final IconData icon;final String title;@override Widget build(BuildContext c)=>Card(child:InkWell(onTap:(){},child:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(icon,size:30),const SizedBox(height:9),Text(title,style:const TextStyle(fontWeight:FontWeight.w800))]))));}

class RecentPage extends StatelessWidget{
 const RecentPage({super.key});
 @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Recent documents')),body:ListView(padding:const EdgeInsets.all(22),children:const[
  _Recent('Project proposal.docx','Word • edited recently',Icons.article_outlined),
  _Recent('Strategy deck.pptx','PowerPoint • yesterday',Icons.slideshow_outlined),
  _Recent('Financial model.xlsx','Excel • 2 days ago',Icons.grid_on_outlined),
  _Recent('Research paper.pdf','PDF • 3 days ago',Icons.picture_as_pdf_outlined),
 ]));
}
class _Recent extends StatelessWidget{const _Recent(this.title,this.subtitle,this.icon);final String title,subtitle;final IconData icon;@override Widget build(BuildContext c)=>Card(margin:const EdgeInsets.only(bottom:12),child:ListTile(leading:CircleAvatar(child:Icon(icon)),title:Text(title,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text(subtitle),trailing:const Icon(Icons.more_horiz_rounded)));}

class WorkspaceHome extends StatelessWidget{
 const WorkspaceHome({super.key});
 @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Workspace')),body:GridView.count(crossAxisCount:MediaQuery.sizeOf(c).width>1000?4:2,padding:const EdgeInsets.all(22),crossAxisSpacing:14,mainAxisSpacing:14,children:const[
  _Feature(Icons.description_outlined,'Documents'),_Feature(Icons.picture_as_pdf_outlined,'PDF Studio'),_Feature(Icons.table_chart_outlined,'Spreadsheet'),_Feature(Icons.slideshow_outlined,'Presentation'),_Feature(Icons.cloud_outlined,'Cloud space'),_Feature(Icons.favorite_border,'Favorites'),_Feature(Icons.folder_open,'Templates'),_Feature(Icons.auto_awesome_outlined,'AI tools'),
 ]));
}

class SettingsPage extends StatelessWidget{
 const SettingsPage({super.key,required this.state});final AppState state;
 Widget section(String title,IconData icon,List<Widget> children)=>Card(child:ExpansionTile(initiallyExpanded:true,leading:Icon(icon),title:Text(title,style:const TextStyle(fontWeight:FontWeight.w900)),children:children));
 @override Widget build(BuildContext c){
  final t=(String k)=>L10n.text(state.locale,k);
  return Scaffold(appBar:AppBar(title:Text(t('settings'))),body:ListView(padding:const EdgeInsets.fromLTRB(18,12,18,40),children:[
   section(t('appearance'),Icons.palette_outlined,[
    ListTile(title:Text(t('themes')),subtitle:const Text('128 color presets')),
    SizedBox(height:320,child:GridView.builder(itemCount:128,gridDelegate:const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent:78,crossAxisSpacing:8,mainAxisSpacing:8),itemBuilder:(ctx,i){final p=ThemeCatalog.presets[i];final selected=i==state.themeIndex;return InkWell(onTap:()=>state.setTheme(i),borderRadius:BorderRadius.circular(16),child:Container(decoration:BoxDecoration(borderRadius:BorderRadius.circular(16),gradient:LinearGradient(colors:[p.primary,p.secondary]),border:selected?Border.all(color:Theme.of(ctx).colorScheme.onSurface,width:3):null),child:Center(child:Text((i+1).toString(),style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w900)))));})),
    ListTile(title:const Text('Display mode'),trailing:DropdownButton<AppearanceMode>(value:state.mode,items:const[
     DropdownMenuItem(value:AppearanceMode.system,child:Text('System')),DropdownMenuItem(value:AppearanceMode.light,child:Text('Light')),DropdownMenuItem(value:AppearanceMode.dark,child:Text('Dark')),DropdownMenuItem(value:AppearanceMode.amoled,child:Text('AMOLED'))
    ],onChanged:(v){if(v!=null)state.setMode(v);}))
   ]),
   section(t('language'),Icons.language_outlined,List.generate(L10n.locales.length,(i){final l=L10n.locales[i];return ListTile(leading:CircleAvatar(radius:15,child:Text(l.languageCode.toUpperCase())),title:Text(L10n.names[i]),trailing:l.toLanguageTag()==state.locale.toLanguageTag()?const Icon(Icons.check_circle):null,onTap:()=>state.setLocale(l));})),
   section(t('general'),Icons.tune_rounded,[
    SwitchListTile(value:state.autosave,onChanged:(v)=>state.setFlag('autosave',v),title:const Text('Smart autosave')),
    SwitchListTile(value:state.animations,onChanged:(v)=>state.setFlag('animations',v),title:const Text('Motion and transitions')),
    SwitchListTile(value:state.haptics,onChanged:(v)=>state.setFlag('haptics',v),title:const Text('Haptic feedback')),
    SwitchListTile(value:state.compactRibbon,onChanged:(v)=>state.setFlag('compact',v),title:const Text('Compact ribbon')),
    const ListTile(title:Text('Safe save policy'),subtitle:Text('Protect originals and use Save As when required'))
   ]),
   section(t('editor'),Icons.edit_note_rounded,[
    const ListTile(title:Text('Command palette'),subtitle:Text('Search every action and shortcut')),
    const ListTile(title:Text('Undo / redo'),subtitle:Text('250+ action history')),
    const ListTile(title:Text('Rulers & snapping'),subtitle:Text('Guides, grid and precise placement')),
    const ListTile(title:Text('Stylus'),subtitle:Text('Pressure, palm rejection and quick tools')),
    const ListTile(title:Text('Typography'),subtitle:Text('Fonts, spacing, ligatures and RTL shaping')),
   ]),
   section(t('security'),Icons.security_outlined,[
    SwitchListTile(value:state.diagnostics,onChanged:(v)=>state.setFlag('diagnostics',v),title:const Text('Anonymous diagnostics')),
    const ListTile(title:Text('App lock'),subtitle:Text('PIN, biometrics and timeout')),
    const ListTile(title:Text('Protected documents'),subtitle:Text('Passwords, permissions and safe handling')),
   ]),
   section(t('performance'),Icons.speed_rounded,[
    const ListTile(title:Text('Large-document mode'),subtitle:Text('Virtualized pages, slides and spreadsheet rows')),
    const ListTile(title:Text('Rendering'),subtitle:Text('Progressive tiles, caching and GPU-first painting')),
    const ListTile(title:Text('Memory'),subtitle:Text('Automatic cache trimming and recovery checkpoints')),
   ]),
   section(t('accessibility'),Icons.accessibility_new_rounded,[
    const ListTile(title:Text('Text scaling'),subtitle:Text('80%–200%')),
    const ListTile(title:Text('High contrast'),subtitle:Text('Focus rings and stronger boundaries')),
    const ListTile(title:Text('Reduced motion'),subtitle:Text('Disable non-essential animations')),
    const ListTile(title:Text('Screen reader'),subtitle:Text('Semantics and keyboard navigation')),
   ]),
   section('Power user',Icons.developer_mode_rounded,[
    const ListTile(title:Text('Compatibility'),subtitle:Text('Strict / balanced / maximum preservation')),
    const ListTile(title:Text('Recovery center'),subtitle:Text('Restore interrupted document sessions')),
    const ListTile(title:Text('Experimental engines'),subtitle:Text('Preview advanced Word / Excel / PowerPoint engines')),
   ]),
  ]));
 }
}

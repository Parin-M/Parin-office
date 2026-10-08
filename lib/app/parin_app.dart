import 'package:flutter/material.dart';
import 'app_state.dart';
import 'i18n.dart';
import '../theme/theme_catalog.dart';
import '../screens/home_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/workspace_screen.dart';

class ParinApp extends StatefulWidget{const ParinApp({super.key});@override State<ParinApp> createState()=>_ParinAppState();}
class _ParinAppState extends State<ParinApp>{
 final state=AppState();bool ready=false;
 @override void initState(){super.initState();state.load().whenComplete(()=>setState(()=>ready=true));}
 @override void dispose(){state.dispose();super.dispose();}
 @override Widget build(BuildContext context){
  if(!ready)return const MaterialApp(home:Scaffold(body:Center(child:CircularProgressIndicator())));
  return AnimatedBuilder(animation:state,builder:(context,_){
   return MaterialApp(
    debugShowCheckedModeBanner:false,title:'Parin Office',locale:state.locale,supportedLocales:AppI18n.supported,
    theme:ThemeCatalog.build(preset:state.preset,brightness:state.brightness(),amoled:state.amoled),
    builder:(context,child)=>Directionality(textDirection:AppI18n.isRtl(state.locale)?TextDirection.rtl:TextDirection.ltr,child:child!),
    home:Shell(state:state),
   );
  });
 }
}
class Shell extends StatefulWidget{const Shell({super.key,required this.state});final AppState state;@override State<Shell> createState()=>_ShellState();}
class _ShellState extends State<Shell>{
 int index=0;
 @override Widget build(BuildContext context){
  final t=(String k)=>AppI18n.t(widget.state.locale,k);
  final d=[(Icons.home_rounded,t('home')),(Icons.description_outlined,t('recent')),(Icons.dashboard_customize_outlined,t('workspace')),(Icons.settings_outlined,t('settings'))];
  final pages=[HomeScreen(state:widget.state),const WorkspaceScreen(filter:'recent'),const WorkspaceScreen(filter:'all'),SettingsScreen(state:widget.state)];
  return LayoutBuilder(builder:(context,c){
   if(c.maxWidth>=900)return Scaffold(body:Row(children:[
    SizedBox(width:260,child:NavigationRail(extended:true,selectedIndex:index,onDestinationSelected:(v)=>setState(()=>index=v),destinations:d.map((x)=>NavigationRailDestination(icon:Icon(x.$1),label:Text(x.$2))).toList())),
    const VerticalDivider(width:1),Expanded(child:pages[index])
   ]));
   return Scaffold(body:pages[index],bottomNavigationBar:NavigationBar(selectedIndex:index,onDestinationSelected:(v)=>setState(()=>index=v),destinations:d.map((x)=>NavigationDestination(icon:Icon(x.$1),label:x.$2)).toList()));
  });
 }
}

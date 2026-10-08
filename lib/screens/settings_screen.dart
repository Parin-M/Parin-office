import 'package:flutter/material.dart';
import '../app/app_state.dart';
import '../app/i18n.dart';
import '../theme/theme_catalog.dart';

class SettingsScreen extends StatefulWidget{
  const SettingsScreen({super.key,required this.state});
  final AppState state;
  @override State<SettingsScreen> createState()=>_SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>{
  Widget section(String title,IconData icon,List<Widget> children)=>Card(child:ExpansionTile(
    initiallyExpanded:true,leading:Icon(icon),title:Text(title,style:const TextStyle(fontWeight:FontWeight.w900)),children:children
  ));

  @override Widget build(BuildContext context){
    final t=(String key)=>AppI18n.t(widget.state.locale,key);
    return Scaffold(
      appBar:AppBar(title:Text(t('settings'))),
      body:ListView(padding:const EdgeInsets.fromLTRB(18,14,18,40),children:[
        section(t('appearance'),Icons.palette_outlined,[
          ListTile(title:Text(t('themes')),subtitle:Text(ThemeCatalog.presets.length.toString()+' themes')),
          SizedBox(height:240,child:GridView.builder(
            padding:const EdgeInsets.symmetric(horizontal:16,vertical:4),
            gridDelegate:const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent:76,crossAxisSpacing:8,mainAxisSpacing:8),
            itemCount:ThemeCatalog.presets.length,
            itemBuilder:(context,index){
              final p=ThemeCatalog.presets[index]; final selected=index==widget.state.themeIndex;
              return InkWell(
                borderRadius:BorderRadius.circular(16),
                onTap:()=>widget.state.setTheme(index),
                child:AnimatedContainer(
                  duration:const Duration(milliseconds:150),
                  decoration:BoxDecoration(
                    borderRadius:BorderRadius.circular(16),
                    gradient:LinearGradient(colors:[p.primary,p.secondary]),
                    border:selected?Border.all(color:Theme.of(context).colorScheme.onSurface,width:3):null,
                  ),
                  child:Center(child:Text((index+1).toString(),style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w900))),
                ),
              );
            },
          )),
          ListTile(
            title:const Text('Appearance mode'),
            trailing:DropdownButton<AppearanceMode>(
              value:widget.state.mode,
              items:const[
                DropdownMenuItem(value:AppearanceMode.system,child:Text('System')),
                DropdownMenuItem(value:AppearanceMode.light,child:Text('Light')),
                DropdownMenuItem(value:AppearanceMode.dark,child:Text('Dark')),
                DropdownMenuItem(value:AppearanceMode.amoled,child:Text('AMOLED')),
              ],
              onChanged:(v){if(v!=null)widget.state.setMode(v);},
            ),
          ),
        ]),
        section(t('language'),Icons.language_outlined,[
          ...AppI18n.supported.map((locale)=>ListTile(
            leading:CircleAvatar(radius:15,child:Text(locale.languageCode.toUpperCase())),
            title:Text(AppI18n.names[locale.toLanguageTag()]??locale.languageCode),
            trailing:locale.toLanguageTag()==widget.state.locale.toLanguageTag()?const Icon(Icons.check_circle_rounded):null,
            onTap:()=>widget.state.setLocale(locale),
          )),
        ]),
        section(t('general'),Icons.tune_rounded,[
          SwitchListTile(value:widget.state.autosave,onChanged:(v)=>widget.state.setFlag('autosave',v),title:const Text('Smart autosave')),
          SwitchListTile(value:widget.state.animations,onChanged:(v)=>widget.state.setFlag('animations',v),title:const Text('Animations')),
          SwitchListTile(value:widget.state.haptics,onChanged:(v)=>widget.state.setFlag('haptics',v),title:const Text('Haptic feedback')),
          SwitchListTile(value:widget.state.compactToolbar,onChanged:(v)=>widget.state.setFlag('compactToolbar',v),title:const Text('Compact ribbon')),
          const ListTile(title:Text('Default start page'),subtitle:Text('Home / Recent / Last workspace')),
          const ListTile(title:Text('Default save behavior'),subtitle:Text('Safe save / Save as / Preserve original')),
        ]),
        section(t('editor'),Icons.edit_note_rounded,[
          const ListTile(title:Text('Undo / Redo history'),subtitle:Text('250+ commands per document')),
          const ListTile(title:Text('Rulers, guides & grid'),subtitle:Text('Smart snapping and alignment')),
          const ListTile(title:Text('External keyboard'),subtitle:Text('Custom shortcuts and command palette')),
          const ListTile(title:Text('Stylus'),subtitle:Text('Pressure, palm rejection, quick tools')),
          const ListTile(title:Text('Typography'),subtitle:Text('Fonts, spacing, ligatures, RTL shaping')),
          const ListTile(title:Text('Spellcheck'),subtitle:Text('Language-aware dictionaries')),
        ]),
        section(t('security'),Icons.security_outlined,[
          SwitchListTile(value:widget.state.telemetry,onChanged:(v)=>widget.state.setFlag('telemetry',v),title:const Text('Anonymous diagnostics')),
          const ListTile(title:Text('App lock'),subtitle:Text('PIN, biometrics and timeout')),
          const ListTile(title:Text('Secure workspace'),subtitle:Text('Encrypt local metadata and recent files')),
          const ListTile(title:Text('Protected documents'),subtitle:Text('Password and permission handling')),
        ]),
        section(t('performance'),Icons.speed_rounded,[
          const ListTile(title:Text('Large document mode'),subtitle:Text('Virtualized pages, slides and spreadsheet rows')),
          const ListTile(title:Text('Rendering'),subtitle:Text('Progressive raster, cache, GPU-first painting')),
          const ListTile(title:Text('Battery'),subtitle:Text('Adaptive background scheduling')),
          const ListTile(title:Text('Cache'),subtitle:Text('Manual cleanup and automatic trimming')),
        ]),
        section(t('accessibility'),Icons.accessibility_new_rounded,[
          const ListTile(title:Text('Text scaling'),subtitle:Text('80%–200%')),
          const ListTile(title:Text('High contrast'),subtitle:Text('Strengthened controls and focus rings')),
          const ListTile(title:Text('Reduced motion'),subtitle:Text('Minimize non-essential animations')),
          const ListTile(title:Text('Screen reader'),subtitle:Text('Semantics and keyboard navigation')),
        ]),
        section('Power user',Icons.developer_mode_rounded,[
          const ListTile(title:Text('Command palette'),subtitle:Text('Search every action and shortcut')),
          const ListTile(title:Text('Feature flags'),subtitle:Text('Preview experimental document engines')),
          const ListTile(title:Text('Compatibility mode'),subtitle:Text('Strict / Balanced / Maximum preservation')),
          const ListTile(title:Text('Recovery center'),subtitle:Text('Recover interrupted edits')),
          const ListTile(title:Text('Diagnostics'),subtitle:Text('Export logs without document content')),
        ]),
      ]),
    );
  }
}

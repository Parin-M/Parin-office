import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/theme_catalog.dart';

enum AppearanceMode { system, light, dark, amoled }

class AppState extends ChangeNotifier {
  Locale _locale=const Locale('en');
  AppearanceMode _mode=AppearanceMode.system;
  int _themeIndex=12;
  bool _compactToolbar=false,_animations=true,_haptics=true,_autosave=true,_telemetry=false;

  Locale get locale=>_locale;
  AppearanceMode get mode=>_mode;
  int get themeIndex=>_themeIndex;
  bool get compactToolbar=>_compactToolbar;
  bool get animations=>_animations;
  bool get haptics=>_haptics;
  bool get autosave=>_autosave;
  bool get telemetry=>_telemetry;
  ThemePreset get preset=>ThemeCatalog.presets[_themeIndex];
  bool get amoled=>_mode==AppearanceMode.amoled;

  Future<void> load() async {
    final p=await SharedPreferences.getInstance();
    final raw=p.getString('locale');
    if(raw!=null){final parts=raw.split('-');_locale=parts.length>1?Locale(parts[0],parts[1]):Locale(parts[0]);}
    _mode=AppearanceMode.values.firstWhere((x)=>x.name==p.getString('appearanceMode'),orElse:()=>AppearanceMode.system);
    _themeIndex=(p.getInt('themeIndex')??12).clamp(0,ThemeCatalog.presets.length-1);
    _compactToolbar=p.getBool('compactToolbar')??false;
    _animations=p.getBool('animations')??true;
    _haptics=p.getBool('haptics')??true;
    _autosave=p.getBool('autosave')??true;
    _telemetry=p.getBool('telemetry')??false;
    notifyListeners();
  }

  Future<void> setLocale(Locale v) async{_locale=v;notifyListeners();final p=await SharedPreferences.getInstance();await p.setString('locale',v.toLanguageTag());}
  Future<void> setMode(AppearanceMode v) async{_mode=v;notifyListeners();final p=await SharedPreferences.getInstance();await p.setString('appearanceMode',v.name);}
  Future<void> setTheme(int v) async{_themeIndex=v.clamp(0,ThemeCatalog.presets.length-1);notifyListeners();final p=await SharedPreferences.getInstance();await p.setInt('themeIndex',_themeIndex);}
  Future<void> setFlag(String key,bool v) async{
    switch(key){case 'compactToolbar':_compactToolbar=v;case 'animations':_animations=v;case 'haptics':_haptics=v;case 'autosave':_autosave=v;case 'telemetry':_telemetry=v;}
    notifyListeners();final p=await SharedPreferences.getInstance();await p.setBool(key,v);
  }
  Brightness brightness(){final b=WidgetsBinding.instance.platformDispatcher.platformBrightness;switch(_mode){case AppearanceMode.system:return b;case AppearanceMode.light:return Brightness.light;case AppearanceMode.dark:case AppearanceMode.amoled:return Brightness.dark;}}
}

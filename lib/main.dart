import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;
import 'package:intl/date_symbol_data_local.dart' as intl_data;
import 'package:shared_preferences/shared_preferences.dart';
import 'document_factory.dart';

Future<void> main() async { WidgetsFlutterBinding.ensureInitialized(); await intl_data.initializeDateFormatting(); runApp(const ParinOfficeApp()); }

enum AppearanceMode { system, light, dark, amoled }

class ThemePreset {
  const ThemePreset({required this.name,required this.primary,required this.secondary,required this.family});
  final String name;
  final Color primary,secondary;
  final String family;
}
class ThemeCatalog {
  static const families=<String>['Ocean','Arctic','Mint','Forest','Sage','Lime','Sunset','Coral','Rose','Berry','Violet','Indigo','Midnight','Stone','Sand','Mono'];
  static const hues=<double>[214,194,164,145,112,84,26,8,342,320,276,244,225,210,37,0];
  static final presets=List<ThemePreset>.generate(128,(i){
    final f=i~/8; final v=i%8; final neutral=f==15;
    final hue=neutral?220.0:(hues[f]+v*3.2)%360;
    final sat=neutral?0.04:0.52+(v%3)*0.07;
    final light=0.37+(v%5)*0.045;
    final primary=HSLColor.fromAHSL(1,hue,sat,light).toColor();
    final secondary=HSLColor.fromAHSL(1,(hue+18)%360,sat*0.78,(light+0.08).clamp(0.0,1.0)).toColor();
    return ThemePreset(name:families[f]+' '+(v+1).toString(),primary:primary,secondary:secondary,family:families[f]);
  });
  static Color _onAccent(Color background){
    const ink=Color(0xFF111522);
    final luminance=background.computeLuminance();
    final whiteContrast=1.05/(luminance+0.05);
    final inkContrast=(luminance+0.05)/(ink.computeLuminance()+0.05);
    return inkContrast>=whiteContrast?ink:Colors.white;
  }
  static ThemeData build(ThemePreset preset,Brightness brightness,bool amoled,{bool highContrast=false,bool compact=false}){
    final dark=brightness==Brightness.dark;
    final source=HSLColor.fromColor(preset.primary);
    final sourceSecondary=HSLColor.fromColor(preset.secondary);
    // Keep hue identity while normalizing contrast for every appearance mode.
    final primary=dark
      ?source.withLightness(0.69).withSaturation((source.saturation*1.05).clamp(0.0,1.0).toDouble()).toColor()
      :source.withLightness(source.lightness.clamp(0.31,0.42).toDouble()).toColor();
    final secondary=dark
      ?sourceSecondary.withLightness(0.73).toColor()
      :sourceSecondary.withLightness(sourceSecondary.lightness.clamp(0.34,0.44).toDouble()).toColor();
    final canvas=amoled?const Color(0xFF000000):dark?const Color(0xFF0B0F16):const Color(0xFFF5F7FB);
    final surface=amoled?const Color(0xFF080B11):dark?const Color(0xFF141923):Colors.white;
    final raised=amoled?const Color(0xFF10141D):dark?const Color(0xFF1C2330):Colors.white;
    final field=amoled?const Color(0xFF10141D):dark?const Color(0xFF1A202B):const Color(0xFFF1F4F9);
    final outline=dark?const Color(0xFF4B5565):const Color(0xFFD6DCE7);
    final outlineVariant=dark?const Color(0xFF303847):const Color(0xFFE2E7EF);
    final scheme=ColorScheme.fromSeed(
      seedColor:primary,
      brightness:brightness,
      contrastLevel:highContrast?1.0:0.12,
    ).copyWith(
      primary:primary,
      onPrimary:_onAccent(primary),
      secondary:secondary,
      onSecondary:_onAccent(secondary),
      surface:surface,
      surfaceContainerLowest:canvas,
      surfaceContainerLow:surface,
      surfaceContainer:raised,
      surfaceContainerHigh:raised,
      surfaceContainerHighest:dark?const Color(0xFF252D3A):const Color(0xFFE9EDF5),
      outline:outline,
      outlineVariant:outlineVariant,
      onSurface:dark?const Color(0xFFF2F5FA):const Color(0xFF182133),
      onSurfaceVariant:dark?const Color(0xFFB7C1D1):const Color(0xFF5E6A7D),
      inverseSurface:dark?const Color(0xFFE9EDF5):const Color(0xFF202838),
      inversePrimary:dark?preset.primary:primary,
    );
    return ThemeData(
      useMaterial3:true,
      visualDensity:compact?VisualDensity.compact:VisualDensity.standard,
      brightness:brightness,
      colorScheme:scheme,
      scaffoldBackgroundColor:canvas,
      canvasColor:surface,
      cardTheme:CardThemeData(
        color:raised,
        elevation:0,
        margin:EdgeInsets.zero,
        shape:RoundedRectangleBorder(
          borderRadius:BorderRadius.circular(18),
          side:BorderSide(color:outlineVariant),
        ),
      ),
      appBarTheme:AppBarTheme(
        centerTitle:false,
        elevation:0,
        scrolledUnderElevation:0,
        backgroundColor:canvas,
        surfaceTintColor:Colors.transparent,
        titleTextStyle:TextStyle(color:scheme.onSurface,fontSize:20,fontWeight:FontWeight.w800),
      ),
      dividerTheme:DividerThemeData(color:outlineVariant,thickness:1,space:1),
      inputDecorationTheme:InputDecorationTheme(
        filled:true,
        fillColor:field,
        contentPadding:const EdgeInsets.symmetric(horizontal:16,vertical:15),
        border:OutlineInputBorder(borderRadius:BorderRadius.circular(15),borderSide:BorderSide(color:outlineVariant)),
        enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(15),borderSide:BorderSide(color:outlineVariant)),
        focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(15),borderSide:BorderSide(color:primary,width:1.6)),
      ),
      filledButtonTheme:FilledButtonThemeData(style:FilledButton.styleFrom(
        foregroundColor:scheme.onPrimary,
        backgroundColor:primary,
        minimumSize:const Size(44,46),
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(15)),
        textStyle:const TextStyle(fontWeight:FontWeight.w800),
      )),
      outlinedButtonTheme:OutlinedButtonThemeData(style:OutlinedButton.styleFrom(
        minimumSize:const Size(44,44),
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(15)),
        side:BorderSide(color:outline),
      )),
      chipTheme:ChipThemeData(
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(13)),
        side:BorderSide(color:outlineVariant),
        padding:const EdgeInsets.symmetric(horizontal:6,vertical:5),
      ),
      navigationBarTheme:NavigationBarThemeData(
        backgroundColor:surface,
        indicatorColor:primary.withAlpha(dark?56:28),
        elevation:0,
        labelTextStyle:WidgetStateProperty.resolveWith((states)=>TextStyle(
          fontSize:12,
          fontWeight:states.contains(WidgetState.selected)?FontWeight.w800:FontWeight.w500,
          color:states.contains(WidgetState.selected)?primary:scheme.onSurfaceVariant,
        )),
      ),
      navigationRailTheme:NavigationRailThemeData(
        backgroundColor:surface,
        indicatorColor:primary.withAlpha(dark?56:28),
        selectedIconTheme:IconThemeData(color:primary),
        unselectedIconTheme:IconThemeData(color:scheme.onSurfaceVariant),
      ),
      snackBarTheme:SnackBarThemeData(behavior:SnackBarBehavior.floating,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16))),
      dialogTheme:DialogThemeData(backgroundColor:surface,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22))),
      bottomSheetTheme:BottomSheetThemeData(backgroundColor:surface,showDragHandle:true),
      switchTheme:SwitchThemeData(
        thumbColor:WidgetStateProperty.resolveWith((states)=>states.contains(WidgetState.selected)?scheme.onPrimary:scheme.onSurfaceVariant),
        trackColor:WidgetStateProperty.resolveWith((states)=>states.contains(WidgetState.selected)?primary:scheme.surfaceContainerHighest),
      ),
    );
  }
}
class RecentDocument {
  const RecentDocument({required this.name,required this.kind,required this.updatedAt});
  final String name; final OfficeKind kind; final DateTime updatedAt;
  Map<String,Object?> toJson()=>{'name':name,'kind':kind.name,'updatedAt':updatedAt.toIso8601String()};
  factory RecentDocument.fromJson(Map<String,dynamic> j)=>RecentDocument(
    name:j['name'] as String? ?? 'Document',
    kind:OfficeKind.values.firstWhere((k)=>k.name==j['kind'],orElse:()=>OfficeKind.pdf),
    updatedAt:DateTime.tryParse(j['updatedAt'] as String? ?? '') ?? DateTime.now());
}
class AppState extends ChangeNotifier {
  Locale locale=const Locale('en'); AppearanceMode mode=AppearanceMode.system; int themeIndex=0;
  double textScale=1,blueStrength=0.48;
  bool autosave=true,animations=true,haptics=true,compactRibbon=false,diagnostics=false;
  bool autoRecovery=true,blueLightFilter=false,highContrast=false,spellCheck=true,showGrid=true,focusMode=false,safeSave=true,keepRecent=true;
  bool showWordCount=true,smartCapitalization=true,openRecentOnStart=false;
  bool showWelcomePanel=true,showQuickActions=true,showDashboardMetrics=true,confirmRecentRemoval=true;
  String editorFontFamily='system';
  double lineSpacing=1.25;
  double autoSaveDelay=0.45,defaultFontSize=16;
  List<RecentDocument> recent=<RecentDocument>[];
  ThemePreset get preset=>ThemeCatalog.presets[themeIndex.clamp(0,127)];
  bool get amoled=>mode==AppearanceMode.amoled;
  bool flag(String key)=>switch(key){
    'autosave'=>autosave,'animations'=>animations,'haptics'=>haptics,'compact'=>compactRibbon,
    'diagnostics'=>diagnostics,'autoRecovery'=>autoRecovery,'blueLightFilter'=>blueLightFilter,
    'highContrast'=>highContrast,'spellCheck'=>spellCheck,'showGrid'=>showGrid,'focusMode'=>focusMode,
    'safeSave'=>safeSave,'keepRecent'=>keepRecent,'showWordCount'=>showWordCount,'smartCapitalization'=>smartCapitalization,'openRecentOnStart'=>openRecentOnStart,
    'showWelcomePanel'=>showWelcomePanel,'showQuickActions'=>showQuickActions,'showDashboardMetrics'=>showDashboardMetrics,'confirmRecentRemoval'=>confirmRecentRemoval,_=>false};
  Future<void> load() async {
    final p=await SharedPreferences.getInstance();
    final raw=p.getString('locale')??'en';final parts=raw.split('-');
    locale=parts.length>1?Locale(parts[0],parts[1]):Locale(parts[0]);
    mode=AppearanceMode.values.firstWhere((v)=>v.name==p.getString('mode'),orElse:()=>AppearanceMode.system);
    themeIndex=(p.getInt('theme')??0).clamp(0,127);
    textScale=(p.getDouble('textScale')??1).clamp(0.85,1.35);
    blueStrength=(p.getDouble('blueStrength')??0.48).clamp(0.0,1.0);
    autosave=p.getBool('autosave')??true;animations=p.getBool('animations')??true;
    haptics=p.getBool('haptics')??true;compactRibbon=p.getBool('compact')??false;
    diagnostics=p.getBool('diagnostics')??false;autoRecovery=p.getBool('autoRecovery')??true;
    blueLightFilter=p.getBool('blueLightFilter')??false;highContrast=p.getBool('highContrast')??false;
    spellCheck=p.getBool('spellCheck')??true;showGrid=p.getBool('showGrid')??true;
    focusMode=p.getBool('focusMode')??false;safeSave=p.getBool('safeSave')??true;keepRecent=p.getBool('keepRecent')??true;
    showWordCount=p.getBool('showWordCount')??true;smartCapitalization=p.getBool('smartCapitalization')??true;openRecentOnStart=p.getBool('openRecentOnStart')??false;
    autoSaveDelay=(p.getDouble('autoSaveDelay')??0.45).clamp(0.2,2.0);defaultFontSize=(p.getDouble('defaultFontSize')??16).clamp(13,22);
    editorFontFamily=switch(p.getString('editorFontFamily')){'serif'=>'serif','monospace'=>'monospace',_=>'system'};
    lineSpacing=(p.getDouble('lineSpacing')??1.25).clamp(1.0,2.0);
    showWelcomePanel=p.getBool('showWelcomePanel')??true;showQuickActions=p.getBool('showQuickActions')??true;
    showDashboardMetrics=p.getBool('showDashboardMetrics')??true;confirmRecentRemoval=p.getBool('confirmRecentRemoval')??true;
    try { final value=p.getString('recentDocuments'); if(value!=null)recent=(jsonDecode(value) as List<dynamic>).whereType<Map<String,dynamic>>().map(RecentDocument.fromJson).take(20).toList(); } catch (_) {recent=<RecentDocument>[];}
  }
  Future<void> setLocale(Locale v) async {locale=v;notifyListeners();final p=await SharedPreferences.getInstance();await p.setString('locale',v.toLanguageTag());}
  Future<void> setMode(AppearanceMode v) async {mode=v;notifyListeners();final p=await SharedPreferences.getInstance();await p.setString('mode',v.name);}
  Future<void> setTheme(int v) async {themeIndex=v.clamp(0,127);notifyListeners();final p=await SharedPreferences.getInstance();await p.setInt('theme',themeIndex);if(haptics)await HapticFeedback.selectionClick();}
  Future<void> setTextScale(double v) async {textScale=v.clamp(0.85,1.35);notifyListeners();final p=await SharedPreferences.getInstance();await p.setDouble('textScale',textScale);}
  Future<void> setAutoSaveDelay(double v) async {autoSaveDelay=v.clamp(0.2,2.0);notifyListeners();final p=await SharedPreferences.getInstance();await p.setDouble('autoSaveDelay',autoSaveDelay);}
  Future<void> setDefaultFontSize(double v) async {defaultFontSize=v.clamp(13,22);notifyListeners();final p=await SharedPreferences.getInstance();await p.setDouble('defaultFontSize',defaultFontSize);}
  Future<void> setEditorFontFamily(String v) async {editorFontFamily=switch(v){'serif'=>'serif','monospace'=>'monospace',_=>'system'};notifyListeners();final p=await SharedPreferences.getInstance();await p.setString('editorFontFamily',editorFontFamily);}
  Future<void> setLineSpacing(double v) async {lineSpacing=v.clamp(1.0,2.0);notifyListeners();final p=await SharedPreferences.getInstance();await p.setDouble('lineSpacing',lineSpacing);}
  Future<void> setBlueStrength(double v) async {blueStrength=v.clamp(0.0,1.0);notifyListeners();final p=await SharedPreferences.getInstance();await p.setDouble('blueStrength',blueStrength);}
  Future<void> setFlag(String key,bool v) async {
    switch(key){
      case 'autosave': autosave=v; break; case 'animations': animations=v; break; case 'haptics': haptics=v; break;
      case 'compact': compactRibbon=v; break; case 'diagnostics': diagnostics=v; break; case 'autoRecovery': autoRecovery=v; break;
      case 'blueLightFilter': blueLightFilter=v; break; case 'highContrast': highContrast=v; break; case 'spellCheck': spellCheck=v; break;
      case 'showGrid': showGrid=v; break; case 'focusMode': focusMode=v; break; case 'safeSave': safeSave=v; break; case 'keepRecent': keepRecent=v; break;
      case 'showWordCount': showWordCount=v; break; case 'smartCapitalization': smartCapitalization=v; break; case 'openRecentOnStart': openRecentOnStart=v; break;
      case 'showWelcomePanel': showWelcomePanel=v; break; case 'showQuickActions': showQuickActions=v; break;
      case 'showDashboardMetrics': showDashboardMetrics=v; break; case 'confirmRecentRemoval': confirmRecentRemoval=v; break;
    }
    notifyListeners();final p=await SharedPreferences.getInstance();await p.setBool(key,v);
  }
  Future<void> addRecent(String name,OfficeKind kind) async {
    if(!keepRecent)return;recent.removeWhere((d)=>d.name==name);
    recent.insert(0,RecentDocument(name:name,kind:kind,updatedAt:DateTime.now()));
    if(recent.length>20)recent=recent.take(20).toList();await _persistRecent();notifyListeners();
  }
  Future<void> removeRecent(String name) async {recent.removeWhere((d)=>d.name==name);await _persistRecent();notifyListeners();}
  Future<void> clearRecent() async {recent.clear();await _persistRecent();notifyListeners();}
  Future<void> _persistRecent() async {final p=await SharedPreferences.getInstance();await p.setString('recentDocuments',jsonEncode(recent.map((d)=>d.toJson()).toList()));}
  Future<Map<String,String>?> readDraft(OfficeKind kind) async {final p=await SharedPreferences.getInstance();final raw=p.getString('draft_'+kind.name);if(raw==null)return null;try{return Map<String,String>.from(jsonDecode(raw) as Map);}catch(_){return null;}}
  Future<void> saveDraft(OfficeKind kind,{required String title,required String body,required String subtitle}) async {
    if(!autosave)return;final p=await SharedPreferences.getInstance();await p.setString('draft_'+kind.name,jsonEncode({'title':title,'body':body,'subtitle':subtitle}));
  }
  Future<void> clearDraft(OfficeKind kind) async {final p=await SharedPreferences.getInstance();await p.remove('draft_'+kind.name);}
  Future<void> resetPreferences() async {
    final p=await SharedPreferences.getInstance();locale=const Locale('en');mode=AppearanceMode.system;themeIndex=0;textScale=1;blueStrength=0.48;
    autosave=true;animations=true;haptics=true;compactRibbon=false;diagnostics=false;autoRecovery=true;blueLightFilter=false;highContrast=false;
    spellCheck=true;showGrid=true;focusMode=false;safeSave=true;keepRecent=true;showWordCount=true;smartCapitalization=true;openRecentOnStart=false;
    showWelcomePanel=true;showQuickActions=true;showDashboardMetrics=true;confirmRecentRemoval=true;editorFontFamily='system';lineSpacing=1.25;autoSaveDelay=0.45;defaultFontSize=16;
    for(final key in ['locale','mode','theme','textScale','blueStrength','autosave','animations','haptics','compact','diagnostics','autoRecovery','blueLightFilter','highContrast','spellCheck','showGrid','focusMode','safeSave','keepRecent','showWordCount','smartCapitalization','openRecentOnStart','showWelcomePanel','showQuickActions','showDashboardMetrics','confirmRecentRemoval','editorFontFamily','lineSpacing','autoSaveDelay','defaultFontSize']){await p.remove(key);}
    notifyListeners();
  }
  Map<String,Object?> exportablePreferences()=>{'language':locale.toLanguageTag(),'appearance':mode.name,'theme':preset.name,'themeIndex':themeIndex,
    'textScale':textScale,'blueLightStrength':blueStrength,'editorFontFamily':editorFontFamily,'lineSpacing':lineSpacing,'settings':{'autosave':autosave,'animations':animations,'haptics':haptics,
    'compactRibbon':compactRibbon,'autoRecovery':autoRecovery,'blueLightFilter':blueLightFilter,'highContrast':highContrast,
    if(diagnostics) 'diagnosticsReport':{'build':'0.10','recentDocumentCount':recent.length,'draftRecovery':autoRecovery},
    'diagnostics':diagnostics,'spellCheck':spellCheck,'showGrid':showGrid,'focusMode':focusMode,'safeSave':safeSave,'keepRecent':keepRecent,
    'showWordCount':showWordCount,'smartCapitalization':smartCapitalization,'openRecentOnStart':openRecentOnStart,
    'showWelcomePanel':showWelcomePanel,'showQuickActions':showQuickActions,'showDashboardMetrics':showDashboardMetrics,'confirmRecentRemoval':confirmRecentRemoval,
    'autoSaveDelay':autoSaveDelay,'defaultFontSize':defaultFontSize}};
}
class L10n {
  static const locales=<Locale>[Locale('fa'),Locale('en'),Locale('da'),Locale('de'),Locale('de','CH'),Locale('ar'),Locale('hi'),Locale('he'),Locale('es'),Locale('it'),Locale('sv'),Locale('fi'),Locale('no'),Locale('is'),Locale('el'),Locale('tr')];
  static const names=<String>['فارسی','English','Dansk','Deutsch','Schweizerdeutsch','العربية','हिन्दी','עברית','Español','Italiano','Svenska','Suomi','Norsk','Íslenska','Ελληνικά','Türkçe'];
  static const en=<String,String>{
    'home':'Home','recent':'Recent','workspace':'Workspace','settings':'Settings','open':'Open file','create':'Create new','newDoc':'New document',
    'pdf':'PDF','word':'Word','powerpoint':'PowerPoint','excel':'Excel','welcome':'A calmer workspace for serious work',
    'welcomeSub':'Create, organize and export your documents from one place.','quick':'Quick actions','appearance':'Appearance','themes':'Color themes',
    'language':'Language','mode':'Display mode','system':'System','light':'Light','dark':'Dark','amoled':'AMOLED black',
    'general':'General','editor':'Editor','security':'Privacy & security','performance':'Performance','accessibility':'Accessibility',
    'searchSettings':'Search settings','blue':'Blue-light filter','blueSub':'Optional warm screen tint for evening work.',
    'textScale':'Text size','blueStrength':'Warm tint strength','reset':'Reset settings','export':'Export settings','cancel':'Cancel',
    'docTitle':'Document title','content':'Content','subtitle':'Subtitle','save':'Create and save','empty':'Your recent documents will appear here.',
    'noRecent':'No recent documents yet','clearRecent':'Clear recent list','autosave':'Autosave drafts','recovery':'Draft recovery',
    'motion':'Motion and transitions','haptics':'Haptic feedback','compact':'Compact toolbars','keepRecent':'Keep recent documents',
    'contrast':'High contrast','spell':'Text suggestions','grid':'Show workspace grid','focus':'Focus-friendly editor','safeSave':'Safer save flow',
    'diagnostics':'Anonymous diagnostics','resetQuestion':'Reset app preferences to their defaults?','paletteHint':'128 curated palettes for Light, Dark and AMOLED.',
    'createFirst':'Create your first document','search':'Search','restored':'Draft restored','saved':'File saved successfully','all':'All',
    'Cool':'Cool','Nature':'Nature','Warm':'Warm','Minimal':'Minimal','wordCount':'Live word count','smartCaps':'Smart capitalization','openRecentStart':'Open Recent at startup','saveDelay':'Autosave delay','defaultFontSize':'Editor font size'};
  static const fa=<String,String>{
    'home':'خانه','recent':'اخیر','workspace':'فضای کاری','settings':'تنظیمات','open':'باز کردن فایل','create':'ساخت فایل','newDoc':'سند جدید',
    'pdf':'PDF','word':'Word','powerpoint':'PowerPoint','excel':'Excel','welcome':'فضایی منظم‌تر برای کارهای حرفه‌ای',
    'welcomeSub':'سند بسازید، مدیریت کنید و خروجی بگیرید؛ همه در یک جا.','quick':'عملیات سریع','appearance':'ظاهر برنامه','themes':'تم‌های رنگی',
    'language':'زبان','mode':'حالت نمایش','system':'سیستم','light':'روشن','dark':'تاریک','amoled':'مشکی AMOLED','general':'عمومی',
    'editor':'ویرایشگر','security':'حریم خصوصی و امنیت','performance':'کارایی','accessibility':'دسترس‌پذیری','searchSettings':'جست‌وجو در تنظیمات',
    'blue':'فیلتر نور آبی','blueSub':'فیلتر گرم و اختیاری برای کار در شب.','textScale':'اندازه متن','blueStrength':'شدت فیلتر گرم',
    'reset':'بازنشانی تنظیمات','export':'خروجی تنظیمات','cancel':'لغو','docTitle':'عنوان سند','content':'محتوا','subtitle':'زیرعنوان',
    'save':'ساخت و ذخیره','empty':'سندهای اخیر شما اینجا نمایش داده می‌شوند.','noRecent':'هنوز سندی ندارید','clearRecent':'پاک‌کردن فهرست اخیر',
    'autosave':'ذخیره خودکار پیش‌نویس','recovery':'بازیابی پیش‌نویس','motion':'حرکت و گذارها','haptics':'بازخورد لمسی',
    'compact':'نوار ابزار فشرده','keepRecent':'نگهداری سندهای اخیر','contrast':'کنتراست بالا','spell':'پیشنهادهای نوشتاری',
    'grid':'نمایش شبکه فضای کاری','focus':'ویرایشگر متمرکز','safeSave':'ذخیره‌سازی ایمن‌تر','diagnostics':'گزارش ناشناس خطا',
    'resetQuestion':'تنظیمات برنامه به حالت پیش‌فرض برگردد؟','paletteHint':'۱۲۸ رنگ هماهنگ برای حالت روشن، تاریک و AMOLED.',
    'createFirst':'اولین سند خود را بسازید','search':'جست‌وجو','restored':'پیش‌نویس بازیابی شد','saved':'فایل با موفقیت ذخیره شد','all':'همه',
    'Cool':'سرد','Nature':'طبیعت','Warm':'گرم','Minimal':'مینیمال','wordCount':'شمارش زنده کلمات','smartCaps':'بزرگ‌نویسی خودکار','openRecentStart':'نمایش اسناد اخیر هنگام شروع','saveDelay':'فاصله ذخیره خودکار','defaultFontSize':'اندازه قلم ویرایشگر'};
  static const ar=<String,String>{
    'home':'الرئيسية','recent':'الأخيرة','workspace':'مساحة العمل','settings':'الإعدادات','open':'فتح ملف','create':'إنشاء جديد','newDoc':'مستند جديد',
    'pdf':'PDF','word':'Word','powerpoint':'PowerPoint','excel':'Excel','welcome':'مساحة منظمة للعمل الاحترافي',
    'welcomeSub':'أنشئ مستنداتك ونظّمها وصدّرها من مكان واحد.','quick':'إجراءات سريعة','appearance':'المظهر','themes':'ألوان السمات',
    'language':'اللغة','mode':'وضع العرض','system':'النظام','light':'فاتح','dark':'داكن','amoled':'أسود AMOLED','general':'عام',
    'editor':'المحرر','security':'الخصوصية والأمان','performance':'الأداء','accessibility':'إمكانية الوصول','searchSettings':'بحث في الإعدادات',
    'blue':'مرشح الضوء الأزرق','blueSub':'لون دافئ اختياري للعمل مساءً.','textScale':'حجم النص','blueStrength':'قوة اللون الدافئ',
    'reset':'إعادة ضبط الإعدادات','export':'تصدير الإعدادات','cancel':'إلغاء','docTitle':'عنوان المستند','content':'المحتوى','subtitle':'العنوان الفرعي',
    'save':'إنشاء وحفظ','empty':'ستظهر مستنداتك الأخيرة هنا.','noRecent':'لا توجد مستندات حديثة','clearRecent':'مسح القائمة',
    'autosave':'حفظ المسودات تلقائيًا','recovery':'استعادة المسودات','motion':'الحركة والانتقالات','haptics':'الاهتزاز اللمسي',
    'compact':'أشرطة أدوات مضغوطة','keepRecent':'الاحتفاظ بالمستندات الأخيرة','contrast':'تباين مرتفع','spell':'اقتراحات النص',
    'grid':'عرض الشبكة','focus':'محرر للتركيز','safeSave':'حفظ أكثر أمانًا','diagnostics':'تقارير مجهولة',
    'resetQuestion':'إعادة تفضيلات التطبيق إلى الوضع الافتراضي؟','paletteHint':'١٢٨ لونًا متناسقًا للأوضاع الفاتح والداكن وAMOLED.',
    'createFirst':'أنشئ مستندك الأول','search':'بحث','restored':'تمت استعادة المسودة','saved':'تم حفظ الملف بنجاح','all':'الكل',
    'Cool':'بارد','Nature':'طبيعة','Warm':'دافئ','Minimal':'بسيط','wordCount':'عداد الكلمات','smartCaps':'تكبير الحرف تلقائيًا','openRecentStart':'فتح الملفات الأخيرة عند التشغيل','saveDelay':'تأخير الحفظ التلقائي','defaultFontSize':'حجم خط المحرر'};
  static const de=<String,String>{'home':'Start','recent':'Zuletzt','workspace':'Arbeitsbereich','settings':'Einstellungen','open':'Datei öffnen','create':'Neu erstellen','newDoc':'Neues Dokument','pdf':'PDF','word':'Word','powerpoint':'PowerPoint','excel':'Excel','welcome':'Ein klarer Arbeitsbereich','welcomeSub':'Dokumente an einem Ort erstellen, ordnen und exportieren.','quick':'Schnellaktionen','appearance':'Darstellung','themes':'Farbthemen','language':'Sprache','mode':'Anzeigemodus','system':'System','light':'Hell','dark':'Dunkel','amoled':'AMOLED-Schwarz','general':'Allgemein','editor':'Editor','security':'Datenschutz & Sicherheit','performance':'Leistung','accessibility':'Barrierefreiheit','searchSettings':'Einstellungen suchen','blue':'Blaulichtfilter','blueSub':'Optionaler warmer Bildschirmton am Abend.','textScale':'Textgröße','blueStrength':'Wärmeintensität','reset':'Einstellungen zurücksetzen','export':'Einstellungen exportieren','cancel':'Abbrechen','docTitle':'Dokumenttitel','content':'Inhalt','subtitle':'Untertitel','save':'Erstellen und speichern','empty':'Ihre letzten Dokumente erscheinen hier.','noRecent':'Noch keine aktuellen Dokumente','clearRecent':'Liste leeren','autosave':'Entwürfe automatisch speichern','recovery':'Entwurfswiederherstellung','motion':'Bewegung und Übergänge','haptics':'Haptisches Feedback','compact':'Kompakte Symbolleisten','keepRecent':'Zuletzt verwendete Dokumente behalten','contrast':'Hoher Kontrast','spell':'Textvorschläge','grid':'Raster anzeigen','focus':'Fokus-Editor','safeSave':'Sicheres Speichern','diagnostics':'Anonyme Diagnose','resetQuestion':'App-Einstellungen auf Standard zurücksetzen?','paletteHint':'128 abgestimmte Paletten für Hell, Dunkel und AMOLED.','createFirst':'Erstes Dokument erstellen','search':'Suchen','restored':'Entwurf wiederhergestellt','saved':'Datei erfolgreich gespeichert','all':'Alle'};
  static const es=<String,String>{'home':'Inicio','recent':'Recientes','workspace':'Espacio de trabajo','settings':'Ajustes','open':'Abrir archivo','create':'Crear nuevo','newDoc':'Documento nuevo','pdf':'PDF','word':'Word','powerpoint':'PowerPoint','excel':'Excel','welcome':'Un espacio más claro para trabajar','welcomeSub':'Crea, organiza y exporta tus documentos en un solo lugar.','quick':'Acciones rápidas','appearance':'Apariencia','themes':'Temas de color','language':'Idioma','mode':'Modo de pantalla','system':'Sistema','light':'Claro','dark':'Oscuro','amoled':'Negro AMOLED','general':'General','editor':'Editor','security':'Privacidad y seguridad','performance':'Rendimiento','accessibility':'Accesibilidad','searchSettings':'Buscar ajustes','blue':'Filtro de luz azul','blueSub':'Tinte cálido opcional para la noche.','textScale':'Tamaño del texto','blueStrength':'Intensidad del tono cálido','reset':'Restablecer ajustes','export':'Exportar ajustes','cancel':'Cancelar','docTitle':'Título del documento','content':'Contenido','subtitle':'Subtítulo','save':'Crear y guardar','empty':'Tus documentos recientes aparecerán aquí.','noRecent':'Todavía no hay documentos recientes','clearRecent':'Vaciar lista','autosave':'Guardar borradores automáticamente','recovery':'Recuperación de borradores','motion':'Movimiento y transiciones','haptics':'Respuesta háptica','compact':'Barras compactas','keepRecent':'Conservar documentos recientes','contrast':'Alto contraste','spell':'Sugerencias de texto','grid':'Mostrar cuadrícula','focus':'Editor de concentración','safeSave':'Guardado seguro','diagnostics':'Diagnóstico anónimo','resetQuestion':'¿Restablecer los ajustes de la aplicación?','paletteHint':'128 paletas coordinadas para los modos claro, oscuro y AMOLED.','createFirst':'Crea tu primer documento','search':'Buscar','restored':'Borrador recuperado','saved':'Archivo guardado correctamente','all':'Todos'};
  static const tr=<String,String>{'home':'Ana sayfa','recent':'Son kullanılanlar','workspace':'Çalışma alanı','settings':'Ayarlar','open':'Dosya aç','create':'Yeni oluştur','newDoc':'Yeni belge','pdf':'PDF','word':'Word','powerpoint':'PowerPoint','excel':'Excel','welcome':'Daha düzenli bir çalışma alanı','welcomeSub':'Belgelerinizi tek yerden oluşturun, düzenleyin ve dışa aktarın.','quick':'Hızlı işlemler','appearance':'Görünüm','themes':'Renk temaları','language':'Dil','mode':'Görünüm modu','system':'Sistem','light':'Açık','dark':'Koyu','amoled':'AMOLED siyah','general':'Genel','editor':'Düzenleyici','security':'Gizlilik ve güvenlik','performance':'Performans','accessibility':'Erişilebilirlik','searchSettings':'Ayarları ara','blue':'Mavi ışık filtresi','blueSub':'Akşam çalışması için isteğe bağlı sıcak ton.','textScale':'Metin boyutu','blueStrength':'Sıcak ton yoğunluğu','reset':'Ayarları sıfırla','export':'Ayarları dışa aktar','cancel':'İptal','docTitle':'Belge başlığı','content':'İçerik','subtitle':'Alt başlık','save':'Oluştur ve kaydet','empty':'Son belgeleriniz burada görünecek.','noRecent':'Henüz son belge yok','clearRecent':'Son listeyi temizle','autosave':'Taslakları otomatik kaydet','recovery':'Taslak kurtarma','motion':'Hareket ve geçişler','haptics':'Dokunsal geri bildirim','compact':'Kompakt araç çubukları','keepRecent':'Son belgeleri sakla','contrast':'Yüksek kontrast','spell':'Metin önerileri','grid':'Izgarayı göster','focus':'Odak düzenleyicisi','safeSave':'Güvenli kaydetme','diagnostics':'Anonim tanılama','resetQuestion':'Uygulama tercihleri varsayılana sıfırlansın mı?','paletteHint':'Açık, koyu ve AMOLED için 128 renk paleti.','createFirst':'İlk belgenizi oluşturun','search':'Ara','restored':'Taslak kurtarıldı','saved':'Dosya başarıyla kaydedildi','all':'Tümü'};
  static const da=<String,String>{
    'home':'Hjem','recent':'Seneste','workspace':'Arbejdsområde','settings':'Indstillinger','open':'Åbn fil','create':'Opret ny','newDoc':'Nyt dokument',
    'welcome':'Et roligt arbejdsområde til seriøst arbejde','welcomeSub':'Opret, organiser og eksporter dokumenter ét sted.','quick':'Hurtige handlinger',
    'appearance':'Udseende','themes':'Farvetemaer','language':'Sprog','mode':'Visningstilstand','system':'System','light':'Lys','dark':'Mørk','amoled':'AMOLED-sort',
    'general':'Generelt','editor':'Editor','security':'Privatliv og sikkerhed','performance':'Ydeevne','accessibility':'Tilgængelighed','searchSettings':'Søg i indstillinger',
    'blue':'Blåt lys-filter','blueSub':'Valgfri varm skærmtone til aftenarbejde.','textScale':'Tekststørrelse','blueStrength':'Varm tone',
    'reset':'Nulstil indstillinger','export':'Eksporter indstillinger','cancel':'Annuller','docTitle':'Dokumenttitel','content':'Indhold','subtitle':'Undertitel','save':'Opret og gem',
    'empty':'Dine seneste dokumenter vises her.','noRecent':'Ingen seneste dokumenter','clearRecent':'Ryd listen','autosave':'Gem kladder automatisk',
    'recovery':'Gendan kladder','motion':'Bevægelse og overgange','haptics':'Haptisk feedback','compact':'Kompakte værktøjslinjer',
    'keepRecent':'Behold seneste dokumenter','contrast':'Høj kontrast','spell':'Tekstforslag','grid':'Vis gitter','focus':'Fokuseret editor',
    'safeSave':'Sikrere lagring','diagnostics':'Anonym diagnosticering','resetQuestion':'Nulstil appens indstillinger?','paletteHint':'128 koordinerede farvepaletter til lys, mørk og AMOLED.','saved':'Filen blev gemt','all':'Alle'};
  static const hi=<String,String>{
    'home':'होम','recent':'हाल के दस्तावेज़','workspace':'कार्यस्थल','settings':'सेटिंग्स','open':'फ़ाइल खोलें','create':'नया बनाएँ','newDoc':'नया दस्तावेज़',
    'welcome':'काम के लिए साफ़ और व्यवस्थित जगह','welcomeSub':'एक ही जगह पर दस्तावेज़ बनाएँ, व्यवस्थित करें और निर्यात करें।','quick':'त्वरित कार्रवाइयाँ',
    'appearance':'दिखावट','themes':'रंग थीम','language':'भाषा','mode':'डिस्प्ले मोड','system':'सिस्टम','light':'लाइट','dark':'डार्क','amoled':'AMOLED ब्लैक',
    'general':'सामान्य','editor':'एडिटर','security':'गोपनीयता और सुरक्षा','performance':'प्रदर्शन','accessibility':'सुलभता','searchSettings':'सेटिंग्स खोजें',
    'blue':'ब्लू-लाइट फ़िल्टर','blueSub':'शाम के लिए वैकल्पिक गर्म स्क्रीन रंग।','textScale':'टेक्स्ट आकार','blueStrength':'गर्म रंग की तीव्रता',
    'reset':'सेटिंग्स रीसेट करें','export':'सेटिंग्स निर्यात करें','cancel':'रद्द करें','docTitle':'दस्तावेज़ शीर्षक','content':'सामग्री','subtitle':'उपशीर्षक','save':'बनाएँ और सेव करें',
    'empty':'हाल के दस्तावेज़ यहाँ दिखाई देंगे।','noRecent':'अभी कोई हाल का दस्तावेज़ नहीं','clearRecent':'सूची साफ़ करें','autosave':'ड्राफ़्ट स्वतः सेव करें',
    'recovery':'ड्राफ़्ट रिकवरी','motion':'गतियाँ और ट्रांज़िशन','haptics':'हैप्टिक फ़ीडबैक','compact':'कॉम्पैक्ट टूलबार',
    'keepRecent':'हाल के दस्तावेज़ रखें','contrast':'उच्च कॉन्ट्रास्ट','spell':'टेक्स्ट सुझाव','grid':'ग्रिड दिखाएँ','focus':'फ़ोकस एडिटर',
    'safeSave':'सुरक्षित सेव','diagnostics':'अनाम डायग्नोस्टिक्स','resetQuestion':'ऐप सेटिंग्स को डिफ़ॉल्ट पर रीसेट करें?','paletteHint':'लाइट, डार्क और AMOLED के लिए 128 समन्वित रंग।','saved':'फ़ाइल सेव हुई','all':'सभी'};
  static const he=<String,String>{
    'home':'בית','recent':'אחרונים','workspace':'סביבת עבודה','settings':'הגדרות','open':'פתיחת קובץ','create':'יצירה חדשה','newDoc':'מסמך חדש',
    'welcome':'סביבת עבודה נקייה ומאורגנת','welcomeSub':'יצירה, ארגון וייצוא של מסמכים במקום אחד.','quick':'פעולות מהירות',
    'appearance':'מראה','themes':'ערכות צבע','language':'שפה','mode':'מצב תצוגה','system':'מערכת','light':'בהיר','dark':'כהה','amoled':'שחור AMOLED',
    'general':'כללי','editor':'עורך','security':'פרטיות ואבטחה','performance':'ביצועים','accessibility':'נגישות','searchSettings':'חיפוש בהגדרות',
    'blue':'מסנן אור כחול','blueSub':'גוון חם אופציונלי לעבודה בערב.','textScale':'גודל טקסט','blueStrength':'עוצמת הגוון החם',
    'reset':'איפוס הגדרות','export':'ייצוא הגדרות','cancel':'ביטול','docTitle':'כותרת המסמך','content':'תוכן','subtitle':'כותרת משנה','save':'יצירה ושמירה',
    'empty':'המסמכים האחרונים יוצגו כאן.','noRecent':'אין עדיין מסמכים אחרונים','clearRecent':'ניקוי הרשימה','autosave':'שמירה אוטומטית של טיוטות',
    'recovery':'שחזור טיוטות','motion':'תנועה ומעברים','haptics':'משוב מישושי','compact':'סרגלי כלים קומפקטיים',
    'keepRecent':'שמירת מסמכים אחרונים','contrast':'ניגודיות גבוהה','spell':'הצעות טקסט','grid':'הצגת רשת','focus':'עורך ממוקד',
    'safeSave':'שמירה בטוחה','diagnostics':'אבחון אנונימי','resetQuestion':'לאפס את הגדרות האפליקציה?','paletteHint':'128 ערכות צבע מותאמות למצבים בהיר, כהה ו-AMOLED.','saved':'הקובץ נשמר','all':'הכול'};
  static const it=<String,String>{
    'home':'Home','recent':'Recenti','workspace':'Area di lavoro','settings':'Impostazioni','open':'Apri file','create':'Crea nuovo','newDoc':'Nuovo documento',
    'welcome':'Uno spazio ordinato per lavorare','welcomeSub':'Crea, organizza ed esporta documenti da un unico posto.','quick':'Azioni rapide',
    'appearance':'Aspetto','themes':'Temi colore','language':'Lingua','mode':'Modalità schermo','system':'Sistema','light':'Chiaro','dark':'Scuro','amoled':'Nero AMOLED',
    'general':'Generale','editor':'Editor','security':'Privacy e sicurezza','performance':'Prestazioni','accessibility':'Accessibilità','searchSettings':'Cerca impostazioni',
    'blue':'Filtro luce blu','blueSub':'Tinta calda opzionale per la sera.','textScale':'Dimensione testo','blueStrength':'Intensità tonalità calda',
    'reset':'Reimposta impostazioni','export':'Esporta impostazioni','cancel':'Annulla','docTitle':'Titolo documento','content':'Contenuto','subtitle':'Sottotitolo','save':'Crea e salva',
    'empty':'I documenti recenti appariranno qui.','noRecent':'Nessun documento recente','clearRecent':'Svuota elenco','autosave':'Salva automaticamente le bozze',
    'recovery':'Recupero bozze','motion':'Movimento e transizioni','haptics':'Feedback aptico','compact':'Barre compatte',
    'keepRecent':'Mantieni documenti recenti','contrast':'Contrasto elevato','spell':'Suggerimenti di testo','grid':'Mostra griglia','focus':'Editor concentrato',
    'safeSave':'Salvataggio sicuro','diagnostics':'Diagnostica anonima','resetQuestion':'Ripristinare le impostazioni predefinite?','paletteHint':'128 palette coordinate per modalità chiara, scura e AMOLED.','saved':'File salvato','all':'Tutti'};
  static const sv=<String,String>{
    'home':'Hem','recent':'Senaste','workspace':'Arbetsyta','settings':'Inställningar','open':'Öppna fil','create':'Skapa nytt','newDoc':'Nytt dokument',
    'welcome':'En lugnare arbetsyta för seriöst arbete','welcomeSub':'Skapa, organisera och exportera dokument på ett ställe.','quick':'Snabbåtgärder',
    'appearance':'Utseende','themes':'Färgteman','language':'Språk','mode':'Visningsläge','system':'System','light':'Ljust','dark':'Mörkt','amoled':'AMOLED-svart',
    'general':'Allmänt','editor':'Redigerare','security':'Integritet och säkerhet','performance':'Prestanda','accessibility':'Tillgänglighet','searchSettings':'Sök inställningar',
    'blue':'Blåljusfilter','blueSub':'Valfri varm skärmton för kvällsarbete.','textScale':'Textstorlek','blueStrength':'Varm tonstyrka',
    'reset':'Återställ inställningar','export':'Exportera inställningar','cancel':'Avbryt','docTitle':'Dokumenttitel','content':'Innehåll','subtitle':'Underrubrik','save':'Skapa och spara',
    'empty':'Dina senaste dokument visas här.','noRecent':'Inga senaste dokument','clearRecent':'Rensa listan','autosave':'Spara utkast automatiskt',
    'recovery':'Återställ utkast','motion':'Rörelse och övergångar','haptics':'Haptisk återkoppling','compact':'Kompakta verktygsfält',
    'keepRecent':'Behåll senaste dokument','contrast':'Hög kontrast','spell':'Textförslag','grid':'Visa rutnät','focus':'Fokusredigerare',
    'safeSave':'Säkrare sparning','diagnostics':'Anonym diagnostik','resetQuestion':'Återställa appinställningarna?','paletteHint':'128 samordnade paletter för ljust, mörkt och AMOLED.','saved':'Filen har sparats','all':'Alla'};
  static const fi=<String,String>{
    'home':'Koti','recent':'Viimeisimmät','workspace':'Työtila','settings':'Asetukset','open':'Avaa tiedosto','create':'Luo uusi','newDoc':'Uusi asiakirja',
    'welcome':'Selkeä työtila tärkeille töille','welcomeSub':'Luo, järjestä ja vie asiakirjoja yhdessä paikassa.','quick':'Pikatoiminnot',
    'appearance':'Ulkoasu','themes':'Väriteemat','language':'Kieli','mode':'Näyttötila','system':'Järjestelmä','light':'Vaalea','dark':'Tumma','amoled':'AMOLED-musta',
    'general':'Yleinen','editor':'Muokkain','security':'Tietosuoja ja turvallisuus','performance':'Suorituskyky','accessibility':'Esteettömyys','searchSettings':'Hae asetuksista',
    'blue':'Sinivalosuodatin','blueSub':'Valinnainen lämmin sävy iltakäyttöön.','textScale':'Tekstin koko','blueStrength':'Lämpimän sävyn voimakkuus',
    'reset':'Palauta asetukset','export':'Vie asetukset','cancel':'Peruuta','docTitle':'Asiakirjan otsikko','content':'Sisältö','subtitle':'Alaotsikko','save':'Luo ja tallenna',
    'empty':'Viimeisimmät asiakirjat näkyvät täällä.','noRecent':'Ei viimeaikaisia asiakirjoja','clearRecent':'Tyhjennä luettelo','autosave':'Tallenna luonnokset automaattisesti',
    'recovery':'Palauta luonnokset','motion':'Liike ja siirtymät','haptics':'Kosketuspalaute','compact':'Kompaktit työkalurivit',
    'keepRecent':'Säilytä viimeisimmät asiakirjat','contrast':'Suuri kontrasti','spell':'Tekstiehdotukset','grid':'Näytä ruudukko','focus':'Keskittyvä muokkain',
    'safeSave':'Turvallisempi tallennus','diagnostics':'Anonyymi diagnostiikka','resetQuestion':'Palautetaanko oletusasetukset?','paletteHint':'128 yhteensopivaa palettia vaaleaan, tummaan ja AMOLED-tilaan.','saved':'Tiedosto tallennettu','all':'Kaikki'};
  static const no=<String,String>{
    'home':'Hjem','recent':'Nylige','workspace':'Arbeidsområde','settings':'Innstillinger','open':'Åpne fil','create':'Opprett ny','newDoc':'Nytt dokument',
    'welcome':'En ryddig arbeidsflate for seriøst arbeid','welcomeSub':'Opprett, organiser og eksporter dokumenter på ett sted.','quick':'Hurtighandlinger',
    'appearance':'Utseende','themes':'Fargetemaer','language':'Språk','mode':'Visningsmodus','system':'System','light':'Lys','dark':'Mørk','amoled':'AMOLED-svart',
    'general':'Generelt','editor':'Redigerer','security':'Personvern og sikkerhet','performance':'Ytelse','accessibility':'Tilgjengelighet','searchSettings':'Søk i innstillinger',
    'blue':'Blålysfilter','blueSub':'Valgfri varm skjermtone for kveldsarbeid.','textScale':'Tekststørrelse','blueStrength':'Varm tonestyrke',
    'reset':'Tilbakestill innstillinger','export':'Eksporter innstillinger','cancel':'Avbryt','docTitle':'Dokumenttittel','content':'Innhold','subtitle':'Undertittel','save':'Opprett og lagre',
    'empty':'Dine nylige dokumenter vises her.','noRecent':'Ingen nylige dokumenter','clearRecent':'Tøm listen','autosave':'Lagre utkast automatisk',
    'recovery':'Gjenopprett utkast','motion':'Bevegelse og overganger','haptics':'Haptisk tilbakemelding','compact':'Kompakte verktøylinjer',
    'keepRecent':'Behold nylige dokumenter','contrast':'Høy kontrast','spell':'Tekstforslag','grid':'Vis rutenett','focus':'Fokusredigerer',
    'safeSave':'Tryggere lagring','diagnostics':'Anonym diagnostikk','resetQuestion':'Tilbakestille appinnstillingene?','paletteHint':'128 koordinerte paletter for lys, mørk og AMOLED.','saved':'Filen er lagret','all':'Alle'};
  static const islandic=<String,String>{
    'home':'Heim','recent':'Nýlegt','workspace':'Vinnusvæði','settings':'Stillingar','open':'Opna skrá','create':'Búa til nýtt','newDoc':'Nýtt skjal',
    'welcome':'Skipulagt vinnusvæði fyrir mikilvæg verkefni','welcomeSub':'Búðu til, skipuleggðu og fluttu út skjöl á einum stað.','quick':'Flýtiaðgerðir',
    'appearance':'Útlit','themes':'Litþemu','language':'Tungumál','mode':'Skjástilling','system':'Kerfi','light':'Ljóst','dark':'Dökkt','amoled':'AMOLED-svart',
    'general':'Almennt','editor':'Ritill','security':'Persónuvernd og öryggi','performance':'Afköst','accessibility':'Aðgengi','searchSettings':'Leita í stillingum',
    'blue':'Bláljósasía','blueSub':'Valfrjáls hlý litun fyrir kvöldvinnu.','textScale':'Textastærð','blueStrength':'Styrkur hlýja litarins',
    'reset':'Endurstilla stillingar','export':'Flytja út stillingar','cancel':'Hætta við','docTitle':'Titill skjals','content':'Efni','subtitle':'Undirtitill','save':'Búa til og vista',
    'empty':'Nýleg skjöl birtast hér.','noRecent':'Engin nýleg skjöl','clearRecent':'Hreinsa lista','autosave':'Vista drög sjálfvirkt',
    'recovery':'Endurheimta drög','motion':'Hreyfing og umbreytingar','haptics':'Snertiviðbrögð','compact':'Þétt verkfæraspjöld',
    'keepRecent':'Halda nýlegum skjölum','contrast':'Mikil birtuskil','spell':'Textatillögur','grid':'Sýna hnitanet','focus':'Einbeittur ritill',
    'safeSave':'Öruggari vistun','diagnostics':'Nafnlaus greining','resetQuestion':'Endurstilla stillingar forritsins?','paletteHint':'128 samræmdir litir fyrir ljóst, dökkt og AMOLED.','saved':'Skrá vistuð','all':'Allt'};
  static const el=<String,String>{
    'home':'Αρχική','recent':'Πρόσφατα','workspace':'Χώρος εργασίας','settings':'Ρυθμίσεις','open':'Άνοιγμα αρχείου','create':'Δημιουργία νέου','newDoc':'Νέο έγγραφο',
    'welcome':'Ένας καθαρός χώρος για σοβαρή εργασία','welcomeSub':'Δημιουργήστε, οργανώστε και εξαγάγετε έγγραφα σε ένα μέρος.','quick':'Γρήγορες ενέργειες',
    'appearance':'Εμφάνιση','themes':'Χρωματικά θέματα','language':'Γλώσσα','mode':'Λειτουργία εμφάνισης','system':'Σύστημα','light':'Φωτεινό','dark':'Σκούρο','amoled':'AMOLED μαύρο',
    'general':'Γενικά','editor':'Επεξεργαστής','security':'Απόρρητο και ασφάλεια','performance':'Απόδοση','accessibility':'Προσβασιμότητα','searchSettings':'Αναζήτηση ρυθμίσεων',
    'blue':'Φίλτρο μπλε φωτός','blueSub':'Προαιρετική θερμή απόχρωση για βραδινή εργασία.','textScale':'Μέγεθος κειμένου','blueStrength':'Ένταση θερμής απόχρωσης',
    'reset':'Επαναφορά ρυθμίσεων','export':'Εξαγωγή ρυθμίσεων','cancel':'Ακύρωση','docTitle':'Τίτλος εγγράφου','content':'Περιεχόμενο','subtitle':'Υπότιτλος','save':'Δημιουργία και αποθήκευση',
    'empty':'Τα πρόσφατα έγγραφά σας θα εμφανίζονται εδώ.','noRecent':'Δεν υπάρχουν πρόσφατα έγγραφα','clearRecent':'Εκκαθάριση λίστας','autosave':'Αυτόματη αποθήκευση προσχεδίων',
    'recovery':'Ανάκτηση προσχεδίων','motion':'Κίνηση και μεταβάσεις','haptics':'Απτική ανάδραση','compact':'Συμπαγείς γραμμές εργαλείων',
    'keepRecent':'Διατήρηση πρόσφατων εγγράφων','contrast':'Υψηλή αντίθεση','spell':'Προτάσεις κειμένου','grid':'Εμφάνιση πλέγματος','focus':'Εστιασμένος επεξεργαστής',
    'safeSave':'Ασφαλέστερη αποθήκευση','diagnostics':'Ανώνυμα διαγνωστικά','resetQuestion':'Επαναφορά προτιμήσεων εφαρμογής;','paletteHint':'128 συντονισμένες παλέτες για φωτεινή, σκοτεινή και AMOLED λειτουργία.','saved':'Το αρχείο αποθηκεύτηκε','all':'Όλα'};


  static const extra=<String,Map<String,String>>{
    'en':{'Cool':'Cool','Nature':'Nature','Warm':'Warm','Minimal':'Minimal','createFirst':'Create your first document','wordCount':'Live word count','smartCaps':'Smart capitalization','openRecentStart':'Open Recent at startup','saveDelay':'Autosave delay','defaultFontSize':'Editor font size','pdf':'PDF','word':'Word','powerpoint':'PowerPoint','excel':'Excel','restored':'Draft restored','search':'Search','fontFamily':'Editor font family','fontSystem':'System','fontSerif':'Serif','fontMono':'Monospace','lineSpacing':'Line spacing','dashboardOptions':'Dashboard personalization','showWelcomePanel':'Show welcome panel','showQuickActions':'Show quick actions','showDashboardMetrics':'Show dashboard metrics','confirmRecentRemoval':'Confirm before removing recent items','metricThemes':'Themes','metricLanguages':'Languages','metricLayout':'Layout','metricPrivacy':'Privacy','activePalette':'Active palette','responsiveNavigation':'Responsive navigation','rtl':'Right to left','ltr':'Left to right'},
    'fa':{'Cool':'سرد','Nature':'طبیعت','Warm':'گرم','Minimal':'مینیمال','createFirst':'اولین سند خود را بسازید','wordCount':'شمارش زنده کلمات','smartCaps':'بزرگ‌نویسی خودکار','openRecentStart':'نمایش اسناد اخیر هنگام شروع','saveDelay':'فاصله ذخیره خودکار','defaultFontSize':'اندازه قلم ویرایشگر','pdf':'PDF','word':'Word','powerpoint':'PowerPoint','excel':'Excel','restored':'پیش‌نویس بازیابی شد','search':'جست‌وجو','fontFamily':'قلم ویرایشگر','fontSystem':'سیستمی','fontSerif':'سریف','fontMono':'تک‌فاصله','lineSpacing':'فاصله خطوط','dashboardOptions':'شخصی‌سازی داشبورد','showWelcomePanel':'نمایش پنل خوش‌آمدگویی','showQuickActions':'نمایش عملیات سریع','showDashboardMetrics':'نمایش آمار داشبورد','confirmRecentRemoval':'تأیید پیش از حذف از فهرست اخیر','metricThemes':'تم‌ها','metricLanguages':'زبان‌ها','metricLayout':'چیدمان','metricPrivacy':'حریم خصوصی','activePalette':'تم فعال','responsiveNavigation':'ناوبری واکنش‌گرا','rtl':'راست‌به‌چپ','ltr':'چپ‌به‌راست'},
    'ar':{'Cool':'بارد','Nature':'طبيعة','Warm':'دافئ','Minimal':'بسيط','createFirst':'أنشئ مستندك الأول','wordCount':'عداد الكلمات المباشر','smartCaps':'تكبير الأحرف تلقائيًا','openRecentStart':'فتح الأخيرة عند التشغيل','saveDelay':'تأخير الحفظ التلقائي','defaultFontSize':'حجم خط المحرر','pdf':'PDF','word':'Word','powerpoint':'PowerPoint','excel':'Excel','restored':'تمت استعادة المسودة','search':'بحث','fontFamily':'خط المحرر','fontSystem':'النظام','fontSerif':'Serif','fontMono':'Monospace','lineSpacing':'تباعد الأسطر','dashboardOptions':'تخصيص لوحة المعلومات','showWelcomePanel':'إظهار لوحة الترحيب','showQuickActions':'إظهار الإجراءات السريعة','showDashboardMetrics':'إظهار إحصاءات اللوحة','confirmRecentRemoval':'التأكيد قبل إزالة العناصر الأخيرة','metricThemes':'السمات','metricLanguages':'اللغات','metricLayout':'التخطيط','metricPrivacy':'الخصوصية','activePalette':'السمة النشطة','responsiveNavigation':'تنقل متكيف','rtl':'من اليمين إلى اليسار','ltr':'من اليسار إلى اليمين'},
    'de':{'Cool':'Kühl','Nature':'Natur','Warm':'Warm','Minimal':'Minimal','createFirst':'Erstes Dokument erstellen','wordCount':'Live-Wortzähler','smartCaps':'Automatische Großschreibung','openRecentStart':'Zuletzt verwendete beim Start öffnen','saveDelay':'Auto-Speicherintervall','defaultFontSize':'Editor-Schriftgröße','pdf':'PDF','word':'Word','powerpoint':'PowerPoint','excel':'Excel','restored':'Entwurf wiederhergestellt','search':'Suchen','fontFamily':'Editor-Schriftart','fontSystem':'System','fontSerif':'Serif','fontMono':'Monospace','lineSpacing':'Zeilenabstand','dashboardOptions':'Dashboard anpassen','showWelcomePanel':'Willkommensbereich anzeigen','showQuickActions':'Schnellaktionen anzeigen','showDashboardMetrics':'Dashboard-Kennzahlen anzeigen','confirmRecentRemoval':'Entfernen zuletzt verwendeter Einträge bestätigen','metricThemes':'Themen','metricLanguages':'Sprachen','metricLayout':'Layout','metricPrivacy':'Datenschutz','activePalette':'Aktive Palette','responsiveNavigation':'Responsive Navigation','rtl':'Von rechts nach links','ltr':'Von links nach rechts'},
    'es':{'Cool':'Fríos','Nature':'Naturaleza','Warm':'Cálidos','Minimal':'Minimalistas','createFirst':'Crea tu primer documento','wordCount':'Recuento de palabras','smartCaps':'Mayúsculas inteligentes','openRecentStart':'Abrir recientes al iniciar','saveDelay':'Retardo de guardado automático','defaultFontSize':'Tamaño de letra del editor','pdf':'PDF','word':'Word','powerpoint':'PowerPoint','excel':'Excel','restored':'Borrador recuperado','search':'Buscar','fontFamily':'Fuente del editor','fontSystem':'Sistema','fontSerif':'Serif','fontMono':'Monoespaciada','lineSpacing':'Interlineado','dashboardOptions':'Personalización del panel','showWelcomePanel':'Mostrar bienvenida','showQuickActions':'Mostrar acciones rápidas','showDashboardMetrics':'Mostrar métricas del panel','confirmRecentRemoval':'Confirmar antes de quitar elementos recientes','metricThemes':'Temas','metricLanguages':'Idiomas','metricLayout':'Diseño','metricPrivacy':'Privacidad','activePalette':'Paleta activa','responsiveNavigation':'Navegación adaptable','rtl':'De derecha a izquierda','ltr':'De izquierda a derecha'},
    'tr':{'Cool':'Soğuk','Nature':'Doğa','Warm':'Sıcak','Minimal':'Minimal','createFirst':'İlk belgenizi oluşturun','wordCount':'Canlı kelime sayısı','smartCaps':'Akıllı büyük harf','openRecentStart':'Başlangıçta son belgeleri aç','saveDelay':'Otomatik kaydetme gecikmesi','defaultFontSize':'Düzenleyici yazı boyutu','pdf':'PDF','word':'Word','powerpoint':'PowerPoint','excel':'Excel','restored':'Taslak geri yüklendi','search':'Ara','fontFamily':'Düzenleyici yazı tipi','fontSystem':'Sistem','fontSerif':'Serif','fontMono':'Eş aralıklı','lineSpacing':'Satır aralığı','dashboardOptions':'Panel kişiselleştirme','showWelcomePanel':'Karşılama panelini göster','showQuickActions':'Hızlı işlemleri göster','showDashboardMetrics':'Panel ölçümlerini göster','confirmRecentRemoval':'Son öğeleri kaldırmadan önce onayla','metricThemes':'Temalar','metricLanguages':'Diller','metricLayout':'Düzen','metricPrivacy':'Gizlilik','activePalette':'Etkin palet','responsiveNavigation':'Uyarlanabilir gezinme','rtl':'Sağdan sola','ltr':'Soldan sağa'},
    'da':{'Cool':'Kølig','Nature':'Natur','Warm':'Varm','Minimal':'Minimal','createFirst':'Opret dit første dokument','wordCount':'Løbende ordtælling','smartCaps':'Automatisk stort begyndelsesbogstav','openRecentStart':'Åbn seneste ved start','saveDelay':'Forsinkelse for automatisk lagring','defaultFontSize':'Skriftstørrelse i editor','pdf':'PDF','word':'Word','powerpoint':'PowerPoint','excel':'Excel','restored':'Kladde gendannet','search':'Søg','fontFamily':'Skrifttype i editor','fontSystem':'System','fontSerif':'Serif','fontMono':'Monospace','lineSpacing':'Linjeafstand','dashboardOptions':'Tilpas dashboard','showWelcomePanel':'Vis velkomstpanel','showQuickActions':'Vis hurtige handlinger','showDashboardMetrics':'Vis dashboardtal','confirmRecentRemoval':'Bekræft før fjernelse fra seneste','metricThemes':'Temaer','metricLanguages':'Sprog','metricLayout':'Layout','metricPrivacy':'Privatliv','activePalette':'Aktiv palet','responsiveNavigation':'Responsiv navigation','rtl':'Højre mod venstre','ltr':'Venstre mod højre'},
    'hi':{'Cool':'ठंडे रंग','Nature':'प्रकृति','Warm':'गर्म रंग','Minimal':'मिनिमल','createFirst':'अपना पहला दस्तावेज़ बनाएँ','wordCount':'लाइव शब्द गणना','smartCaps':'स्मार्ट कैपिटलाइज़ेशन','openRecentStart':'शुरू होते ही हाल के दस्तावेज़ खोलें','saveDelay':'ऑटोसेव विलंब','defaultFontSize':'एडिटर फ़ॉन्ट आकार','pdf':'PDF','word':'Word','powerpoint':'PowerPoint','excel':'Excel','restored':'ड्राफ़्ट बहाल हुआ','search':'खोजें','fontFamily':'एडिटर फ़ॉन्ट','fontSystem':'सिस्टम','fontSerif':'सेरिफ़','fontMono':'मोनोस्पेस','lineSpacing':'पंक्ति अंतर','dashboardOptions':'डैशबोर्ड अनुकूलन','showWelcomePanel':'स्वागत पैनल दिखाएँ','showQuickActions':'त्वरित कार्रवाइयाँ दिखाएँ','showDashboardMetrics':'डैशबोर्ड आँकड़े दिखाएँ','confirmRecentRemoval':'हाल की सूची से हटाने से पहले पुष्टि','metricThemes':'थीम','metricLanguages':'भाषाएँ','metricLayout':'लेआउट','metricPrivacy':'गोपनीयता','activePalette':'सक्रिय पैलेट','responsiveNavigation':'अनुकूली नेविगेशन','rtl':'दाएँ से बाएँ','ltr':'बाएँ से दाएँ'},
    'he':{'Cool':'קרירים','Nature':'טבע','Warm':'חמים','Minimal':'מינימלי','createFirst':'יצירת המסמך הראשון','wordCount':'ספירת מילים חיה','smartCaps':'אותיות גדולות חכמות','openRecentStart':'פתיחת האחרונים בהפעלה','saveDelay':'השהיית שמירה אוטומטית','defaultFontSize':'גודל גופן בעורך','pdf':'PDF','word':'Word','powerpoint':'PowerPoint','excel':'Excel','restored':'הטיוטה שוחזרה','search':'חיפוש','fontFamily':'גופן העורך','fontSystem':'מערכת','fontSerif':'סריף','fontMono':'רוחב קבוע','lineSpacing':'ריווח שורות','dashboardOptions':'התאמה אישית של לוח המחוונים','showWelcomePanel':'הצגת לוח ברוכים הבאים','showQuickActions':'הצגת פעולות מהירות','showDashboardMetrics':'הצגת מדדים','confirmRecentRemoval':'אישור לפני הסרה מהרשימה האחרונה','metricThemes':'ערכות נושא','metricLanguages':'שפות','metricLayout':'פריסה','metricPrivacy':'פרטיות','activePalette':'ערכת צבע פעילה','responsiveNavigation':'ניווט רספונסיבי','rtl':'מימין לשמאל','ltr':'משמאל לימין'},
    'it':{'Cool':'Freddi','Nature':'Natura','Warm':'Caldi','Minimal':'Minimali','createFirst':'Crea il tuo primo documento','wordCount':'Conteggio parole in tempo reale','smartCaps':'Maiuscole automatiche','openRecentStart':'Apri recenti all’avvio','saveDelay':'Ritardo salvataggio automatico','defaultFontSize':'Dimensione carattere editor','pdf':'PDF','word':'Word','powerpoint':'PowerPoint','excel':'Excel','restored':'Bozza ripristinata','search':'Cerca','fontFamily':'Carattere editor','fontSystem':'Sistema','fontSerif':'Serif','fontMono':'Monospaziato','lineSpacing':'Interlinea','dashboardOptions':'Personalizzazione dashboard','showWelcomePanel':'Mostra pannello di benvenuto','showQuickActions':'Mostra azioni rapide','showDashboardMetrics':'Mostra metriche dashboard','confirmRecentRemoval':'Conferma rimozione dagli elementi recenti','metricThemes':'Temi','metricLanguages':'Lingue','metricLayout':'Layout','metricPrivacy':'Privacy','activePalette':'Palette attiva','responsiveNavigation':'Navigazione adattiva','rtl':'Da destra a sinistra','ltr':'Da sinistra a destra'},
    'sv':{'Cool':'Kalla','Nature':'Natur','Warm':'Varma','Minimal':'Minimalistiska','createFirst':'Skapa ditt första dokument','wordCount':'Ordräkning i realtid','smartCaps':'Smart versalisering','openRecentStart':'Öppna senaste vid start','saveDelay':'Fördröjning för autosparande','defaultFontSize':'Teckenstorlek i redigeraren','pdf':'PDF','word':'Word','powerpoint':'PowerPoint','excel':'Excel','restored':'Utkast återställt','search':'Sök','fontFamily':'Teckensnitt i redigeraren','fontSystem':'System','fontSerif':'Serif','fontMono':'Monospace','lineSpacing':'Radavstånd','dashboardOptions':'Anpassa instrumentpanelen','showWelcomePanel':'Visa välkomstpanel','showQuickActions':'Visa snabbåtgärder','showDashboardMetrics':'Visa nyckeltal','confirmRecentRemoval':'Bekräfta innan objekt tas bort från senaste','metricThemes':'Teman','metricLanguages':'Språk','metricLayout':'Layout','metricPrivacy':'Sekretess','activePalette':'Aktiv palett','responsiveNavigation':'Responsiv navigering','rtl':'Höger till vänster','ltr':'Vänster till höger'},
    'fi':{'Cool':'Viileät','Nature':'Luonto','Warm':'Lämpimät','Minimal':'Minimalistiset','createFirst':'Luo ensimmäinen asiakirjasi','wordCount':'Reaaliaikainen sanalaskuri','smartCaps':'Älykäs isojen kirjainten käyttö','openRecentStart':'Avaa viimeisimmät käynnistyksessä','saveDelay':'Automaattitallennuksen viive','defaultFontSize':'Muokkaimen fonttikoko','pdf':'PDF','word':'Word','powerpoint':'PowerPoint','excel':'Excel','restored':'Luonnos palautettu','search':'Hae','fontFamily':'Muokkaimen fontti','fontSystem':'Järjestelmä','fontSerif':'Serif','fontMono':'Tasavälinen','lineSpacing':'Riviväli','dashboardOptions':'Kojelaudan mukautus','showWelcomePanel':'Näytä tervetulopaneeli','showQuickActions':'Näytä pikatoiminnot','showDashboardMetrics':'Näytä kojelaudan mittarit','confirmRecentRemoval':'Vahvista ennen poistamista viimeisistä','metricThemes':'Teemat','metricLanguages':'Kielet','metricLayout':'Asettelu','metricPrivacy':'Tietosuoja','activePalette':'Aktiivinen paletti','responsiveNavigation':'Mukautuva navigointi','rtl':'Oikealta vasemmalle','ltr':'Vasemmalta oikealle'},
    'no':{'Cool':'Kalde','Nature':'Natur','Warm':'Varme','Minimal':'Minimalistiske','createFirst':'Opprett ditt første dokument','wordCount':'Løpende ordtelling','smartCaps':'Smart bruk av store bokstaver','openRecentStart':'Åpne nylige ved oppstart','saveDelay':'Forsinkelse for automatisk lagring','defaultFontSize':'Skriftstørrelse i editor','pdf':'PDF','word':'Word','powerpoint':'PowerPoint','excel':'Excel','restored':'Utkast gjenopprettet','search':'Søk','fontFamily':'Skrifttype i editor','fontSystem':'System','fontSerif':'Serif','fontMono':'Monospace','lineSpacing':'Linjeavstand','dashboardOptions':'Tilpass oversikten','showWelcomePanel':'Vis velkomstpanel','showQuickActions':'Vis hurtighandlinger','showDashboardMetrics':'Vis oversiktstall','confirmRecentRemoval':'Bekreft før nylige elementer fjernes','metricThemes':'Temaer','metricLanguages':'Språk','metricLayout':'Oppsett','metricPrivacy':'Personvern','activePalette':'Aktiv palett','responsiveNavigation':'Responsiv navigasjon','rtl':'Høyre til venstre','ltr':'Venstre til høyre'},
    'is':{'Cool':'Kaldir','Nature':'Náttúra','Warm':'Hlýir','Minimal':'Einfaldir','createFirst':'Búðu til fyrsta skjalið','wordCount':'Orðatalning í rauntíma','smartCaps':'Sjálfvirkir hástafir','openRecentStart':'Opna nýleg skjöl við ræsingu','saveDelay':'Töf á sjálfvirkri vistun','defaultFontSize':'Leturstærð ritils','pdf':'PDF','word':'Word','powerpoint':'PowerPoint','excel':'Excel','restored':'Drög endurheimt','search':'Leita','fontFamily':'Letur ritils','fontSystem':'Kerfisletur','fontSerif':'Serif','fontMono':'Einbreitt','lineSpacing':'Línubil','dashboardOptions':'Sérsníða mælaborð','showWelcomePanel':'Sýna kveðjuspjald','showQuickActions':'Sýna flýtiaðgerðir','showDashboardMetrics':'Sýna tölur mælaborðs','confirmRecentRemoval':'Staðfesta áður en nýleg atriði eru fjarlægð','metricThemes':'Þemu','metricLanguages':'Tungumál','metricLayout':'Skipulag','metricPrivacy':'Persónuvernd','activePalette':'Virkt litasafn','responsiveNavigation':'Aðlögunarhæf leiðsögn','rtl':'Hægri til vinstri','ltr':'Vinstri til hægri'},
    'el':{'Cool':'Ψυχρά','Nature':'Φύση','Warm':'Θερμά','Minimal':'Μινιμαλιστικά','createFirst':'Δημιουργήστε το πρώτο έγγραφο','wordCount':'Ζωντανή καταμέτρηση λέξεων','smartCaps':'Έξυπνα κεφαλαία','openRecentStart':'Άνοιγμα πρόσφατων κατά την εκκίνηση','saveDelay':'Καθυστέρηση αυτόματης αποθήκευσης','defaultFontSize':'Μέγεθος γραμματοσειράς επεξεργαστή','pdf':'PDF','word':'Word','powerpoint':'PowerPoint','excel':'Excel','restored':'Το πρόχειρο ανακτήθηκε','search':'Αναζήτηση','fontFamily':'Γραμματοσειρά επεξεργαστή','fontSystem':'Σύστημα','fontSerif':'Serif','fontMono':'Monospace','lineSpacing':'Διάστιχο','dashboardOptions':'Προσαρμογή πίνακα','showWelcomePanel':'Εμφάνιση πίνακα καλωσορίσματος','showQuickActions':'Εμφάνιση γρήγορων ενεργειών','showDashboardMetrics':'Εμφάνιση μετρικών','confirmRecentRemoval':'Επιβεβαίωση πριν από αφαίρεση πρόσφατων','metricThemes':'Θέματα','metricLanguages':'Γλώσσες','metricLayout':'Διάταξη','metricPrivacy':'Απόρρητο','activePalette':'Ενεργή παλέτα','responsiveNavigation':'Προσαρμοστική πλοήγηση','rtl':'Δεξιά προς αριστερά','ltr':'Αριστερά προς δεξιά'},
  };

  static String text(Locale locale,String key){
    final table=switch(locale.languageCode){
      'fa'=>fa,'ar'=>ar,'de'=>de,'es'=>es,'tr'=>tr,'da'=>da,'hi'=>hi,'he'=>he,'it'=>it,'sv'=>sv,'fi'=>fi,'no'=>no,'is'=>islandic,'el'=>el,_=>en};
    return table[key]??extra[locale.languageCode]?[key]??en[key]??extra['en']?[key]??key;
  }
  static bool rtl(Locale l)=>const {'fa','ar','he'}.contains(l.languageCode);
}class ParinOfficeApp extends StatefulWidget {
  const ParinOfficeApp({super.key});
  @override State<ParinOfficeApp> createState()=>_ParinOfficeAppState();
}
class _ParinOfficeAppState extends State<ParinOfficeApp>{
  final state=AppState();bool ready=false;
  @override void initState(){super.initState();state.load().whenComplete(() { if (mounted) setState(() => ready = true); });}
  @override void dispose(){state.dispose();super.dispose();}
  @override Widget build(BuildContext context){
    if(!ready)return const MaterialApp(home:Scaffold(body:Center(child:CircularProgressIndicator())));
    return AnimatedBuilder(animation:state,builder:(context,_)=>MaterialApp(
      title:'Parin Office',debugShowCheckedModeBanner:false,locale:state.locale,supportedLocales:L10n.locales,
      localizationsDelegates:const [GlobalMaterialLocalizations.delegate,GlobalWidgetsLocalizations.delegate,GlobalCupertinoLocalizations.delegate],
      localeResolutionCallback:(device,supported){for(final l in supported){if(l.toLanguageTag()==state.locale.toLanguageTag())return l;}for(final l in supported){if(l.languageCode==state.locale.languageCode)return l;}return const Locale('en');},
      theme:ThemeCatalog.build(state.preset,Brightness.light,false,highContrast:state.highContrast,compact:state.compactRibbon),
      darkTheme:ThemeCatalog.build(state.preset,Brightness.dark,state.amoled,highContrast:state.highContrast,compact:state.compactRibbon),
      themeMode:state.mode==AppearanceMode.system?ThemeMode.system:state.mode==AppearanceMode.light?ThemeMode.light:ThemeMode.dark,
      builder:(context,child)=>Directionality(textDirection:L10n.rtl(state.locale)?TextDirection.rtl:TextDirection.ltr,
        child:MediaQuery(data:MediaQuery.of(context).copyWith(textScaler:TextScaler.linear(state.textScale)),
          child:Stack(fit:StackFit.expand,children:[child??const SizedBox.shrink(),
            if(state.blueLightFilter)IgnorePointer(child:ColoredBox(color:Color.fromRGBO(255,153,64,0.32*state.blueStrength)))]))),
      home:Shell(state:state)));
  }
}
class BrandMark extends StatelessWidget{
  const BrandMark({super.key,this.size=42});final double size;
  @override Widget build(BuildContext context)=>Container(width:size,height:size,
    decoration:BoxDecoration(borderRadius:BorderRadius.circular(size*0.28),
      gradient:const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xFF2869F6),Color(0xFF7255DE)]),
      boxShadow:[BoxShadow(color:const Color(0xFF4169E8).withAlpha(45),blurRadius:size*0.32,offset:Offset(0,size*0.08))]),
    child:Stack(alignment:Alignment.center,children:[Text('P',style:TextStyle(color:Colors.white,fontSize:size*0.63,fontWeight:FontWeight.w900,height:1)),
      Positioned(right:size*0.16,bottom:size*0.17,child:Container(width:size*0.21,height:size*0.21,
        decoration:BoxDecoration(color:const Color(0xFF70E3D3),borderRadius:BorderRadius.circular(size*0.06),border:Border.all(color:Colors.white,width:size*0.025))))]));
}
class Shell extends StatefulWidget{
  const Shell({super.key,required this.state});final AppState state;
  @override State<Shell> createState()=>_ShellState();
}

class _ShellState extends State<Shell> {
  late int index=widget.state.openRecentOnStart&&widget.state.recent.isNotEmpty?1:0;
  @override Widget build(BuildContext context) {
    final t=(String key)=>L10n.text(widget.state.locale,key);
    final items=<(IconData,String)>[
      (Icons.space_dashboard_rounded,t('home')),(Icons.history_rounded,t('recent')),
      (Icons.grid_view_rounded,t('workspace')),(Icons.tune_rounded,t('settings'))];
    final pages=<Widget>[
      Dashboard(state:widget.state,openSettings:()=>setState(()=>index=3)),
      RecentPage(state:widget.state),WorkspaceHome(state:widget.state,openSettings:()=>setState(()=>index=3)),
      SettingsPage(state:widget.state)];
    return LayoutBuilder(builder:(context,c) {
      final desktop=c.maxWidth>=900,extended=c.maxWidth>=1180;
      final page=AnimatedSwitcher(duration:widget.state.animations?const Duration(milliseconds:220):Duration.zero,
        child:KeyedSubtree(key:ValueKey(index),child:pages[index]));
      if(desktop)return Scaffold(body:Row(children:[
        NavigationRail(selectedIndex:index,extended:extended,minExtendedWidth:238,onDestinationSelected:(v)=>setState(()=>index=v),
          leading:Padding(padding:const EdgeInsets.fromLTRB(14,18,14,24),child:Row(mainAxisSize:extended?MainAxisSize.max:MainAxisSize.min,children:[
            const BrandMark(size:40),if(extended)...[const SizedBox(width:10),const Flexible(child:Text('Parin Office',style:TextStyle(fontWeight:FontWeight.w900,fontSize:17)))]
          ])),
          destinations:items.map((x)=>NavigationRailDestination(icon:Icon(x.$1),selectedIcon:Icon(x.$1),label:Text(x.$2))).toList()),
        VerticalDivider(width:1,color:Theme.of(context).colorScheme.outlineVariant),Expanded(child:page)]));
      return Scaffold(body:page,bottomNavigationBar:NavigationBar(selectedIndex:index,onDestinationSelected:(v)=>setState(()=>index=v),
        destinations:items.map((x)=>NavigationDestination(icon:Icon(x.$1),selectedIcon:Icon(x.$1),label:x.$2)).toList()));
    });
  }
}

class Dashboard extends StatelessWidget {
  const Dashboard({super.key,required this.state,required this.openSettings});
  final AppState state;
  final VoidCallback openSettings;

  Future<void> openFile(BuildContext context) async {
    final files=await FilePicker.pickFiles(type:FileType.custom,allowedExtensions:const ['pdf','docx','pptx','xlsx']);
    if(!context.mounted||files.isEmpty)return;
    final file=files.first;
    final bytes=await file.readAsBytes();
    if(!context.mounted)return;
    final ext=(file.extension??'').toLowerCase();
    final kind=switch(ext){'docx'=>OfficeKind.word,'pptx'=>OfficeKind.powerpoint,'xlsx'=>OfficeKind.excel,_=>OfficeKind.pdf};
    await state.addRecent(file.name,kind);
    if(!context.mounted)return;
    if(kind==OfficeKind.pdf) {
      Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>PdfPage(bytes:bytes,name:file.name)));
    } else {
      Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>OfficePage(bytes:bytes,name:file.name,state:state)));
    }
  }

  void create(BuildContext context,OfficeKind kind) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>NewDocumentPage(kind:kind,state:state)));
  }

  void _showCreate(BuildContext context) {
    final t=(String key)=>L10n.text(state.locale,key);
    showModalBottomSheet<void>(context:context,showDragHandle:true,isScrollControlled:true,builder:(sheet)=>SafeArea(
      child:Padding(padding:const EdgeInsets.fromLTRB(18,8,18,24),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(t('newDoc'),style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w900)),
        const SizedBox(height:8),Text(t('welcomeSub')),const SizedBox(height:16),
        for(final kind in OfficeKind.values)
          ListTile(
            leading:Container(width:44,height:44,decoration:BoxDecoration(color:kind.color.withAlpha(24),borderRadius:BorderRadius.circular(14)),child:Icon(kind.icon,color:kind.color)),
            title:Text(kind.label,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text(kind.description),
            trailing:const Icon(Icons.arrow_forward_ios_rounded,size:16),
            onTap:(){Navigator.of(sheet).pop();create(context,kind);})
      ]))));
  }

  @override Widget build(BuildContext context) {
    final t=(String key)=>L10n.text(state.locale,key);
    final theme=Theme.of(context);
    return Scaffold(
      appBar:AppBar(
        title:const Row(children:[BrandMark(size:34),SizedBox(width:10),Text('Parin Office',style:TextStyle(fontWeight:FontWeight.w900))]),
        actions:[
          IconButton(tooltip:t('open'),onPressed:()=>openFile(context),icon:const Icon(Icons.folder_open_rounded)),
          IconButton(tooltip:t('settings'),onPressed:openSettings,icon:const Icon(Icons.tune_rounded)),
          const SizedBox(width:6)]),
      body:LayoutBuilder(builder:(context,constraints) {
        final columns=constraints.maxWidth>=1050?4:constraints.maxWidth>=620?2:1;
        return ListView(
          padding:const EdgeInsets.fromLTRB(20,18,20,30),
          children:[
            if(state.showWelcomePanel) Container(
              padding:const EdgeInsets.all(24),
              decoration:BoxDecoration(
                gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[
                  theme.colorScheme.primary.withAlpha(theme.brightness==Brightness.dark?52:28),
                  theme.colorScheme.secondary.withAlpha(theme.brightness==Brightness.dark?34:20),
                  theme.colorScheme.surface]),
                borderRadius:BorderRadius.circular(28),
                border:Border.all(color:theme.colorScheme.outlineVariant)),
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Container(padding:const EdgeInsets.symmetric(horizontal:11,vertical:7),
                  decoration:BoxDecoration(color:theme.colorScheme.primary.withAlpha(24),borderRadius:BorderRadius.circular(50)),
                  child:Text(t('workspace').toUpperCase(),style:TextStyle(color:theme.colorScheme.primary,fontSize:11,letterSpacing:1.2,fontWeight:FontWeight.w900))),
                const SizedBox(height:16),
                Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  const BrandMark(size:52),const SizedBox(width:14),
                  Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Text(t('welcome'),style:theme.textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.w900,height:1.12,letterSpacing:-0.5)),
                    const SizedBox(height:10),
                    Text(t('welcomeSub'),style:theme.textTheme.bodyLarge?.copyWith(color:theme.colorScheme.onSurfaceVariant,height:1.45))
                  ]))
                ]),
                const SizedBox(height:22),
                Wrap(spacing:10,runSpacing:10,children:[
                  FilledButton.icon(onPressed:()=>_showCreate(context),icon:const Icon(Icons.add_rounded),label:Text(t('create'))),
                  OutlinedButton.icon(onPressed:()=>openFile(context),icon:const Icon(Icons.file_open_rounded),label:Text(t('open')))
                ])
              ])),
            if(state.showWelcomePanel) const SizedBox(height:24),
            Row(children:[
              Expanded(child:Text(t('newDoc'),style:theme.textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w900))),
              Text('PDF · DOCX · PPTX · XLSX',style:theme.textTheme.labelSmall?.copyWith(letterSpacing:0.5,fontWeight:FontWeight.w900,color:theme.colorScheme.onSurfaceVariant))
            ]),
            const SizedBox(height:12),
            GridView.builder(
              shrinkWrap:true,
              physics:const NeverScrollableScrollPhysics(),
              itemCount:OfficeKind.values.length,
              gridDelegate:SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount:columns,crossAxisSpacing:13,mainAxisSpacing:13,childAspectRatio:columns==1?2.3:1.65),
              itemBuilder:(context,i){
                final kind=OfficeKind.values[i];
                return _DocTile(kind.label,kind.description,kind.icon,kind.color,()=>create(context,kind));
              }),
            if(state.showQuickActions) const SizedBox(height:23),
            if(state.showQuickActions) Text(t('quick'),style:theme.textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w900)),
            if(state.showQuickActions) const SizedBox(height:11),
            if(state.showQuickActions) Wrap(spacing:9,runSpacing:9,children:[
              ActionChip(avatar:const Icon(Icons.folder_open_rounded,size:18),label:Text(t('open')),onPressed:()=>openFile(context)),
              ActionChip(avatar:const Icon(Icons.palette_outlined,size:18),label:Text(t('themes')),onPressed:openSettings),
              ActionChip(avatar:const Icon(Icons.remove_red_eye_outlined,size:18),label:Text(t('blue')),onPressed:openSettings)
            ]),
            const SizedBox(height:24),
            if(state.showDashboardMetrics) Wrap(spacing:12,runSpacing:12,children:[
              _Metric(Icons.palette_outlined,L10n.text(state.locale,'metricThemes'),'128 palettes'),
              _Metric(Icons.translate_rounded,L10n.text(state.locale,'metricLanguages'),'16 locales'),
              _Metric(Icons.devices_rounded,L10n.text(state.locale,'metricLayout'),'Phone + tablet'),
              _Metric(Icons.shield_outlined,L10n.text(state.locale,'metricPrivacy'),'Local controls')
            ])
          ]);
      }));
  }
}


class _DocTile extends StatelessWidget{const _DocTile(this.title,this.subtitle,this.icon,this.color,this.onTap);final String title,subtitle;final IconData icon;final Color color;final VoidCallback onTap;@override Widget build(BuildContext c)=>Card(clipBehavior:Clip.antiAlias,child:InkWell(onTap:onTap,child:Padding(padding:const EdgeInsets.all(18),child:Row(children:[Container(width:58,height:58,decoration:BoxDecoration(color:color.withAlpha(30),borderRadius:BorderRadius.circular(18)),child:Icon(icon,color:color,size:30)),const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.center,children:[Text(title,style:Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w900)),const SizedBox(height:5),Text(subtitle)])),const Icon(Icons.chevron_right_rounded)]))));}
class _Metric extends StatelessWidget{const _Metric(this.icon,this.title,this.value);final IconData icon;final String title,value;@override Widget build(BuildContext c)=>Row(mainAxisSize:MainAxisSize.min,children:[Icon(icon),const SizedBox(width:9),Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontWeight:FontWeight.w800)),Text(value)])]);}

class NewDocumentPage extends StatefulWidget {
  const NewDocumentPage({super.key, required this.kind, required this.state});
  final OfficeKind kind;
  final AppState state;
  @override State<NewDocumentPage> createState() => _NewDocumentPageState();
}

class _NewDocumentPageState extends State<NewDocumentPage> {
  late final TextEditingController titleController, bodyController, subtitleController;
  Timer? timer;
  bool saving=false;
  @override void initState() {
    super.initState();
    titleController=TextEditingController(text:switch(widget.kind){OfficeKind.pdf=>'Untitled PDF',OfficeKind.word=>'Untitled document',OfficeKind.powerpoint=>'Untitled presentation',OfficeKind.excel=>'Untitled workbook'});
    bodyController=TextEditingController(text:switch(widget.kind){
      OfficeKind.pdf=>'Start writing your document here.\n\nParin Office keeps your work organized.',
      OfficeKind.word=>'Start writing here...\n\nAdd your ideas, notes and next steps.',
      OfficeKind.powerpoint=>'A clear outline for your next presentation.',
      OfficeKind.excel=>'Month,Revenue,Expenses\nJanuary,1200,450\nFebruary,1800,620\nMarch,2100,780'});
    subtitleController=TextEditingController(text:'Created with Parin Office');
    titleController.addListener(_queueDraft);bodyController.addListener(_queueDraft);subtitleController.addListener(_queueDraft);
    _restoreDraft();
  }
  Future<void> _restoreDraft() async {
    if(!widget.state.autoRecovery)return;
    final draft=await widget.state.readDraft(widget.kind);
    if(!mounted||draft==null)return;
    titleController.text=draft['title']??titleController.text;
    bodyController.text=draft['body']??bodyController.text;
    subtitleController.text=draft['subtitle']??subtitleController.text;
    if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(L10n.text(widget.state.locale,'restored'))));
  }
  void _queueDraft(){
    timer?.cancel();
    if(!widget.state.autosave)return;
    if(mounted)setState((){});
    timer=Timer(Duration(milliseconds:(widget.state.autoSaveDelay*1000).round()),()=>widget.state.saveDraft(widget.kind,title:titleController.text,body:bodyController.text,subtitle:subtitleController.text));
  }
  @override void dispose(){timer?.cancel();titleController.dispose();bodyController.dispose();subtitleController.dispose();super.dispose();}

  Future<void> _save() async {
    final t=(String key)=>L10n.text(widget.state.locale,key);
    final title=titleController.text.trim();
    if(title.isEmpty){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Enter a document title first.')));return;}
    setState(()=>saving=true);
    try {
      if(widget.state.safeSave){
        final confirmed=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(
          title:const Text('Confirm export'),
          content:Text('Create a new '+widget.kind.label+' file and open the save dialog?'),
          actions:[
            TextButton(onPressed:()=>Navigator.of(context).pop(false),child:Text(t('cancel'))),
            FilledButton(onPressed:()=>Navigator.of(context).pop(true),child:const Text('Continue'))
          ]));
        if(!mounted||confirmed!=true)return;
      }
      final bytes=await OfficeDocumentFactory.create(kind:widget.kind,title:title,body:bodyController.text,subtitle:subtitleController.text);
      if(!mounted)return;
      final name=title.replaceAll(RegExp(r'[\\/:*?"<>|]'),'').trim();
      final path=await FilePicker.saveFile(fileName:'${name.isEmpty?'Parin-Office':name}.${widget.kind.extension}',bytes:bytes,mimeType:widget.kind.mimeType,dialogTitle:'Save ${widget.kind.label}');
      if(!mounted)return;
      if(path!=null){
        await widget.state.addRecent('${name.isEmpty?'Parin-Office':name}.${widget.kind.extension}',widget.kind);
        await widget.state.clearDraft(widget.kind);
        if(widget.state.haptics)await HapticFeedback.mediumImpact();
        if(!mounted)return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(t('saved'))));
        Navigator.of(context).pop();
      }
    } catch(e) {
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Could not create file: $e')));
    } finally {if(mounted)setState(()=>saving=false);}
  }

  @override Widget build(BuildContext context){
    final theme=Theme.of(context);final t=(String key)=>L10n.text(widget.state.locale,key);
    return Scaffold(
      appBar:AppBar(title:Row(children:[
        Container(width:35,height:35,decoration:BoxDecoration(color:widget.kind.color.withAlpha(24),borderRadius:BorderRadius.circular(11)),child:Icon(widget.kind.icon,color:widget.kind.color)),
        const SizedBox(width:10),Expanded(child:Text(t('newDoc')))]),
        actions:[IconButton(onPressed:()=>Navigator.of(context).maybePop(),icon:const Icon(Icons.close_rounded))]),
      body:Center(child:ConstrainedBox(constraints:BoxConstraints(maxWidth:widget.state.focusMode?720:900),child:ListView(padding:const EdgeInsets.fromLTRB(20,12,20,32),children:[
        if(!widget.state.focusMode)
          Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:theme.colorScheme.surface,borderRadius:BorderRadius.circular(22),border:Border.all(color:theme.colorScheme.outlineVariant)),
          child:Row(children:[const BrandMark(size:44),const SizedBox(width:13),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(widget.kind.label,style:theme.textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w900)),
            const SizedBox(height:4),Text(widget.kind.description,style:theme.textTheme.bodySmall?.copyWith(color:theme.colorScheme.onSurfaceVariant))]))])),
        const SizedBox(height:17),
        TextField(controller:titleController,textInputAction:TextInputAction.next,decoration:InputDecoration(labelText:t('docTitle'),prefixIcon:const Icon(Icons.title_rounded))),
        if(widget.kind==OfficeKind.powerpoint)...[
          const SizedBox(height:13),TextField(controller:subtitleController,textInputAction:TextInputAction.next,decoration:InputDecoration(labelText:t('subtitle'),prefixIcon:const Icon(Icons.short_text_rounded)))],
        const SizedBox(height:13),
        TextField(controller:bodyController,minLines:widget.kind==OfficeKind.excel?9:12,maxLines:24,keyboardType:TextInputType.multiline,
          textCapitalization:widget.state.smartCapitalization?TextCapitalization.sentences:TextCapitalization.none,
          style:TextStyle(fontSize:widget.state.defaultFontSize,height:widget.state.lineSpacing,fontFamily:switch(widget.state.editorFontFamily){'serif'=>'serif','monospace'=>'monospace',_=>null}),autocorrect:widget.state.spellCheck,
          decoration:InputDecoration(alignLabelWithHint:true,labelText:widget.kind==OfficeKind.excel?'Sheet data (CSV)':t('content'),
            hintText:widget.kind==OfficeKind.excel?'Product,Quantity,Price\nNotebook,4,5.99\nPen,12,1.50':'Write your content here…',
            helperText:widget.kind==OfficeKind.excel?'Put each row on a new line; separate columns with commas.':widget.kind==OfficeKind.powerpoint?'The subtitle appears below the title on the first slide.':'Your content will be packaged into a real .${widget.kind.extension} file.',
            prefixIcon:const Padding(padding:EdgeInsets.only(bottom:185),child:Icon(Icons.edit_note_rounded)))),
        if(widget.state.showWordCount)Padding(padding:const EdgeInsets.fromLTRB(4,9,4,0),child:Row(children:[
          Icon(Icons.text_fields_rounded,size:16,color:theme.colorScheme.onSurfaceVariant),const SizedBox(width:6),
          Text('${bodyController.text.trim().isEmpty?0:bodyController.text.trim().split(RegExp(r'\s+')).length} words',style:theme.textTheme.labelSmall?.copyWith(color:theme.colorScheme.onSurfaceVariant)),
          const SizedBox(width:13),Text('${bodyController.text.length} characters',style:theme.textTheme.labelSmall?.copyWith(color:theme.colorScheme.onSurfaceVariant)),
        ])),
        const SizedBox(height:18),
        Wrap(spacing:10,runSpacing:10,children:[
          FilledButton.icon(onPressed:saving?null:_save,icon:saving?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.file_download_outlined),label:Text(saving?'Preparing…':t('save'))),
          OutlinedButton.icon(onPressed:(){titleController.clear();bodyController.clear();subtitleController.clear();},icon:const Icon(Icons.clear_all_rounded),label:const Text('Clear fields'))]),
        const SizedBox(height:12),
        Text('Generated on-device. No sign-in or upload is required.',style:theme.textTheme.bodySmall?.copyWith(color:theme.colorScheme.onSurfaceVariant)),
      ]))),
    );
  }
}

class PdfPage extends StatelessWidget {
  const PdfPage({super.key, required this.bytes, required this.name});
  final Uint8List bytes;final String name;
  Future<void> save(Uint8List output) async {await FilePicker.saveFile(fileName:name,bytes:output,mimeType:'application/pdf',dialogTitle:'Save edited PDF');}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(name)),body:PdfEditorView(bytes:bytes,documentId:name,onSave:save,showSaveButton:true));
}

class OfficePage extends StatelessWidget {
  const OfficePage({super.key,required this.bytes,required this.name,required this.state});
  final Uint8List bytes;
  final String name;
  final AppState state;
  @override Widget build(BuildContext context){
    final extension=name.split('.').last.toLowerCase();
    final kind=switch(extension){'pptx'=>OfficeKind.powerpoint,'xlsx'=>OfficeKind.excel,_=>OfficeKind.word};
    final theme=Theme.of(context);
    return Scaffold(appBar:AppBar(title:Text(name)),body:Center(
      child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:620),child:Padding(padding:const EdgeInsets.all(24),child:Column(
        mainAxisAlignment:MainAxisAlignment.center,children:[
          Container(width:78,height:78,decoration:BoxDecoration(color:kind.color.withAlpha(25),borderRadius:BorderRadius.circular(24)),child:Icon(kind.icon,color:kind.color,size:40)),
          const SizedBox(height:20),Text(name,textAlign:TextAlign.center,style:theme.textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w900)),
          const SizedBox(height:10),Text('This build can create starter '+kind.label+' files. Full-fidelity import and editing of existing Office documents is still in development.',
            textAlign:TextAlign.center,style:theme.textTheme.bodyLarge?.copyWith(color:theme.colorScheme.onSurfaceVariant,height:1.45)),
          const SizedBox(height:22),FilledButton.icon(onPressed:()=>Navigator.of(context).push(MaterialPageRoute<void>(
            builder:(_)=>NewDocumentPage(kind:kind,state:state))),icon:const Icon(Icons.note_add_outlined),label:Text('Create new '+kind.label))
        ])))));
  }
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

class RecentPage extends StatelessWidget {
  const RecentPage({super.key, required this.state});
  final AppState state;
  @override Widget build(BuildContext context) {
    final t=(String key)=>L10n.text(state.locale,key);final theme=Theme.of(context);
    return Scaffold(appBar:AppBar(title:Text(t('recent')),actions:[
      if(state.recent.isNotEmpty)IconButton(tooltip:t('clearRecent'),icon:const Icon(Icons.delete_sweep_outlined),onPressed:()async{
        final yes=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:Text(t('clearRecent')),
          content:const Text('This only clears the recent list. Your saved files will not be deleted.'),
          actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(t('cancel'))),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(t('reset')))]));
        if(yes==true)await state.clearRecent();
      }),const SizedBox(width:6)]),
      body:state.recent.isEmpty?Center(child:Padding(padding:const EdgeInsets.all(26),child:Column(mainAxisSize:MainAxisSize.min,children:[
        Icon(Icons.history_rounded,size:46,color:theme.colorScheme.primary),const SizedBox(height:15),
        Text(t('noRecent'),style:theme.textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w900)),
        const SizedBox(height:7),Text(t('empty'),textAlign:TextAlign.center,style:theme.textTheme.bodyMedium?.copyWith(color:theme.colorScheme.onSurfaceVariant)),
      ]))):ListView.separated(padding:const EdgeInsets.all(20),itemCount:state.recent.length,separatorBuilder:(_,__)=>const SizedBox(height:9),itemBuilder:(context,i){
        final d=state.recent[i];
        return Card(child:ListTile(contentPadding:const EdgeInsets.symmetric(horizontal:14,vertical:5),
          leading:CircleAvatar(backgroundColor:d.kind.color.withAlpha(24),child:Icon(d.kind.icon,color:d.kind.color)),
          title:Text(d.name,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w800)),
          subtitle:Text('${d.kind.label} • ${intl.DateFormat.yMMMd(state.locale.toString()).format(d.updatedAt)}'),
          trailing:IconButton(
            tooltip:'Remove from recent',
            icon:const Icon(Icons.close_rounded),
            onPressed:() async {
              if(state.confirmRecentRemoval){
                final yes=await showDialog<bool>(
                  context:context,
                  builder:(ctx)=>AlertDialog(
                    title:Text(t('confirmRecentRemoval')),
                    content:Text(state.locale.languageCode=='fa'
                      ?'این مورد فقط از فهرست اخیر حذف می‌شود؛ فایل ذخیره‌شده حذف نخواهد شد.'
                      :'Remove this item from the recent list only? The saved file will not be deleted.'),
                    actions:[
                      TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(t('cancel'))),
                      FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(t('reset'))),
                    ],
                  ),
                );
                if(yes!=true)return;
              }
              await state.removeRecent(d.name);
            },
          )));
      }));
  }
}

class WorkspaceHome extends StatelessWidget {
  const WorkspaceHome({super.key,required this.state,required this.openSettings});
  final AppState state;
  final VoidCallback openSettings;

  Widget _tile(BuildContext context,(IconData,String,String,VoidCallback) item) {
    final theme=Theme.of(context);
    return Card(clipBehavior:Clip.antiAlias,child:InkWell(
      borderRadius:BorderRadius.circular(20),onTap:item.$4,child:Padding(padding:const EdgeInsets.all(16),child:Row(children:[
        Container(width:48,height:48,decoration:BoxDecoration(color:theme.colorScheme.primary.withAlpha(22),borderRadius:BorderRadius.circular(15)),
          child:Icon(item.$1,color:theme.colorScheme.primary)),
        const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(item.$2,style:const TextStyle(fontWeight:FontWeight.w900)),const SizedBox(height:4),
          Text(item.$3,style:theme.textTheme.bodySmall?.copyWith(color:theme.colorScheme.onSurfaceVariant))])),
        const Icon(Icons.arrow_forward_ios_rounded,size:15)
      ]))));
  }

  @override Widget build(BuildContext context) {
    final t=(String key)=>L10n.text(state.locale,key);
    final theme=Theme.of(context);
    final cards=<(IconData,String,String,VoidCallback)>[
      (Icons.note_add_outlined,t('create'), 'PDF · DOCX · PPTX · XLSX',()=>showModalBottomSheet<void>(
        context:context,showDragHandle:true,builder:(ctx)=>SafeArea(child:Wrap(children:OfficeKind.values.map((kind)=>ListTile(
          leading:Icon(kind.icon,color:kind.color),title:Text(kind.label),subtitle:Text(kind.description),
          onTap:(){Navigator.pop(ctx);Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>NewDocumentPage(kind:kind,state:state)));})).toList())))),
      (Icons.palette_outlined,t('themes'),t('paletteHint'),openSettings),
      (Icons.remove_red_eye_outlined,t('blue'),t('blueSub'),openSettings),
      (Icons.translate_rounded,t('language'),t('responsiveNavigation'),openSettings),
      (Icons.shield_outlined,t('security'),t('keepRecent'),openSettings),
      (Icons.accessibility_new_rounded,t('accessibility'),t('textScale')+' · '+t('contrast'),openSettings),
    ];
    return Scaffold(
      appBar:AppBar(title:Text(L10n.text(state.locale,'workspace'))),
      body:ListView(padding:const EdgeInsets.all(20),children:[
        Text(t('workspace'),style:theme.textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w900)),
        const SizedBox(height:8),
        Text(t('welcomeSub'),style:theme.textTheme.bodyLarge?.copyWith(color:theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height:22),
        if(state.showGrid)
          LayoutBuilder(builder:(context,c){
            final cols=c.maxWidth>=1050?3:c.maxWidth>=590?2:1;
            return GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),itemCount:cards.length,
              gridDelegate:SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:cols,crossAxisSpacing:12,mainAxisSpacing:12,childAspectRatio:2.35),
              itemBuilder:(context,i)=>_tile(context,cards[i]));
          })
        else
          for(final item in cards)...[_tile(context,item),const SizedBox(height:10)]
      ])
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key,required this.state});
  final AppState state;
  @override State<SettingsPage> createState()=>_SettingsPageState();
}
class _SettingsPageState extends State<SettingsPage> {
  final searchController=TextEditingController();
  String category='All',paletteSearch='';
  @override void dispose(){searchController.dispose();super.dispose();}
  bool _matches(String q,String title,String tags)=>q.isEmpty||title.toLowerCase().contains(q.toLowerCase())||tags.toLowerCase().contains(q.toLowerCase());

  @override Widget build(BuildContext context){
    final state=widget.state;final t=(String key)=>L10n.text(state.locale,key);final query=searchController.text;final theme=Theme.of(context);
    final sections=<Widget>[];
    if(_matches(query,t('appearance'),'palette themes light dark amoled colors'))sections.add(_appearance(context,state,t));
    if(_matches(query,t('language'),'locale rtl persian arabic hebrew'))sections.add(_language(context,state,t));
    if(_matches(query,t('general'),'autosave recovery animations haptics recent toolbar'))sections.add(_general(context,state,t));
    if(_matches(query,t('editor'),'spell grid focus safe save'))sections.add(_editor(context,state,t));
    if(_matches(query,t('security'),'privacy diagnostics local'))sections.add(_security(context,state,t));
    if(_matches(query,t('accessibility'),'blue light filter text scale contrast'))sections.add(_accessibility(context,state,t));
    if(_matches(query,t('performance'),'responsive mode surfaces rendering'))sections.add(_performance(context,state,t));
    return Scaffold(appBar:AppBar(title:Text(t('settings')),actions:[
      IconButton(tooltip:t('export'),onPressed:()=>_export(state,t),icon:const Icon(Icons.file_download_outlined)),const SizedBox(width:5)]),
      body:ListView(padding:const EdgeInsets.fromLTRB(18,10,18,32),children:[
        Container(padding:const EdgeInsets.all(17),decoration:BoxDecoration(
          color:theme.colorScheme.primary.withAlpha(theme.brightness==Brightness.dark?32:16),
          borderRadius:BorderRadius.circular(22),border:Border.all(color:theme.colorScheme.primary.withAlpha(48))),
          child:Row(children:[const BrandMark(size:46),const SizedBox(width:13),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(t('appearance'),style:theme.textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w900)),
            const SizedBox(height:4),Text(t('paletteHint'),style:theme.textTheme.bodySmall?.copyWith(color:theme.colorScheme.onSurfaceVariant,height:1.4))]))])),
        const SizedBox(height:14),
        TextField(controller:searchController,onChanged:(_)=>setState((){}),decoration:InputDecoration(
          hintText:t('searchSettings'),prefixIcon:const Icon(Icons.search_rounded),
          suffixIcon:query.isEmpty?null:IconButton(onPressed:(){searchController.clear();setState((){});},icon:const Icon(Icons.close_rounded)))),
        const SizedBox(height:14),
        if(sections.isEmpty)Padding(padding:const EdgeInsets.all(24),child:Text('No settings match "'+query+'".',textAlign:TextAlign.center))
        else for(final sectionWidget in sections)Padding(padding:const EdgeInsets.only(bottom:12),child:sectionWidget),
        OutlinedButton.icon(onPressed:()=>_reset(state,t),icon:const Icon(Icons.restart_alt_rounded),label:Text(t('reset'))),
        const SizedBox(height:12),Text('Parin Office • Settings save on this device.',textAlign:TextAlign.center,
          style:theme.textTheme.labelSmall?.copyWith(color:theme.colorScheme.onSurfaceVariant))
      ]));
  }

  Widget _section(String title,String subtitle,IconData icon,List<Widget> children)=>Card(clipBehavior:Clip.antiAlias,
    child:Theme(data:Theme.of(context).copyWith(dividerColor:Colors.transparent),child:ExpansionTile(
      initiallyExpanded:true,tilePadding:const EdgeInsets.symmetric(horizontal:15,vertical:3),childrenPadding:const EdgeInsets.fromLTRB(12,0,12,14),
      leading:Container(width:40,height:40,decoration:BoxDecoration(color:Theme.of(context).colorScheme.primary.withAlpha(20),borderRadius:BorderRadius.circular(13)),
        child:Icon(icon,color:Theme.of(context).colorScheme.primary)),
      title:Text(title,style:const TextStyle(fontWeight:FontWeight.w900)),subtitle:Text(subtitle,maxLines:2,overflow:TextOverflow.ellipsis),children:children)));

  Widget _switchRow(AppState state,String key,String title,String subtitle,{IconData? icon})=>SwitchListTile(
    value:state.flag(key),onChanged:(value)=>state.setFlag(key,value),contentPadding:const EdgeInsets.symmetric(horizontal:6),
    secondary:icon==null?null:Icon(icon),title:Text(title,style:const TextStyle(fontWeight:FontWeight.w700)),subtitle:Text(subtitle));

  Widget _appearance(BuildContext context,AppState state,String Function(String) t){
    final theme=Theme.of(context);
    final modes=<(AppearanceMode,String,IconData)>[
      (AppearanceMode.system,t('system'),Icons.settings_brightness_rounded),
      (AppearanceMode.light,t('light'),Icons.light_mode_outlined),
      (AppearanceMode.dark,t('dark'),Icons.dark_mode_outlined),
      (AppearanceMode.amoled,t('amoled'),Icons.contrast_rounded)];
    final presets=ThemeCatalog.presets.where((p){
      final include=switch(category){
        'Cool'=>const ['Ocean','Arctic','Indigo','Midnight','Violet'].contains(p.family),
        'Nature'=>const ['Mint','Forest','Sage','Lime'].contains(p.family),
        'Warm'=>const ['Sunset','Coral','Rose','Sand'].contains(p.family),
        'Minimal'=>const ['Mono','Stone'].contains(p.family),
        _=>true};
      return include&&(paletteSearch.isEmpty||p.name.toLowerCase().contains(paletteSearch.toLowerCase())||p.family.toLowerCase().contains(paletteSearch.toLowerCase()));
    }).toList();
    return _section(t('appearance'),'128 coordinated palettes • preview instantly',Icons.palette_outlined,[
      Padding(padding:const EdgeInsets.fromLTRB(4,7,4,7),child:SingleChildScrollView(scrollDirection:Axis.horizontal,
        child:Row(children:modes.map((mode)=>Padding(padding:const EdgeInsetsDirectional.only(end:7),
          child:ChoiceChip(avatar:Icon(mode.$3,size:17),label:Text(mode.$2),selected:state.mode==mode.$1,
            onSelected:(_)=>state.setMode(mode.$1)))).toList()))),
      Padding(padding:const EdgeInsets.symmetric(horizontal:4,vertical:5),child:Text(t('paletteHint'),
        style:theme.textTheme.bodySmall?.copyWith(color:theme.colorScheme.onSurfaceVariant))),
      TextField(onChanged:(value)=>setState(()=>paletteSearch=value),decoration:const InputDecoration(
        prefixIcon:Icon(Icons.search_rounded),hintText:'Find Ocean, Rose, Mono...')),
      const SizedBox(height:10),
      Wrap(spacing:7,runSpacing:7,children:[
        for(final name in ['All','Cool','Nature','Warm','Minimal'])
          ChoiceChip(label:Text(name=='All'?t('all'):t(name)),selected:category==name,onSelected:(_)=>setState(()=>category=name))
      ]),
      const SizedBox(height:12),
      SizedBox(height:310,child:GridView.builder(itemCount:presets.length,
        gridDelegate:const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent:114,mainAxisExtent:86,crossAxisSpacing:9,mainAxisSpacing:9),
        itemBuilder:(context,i){
          final preset=presets[i]; final selected=state.preset.name==presets[i].name;
          return Semantics(button:true,selected:selected,label:preset.name,child:InkWell(borderRadius:BorderRadius.circular(16),
            onTap:()=>state.setTheme(ThemeCatalog.presets.indexOf(preset)),
            child:Container(padding:const EdgeInsets.all(8),decoration:BoxDecoration(color:theme.colorScheme.surface,
              borderRadius:BorderRadius.circular(16),border:Border.all(color:selected?theme.colorScheme.primary:theme.colorScheme.outlineVariant,width:selected?2:1)),
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Expanded(child:ClipRRect(borderRadius:BorderRadius.circular(10),child:Row(children:[
                  Expanded(child:ColoredBox(color:preset.primary)),Expanded(child:ColoredBox(color:preset.secondary)),
                  Expanded(child:ColoredBox(color:theme.colorScheme.surfaceContainerHigh))]))),
                const SizedBox(height:6),Row(children:[Expanded(child:Text(preset.name,maxLines:1,overflow:TextOverflow.ellipsis,
                  style:theme.textTheme.labelSmall?.copyWith(fontWeight:FontWeight.w800))),
                  if(selected)Icon(Icons.check_circle_rounded,color:theme.colorScheme.primary,size:15)])
              ]))));
        })),
      Padding(padding:const EdgeInsets.only(top:8),child:Text('Selected: '+state.preset.name,
        style:theme.textTheme.labelMedium?.copyWith(color:theme.colorScheme.onSurfaceVariant)))
    ]);
  }

  Widget _language(BuildContext context,AppState state,String Function(String) t)=>_section(
    t('language'),'16 locale choices • RTL-aware layout',Icons.translate_rounded,[
      Padding(padding:const EdgeInsets.all(6),child:DropdownButtonFormField<Locale>(
        value:state.locale,isExpanded:true,decoration:InputDecoration(labelText:t('language')),
        items:List.generate(L10n.locales.length,(i)=>DropdownMenuItem(value:L10n.locales[i],child:Text(L10n.names[i],overflow:TextOverflow.ellipsis))),
        onChanged:(locale){if(locale!=null)state.setLocale(locale);})),
      Padding(padding:const EdgeInsets.fromLTRB(8,8,8,0),child:Text(
        'Persian, Arabic and Hebrew use right-to-left layout. Material controls use Flutter localization delegates.',
        style:Theme.of(context).textTheme.bodySmall?.copyWith(color:Theme.of(context).colorScheme.onSurfaceVariant)))
    ]);

  Widget _general(BuildContext context,AppState state,String Function(String) t)=>_section(
    t('general'),'Interaction, autosave and recovery',Icons.tune_rounded,[
      _switchRow(state,'autosave',t('autosave'),'Save a local draft while composing.',icon:Icons.save_outlined),
      _switchRow(state,'autoRecovery',t('recovery'),'Restore the latest saved draft.',icon:Icons.history_rounded),
      _switchRow(state,'animations',t('motion'),'Enable screen transitions.',icon:Icons.animation_rounded),
      _switchRow(state,'haptics',t('haptics'),'Use touch feedback for selection and save.',icon:Icons.vibration_rounded),
      _switchRow(state,'compact',t('compact'),'Reduce toolbar spacing.',icon:Icons.view_compact_alt_outlined),
      _switchRow(state,'keepRecent',t('keepRecent'),'Keep up to 20 file names on this device.',icon:Icons.history_toggle_off_rounded),
      _switchRow(state,'showWelcomePanel',t('showWelcomePanel'),'Customize the first screen.',icon:Icons.dashboard_customize_outlined),
      _switchRow(state,'showQuickActions',t('showQuickActions'),'Show shortcuts below the format cards.',icon:Icons.bolt_outlined),
      _switchRow(state,'showDashboardMetrics',t('showDashboardMetrics'),'Show theme, locale, layout and privacy summaries.',icon:Icons.insights_outlined),
      _switchRow(state,'confirmRecentRemoval',t('confirmRecentRemoval'),'Ask before removing an item from the recent list.',icon:Icons.delete_outline_rounded),
    ]);

  Widget _editor(BuildContext context,AppState state,String Function(String) t)=>_section(
    t('editor'),'Editing and canvas preferences',Icons.edit_note_rounded,[
      Padding(padding:const EdgeInsets.fromLTRB(10,8,10,4),child:Column(children:[
        DropdownButtonFormField<String>(value:state.editorFontFamily,isExpanded:true,decoration:InputDecoration(labelText:t('fontFamily'),prefixIcon:const Icon(Icons.font_download_outlined)),
          items:[DropdownMenuItem(value:'system',child:Text(t('fontSystem'))),DropdownMenuItem(value:'serif',child:Text(t('fontSerif'))),DropdownMenuItem(value:'monospace',child:Text(t('fontMono')))],
          onChanged:(value){if(value!=null)state.setEditorFontFamily(value);}),
        const SizedBox(height:10),
        Row(children:[Expanded(child:Text(t('lineSpacing'),style:const TextStyle(fontWeight:FontWeight.w700))),Text(state.lineSpacing.toStringAsFixed(2)+'×')]),
        Slider(value:state.lineSpacing,min:1,max:2,divisions:10,onChanged:state.setLineSpacing),
      ])),
      _switchRow(state,'spellCheck',t('spell'),'Enable keyboard autocorrect in the composing field.',icon:Icons.spellcheck_rounded),
      _switchRow(state,'showGrid',t('grid'),'Remember the grid preference for workspace tools.',icon:Icons.grid_on_rounded),
      _switchRow(state,'focusMode',t('focus'),'Use a less distracting composition canvas.',icon:Icons.center_focus_strong_rounded),
      _switchRow(state,'safeSave',t('safeSave'),'Use the system Save As flow for new files.',icon:Icons.save_as_outlined),
      _switchRow(state,'showWordCount',t('wordCount'),'Show live word and character counts in the composer.',icon:Icons.text_fields_rounded),
      _switchRow(state,'smartCapitalization',t('smartCaps'),'Capitalize the beginning of sentences in the mobile keyboard.',icon:Icons.text_format_rounded),
      _switchRow(state,'openRecentOnStart',t('openRecentStart'),'Start on the recent list when saved recent files exist.',icon:Icons.history_rounded),
      Padding(padding:const EdgeInsets.fromLTRB(10,8,10,4),child:Column(children:[
        Row(children:[Expanded(child:Text(t('saveDelay'),style:const TextStyle(fontWeight:FontWeight.w700))),Text(state.autoSaveDelay.toStringAsFixed(1)+' s')]),
        Slider(value:state.autoSaveDelay,min:0.2,max:2,divisions:9,onChanged:state.setAutoSaveDelay),
        Row(children:[Expanded(child:Text(t('defaultFontSize'),style:const TextStyle(fontWeight:FontWeight.w700))),Text(state.defaultFontSize.round().toString()+' pt')]),
        Slider(value:state.defaultFontSize,min:13,max:22,divisions:9,onChanged:state.setDefaultFontSize),
      ])),
    ]);

  Widget _security(BuildContext context,AppState state,String Function(String) t)=>_section(
    t('security'),'Local processing and privacy choices',Icons.shield_outlined,[
      _switchRow(state,'diagnostics',t('diagnostics'),'Enable local diagnostics for troubleshooting.',icon:Icons.bug_report_outlined),
      const Padding(padding:EdgeInsets.fromLTRB(12,7,12,5),child:Text(
        'Generated files and drafts stay on-device in these flows. Cloud sync, app lock and document permissions are not enabled in this build.'))
    ]);

  Widget _accessibility(BuildContext context,AppState state,String Function(String) t)=>_section(
    t('accessibility'),'Screen comfort and readability',Icons.accessibility_new_rounded,[
      _switchRow(state,'blueLightFilter',t('blue'),t('blueSub'),icon:Icons.remove_red_eye_outlined),
      Padding(padding:const EdgeInsets.fromLTRB(10,6,10,4),child:Column(children:[
        Row(children:[Expanded(child:Text(t('blueStrength'),style:const TextStyle(fontWeight:FontWeight.w700))),
          Text((state.blueStrength*100).round().toString()+'%')]),
        Slider(value:state.blueStrength,min:0,max:1,divisions:20,onChanged:state.blueLightFilter?state.setBlueStrength:null),
        Row(children:[Expanded(child:Text(t('textScale'),style:const TextStyle(fontWeight:FontWeight.w700))),
          Text((state.textScale*100).round().toString()+'%')]),
        Slider(value:state.textScale,min:0.85,max:1.35,divisions:10,onChanged:state.setTextScale)
      ])),
      _switchRow(state,'highContrast',t('contrast'),'Increase contrast across surfaces and boundaries.',icon:Icons.contrast_rounded),
    ]);

  Widget _performance(BuildContext context,AppState state,String Function(String) t)=>_section(
    t('performance'),'Current runtime behavior',Icons.speed_rounded,[
      ListTile(leading:const Icon(Icons.palette_outlined),title:const Text('Active palette'),subtitle:Text(state.preset.name),
        trailing:Container(width:26,height:26,decoration:BoxDecoration(color:state.preset.primary,borderRadius:BorderRadius.circular(8)))),
      ListTile(leading:const Icon(Icons.devices_rounded),title:const Text('Responsive navigation'),
        subtitle:const Text('Navigation rail on wide layouts; bottom navigation on phones.')),
      ListTile(leading:const Icon(Icons.language_outlined),title:const Text('Text direction'),
        subtitle:Text(L10n.rtl(state.locale)?'Right to left':'Left to right')),
    ]);

  Future<void> _export(AppState state,String Function(String) t) async{
    final bytes=Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(state.exportablePreferences())));
    await FilePicker.saveFile(fileName:'parin-office-settings.json',bytes:bytes,mimeType:'application/json',dialogTitle:t('export'));
  }
  Future<void> _reset(AppState state,String Function(String) t) async{
    final yes=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:Text(t('reset')),
      content:Text(t('resetQuestion')),actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(t('cancel'))),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(t('reset')))]));
    if(yes==true)await state.resetPreferences();
  }
}

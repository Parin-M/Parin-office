import 'dart:typed_data';
import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'document_factory.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main(){WidgetsFlutterBinding.ensureInitialized();runApp(const ParinOfficeApp());}

enum AppearanceMode { system, light, dark, amoled }

class ThemePreset {
  const ThemePreset({required this.name, required this.primary, required this.secondary, required this.background, required this.family});
  final String name;
  final Color primary, secondary, background;
  final String family;
}

class ThemeCatalog {
  static const families = <String>['Ocean','Arctic','Mint','Forest','Sage','Lime','Sunset','Coral','Rose','Berry','Violet','Indigo','Midnight','Stone','Sand','Mono'];
  static const hues = <double>[214,194,164,145,112,84,26,8,342,320,276,244,225,210,37,0];
  static final presets = List<ThemePreset>.generate(128, (i) {
    final family = i ~/ 8;
    final variant = i % 8;
    final neutral = family == 15;
    final hue = neutral ? 220.0 : (hues[family] + variant * 3.2) % 360;
    final sat = neutral ? 0.04 : 0.52 + (variant % 3) * 0.07;
    final light = 0.37 + (variant % 5) * 0.045;
    final primary = HSLColor.fromAHSL(1, hue, sat, light).toColor();
    final secondary = HSLColor.fromAHSL(1, (hue + 18) % 360, sat * 0.78, (light + 0.08).clamp(0.0, 1.0)).toColor();
    return ThemePreset(name: '${families[family]} ${variant + 1}', primary: primary, secondary: secondary,
      background: HSLColor.fromAHSL(1, hue, 0.03, 0.97).toColor(), family: families[family]);
  });

  static ThemeData build(ThemePreset preset, Brightness brightness, bool amoled, {bool highContrast = false}) {
    final dark = brightness == Brightness.dark;
    final canvas = amoled ? const Color(0xFF000000) : dark ? const Color(0xFF101116) : const Color(0xFFF5F7FB);
    final surface = amoled ? const Color(0xFF000000) : dark ? const Color(0xFF191B22) : Colors.white;
    final raised = amoled ? const Color(0xFF08090D) : dark ? const Color(0xFF20232C) : Colors.white;
    final scheme = ColorScheme.fromSeed(seedColor: preset.primary, brightness: brightness,
      contrastLevel: highContrast ? 0.75 : 0).copyWith(
      primary: preset.primary, secondary: preset.secondary, surface: surface,
      surfaceContainerLowest: canvas, surfaceContainerLow: raised, surfaceContainer: raised,
      outline: dark ? const Color(0xFF3D414C) : const Color(0xFFE0E4EC),
      outlineVariant: dark ? const Color(0xFF2C3039) : const Color(0xFFE9ECF2));
    return ThemeData(
      useMaterial3: true, brightness: brightness, colorScheme: scheme,
      scaffoldBackgroundColor: canvas, canvasColor: surface,
      cardTheme: CardThemeData(color: surface, elevation: 0, margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: scheme.outlineVariant))),
      appBarTheme: AppBarTheme(centerTitle: false, elevation: 0, scrolledUnderElevation: 0,
        backgroundColor: canvas, surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(color: scheme.onSurface, fontSize: 20, fontWeight: FontWeight.w800)),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: dark ? const Color(0xFF20232B) : const Color(0xFFF7F8FC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: scheme.outlineVariant)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: scheme.outlineVariant)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: scheme.primary, width: 1.6))),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
        minimumSize: const Size(44, 46), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800))),
      chipTheme: ChipThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        side: BorderSide(color: scheme.outlineVariant), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5)),
      snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      dialogTheme: DialogThemeData(backgroundColor: surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
    );
  }
}

class RecentDocument {
  const RecentDocument({required this.name, required this.kind, required this.updatedAt});
  final String name;
  final OfficeKind kind;
  final DateTime updatedAt;
  Map<String, Object?> toJson() => {'name': name, 'kind': kind.name, 'updatedAt': updatedAt.toIso8601String()};
  factory RecentDocument.fromJson(Map<String, dynamic> json) => RecentDocument(
    name: json['name'] as String? ?? 'Document',
    kind: OfficeKind.values.firstWhere((e) => e.name == json['kind'], orElse: () => OfficeKind.pdf),
    updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now());
}

class AppState extends ChangeNotifier {
  Locale locale = const Locale('en');
  AppearanceMode mode = AppearanceMode.system;
  int themeIndex = 0;
  bool autosave = true, animations = true, haptics = true, compactRibbon = false, diagnostics = false;
  bool autoRecovery = true, blueLightFilter = false, highContrast = false, spellCheck = true;
  bool showGrid = true, focusMode = false, safeSave = true, keepRecent = true;
  double textScale = 1, blueStrength = 0.48;
  List<RecentDocument> recent = <RecentDocument>[];

  ThemePreset get preset => ThemeCatalog.presets[themeIndex.clamp(0, 127)];
  bool get amoled => mode == AppearanceMode.amoled;
  bool flag(String key) => switch (key) {
    'autosave' => autosave, 'animations' => animations, 'haptics' => haptics, 'compact' => compactRibbon,
    'diagnostics' => diagnostics, 'autoRecovery' => autoRecovery, 'blueLightFilter' => blueLightFilter,
    'highContrast' => highContrast, 'spellCheck' => spellCheck, 'showGrid' => showGrid,
    'focusMode' => focusMode, 'safeSave' => safeSave, 'keepRecent' => keepRecent, _ => false,
  };

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('locale') ?? 'en';
    final parts = raw.split('-');
    locale = parts.length > 1 ? Locale(parts[0], parts[1]) : Locale(parts[0]);
    mode = AppearanceMode.values.firstWhere((v) => v.name == p.getString('mode'), orElse: () => AppearanceMode.system);
    themeIndex = (p.getInt('theme') ?? 0).clamp(0, 127);
    textScale = (p.getDouble('textScale') ?? 1).clamp(0.85, 1.35);
    blueStrength = (p.getDouble('blueStrength') ?? 0.48).clamp(0.0, 1.0);
    autosave = p.getBool('autosave') ?? true;
    animations = p.getBool('animations') ?? true;
    haptics = p.getBool('haptics') ?? true;
    compactRibbon = p.getBool('compact') ?? false;
    diagnostics = p.getBool('diagnostics') ?? false;
    autoRecovery = p.getBool('autoRecovery') ?? true;
    blueLightFilter = p.getBool('blueLightFilter') ?? false;
    highContrast = p.getBool('highContrast') ?? false;
    spellCheck = p.getBool('spellCheck') ?? true;
    showGrid = p.getBool('showGrid') ?? true;
    focusMode = p.getBool('focusMode') ?? false;
    safeSave = p.getBool('safeSave') ?? true;
    keepRecent = p.getBool('keepRecent') ?? true;
    try {
      final data = p.getString('recentDocuments');
      if (data != null) recent = (jsonDecode(data) as List<dynamic>).whereType<Map<String, dynamic>>().map(RecentDocument.fromJson).take(20).toList();
    } catch (_) { recent = <RecentDocument>[]; }
  }

  Future<void> setLocale(Locale v) async { locale = v; notifyListeners(); final p = await SharedPreferences.getInstance(); await p.setString('locale', v.toLanguageTag()); }
  Future<void> setMode(AppearanceMode v) async { mode = v; notifyListeners(); final p = await SharedPreferences.getInstance(); await p.setString('mode', v.name); }
  Future<void> setTheme(int v) async { themeIndex = v.clamp(0, 127); notifyListeners(); final p = await SharedPreferences.getInstance(); await p.setInt('theme', themeIndex); if (haptics) await HapticFeedback.selectionClick(); }
  Future<void> setTextScale(double v) async { textScale = v.clamp(0.85, 1.35); notifyListeners(); final p = await SharedPreferences.getInstance(); await p.setDouble('textScale', textScale); }
  Future<void> setBlueStrength(double v) async { blueStrength = v.clamp(0.0, 1.0); notifyListeners(); final p = await SharedPreferences.getInstance(); await p.setDouble('blueStrength', blueStrength); }

  Future<void> setFlag(String key, bool v) async {
    switch (key) {
      case 'autosave': autosave = v;
      case 'animations': animations = v;
      case 'haptics': haptics = v;
      case 'compact': compactRibbon = v;
      case 'diagnostics': diagnostics = v;
      case 'autoRecovery': autoRecovery = v;
      case 'blueLightFilter': blueLightFilter = v;
      case 'highContrast': highContrast = v;
      case 'spellCheck': spellCheck = v;
      case 'showGrid': showGrid = v;
      case 'focusMode': focusMode = v;
      case 'safeSave': safeSave = v;
      case 'keepRecent': keepRecent = v;
    }
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(key, v);
  }

  Future<void> addRecent(String name, OfficeKind kind) async {
    if (!keepRecent) return;
    recent.removeWhere((d) => d.name == name);
    recent.insert(0, RecentDocument(name: name, kind: kind, updatedAt: DateTime.now()));
    if (recent.length > 20) recent = recent.take(20).toList();
    await _persistRecent();
    notifyListeners();
  }
  Future<void> removeRecent(String name) async { recent.removeWhere((d) => d.name == name); await _persistRecent(); notifyListeners(); }
  Future<void> clearRecent() async { recent.clear(); await _persistRecent(); notifyListeners(); }
  Future<void> _persistRecent() async { final p = await SharedPreferences.getInstance(); await p.setString('recentDocuments', jsonEncode(recent.map((d) => d.toJson()).toList())); }

  Future<Map<String, String>?> readDraft(OfficeKind kind) async {
    final p = await SharedPreferences.getInstance(); final raw = p.getString('draft_${kind.name}');
    if (raw == null) return null;
    try { return Map<String, String>.from(jsonDecode(raw) as Map); } catch (_) { return null; }
  }
  Future<void> saveDraft(OfficeKind kind, {required String title, required String body, required String subtitle}) async {
    if (!autosave) return;
    final p = await SharedPreferences.getInstance();
    await p.setString('draft_${kind.name}', jsonEncode({'title': title, 'body': body, 'subtitle': subtitle}));
  }
  Future<void> clearDraft(OfficeKind kind) async { final p = await SharedPreferences.getInstance(); await p.remove('draft_${kind.name}'); }

  Future<void> resetPreferences() async {
    final p = await SharedPreferences.getInstance();
    locale = const Locale('en'); mode = AppearanceMode.system; themeIndex = 0; textScale = 1; blueStrength = 0.48;
    autosave = true; animations = true; haptics = true; compactRibbon = false; diagnostics = false;
    autoRecovery = true; blueLightFilter = false; highContrast = false; spellCheck = true; showGrid = true;
    focusMode = false; safeSave = true; keepRecent = true;
    for (final key in ['locale','mode','theme','textScale','blueStrength','autosave','animations','haptics','compact','diagnostics','autoRecovery','blueLightFilter','highContrast','spellCheck','showGrid','focusMode','safeSave','keepRecent']) { await p.remove(key); }
    notifyListeners();
  }
  Map<String, Object?> exportablePreferences() => {
    'language': locale.toLanguageTag(), 'appearance': mode.name, 'theme': preset.name,
    'themeIndex': themeIndex, 'textScale': textScale, 'blueLightStrength': blueStrength,
    'settings': {'autosave':autosave,'animations':animations,'haptics':haptics,'compactRibbon':compactRibbon,
      'autoRecovery':autoRecovery,'blueLightFilter':blueLightFilter,'highContrast':highContrast,
      'diagnostics':diagnostics,'spellCheck':spellCheck,'showGrid':showGrid,'focusMode':focusMode,'safeSave':safeSave,'keepRecent':keepRecent},
  };
}

class L10n {
  static const locales = <Locale>[
    Locale('fa'),Locale('en'),Locale('da'),Locale('de'),Locale('de','CH'),Locale('ar'),Locale('hi'),Locale('he'),
    Locale('es'),Locale('it'),Locale('sv'),Locale('fi'),Locale('no'),Locale('is'),Locale('el'),Locale('tr')
  ];
  static const names = <String>['فارسی','English','Dansk','Deutsch','Schweizerdeutsch','العربية','हिन्दी','עברית','Español','Italiano','Svenska','Suomi','Norsk','Íslenska','Ελληνικά','Türkçe'];
  static const en = <String,String>{
    'home':'Home','recent':'Recent','workspace':'Workspace','settings':'Settings','open':'Open file',
    'create':'Create new','newDoc':'New document','pdf':'PDF','word':'Word','powerpoint':'PowerPoint','excel':'Excel',
    'welcome':'A calmer workspace for serious work','welcomeSub':'Create, organize and export your documents from one place.',
    'quick':'Quick actions','appearance':'Appearance','themes':'Color themes','language':'Language','mode':'Display mode',
    'system':'System','light':'Light','dark':'Dark','amoled':'AMOLED black','general':'General','editor':'Editor',
    'security':'Privacy & security','performance':'Performance','accessibility':'Accessibility','searchSettings':'Search settings',
    'blue':'Blue-light filter','blueSub':'Optional warm screen tint for evening work.','textScale':'Text size',
    'blueStrength':'Warm tint strength','reset':'Reset settings','export':'Export settings','cancel':'Cancel',
    'docTitle':'Document title','content':'Content','subtitle':'Subtitle','save':'Create and save',
    'empty':'Your recent documents will appear here.','noRecent':'No recent documents yet','clearRecent':'Clear recent list',
    'autosave':'Autosave drafts','recovery':'Draft recovery','motion':'Motion and transitions','haptics':'Haptic feedback',
    'compact':'Compact toolbars','keepRecent':'Keep recent documents','contrast':'High contrast','spell':'Text suggestions',
    'grid':'Show workspace grid','focus':'Focus-friendly editor','safeSave':'Safer save flow','diagnostics':'Anonymous diagnostics',
    'resetQuestion':'Reset app preferences to their defaults?','paletteHint':'128 curated accents for Light, Dark and AMOLED.',
    'createFirst':'Create your first document','search':'Search','restored':'Draft restored','saved':'File saved successfully',
  };
  static const fa = <String,String>{
    'home':'خانه','recent':'اخیر','workspace':'فضای کاری','settings':'تنظیمات','open':'باز کردن فایل',
    'create':'ساخت فایل','newDoc':'سند جدید','pdf':'PDF','word':'Word','powerpoint':'PowerPoint','excel':'Excel',
    'welcome':'فضایی منظم‌تر برای کارهای حرفه‌ای','welcomeSub':'سند بسازید، مدیریت کنید و خروجی بگیرید؛ همه در یک جا.',
    'quick':'عملیات سریع','appearance':'ظاهر برنامه','themes':'تم‌های رنگی','language':'زبان','mode':'حالت نمایش',
    'system':'سیستم','light':'روشن','dark':'تاریک','amoled':'مشکی AMOLED','general':'عمومی','editor':'ویرایشگر',
    'security':'حریم خصوصی و امنیت','performance':'کارایی','accessibility':'دسترس‌پذیری','searchSettings':'جست‌وجو در تنظیمات',
    'blue':'فیلتر نور آبی','blueSub':'فیلتر گرم و اختیاری برای کار در شب.','textScale':'اندازه متن',
    'blueStrength':'شدت فیلتر گرم','reset':'بازنشانی تنظیمات','export':'خروجی تنظیمات','cancel':'لغو',
    'docTitle':'عنوان سند','content':'محتوا','subtitle':'زیرعنوان','save':'ساخت و ذخیره',
    'empty':'سندهای اخیر شما اینجا نمایش داده می‌شوند.','noRecent':'هنوز سندی ندارید','clearRecent':'پاک‌کردن فهرست اخیر',
    'autosave':'ذخیره خودکار پیش‌نویس','recovery':'بازیابی پیش‌نویس','motion':'حرکت و گذارها','haptics':'بازخورد لمسی',
    'compact':'نوار ابزار فشرده','keepRecent':'نگهداری سندهای اخیر','contrast':'کنتراست بالا','spell':'پیشنهادهای نوشتاری',
    'grid':'نمایش شبکه فضای کاری','focus':'ویرایشگر متمرکز','safeSave':'ذخیره‌سازی ایمن‌تر','diagnostics':'گزارش ناشناس خطا',
    'resetQuestion':'تنظیمات برنامه به حالت پیش‌فرض برگردد؟','paletteHint':'۱۲۸ رنگ حرفه‌ای برای حالت روشن، تاریک و AMOLED.',
    'createFirst':'اولین سند خود را بسازید','search':'جست‌وجو','restored':'پیش‌نویس بازیابی شد','saved':'فایل با موفقیت ذخیره شد',
  };
  static const ar = <String,String>{
    'home':'الرئيسية','recent':'الأخيرة','workspace':'مساحة العمل','settings':'الإعدادات','open':'فتح ملف',
    'create':'إنشاء جديد','newDoc':'مستند جديد','pdf':'PDF','word':'Word','powerpoint':'PowerPoint','excel':'Excel',
    'welcome':'مساحة منظمة للعمل الاحترافي','welcomeSub':'أنشئ مستنداتك ونظّمها وصدّرها من مكان واحد.',
    'quick':'إجراءات سريعة','appearance':'المظهر','themes':'ألوان السمات','language':'اللغة','mode':'وضع العرض',
    'system':'النظام','light':'فاتح','dark':'داكن','amoled':'أسود AMOLED','general':'عام','editor':'المحرر',
    'security':'الخصوصية والأمان','performance':'الأداء','accessibility':'إمكانية الوصول','searchSettings':'بحث في الإعدادات',
    'blue':'مرشح الضوء الأزرق','blueSub':'لون دافئ اختياري للعمل مساءً.','textScale':'حجم النص',
    'blueStrength':'قوة اللون الدافئ','reset':'إعادة ضبط الإعدادات','export':'تصدير الإعدادات','cancel':'إلغاء',
    'docTitle':'عنوان المستند','content':'المحتوى','subtitle':'العنوان الفرعي','save':'إنشاء وحفظ',
    'empty':'ستظهر مستنداتك الأخيرة هنا.','noRecent':'لا توجد مستندات حديثة','clearRecent':'مسح القائمة',
    'autosave':'حفظ المسودات تلقائيًا','recovery':'استعادة المسودات','motion':'الحركة والانتقالات','haptics':'الاهتزاز اللمسي',
    'compact':'أشرطة أدوات مضغوطة','keepRecent':'الاحتفاظ بالمستندات الأخيرة','contrast':'تباين مرتفع','spell':'اقتراحات النص',
    'grid':'عرض الشبكة','focus':'محرر للتركيز','safeSave':'حفظ أكثر أمانًا','diagnostics':'تقارير مجهولة',
    'resetQuestion':'إعادة تفضيلات التطبيق إلى الوضع الافتراضي؟','paletteHint':'١٢٨ لونًا متناسقًا للأوضاع الفاتح والداكن وAMOLED.',
    'createFirst':'أنشئ مستندك الأول','search':'بحث','restored':'تمت استعادة المسودة','saved':'تم حفظ الملف بنجاح',
  };
  static const de = <String,String>{'home':'Start','recent':'Zuletzt','workspace':'Arbeitsbereich','settings':'Einstellungen','open':'Datei öffnen','create':'Neu erstellen','newDoc':'Neues Dokument','welcome':'Ein klarer Arbeitsbereich','welcomeSub':'Dokumente an einem Ort erstellen, ordnen und exportieren.','quick':'Schnellaktionen','appearance':'Darstellung','themes':'Farbthemen','language':'Sprache','mode':'Anzeigemodus','system':'System','light':'Hell','dark':'Dunkel','amoled':'AMOLED-Schwarz','general':'Allgemein','editor':'Editor','security':'Datenschutz & Sicherheit','performance':'Leistung','accessibility':'Barrierefreiheit','searchSettings':'Einstellungen suchen','blue':'Blaulichtfilter','blueSub':'Optionaler warmer Bildschirmton am Abend.','textScale':'Textgröße','blueStrength':'Wärmeintensität','reset':'Einstellungen zurücksetzen','export':'Einstellungen exportieren','cancel':'Abbrechen','docTitle':'Dokumenttitel','content':'Inhalt','subtitle':'Untertitel','save':'Erstellen und speichern','empty':'Ihre letzten Dokumente erscheinen hier.','noRecent':'Noch keine aktuellen Dokumente','clearRecent':'Liste leeren','autosave':'Entwürfe automatisch speichern','recovery':'Entwurfswiederherstellung','motion':'Bewegung und Übergänge','haptics':'Haptisches Feedback','compact':'Kompakte Symbolleisten','keepRecent':'Zuletzt verwendete Dokumente behalten','contrast':'Hoher Kontrast','spell':'Textvorschläge','grid':'Raster anzeigen','focus':'Fokus-Editor','safeSave':'Sicheres Speichern','diagnostics':'Anonyme Diagnose','resetQuestion':'App-Einstellungen auf Standard zurücksetzen?','paletteHint':'128 abgestimmte Akzentfarben für Hell, Dunkel und AMOLED.','createFirst':'Erstes Dokument erstellen','search':'Suchen','restored':'Entwurf wiederhergestellt','saved':'Datei erfolgreich gespeichert'};
  static const es = <String,String>{'home':'Inicio','recent':'Recientes','workspace':'Espacio de trabajo','settings':'Ajustes','open':'Abrir archivo','create':'Crear nuevo','newDoc':'Documento nuevo','welcome':'Un espacio más claro para trabajar','welcomeSub':'Crea, organiza y exporta tus documentos en un solo lugar.','quick':'Acciones rápidas','appearance':'Apariencia','themes':'Temas de color','language':'Idioma','mode':'Modo de pantalla','system':'Sistema','light':'Claro','dark':'Oscuro','amoled':'Negro AMOLED','general':'General','editor':'Editor','security':'Privacidad y seguridad','performance':'Rendimiento','accessibility':'Accesibilidad','searchSettings':'Buscar ajustes','blue':'Filtro de luz azul','blueSub':'Tinte cálido opcional para la noche.','textScale':'Tamaño del texto','blueStrength':'Intensidad del tono cálido','reset':'Restablecer ajustes','export':'Exportar ajustes','cancel':'Cancelar','docTitle':'Título del documento','content':'Contenido','subtitle':'Subtítulo','save':'Crear y guardar','empty':'Tus documentos recientes aparecerán aquí.','noRecent':'Todavía no hay documentos recientes','clearRecent':'Vaciar lista','autosave':'Guardar borradores automáticamente','recovery':'Recuperación de borradores','motion':'Movimiento y transiciones','haptics':'Respuesta háptica','compact':'Barras compactas','keepRecent':'Conservar documentos recientes','contrast':'Alto contraste','spell':'Sugerencias de texto','grid':'Mostrar cuadrícula','focus':'Editor de concentración','safeSave':'Guardado seguro','diagnostics':'Diagnóstico anónimo','resetQuestion':'¿Restablecer los ajustes de la aplicación?','paletteHint':'128 acentos coordinados para modos claro, oscuro y AMOLED.','createFirst':'Crea tu primer documento','search':'Buscar','restored':'Borrador recuperado','saved':'Archivo guardado correctamente'};
  static const tr = <String,String>{'home':'Ana sayfa','recent':'Son kullanılanlar','workspace':'Çalışma alanı','settings':'Ayarlar','open':'Dosya aç','create':'Yeni oluştur','newDoc':'Yeni belge','welcome':'Daha düzenli bir çalışma alanı','welcomeSub':'Belgelerinizi tek yerden oluşturun, düzenleyin ve dışa aktarın.','quick':'Hızlı işlemler','appearance':'Görünüm','themes':'Renk temaları','language':'Dil','mode':'Görünüm modu','system':'Sistem','light':'Açık','dark':'Koyu','amoled':'AMOLED siyah','general':'Genel','editor':'Düzenleyici','security':'Gizlilik ve güvenlik','performance':'Performans','accessibility':'Erişilebilirlik','searchSettings':'Ayarları ara','blue':'Mavi ışık filtresi','blueSub':'Akşam çalışması için isteğe bağlı sıcak ton.','textScale':'Metin boyutu','blueStrength':'Sıcak ton yoğunluğu','reset':'Ayarları sıfırla','export':'Ayarları dışa aktar','cancel':'İptal','docTitle':'Belge başlığı','content':'İçerik','subtitle':'Alt başlık','save':'Oluştur ve kaydet','empty':'Son belgeleriniz burada görünecek.','noRecent':'Henüz son belge yok','clearRecent':'Son listeyi temizle','autosave':'Taslakları otomatik kaydet','recovery':'Taslak kurtarma','motion':'Hareket ve geçişler','haptics':'Dokunsal geri bildirim','compact':'Kompakt araç çubukları','keepRecent':'Son belgeleri sakla','contrast':'Yüksek kontrast','spell':'Metin önerileri','grid':'Izgarayı göster','focus':'Odak düzenleyicisi','safeSave':'Güvenli kaydetme','diagnostics':'Anonim tanılama','resetQuestion':'Uygulama tercihleri varsayılana sıfırlansın mı?','paletteHint':'Açık, koyu ve AMOLED modları için 128 renk.','createFirst':'İlk belgenizi oluşturun','search':'Ara','restored':'Taslak kurtarıldı','saved':'Dosya başarıyla kaydedildi'};
  static String text(Locale locale, String key) {
    final table = switch (locale.languageCode) {'fa'=>fa,'ar'=>ar,'de'=>de,'es'=>es,'tr'=>tr,_=>en};
    return table[key] ?? en[key] ?? key;
  }
  static bool rtl(Locale locale) => const {'fa','ar','he'}.contains(locale.languageCode);
}

class ParinOfficeApp extends StatefulWidget {
  const ParinOfficeApp({super.key});
  @override State<ParinOfficeApp> createState() => _ParinOfficeAppState();
}
class _ParinOfficeAppState extends State<ParinOfficeApp> {
  final state = AppState();
  bool ready = false;
  @override void initState() { super.initState(); state.load().whenComplete(() { if (mounted) setState(() => ready = true); }); }
  @override void dispose() { state.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    if (!ready) return const MaterialApp(home: Scaffold(body: Center(child: CircularProgressIndicator())));
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) => MaterialApp(
        title: 'Parin Office', debugShowCheckedModeBanner: false, locale: state.locale,
        supportedLocales: L10n.locales,
        localizationsDelegates: const [GlobalMaterialLocalizations.delegate,GlobalWidgetsLocalizations.delegate,GlobalCupertinoLocalizations.delegate],
        theme: ThemeCatalog.build(state.preset, Brightness.light, false, highContrast: state.highContrast),
        darkTheme: ThemeCatalog.build(state.preset, Brightness.dark, state.amoled, highContrast: state.highContrast),
        themeMode: state.mode == AppearanceMode.system ? ThemeMode.system : state.mode == AppearanceMode.light ? ThemeMode.light : ThemeMode.dark,
        localeResolutionCallback: (device, supported) {
          for (final l in supported) { if (l.toLanguageTag() == state.locale.toLanguageTag()) return l; }
          for (final l in supported) { if (l.languageCode == state.locale.languageCode) return l; }
          return const Locale('en');
        },
        builder: (context, child) => Directionality(
          textDirection: L10n.rtl(state.locale) ? TextDirection.rtl : TextDirection.ltr,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(state.textScale)),
            child: Stack(fit: StackFit.expand, children: [
              child ?? const SizedBox.shrink(),
              if (state.blueLightFilter) IgnorePointer(child: ColoredBox(color: Color.fromRGBO(255,153,64,0.23 * state.blueStrength))),
            ]),
          ),
        ),
        home: Shell(state: state),
      ),
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 42});
  final double size;
  @override Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(size * 0.28),
      gradient: const LinearGradient(begin: Alignment.topLeft,end: Alignment.bottomRight,colors:[Color(0xFF2869F6),Color(0xFF7255DE)]),
      boxShadow: [BoxShadow(color: const Color(0xFF4169E8).withAlpha(45),blurRadius:size * 0.32,offset:Offset(0,size * 0.08))]),
    child: Stack(alignment:Alignment.center,children:[
      Text('P',style:TextStyle(color:Colors.white,fontSize:size*0.63,fontWeight:FontWeight.w900,height:1)),
      Positioned(right:size*0.16,bottom:size*0.17,child:Container(width:size*0.21,height:size*0.21,
        decoration:BoxDecoration(color:const Color(0xFF70E3D3),borderRadius:BorderRadius.circular(size*0.06),border:Border.all(color:Colors.white,width:size*0.025))))
    ]));
}

class Shell extends StatefulWidget {
  const Shell({super.key, required this.state});
  final AppState state;
  @override State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;
  @override Widget build(BuildContext context) {
    final t = (String key) => L10n.text(widget.state.locale, key);
    final items = <(IconData,String)>[
      (Icons.space_dashboard_rounded,t('home')),(Icons.history_rounded,t('recent')),
      (Icons.grid_view_rounded,t('workspace')),(Icons.tune_rounded,t('settings'))];
    final pages = <Widget>[
      Dashboard(state:widget.state,openSettings:()=>setState(()=>index=3)),
      RecentPage(state:widget.state),
      WorkspaceHome(state:widget.state,openSettings:()=>setState(()=>index=3)),
      SettingsPage(state:widget.state)];
    return LayoutBuilder(builder:(context,c) {
      final desktop=c.maxWidth>=900;
      final extended=c.maxWidth>=1180;
      final page=AnimatedSwitcher(
        duration:widget.state.animations?const Duration(milliseconds:220):Duration.zero,
        child:KeyedSubtree(key:ValueKey(index),child:pages[index]));
      if(desktop) return Scaffold(body:Row(children:[
        NavigationRail(
          selectedIndex:index,extended:extended,minExtendedWidth:238,
          onDestinationSelected:(v)=>setState(()=>index=v),
          leading:Padding(padding:const EdgeInsets.fromLTRB(14,18,14,24),
            child:Row(mainAxisSize:extended?MainAxisSize.max:MainAxisSize.min,children:[
              const BrandMark(size:40),
              if(extended)...[const SizedBox(width:10),const Flexible(child:Text('Parin Office',style:TextStyle(fontSize:17,fontWeight:FontWeight.w900)))]])),
          destinations:items.map((x)=>NavigationRailDestination(icon:Icon(x.$1),selectedIcon:Icon(x.$1),label:Text(x.$2))).toList()),
        VerticalDivider(width:1,color:Theme.of(context).colorScheme.outlineVariant),
        Expanded(child:page)]));
      return Scaffold(body:page,bottomNavigationBar:NavigationBar(
        selectedIndex:index,onDestinationSelected:(v)=>setState(()=>index=v),
        destinations:items.map((x)=>NavigationDestination(icon:Icon(x.$1),selectedIcon:Icon(x.$1),label:x.$2)).toList()));
    });
  }
}

class Dashboard extends StatelessWidget {
  const Dashboard({super.key, required this.state, required this.openSettings});
  final AppState state;
  final VoidCallback openSettings;

  Future<void> openFile(BuildContext context) async {
    final files = await FilePicker.pickFiles(type:FileType.custom,allowedExtensions:const['pdf','docx','pptx','xlsx'],withData:true);
    if (!context.mounted || files == null || files.files.isEmpty) return;
    final file = files.files.first;
    final bytes = file.bytes ?? await file.readAsBytes();
    if (!context.mounted) return;
    final ext = (file.extension ?? '').toLowerCase();
    final kind = switch (ext) {'docx'=>OfficeKind.word,'pptx'=>OfficeKind.powerpoint,'xlsx'=>OfficeKind.excel,_=>OfficeKind.pdf};
    await state.addRecent(file.name,kind);
    if (!context.mounted) return;
    if (kind == OfficeKind.pdf) {
      Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>PdfPage(bytes:bytes,name:file.name)));
    } else {
      Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>OfficePage(bytes:bytes,name:file.name)));
    }
  }

  void create(BuildContext context, OfficeKind kind) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder:(_)=>NewDocumentPage(kind:kind,state:state)));

  @override Widget build(BuildContext context) {
    final t=(String key)=>L10n.text(state.locale,key);
    final theme=Theme.of(context);
    return Scaffold(
      appBar:AppBar(title:Row(children:[const BrandMark(size:34),const SizedBox(width:10),const Text('Parin Office',style:TextStyle(fontWeight:FontWeight.w900))]),
        actions:[IconButton(tooltip:t('open'),onPressed:()=>openFile(context),icon:const Icon(Icons.folder_open_rounded)),
          IconButton(tooltip:t('settings'),onPressed:openSettings,icon:const Icon(Icons.tune_rounded)),const SizedBox(width:6)]),
      body:CustomScrollView(slivers:[
        SliverPadding(padding:const EdgeInsets.fromLTRB(20,18,20,20),sliver:SliverToBoxAdapter(
          child:Container(padding:const EdgeInsets.all(24),decoration:BoxDecoration(
            gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[
              theme.colorScheme.primary.withAlpha(theme.brightness==Brightness.dark?52:28),
              theme.colorScheme.secondary.withAlpha(theme.brightness==Brightness.dark?34:20),theme.colorScheme.surface]),
            borderRadius:BorderRadius.circular(28),border:Border.all(color:theme.colorScheme.outlineVariant)),
            child:LayoutBuilder(builder:(context,c){
              final text=Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:7),
                  decoration:BoxDecoration(color:theme.colorScheme.primary.withAlpha(24),borderRadius:BorderRadius.circular(50)),
                  child:Text('YOUR WORKSPACE',style:TextStyle(color:theme.colorScheme.primary,fontSize:11,letterSpacing:1.2,fontWeight:FontWeight.w900))),
                const SizedBox(height:16),
                Text(t('welcome'),style:theme.textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.w900,height:1.12,letterSpacing:-0.5)),
                const SizedBox(height:10),
                Text(t('welcomeSub'),style:theme.textTheme.bodyLarge?.copyWith(color:theme.colorScheme.onSurfaceVariant,height:1.45)),
                const SizedBox(height:22),
                Wrap(spacing:10,runSpacing:10,children:[
                  FilledButton.icon(onPressed:()=>_showCreate(context),icon:const Icon(Icons.add_rounded),label:Text(t('create'))),
                  OutlinedButton.icon(onPressed:()=>openFile(context),icon:const Icon(Icons.file_open_rounded),label:Text(t('open')))])]);
              if(c.maxWidth<600)return text;
              return Row(children:[
                Expanded(flex:7,child:text),const SizedBox(width:20),
                Expanded(flex:3,child:Container(height:180,decoration:BoxDecoration(color:theme.colorScheme.surface.withAlpha(210),borderRadius:BorderRadius.circular(24)),
                  child:Stack(alignment:Alignment.center,children:[
                    Positioned(right:15,top:15,child:Icon(Icons.auto_awesome_rounded,size:27,color:theme.colorScheme.primary.withAlpha(150))),
                    Transform.rotate(angle:-0.08,child:Container(width:100,height:132,padding:const EdgeInsets.all(18),
                      decoration:BoxDecoration(color:theme.colorScheme.surface,borderRadius:BorderRadius.circular(17),border:Border.all(color:theme.colorScheme.outlineVariant),
                        boxShadow:[BoxShadow(color:theme.colorScheme.primary.withAlpha(25),blurRadius:25,offset:const Offset(0,10))]),
                      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                        Container(width:34,height:7,decoration:BoxDecoration(color:theme.colorScheme.primary,borderRadius:BorderRadius.circular(5))),
                        const SizedBox(height:16),
                        for(var i=0;i<4;i++)Container(width:i==3?38:62,height:4,margin:const EdgeInsets.only(bottom:8),decoration:BoxDecoration(color:theme.colorScheme.outlineVariant,borderRadius:BorderRadius.circular(5))),
                        const Spacer(),Container(width:43,height:5,color:theme.colorScheme.secondary)]))]))]);
            })))),
        SliverPadding(padding:const EdgeInsets.fromLTRB(20,0,20,13),sliver:SliverToBoxAdapter(child:Row(children:[
          Expanded(child:Text(t('quick'),style:theme.textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w900))),
          Text('04 FORMATS',style:theme.textTheme.labelSmall?.copyWith(letterSpacing:1,fontWeight:FontWeight.w900,color:theme.colorScheme.onSurfaceVariant))]))),
        SliverPadding(padding:const EdgeInsets.symmetric(horizontal:20),sliver:SliverGrid(
          delegate:SliverChildBuilderDelegate((context,i){
            final kind=OfficeKind.values[i];
            return _DocTile(kind.label,kind.description,kind.icon,kind.color,()=>create(context,kind));
          },childCount:OfficeKind.values.length),
          gridDelegate:const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent:390,mainAxisExtent:156,crossAxisSpacing:13,mainAxisSpacing:13))),
        SliverPadding(padding:const EdgeInsets.fromLTRB(20,25,20,11),sliver:SliverToBoxAdapter(
          child:Text(t('quick'),style:theme.textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w900)))),
        SliverPadding(padding:const EdgeInsets.symmetric(horizontal:20),sliver:SliverToBoxAdapter(child:Wrap(spacing:9,runSpacing:9,children:[
          ActionChip(avatar:const Icon(Icons.folder_open_rounded,size:18),label:Text(t('open')),onPressed:()=>openFile(context)),
          ActionChip(avatar:const Icon(Icons.palette_outlined,size:18),label:Text(t('themes')),onPressed:openSettings),
          ActionChip(avatar:const Icon(Icons.remove_red_eye_outlined,size:18),label:Text(t('blue')),onPressed:openSettings),
        ])))),
        SliverPadding(padding:const EdgeInsets.fromLTRB(20,24,20,30),sliver:SliverToBoxAdapter(child:Wrap(spacing:12,runSpacing:12,children:[
          const _Metric(Icons.palette_outlined,'Themes','128 presets'),
          const _Metric(Icons.translate_rounded,'Languages','16 locales'),
          const _Metric(Icons.devices_rounded,'Layout','Phone + tablet'),
          const _Metric(Icons.shield_outlined,'Privacy','Local controls'),
        ])))),
      ]),
    );
  }

  void _showCreate(BuildContext context) {
    final t=(String key)=>L10n.text(state.locale,key);
    showModalBottomSheet<void>(context:context,showDragHandle:true,isScrollControlled:true,builder:(sheet)=>SafeArea(
      child:Padding(padding:const EdgeInsets.fromLTRB(18,8,18,24),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(t('newDoc'),style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w900)),
        const SizedBox(height:8),Text(t('welcomeSub')),const SizedBox(height:16),
        for(final kind in OfficeKind.values)ListTile(
          leading:Container(width:44,height:44,decoration:BoxDecoration(color:kind.color.withAlpha(24),borderRadius:BorderRadius.circular(14)),child:Icon(kind.icon,color:kind.color)),
          title:Text(kind.label,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text(kind.description),
          trailing:const Icon(Icons.arrow_forward_ios_rounded,size:16),
          onTap:(){Navigator.of(sheet).pop();create(context,kind);}),
      ]))));
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
    timer=Timer(const Duration(milliseconds:450),()=>widget.state.saveDraft(widget.kind,title:titleController.text,body:bodyController.text,subtitle:subtitleController.text));
  }
  @override void dispose(){timer?.cancel();titleController.dispose();bodyController.dispose();subtitleController.dispose();super.dispose();}

  Future<void> _save() async {
    final t=(String key)=>L10n.text(widget.state.locale,key);
    final title=titleController.text.trim();
    if(title.isEmpty){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Enter a document title first.')));return;}
    setState(()=>saving=true);
    try {
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
      body:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:900),child:ListView(padding:const EdgeInsets.fromLTRB(20,12,20,32),children:[
        Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:theme.colorScheme.surface,borderRadius:BorderRadius.circular(22),border:Border.all(color:theme.colorScheme.outlineVariant)),
          child:Row(children:[const BrandMark(size:44),const SizedBox(width:13),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(widget.kind.label,style:theme.textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w900)),
            const SizedBox(height:4),Text(widget.kind.description,style:theme.textTheme.bodySmall?.copyWith(color:theme.colorScheme.onSurfaceVariant))]))])),
        const SizedBox(height:17),
        TextField(controller:titleController,textInputAction:TextInputAction.next,decoration:InputDecoration(labelText:t('docTitle'),prefixIcon:const Icon(Icons.title_rounded))),
        if(widget.kind==OfficeKind.powerpoint)...[
          const SizedBox(height:13),TextField(controller:subtitleController,textInputAction:TextInputAction.next,decoration:InputDecoration(labelText:t('subtitle'),prefixIcon:const Icon(Icons.short_text_rounded)))],
        const SizedBox(height:13),
        TextField(controller:bodyController,minLines:widget.kind==OfficeKind.excel?9:12,maxLines:24,keyboardType:TextInputType.multiline,autocorrect:widget.state.spellCheck,
          decoration:InputDecoration(alignLabelWithHint:true,labelText:widget.kind==OfficeKind.excel?'Sheet data (CSV)':t('content'),
            hintText:widget.kind==OfficeKind.excel?'Product,Quantity,Price\nNotebook,4,5.99\nPen,12,1.50':'Write your content here…',
            helperText:widget.kind==OfficeKind.excel?'Put each row on a new line; separate columns with commas.':widget.kind==OfficeKind.powerpoint?'The subtitle appears below the title on the first slide.':'Your content will be packaged into a real .${widget.kind.extension} file.',
            prefixIcon:const Padding(padding:EdgeInsets.only(bottom:185),child:Icon(Icons.edit_note_rounded)))),
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
          subtitle:Text('${d.kind.label} • ${DateFormat.yMMMd(state.locale.toLanguageTag()).format(d.updatedAt)}'),
          trailing:IconButton(tooltip:'Remove from recent',icon:const Icon(Icons.close_rounded),onPressed:()=>state.removeRecent(d.name))));
      }));
  }
}

class WorkspaceHome extends StatelessWidget {
  const WorkspaceHome({super.key, required this.state, required this.openSettings});
  final AppState state;final VoidCallback openSettings;
  @override Widget build(BuildContext context) {
    final theme=Theme.of(context);
    final cards=< (IconData,String,String,VoidCallback)>[
      (Icons.note_add_outlined,'Create a document','PDF, Word, PowerPoint and Excel',()=>showModalBottomSheet<void>(context:context,showDragHandle:true,builder:(ctx)=>SafeArea(child:Wrap(children:OfficeKind.values.map((kind)=>ListTile(leading:Icon(kind.icon,color:kind.color),title:Text(kind.label),onTap:(){Navigator.pop(ctx);Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>NewDocumentPage(kind:kind,state:state)));})).toList())))),
      (Icons.palette_outlined,'Theme studio','128 coordinated color palettes',openSettings),
      (Icons.remove_red_eye_outlined,'Reading comfort','Optional blue-light filter',openSettings),
      (Icons.translate_rounded,'Language and layout','Locale-aware layout with RTL support',openSettings),
      (Icons.shield_outlined,'Privacy controls','Local drafts and recent-document settings',openSettings),
      (Icons.accessibility_new_rounded,'Accessibility','Text scaling and contrast controls',openSettings),
    ];
    return Scaffold(appBar:AppBar(title:Text(L10n.text(state.locale,'workspace'))),body:ListView(padding:const EdgeInsets.all(20),children:[
      Text('A toolkit that stays out of your way',style:theme.textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w900)),
      const SizedBox(height:8),Text('Shortcuts, appearance and preferences in one adaptive workspace.',style:theme.textTheme.bodyLarge?.copyWith(color:theme.colorScheme.onSurfaceVariant)),
      const SizedBox(height:22),
      for(final card in cards)...[
        Card(child:InkWell(borderRadius:BorderRadius.circular(20),onTap:card.$4,child:Padding(padding:const EdgeInsets.all(16),child:Row(children:[
          Container(width:48,height:48,decoration:BoxDecoration(color:theme.colorScheme.primary.withAlpha(22),borderRadius:BorderRadius.circular(15)),child:Icon(card.$1,color:theme.colorScheme.primary)),
          const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(card.$2,style:const TextStyle(fontWeight:FontWeight.w900)),const SizedBox(height:4),Text(card.$3,style:theme.textTheme.bodySmall?.copyWith(color:theme.colorScheme.onSurfaceVariant))])),
          const Icon(Icons.arrow_forward_ios_rounded,size:15)])))),const SizedBox(height:10)]])
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
  String themeCategory='All';
  String themeQuery='';
  @override void dispose(){searchController.dispose();super.dispose();}
  bool matches(String query,String title,String keywords)=>query.isEmpty||title.toLowerCase().contains(query.toLowerCase())||keywords.toLowerCase().contains(query.toLowerCase());

  @override Widget build(BuildContext context){
    final s=widget.state;final t=(String key)=>L10n.text(s.locale,key);final q=searchController.text;final theme=Theme.of(context);
    final children=<Widget>[];
    if(matches(q,t('appearance'),'themes palette light dark amoled'))children.add(_appearance(context,s,t));
    if(matches(q,t('language'),'locale persian arabic hebrew rtl'))children.add(_language(context,s,t));
    if(matches(q,t('general'),'autosave recovery animation haptics recent toolbar'))children.add(_general(context,s,t));
    if(matches(q,t('editor'),'spell grid focus save'))children.add(_editor(context,s,t));
    if(matches(q,t('security'),'privacy diagnostics local'))children.add(_security(context,s,t));
    if(matches(q,t('accessibility'),'blue light filter text scale contrast'))children.add(_accessibility(context,s,t));
    if(matches(q,t('performance'),'rendering responsiveness'))children.add(_performance(context,s,t));
    return Scaffold(appBar:AppBar(title:Text(t('settings')),actions:[IconButton(tooltip:t('export'),onPressed:()=>_export(s,t),icon:const Icon(Icons.file_download_outlined)),const SizedBox(width:6)]),
      body:ListView(padding:const EdgeInsets.fromLTRB(18,10,18,32),children:[
        Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:theme.colorScheme.primary.withAlpha(theme.brightness==Brightness.dark?32:16),borderRadius:BorderRadius.circular(22),border:Border.all(color:theme.colorScheme.primary.withAlpha(50))),
          child:Row(children:[const BrandMark(size:46),const SizedBox(width:13),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(t('appearance'),style:theme.textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w900)),const SizedBox(height:4),
            Text(t('paletteHint'),style:theme.textTheme.bodySmall?.copyWith(color:theme.colorScheme.onSurfaceVariant,height:1.4))]))])),
        const SizedBox(height:14),
        TextField(controller:searchController,onChanged:(_)=>setState((){}),decoration:InputDecoration(hintText:t('searchSettings'),prefixIcon:const Icon(Icons.search_rounded),
          suffixIcon:q.isEmpty?null:IconButton(onPressed:(){searchController.clear();setState((){});},icon:const Icon(Icons.close_rounded)))),
        const SizedBox(height:14),
        if(children.isEmpty)Padding(padding:const EdgeInsets.all(24),child:Text('No settings match "$q".',textAlign:TextAlign.center))
        else for(final child in children)Padding(padding:const EdgeInsets.only(bottom:12),child:child),
        OutlinedButton.icon(onPressed:()=>_reset(s,t),icon:const Icon(Icons.restart_alt_rounded),label:Text(t('reset'))),
        const SizedBox(height:12),
        Text('Parin Office • Preferences are saved on this device.',textAlign:TextAlign.center,style:theme.textTheme.labelSmall?.copyWith(color:theme.colorScheme.onSurfaceVariant))
      ]));
  }

  Widget section(String title,String subtitle,IconData icon,List<Widget> children)=>Card(clipBehavior:Clip.antiAlias,child:Theme(
    data:Theme.of(context).copyWith(dividerColor:Colors.transparent),child:ExpansionTile(
      initiallyExpanded:true,tilePadding:const EdgeInsets.symmetric(horizontal:15,vertical:3),childrenPadding:const EdgeInsets.fromLTRB(12,0,12,14),
      leading:Container(width:40,height:40,decoration:BoxDecoration(color:Theme.of(context).colorScheme.primary.withAlpha(20),borderRadius:BorderRadius.circular(13)),child:Icon(icon,color:Theme.of(context).colorScheme.primary)),
      title:Text(title,style:const TextStyle(fontWeight:FontWeight.w900)),subtitle:Text(subtitle,maxLines:2,overflow:TextOverflow.ellipsis),children:children)));
  Widget switchRow(AppState s,String key,String title,String subtitle,{IconData? icon})=>SwitchListTile(
    value:s.flag(key),onChanged:(v)=>s.setFlag(key,v),contentPadding:const EdgeInsets.symmetric(horizontal:6),
    secondary:icon==null?null:Icon(icon),title:Text(title,style:const TextStyle(fontWeight:FontWeight.w700)),subtitle:Text(subtitle));

  Widget _appearance(BuildContext context,AppState s,String Function(String) t){
    final theme=Theme.of(context);
    final modes=< (AppearanceMode,String,IconData)>[
      (AppearanceMode.system,t('system'),Icons.settings_brightness_rounded),(AppearanceMode.light,t('light'),Icons.light_mode_outlined),
      (AppearanceMode.dark,t('dark'),Icons.dark_mode_outlined),(AppearanceMode.amoled,t('amoled'),Icons.contrast_rounded)];
    final choices=ThemeCatalog.presets.where((p){
      final category=switch(themeCategory){
        'Cool'=>const ['Ocean','Arctic','Indigo','Midnight','Violet'].contains(p.family),
        'Nature'=>const ['Mint','Forest','Sage','Lime'].contains(p.family),
        'Warm'=>const ['Sunset','Coral','Rose','Sand'].contains(p.family),
        'Minimal'=>const ['Mono','Stone'].contains(p.family),_=>true};
      return category&&(themeQuery.isEmpty||p.name.toLowerCase().contains(themeQuery.toLowerCase())||p.family.toLowerCase().contains(themeQuery.toLowerCase()));
    }).toList();
    return section(t('appearance'),'128 coordinated palettes • immediate preview',Icons.palette_outlined,[
      Padding(padding:const EdgeInsets.fromLTRB(4,7,4,7),child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:modes.map((m)=>Padding(
        padding:const EdgeInsetsDirectional.only(end:7),child:ChoiceChip(avatar:Icon(m.$3,size:17),label:Text(m.$2),selected:s.mode==m.$1,onSelected:(_)=>s.setMode(m.$1)))).toList()))),
      Padding(padding:const EdgeInsets.symmetric(horizontal:4,vertical:5),child:Text(t('paletteHint'),style:theme.textTheme.bodySmall?.copyWith(color:theme.colorScheme.onSurfaceVariant))),
      TextField(onChanged:(v)=>setState(()=>themeQuery=v),decoration:const InputDecoration(prefixIcon:Icon(Icons.search_rounded),hintText:'Find a palette (Ocean 3, Rose, Mono...)')),
      const SizedBox(height:10),
      Wrap(spacing:7,runSpacing:7,children:[for(final c in ['All','Cool','Nature','Warm','Minimal'])ChoiceChip(
        label:Text(c=='All'?t('all'):c=='Cool'?'Cool':c=='Nature'?'Nature':c=='Warm'?'Warm':'Minimal'),selected:themeCategory==c,onSelected:(_)=>setState(()=>themeCategory=c))]),
      const SizedBox(height:12),
      SizedBox(height:310,child:GridView.builder(itemCount:choices.length,
        gridDelegate:const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent:114,mainAxisExtent:86,crossAxisSpacing:9,mainAxisSpacing:9),
        itemBuilder:(context,i){final p=choices[i];final selected=s.preset.name==p.name;return InkWell(borderRadius:BorderRadius.circular(16),onTap:()=>s.setTheme(ThemeCatalog.presets.indexOf(p)),
          child:Container(padding:const EdgeInsets.all(8),decoration:BoxDecoration(color:theme.colorScheme.surface,borderRadius:BorderRadius.circular(16),border:Border.all(color:selected?theme.colorScheme.primary:theme.colorScheme.outlineVariant,width:selected?2:1)),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Expanded(child:ClipRRect(borderRadius:BorderRadius.circular(10),child:Row(children:[Expanded(child:ColoredBox(color:p.primary)),Expanded(child:ColoredBox(color:p.secondary)),Expanded(child:ColoredBox(color:theme.colorScheme.surfaceContainerHigh))]))),
              const SizedBox(height:6),Row(children:[Expanded(child:Text(p.name,maxLines:1,overflow:TextOverflow.ellipsis,style:theme.textTheme.labelSmall?.copyWith(fontWeight:FontWeight.w800))),if(selected)Icon(Icons.check_circle_rounded,color:theme.colorScheme.primary,size:15)])])));
        })),
      Padding(padding:const EdgeInsets.only(top:8),child:Text('Selected: ${s.preset.name}',style:theme.textTheme.labelMedium?.copyWith(color:theme.colorScheme.onSurfaceVariant)))
    ]);
  }

  Widget _language(BuildContext context,AppState s,String Function(String) t)=>section(t('language'),'16 locale choices • RTL-aware layout',Icons.translate_rounded,[
    Padding(padding:const EdgeInsets.all(6),child:DropdownButtonFormField<Locale>(
      value:s.locale,isExpanded:true,decoration:InputDecoration(labelText:t('language')),
      items:List.generate(L10n.locales.length,(i)=>DropdownMenuItem(value:L10n.locales[i],child:Text(L10n.names[i],overflow:TextOverflow.ellipsis))),
      onChanged:(v){if(v!=null)s.setLocale(v);})),
    Padding(padding:const EdgeInsets.fromLTRB(8,8,8,0),child:Text('Persian, Arabic and Hebrew use right-to-left layout; other locales use left-to-right layout.',
      style:Theme.of(context).textTheme.bodySmall?.copyWith(color:Theme.of(context).colorScheme.onSurfaceVariant)))
  ]);

  Widget _general(BuildContext context,AppState s,String Function(String) t)=>section(t('general'),'Interaction, autosave and recovery',Icons.tune_rounded,[
    switchRow(s,'autosave',t('autosave'),'Save a local draft while composing.',icon:Icons.save_outlined),
    switchRow(s,'autoRecovery',t('recovery'),'Restore the last local draft when opening a matching editor.',icon:Icons.history_rounded),
    switchRow(s,'animations',t('motion'),'Use gentle transitions between screens.',icon:Icons.animation_rounded),
    switchRow(s,'haptics',t('haptics'),'Use touch feedback when changing theme or saving.',icon:Icons.vibration_rounded),
    switchRow(s,'compact',t('compact'),'Reduce spacing in editor toolbars.',icon:Icons.view_compact_alt_outlined),
    switchRow(s,'keepRecent',t('keepRecent'),'Keep up to 20 document names on this device.',icon:Icons.history_toggle_off_rounded),
  ]);
  Widget _editor(BuildContext context,AppState s,String Function(String) t)=>section(t('editor'),'Editing and canvas helpers',Icons.edit_note_rounded,[
    switchRow(s,'spellCheck',t('spell'),'Enable keyboard autocorrect in the document composer.',icon:Icons.spellcheck_rounded),
    switchRow(s,'showGrid',t('grid'),'Keep grid preference enabled in workspace settings.',icon:Icons.grid_on_rounded),
    switchRow(s,'focusMode',t('focus'),'Use a less distracting composing canvas.',icon:Icons.center_focus_strong_rounded),
    switchRow(s,'safeSave',t('safeSave'),'Open the system Save As dialog for generated files.',icon:Icons.save_as_outlined),
  ]);
  Widget _security(BuildContext context,AppState s,String Function(String) t)=>section(t('security'),'Local data controls',Icons.shield_outlined,[
    switchRow(s,'diagnostics',t('diagnostics'),'Enable local diagnostics for troubleshooting.',icon:Icons.bug_report_outlined),
    const Padding(padding:EdgeInsets.fromLTRB(12,7,12,5),child:Text('Generated files and drafts stay on-device in these flows. Cloud sync, app lock and protected-document permissions are not enabled in this build.'))
  ]);
  Widget _accessibility(BuildContext context,AppState s,String Function(String) t)=>section(t('accessibility'),'Screen comfort and legibility',Icons.accessibility_new_rounded,[
    switchRow(s,'blueLightFilter',t('blue'),t('blueSub'),icon:Icons.remove_red_eye_outlined),
    Padding(padding:const EdgeInsets.fromLTRB(10,6,10,4),child:Column(children:[
      Row(children:[Expanded(child:Text(t('blueStrength'),style:const TextStyle(fontWeight:FontWeight.w700))),Text('${(s.blueStrength*100).round()}%')]),
      Slider(value:s.blueStrength,min:0,max:1,divisions:20,label:'${(s.blueStrength*100).round()}%',onChanged:s.setBlueStrength),
      Row(children:[Expanded(child:Text(t('textScale'),style:const TextStyle(fontWeight:FontWeight.w700))),Text('${(s.textScale*100).round()}%')]),
      Slider(value:s.textScale,min:0.85,max:1.35,divisions:10,label:'${(s.textScale*100).round()}%',onChanged:s.setTextScale),
    ])),
    switchRow(s,'highContrast',t('contrast'),'Increase visual separation across surfaces.',icon:Icons.contrast_rounded),
  ]);
  Widget _performance(BuildContext context,AppState s,String Function(String) t)=>section(t('performance'),'Applied immediately',Icons.speed_rounded,[
    ListTile(leading:const Icon(Icons.palette_outlined),title:const Text('Active palette'),subtitle:Text(s.preset.name),trailing:Container(width:26,height:26,decoration:BoxDecoration(color:s.preset.primary,borderRadius:BorderRadius.circular(8)))),
    ListTile(leading:const Icon(Icons.devices_rounded),title:const Text('Responsive layout'),subtitle:const Text('Navigation rail on wider layouts; bottom navigation on phones.')),
    ListTile(leading:const Icon(Icons.language_outlined),title:const Text('Text direction'),subtitle:Text(L10n.rtl(s.locale)?'Right-to-left':'Left-to-right')),
  ]);

  Future<void> _export(AppState s,String Function(String) t) async {
    final bytes=Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(s.exportablePreferences())));
    await FilePicker.saveFile(fileName:'parin-office-settings.json',bytes:bytes,mimeType:'application/json',dialogTitle:t('export'));
  }
  Future<void> _reset(AppState s,String Function(String) t) async {
    final yes=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:Text(t('reset')),content:Text(t('resetQuestion')),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(t('cancel'))),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(t('reset')))]));
    if(yes==true)await s.resetPreferences();
  }
}

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

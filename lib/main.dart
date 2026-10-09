import 'dart:typed_data';
import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'document_factory.dart';

void main(){WidgetsFlutterBinding.ensureInitialized();runApp(const ParinOfficeApp());}

enum AppearanceMode{system,light,dark,amoled}

class ThemePreset {
  const ThemePreset({required this.name, required this.family, required this.primary, required this.secondary});
  final String name;
  final String family;
  final Color primary;
  final Color secondary;
}

class ThemeCatalog {
  static const families = <String>[
    'Ocean', 'Indigo', 'Violet', 'Orchid', 'Rose', 'Coral', 'Amber', 'Lime',
    'Emerald', 'Jade', 'Teal', 'Cyan', 'Sky', 'Slate', 'Graphite', 'Sand',
  ];
  static const _hues = <double>[
    205, 231, 258, 282, 338, 8, 37, 75, 145, 164, 177, 190, 215, 222, 228, 36,
  ];

  static final presets = List<ThemePreset>.generate(128, (index) {
    final familyIndex = index ~/ 8;
    final variant = index % 8;
    final hue = (_hues[familyIndex] + (variant - 3.5) * 2.3 + 360) % 360;
    final saturation = 0.52 + (variant % 4) * 0.055;
    final lightness = 0.35 + (variant % 3) * 0.035;
    final primary = HSLColor.fromAHSL(1, hue, saturation, lightness).toColor();
    final secondary = HSLColor.fromAHSL(
      1, (hue + 27) % 360,
      (saturation - 0.04).clamp(0.42, 0.76).toDouble(),
      (lightness + 0.09).clamp(0.36, 0.62).toDouble(),
    ).toColor();
    return ThemePreset(
      name: families[familyIndex] + ' ' + (variant + 1).toString(),
      family: families[familyIndex],
      primary: primary,
      secondary: secondary,
    );
  });

  static ThemeData build(ThemePreset preset, Brightness brightness, bool amoled, {bool highContrast = false}) {
    final light = brightness == Brightness.light;
    final background = light ? const Color(0xFFF5F7FB) : (amoled ? Colors.black : const Color(0xFF101319));
    final surface = light ? Colors.white : (amoled ? Colors.black : const Color(0xFF171B23));
    final surfaceLow = light ? const Color(0xFFEEF2F8) : (amoled ? const Color(0xFF050506) : const Color(0xFF1D222C));
    final surfaceHigh = light ? const Color(0xFFE5EAF3) : (amoled ? const Color(0xFF0D0D10) : const Color(0xFF262C37));
    final outline = highContrast
        ? (light ? const Color(0xFF303745) : const Color(0xFFE4E8EF))
        : (light ? const Color(0xFFD7DEEA) : const Color(0xFF343B48));
    final seed = ColorScheme.fromSeed(seedColor: preset.primary, brightness: brightness);
    final scheme = seed.copyWith(
      primary: preset.primary,
      onPrimary: Colors.white,
      secondary: preset.secondary,
      surface: surface,
      surfaceContainerLowest: background,
      surfaceContainerLow: surfaceLow,
      surfaceContainer: surface,
      surfaceContainerHigh: surfaceHigh,
      surfaceContainerHighest: surfaceHigh,
      outline: outline,
      outlineVariant: outline,
      onSurface: light ? const Color(0xFF182031) : const Color(0xFFF0F3F8),
      onSurfaceVariant: light ? const Color(0xFF5E6879) : const Color(0xFFABB4C3),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(centerTitle: false, scrolledUnderElevation: 0, backgroundColor: background, foregroundColor: scheme.onSurface),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: outline.withValues(alpha: 0.55)),
        ),
      ),
      dividerTheme: DividerThemeData(color: outline.withValues(alpha: 0.7), thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLow,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: outline)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: outline)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: preset.primary, width: 1.8)),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: outline),
        labelStyle: TextStyle(color: scheme.onSurface),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class AppState extends ChangeNotifier {
  Locale locale = const Locale('en');
  AppearanceMode mode = AppearanceMode.system;
  int themeIndex = 9;
  double blueStrength = 0.42;
  double textScale = 1;
  double defaultZoom = 1;
  double editorFontSize = 16;
  String themeQuery = '';
  Set<int> favoriteThemes = <int>{};
  List<String> recentDocuments = <String>[];

  static const defaults = <String, bool>{
    'autosave': true, 'animations': true, 'haptics': true, 'compactRibbon': false,
    'confirmExport': false, 'showExtensions': true, 'smartPunctuation': true,
    'spellAssist': true, 'showGridlines': true, 'showRulers': true,
    'autoRecovery': true, 'reduceMotion': false, 'highContrast': false,
    'lowMemoryMode': false, 'previewThumbnails': true, 'offlineOnly': true,
    'diagnostics': false, 'restoreDrafts': true, 'protectSourceFiles': true,
    'showStatusBar': true, 'blueLightFilter': false,
  };
  final Map<String, bool> _flags = Map<String, bool>.from(defaults);

  bool flag(String key) => _flags[key] ?? false;
  bool get autosave => flag('autosave');
  bool get animations => flag('animations');
  bool get haptics => flag('haptics');
  bool get compactRibbon => flag('compactRibbon');
  bool get diagnostics => flag('diagnostics');
  ThemePreset get preset => ThemeCatalog.presets[themeIndex.clamp(0, 127).toInt()];
  bool get amoled => mode == AppearanceMode.amoled;
  Brightness get brightness {
    switch (mode) {
      case AppearanceMode.system:
        return WidgetsBinding.instance.platformDispatcher.platformBrightness;
      case AppearanceMode.light:
        return Brightness.light;
      case AppearanceMode.dark:
      case AppearanceMode.amoled:
        return Brightness.dark;
    }
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final rawLocale = prefs.getString('locale');
    if (rawLocale != null) {
      final exact = L10n.locales.where((item) => item.toLanguageTag().toLowerCase() == rawLocale.toLowerCase());
      locale = exact.isNotEmpty
          ? exact.first
          : L10n.locales.firstWhere(
              (item) => item.languageCode == rawLocale.split('-').first,
              orElse: () => const Locale('en'),
            );
    }
    mode = AppearanceMode.values.firstWhere((item) => item.name == prefs.getString('mode'), orElse: () => AppearanceMode.system);
    themeIndex = (prefs.getInt('theme') ?? 9).clamp(0, 127).toInt();
    blueStrength = (prefs.getDouble('blueStrength') ?? 0.42).clamp(0.0, 1.0).toDouble();
    textScale = (prefs.getDouble('textScale') ?? 1).clamp(0.85, 1.4).toDouble();
    defaultZoom = (prefs.getDouble('defaultZoom') ?? 1).clamp(0.5, 1.5).toDouble();
    editorFontSize = (prefs.getDouble('editorFontSize') ?? 16).clamp(12.0, 26.0).toDouble();
    favoriteThemes = (prefs.getStringList('favoriteThemes') ?? <String>[])
        .map(int.tryParse).whereType<int>().where((index) => index >= 0 && index < 128).toSet();
    recentDocuments = prefs.getStringList('recentDocuments') ?? <String>[];
    for (final key in defaults.keys) {
      final legacyKey = key == 'compactRibbon' ? 'compact' : key;
      _flags[key] = prefs.getBool('settings.' + key) ?? prefs.getBool(legacyKey) ?? defaults[key]!;
    }
    notifyListeners();
  }

  Future<void> setLocale(Locale value) async {
    locale = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', value.toLanguageTag());
  }

  Future<void> setMode(AppearanceMode value) async {
    mode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mode', value.name);
  }

  Future<void> setTheme(int value) async {
    themeIndex = value.clamp(0, 127).toInt();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme', themeIndex);
  }

  Future<void> toggleFavoriteTheme(int index) async {
    if (!favoriteThemes.add(index)) favoriteThemes.remove(index);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favoriteThemes', favoriteThemes.map((item) => item.toString()).toList());
  }

  Future<void> setFlag(String key, bool value) async {
    if (key == 'compact') key = 'compactRibbon';
    _flags[key] = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('settings.' + key, value);
    await prefs.setBool(key, value);
  }

  Future<void> setNumeric(String key, double value) async {
    switch (key) {
      case 'blueStrength': blueStrength = value.clamp(0.0, 1.0).toDouble(); break;
      case 'textScale': textScale = value.clamp(0.85, 1.4).toDouble(); break;
      case 'defaultZoom': defaultZoom = value.clamp(0.5, 1.5).toDouble(); break;
      case 'editorFontSize': editorFontSize = value.clamp(12.0, 26.0).toDouble(); break;
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(key, value);
  }

  Future<void> markRecent(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    recentDocuments.removeWhere((item) => item == clean);
    recentDocuments.insert(0, clean);
    if (recentDocuments.length > 40) recentDocuments = recentDocuments.take(40).toList();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('recentDocuments', recentDocuments);
  }

  Future<void> clearRecents() async {
    recentDocuments.clear();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('recentDocuments');
  }

  Future<void> saveDraft(String name, String content) async {
    if (!flag('autosave') || !flag('autoRecovery')) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('draft.' + name, content);
  }

  Future<String?> loadDraft(String name) async {
    if (!flag('restoreDrafts')) return null;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('draft.' + name);
  }

  Future<void> clearDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where((item) => item.startsWith('draft.')).toList()) {
      await prefs.remove(key);
    }
    notifyListeners();
  }

  void setThemeQuery(String value) {
    themeQuery = value;
    notifyListeners();
  }
}

class L10n {
  static const locales = <Locale>[
    Locale('fa'), Locale('en'), Locale('da'), Locale('de'), Locale('de', 'CH'),
    Locale('ar'), Locale('hi'), Locale('he'), Locale('es'), Locale('it'),
    Locale('sv'), Locale('fi'), Locale('no'), Locale('is'), Locale('el'), Locale('tr'),
  ];
  static const names = <String>[
    'فارسی', 'English', 'Dansk', 'Deutsch', 'Schweizerdeutsch', 'العربية',
    'हिन्दी', 'עברית', 'Español', 'Italiano', 'Svenska', 'Suomi', 'Norsk', 'Íslenska', 'Ελληνικά', 'Türkçe',
  ];

  static const _en = <String, String>{
    'home':'Home','recent':'Recent files','workspace':'Workspace','settings':'Settings',
    'open':'Open file','create':'Create new','pdf':'PDF','word':'Word','powerpoint':'PowerPoint','excel':'Excel',
    'quick':'Quick actions','themes':'Color themes','language':'Language','appearance':'Appearance',
    'general':'General','editor':'Editor preferences','security':'Privacy & security','performance':'Performance',
    'accessibility':'Accessibility','light':'Light','dark':'Dark','amoled':'AMOLED black','system':'System',
    'search':'Search','newDocument':'New document','welcome':'Your work, beautifully organized.',
    'welcomeSubtitle':'Create, edit and export documents from one calm workspace.',
    'createPdf':'Create PDF','createWord':'Create Word file','createPowerPoint':'Create presentation','createExcel':'Create spreadsheet',
    'documentTitle':'Document title','cancel':'Cancel','done':'Done','save':'Save / Export',
    'noRecent':'No recent documents yet','clearRecent':'Clear recent documents','clearDrafts':'Clear saved drafts',
    'blueFilter':'Blue-light filter','blueFilterSubtitle':'Optional warm tint for evening use','strength':'Filter strength',
    'selectedTheme':'Selected theme','allThemes':'All themes','favorites':'Favorites',
    'autosave':'Autosave local drafts','animations':'Animated transitions','haptics':'Haptic feedback',
    'compactRibbon':'Compact editor toolbar','confirmExport':'Confirm before export','showExtensions':'Show file extensions',
    'smartPunctuation':'Smart punctuation','spellAssist':'Writing assistance hints','showGridlines':'Spreadsheet gridlines',
    'showRulers':'Editor rulers','autoRecovery':'Save recovery copy','reduceMotion':'Reduce motion',
    'highContrast':'High contrast','lowMemoryMode':'Low-memory mode','previewThumbnails':'Show preview thumbnails',
    'offlineOnly':'Prefer offline processing','diagnostics':'Show local diagnostics','restoreDrafts':'Restore saved drafts',
    'protectSourceFiles':'Protect source files','showStatusBar':'Show editor status bar',
    'textScale':'Interface text size','defaultZoom':'Default document zoom','fontSize':'Editor font size',
    'generalSubtitle':'Saved settings that affect the workspace','recentSubtitle':'Continue where you left off',
    'subtitlePdf':'Create a PDF and open it in PDF Studio','subtitleWord':'Edit text and export a DOCX file',
    'subtitlePowerPoint':'Compose a slide and export a PPTX file','subtitleExcel':'Separate columns with tabs and rows with new lines',
    'saveHint':'Your file is generated on this device.',
    'existingFileNote':'Imported Office files are not fully parsed yet. Saving exports a new file from this editor text.',
    'spreadsheetHint':'Tip: separate columns with a Tab; each new line becomes a row.',
    'draftSaved':'Draft saved on this device','exported':'File exported','openFailed':'Could not open that file',
    'onDevice':'On this device','about':'About Parin Office',
    'aboutText':'PDF editing is integrated and DOCX/PPTX/XLSX creation is enabled. Full native editing for imported Office files is still under development.',
  };
  static const _fa = <String, String>{
    'home':'خانه','recent':'فایل‌های اخیر','workspace':'فضای کار','settings':'تنظیمات','open':'باز کردن فایل','create':'ساخت فایل',
    'pdf':'PDF','word':'Word','powerpoint':'PowerPoint','excel':'Excel','quick':'عملیات سریع','themes':'تم‌های رنگی',
    'language':'زبان','appearance':'ظاهر برنامه','general':'عمومی','editor':'تنظیمات ویرایشگر',
    'security':'حریم خصوصی و امنیت','performance':'کارایی','accessibility':'دسترس‌پذیری','light':'روشن','dark':'تاریک',
    'amoled':'مشکی AMOLED','system':'سیستم','search':'جستجو','newDocument':'سند جدید',
    'welcome':'همه کارهایت، مرتب و حرفه‌ای.','welcomeSubtitle':'اسناد را در یک فضای کاری خلوت بساز، ویرایش و صادر کن.',
    'createPdf':'ساخت PDF','createWord':'ساخت فایل Word','createPowerPoint':'ساخت ارائه','createExcel':'ساخت صفحه‌گسترده',
    'documentTitle':'عنوان سند','cancel':'انصراف','done':'تأیید','save':'ذخیره / خروجی',
    'noRecent':'هنوز سندی باز نشده است','clearRecent':'پاک کردن فایل‌های اخیر','clearDrafts':'پاک کردن پیش‌نویس‌ها',
    'blueFilter':'فیلتر نور آبی','blueFilterSubtitle':'ته‌رنگ گرم و اختیاری برای شب','strength':'شدت فیلتر',
    'selectedTheme':'تم انتخاب‌شده','allThemes':'همه تم‌ها','favorites':'علاقه‌مندی‌ها',
    'autosave':'ذخیره خودکار پیش‌نویس','animations':'انیمیشن انتقال‌ها','haptics':'بازخورد لرزشی',
    'compactRibbon':'نوار ابزار فشرده','confirmExport':'تأیید پیش از خروجی','showExtensions':'نمایش پسوند فایل',
    'smartPunctuation':'نشانه‌گذاری هوشمند','spellAssist':'راهنمای نوشتار','showGridlines':'خطوط جدول اکسل',
    'showRulers':'خط‌کش ویرایشگر','autoRecovery':'ذخیره نسخه بازیابی','reduceMotion':'کاهش حرکت و انیمیشن',
    'highContrast':'کنتراست بالا','lowMemoryMode':'حالت حافظه کم','previewThumbnails':'نمایش پیش‌نمایش',
    'offlineOnly':'پردازش ترجیحاً آفلاین','diagnostics':'نمایش اطلاعات فنی محلی','restoreDrafts':'بازیابی پیش‌نویس',
    'protectSourceFiles':'محافظت از فایل اصلی','showStatusBar':'نمایش نوار وضعیت','textScale':'اندازه نوشته‌های رابط',
    'defaultZoom':'بزرگ‌نمایی پیش‌فرض','fontSize':'اندازه متن ویرایشگر',
    'generalSubtitle':'گزینه‌هایی که ذخیره می‌شوند و روی محیط کار اثر دارند','recentSubtitle':'ادامه از آخرین نقطه',
    'subtitlePdf':'ساخت PDF و باز کردن در استودیوی PDF','subtitleWord':'ویرایش متن و خروجی DOCX',
    'subtitlePowerPoint':'ساخت اسلاید و خروجی PPTX','subtitleExcel':'ستون‌ها با Tab و ردیف‌ها با خط جدید جدا می‌شوند',
    'saveHint':'فایل روی همین دستگاه تولید می‌شود.',
    'existingFileNote':'خواندن کامل فایل‌های آفیس واردشده هنوز فعال نیست؛ ذخیره، فایل تازه‌ای از متن این ویرایشگر می‌سازد.',
    'spreadsheetHint':'نکته: ستون‌ها را با Tab جدا کن؛ هر خط یک ردیف است.','draftSaved':'پیش‌نویس روی دستگاه ذخیره شد',
    'exported':'فایل صادر شد','openFailed':'باز کردن فایل ممکن نشد','onDevice':'روی دستگاه',
    'about':'درباره Parin Office','aboutText':'ویرایش PDF یکپارچه است و ساخت DOCX/PPTX/XLSX فعال است؛ ویرایش کامل فایل‌های آفیس واردشده در حال توسعه است.',
  };
  static const _ar = <String, String>{
    'home':'الرئيسية','recent':'الملفات الأخيرة','workspace':'مساحة العمل','settings':'الإعدادات','open':'فتح ملف','create':'إنشاء جديد',
    'pdf':'PDF','word':'Word','powerpoint':'PowerPoint','excel':'Excel','quick':'إجراءات سريعة','themes':'سمات الألوان',
    'language':'اللغة','appearance':'المظهر','general':'عام','editor':'إعدادات المحرر','security':'الخصوصية والأمان',
    'performance':'الأداء','accessibility':'إمكانية الوصول','light':'فاتح','dark':'داكن','amoled':'أسود AMOLED','system':'النظام',
    'search':'بحث','newDocument':'مستند جديد','welcome':'عملك، منظم باحتراف.','welcomeSubtitle':'أنشئ المستندات وعدّلها وصدّرها من مساحة واحدة.',
    'createPdf':'إنشاء PDF','createWord':'إنشاء ملف Word','createPowerPoint':'إنشاء عرض','createExcel':'إنشاء جدول بيانات',
    'documentTitle':'عنوان المستند','cancel':'إلغاء','done':'تم','save':'حفظ / تصدير',
    'noRecent':'لا توجد مستندات حديثة بعد','clearRecent':'مسح الملفات الأخيرة','clearDrafts':'مسح المسودات المحفوظة',
    'blueFilter':'مرشح الضوء الأزرق','blueFilterSubtitle':'درجة دافئة اختيارية للمساء','strength':'قوة المرشح',
    'selectedTheme':'السمة المحددة','allThemes':'كل السمات','favorites':'المفضلة',
    'autosave':'حفظ المسودات تلقائياً','animations':'انتقالات متحركة','haptics':'الاهتزاز اللمسي',
    'compactRibbon':'شريط أدوات مضغوط','confirmExport':'التأكيد قبل التصدير','showExtensions':'إظهار امتدادات الملفات',
    'smartPunctuation':'ترقيم ذكي','spellAssist':'تلميحات الكتابة','showGridlines':'خطوط جدول البيانات',
    'showRulers':'مساطر المحرر','autoRecovery':'حفظ نسخة للاسترداد','reduceMotion':'تقليل الحركة','highContrast':'تباين عالٍ',
    'lowMemoryMode':'وضع ذاكرة منخفضة','previewThumbnails':'إظهار المعاينات','offlineOnly':'تفضيل المعالجة دون اتصال',
    'diagnostics':'عرض معلومات التشخيص المحلية','restoreDrafts':'استعادة المسودات','protectSourceFiles':'حماية الملفات الأصلية',
    'showStatusBar':'إظهار شريط الحالة','textScale':'حجم نص الواجهة','defaultZoom':'تكبير المستند الافتراضي','fontSize':'حجم خط المحرر',
    'generalSubtitle':'إعدادات محفوظة تؤثر في مساحة العمل','recentSubtitle':'تابع من آخر نقطة',
    'subtitlePdf':'أنشئ PDF وافتحه في استوديو PDF','subtitleWord':'حرّر النص وصدّره كملف DOCX',
    'subtitlePowerPoint':'أنشئ شريحة وصدّرها كملف PPTX','subtitleExcel':'افصل الأعمدة بعلامة تبويب والصفوف بأسطر جديدة',
    'saveHint':'يتم إنشاء الملف على هذا الجهاز.','existingFileNote':'قراءة ملفات Office المستوردة بالكامل قيد التطوير؛ الحفظ ينشئ ملفاً جديداً من نص المحرر.',
    'spreadsheetHint':'نصيحة: Tab يفصل الأعمدة وكل سطر يمثل صفاً.','draftSaved':'تم حفظ المسودة على الجهاز','exported':'تم تصدير الملف',
    'openFailed':'تعذر فتح الملف','onDevice':'على الجهاز','about':'حول Parin Office',
    'aboutText':'تحرير PDF مدمج وإنشاء DOCX/PPTX/XLSX متاح؛ تحرير ملفات Office المستوردة بالكامل ما زال قيد التطوير.',
  };
  static const _de = <String, String>{
    'home':'Startseite','recent':'Zuletzt verwendet','workspace':'Arbeitsbereich','settings':'Einstellungen','open':'Datei öffnen','create':'Neu erstellen',
    'pdf':'PDF','word':'Word','powerpoint':'PowerPoint','excel':'Excel','quick':'Schnellaktionen','themes':'Farbthemen',
    'language':'Sprache','appearance':'Darstellung','general':'Allgemein','editor':'Editor-Einstellungen','security':'Datenschutz & Sicherheit',
    'performance':'Leistung','accessibility':'Barrierefreiheit','light':'Hell','dark':'Dunkel','amoled':'AMOLED-Schwarz','system':'System',
    'search':'Suchen','newDocument':'Neues Dokument','welcome':'Deine Arbeit. Klar organisiert.','welcomeSubtitle':'Dokumente an einem Ort erstellen, bearbeiten und exportieren.',
    'createPdf':'PDF erstellen','createWord':'Word-Datei erstellen','createPowerPoint':'Präsentation erstellen','createExcel':'Tabelle erstellen',
    'documentTitle':'Dokumenttitel','cancel':'Abbrechen','done':'Fertig','save':'Speichern / Exportieren',
    'noRecent':'Noch keine aktuellen Dokumente','clearRecent':'Zuletzt verwendete Dateien löschen','clearDrafts':'Gespeicherte Entwürfe löschen',
    'blueFilter':'Blaulichtfilter','blueFilterSubtitle':'Optionaler warmer Farbton am Abend','strength':'Filterstärke',
    'selectedTheme':'Ausgewähltes Thema','allThemes':'Alle Themen','favorites':'Favoriten','autosave':'Entwürfe automatisch speichern',
    'animations':'Animierte Übergänge','haptics':'Haptisches Feedback','compactRibbon':'Kompakte Symbolleiste',
    'confirmExport':'Export bestätigen','showExtensions':'Dateiendungen anzeigen','smartPunctuation':'Intelligente Zeichensetzung',
    'spellAssist':'Schreibhilfen','showGridlines':'Tabellenraster','showRulers':'Editor-Lineale','autoRecovery':'Wiederherstellungskopie speichern',
    'reduceMotion':'Bewegung reduzieren','highContrast':'Hoher Kontrast','lowMemoryMode':'Speichersparmodus','previewThumbnails':'Vorschauen anzeigen',
    'offlineOnly':'Offline-Verarbeitung bevorzugen','diagnostics':'Lokale Diagnose anzeigen','restoreDrafts':'Gespeicherte Entwürfe wiederherstellen',
    'protectSourceFiles':'Quelldateien schützen','showStatusBar':'Statusleiste anzeigen','textScale':'Textgröße der Oberfläche',
    'defaultZoom':'Standard-Zoom','fontSize':'Editor-Schriftgröße','generalSubtitle':'Gespeicherte Optionen für den Arbeitsbereich',
    'recentSubtitle':'Dort weitermachen, wo du aufgehört hast','subtitlePdf':'PDF erstellen und im PDF-Studio öffnen',
    'subtitleWord':'Text bearbeiten und als DOCX exportieren','subtitlePowerPoint':'Folie erstellen und als PPTX exportieren',
    'subtitleExcel':'Spalten mit Tab, Zeilen mit Zeilenumbruch trennen','saveHint':'Die Datei wird auf diesem Gerät erstellt.',
    'existingFileNote':'Das vollständige Einlesen importierter Office-Dateien ist noch in Arbeit; Speichern erstellt eine neue Datei aus dem Editor-Text.',
    'spreadsheetHint':'Tipp: Tab trennt Spalten; jede neue Zeile ergibt eine Zeile.','draftSaved':'Entwurf lokal gespeichert',
    'exported':'Datei exportiert','openFailed':'Datei konnte nicht geöffnet werden','onDevice':'Auf diesem Gerät',
    'about':'Über Parin Office','aboutText':'PDF-Bearbeitung ist integriert, DOCX/PPTX/XLSX-Erstellung ist aktiv. Vollständige Bearbeitung importierter Office-Dateien ist in Arbeit.',
  };
  static const _es = <String, String>{
    'home':'Inicio','recent':'Archivos recientes','workspace':'Espacio de trabajo','settings':'Ajustes','open':'Abrir archivo','create':'Crear nuevo',
    'pdf':'PDF','word':'Word','powerpoint':'PowerPoint','excel':'Excel','quick':'Acciones rápidas','themes':'Temas de color',
    'language':'Idioma','appearance':'Apariencia','general':'General','editor':'Preferencias del editor','security':'Privacidad y seguridad',
    'performance':'Rendimiento','accessibility':'Accesibilidad','light':'Claro','dark':'Oscuro','amoled':'Negro AMOLED','system':'Sistema',
    'search':'Buscar','newDocument':'Documento nuevo','welcome':'Tu trabajo, bien organizado.','welcomeSubtitle':'Crea, edita y exporta documentos desde un solo espacio.',
    'createPdf':'Crear PDF','createWord':'Crear archivo Word','createPowerPoint':'Crear presentación','createExcel':'Crear hoja de cálculo',
    'documentTitle':'Título del documento','cancel':'Cancelar','done':'Listo','save':'Guardar / Exportar',
    'noRecent':'Aún no hay documentos recientes','clearRecent':'Borrar archivos recientes','clearDrafts':'Borrar borradores guardados',
    'blueFilter':'Filtro de luz azul','blueFilterSubtitle':'Tinte cálido opcional para la noche','strength':'Intensidad del filtro',
    'selectedTheme':'Tema seleccionado','allThemes':'Todos los temas','favorites':'Favoritos','autosave':'Guardar borradores automáticamente',
    'animations':'Transiciones animadas','haptics':'Respuesta háptica','compactRibbon':'Barra de herramientas compacta',
    'confirmExport':'Confirmar antes de exportar','showExtensions':'Mostrar extensiones de archivo','smartPunctuation':'Puntuación inteligente',
    'spellAssist':'Ayudas de escritura','showGridlines':'Cuadrícula de hoja de cálculo','showRulers':'Reglas del editor',
    'autoRecovery':'Guardar copia de recuperación','reduceMotion':'Reducir movimiento','highContrast':'Alto contraste',
    'lowMemoryMode':'Modo de poca memoria','previewThumbnails':'Mostrar vistas previas','offlineOnly':'Preferir procesamiento sin conexión',
    'diagnostics':'Mostrar diagnóstico local','restoreDrafts':'Restaurar borradores guardados','protectSourceFiles':'Proteger archivos originales',
    'showStatusBar':'Mostrar barra de estado','textScale':'Tamaño del texto de la interfaz','defaultZoom':'Zoom predeterminado',
    'fontSize':'Tamaño de letra del editor','generalSubtitle':'Opciones guardadas del espacio de trabajo',
    'recentSubtitle':'Continúa donde lo dejaste','subtitlePdf':'Crea un PDF y ábrelo en PDF Studio','subtitleWord':'Edita texto y expórtalo como DOCX',
    'subtitlePowerPoint':'Crea una diapositiva y expórtala como PPTX','subtitleExcel':'Separa columnas con tabulaciones y filas con saltos de línea',
    'saveHint':'El archivo se genera en este dispositivo.','existingFileNote':'La lectura completa de Office importado sigue en desarrollo; guardar crea un archivo nuevo a partir del texto del editor.',
    'spreadsheetHint':'Consejo: Tab separa columnas; cada línea nueva crea una fila.','draftSaved':'Borrador guardado en este dispositivo',
    'exported':'Archivo exportado','openFailed':'No se pudo abrir el archivo','onDevice':'En este dispositivo',
    'about':'Acerca de Parin Office','aboutText':'La edición PDF está integrada y la creación DOCX/PPTX/XLSX está disponible. La edición nativa completa de Office importado sigue en desarrollo.',
  };
  static const _it = <String, String>{
    'home':'Home','recent':'File recenti','workspace':'Area di lavoro','settings':'Impostazioni','open':'Apri file','create':'Crea nuovo',
    'pdf':'PDF','word':'Word','powerpoint':'PowerPoint','excel':'Excel','quick':'Azioni rapide','themes':'Temi colore',
    'language':'Lingua','appearance':'Aspetto','general':'Generale','editor':'Preferenze editor','security':'Privacy e sicurezza',
    'performance':'Prestazioni','accessibility':'Accessibilità','light':'Chiaro','dark':'Scuro','amoled':'Nero AMOLED','system':'Sistema',
    'search':'Cerca','newDocument':'Nuovo documento','welcome':'Il tuo lavoro, ben organizzato.','welcomeSubtitle':'Crea, modifica ed esporta documenti da un unico spazio.',
    'createPdf':'Crea PDF','createWord':'Crea file Word','createPowerPoint':'Crea presentazione','createExcel':'Crea foglio di calcolo',
    'documentTitle':'Titolo documento','cancel':'Annulla','done':'Fatto','save':'Salva / Esporta',
    'noRecent':'Nessun documento recente','clearRecent':'Cancella file recenti','clearDrafts':'Cancella bozze salvate',
    'blueFilter':'Filtro luce blu','blueFilterSubtitle':'Tinta calda facoltativa per la sera','strength':'Intensità filtro',
    'selectedTheme':'Tema selezionato','allThemes':'Tutti i temi','favorites':'Preferiti','autosave':'Salvataggio automatico bozze',
    'animations':'Transizioni animate','haptics':'Feedback aptico','compactRibbon':'Barra strumenti compatta',
    'confirmExport':'Conferma prima di esportare','showExtensions':'Mostra estensioni file','smartPunctuation':'Punteggiatura intelligente',
    'spellAssist':'Suggerimenti di scrittura','showGridlines':'Griglia foglio di calcolo','showRulers':'Righelli editor',
    'autoRecovery':'Salva copia di ripristino','reduceMotion':'Riduci movimento','highContrast':'Contrasto elevato',
    'lowMemoryMode':'Modalità memoria ridotta','previewThumbnails':'Mostra anteprime','offlineOnly':'Preferisci elaborazione offline',
    'diagnostics':'Mostra diagnostica locale','restoreDrafts':'Ripristina bozze salvate','protectSourceFiles':'Proteggi file originali',
    'showStatusBar':'Mostra barra di stato','textScale':'Dimensione testo interfaccia','defaultZoom':'Zoom predefinito',
    'fontSize':'Dimensione carattere editor','generalSubtitle':'Opzioni salvate dell’area di lavoro',
    'recentSubtitle':'Riprendi da dove eri rimasto','subtitlePdf':'Crea un PDF e aprilo in PDF Studio','subtitleWord':'Modifica testo ed esporta in DOCX',
    'subtitlePowerPoint':'Crea una diapositiva ed esporta in PPTX','subtitleExcel':'Separa colonne con Tab e righe con nuove righe',
    'saveHint':'Il file viene generato su questo dispositivo.','existingFileNote':'La lettura completa dei file Office importati è in sviluppo; il salvataggio crea un nuovo file dal testo dell’editor.',
    'spreadsheetHint':'Suggerimento: Tab separa le colonne; ogni nuova riga crea una riga.','draftSaved':'Bozza salvata sul dispositivo',
    'exported':'File esportato','openFailed':'Impossibile aprire il file','onDevice':'Su questo dispositivo',
    'about':'Informazioni su Parin Office','aboutText':'La modifica PDF è integrata e la creazione DOCX/PPTX/XLSX è disponibile; la modifica nativa completa dei file Office importati è in sviluppo.',
  };
  static const _tr = <String, String>{
    'home':'Ana sayfa','recent':'Son dosyalar','workspace':'Çalışma alanı','settings':'Ayarlar','open':'Dosya aç','create':'Yeni oluştur',
    'pdf':'PDF','word':'Word','powerpoint':'PowerPoint','excel':'Excel','quick':'Hızlı işlemler','themes':'Renk temaları',
    'language':'Dil','appearance':'Görünüm','general':'Genel','editor':'Düzenleyici tercihleri','security':'Gizlilik ve güvenlik',
    'performance':'Performans','accessibility':'Erişilebilirlik','light':'Açık','dark':'Koyu','amoled':'AMOLED siyahı','system':'Sistem',
    'search':'Ara','newDocument':'Yeni belge','welcome':'İşlerin düzenli ve profesyonel.','welcomeSubtitle':'Belgeleri tek bir çalışma alanında oluştur, düzenle ve dışa aktar.',
    'createPdf':'PDF oluştur','createWord':'Word dosyası oluştur','createPowerPoint':'Sunum oluştur','createExcel':'E-tablo oluştur',
    'documentTitle':'Belge başlığı','cancel':'İptal','done':'Tamam','save':'Kaydet / Dışa aktar',
    'noRecent':'Henüz son belge yok','clearRecent':'Son dosyaları temizle','clearDrafts':'Kaydedilmiş taslakları temizle',
    'blueFilter':'Mavi ışık filtresi','blueFilterSubtitle':'Akşam için isteğe bağlı sıcak ton','strength':'Filtre gücü',
    'selectedTheme':'Seçili tema','allThemes':'Tüm temalar','favorites':'Favoriler',
    'autosave':'Taslakları otomatik kaydet','animations':'Animasyonlu geçişler','haptics':'Dokunsal geri bildirim',
    'compactRibbon':'Kompakt araç çubuğu','confirmExport':'Dışa aktarmadan önce onayla','showExtensions':'Dosya uzantılarını göster',
    'smartPunctuation':'Akıllı noktalama','spellAssist':'Yazım yardımcıları','showGridlines':'Tablo kılavuz çizgileri',
    'showRulers':'Düzenleyici cetvelleri','autoRecovery':'Kurtarma kopyasını kaydet','reduceMotion':'Hareketi azalt',
    'highContrast':'Yüksek kontrast','lowMemoryMode':'Düşük bellek modu','previewThumbnails':'Önizlemeleri göster',
    'offlineOnly':'Çevrimdışı işlemeyi tercih et','diagnostics':'Yerel tanılamayı göster','restoreDrafts':'Kaydedilmiş taslakları geri yükle',
    'protectSourceFiles':'Kaynak dosyaları koru','showStatusBar':'Durum çubuğunu göster','textScale':'Arayüz metin boyutu',
    'defaultZoom':'Varsayılan yakınlaştırma','fontSize':'Düzenleyici yazı boyutu','generalSubtitle':'Çalışma alanını etkileyen kayıtlı seçenekler',
    'recentSubtitle':'Kaldığın yerden devam et','subtitlePdf':'PDF oluştur ve PDF Studio’da aç',
    'subtitleWord':'Metni düzenle ve DOCX olarak dışa aktar','subtitlePowerPoint':'Slayt oluştur ve PPTX olarak dışa aktar',
    'subtitleExcel':'Sütunları Tab, satırları yeni satırla ayır','saveHint':'Dosya bu cihazda oluşturulur.',
    'existingFileNote':'İçe aktarılan Office dosyalarının tam okunması geliştirme aşamasında; kaydetme yeni dosya oluşturur.',
    'spreadsheetHint':'İpucu: Tab sütunları ayırır; her yeni satır bir satır oluşturur.','draftSaved':'Taslak bu cihaza kaydedildi',
    'exported':'Dosya dışa aktarıldı','openFailed':'Dosya açılamadı','onDevice':'Bu cihazda','about':'Parin Office hakkında',
    'aboutText':'PDF düzenleme tümleşiktir; DOCX/PPTX/XLSX oluşturma etkin. İçe aktarılan Office dosyalarının tam düzenlemesi geliştiriliyor.',
  };
  static const _he = <String, String>{
    'home':'בית','recent':'קבצים אחרונים','workspace':'סביבת עבודה','settings':'הגדרות','open':'פתיחת קובץ','create':'יצירה חדשה',
    'pdf':'PDF','word':'Word','powerpoint':'PowerPoint','excel':'Excel','quick':'פעולות מהירות','themes':'ערכות צבע',
    'language':'שפה','appearance':'מראה','general':'כללי','editor':'העדפות העורך','security':'פרטיות ואבטחה','performance':'ביצועים',
    'accessibility':'נגישות','light':'בהיר','dark':'כהה','amoled':'שחור AMOLED','system':'מערכת','search':'חיפוש',
    'newDocument':'מסמך חדש','welcome':'העבודה שלך, מסודרת היטב.','welcomeSubtitle':'יצירה, עריכה וייצוא של מסמכים מסביבת עבודה אחת.',
    'createPdf':'יצירת PDF','createWord':'יצירת קובץ Word','createPowerPoint':'יצירת מצגת','createExcel':'יצירת גיליון',
    'documentTitle':'כותרת המסמך','cancel':'ביטול','done':'סיום','save':'שמירה / ייצוא','noRecent':'אין עדיין מסמכים אחרונים',
    'clearRecent':'ניקוי קבצים אחרונים','clearDrafts':'ניקוי טיוטות שמורות','blueFilter':'מסנן אור כחול',
    'blueFilterSubtitle':'גוון חם אופציונלי לשעות הערב','strength':'עוצמת המסנן','selectedTheme':'ערכת הצבע שנבחרה',
    'allThemes':'כל הערכות','favorites':'מועדפים','autosave':'שמירה אוטומטית של טיוטות','animations':'מעברים מונפשים',
    'haptics':'משוב הפטי','compactRibbon':'סרגל כלים קומפקטי','confirmExport':'אישור לפני ייצוא',
    'showExtensions':'הצגת סיומות קבצים','smartPunctuation':'פיסוק חכם','spellAssist':'עזרי כתיבה',
    'showGridlines':'קווי רשת בגיליון','showRulers':'סרגלים בעורך','autoRecovery':'שמירת עותק שחזור',
    'reduceMotion':'הפחתת תנועה','highContrast':'ניגודיות גבוהה','lowMemoryMode':'מצב חסכוני בזיכרון',
    'previewThumbnails':'הצגת תצוגות מקדימות','offlineOnly':'העדפת עיבוד לא מקוון','diagnostics':'הצגת אבחון מקומי',
    'restoreDrafts':'שחזור טיוטות','protectSourceFiles':'הגנה על קובצי מקור','showStatusBar':'הצגת שורת מצב',
    'textScale':'גודל טקסט בממשק','defaultZoom':'הגדלה ברירת מחדל','fontSize':'גודל גופן בעורך',
    'generalSubtitle':'אפשרויות שמורות לסביבת העבודה','recentSubtitle':'המשך מהמקום שבו עצרת',
    'subtitlePdf':'יצירת PDF ופתיחתו ב-PDF Studio','subtitleWord':'עריכת טקסט וייצוא לקובץ DOCX',
    'subtitlePowerPoint':'יצירת שקופית וייצוא לקובץ PPTX','subtitleExcel':'הפרדת עמודות באמצעות Tab ושורות באמצעות ירידות שורה',
    'saveHint':'הקובץ נוצר במכשיר זה.','existingFileNote':'קריאת קובצי Office מיובאים עדיין בפיתוח; שמירה יוצרת קובץ חדש.',
    'spreadsheetHint':'טיפ: Tab מפריד עמודות; כל שורה חדשה יוצרת שורה.','draftSaved':'הטיוטה נשמרה במכשיר',
    'exported':'הקובץ יוצא','openFailed':'לא ניתן לפתוח את הקובץ','onDevice':'במכשיר זה','about':'על Parin Office',
    'aboutText':'עריכת PDF משולבת ויצירת DOCX/PPTX/XLSX זמינות; עריכה מלאה של Office מיובא עדיין בפיתוח.',
  };
  static const _extra = <String, Map<String, String>>{
    'da': {'home':'Hjem','recent':'Seneste filer','workspace':'Arbejdsområde','settings':'Indstillinger','open':'Åbn fil','create':'Opret ny','appearance':'Udseende','themes':'Farvetemaer','language':'Sprog','general':'Generelt','blueFilter':'Blåt lys-filter','strength':'Filterstyrke','newDocument':'Nyt dokument','welcome':'Dit arbejde, godt organiseret.','createPdf':'Opret PDF','createWord':'Opret Word-fil','createPowerPoint':'Opret præsentation','createExcel':'Opret regneark','cancel':'Annuller','done':'Færdig','save':'Gem / Eksportér'},
    'sv': {'home':'Hem','recent':'Senaste filer','workspace':'Arbetsyta','settings':'Inställningar','open':'Öppna fil','create':'Skapa nytt','appearance':'Utseende','themes':'Färgteman','language':'Språk','general':'Allmänt','blueFilter':'Blåljusfilter','strength':'Filterstyrka','newDocument':'Nytt dokument','welcome':'Ditt arbete, snyggt organiserat.','createPdf':'Skapa PDF','createWord':'Skapa Word-fil','createPowerPoint':'Skapa presentation','createExcel':'Skapa kalkylblad','cancel':'Avbryt','done':'Klart','save':'Spara / Exportera'},
    'fi': {'home':'Etusivu','recent':'Viimeisimmät tiedostot','workspace':'Työtila','settings':'Asetukset','open':'Avaa tiedosto','create':'Luo uusi','appearance':'Ulkoasu','themes':'Väriteemat','language':'Kieli','general':'Yleiset','blueFilter':'Sinivalosuodatin','strength':'Suodattimen voimakkuus','newDocument':'Uusi asiakirja','welcome':'Työsi, selkeästi järjestetty.','createPdf':'Luo PDF','createWord':'Luo Word-tiedosto','createPowerPoint':'Luo esitys','createExcel':'Luo laskentataulukko','cancel':'Peruuta','done':'Valmis','save':'Tallenna / Vie'},
    'no': {'home':'Hjem','recent':'Siste filer','workspace':'Arbeidsområde','settings':'Innstillinger','open':'Åpne fil','create':'Opprett ny','appearance':'Utseende','themes':'Fargetemaer','language':'Språk','general':'Generelt','blueFilter':'Blålysfilter','strength':'Filterstyrke','newDocument':'Nytt dokument','welcome':'Arbeidet ditt, ryddig organisert.','createPdf':'Opprett PDF','createWord':'Opprett Word-fil','createPowerPoint':'Opprett presentasjon','createExcel':'Opprett regneark','cancel':'Avbryt','done':'Ferdig','save':'Lagre / Eksporter'},
    'is': {'home':'Heim','recent':'Nýlegar skrár','workspace':'Vinnusvæði','settings':'Stillingar','open':'Opna skrá','create':'Búa til nýtt','appearance':'Útlit','themes':'Litþemu','language':'Tungumál','general':'Almennt','blueFilter':'Bláljósasía','strength':'Styrkur síu','newDocument':'Nýtt skjal','welcome':'Vinnan þín, vel skipulögð.','createPdf':'Búa til PDF','createWord':'Búa til Word-skrá','createPowerPoint':'Búa til kynningu','createExcel':'Búa til töflureikni','cancel':'Hætta við','done':'Lokið','save':'Vista / Flytja út'},
    'el': {'home':'Αρχική','recent':'Πρόσφατα αρχεία','workspace':'Χώρος εργασίας','settings':'Ρυθμίσεις','open':'Άνοιγμα αρχείου','create':'Δημιουργία νέου','appearance':'Εμφάνιση','themes':'Χρωματικά θέματα','language':'Γλώσσα','general':'Γενικά','blueFilter':'Φίλτρο μπλε φωτός','strength':'Ένταση φίλτρου','newDocument':'Νέο έγγραφο','welcome':'Η εργασία σου, οργανωμένη με σαφήνεια.','createPdf':'Δημιουργία PDF','createWord':'Δημιουργία αρχείου Word','createPowerPoint':'Δημιουργία παρουσίασης','createExcel':'Δημιουργία υπολογιστικού φύλλου','cancel':'Ακύρωση','done':'Έτοιμο','save':'Αποθήκευση / Εξαγωγή'},
    'hi': {'home':'होम','recent':'हाल की फ़ाइलें','workspace':'कार्यस्थान','settings':'सेटिंग्स','open':'फ़ाइल खोलें','create':'नई फ़ाइल बनाएँ','appearance':'दिखावट','themes':'रंग थीम','language':'भाषा','general':'सामान्य','blueFilter':'ब्लू-लाइट फ़िल्टर','strength':'फ़िल्टर की तीव्रता','newDocument':'नया दस्तावेज़','welcome':'आपका काम, व्यवस्थित और पेशेवर।','createPdf':'PDF बनाएँ','createWord':'Word फ़ाइल बनाएँ','createPowerPoint':'प्रस्तुति बनाएँ','createExcel':'स्प्रेडशीट बनाएँ','cancel':'रद्द करें','done':'पूर्ण','save':'सहेजें / निर्यात'},
  };
  static String text(Locale locale, String key) {
    final map = switch (locale.languageCode) {
      'fa' => _fa, 'ar' => _ar, 'de' => _de, 'es' => _es, 'it' => _it, 'tr' => _tr, 'he' => _he, _ => _en,
    };
    return _extra[locale.languageCode]?[key] ?? map[key] ?? _en[key] ?? key;
  }
  static bool rtl(Locale locale) => const <String>{'fa','ar','he'}.contains(locale.languageCode);
}

class ParinOfficeApp extends StatefulWidget {
  const ParinOfficeApp({super.key});
  @override
  State<ParinOfficeApp> createState() => _ParinOfficeAppState();
}

class _ParinOfficeAppState extends State<ParinOfficeApp> {
  final state = AppState();
  bool ready = false;

  @override
  void initState() {
    super.initState();
    state.load().whenComplete(() {
      if (mounted) setState(() => ready = true);
    });
  }

  @override
  void dispose() {
    state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ready) return const MaterialApp(home: Scaffold(body: Center(child: CircularProgressIndicator())));
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final noMotion = state.flag('reduceMotion') || !state.flag('animations');
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Parin Office',
          locale: state.locale,
          supportedLocales: L10n.locales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          localeResolutionCallback: (deviceLocale, supported) {
            if (deviceLocale == null) return const Locale('en');
            return supported.firstWhere((item) => item.languageCode == deviceLocale.languageCode, orElse: () => const Locale('en'));
          },
          theme: ThemeCatalog.build(state.preset, Brightness.light, false, highContrast: state.flag('highContrast')),
          darkTheme: ThemeCatalog.build(state.preset, Brightness.dark, state.amoled, highContrast: state.flag('highContrast')),
          themeMode: switch (state.mode) {
            AppearanceMode.system => ThemeMode.system,
            AppearanceMode.light => ThemeMode.light,
            AppearanceMode.dark || AppearanceMode.amoled => ThemeMode.dark,
          },
          themeAnimationDuration: noMotion ? Duration.zero : const Duration(milliseconds: 220),
          builder: (context, child) {
            final app = MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(state.textScale)),
              child: Directionality(
                textDirection: L10n.rtl(state.locale) ? TextDirection.rtl : TextDirection.ltr,
                child: child ?? const SizedBox.shrink(),
              ),
            );
            return Stack(
              fit: StackFit.expand,
              children: [
                app,
                if (state.flag('blueLightFilter'))
                  IgnorePointer(
                    child: ColoredBox(color: const Color(0xFFFFB65C).withValues(alpha: state.blueStrength * 0.18)),
                  ),
              ],
            );
          },
          home: Shell(state: state),
        );
      },
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.15),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [colors.primary, colors.secondary]),
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [BoxShadow(color: colors.primary.withValues(alpha: 0.22), blurRadius: size * 0.22, offset: Offset(0, size * 0.07))],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(color: const Color(0xFF071632), borderRadius: BorderRadius.circular(size * 0.18)),
        child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
      ),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key, required this.state});
  final AppState state;
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    String t(String key) => L10n.text(state.locale, key);
    final items = <(IconData, String)>[
      (Icons.space_dashboard_rounded, t('home')),
      (Icons.history_rounded, t('recent')),
      (Icons.grid_view_rounded, t('workspace')),
      (Icons.tune_rounded, t('settings')),
    ];
    final pages = <Widget>[
      Dashboard(state: state),
      RecentPage(state: state),
      WorkspaceHome(state: state),
      SettingsPage(state: state),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth >= 760) {
        final extended = constraints.maxWidth >= 1120;
        return Scaffold(
          body: Row(
            children: [
              Container(
                width: extended ? 248 : 88,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(right: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: extended ? 18 : 14, vertical: 24),
                      child: Row(
                        mainAxisAlignment: extended ? MainAxisAlignment.start : MainAxisAlignment.center,
                        children: [
                          const BrandMark(size: 44),
                          if (extended) ...[
                            const SizedBox(width: 12),
                            const Expanded(child: Text('Parin Office', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.4))),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      child: NavigationRail(
                        extended: extended,
                        minWidth: 72,
                        minExtendedWidth: 220,
                        selectedIndex: index,
                        onDestinationSelected: (value) => setState(() => index = value),
                        labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                        destinations: items.map((item) => NavigationRailDestination(icon: Icon(item.$1), selectedIcon: Icon(item.$1), label: Text(item.$2))).toList(),
                      ),
                    ),
                    if (extended)
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(18)),
                          child: Row(children: [
                            Icon(Icons.offline_bolt_rounded, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 9),
                            Expanded(child: Text(t('onDevice'), style: const TextStyle(fontWeight: FontWeight.w700))),
                          ]),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(child: pages[index]),
            ],
          ),
        );
      }
      return Scaffold(
        body: pages[index],
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (value) => setState(() => index = value),
          destinations: items.map((item) => NavigationDestination(icon: Icon(item.$1), selectedIcon: Icon(item.$1), label: item.$2)).toList(),
        ),
      );
    });
  }
}

Future<void> launchCreate(BuildContext context, AppState state, {DocumentKind? initialKind}) async {
  final selected = await showDialog<(DocumentKind, String)>(
    context: context,
    builder: (_) => _CreateDocumentDialog(state: state, initialKind: initialKind),
  );
  if (!context.mounted || selected == null) return;
  final kind = selected.$1;
  final title = selected.$2.trim().isEmpty ? 'Untitled' : selected.$2.trim();
  try {
    if (kind == DocumentKind.pdf) {
      final bytes = await DocumentFactory.create(kind, title, DocumentFactory.initialContent(kind));
      if (!context.mounted) return;
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PdfPage(bytes: bytes, name: title + '.pdf', state: state)));
    } else {
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => OfficeDocumentEditor(kind: kind, title: title, state: state, initialContent: DocumentFactory.initialContent(kind)),
      ));
    }
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create file: ' + error.toString())));
  }
}

Future<void> openRecentFile(BuildContext context, AppState state) async {
  final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf', 'docx', 'pptx', 'xlsx']);
  if (!context.mounted || files.isEmpty) return;
  final file = files.first;
  final bytes = await file.readAsBytes();
  if (!context.mounted) return;
  await state.markRecent(file.name);
  final extension = (file.extension ?? '').toLowerCase();
  if (extension == 'pdf') {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PdfPage(bytes: bytes, name: file.name, state: state)));
    return;
  }
  final kind = switch (extension) {
    'pptx' => DocumentKind.powerpoint,
    'xlsx' => DocumentKind.excel,
    _ => DocumentKind.word,
  };
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => OfficeDocumentEditor(kind: kind, title: file.name, state: state, initialContent: DocumentFactory.initialContent(kind), importedFile: true),
  ));
}

class _CreateDocumentDialog extends StatefulWidget {
  const _CreateDocumentDialog({required this.state, this.initialKind});
  final AppState state;
  final DocumentKind? initialKind;
  @override
  State<_CreateDocumentDialog> createState() => _CreateDocumentDialogState();
}

class _CreateDocumentDialogState extends State<_CreateDocumentDialog> {
  late DocumentKind selected;
  late final TextEditingController titleController;

  @override
  void initState() {
    super.initState();
    selected = widget.initialKind ?? DocumentKind.word;
    titleController = TextEditingController(text: 'Untitled');
  }

  @override
  void dispose() {
    titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String t(String key) => L10n.text(widget.state.locale, key);
    final options = <(DocumentKind, IconData, Color, String)>[
      (DocumentKind.pdf, Icons.picture_as_pdf_rounded, const Color(0xFFE84E68), t('createPdf')),
      (DocumentKind.word, Icons.description_rounded, const Color(0xFF3478E5), t('createWord')),
      (DocumentKind.powerpoint, Icons.slideshow_rounded, const Color(0xFFEB8734), t('createPowerPoint')),
      (DocumentKind.excel, Icons.grid_on_rounded, const Color(0xFF1A9E75), t('createExcel')),
    ];
    return AlertDialog(
      title: Text(t('newDocument')),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleController, autofocus: true, decoration: InputDecoration(labelText: t('documentTitle'), prefixIcon: const Icon(Icons.edit_note_rounded))),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: options.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, mainAxisExtent: 120),
                itemBuilder: (context, index) {
                  final option = options[index];
                  final active = selected == option.$1;
                  return Material(
                    color: active ? option.$3.withValues(alpha: 0.12) : Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => setState(() => selected = option.$1),
                      child: Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: active ? option.$3 : Theme.of(context).colorScheme.outlineVariant, width: active ? 2 : 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Icon(option.$2, color: option.$3, size: 27),
                            Text(option.$4, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(t('cancel'))),
        FilledButton.icon(onPressed: () => Navigator.pop(context, (selected, titleController.text.trim())), icon: const Icon(Icons.add_rounded), label: Text(t('create'))),
      ],
    );
  }
}

class Dashboard extends StatelessWidget {
  const Dashboard({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    String t(String key) => L10n.text(state.locale, key);
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final columns = width > 1180 ? 4 : width > 680 ? 2 : 1;
    final docs = <(DocumentKind, String, String, IconData, Color)>[
      (DocumentKind.pdf, t('pdf'), t('subtitlePdf'), Icons.picture_as_pdf_rounded, const Color(0xFFE84E68)),
      (DocumentKind.word, t('word'), t('subtitleWord'), Icons.description_rounded, const Color(0xFF3478E5)),
      (DocumentKind.powerpoint, t('powerpoint'), t('subtitlePowerPoint'), Icons.slideshow_rounded, const Color(0xFFEB8734)),
      (DocumentKind.excel, t('excel'), t('subtitleExcel'), Icons.grid_on_rounded, const Color(0xFF1A9E75)),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [const BrandMark(size: 34), const SizedBox(width: 10), const Text('Parin Office', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.35))]),
        actions: [
          IconButton(tooltip: t('create'), onPressed: () => launchCreate(context, state), icon: const Icon(Icons.add_circle_outline_rounded)),
          IconButton(tooltip: t('open'), onPressed: () => openRecentFile(context, state), icon: const Icon(Icons.folder_open_rounded)),
          IconButton(
            tooltip: t('blueFilter'),
            onPressed: () => state.setFlag('blueLightFilter', !state.flag('blueLightFilter')),
            icon: Icon(state.flag('blueLightFilter') ? Icons.wb_sunny_rounded : Icons.nightlight_round),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(width < 600 ? 15 : 25, 16, width < 600 ? 15 : 25, 18),
            sliver: SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.all(width < 600 ? 21 : 28),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [theme.colorScheme.primary, Color.lerp(theme.colorScheme.primary, theme.colorScheme.secondary, 0.55)!, const Color(0xFF142441)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(24)),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 7),
                        Text('PARIN WORKSPACE', style: TextStyle(color: Colors.white, letterSpacing: 1.3, fontSize: 11, fontWeight: FontWeight.w900)),
                      ]),
                    ),
                    const SizedBox(height: 18),
                    Text(t('welcome'), style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: -0.7, height: 1.12)),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: Text(t('welcomeSubtitle'), style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white.withValues(alpha: 0.84), height: 1.5)),
                    ),
                    const SizedBox(height: 18),
                    Wrap(spacing: 10, runSpacing: 10, children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF10203F)),
                        onPressed: () => launchCreate(context, state),
                        icon: const Icon(Icons.add_rounded),
                        label: Text(t('create')),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: Colors.white.withValues(alpha: 0.55))),
                        onPressed: () => openRecentFile(context, state),
                        icon: const Icon(Icons.folder_open_rounded),
                        label: Text(t('open')),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: width < 600 ? 15 : 25),
            sliver: SliverToBoxAdapter(
              child: Row(children: [
                Expanded(child: Text(t('newDocument'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
                Text('PDF · DOCX · PPTX · XLSX', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(width < 600 ? 15 : 25, 13, width < 600 ? 15 : 25, 6),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate((context, index) {
                final doc = docs[index];
                return _DocTile(doc.$2, doc.$3, doc.$4, doc.$5, () => launchCreate(context, state, initialKind: doc.$1));
              }, childCount: docs.length),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisExtent: columns == 1 ? 104 : 148,
                crossAxisSpacing: 13,
                mainAxisSpacing: 13,
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(width < 600 ? 15 : 25, 20, width < 600 ? 15 : 25, 10),
            sliver: SliverToBoxAdapter(child: Text(t('quick'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: width < 600 ? 15 : 25),
            sliver: SliverToBoxAdapter(
              child: Wrap(
                spacing: 9,
                runSpacing: 9,
                children: [
                  ActionChip(avatar: const Icon(Icons.note_add_outlined, size: 18), label: Text(t('create')), onPressed: () => launchCreate(context, state)),
                  ActionChip(avatar: const Icon(Icons.folder_open_rounded, size: 18), label: Text(t('open')), onPressed: () => openRecentFile(context, state)),
                  ActionChip(avatar: const Icon(Icons.palette_outlined, size: 18), label: Text(t('themes')), onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SettingsPage(state: state, openAppearance: true)))),
                  ActionChip(avatar: const Icon(Icons.language_rounded, size: 18), label: Text(t('language')), onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SettingsPage(state: state, openLanguage: true)))),
                  ActionChip(avatar: const Icon(Icons.nightlight_round, size: 18), label: Text(t('blueFilter')), onPressed: () => state.setFlag('blueLightFilter', !state.flag('blueLightFilter'))),
                  ActionChip(avatar: const Icon(Icons.history_rounded, size: 18), label: Text(t('recent')), onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => RecentPage(state: state)))),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(width < 600 ? 15 : 25, 21, width < 600 ? 15 : 25, 30),
            sliver: SliverToBoxAdapter(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Wrap(
                    spacing: 26,
                    runSpacing: 18,
                    children: const [
                      _Metric(Icons.devices_other_rounded, 'Adaptive', 'Phone + Tablet'),
                      _Metric(Icons.offline_bolt_outlined, 'Offline-first', 'Local file creation'),
                      _Metric(Icons.palette_outlined, 'Personalization', '128 themes · 16 locales'),
                      _Metric(Icons.security_outlined, 'Privacy', 'Local settings & drafts'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OfficeDocumentEditor extends StatefulWidget {
  const OfficeDocumentEditor({super.key, required this.kind, required this.title, required this.state, required this.initialContent, this.importedFile = false});
  final DocumentKind kind;
  final String title;
  final AppState state;
  final String initialContent;
  final bool importedFile;
  @override
  State<OfficeDocumentEditor> createState() => _OfficeDocumentEditorState();
}

class _OfficeDocumentEditorState extends State<OfficeDocumentEditor> {
  late final TextEditingController titleController;
  late final TextEditingController contentController;
  bool exporting = false;
  String t(String key) => L10n.text(widget.state.locale, key);

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.title.replaceFirst(RegExp(r'\.(docx|pptx|xlsx){const _DocTile(this.title,this.subtitle,this.icon,this.color,this.onTap);final String title,subtitle;final IconData icon;final Color color;final VoidCallback onTap;@override Widget build(BuildContext c)=>Card(clipBehavior:Clip.antiAlias,child:InkWell(onTap:onTap,child:Padding(padding:const EdgeInsets.all(18),child:Row(children:[Container(width:58,height:58,decoration:BoxDecoration(color:color.withAlpha(30),borderRadius:BorderRadius.circular(18)),child:Icon(icon,color:color,size:30)),const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.center,children:[Text(title,style:Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w900)),const SizedBox(height:5),Text(subtitle)])),const Icon(Icons.chevron_right_rounded)]))));}
class _Metric extends StatelessWidget{const _Metric(this.icon,this.title,this.value);final IconData icon;final String title,value;@override Widget build(BuildContext c)=>Row(mainAxisSize:MainAxisSize.min,children:[Icon(icon),const SizedBox(width:9),Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontWeight:FontWeight.w800)),Text(value)])]);}

class PdfPage extends StatelessWidget {
  const PdfPage({super.key, required this.bytes, required this.name, required this.state});
  final Uint8List bytes;
  final String name;
  final AppState state;

  Future<void> save(Uint8List output) async {
    final filename = name.toLowerCase().endsWith('.pdf') ? name : name + '.pdf';
    final saved = await FilePicker.saveFile(
      fileName: filename,
      bytes: output,
      mimeType: 'application/pdf',
      dialogTitle: 'Save edited PDF',
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (saved != null) await state.markRecent(filename);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis)),
    body: PdfEditorView(bytes: bytes, documentId: name, onSave: save, showSaveButton: true),
  );
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
  @override
  Widget build(BuildContext context) {
    String t(String key) => L10n.text(state.locale, key);
    return Scaffold(
      appBar: AppBar(
        title: Text(t('recent')),
        actions: [
          if (state.recentDocuments.isNotEmpty)
            IconButton(
              tooltip: t('clearRecent'),
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () async {
                await state.clearRecents();
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('clearRecent'))));
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: state.recentDocuments.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.folder_open_rounded, size: 54, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text(t('noRecent'), style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 7),
                  Text(t('recentSubtitle'), style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 16),
                  FilledButton.icon(onPressed: () => openRecentFile(context, state), icon: const Icon(Icons.folder_open_rounded), label: Text(t('open'))),
                ]),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(18),
              itemCount: state.recentDocuments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 9),
              itemBuilder: (context, index) {
                final name = state.recentDocuments[index];
                final extension = name.split('.').last.toLowerCase();
                final icon = switch (extension) {
                  'pdf' => Icons.picture_as_pdf_rounded,
                  'docx' => Icons.description_rounded,
                  'pptx' => Icons.slideshow_rounded,
                  'xlsx' => Icons.grid_on_rounded,
                  _ => Icons.insert_drive_file_outlined,
                };
                final accent = switch (extension) {
                  'pdf' => const Color(0xFFE84E68),
                  'docx' => const Color(0xFF3478E5),
                  'pptx' => const Color(0xFFEB8734),
                  'xlsx' => const Color(0xFF1A9E75),
                  _ => Theme.of(context).colorScheme.primary,
                };
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: accent.withValues(alpha: 0.13), child: Icon(icon, color: accent)),
                    title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(state.flag('showExtensions') ? extension.toUpperCase() + ' • ' + t('onDevice') : t('onDevice')),
                    trailing: const Icon(Icons.folder_open_rounded),
                    onTap: () => openRecentFile(context, state),
                  ),
                );
              },
            ),
    );
  }
}

class WorkspaceHome extends StatelessWidget {
  const WorkspaceHome({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    String t(String key) => L10n.text(state.locale, key);
    final width = MediaQuery.sizeOf(context).width;
    final items = <(IconData, String, Color, VoidCallback)>[
      (Icons.picture_as_pdf_rounded, t('createPdf'), const Color(0xFFE84E68), () => launchCreate(context, state, initialKind: DocumentKind.pdf)),
      (Icons.description_rounded, t('createWord'), const Color(0xFF3478E5), () => launchCreate(context, state, initialKind: DocumentKind.word)),
      (Icons.slideshow_rounded, t('createPowerPoint'), const Color(0xFFEB8734), () => launchCreate(context, state, initialKind: DocumentKind.powerpoint)),
      (Icons.grid_on_rounded, t('createExcel'), const Color(0xFF1A9E75), () => launchCreate(context, state, initialKind: DocumentKind.excel)),
      (Icons.folder_open_rounded, t('open'), Theme.of(context).colorScheme.primary, () => openRecentFile(context, state)),
      (Icons.palette_outlined, t('themes'), Theme.of(context).colorScheme.secondary, () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SettingsPage(state: state, openAppearance: true)))),
      (Icons.language_rounded, t('language'), const Color(0xFF765DE8), () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SettingsPage(state: state, openLanguage: true)))),
      (Icons.tune_rounded, t('settings'), Theme.of(context).colorScheme.onSurfaceVariant, () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SettingsPage(state: state)))),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(t('workspace'))),
      body: GridView.builder(
        padding: EdgeInsets.all(width < 600 ? 15 : 24),
        itemCount: items.length,
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 290, mainAxisExtent: 145, crossAxisSpacing: 13, mainAxisSpacing: 13),
        itemBuilder: (context, index) {
          final item = items[index];
          return Material(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(21),
            child: InkWell(
              borderRadius: BorderRadius.circular(21),
              onTap: item.$4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(color: item.$3.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(15)),
                    child: Icon(item.$1, color: item.$3),
                  ),
                  Row(children: [
                    Expanded(child: Text(item.$2, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
                    const Icon(Icons.arrow_outward_rounded, size: 17),
                  ]),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.state, this.openAppearance = false, this.openLanguage = false});
  final AppState state;
  final bool openAppearance;
  final bool openLanguage;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final themeSearch = TextEditingController();
  final languageSearch = TextEditingController();
  String family = 'All';
  bool favoritesOnly = false;

  String t(String key) => L10n.text(widget.state.locale, key);

  @override
  void dispose() {
    themeSearch.dispose();
    languageSearch.dispose();
    super.dispose();
  }

  Widget section(String title, IconData icon, List<Widget> children, {bool expanded = false}) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: ExpansionTile(
      initiallyExpanded: expanded,
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      childrenPadding: const EdgeInsets.fromLTRB(14, 2, 14, 16),
      children: children,
    ),
  );

  Widget switchTile(String key) {
    final state = widget.state;
    return SwitchListTile.adaptive(
      value: state.flag(key),
      title: Text(t(key)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      onChanged: (value) async {
        if (state.flag('haptics')) HapticFeedback.selectionClick();
        await state.setFlag(key, value);
      },
    );
  }

  List<ThemePreset> get visibleThemes {
    final state = widget.state;
    return ThemeCatalog.presets.where((preset) {
      final query = themeSearch.text.toLowerCase();
      return preset.name.toLowerCase().contains(query) &&
          (family == 'All' || preset.family == family) &&
          (!favoritesOnly || state.favoriteThemes.contains(preset.index));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final locales = L10n.locales.where((locale) {
      final index = L10n.locales.indexOf(locale);
      final query = languageSearch.text.toLowerCase();
      return L10n.names[index].toLowerCase().contains(query) || locale.languageCode.contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(t('settings')),
        actions: [
          IconButton(
            tooltip: t('blueFilter'),
            onPressed: () => state.setFlag('blueLightFilter', !state.flag('blueLightFilter')),
            icon: Icon(state.flag('blueLightFilter') ? Icons.wb_sunny_rounded : Icons.nightlight_round),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(width < 600 ? 12 : 22, 12, width < 600 ? 12 : 22, 42),
        children: [
          section(t('appearance'), Icons.palette_outlined, [
            ListTile(
              title: Text(t('selectedTheme')),
              subtitle: Text(state.preset.name),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [state.preset.primary, state.preset.secondary]),
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              trailing: Text((state.themeIndex + 1).toString() + '/128', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 3),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: AppearanceMode.values.map((mode) {
                final label = switch (mode) {
                  AppearanceMode.system => t('system'),
                  AppearanceMode.light => t('light'),
                  AppearanceMode.dark => t('dark'),
                  AppearanceMode.amoled => t('amoled'),
                };
                final icon = switch (mode) {
                  AppearanceMode.system => Icons.brightness_auto_rounded,
                  AppearanceMode.light => Icons.light_mode_rounded,
                  AppearanceMode.dark => Icons.dark_mode_rounded,
                  AppearanceMode.amoled => Icons.contrast_rounded,
                };
                return ChoiceChip(
                  avatar: Icon(icon, size: 18),
                  label: Text(label),
                  selected: state.mode == mode,
                  onSelected: (_) => state.setMode(mode),
                );
              }).toList(),
            ),
            const SizedBox(height: 13),
            TextField(
              controller: themeSearch,
              onChanged: state.setThemeQuery,
              decoration: InputDecoration(
                labelText: t('search') + ' • ' + t('themes'),
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: themeSearch.text.isEmpty ? null : IconButton(
                  onPressed: () {
                    themeSearch.clear();
                    state.setThemeQuery('');
                    setState(() {});
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                ChoiceChip(label: Text(t('allThemes')), selected: family == 'All', onSelected: (_) => setState(() => family = 'All')),
                const SizedBox(width: 7),
                ...ThemeCatalog.families.map((item) => Padding(
                  padding: const EdgeInsets.only(right: 7),
                  child: ChoiceChip(label: Text(item), selected: family == item, onSelected: (_) => setState(() => family = item)),
                )),
              ]),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: favoritesOnly,
              title: Text(t('favorites')),
              subtitle: Text(state.favoriteThemes.length.toString() + ' saved palettes'),
              onChanged: (value) => setState(() => favoritesOnly = value ?? false),
            ),
            SizedBox(
              height: width < 550 ? 390 : 460,
              child: GridView.builder(
                key: const PageStorageKey<String>('theme-grid'),
                itemCount: visibleThemes.length,
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: width < 550 ? 112 : 132,
                  mainAxisExtent: 95,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemBuilder: (context, index) {
                  final preset = visibleThemes[index];
                  final selected = state.themeIndex == preset.index;
                  final favorite = state.favoriteThemes.contains(preset.index);
                  return Material(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(15),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(15),
                      onTap: () async {
                        await state.setTheme(preset.index);
                        if (state.flag('haptics')) HapticFeedback.selectionClick();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: selected ? preset.primary : theme.colorScheme.outlineVariant, width: selected ? 2.2 : 1),
                        ),
                        child: Column(children: [
                          Expanded(
                            child: Stack(children: [
                              Positioned.fill(child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [preset.primary, preset.secondary]),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                              )),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: InkResponse(
                                  onTap: () => state.toggleFavoriteTheme(preset.index),
                                  radius: 18,
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(favorite ? Icons.star_rounded : Icons.star_border_rounded, size: 18, color: Colors.white),
                                  ),
                                ),
                              ),
                              if (selected) const Center(child: Icon(Icons.check_circle_rounded, color: Colors.white, size: 24)),
                            ]),
                          ),
                          const SizedBox(height: 5),
                          Text(preset.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800)),
                        ]),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (visibleThemes.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('No themes match this filter.')),
          ], expanded: widget.openAppearance),
          section(t('language'), Icons.language_rounded, [
            ListTile(
              leading: const Icon(Icons.translate_rounded),
              title: Text(L10n.names[L10n.locales.indexOf(state.locale)]),
              subtitle: Text(state.locale.toLanguageTag()),
              trailing: const Icon(Icons.check_circle_rounded),
            ),
            TextField(
              controller: languageSearch,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: t('search') + ' • ' + t('language'), prefixIcon: const Icon(Icons.search_rounded)),
            ),
            const SizedBox(height: 6),
            ...locales.map((locale) {
              final index = L10n.locales.indexOf(locale);
              final selected = locale.toLanguageTag() == state.locale.toLanguageTag();
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 2),
                leading: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
                  child: Text(locale.languageCode.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                ),
                title: Text(L10n.names[index]),
                subtitle: Text(locale.toLanguageTag()),
                trailing: selected ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary) : null,
                onTap: () async {
                  await state.setLocale(locale);
                  if (state.flag('haptics')) HapticFeedback.selectionClick();
                  if (mounted) setState(() {});
                },
              );
            }),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text('RTL direction is applied to Persian, Arabic and Hebrew. Navigation wraps and scales for longer translations.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ),
          ], expanded: widget.openLanguage),
          section(t('general'), Icons.tune_rounded, [
            Padding(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4), child: Text(t('generalSubtitle'), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
            switchTile('autosave'),
            switchTile('autoRecovery'),
            switchTile('restoreDrafts'),
            switchTile('haptics'),
            switchTile('animations'),
            switchTile('compactRibbon'),
            switchTile('confirmExport'),
            switchTile('showExtensions'),
            switchTile('smartPunctuation'),
            switchTile('spellAssist'),
            switchTile('showStatusBar'),
          ], expanded: true),
          section(t('blueFilter'), Icons.nightlight_round, [
            SwitchListTile.adaptive(
              value: state.flag('blueLightFilter'),
              title: Text(t('blueFilter')),
              subtitle: Text(t('blueFilterSubtitle')),
              secondary: const Icon(Icons.wb_twilight_rounded),
              onChanged: (value) => state.setFlag('blueLightFilter', value),
            ),
            if (state.flag('blueLightFilter')) ...[
              ListTile(title: Text(t('strength')), trailing: Text((state.blueStrength * 100).round().toString() + '%')),
              Slider(value: state.blueStrength, min: 0.05, max: 1, divisions: 19, onChanged: (value) => state.setNumeric('blueStrength', value)),
              Container(
                height: 45,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFE7F2FF), Color(0xFFFFE0A7), Color(0xFFFFB75A)]),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: const Center(child: Text('Live filter preview', style: TextStyle(color: Color(0xFF1D2A40), fontWeight: FontWeight.w800))),
              ),
              const SizedBox(height: 10),
            ],
          ], expanded: true),
          section(t('editor'), Icons.edit_note_rounded, [
            ListTile(title: Text(t('textScale')), trailing: Text((state.textScale * 100).round().toString() + '%')),
            Slider(value: state.textScale, min: 0.85, max: 1.4, divisions: 11, onChanged: (value) => state.setNumeric('textScale', value)),
            ListTile(title: Text(t('defaultZoom')), trailing: Text((state.defaultZoom * 100).round().toString() + '%')),
            Slider(value: state.defaultZoom, min: 0.5, max: 1.5, divisions: 10, onChanged: (value) => state.setNumeric('defaultZoom', value)),
            ListTile(title: Text(t('fontSize')), trailing: Text(state.editorFontSize.round().toString())),
            Slider(value: state.editorFontSize, min: 12, max: 26, divisions: 14, onChanged: (value) => state.setNumeric('editorFontSize', value)),
            switchTile('showRulers'),
            switchTile('showGridlines'),
            switchTile('smartPunctuation'),
            switchTile('spellAssist'),
          ]),
          section(t('accessibility'), Icons.accessibility_new_rounded, [
            switchTile('reduceMotion'),
            switchTile('highContrast'),
            ListTile(
              title: Text(t('textScale')),
              subtitle: Text((state.textScale * 100).round().toString() + '%'),
              trailing: IconButton(tooltip: 'Reset', onPressed: () => state.setNumeric('textScale', 1), icon: const Icon(Icons.restart_alt_rounded)),
            ),
          ]),
          section(t('performance'), Icons.speed_rounded, [
            switchTile('lowMemoryMode'),
            switchTile('previewThumbnails'),
            switchTile('offlineOnly'),
            switchTile('protectSourceFiles'),
            ListTile(
              leading: const Icon(Icons.memory_rounded),
              title: const Text('Rendering profile'),
              subtitle: Text(state.flag('lowMemoryMode') ? 'Conservative memory profile; live preview hidden' : 'Balanced mode with tablet preview'),
            ),
            if (state.flag('diagnostics'))
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('Local diagnostics'),
                subtitle: Text('Theme ' + (state.themeIndex + 1).toString() + ' · ' + state.locale.toLanguageTag() + ' · ' + ThemeCatalog.presets.length.toString() + ' palettes'),
              ),
          ]),
          section(t('security'), Icons.security_rounded, [
            switchTile('offlineOnly'),
            switchTile('protectSourceFiles'),
            switchTile('diagnostics'),
            const ListTile(
              leading: Icon(Icons.lock_outline_rounded),
              title: Text('Privacy note'),
              subtitle: Text('Document generation and drafts run locally. Cloud sync is not connected in this build.'),
            ),
          ]),
          section(t('general'), Icons.storage_rounded, [
            ListTile(
              leading: const Icon(Icons.delete_sweep_outlined),
              title: Text(t('clearRecent')),
              subtitle: Text(state.recentDocuments.length.toString() + ' recent entries'),
              onTap: () async {
                await state.clearRecents();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('clearRecent'))));
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: Text(t('clearDrafts')),
              subtitle: const Text('Remove local autosave recovery texts'),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: Text(t('clearDrafts')),
                    content: const Text('Saved recovery drafts will be removed from this device.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(t('cancel'))),
                      FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(t('done'))),
                    ],
                  ),
                );
                if (confirm == true) {
                  await state.clearDrafts();
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('clearDrafts'))));
                }
              },
            ),
          ]),
          section(t('about'), Icons.info_outline_rounded, [
            const ListTile(
              leading: BrandMark(size: 42),
              title: Text('Parin Office'),
              subtitle: Text('Version 0.10 · Flutter 3.47'),
            ),
            ListTile(title: Text(t('aboutText')), isThreeLine: true),
          ]),
        ],
      ),
    );
  }
}

 extends StatelessWidget{
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
, caseSensitive: false), ''));
    contentController = TextEditingController(text: widget.initialContent);
    _restoreDraft();
  }

  Future<void> _restoreDraft() async {
    if (widget.importedFile || !widget.state.flag('restoreDrafts')) return;
    final draft = await widget.state.loadDraft(titleController.text);
    if (!mounted || draft == null || contentController.text != widget.initialContent) return;
    setState(() => contentController.text = draft);
  }

  Future<void> _saveDraft() async {
    if (widget.state.flag('autosave') && widget.state.flag('autoRecovery')) {
      await widget.state.saveDraft(titleController.text, contentController.text);
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    contentController.dispose();
    super.dispose();
  }

  Future<bool> _confirmExport() async {
    if (!widget.state.flag('confirmExport')) return true;
    final answer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export document?'),
        content: Text(t('saveHint')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(t('done'))),
        ],
      ),
    );
    return answer == true;
  }

  Future<void> _export() async {
    if (exporting || !await _confirmExport() || !mounted) return;
    setState(() => exporting = true);
    try {
      var baseName = titleController.text.trim();
      if (baseName.isEmpty) baseName = 'Untitled';
      baseName = baseName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
      final fileName = baseName + '.' + widget.kind.extension;
      final bytes = await DocumentFactory.create(widget.kind, baseName, contentController.text, slideTitle: baseName);
      if (!mounted) return;
      final saved = await FilePicker.saveFile(
        fileName: fileName,
        bytes: bytes,
        mimeType: widget.kind.mimeType,
        dialogTitle: 'Save ' + widget.kind.label,
        type: FileType.custom,
        allowedExtensions: [widget.kind.extension],
      );
      if (saved != null) {
        await widget.state.markRecent(fileName);
        await widget.state.saveDraft(baseName, contentController.text);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('exported') + ': ' + fileName)));
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: ' + error.toString())));
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isExcel = widget.kind == DocumentKind.excel;
    final accent = switch (widget.kind) {
      DocumentKind.pdf => const Color(0xFFE84E68),
      DocumentKind.word => const Color(0xFF3478E5),
      DocumentKind.powerpoint => const Color(0xFFEB8734),
      DocumentKind.excel => const Color(0xFF1A9E75),
    };
    final name = titleController.text.trim().isEmpty ? 'Untitled' : titleController.text.trim();

    final editor = Column(
      children: [
        if (widget.importedFile)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: theme.colorScheme.tertiaryContainer, borderRadius: BorderRadius.circular(15)),
            child: Text(t('existingFileNote'), style: theme.textTheme.bodySmall),
          ),
        Expanded(
          child: Container(
            padding: EdgeInsets.all(state.compactRibbon ? 11 : 16),
            decoration: BoxDecoration(color: theme.colorScheme.surface, border: Border.all(color: theme.colorScheme.outlineVariant), borderRadius: BorderRadius.circular(22)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(labelText: t('documentTitle'), prefixIcon: const Icon(Icons.title_rounded)),
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                if (state.flag('showRulers')) ...[
                  const SizedBox(height: 10),
                  _EditorRuler(color: accent),
                ],
                const SizedBox(height: 12),
                Row(children: [
                  Icon(_iconForKind(widget.kind), color: accent),
                  const SizedBox(width: 8),
                  Expanded(child: Text(widget.kind.label, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
                  if (state.flag('autosave') && state.flag('autoRecovery'))
                    Tooltip(message: t('draftSaved'), child: Icon(Icons.cloud_done_outlined, color: theme.colorScheme.tertiary, size: 19)),
                ]),
                const SizedBox(height: 11),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isExcel ? theme.colorScheme.surfaceContainerLow : theme.colorScheme.surface,
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Stack(children: [
                      if (isExcel && state.flag('showGridlines'))
                        Positioned.fill(child: CustomPaint(painter: _EditorGridPainter(theme.colorScheme.outlineVariant.withValues(alpha: 0.35)))),
                      TextField(
                        controller: contentController,
                        expands: true,
                        maxLines: null,
                        minLines: null,
                        keyboardType: TextInputType.multiline,
                        textAlignVertical: TextAlignVertical.top,
                        smartDashesType: state.flag('smartPunctuation') ? SmartDashesType.enabled : SmartDashesType.disabled,
                        smartQuotesType: state.flag('smartPunctuation') ? SmartQuotesType.enabled : SmartQuotesType.disabled,
                        style: TextStyle(fontSize: state.editorFontSize, height: 1.58, fontFamily: isExcel ? 'monospace' : null),
                        decoration: InputDecoration(
                          hintText: isExcel ? t('spreadsheetHint') : 'Start typing here…',
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(18),
                          fillColor: Colors.transparent,
                          filled: true,
                        ),
                        onChanged: (_) {
                          setState(() {});
                          _saveDraft();
                        },
                      ),
                    ]),
                  ),
                ),
                if (isExcel && state.flag('showGridlines')) ...[
                  const SizedBox(height: 9),
                  Text(t('showGridlines') + ' • ' + contentController.text.split('\n').length.toString() + ' rows', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
                if (!isExcel && state.flag('spellAssist')) ...[
                  const SizedBox(height: 9),
                  Row(children: [
                    Icon(Icons.lightbulb_outline_rounded, size: 17, color: theme.colorScheme.tertiary),
                    const SizedBox(width: 6),
                    Expanded(child: Text('Writing hints are enabled. Drafts stay on this device.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
                  ]),
                ],
                if (state.flag('showStatusBar')) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.offline_bolt_outlined, size: 15, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Expanded(child: Text(t('onDevice'), style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
                    Text(contentController.text.length.toString() + ' chars', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ]),
                ],
              ],
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: accent.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(12)),
            child: Icon(_iconForKind(widget.kind), color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
        actions: [
          if (state.flag('showStatusBar'))
            Padding(padding: const EdgeInsets.symmetric(horizontal: 7), child: Center(child: Text(widget.kind.extension.toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 1)))),
          IconButton(
            tooltip: t('save'),
            onPressed: exporting ? null : _export,
            icon: exporting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.file_download_outlined),
          ),
        ],
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        if (width >= 1020 && state.flag('previewThumbnails') && !state.flag('lowMemoryMode')) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              Expanded(flex: 3, child: editor),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: _OfficePreview(kind: widget.kind, title: name, accent: accent, zoom: state.defaultZoom)),
            ]),
          );
        }
        return Padding(padding: EdgeInsets.all(width < 600 ? 11 : 18), child: editor);
      }),
    );
  }
}

IconData _iconForKind(DocumentKind kind) => switch (kind) {
  DocumentKind.pdf => Icons.picture_as_pdf_rounded,
  DocumentKind.word => Icons.description_rounded,
  DocumentKind.powerpoint => Icons.slideshow_rounded,
  DocumentKind.excel => Icons.grid_on_rounded,
};

class _EditorRuler extends StatelessWidget {
  const _EditorRuler({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    height: 25,
    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(8)),
    child: Row(children: List<Widget>.generate(16, (index) => Expanded(
      child: Align(alignment: Alignment.bottomCenter, child: Container(width: 1, height: index % 4 == 0 ? 17 : 7, color: index % 4 == 0 ? color : Theme.of(context).colorScheme.outlineVariant)),
    ))),
  );
}

class _EditorGridPainter extends CustomPainter {
  const _EditorGridPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 0.6;
    const step = 32.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
  @override
  bool shouldRepaint(covariant _EditorGridPainter oldDelegate) => oldDelegate.color != color;
}

class _OfficePreview extends StatelessWidget {
  const _OfficePreview({required this.kind, required this.title, required this.accent, required this.zoom});
  final DocumentKind kind;
  final String title;
  final Color accent;
  final double zoom;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(22), border: Border.all(color: theme.colorScheme.outlineVariant)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Live preview', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text('Document canvas', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 20),
        Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: Transform.scale(
                scale: zoom,
                child: Container(
                  width: kind == DocumentKind.powerpoint ? 520 : 360,
                  height: kind == DocumentKind.powerpoint ? 292 : 495,
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 18, offset: const Offset(0, 7))]),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(width: 52, height: 5, color: accent),
                    const SizedBox(height: 18),
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: Color(0xFF18243A))),
                    const SizedBox(height: 18),
                    ...List<Widget>.generate(8, (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(height: 5, width: index % 3 == 0 ? 300 : (index % 2 == 0 ? 255 : 210), color: const Color(0xFFDDE5F0)),
                    )),
                  ]),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(L10n.text(Localizations.localeOf(context), 'saveHint'), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ]),
    );
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


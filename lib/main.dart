import 'dart:typed_data';

import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'document_factory.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ParinOfficeApp());
}

enum AppearanceMode { system, light, dark, amoled }

class ThemePreset {
  const ThemePreset({required this.index, required this.name, required this.family, required this.primary, required this.secondary});
  final int index;
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
  static const _hues = <double>[205, 231, 258, 282, 338, 8, 37, 75, 145, 164, 177, 190, 215, 222, 228, 36];

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
      index: index,
      name: families[familyIndex] + ' ' + (variant + 1).toString(),
      family: families[familyIndex],
      primary: primary,
      secondary: secondary,
    );
  });

  static ThemeData build(ThemePreset preset, Brightness brightness, {bool amoled = false, bool highContrast = false}) {
    final isLight = brightness == Brightness.light;
    final background = isLight ? const Color(0xFFF5F7FB) : (amoled ? Colors.black : const Color(0xFF101319));
    final surface = isLight ? Colors.white : (amoled ? Colors.black : const Color(0xFF171B23));
    final surfaceLow = isLight ? const Color(0xFFEEF2F8) : (amoled ? const Color(0xFF050506) : const Color(0xFF1D222C));
    final surfaceHigh = isLight ? const Color(0xFFE5EAF3) : (amoled ? const Color(0xFF0D0D10) : const Color(0xFF262C37));
    final outline = highContrast
        ? (isLight ? const Color(0xFF303745) : const Color(0xFFE4E8EF))
        : (isLight ? const Color(0xFFD7DEEA) : const Color(0xFF343B48));
    final seed = ColorScheme.fromSeed(seedColor: preset.primary, brightness: brightness);
    final colors = seed.copyWith(
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
      onSurface: isLight ? const Color(0xFF182031) : const Color(0xFFF0F3F8),
      onSurfaceVariant: isLight ? const Color(0xFF5E6879) : const Color(0xFFABB4C3),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      brightness: brightness,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(centerTitle: false, scrolledUnderElevation: 0, backgroundColor: background, foregroundColor: colors.onSurface),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: outline.withValues(alpha: 0.55))),
      ),
      dividerTheme: DividerThemeData(color: outline.withValues(alpha: 0.7), thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLow,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: outline)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: outline)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: preset.primary, width: 1.8)),
      ),
      chipTheme: ChipThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: BorderSide(color: outline), labelStyle: TextStyle(color: colors.onSurface)),
      snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
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
  List<String> recentDocuments = <String>[];
  Set<int> favoriteThemes = <int>{};

  static const defaults = <String, bool>{
    'autosave': true, 'animations': true, 'haptics': true, 'compactRibbon': false,
    'confirmExport': false, 'showExtensions': true, 'smartPunctuation': true, 'spellAssist': true,
    'showGridlines': true, 'showRulers': true, 'autoRecovery': true, 'reduceMotion': false,
    'highContrast': false, 'lowMemoryMode': false, 'previewThumbnails': true, 'offlineOnly': true,
    'diagnostics': false, 'restoreDrafts': true, 'protectSourceFiles': true, 'showStatusBar': true,
    'blueLightFilter': false,
  };
  final Map<String, bool> _flags = Map<String, bool>.from(defaults);

  bool flag(String key) => _flags[key] ?? false;
  bool get compactRibbon => flag('compactRibbon');
  bool get amoled => mode == AppearanceMode.amoled;
  ThemePreset get preset => ThemeCatalog.presets[themeIndex.clamp(0, 127).toInt()];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLocale = prefs.getString('locale');
    if (savedLocale != null) {
      final exact = L10n.locales.where((item) => item.toLanguageTag().toLowerCase() == savedLocale.toLowerCase());
      locale = exact.isNotEmpty
          ? exact.first
          : L10n.locales.firstWhere((item) => item.languageCode == savedLocale.split('-').first, orElse: () => const Locale('en'));
    }
    mode = AppearanceMode.values.firstWhere((item) => item.name == prefs.getString('mode'), orElse: () => AppearanceMode.system);
    themeIndex = (prefs.getInt('theme') ?? 9).clamp(0, 127).toInt();
    blueStrength = (prefs.getDouble('blueStrength') ?? 0.42).clamp(0.0, 1.0).toDouble();
    textScale = (prefs.getDouble('textScale') ?? 1).clamp(0.85, 1.4).toDouble();
    defaultZoom = (prefs.getDouble('defaultZoom') ?? 1).clamp(0.5, 1.5).toDouble();
    editorFontSize = (prefs.getDouble('editorFontSize') ?? 16).clamp(12.0, 26.0).toDouble();
    favoriteThemes = (prefs.getStringList('favoriteThemes') ?? <String>[])
        .map(int.tryParse).whereType<int>().where((item) => item >= 0 && item < 128).toSet();
    recentDocuments = prefs.getStringList('recentDocuments') ?? <String>[];
    for (final key in defaults.keys) {
      _flags[key] = prefs.getBool('settings.' + key) ?? prefs.getBool(key) ?? defaults[key]!;
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
    _flags[key] = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('settings.' + key, value);
    await prefs.setBool(key, value);
  }

  Future<void> setNumber(String key, double value) async {
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
    for (final key in prefs.getKeys().where((key) => key.startsWith('draft.')).toList()) {
      await prefs.remove(key);
    }
    notifyListeners();
  }
}

class L10n {
  static const locales = <Locale>[
    Locale('fa'), Locale('en'), Locale('da'), Locale('de'), Locale('de', 'CH'), Locale('ar'),
    Locale('hi'), Locale('he'), Locale('es'), Locale('it'), Locale('sv'), Locale('fi'),
    Locale('no'), Locale('is'), Locale('el'), Locale('tr'),
  ];
  static const names = <String>[
    'فارسی', 'English', 'Dansk', 'Deutsch', 'Schweizerdeutsch', 'العربية', 'हिन्दी', 'עברית',
    'Español', 'Italiano', 'Svenska', 'Suomi', 'Norsk', 'Íslenska', 'Ελληνικά', 'Türkçe',
  ];
  static const en = <String, String>{
    'home':'Home','recent':'Recent files','workspace':'Workspace','settings':'Settings','open':'Open file','create':'Create new',
    'pdf':'PDF','word':'Word','powerpoint':'PowerPoint','excel':'Excel','quick':'Quick actions','themes':'Color themes',
    'language':'Language','appearance':'Appearance','general':'General','editor':'Editor preferences','security':'Privacy & security',
    'performance':'Performance','accessibility':'Accessibility','light':'Light','dark':'Dark','amoled':'AMOLED black','system':'System',
    'search':'Search','newDocument':'New document','welcome':'Your work, beautifully organized.',
    'welcomeSubtitle':'Create, edit and export documents from one calm workspace.','createPdf':'Create PDF','createWord':'Create Word file',
    'createPowerPoint':'Create presentation','createExcel':'Create spreadsheet','documentTitle':'Document title','cancel':'Cancel',
    'done':'Done','save':'Save / Export','noRecent':'No recent documents yet','clearRecent':'Clear recent documents',
    'clearDrafts':'Clear saved drafts','blueFilter':'Blue-light filter','blueFilterSubtitle':'Optional warm tint for evening use',
    'strength':'Filter strength','selectedTheme':'Selected theme','allThemes':'All themes','favorites':'Favorites',
    'autosave':'Autosave local drafts','animations':'Animated transitions','haptics':'Haptic feedback','compactRibbon':'Compact editor toolbar',
    'confirmExport':'Confirm before export','showExtensions':'Show file extensions','smartPunctuation':'Smart punctuation',
    'spellAssist':'Writing assistance hints','showGridlines':'Spreadsheet gridlines','showRulers':'Editor rulers','autoRecovery':'Save recovery copy',
    'reduceMotion':'Reduce motion','highContrast':'High contrast','lowMemoryMode':'Low-memory mode','previewThumbnails':'Show live preview',
    'offlineOnly':'Prefer offline processing','diagnostics':'Show local diagnostics','restoreDrafts':'Restore saved drafts',
    'protectSourceFiles':'Protect source files','showStatusBar':'Show editor status bar','textScale':'Interface text size',
    'defaultZoom':'Default document zoom','fontSize':'Editor font size','generalSubtitle':'Saved settings that affect the workspace',
    'recentSubtitle':'Continue where you left off','subtitlePdf':'Create a PDF and open it in PDF Studio',
    'subtitleWord':'Write text and export a DOCX file','subtitlePowerPoint':'Write slide content and export PPTX',
    'subtitleExcel':'Use tabs between columns and new lines between rows','saveHint':'The file is generated on this device.',
    'existingFileNote':'Imported Office files are not fully parsed yet. Saving creates a new file from this editor text.',
    'spreadsheetHint':'Tip: separate columns with a Tab; each new line becomes a row.','draftSaved':'Draft saved on this device',
    'exported':'File exported','openFailed':'Could not open that file','onDevice':'On this device','about':'About Parin Office',
    'aboutText':'PDF editing is integrated and DOCX/PPTX/XLSX creation is enabled. Full native editing for imported Office files is still under development.',
  };
  static const maps = <String, Map<String, String>>{
    'fa': {
      'home':'خانه','recent':'فایل‌های اخیر','workspace':'فضای کار','settings':'تنظیمات','open':'باز کردن فایل','create':'ساخت فایل',
      'quick':'عملیات سریع','themes':'تم‌های رنگی','language':'زبان','appearance':'ظاهر برنامه','general':'عمومی',
      'editor':'تنظیمات ویرایشگر','security':'حریم خصوصی و امنیت','performance':'کارایی','accessibility':'دسترس‌پذیری',
      'light':'روشن','dark':'تاریک','amoled':'مشکی AMOLED','system':'سیستم','search':'جستجو','newDocument':'سند جدید',
      'welcome':'همه کارهایت، مرتب و حرفه‌ای.','welcomeSubtitle':'اسناد را در یک فضای کاری خلوت بساز، ویرایش و صادر کن.',
      'createPdf':'ساخت PDF','createWord':'ساخت فایل Word','createPowerPoint':'ساخت ارائه','createExcel':'ساخت صفحه‌گسترده',
      'documentTitle':'عنوان سند','cancel':'انصراف','done':'تأیید','save':'ذخیره / خروجی','noRecent':'هنوز سندی باز نشده است',
      'clearRecent':'پاک کردن فایل‌های اخیر','clearDrafts':'پاک کردن پیش‌نویس‌ها','blueFilter':'فیلتر نور آبی',
      'blueFilterSubtitle':'ته‌رنگ گرم و اختیاری برای شب','strength':'شدت فیلتر','selectedTheme':'تم انتخاب‌شده',
      'allThemes':'همه تم‌ها','favorites':'علاقه‌مندی‌ها','autosave':'ذخیره خودکار پیش‌نویس','animations':'انیمیشن انتقال‌ها',
      'haptics':'بازخورد لرزشی','compactRibbon':'نوار ابزار فشرده','confirmExport':'تأیید پیش از خروجی',
      'showExtensions':'نمایش پسوند فایل','smartPunctuation':'نشانه‌گذاری هوشمند','spellAssist':'راهنمای نوشتار',
      'showGridlines':'خطوط جدول اکسل','showRulers':'خط‌کش ویرایشگر','autoRecovery':'ذخیره نسخه بازیابی',
      'reduceMotion':'کاهش حرکت و انیمیشن','highContrast':'کنتراست بالا','lowMemoryMode':'حالت حافظه کم',
      'previewThumbnails':'نمایش پیش‌نمایش','offlineOnly':'پردازش ترجیحاً آفلاین','diagnostics':'نمایش اطلاعات فنی محلی',
      'restoreDrafts':'بازیابی پیش‌نویس','protectSourceFiles':'محافظت از فایل اصلی','showStatusBar':'نمایش نوار وضعیت',
      'textScale':'اندازه نوشته‌های رابط','defaultZoom':'بزرگ‌نمایی پیش‌فرض','fontSize':'اندازه متن ویرایشگر',
      'generalSubtitle':'گزینه‌هایی که ذخیره می‌شوند و روی محیط کار اثر دارند','recentSubtitle':'ادامه از آخرین نقطه',
      'subtitlePdf':'ساخت PDF و باز کردن در استودیوی PDF','subtitleWord':'نوشتن متن و خروجی DOCX',
      'subtitlePowerPoint':'نوشتن محتوای اسلاید و خروجی PPTX','subtitleExcel':'ستون‌ها با Tab و ردیف‌ها با خط جدید جدا می‌شوند',
      'saveHint':'فایل روی همین دستگاه تولید می‌شود.','existingFileNote':'خواندن کامل فایل‌های آفیس واردشده هنوز فعال نیست؛ ذخیره فایل جدیدی از متن ویرایشگر می‌سازد.',
      'spreadsheetHint':'نکته: ستون‌ها را با Tab جدا کن؛ هر خط یک ردیف است.','draftSaved':'پیش‌نویس روی دستگاه ذخیره شد',
      'exported':'فایل صادر شد','openFailed':'باز کردن فایل ممکن نشد','onDevice':'روی دستگاه','about':'درباره Parin Office',
      'aboutText':'ویرایش PDF یکپارچه است و ساخت DOCX/PPTX/XLSX فعال است؛ ویرایش کامل فایل‌های آفیس واردشده در حال توسعه است.',
    },
    'ar': {
      'home':'الرئيسية','recent':'الملفات الأخيرة','workspace':'مساحة العمل','settings':'الإعدادات','open':'فتح ملف','create':'إنشاء جديد',
      'quick':'إجراءات سريعة','themes':'سمات الألوان','language':'اللغة','appearance':'المظهر','general':'عام',
      'editor':'إعدادات المحرر','security':'الخصوصية والأمان','performance':'الأداء','accessibility':'إمكانية الوصول',
      'light':'فاتح','dark':'داكن','amoled':'أسود AMOLED','system':'النظام','search':'بحث','newDocument':'مستند جديد',
      'welcome':'عملك، منظم باحتراف.','welcomeSubtitle':'أنشئ المستندات وعدّلها وصدّرها من مساحة واحدة.',
      'createPdf':'إنشاء PDF','createWord':'إنشاء ملف Word','createPowerPoint':'إنشاء عرض','createExcel':'إنشاء جدول بيانات',
      'documentTitle':'عنوان المستند','cancel':'إلغاء','done':'تم','save':'حفظ / تصدير','noRecent':'لا توجد مستندات حديثة بعد',
      'clearRecent':'مسح الملفات الأخيرة','clearDrafts':'مسح المسودات المحفوظة','blueFilter':'مرشح الضوء الأزرق',
      'blueFilterSubtitle':'درجة دافئة اختيارية للمساء','strength':'قوة المرشح','selectedTheme':'السمة المحددة',
      'allThemes':'كل السمات','favorites':'المفضلة','autosave':'حفظ المسودات تلقائياً','animations':'انتقالات متحركة',
      'haptics':'الاهتزاز اللمسي','compactRibbon':'شريط أدوات مضغوط','confirmExport':'التأكيد قبل التصدير',
      'showExtensions':'إظهار امتدادات الملفات','smartPunctuation':'ترقيم ذكي','spellAssist':'تلميحات الكتابة',
      'showGridlines':'خطوط جدول البيانات','showRulers':'مساطر المحرر','autoRecovery':'حفظ نسخة للاسترداد',
      'reduceMotion':'تقليل الحركة','highContrast':'تباين عالٍ','lowMemoryMode':'وضع ذاكرة منخفضة',
      'previewThumbnails':'إظهار المعاينات','offlineOnly':'تفضيل المعالجة دون اتصال','diagnostics':'عرض معلومات التشخيص المحلية',
      'restoreDrafts':'استعادة المسودات','protectSourceFiles':'حماية الملفات الأصلية','showStatusBar':'إظهار شريط الحالة',
      'textScale':'حجم نص الواجهة','defaultZoom':'تكبير المستند الافتراضي','fontSize':'حجم خط المحرر',
      'generalSubtitle':'إعدادات محفوظة تؤثر في مساحة العمل','recentSubtitle':'تابع من آخر نقطة',
      'subtitlePdf':'أنشئ PDF وافتحه في استوديو PDF','subtitleWord':'اكتب النص وصدّره كملف DOCX',
      'subtitlePowerPoint':'اكتب محتوى الشريحة وصدّره PPTX','subtitleExcel':'افصل الأعمدة بعلامة تبويب والصفوف بأسطر جديدة',
      'saveHint':'يتم إنشاء الملف على هذا الجهاز.','existingFileNote':'قراءة ملفات Office المستوردة بالكامل قيد التطوير؛ الحفظ ينشئ ملفاً جديداً من نص المحرر.',
      'spreadsheetHint':'نصيحة: Tab يفصل الأعمدة وكل سطر يمثل صفاً.','draftSaved':'تم حفظ المسودة على الجهاز',
      'exported':'تم تصدير الملف','openFailed':'تعذر فتح الملف','onDevice':'على الجهاز','about':'حول Parin Office',
      'aboutText':'تحرير PDF مدمج وإنشاء DOCX/PPTX/XLSX متاح؛ تحرير ملفات Office المستوردة بالكامل ما زال قيد التطوير.',
    },
    'de': {
      'home':'Startseite','recent':'Zuletzt verwendet','workspace':'Arbeitsbereich','settings':'Einstellungen','open':'Datei öffnen','create':'Neu erstellen',
      'quick':'Schnellaktionen','themes':'Farbthemen','language':'Sprache','appearance':'Darstellung','general':'Allgemein',
      'editor':'Editor-Einstellungen','security':'Datenschutz & Sicherheit','performance':'Leistung','accessibility':'Barrierefreiheit',
      'light':'Hell','dark':'Dunkel','amoled':'AMOLED-Schwarz','system':'System','search':'Suchen','newDocument':'Neues Dokument',
      'welcome':'Deine Arbeit. Klar organisiert.','welcomeSubtitle':'Dokumente an einem Ort erstellen, bearbeiten und exportieren.',
      'createPdf':'PDF erstellen','createWord':'Word-Datei erstellen','createPowerPoint':'Präsentation erstellen','createExcel':'Tabelle erstellen',
      'documentTitle':'Dokumenttitel','cancel':'Abbrechen','done':'Fertig','save':'Speichern / Exportieren',
      'blueFilter':'Blaulichtfilter','blueFilterSubtitle':'Optionaler warmer Farbton am Abend','strength':'Filterstärke',
      'selectedTheme':'Ausgewähltes Thema','allThemes':'Alle Themen','favorites':'Favoriten','autosave':'Entwürfe automatisch speichern',
      'animations':'Animierte Übergänge','haptics':'Haptisches Feedback','compactRibbon':'Kompakte Symbolleiste','confirmExport':'Export bestätigen',
      'showExtensions':'Dateiendungen anzeigen','smartPunctuation':'Intelligente Zeichensetzung','spellAssist':'Schreibhilfen',
      'showGridlines':'Tabellenraster','showRulers':'Editor-Lineale','autoRecovery':'Wiederherstellungskopie speichern',
      'reduceMotion':'Bewegung reduzieren','highContrast':'Hoher Kontrast','lowMemoryMode':'Speichersparmodus','previewThumbnails':'Live-Vorschau anzeigen',
      'offlineOnly':'Offline-Verarbeitung bevorzugen','diagnostics':'Lokale Diagnose anzeigen','restoreDrafts':'Gespeicherte Entwürfe wiederherstellen',
      'protectSourceFiles':'Quelldateien schützen','showStatusBar':'Statusleiste anzeigen','textScale':'Textgröße der Oberfläche',
      'defaultZoom':'Standard-Zoom','fontSize':'Editor-Schriftgröße','generalSubtitle':'Gespeicherte Optionen für den Arbeitsbereich',
      'recentSubtitle':'Dort weitermachen, wo du aufgehört hast','subtitlePdf':'PDF erstellen und im PDF-Studio öffnen',
      'subtitleWord':'Text schreiben und als DOCX exportieren','subtitlePowerPoint':'Folieninhalt schreiben und als PPTX exportieren',
      'subtitleExcel':'Spalten mit Tab, Zeilen mit Zeilenumbruch trennen','saveHint':'Die Datei wird auf diesem Gerät erstellt.',
      'existingFileNote':'Importierte Office-Dateien werden noch nicht vollständig eingelesen; Speichern erstellt eine neue Datei aus dem Editor-Text.',
      'spreadsheetHint':'Tipp: Tab trennt Spalten; jede neue Zeile ergibt eine Zeile.','draftSaved':'Entwurf lokal gespeichert',
      'exported':'Datei exportiert','openFailed':'Datei konnte nicht geöffnet werden','onDevice':'Auf diesem Gerät',
      'clearRecent':'Zuletzt verwendete Dateien löschen','clearDrafts':'Gespeicherte Entwürfe löschen','noRecent':'Noch keine aktuellen Dokumente',
      'about':'Über Parin Office','aboutText':'PDF-Bearbeitung ist integriert, DOCX/PPTX/XLSX-Erstellung ist aktiv. Vollständige Bearbeitung importierter Office-Dateien ist in Arbeit.',
    },
    'es': {
      'home':'Inicio','recent':'Archivos recientes','workspace':'Espacio de trabajo','settings':'Ajustes','open':'Abrir archivo','create':'Crear nuevo',
      'quick':'Acciones rápidas','themes':'Temas de color','language':'Idioma','appearance':'Apariencia','general':'General',
      'editor':'Preferencias del editor','security':'Privacidad y seguridad','performance':'Rendimiento','accessibility':'Accesibilidad',
      'light':'Claro','dark':'Oscuro','amoled':'Negro AMOLED','system':'Sistema','search':'Buscar','newDocument':'Documento nuevo',
      'welcome':'Tu trabajo, bien organizado.','welcomeSubtitle':'Crea, edita y exporta documentos desde un solo espacio.',
      'createPdf':'Crear PDF','createWord':'Crear archivo Word','createPowerPoint':'Crear presentación','createExcel':'Crear hoja de cálculo',
      'documentTitle':'Título del documento','cancel':'Cancelar','done':'Listo','save':'Guardar / Exportar',
      'blueFilter':'Filtro de luz azul','blueFilterSubtitle':'Tinte cálido opcional para la noche','strength':'Intensidad del filtro',
      'selectedTheme':'Tema seleccionado','allThemes':'Todos los temas','favorites':'Favoritos',
      'autosave':'Guardar borradores automáticamente','animations':'Transiciones animadas','haptics':'Respuesta háptica',
      'compactRibbon':'Barra de herramientas compacta','confirmExport':'Confirmar antes de exportar','showExtensions':'Mostrar extensiones de archivo',
      'smartPunctuation':'Puntuación inteligente','spellAssist':'Ayudas de escritura','showGridlines':'Cuadrícula de hoja de cálculo',
      'showRulers':'Reglas del editor','autoRecovery':'Guardar copia de recuperación','reduceMotion':'Reducir movimiento',
      'highContrast':'Alto contraste','lowMemoryMode':'Modo de poca memoria','previewThumbnails':'Mostrar vista previa',
      'offlineOnly':'Preferir procesamiento sin conexión','diagnostics':'Mostrar diagnóstico local','restoreDrafts':'Restaurar borradores guardados',
      'protectSourceFiles':'Proteger archivos originales','showStatusBar':'Mostrar barra de estado','textScale':'Tamaño del texto de la interfaz',
      'defaultZoom':'Zoom predeterminado','fontSize':'Tamaño de letra del editor','generalSubtitle':'Opciones guardadas del espacio de trabajo',
      'recentSubtitle':'Continúa donde lo dejaste','subtitlePdf':'Crea un PDF y ábrelo en PDF Studio','subtitleWord':'Escribe texto y expórtalo como DOCX',
      'subtitlePowerPoint':'Escribe contenido de diapositivas y expórtalo como PPTX','subtitleExcel':'Separa columnas con tabulaciones y filas con saltos de línea',
      'saveHint':'El archivo se genera en este dispositivo.','existingFileNote':'La lectura completa de Office importado sigue en desarrollo; guardar crea un archivo nuevo desde el texto del editor.',
      'spreadsheetHint':'Consejo: Tab separa columnas; cada línea nueva crea una fila.','draftSaved':'Borrador guardado en este dispositivo',
      'exported':'Archivo exportado','openFailed':'No se pudo abrir el archivo','onDevice':'En este dispositivo','clearRecent':'Borrar archivos recientes',
      'clearDrafts':'Borrar borradores guardados','noRecent':'Aún no hay documentos recientes','about':'Acerca de Parin Office',
      'aboutText':'La edición PDF está integrada y la creación DOCX/PPTX/XLSX está disponible. La edición nativa completa de Office importado sigue en desarrollo.',
    },
    'tr': {
      'home':'Ana sayfa','recent':'Son dosyalar','workspace':'Çalışma alanı','settings':'Ayarlar','open':'Dosya aç','create':'Yeni oluştur',
      'quick':'Hızlı işlemler','themes':'Renk temaları','language':'Dil','appearance':'Görünüm','general':'Genel',
      'editor':'Düzenleyici tercihleri','security':'Gizlilik ve güvenlik','performance':'Performans','accessibility':'Erişilebilirlik',
      'light':'Açık','dark':'Koyu','amoled':'AMOLED siyahı','system':'Sistem','search':'Ara','newDocument':'Yeni belge',
      'welcome':'İşlerin düzenli ve profesyonel.','welcomeSubtitle':'Belgeleri tek bir çalışma alanında oluştur, düzenle ve dışa aktar.',
      'createPdf':'PDF oluştur','createWord':'Word dosyası oluştur','createPowerPoint':'Sunum oluştur','createExcel':'E-tablo oluştur',
      'documentTitle':'Belge başlığı','cancel':'İptal','done':'Tamam','save':'Kaydet / Dışa aktar',
      'blueFilter':'Mavi ışık filtresi','blueFilterSubtitle':'Akşam için isteğe bağlı sıcak ton','strength':'Filtre gücü',
      'selectedTheme':'Seçili tema','allThemes':'Tüm temalar','favorites':'Favoriler','autosave':'Taslakları otomatik kaydet',
      'animations':'Animasyonlu geçişler','haptics':'Dokunsal geri bildirim','compactRibbon':'Kompakt araç çubuğu',
      'confirmExport':'Dışa aktarmadan önce onayla','showExtensions':'Dosya uzantılarını göster','smartPunctuation':'Akıllı noktalama',
      'spellAssist':'Yazım yardımcıları','showGridlines':'Tablo kılavuz çizgileri','showRulers':'Düzenleyici cetvelleri',
      'autoRecovery':'Kurtarma kopyasını kaydet','reduceMotion':'Hareketi azalt','highContrast':'Yüksek kontrast',
      'lowMemoryMode':'Düşük bellek modu','previewThumbnails':'Canlı önizlemeyi göster','offlineOnly':'Çevrimdışı işlemeyi tercih et',
      'diagnostics':'Yerel tanılamayı göster','restoreDrafts':'Kaydedilmiş taslakları geri yükle','protectSourceFiles':'Kaynak dosyaları koru',
      'showStatusBar':'Durum çubuğunu göster','textScale':'Arayüz metin boyutu','defaultZoom':'Varsayılan yakınlaştırma',
      'fontSize':'Düzenleyici yazı boyutu','generalSubtitle':'Çalışma alanını etkileyen kayıtlı seçenekler',
      'recentSubtitle':'Kaldığın yerden devam et','subtitlePdf':'PDF oluştur ve PDF Studio’da aç','subtitleWord':'Metin yaz ve DOCX olarak dışa aktar',
      'subtitlePowerPoint':'Slayt metnini yaz ve PPTX olarak dışa aktar','subtitleExcel':'Sütunları Tab, satırları yeni satırla ayır',
      'saveHint':'Dosya bu cihazda oluşturulur.','existingFileNote':'İçe aktarılan Office dosyalarının tam okunması geliştirme aşamasında; kaydetme yeni dosya oluşturur.',
      'spreadsheetHint':'İpucu: Tab sütunları ayırır; her yeni satır bir satır oluşturur.','draftSaved':'Taslak bu cihaza kaydedildi',
      'exported':'Dosya dışa aktarıldı','openFailed':'Dosya açılamadı','onDevice':'Bu cihazda','clearRecent':'Son dosyaları temizle',
      'clearDrafts':'Kaydedilmiş taslakları temizle','noRecent':'Henüz son belge yok','about':'Parin Office hakkında',
      'aboutText':'PDF düzenleme tümleşiktir; DOCX/PPTX/XLSX oluşturma etkin. İçe aktarılan Office dosyalarının tam düzenlemesi geliştiriliyor.',
    },
    'he': {'home':'בית','recent':'קבצים אחרונים','workspace':'סביבת עבודה','settings':'הגדרות','open':'פתיחת קובץ','create':'יצירה חדשה','quick':'פעולות מהירות','themes':'ערכות צבע','language':'שפה','appearance':'מראה','general':'כללי','editor':'העדפות העורך','security':'פרטיות ואבטחה','performance':'ביצועים','accessibility':'נגישות','light':'בהיר','dark':'כהה','amoled':'שחור AMOLED','system':'מערכת','search':'חיפוש','newDocument':'מסמך חדש','welcome':'העבודה שלך, מסודרת היטב.','createPdf':'יצירת PDF','createWord':'יצירת קובץ Word','createPowerPoint':'יצירת מצגת','createExcel':'יצירת גיליון','documentTitle':'כותרת המסמך','cancel':'ביטול','done':'סיום','save':'שמירה / ייצוא','blueFilter':'מסנן אור כחול','strength':'עוצמת המסנן','allThemes':'כל הערכות','favorites':'מועדפים'},
  };

  static String text(Locale locale, String key) => maps[locale.languageCode]?[key] ?? en[key] ?? key;
  static bool rtl(Locale locale) => const <String>{'fa', 'ar', 'he'}.contains(locale.languageCode);
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
    state.load().whenComplete(() { if (mounted) setState(() => ready = true); });
  }
  @override
  void dispose() { state.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (!ready) return const MaterialApp(home: Scaffold(body: Center(child: CircularProgressIndicator())));
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final noMotion = state.flag('reduceMotion') || !state.flag('animations');
        return MaterialApp(
          title: 'Parin Office',
          debugShowCheckedModeBanner: false,
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
          theme: ThemeCatalog.build(state.preset, Brightness.light, highContrast: state.flag('highContrast')),
          darkTheme: ThemeCatalog.build(state.preset, Brightness.dark, amoled: state.amoled, highContrast: state.flag('highContrast')),
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
                  IgnorePointer(child: ColoredBox(color: const Color(0xFFFFB65C).withValues(alpha: state.blueStrength * 0.18))),
              ],
            );
          },
          home: AppShell(state: state),
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
      width: size, height: size, padding: EdgeInsets.all(size * 0.15),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [colors.primary, colors.secondary]),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(color: const Color(0xFF071632), borderRadius: BorderRadius.circular(size * 0.18)),
        child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.state});
  final AppState state;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int selectedIndex = 0;
  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    String t(String key) => L10n.text(state.locale, key);
    final nav = <(IconData, String)>[
      (Icons.space_dashboard_rounded, t('home')),
      (Icons.history_rounded, t('recent')),
      (Icons.grid_view_rounded, t('workspace')),
      (Icons.tune_rounded, t('settings')),
    ];
    final pages = <Widget>[
      DashboardPage(state: state),
      RecentPage(state: state),
      WorkspacePage(state: state),
      SettingsPage(state: state),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth >= 760) {
        final extended = constraints.maxWidth >= 1120;
        return Scaffold(
          body: Row(children: [
            Container(
              width: extended ? 248 : 86,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(right: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
              ),
              child: Column(children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: extended ? 18 : 13, vertical: 24),
                  child: Row(mainAxisAlignment: extended ? MainAxisAlignment.start : MainAxisAlignment.center, children: [
                    const BrandMark(size: 44),
                    if (extended) ...[
                      const SizedBox(width: 12),
                      const Expanded(child: Text('Parin Office', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                    ],
                  ]),
                ),
                Expanded(
                  child: NavigationRail(
                    extended: extended,
                    selectedIndex: selectedIndex,
                    onDestinationSelected: (value) => setState(() => selectedIndex = value),
                    labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                    destinations: nav.map((item) => NavigationRailDestination(icon: Icon(item.$1), selectedIcon: Icon(item.$1), label: Text(item.$2))).toList(),
                  ),
                ),
                if (extended)
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
                      child: Row(children: [
                        Icon(Icons.offline_bolt_rounded, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 9),
                        Expanded(child: Text(t('onDevice'), style: const TextStyle(fontWeight: FontWeight.w800))),
                      ]),
                    ),
                  ),
              ]),
            ),
            Expanded(child: pages[selectedIndex]),
          ]),
        );
      }
      return Scaffold(
        body: pages[selectedIndex],
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (value) => setState(() => selectedIndex = value),
          destinations: nav.map((item) => NavigationDestination(icon: Icon(item.$1), selectedIcon: Icon(item.$1), label: item.$2)).toList(),
        ),
      );
    });
  }
}

Future<void> createDocument(BuildContext context, AppState state, {DocumentKind? initialKind}) async {
  final result = await showDialog<(DocumentKind, String)>(
    context: context,
    builder: (_) => _CreateDialog(state: state, initialKind: initialKind),
  );
  if (!context.mounted || result == null) return;
  final kind = result.$1;
  final title = result.$2.trim().isEmpty ? 'Untitled' : result.$2.trim();
  try {
    if (kind == DocumentKind.pdf) {
      final bytes = await DocumentFactory.create(kind, title, DocumentFactory.initialContent(kind));
      if (!context.mounted) return;
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PdfStudioPage(bytes: bytes, name: title + '.pdf', state: state)));
    } else {
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => OfficeDocumentEditor(kind: kind, title: title, state: state, content: DocumentFactory.initialContent(kind)),
      ));
    }
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create file: ' + error.toString())));
  }
}

Future<void> openDocument(BuildContext context, AppState state) async {
  try {
    final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf', 'docx', 'pptx', 'xlsx']);
    if (!context.mounted || result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = await file.readAsBytes();
    if (!context.mounted) return;
    await state.markRecent(file.name);
    final ext = (file.extension ?? '').toLowerCase();
    if (ext == 'pdf') {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PdfStudioPage(bytes: bytes, name: file.name, state: state)));
      return;
    }
    final kind = switch (ext) {
      'pptx' => DocumentKind.powerpoint,
      'xlsx' => DocumentKind.excel,
      _ => DocumentKind.word,
    };
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => OfficeDocumentEditor(kind: kind, title: file.name, state: state, content: DocumentFactory.initialContent(kind), importedFile: true),
    ));
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(L10n.text(state.locale, 'openFailed'))));
  }
}

class _CreateDialog extends StatefulWidget {
  const _CreateDialog({required this.state, this.initialKind});
  final AppState state;
  final DocumentKind? initialKind;
  @override
  State<_CreateDialog> createState() => _CreateDialogState();
}

class _CreateDialogState extends State<_CreateDialog> {
  late DocumentKind selected;
  late final TextEditingController titleController;
  String t(String key) => L10n.text(widget.state.locale, key);

  @override
  void initState() {
    super.initState();
    selected = widget.initialKind ?? DocumentKind.word;
    titleController = TextEditingController(text: 'Untitled');
  }
  @override
  void dispose() { titleController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
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
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: titleController, autofocus: true, decoration: InputDecoration(labelText: t('documentTitle'), prefixIcon: const Icon(Icons.edit_note_rounded))),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: options.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, mainAxisExtent: 118),
              itemBuilder: (context, index) {
                final item = options[index];
                final active = selected == item.$1;
                return Material(
                  color: active ? item.$3.withValues(alpha: 0.13) : Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => setState(() => selected = item.$1),
                    child: Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: active ? item.$3 : Theme.of(context).colorScheme.outlineVariant, width: active ? 2 : 1)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Icon(item.$2, color: item.$3, size: 27),
                        Text(item.$4, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                      ]),
                    ),
                  ),
                );
              },
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(t('cancel'))),
        FilledButton.icon(onPressed: () => Navigator.pop(context, (selected, titleController.text.trim())), icon: const Icon(Icons.add_rounded), label: Text(t('create'))),
      ],
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.state});
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
          IconButton(tooltip: t('create'), onPressed: () => createDocument(context, state), icon: const Icon(Icons.add_circle_outline_rounded)),
          IconButton(tooltip: t('open'), onPressed: () => openDocument(context, state), icon: const Icon(Icons.folder_open_rounded)),
          IconButton(tooltip: t('blueFilter'), onPressed: () => state.setFlag('blueLightFilter', !state.flag('blueLightFilter')), icon: Icon(state.flag('blueLightFilter') ? Icons.wb_sunny_rounded : Icons.nightlight_round)),
          const SizedBox(width: 6),
        ],
      ),
      body: CustomScrollView(slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(width < 600 ? 15 : 25, 16, width < 600 ? 15 : 25, 18),
          sliver: SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.all(width < 600 ? 21 : 28),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [theme.colorScheme.primary, Color.lerp(theme.colorScheme.primary, theme.colorScheme.secondary, 0.55)!, const Color(0xFF142441)]),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(24)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16), SizedBox(width: 7),
                    Text('PARIN WORKSPACE', style: TextStyle(color: Colors.white, letterSpacing: 1.3, fontSize: 11, fontWeight: FontWeight.w900)),
                  ]),
                ),
                const SizedBox(height: 18),
                Text(t('welcome'), style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: -0.7, height: 1.12)),
                const SizedBox(height: 10),
                ConstrainedBox(constraints: const BoxConstraints(maxWidth: 620), child: Text(t('welcomeSubtitle'), style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white.withValues(alpha: 0.84), height: 1.5))),
                const SizedBox(height: 18),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF10203F)), onPressed: () => createDocument(context, state), icon: const Icon(Icons.add_rounded), label: Text(t('create'))),
                  OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: Colors.white.withValues(alpha: 0.55))), onPressed: () => openDocument(context, state), icon: const Icon(Icons.folder_open_rounded), label: Text(t('open'))),
                ]),
              ]),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: width < 600 ? 15 : 25),
          sliver: SliverToBoxAdapter(child: Row(children: [
            Expanded(child: Text(t('newDocument'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
            Text('PDF · DOCX · PPTX · XLSX', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
          ])),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(width < 600 ? 15 : 25, 13, width < 600 ? 15 : 25, 6),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate((context, index) {
              final doc = docs[index];
              return _DocumentTile(title: doc.$2, subtitle: doc.$3, icon: doc.$4, accent: doc.$5, compact: state.compactRibbon, onTap: () => createDocument(context, state, initialKind: doc.$1));
            }, childCount: docs.length),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, mainAxisExtent: columns == 1 ? 104 : 148, crossAxisSpacing: 13, mainAxisSpacing: 13),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(width < 600 ? 15 : 25, 20, width < 600 ? 15 : 25, 10),
          sliver: SliverToBoxAdapter(child: Text(t('quick'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: width < 600 ? 15 : 25),
          sliver: SliverToBoxAdapter(child: Wrap(spacing: 9, runSpacing: 9, children: [
            ActionChip(avatar: const Icon(Icons.note_add_outlined, size: 18), label: Text(t('create')), onPressed: () => createDocument(context, state)),
            ActionChip(avatar: const Icon(Icons.folder_open_rounded, size: 18), label: Text(t('open')), onPressed: () => openDocument(context, state)),
            ActionChip(avatar: const Icon(Icons.palette_outlined, size: 18), label: Text(t('themes')), onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SettingsPage(state: state, openAppearance: true)))),
            ActionChip(avatar: const Icon(Icons.language_rounded, size: 18), label: Text(t('language')), onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SettingsPage(state: state, openLanguage: true)))),
            ActionChip(avatar: const Icon(Icons.nightlight_round, size: 18), label: Text(t('blueFilter')), onPressed: () => state.setFlag('blueLightFilter', !state.flag('blueLightFilter'))),
            ActionChip(avatar: const Icon(Icons.history_rounded, size: 18), label: Text(t('recent')), onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => RecentPage(state: state)))),
          ])),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(width < 600 ? 15 : 25, 21, width < 600 ? 15 : 25, 30),
          sliver: SliverToBoxAdapter(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Wrap(spacing: 26, runSpacing: 18, children: const [
                  _Metric(Icons.devices_other_rounded, 'Adaptive', 'Phone + Tablet'),
                  _Metric(Icons.offline_bolt_outlined, 'Offline-first', 'Local file creation'),
                  _Metric(Icons.palette_outlined, 'Personalization', '128 themes · 16 locales'),
                  _Metric(Icons.security_outlined, 'Privacy', 'Local settings & drafts'),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.title, required this.subtitle, required this.icon, required this.accent, required this.compact, required this.onTap});
  final String title, subtitle;
  final IconData icon;
  final Color accent;
  final bool compact;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(22),
    child: InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 16),
        child: Row(children: [
          Container(width: compact ? 46 : 54, height: compact ? 46 : 54, decoration: BoxDecoration(color: accent.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(17)), child: Icon(icon, color: accent, size: 27)),
          const SizedBox(width: 13),
          Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.3)),
          ])),
          Icon(Icons.arrow_outward_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 18),
        ]),
      ),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.icon, this.title, this.subtitle);
  final IconData icon;
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 205,
    child: Row(children: [
      Icon(icon, color: Theme.of(context).colorScheme.primary, size: 23),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ])),
    ]),
  );
}

class PdfStudioPage extends StatelessWidget {
  const PdfStudioPage({super.key, required this.bytes, required this.name, required this.state});
  final Uint8List bytes;
  final String name;
  final AppState state;
  Future<void> save(Uint8List output) async {
    final filename = name.toLowerCase().endsWith('.pdf') ? name : name + '.pdf';
    final result = await FilePicker.saveFile(fileName: filename, bytes: output, mimeType: 'application/pdf', dialogTitle: 'Save edited PDF', type: FileType.custom, allowedExtensions: const ['pdf']);
    if (result != null) await state.markRecent(filename);
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis)),
    body: PdfEditorView(bytes: bytes, documentId: name, onSave: save, showSaveButton: true),
  );
}

class OfficeDocumentEditor extends StatefulWidget {
  const OfficeDocumentEditor({super.key, required this.kind, required this.title, required this.state, required this.content, this.importedFile = false});
  final DocumentKind kind;
  final String title;
  final AppState state;
  final String content;
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
    titleController = TextEditingController(text: widget.title.replaceFirst(RegExp(r'\.(docx|pptx|xlsx)$', caseSensitive: false), ''));
    contentController = TextEditingController(text: widget.content);
    _restoreDraft();
  }
  @override
  void dispose() { titleController.dispose(); contentController.dispose(); super.dispose(); }

  Future<void> _restoreDraft() async {
    if (widget.importedFile || !widget.state.flag('restoreDrafts')) return;
    final text = await widget.state.loadDraft(titleController.text);
    if (!mounted || text == null || contentController.text != widget.content) return;
    setState(() => contentController.text = text);
  }

  Future<void> _saveDraft() async {
    if (widget.state.flag('autosave') && widget.state.flag('autoRecovery')) {
      await widget.state.saveDraft(titleController.text, contentController.text);
    }
  }

  Future<bool> _confirmExport() async {
    if (!widget.state.flag('confirmExport')) return true;
    final result = await showDialog<bool>(
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
    return result == true;
  }

  Future<void> _export() async {
    if (exporting || !await _confirmExport() || !mounted) return;
    setState(() => exporting = true);
    try {
      var title = titleController.text.trim();
      if (title.isEmpty) title = 'Untitled';
      title = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
      final fileName = title + '.' + widget.kind.extension;
      final bytes = await DocumentFactory.create(widget.kind, title, contentController.text, slideTitle: title);
      if (!mounted) return;
      final saved = await FilePicker.saveFile(fileName: fileName, bytes: bytes, mimeType: widget.kind.mimeType, dialogTitle: 'Save ' + widget.kind.label, type: FileType.custom, allowedExtensions: [widget.kind.extension]);
      if (saved != null) {
        await widget.state.markRecent(fileName);
        await widget.state.saveDraft(title, contentController.text);
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
    final excel = widget.kind == DocumentKind.excel;
    final accent = switch (widget.kind) {
      DocumentKind.pdf => const Color(0xFFE84E68),
      DocumentKind.word => const Color(0xFF3478E5),
      DocumentKind.powerpoint => const Color(0xFFEB8734),
      DocumentKind.excel => const Color(0xFF1A9E75),
    };
    final name = titleController.text.trim().isEmpty ? 'Untitled' : titleController.text.trim();
    final editor = Column(children: [
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(controller: titleController, onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: t('documentTitle'), prefixIcon: const Icon(Icons.title_rounded)), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            if (state.flag('showRulers')) ...[const SizedBox(height: 10), _EditorRuler(color: accent)],
            const SizedBox(height: 12),
            Row(children: [
              Icon(_kindIcon(widget.kind), color: accent), const SizedBox(width: 8),
              Expanded(child: Text(widget.kind.label, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
              if (state.flag('autosave') && state.flag('autoRecovery')) Tooltip(message: t('draftSaved'), child: Icon(Icons.cloud_done_outlined, color: theme.colorScheme.tertiary, size: 19)),
            ]),
            const SizedBox(height: 11),
            Expanded(
              child: Container(
                decoration: BoxDecoration(color: excel ? theme.colorScheme.surfaceContainerLow : theme.colorScheme.surface, border: Border.all(color: theme.colorScheme.outlineVariant), borderRadius: BorderRadius.circular(15)),
                child: Stack(children: [
                  if (excel && state.flag('showGridlines')) Positioned.fill(child: CustomPaint(painter: _GridPainter(theme.colorScheme.outlineVariant.withValues(alpha: 0.35)))),
                  TextField(
                    controller: contentController,
                    expands: true, maxLines: null, minLines: null,
                    keyboardType: TextInputType.multiline,
                    textAlignVertical: TextAlignVertical.top,
                    smartDashesType: state.flag('smartPunctuation') ? SmartDashesType.enabled : SmartDashesType.disabled,
                    smartQuotesType: state.flag('smartPunctuation') ? SmartQuotesType.enabled : SmartQuotesType.disabled,
                    style: TextStyle(fontSize: state.editorFontSize, height: 1.58, fontFamily: excel ? 'monospace' : null),
                    decoration: InputDecoration(
                      hintText: excel ? t('spreadsheetHint') : 'Start typing here…',
                      border: InputBorder.none, contentPadding: const EdgeInsets.all(18),
                      fillColor: Colors.transparent, filled: true,
                    ),
                    onChanged: (_) { setState(() {}); _saveDraft(); },
                  ),
                ]),
              ),
            ),
            if (excel && state.flag('showGridlines')) ...[
              const SizedBox(height: 8),
              Text(t('showGridlines') + ' · ' + contentController.text.split('\n').length.toString() + ' rows', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
            if (!excel && state.flag('spellAssist')) ...[
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.lightbulb_outline_rounded, color: theme.colorScheme.tertiary, size: 17),
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
          ]),
        ),
      ),
    ]);

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: accent.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(12)), child: Icon(_kindIcon(widget.kind), color: accent)),
          const SizedBox(width: 10),
          Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
        actions: [
          if (state.flag('showStatusBar')) Padding(padding: const EdgeInsets.symmetric(horizontal: 7), child: Center(child: Text(widget.kind.extension.toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 1)))),
          IconButton(tooltip: t('save'), onPressed: exporting ? null : _export, icon: exporting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.file_download_outlined)),
        ],
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        if (width >= 1020 && state.flag('previewThumbnails') && !state.flag('lowMemoryMode')) {
          return Padding(padding: const EdgeInsets.all(20), child: Row(children: [
            Expanded(flex: 3, child: editor),
            const SizedBox(width: 16),
            Expanded(flex: 2, child: _OfficePreview(kind: widget.kind, title: name, accent: accent, zoom: state.defaultZoom)),
          ]));
        }
        return Padding(padding: EdgeInsets.all(width < 600 ? 11 : 18), child: editor);
      }),
    );
  }
}

IconData _kindIcon(DocumentKind kind) => switch (kind) {
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

class _GridPainter extends CustomPainter {
  const _GridPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 0.6;
    const step = 32.0;
    for (double x = 0; x < size.width; x += step) { canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint); }
    for (double y = 0; y < size.height; y += step) { canvas.drawLine(Offset(0, y), Offset(size.width, y), paint); }
  }
  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => oldDelegate.color != color;
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
        Expanded(child: Center(child: FittedBox(fit: BoxFit.contain, child: Transform.scale(
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
              ...List<Widget>.generate(8, (index) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Container(height: 5, width: index % 3 == 0 ? 300 : (index % 2 == 0 ? 255 : 210), color: const Color(0xFFDDE5F0)))),
            ]),
          ),
        )))),
        const SizedBox(height: 12),
        Text(L10n.text(Localizations.localeOf(context), 'saveHint'), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ]),
    );
  }
}

class RecentPage extends StatelessWidget {
  const RecentPage({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) {
    String t(String key) => L10n.text(state.locale, key);
    return Scaffold(
      appBar: AppBar(title: Text(t('recent')), actions: [
        if (state.recentDocuments.isNotEmpty) IconButton(tooltip: t('clearRecent'), icon: const Icon(Icons.delete_sweep_outlined), onPressed: () async {
          await state.clearRecents();
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('clearRecent'))));
        }),
        const SizedBox(width: 8),
      ]),
      body: state.recentDocuments.isEmpty
          ? Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.folder_open_rounded, size: 54, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 12), Text(t('noRecent'), style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 7), Text(t('recentSubtitle'), style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16), FilledButton.icon(onPressed: () => openDocument(context, state), icon: const Icon(Icons.folder_open_rounded), label: Text(t('open'))),
            ])))
          : ListView.separated(
              padding: const EdgeInsets.all(18),
              itemCount: state.recentDocuments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 9),
              itemBuilder: (context, index) {
                final name = state.recentDocuments[index];
                final ext = name.split('.').last.toLowerCase();
                final icon = switch (ext) {
                  'pdf' => Icons.picture_as_pdf_rounded,
                  'docx' => Icons.description_rounded,
                  'pptx' => Icons.slideshow_rounded,
                  'xlsx' => Icons.grid_on_rounded,
                  _ => Icons.insert_drive_file_outlined,
                };
                return Card(child: ListTile(
                  leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
                  title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(state.flag('showExtensions') ? ext.toUpperCase() + ' · ' + t('onDevice') : t('onDevice')),
                  trailing: const Icon(Icons.info_outline_rounded),
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Choose ' + name + ' again with Open; file access is not stored permanently.'))),
                ));
              },
            ),
    );
  }
}

class WorkspacePage extends StatelessWidget {
  const WorkspacePage({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) {
    String t(String key) => L10n.text(state.locale, key);
    final width = MediaQuery.sizeOf(context).width;
    final cards = <(IconData, String, Color, VoidCallback)>[
      (Icons.picture_as_pdf_rounded, t('createPdf'), const Color(0xFFE84E68), () => createDocument(context, state, initialKind: DocumentKind.pdf)),
      (Icons.description_rounded, t('createWord'), const Color(0xFF3478E5), () => createDocument(context, state, initialKind: DocumentKind.word)),
      (Icons.slideshow_rounded, t('createPowerPoint'), const Color(0xFFEB8734), () => createDocument(context, state, initialKind: DocumentKind.powerpoint)),
      (Icons.grid_on_rounded, t('createExcel'), const Color(0xFF1A9E75), () => createDocument(context, state, initialKind: DocumentKind.excel)),
      (Icons.folder_open_rounded, t('open'), Theme.of(context).colorScheme.primary, () => openDocument(context, state)),
      (Icons.palette_outlined, t('themes'), Theme.of(context).colorScheme.secondary, () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SettingsPage(state: state, openAppearance: true)))),
      (Icons.language_rounded, t('language'), const Color(0xFF765DE8), () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SettingsPage(state: state, openLanguage: true)))),
      (Icons.tune_rounded, t('settings'), Theme.of(context).colorScheme.onSurfaceVariant, () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SettingsPage(state: state)))),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(t('workspace'))),
      body: GridView.builder(
        padding: EdgeInsets.all(width < 600 ? 15 : 24),
        itemCount: cards.length,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 290, mainAxisExtent: 145, crossAxisSpacing: 13, mainAxisSpacing: 13),
        itemBuilder: (context, index) {
          final item = cards[index];
          return Material(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(21),
            child: InkWell(
              borderRadius: BorderRadius.circular(21),
              onTap: item.$4,
              child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Container(width: 46, height: 46, decoration: BoxDecoration(color: item.$3.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(15)), child: Icon(item.$1, color: item.$3)),
                Row(children: [Expanded(child: Text(item.$2, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))), const Icon(Icons.arrow_outward_rounded, size: 17)]),
              ])),
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
  void dispose() { themeSearch.dispose(); languageSearch.dispose(); super.dispose(); }

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

  Widget switchTile(String key) => SwitchListTile.adaptive(
    value: widget.state.flag(key),
    title: Text(t(key)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
    onChanged: (value) async {
      if (widget.state.flag('haptics')) HapticFeedback.selectionClick();
      await widget.state.setFlag(key, value);
    },
  );

  List<ThemePreset> get visibleThemes => ThemeCatalog.presets.where((preset) {
    final query = themeSearch.text.toLowerCase();
    return preset.name.toLowerCase().contains(query) &&
      (family == 'All' || preset.family == family) &&
      (!favoritesOnly || widget.state.favoriteThemes.contains(preset.index));
  }).toList();

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
      appBar: AppBar(title: Text(t('settings')), actions: [
        IconButton(tooltip: t('blueFilter'), onPressed: () => state.setFlag('blueLightFilter', !state.flag('blueLightFilter')), icon: Icon(state.flag('blueLightFilter') ? Icons.wb_sunny_rounded : Icons.nightlight_round)),
        const SizedBox(width: 8),
      ]),
      body: ListView(
        padding: EdgeInsets.fromLTRB(width < 600 ? 12 : 22, 12, width < 600 ? 12 : 22, 42),
        children: [
          section(t('appearance'), Icons.palette_outlined, [
            ListTile(
              title: Text(t('selectedTheme')),
              subtitle: Text(state.preset.name),
              leading: Container(width: 40, height: 40, decoration: BoxDecoration(gradient: LinearGradient(colors: [state.preset.primary, state.preset.secondary]), borderRadius: BorderRadius.circular(13))),
              trailing: Text((state.themeIndex + 1).toString() + '/128', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
            ),
            Wrap(spacing: 7, runSpacing: 7, children: AppearanceMode.values.map((mode) {
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
              return ChoiceChip(avatar: Icon(icon, size: 18), label: Text(label), selected: state.mode == mode, onSelected: (_) => state.setMode(mode));
            }).toList()),
            const SizedBox(height: 13),
            TextField(controller: themeSearch, onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: t('search') + ' · ' + t('themes'), prefixIcon: const Icon(Icons.search_rounded), suffixIcon: themeSearch.text.isEmpty ? null : IconButton(onPressed: () { themeSearch.clear(); setState(() {}); }, icon: const Icon(Icons.close_rounded)))),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                ChoiceChip(label: Text(t('allThemes')), selected: family == 'All', onSelected: (_) => setState(() => family = 'All')),
                const SizedBox(width: 7),
                ...ThemeCatalog.families.map((value) => Padding(padding: const EdgeInsets.only(right: 7), child: ChoiceChip(label: Text(value), selected: family == value, onSelected: (_) => setState(() => family = value)))),
              ]),
            ),
            CheckboxListTile(
              value: favoritesOnly,
              title: Text(t('favorites')),
              subtitle: Text(state.favoriteThemes.length.toString() + ' saved palettes'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (value) => setState(() => favoritesOnly = value ?? false),
            ),
            SizedBox(
              height: width < 550 ? 390 : 455,
              child: GridView.builder(
                key: const PageStorageKey<String>('theme-grid'),
                itemCount: visibleThemes.length,
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: width < 550 ? 112 : 132, mainAxisExtent: 95, crossAxisSpacing: 10, mainAxisSpacing: 10),
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
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), border: Border.all(color: selected ? preset.primary : theme.colorScheme.outlineVariant, width: selected ? 2.2 : 1)),
                        child: Column(children: [
                          Expanded(child: Stack(children: [
                            Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [preset.primary, preset.secondary]), borderRadius: BorderRadius.circular(9)))),
                            Positioned(right: 0, top: 0, child: InkResponse(onTap: () => state.toggleFavoriteTheme(preset.index), radius: 18, child: Padding(padding: const EdgeInsets.all(4), child: Icon(favorite ? Icons.star_rounded : Icons.star_border_rounded, size: 18, color: Colors.white)))),
                            if (selected) const Center(child: Icon(Icons.check_circle_rounded, color: Colors.white, size: 24)),
                          ])),
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
            ListTile(leading: const Icon(Icons.translate_rounded), title: Text(L10n.names[L10n.locales.indexOf(state.locale)]), subtitle: Text(state.locale.toLanguageTag()), trailing: const Icon(Icons.check_circle_rounded)),
            TextField(controller: languageSearch, onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: t('search') + ' · ' + t('language'), prefixIcon: const Icon(Icons.search_rounded))),
            const SizedBox(height: 6),
            ...locales.map((locale) {
              final index = L10n.locales.indexOf(locale);
              final selected = locale.toLanguageTag() == state.locale.toLanguageTag();
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 2),
                leading: Container(width: 40, height: 40, alignment: Alignment.center, decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(12)), child: Text(locale.languageCode.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12))),
                title: Text(L10n.names[index]), subtitle: Text(locale.toLanguageTag()),
                trailing: selected ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary) : null,
                onTap: () async { await state.setLocale(locale); if (state.flag('haptics')) HapticFeedback.selectionClick(); if (mounted) setState(() {}); },
              );
            }),
            Padding(padding: const EdgeInsets.all(8), child: Text('RTL direction is applied to Persian, Arabic and Hebrew. Text scaling and navigation adapt to longer labels.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
          ], expanded: widget.openLanguage),
          section(t('general'), Icons.tune_rounded, [
            Padding(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4), child: Text(t('generalSubtitle'), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
            switchTile('autosave'), switchTile('autoRecovery'), switchTile('restoreDrafts'), switchTile('haptics'),
            switchTile('animations'), switchTile('compactRibbon'), switchTile('confirmExport'), switchTile('showExtensions'),
            switchTile('smartPunctuation'), switchTile('spellAssist'), switchTile('showStatusBar'),
          ], expanded: true),
          section(t('blueFilter'), Icons.nightlight_round, [
            SwitchListTile.adaptive(value: state.flag('blueLightFilter'), title: Text(t('blueFilter')), subtitle: Text(t('blueFilterSubtitle')), secondary: const Icon(Icons.wb_twilight_rounded), onChanged: (value) => state.setFlag('blueLightFilter', value)),
            if (state.flag('blueLightFilter')) ...[
              ListTile(title: Text(t('strength')), trailing: Text((state.blueStrength * 100).round().toString() + '%')),
              Slider(value: state.blueStrength, min: 0.05, max: 1, divisions: 19, onChanged: (value) => state.setNumber('blueStrength', value)),
              Container(height: 45, margin: const EdgeInsets.symmetric(horizontal: 4), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFE7F2FF), Color(0xFFFFE0A7), Color(0xFFFFB75A)]), borderRadius: BorderRadius.circular(13), border: Border.all(color: theme.colorScheme.outlineVariant)), child: const Center(child: Text('Live filter preview', style: TextStyle(color: Color(0xFF1D2A40), fontWeight: FontWeight.w800)))),
              const SizedBox(height: 10),
            ],
          ], expanded: true),
          section(t('editor'), Icons.edit_note_rounded, [
            ListTile(title: Text(t('textScale')), trailing: Text((state.textScale * 100).round().toString() + '%')),
            Slider(value: state.textScale, min: 0.85, max: 1.4, divisions: 11, onChanged: (value) => state.setNumber('textScale', value)),
            ListTile(title: Text(t('defaultZoom')), trailing: Text((state.defaultZoom * 100).round().toString() + '%')),
            Slider(value: state.defaultZoom, min: 0.5, max: 1.5, divisions: 10, onChanged: (value) => state.setNumber('defaultZoom', value)),
            ListTile(title: Text(t('fontSize')), trailing: Text(state.editorFontSize.round().toString())),
            Slider(value: state.editorFontSize, min: 12, max: 26, divisions: 14, onChanged: (value) => state.setNumber('editorFontSize', value)),
            switchTile('showRulers'), switchTile('showGridlines'), switchTile('smartPunctuation'), switchTile('spellAssist'),
          ]),
          section(t('accessibility'), Icons.accessibility_new_rounded, [
            switchTile('reduceMotion'), switchTile('highContrast'),
            ListTile(title: Text(t('textScale')), subtitle: Text((state.textScale * 100).round().toString() + '%'), trailing: IconButton(tooltip: 'Reset', onPressed: () => state.setNumber('textScale', 1), icon: const Icon(Icons.restart_alt_rounded))),
          ]),
          section(t('performance'), Icons.speed_rounded, [
            switchTile('lowMemoryMode'), switchTile('previewThumbnails'), switchTile('offlineOnly'), switchTile('protectSourceFiles'),
            ListTile(leading: const Icon(Icons.memory_rounded), title: const Text('Rendering profile'), subtitle: Text(state.flag('lowMemoryMode') ? 'Conservative memory profile; live preview hidden' : 'Balanced mode with tablet preview')),
            if (state.flag('diagnostics')) ListTile(leading: const Icon(Icons.info_outline_rounded), title: const Text('Local diagnostics'), subtitle: Text('Theme ' + (state.themeIndex + 1).toString() + ' · ' + state.locale.toLanguageTag() + ' · 128 palettes')),
          ]),
          section(t('security'), Icons.security_rounded, [
            switchTile('offlineOnly'), switchTile('protectSourceFiles'), switchTile('diagnostics'),
            const ListTile(leading: Icon(Icons.lock_outline_rounded), title: Text('Privacy note'), subtitle: Text('Document generation and drafts run locally. Cloud sync is not connected in this build.')),
          ]),
          section(t('general'), Icons.storage_rounded, [
            ListTile(leading: const Icon(Icons.delete_sweep_outlined), title: Text(t('clearRecent')), subtitle: Text(state.recentDocuments.length.toString() + ' recent entries'), onTap: () async { await state.clearRecents(); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('clearRecent')))); }),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: Text(t('clearDrafts')),
              subtitle: const Text('Remove local autosave recovery texts'),
              onTap: () async {
                final confirm = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
                  title: Text(t('clearDrafts')),
                  content: const Text('Saved recovery drafts will be removed from this device.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(t('cancel'))),
                    FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(t('done'))),
                  ],
                ));
                if (confirm == true) { await state.clearDrafts(); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('clearDrafts')))); }
              },
            ),
          ]),
          section(t('about'), Icons.info_outline_rounded, [
            const ListTile(leading: BrandMark(size: 42), title: Text('Parin Office'), subtitle: Text('Flutter · Android')),
            ListTile(title: Text(t('aboutText')), isThreeLine: true),
          ]),
        ],
      ),
    );
  }
}
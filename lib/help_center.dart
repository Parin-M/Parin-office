import 'package:flutter/material.dart';

class HelpCenterPage extends StatefulWidget {
  const HelpCenterPage({super.key, this.initialFormat = 'All'});

  final String initialFormat;

  @override
  State<HelpCenterPage> createState() => _HelpCenterPageState();
}

class _HelpCenterPageState extends State<HelpCenterPage> {
  final TextEditingController _search = TextEditingController();
  late String _category;

  bool get _fa => Localizations.localeOf(context).languageCode == 'fa';

  @override
  void initState() {
    super.initState();
    _category = switch (widget.initialFormat.toLowerCase()) {
      'docx' || 'word' => 'Word',
      'xlsx' || 'xls' || 'excel' => 'Excel',
      'pptx' || 'powerpoint' || 'ppt' => 'PowerPoint',
      'pdf' => 'PDF',
      _ => 'All',
    };
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<_HelpArticle> _articles() {
    if (_fa) {
      return const [
        _HelpArticle('عمومی', 'ذخیره‌سازی امن و جلوگیری از ازدست‌رفتن تغییرات', 'بعد از ویرایش، از دکمهٔ ذخیره استفاده کنید و فایل خروجی را دوباره باز کنید.', [
          'برای فایل مهم، نسخهٔ اصلی را نگه دارید و روی یک کپی کار کنید.',
          'تا قبل از پایان ذخیره‌سازی، برنامه را نبندید.',
          'برای مطمئن‌شدن از نتیجه، فایل ذخیره‌شده را دوباره باز کنید.'
        ]),
        _HelpArticle('عمومی', 'کار آفلاین و حریم خصوصی', 'ویرایشگرهای داخلی DOCX، XLSX و PPTX فایل را روی همین دستگاه پردازش می‌کنند.', [
          'برای ویرایش معمولی نیازی به حساب کاربری یا آپلود سند نیست.',
          'فایل فقط زمانی از دستگاه خارج می‌شود که خودتان آن را به اشتراک بگذارید یا در مقصد دیگری ذخیره کنید.',
          'قابلیت‌های بسیار خاص یا افزونه‌های اختصاصی آفیس ممکن است دقیقاً یکسان نمایش داده نشوند.'
        ]),
        _HelpArticle('Word', 'قالب‌بندی متن و پاراگراف', 'برای تغییر ظاهر، ابتدا متن را انتخاب کنید؛ سپس از نوار Home فونت، اندازه، رنگ و سبک را اعمال کنید.', [
          'برای متن برجسته از Bold، برای تأکید از Italic و برای زیرخط از Underline استفاده کنید.',
          'از سبک‌های Heading 1 و Heading 2 برای عنوان‌ها استفاده کنید؛ متن عادی را با اندازهٔ فونت دستی به‌جای عنوان قالب‌بندی نکنید.',
          'از گزینه‌های چپ‌چین، وسط‌چین، راست‌چین و Justify متناسب با نوع متن استفاده کنید.'
        ]),
        _HelpArticle('Word', 'فهرست مطالب، جدول و شکست صفحه', 'ساختاردهی با سبک‌های عنوان، ویرایش سندهای بلند را بسیار آسان‌تر می‌کند.', [
          'ابتدا عنوان‌های فصل را با Heading 1/2 قالب‌بندی کنید.',
          'از Insert برای درج جدول، پیوند، پاورقی و شکست صفحه استفاده کنید.',
          'بعد از تغییر عنوان‌ها، فهرست مطالب را بازبینی یا به‌روزرسانی کنید.'
        ]),
        _HelpArticle('Word', 'جست‌وجو، جایگزینی و بازبینی', 'برای اصلاح تکرارها، Find and replace از ویرایش دستی سریع‌تر و کم‌خطاتر است.', [
          'از Find برای پیدا کردن یک عبارت و از Replace برای جایگزینی کنترل‌شده استفاده کنید.',
          'برای نظر بازبینی، متن مورد نظر را انتخاب و از Insert/Review گزینهٔ Comment را اجرا کنید.',
          'قبل از تحویل سند، یک بار از ابتدا تا انتها صفحه‌ها، پیوندها و جدول‌ها را بررسی کنید.'
        ]),
        _HelpArticle('Word', 'صفحه‌آرایی و زبان فارسی', 'اندازهٔ کاغذ و جهت صفحه، شکل خروجی چاپ و PDF را تغییر می‌دهند.', [
          'برای گزارش معمولی A4 و برای سند افقیِ جدول‌محور Landscape را انتخاب کنید.',
          'برای فارسی یا عربی، جهت متن و تراز پاراگراف را بررسی کنید؛ جهت رابط کاربری لزوماً جهت همهٔ پاراگراف‌ها را تغییر نمی‌دهد.',
          'بعد از تغییر صفحه‌آرایی، خروجی PDF بگیرید و شکست صفحه‌ها را بازبینی کنید.'
        ]),
        _HelpArticle('Excel', 'فرمول‌نویسی پایه', 'فرمول در Excel با علامت = شروع می‌شود و می‌تواند به سلول‌های دیگر ارجاع دهد.', [
          'جمع: =SUM(B2:B20)',
          'میانگین: =AVERAGE(B2:B20) و شمارش اعداد: =COUNT(B2:B20)',
          'شرط ساده: =IF(B2>=10,"قبول","نیاز به بررسی")',
          'پس از ویرایش داده‌ها، Recalculate را اجرا کنید اگر نتیجه فوراً به‌روز نشد.'
        ]),
        _HelpArticle('Excel', 'نوار فرمول، سلول و قالب عددی', 'روی سلول بزنید تا نشانی و مقدار آن در نوار فرمول نمایش داده شود.', [
          'با دوبار لمس/کلیک، سلول را ویرایش کنید؛ برای فرمول، خود فرمول را در نوار فرمول وارد کنید.',
          'برای تاریخ، درصد و پول، قالب عددی را تغییر دهید؛ تبدیل قالب، مقدار واقعی سلول را عوض نمی‌کند.',
          'برای خواندن جدول بزرگ، ردیف اول یا ستون شناسه را Freeze کنید.'
        ]),
        _HelpArticle('Excel', 'شیت‌ها، نمودار و فیلتر', 'دادهٔ تمیز، نمودار و فیلتر قابل‌اعتمادتر می‌سازد.', [
          'در هر ستون یک نوع داده نگه دارید و در ردیف اول عنوان ستون‌ها را قرار دهید.',
          'برای جداکردن داده‌ها از شیت‌های مستقل استفاده کنید.',
          'قبل از ساخت نمودار، محدودهٔ داده و عنوان‌ها را بررسی کنید؛ سپس نمودار و فیلتر را اعمال کنید.'
        ]),
        _HelpArticle('PowerPoint', 'ساخت اسلاید قابل‌ارائه', 'اسلاید خوب، یک پیام اصلی دارد و متن آن کوتاه و خواناست.', [
          'برای جابه‌جایی، تغییر اندازه و چرخاندن اشیا، ابتدا شیء را انتخاب کنید و از دستگیره‌ها استفاده کنید.',
          'برای جدول از Insert table و برای ترتیب اشیا از کنترل‌های ترتیب/لایه استفاده کنید.',
          'یادداشت سخنران را برای توضیحات خودتان نگه دارید؛ آن را با متن قابل مشاهده برای مخاطب اشتباه نگیرید.'
        ]),
        _HelpArticle('PowerPoint', 'ترنزیشن بین اسلایدها', 'Transition افکت تعویض یک اسلاید با اسلاید بعدی است؛ روی خود شیء اجرا نمی‌شود.', [
          'از تب Transitions نوع افکت، جهت و مدت را انتخاب کنید.',
          'با Preview نتیجه را ببینید؛ مدت کوتاه معمولاً برای ارائه رسمی مناسب‌تر است.',
          'Apply to all را فقط وقتی بزنید که می‌خواهید همهٔ اسلایدها افکت یکسان داشته باشند.',
          'Advance after باعث تعویض خودکار اسلاید پس از زمان تعیین‌شده می‌شود؛ در غیر این صورت با کلیک/کلید بعدی جلو بروید.'
        ]),
        _HelpArticle('PowerPoint', 'انیمیشن اشیا', 'Animation حرکت یا ظاهرشدن یک متن/تصویر داخل همان اسلاید است.', [
          'ابتدا شیء را انتخاب کنید و بعد از تب Animations یک افکت اضافه کنید.',
          'از On click، With previous یا After previous برای کنترل شروع استفاده کنید.',
          'Duration سرعت و Delay زمان انتظار قبل از شروع را تعیین می‌کند.',
          'برای پیشگیری از شلوغی، چند افکت هدفمند بهتر از انیمیشن‌دادن به همه‌چیز است.'
        ]),
        _HelpArticle('PDF', 'رمزگذاری و حذف رمز PDF', 'ابزار امنیت PDF رمز عبور را روی فایل خروجی اعمال می‌کند یا پس از ورود رمز فعلی آن را برمی‌دارد.', [
          'Protect: یک رمز طولانی و غیرقابل حدس انتخاب کنید و نسخهٔ رمزدار را در محل امن ذخیره کنید.',
          'Remove password: رمز فعلی لازم است؛ این ابزار برای دور زدن رمز فایل‌های دیگران نیست.',
          'Change password: ابتدا رمز فعلی را وارد کنید و سپس رمز جدید را دوبار تأیید کنید.',
          'اگر رمز را فراموش کنید، ممکن است امکان بازیابی فایل وجود نداشته باشد.'
        ]),
        _HelpArticle('PDF', 'حاشیه‌نویسی و خروجی PDF', 'نسخهٔ PDF را بعد از حاشیه‌نویسی ذخیره کنید و سپس در صورت نیاز رمزگذاری کنید.', [
          'برای محافظت از آخرین تغییرات، ابتدا خروجی ویرایشگر PDF را ذخیره کنید.',
          'بعد از رمزگذاری یا حذف رمز، فایل خروجی جدیدی ساخته می‌شود؛ فایل اصلی بدون تأیید شما بازنویسی نمی‌شود.',
          'پس از ذخیره، PDF را دوباره باز کنید و رمز عبور را آزمایش کنید.'
        ]),
        _HelpArticle('عمومی', 'میانبرهای مفید در کیبورد', 'وقتی کیبورد فیزیکی متصل است، میانبرهای متداول ویرایش کار را سریع می‌کنند.', [
          'Ctrl+S: ذخیره یا خروجی گرفتن؛ Ctrl+Z: بازگشت؛ Ctrl+Y: انجام دوباره.',
          'Ctrl+F: جست‌وجو؛ Ctrl+H: جست‌وجو و جایگزینی؛ Ctrl+A: انتخاب همه.',
          'در دستگاه‌های لمسی، دکمه‌های نوار ابزار و منوها جایگزین میانبرها هستند.'
        ]),
      ];
    }
    return const [
      _HelpArticle('General', 'Save safely and avoid losing changes', 'Use Save/Download after editing, then reopen the saved output to verify it.', [
        'Keep a copy of important originals and work on a duplicate when possible.',
        'Do not close the app while the save indicator is active.',
        'Reopen the output and verify page breaks, formulas, slide objects, and links.'
      ]),
      _HelpArticle('General', 'Offline editing and privacy', 'The built-in DOCX, XLSX, and PPTX editors process document bytes locally on this device.', [
        'Normal editing does not require an account, server, or document upload.',
        'A file leaves the device only when you intentionally share it or save it to another destination.',
        'Rare vendor-specific extensions, macros, and advanced Office features may not round-trip identically.'
      ]),
      _HelpArticle('Word', 'Format text and paragraphs', 'Select text first, then use Home to change fonts, size, color, and style.', [
        'Use Bold for emphasis, Italic for subtle emphasis, and Underline for underlined text.',
        'Use Heading 1/2 styles for headings rather than merely increasing font size.',
        'Use left, center, right, or justified alignment to match the type of content.'
      ]),
      _HelpArticle('Word', 'Table of contents, tables, and page breaks', 'Consistent heading styles make longer documents easier to maintain.', [
        'Apply Heading 1/2 to chapter and section titles before adding a table of contents.',
        'Use Insert for tables, hyperlinks, footnotes, and page breaks.',
        'After renaming or moving headings, review the table of contents and page numbering.'
      ]),
      _HelpArticle('Word', 'Find, replace, and review comments', 'Find and replace is faster and safer than manually changing repeated text.', [
        'Use Find to locate a phrase and Replace to make controlled substitutions.',
        'Select the relevant text before adding a review comment.',
        'Before sharing the document, review page breaks, links, tables, and comments from start to finish.'
      ]),
      _HelpArticle('Word', 'Page layout and right-to-left text', 'Paper size and orientation affect printing and PDF layout.', [
        'A4 works for most reports; Landscape is useful for wide tables.',
        'For Persian or Arabic, verify paragraph direction and alignment separately from the app interface direction.',
        'Export a PDF after layout changes and inspect page breaks before printing.'
      ]),
      _HelpArticle('Excel', 'Formula basics', 'Excel formulas start with = and can refer to other cells.', [
        'Sum: =SUM(B2:B20)',
        'Average: =AVERAGE(B2:B20); count numeric cells: =COUNT(B2:B20)',
        'Simple condition: =IF(B2>=10,"Pass","Review")',
        'Run Recalculate if a result does not update immediately after edits.'
      ]),
      _HelpArticle('Excel', 'Formula bar, cells, and number formats', 'Select a cell to show its address and current value in the formula bar.', [
        'Double-tap or double-click a cell to edit it; type formulas in the formula bar.',
        'Apply date, percentage, or currency formats without confusing the display format with the underlying value.',
        'Freeze the top row or an identifier column when navigating a large sheet.'
      ]),
      _HelpArticle('Excel', 'Worksheets, charts, and filters', 'Clean data makes charts and filters more reliable.', [
        'Keep one data type per column and use the first row for column headings.',
        'Use separate worksheets for independent tables or stages of work.',
        'Check the selected data range before inserting a chart, then review its labels and series.'
      ]),
      _HelpArticle('PowerPoint', 'Build presentation-ready slides', 'Each slide should communicate one main idea with concise, readable text.', [
        'Select an object and use its handles to move, resize, or rotate it.',
        'Use Insert table for structured data and z-order controls to arrange overlapping objects.',
        'Keep speaker notes for the presenter; they are not the same as text shown to the audience.'
      ]),
      _HelpArticle('PowerPoint', 'Slide transitions', 'A transition is the effect between slides, not the effect on an object.', [
        'Use the Transitions tab to choose the effect, direction, and duration.',
        'Preview each effect; shorter transitions are often better for professional presentations.',
        'Use Apply to all only when the entire deck should share the same transition.',
        'Advance after schedules automatic slide changes; otherwise advance manually with a click or key.'
      ]),
      _HelpArticle('PowerPoint', 'Animate individual objects', 'Animations control how text or pictures enter, emphasize, move, or exit within a slide.', [
        'Select an object first, then add an effect from the Animations tab.',
        'Choose On click, With previous, or After previous to control when an animation starts.',
        'Duration controls speed; Delay controls how long to wait before starting.',
        'A few intentional effects are clearer than animating every object.'
      ]),
      _HelpArticle('PDF', 'Protect, remove, or change a PDF password', 'The security tools apply password encryption to the output or remove it after the current password is supplied.', [
        'Protect: use a long, hard-to-guess password and keep it in a safe place.',
        'Remove password requires the current password; it does not bypass protection on someone else’s file.',
        'Change password requires the current password and confirmation of the new password.',
        'If you forget the password, recovery may not be possible.'
      ]),
      _HelpArticle('PDF', 'PDF annotations and secure output', 'Save PDF annotations first, then apply password protection if needed.', [
        'Save the PDF editor output before switching to security operations so your latest annotations are included.',
        'Protect/remove/change creates a new output file; the source is not overwritten automatically.',
        'Reopen the saved PDF and test the password before sharing it.'
      ]),
      _HelpArticle('General', 'Useful keyboard shortcuts', 'With a physical keyboard, common shortcuts speed up editing.', [
        'Ctrl+S: save/export; Ctrl+Z: undo; Ctrl+Y: redo.',
        'Ctrl+F: find; Ctrl+H: find and replace; Ctrl+A: select all.',
        'On touch devices, use the toolbar and menus when keyboard shortcuts are unavailable.'
      ]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final articles = _articles().where((article) {
      final articleCategory = article.category == 'عمومی' ? 'General' : article.category;
      final selectedCategory = _category == 'عمومی' ? 'General' : _category;
      final categoryMatch = selectedCategory == 'All' || articleCategory == selectedCategory;
      final query = _search.text.trim().toLowerCase();
      return categoryMatch && (query.isEmpty ||
          article.title.toLowerCase().contains(query) ||
          article.summary.toLowerCase().contains(query) ||
          article.steps.any((step) => step.toLowerCase().contains(query)));
    }).toList();
    final categories = _fa
        ? const [('All', 'همه'), ('Word', 'ورد'), ('Excel', 'اکسل'), ('PowerPoint', 'پاورپوینت'), ('PDF', 'PDF'), ('عمومی', 'عمومی')]
        : const [('All', 'All'), ('Word', 'Word'), ('Excel', 'Excel'), ('PowerPoint', 'PowerPoint'), ('PDF', 'PDF'), ('General', 'General')];

    return Scaffold(
      appBar: AppBar(
        title: Text(_fa ? 'راهنمای Parin Office' : 'Parin Office Help Center'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: _fa ? 'جست‌وجوی قابلیت یا مشکل…' : 'Search a feature or problem…',
                suffixIcon: _search.text.isEmpty ? null : IconButton(
                  onPressed: () { _search.clear(); setState(() {}); },
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 46,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              children: [
                for (final category in categories)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 7),
                    child: ChoiceChip(
                      label: Text(category.$2),
                      selected: _category == category.$1,
                      onSelected: (_) => setState(() => _category = category.$1),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: articles.isEmpty
                ? Center(child: Text(_fa ? 'موردی پیدا نشد.' : 'No matching guide was found.'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                    itemCount: articles.length,
                    itemBuilder: (context, index) {
                      final article = articles[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primary.withAlpha(20),
                            child: Icon(_iconFor(article.category), color: Theme.of(context).colorScheme.primary),
                          ),
                          title: Text(article.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(article.summary),
                          childrenPadding: const EdgeInsetsDirectional.fromSTEB(18, 0, 18, 18),
                          children: [
                            for (var i = 0; i < article.steps.length; i++)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 24, height: 24,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.secondaryContainer,
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Text((i + 1).toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text(article.steps[i])),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String category) => switch (category) {
        'Word' => Icons.description_outlined,
        'Excel' => Icons.grid_on_rounded,
        'PowerPoint' => Icons.slideshow_outlined,
        'PDF' => Icons.picture_as_pdf_outlined,
        _ => Icons.lightbulb_outline_rounded,
      };
}

class _HelpArticle {
  const _HelpArticle(this.category, this.title, this.summary, this.steps);

  final String category;
  final String title;
  final String summary;
  final List<String> steps;
}

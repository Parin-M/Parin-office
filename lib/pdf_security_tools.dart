import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

enum _SecurityAction { protect, remove, change }

class PdfSecurityToolsPage extends StatefulWidget {
  const PdfSecurityToolsPage({
    super.key,
    required this.bytes,
    required this.fileName,
  });

  final Uint8List bytes;
  final String fileName;

  @override
  State<PdfSecurityToolsPage> createState() => _PdfSecurityToolsPageState();
}

class _PdfSecurityToolsPageState extends State<PdfSecurityToolsPage> {
  bool _working = false;
  bool get _fa => Localizations.localeOf(context).languageCode == 'fa';

  Future<void> _start(_SecurityAction action) async {
    if (_working) return;
    final current = TextEditingController();
    final password = TextEditingController();
    final confirm = TextEditingController();
    final owner = TextEditingController();
    bool obscure = true;
    String? validation;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, refresh) => AlertDialog(
          title: Text(_title(action)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (action != _SecurityAction.protect)
                  TextField(
                    controller: current,
                    autofocus: true,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: _fa ? 'رمز فعلی PDF' : 'Current PDF password',
                      prefixIcon: const Icon(Icons.key_rounded),
                      suffixIcon: IconButton(
                        onPressed: () => refresh(() => obscure = !obscure),
                        icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      ),
                    ),
                  ),
                if (action != _SecurityAction.remove) ...[
                  if (action != _SecurityAction.protect) const SizedBox(height: 12),
                  TextField(
                    controller: password,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: _fa ? 'رمز جدید' : 'New password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirm,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: _fa ? 'تکرار رمز جدید' : 'Confirm new password',
                      prefixIcon: const Icon(Icons.verified_user_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: owner,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: _fa ? 'رمز مالک (اختیاری)' : 'Owner password (optional)',
                      helperText: _fa ? 'در صورت خالی‌بودن، از رمز جدید استفاده می‌شود.' : 'If blank, the new password is also used as the owner password.',
                      prefixIcon: const Icon(Icons.admin_panel_settings_outlined),
                    ),
                  ),
                ],
                if (validation != null) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(validation!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  _fa
                    ? 'یک نسخهٔ خروجی جدید ساخته می‌شود؛ فایل اصلی خودکار بازنویسی نمی‌شود.'
                    : 'A separate output file is created. The original is not overwritten automatically.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(_fa ? 'انصراف' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (action != _SecurityAction.protect && current.text.isEmpty) {
                  refresh(() => validation = _fa ? 'رمز فعلی را وارد کنید.' : 'Enter the current password.');
                  return;
                }
                if (action != _SecurityAction.remove) {
                  if (password.text.length < 6) {
                    refresh(() => validation = _fa ? 'رمز جدید باید حداقل ۶ نویسه داشته باشد.' : 'Use at least 6 characters for the new password.');
                    return;
                  }
                  if (password.text != confirm.text) {
                    refresh(() => validation = _fa ? 'تکرار رمز با رمز جدید یکسان نیست.' : 'The new passwords do not match.');
                    return;
                  }
                }
                Navigator.pop(dialogContext, true);
              },
              child: Text(_fa ? 'ادامه' : 'Continue'),
            ),
          ],
        ),
      ),
    );

    if (accepted != true || !mounted) {
      current.dispose();
      password.dispose();
      confirm.dispose();
      owner.dispose();
      return;
    }

    setState(() => _working = true);
    try {
      final PdfDocument document;
      if (action == _SecurityAction.protect) {
        document = PdfDocument(inputBytes: widget.bytes);
      } else {
        document = PdfDocument(inputBytes: widget.bytes, password: current.text);
      }
      late final Uint8List output;
      try {
        final security = document.security;
        if (action == _SecurityAction.remove) {
          security.userPassword = '';
          security.ownerPassword = '';
        } else {
          security.userPassword = password.text;
          security.ownerPassword = owner.text.trim().isEmpty ? password.text : owner.text;
          security.algorithm = PdfEncryptionAlgorithm.aesx256Bit;
        }
        output = Uint8List.fromList(await document.save());
      } finally {
        document.dispose();
      }

      final base = widget.fileName.replaceFirst(RegExp(r'\.pdf$', caseSensitive: false), '');
      final suffix = switch (action) {
        _SecurityAction.protect => _fa ? '-رمزدار' : '-protected',
        _SecurityAction.remove => _fa ? '-بدون-رمز' : '-unlocked',
        _SecurityAction.change => _fa ? '-رمز-جدید' : '-password-changed',
      };
      final savedPath = await FilePicker.saveFile(
        fileName: base + suffix + '.pdf',
        bytes: output,
        mimeType: 'application/pdf',
        dialogTitle: _title(action),
      );
      if (mounted && savedPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_fa ? 'فایل امنیتی جدید ذخیره شد.' : 'The secured PDF output was saved.')),
        );
      }
    } catch (error) {
      if (mounted) {
        final message = error.toString().toLowerCase().contains('password') ||
                error.toString().toLowerCase().contains('encrypt')
            ? (_fa ? 'بازکردن فایل ناموفق بود؛ رمز فعلی را بررسی کنید.' : 'Could not open the PDF. Check the current password.')
            : (_fa ? 'عملیات امنیت PDF انجام نشد: ' : 'PDF security operation failed: ') + error.toString();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      current.dispose();
      password.dispose();
      confirm.dispose();
      owner.dispose();
      if (mounted) setState(() => _working = false);
    }
  }

  String _title(_SecurityAction action) => switch (action) {
    _SecurityAction.protect => _fa ? 'رمزگذاری PDF' : 'Protect PDF',
    _SecurityAction.remove => _fa ? 'حذف رمز PDF' : 'Remove PDF password',
    _SecurityAction.change => _fa ? 'تغییر رمز PDF' : 'Change PDF password',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actions = <(_SecurityAction, IconData, String, String)>[
      (_SecurityAction.protect, Icons.lock_outline_rounded,
        _fa ? 'ساخت رمز برای PDF' : 'Create a PDF password',
        _fa ? 'رمزگذاری AES-256 و ایجاد یک نسخهٔ محافظت‌شده.' : 'Apply AES-256 encryption and create a protected copy.'),
      (_SecurityAction.remove, Icons.lock_open_rounded,
        _fa ? 'حذف رمز PDF' : 'Remove a PDF password',
        _fa ? 'با واردکردن رمز معتبر، یک نسخهٔ بدون رمز بسازید.' : 'Enter the valid password to create an unlocked copy.'),
      (_SecurityAction.change, Icons.password_rounded,
        _fa ? 'تغییر رمز PDF' : 'Change a PDF password',
        _fa ? 'رمز فعلی را تأیید و رمز جدید را تنظیم کنید.' : 'Verify the current password and set a new one.'),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(_fa ? 'امنیت PDF' : 'PDF security')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withAlpha(18),
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, color: theme.colorScheme.primary, size: 27),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _fa
                      ? 'این ابزار کاملاً آفلاین است. رمز فراموش‌شده قابل بازیابی تضمینی نیست؛ رمز را در محل امن نگه دارید.'
                      : 'This tool works offline. A forgotten password may not be recoverable; store it securely.',
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(widget.fileName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          for (final action in actions)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(action.$2, color: theme.colorScheme.primary),
                ),
                title: Text(action.$3, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(action.$4),
                ),
                trailing: _working
                  ? const SizedBox(width: 19, height: 19, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.chevron_right_rounded),
                onTap: _working ? null : () => _start(action.$1),
              ),
            ),
          const SizedBox(height: 6),
          Text(
            _fa
              ? 'نکته: اگر روی PDF حاشیه‌نویسی کرده‌اید، ابتدا آن را در ویرایشگر PDF ذخیره کنید و سپس نسخهٔ ذخیره‌شده را برای عملیات رمزگذاری باز کنید.'
              : 'Tip: save PDF annotations first. Then open the saved copy here for password operations so the latest changes are included.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.45),
          ),
        ],
      ),
    );
  }
}

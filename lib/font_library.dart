import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserFontFamily {
  const UserFontFamily({
    required this.family,
    required this.fileName,
    required this.path,
  });

  final String family;
  final String fileName;
  final String path;

  Map<String, Object?> toJson() => {
        'family': family,
        'fileName': fileName,
        'path': path,
      };

  factory UserFontFamily.fromJson(Map<String, dynamic> json) => UserFontFamily(
        family: json['family'] as String? ?? 'ParinCustomFont',
        fileName: json['fileName'] as String? ?? 'font.ttf',
        path: json['path'] as String? ?? '',
      );
}

/// User-selected TTF/OTF files are copied into app-private storage and loaded
/// by Flutter. No font files are uploaded or sent to third-party services.
class UserFontLibrary {
  UserFontLibrary._();

  static const String _storageKey = 'parinOfficeUserFonts';
  static final Set<String> _registeredPaths = <String>{};

  static Future<List<UserFontFamily>> list() async {
    final preferences = await SharedPreferences.getInstance();
    final entries = preferences.getStringList(_storageKey) ?? <String>[];
    final fonts = <UserFontFamily>[];
    for (final entry in entries) {
      try {
        final value = jsonDecode(entry);
        if (value is Map<String, dynamic>) {
          final font = UserFontFamily.fromJson(value);
          if (font.path.isNotEmpty && await File(font.path).exists()) fonts.add(font);
        }
      } catch (_) {
        // Skip malformed entries and continue loading usable fonts.
      }
    }
    return fonts;
  }

  static Future<List<String>> families() async =>
      (await list()).map((font) => font.family).toList(growable: false);

  static Future<void> registerSavedFonts() async {
    for (final font in await list()) {
      try {
        await _register(font);
      } catch (_) {
        // A broken or unsupported font should never stop the app from opening.
      }
    }
  }

  static Future<UserFontFamily?> importFromDevice() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['ttf', 'otf'],
      allowMultiple: false,
      withData: true,
    );
    if (picked.isEmpty) return null;
    final selected = picked.files.single;
    final extension = (selected.extension ?? '').toLowerCase();
    if (extension != 'ttf' && extension != 'otf') {
      throw const FormatException('Only TrueType (.ttf) and OpenType (.otf) fonts are supported.');
    }
    final bytes = selected.bytes ?? await selected.readAsBytes();
    if (bytes.length < 256) {
      throw const FormatException('The selected font file is empty or invalid.');
    }

    final name = selected.name.replaceFirst(RegExp(r'\.(ttf|otf)$', caseSensitive: false), '');
    final base = name.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    if (base.isEmpty) {
      throw const FormatException('The font filename must contain letters or numbers.');
    }

    final existing = await list();
    final familyStem = 'Parin_$base';
    var family = familyStem;
    var sequence = 2;
    final used = existing.map((font) => font.family).toSet();
    while (used.contains(family)) {
      family = '${familyStem}_$sequence';
      sequence++;
    }

    final root = await getApplicationSupportDirectory();
    final directory = Directory('${root.path}${Platform.pathSeparator}user_fonts');
    await directory.create(recursive: true);
    final fileName = '$family.$extension';
    final path = '${directory.path}${Platform.pathSeparator}$fileName';
    await File(path).writeAsBytes(bytes, flush: true);

    final font = UserFontFamily(family: family, fileName: selected.name, path: path);
    try {
      await _register(font, bytes: bytes);
      final preferences = await SharedPreferences.getInstance();
      final stored = preferences.getStringList(_storageKey) ?? <String>[];
      stored.add(jsonEncode(font.toJson()));
      await preferences.setStringList(_storageKey, stored);
      return font;
    } catch (_) {
      await File(path).delete().catchError((_) => File(path));
      rethrow;
    }
  }

  static Future<void> remove(UserFontFamily font) async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getStringList(_storageKey) ?? <String>[];
    stored.removeWhere((value) {
      try {
        final decoded = jsonDecode(value);
        return decoded is Map && decoded['path'] == font.path;
      } catch (_) {
        return false;
      }
    });
    await preferences.setStringList(_storageKey, stored);
    // Flutter cannot unload a registered font from the active process; the
    // file is removed from the library and disappears fully after restart.
    final file = File(font.path);
    if (await file.exists()) await file.delete();
  }

  static Future<void> _register(UserFontFamily font, {Uint8List? bytes}) async {
    if (_registeredPaths.contains(font.path)) return;
    final data = bytes ?? await File(font.path).readAsBytes();
    final loader = FontLoader(font.family)
      ..addFont(Future<ByteData>.value(ByteData.sublistView(data)));
    await loader.load();
    _registeredPaths.add(font.path);
  }
}

class FontLibraryPage extends StatefulWidget {
  const FontLibraryPage({super.key});

  @override
  State<FontLibraryPage> createState() => _FontLibraryPageState();
}

class _FontLibraryPageState extends State<FontLibraryPage> {
  List<UserFontFamily> _fonts = <UserFontFamily>[];
  bool _loading = true;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final fonts = await UserFontLibrary.list();
    if (mounted) setState(() {
      _fonts = fonts;
      _loading = false;
    });
  }

  Future<void> _import() async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      final font = await UserFontLibrary.importFromDevice();
      await _reload();
      if (mounted && font != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added ${font.fileName} to your font library.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add font: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _remove(UserFontFamily font) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove custom font?'),
        content: Text(
          'Remove ${font.fileName} from this device’s font library? Text already formatted with this font will keep its font-family name.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (accepted != true) return;
    await UserFontLibrary.remove(font);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Font library')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _importing ? null : _import,
        icon: _importing
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.add_rounded),
        label: Text(_importing ? 'Adding…' : 'Add font'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 92),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withAlpha(18),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.font_download_outlined, size: 28),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Import a .TTF or .OTF font from this device. Fonts stay in app-private storage and are available to the editor after import. Only import fonts that you have permission to use.',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text('Installed custom fonts (${_fonts.length})', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                if (_fonts.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('No custom fonts yet. Use Add font to import a TTF or OTF file.'),
                    ),
                  )
                else
                  for (final font in _fonts)
                    Card(
                      child: ListTile(
                        title: Text(font.fileName, style: TextStyle(fontFamily: font.family, fontWeight: FontWeight.w700)),
                        subtitle: Text(font.family),
                        trailing: IconButton(
                          tooltip: 'Remove font',
                          onPressed: () => _remove(font),
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ),
                    ),
              ],
            ),
    );
  }
}

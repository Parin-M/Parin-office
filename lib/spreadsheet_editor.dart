import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:convert';
import 'package:excel_plus/excel_plus.dart' as xls;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class SpreadsheetEditorPage extends StatefulWidget {
  const SpreadsheetEditorPage({super.key, required this.bytes, required this.fileName});
  final Uint8List bytes;
  final String fileName;
  @override State<SpreadsheetEditorPage> createState() => _SpreadsheetEditorPageState();
}

class _SpreadsheetEditorPageState extends State<SpreadsheetEditorPage> {
  xls.Excel? _workbook;
  String? _error;
  String _sheetName = 'Sheet1';
  int _row = 0, _column = 0;
  bool _saving = false;
  final _formula = TextEditingController();

  xls.Sheet get _sheet => _workbook![_sheetName];
  xls.CellIndex get _selectedIndex => xls.CellIndex.indexByColumnRow(columnIndex: _column, rowIndex: _row);
  String get _selectedAddress => _cellAddress(_row, _column);
  int get _visibleRows => math.min(math.max(_sheet.maxRows + 8, 18), 60);
  int get _visibleColumns => math.min(math.max(_sheet.maxColumns + 3, 10), 14);

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final workbook = widget.bytes.isEmpty ? xls.Excel.createExcel() : await xls.Excel.decodeBytesAsync(widget.bytes);
      if (workbook.tables.isEmpty) workbook['Sheet1'];
      if (!mounted) return;
      setState(() { _workbook = workbook; _sheetName = workbook.tables.keys.first; });
      _syncFormula();
    } catch (error) {
      if (mounted) setState(() => _error = 'This spreadsheet could not be opened: $error');
    }
  }

  @override void dispose() { _formula.dispose(); super.dispose(); }

  String _cellAddress(int row, int col) {
    var n = col + 1;
    var name = '';
    while (n > 0) {
      final remainder = (n - 1) % 26;
      name = String.fromCharCode(65 + remainder) + name;
      n = (n - 1) ~/ 26;
    }
    return '$name${row + 1}';
  }

  String _valueText(dynamic value) {
    if (value == null) return '';
    if (value is xls.TextCellValue) return value.value;
    if (value is xls.IntCellValue) return value.value.toString();
    if (value is xls.DoubleCellValue) return value.value.toString();
    if (value is xls.BoolCellValue) return value.value.toString();
    if (value is xls.FormulaCellValue) return '=${value.formula}';
    if (value is xls.DateCellValue) return value.year.toString().padLeft(4, '0') + '-' + value.month.toString().padLeft(2, '0') + '-' + value.day.toString().padLeft(2, '0');
    if (value is xls.TimeCellValue) return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    return value.toString();
  }

  void _syncFormula() {
    if (_workbook == null) return;
    _formula.text = _valueText(_sheet.cell(_selectedIndex).value);
  }

  void _select(int row, int column) {
    setState(() { _row = row; _column = column; });
    _syncFormula();
  }

  void _writeValue(String input, {bool notify = true}) {
    final value = input.trim();
    late final xls.CellValue cellValue;
    if (value.startsWith('=')) {
      cellValue = xls.FormulaCellValue(value.substring(1));
    } else if (value.toLowerCase() == 'true' || value.toLowerCase() == 'false') {
      cellValue = xls.BoolCellValue(value.toLowerCase() == 'true');
    } else if (RegExp(r'^-?\d+$').hasMatch(value)) {
      cellValue = xls.IntCellValue(int.parse(value));
    } else if (RegExp(r'^-?(?:\d+\.\d*|\d*\.\d+)$').hasMatch(value)) {
      cellValue = xls.DoubleCellValue(double.parse(value));
    } else {
      cellValue = xls.TextCellValue(input);
    }
    _sheet.updateCell(_selectedIndex, cellValue);
    if (value.startsWith('=')) _workbook!.recalculate(changed: [_selectedAddress]);
    if (notify && mounted) setState(() {});
  }

  Future<void> _editCell() async {
    final controller = TextEditingController(text: _valueText(_sheet.cell(_selectedIndex).value));
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit $_selectedAddress'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'Value or =SUM(A1:A5)'), onSubmitted: (v) => Navigator.pop(ctx, v)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Apply')),
        ],
      ),
    );
    if (result != null) { _formula.text = result; _writeValue(result); }
    controller.dispose();
  }

  Future<void> _save() async {
    if (_workbook == null || _saving) return;
    setState(() => _saving = true);
    try {
      _workbook!.recalculate();
      final bytes = _workbook!.save();
      if (bytes == null) throw StateError('Workbook encoding returned no data.');
      final base = widget.fileName.replaceAll(RegExp(r'\.(xlsx?|XLSX?)$'), '');
      final outputName = '${_safeName(base, 'Workbook')}.xlsx';
      final path = await FilePicker.saveFile(fileName: outputName, bytes: Uint8List.fromList(bytes),
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', dialogTitle: 'Save Excel workbook');
      if (mounted && path != null) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Workbook saved.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save workbook: $error')));
    } finally { if (mounted) setState(() => _saving = false); }
  }

  void _addSheet() {
    final name = 'Sheet${_workbook!.tables.length + 1}';
    _workbook![name];
    setState(() => _sheetName = name);
    _select(0, 0);
  }
  void _addRow() { _sheet.insertRow(_sheet.maxRows + 1); setState(() {}); }
  void _addColumn() { _sheet.insertColumn(_sheet.maxColumns + 1); setState(() {}); }

  Future<void> _findReplace() async {
    final find = TextEditingController(), replace = TextEditingController();
    final apply = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Find and replace'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: find, decoration: const InputDecoration(labelText: 'Find')),
          TextField(controller: replace, decoration: const InputDecoration(labelText: 'Replace with')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Replace all')),
        ],
      ),
    );
    if (apply == true && find.text.isNotEmpty) { _workbook!.findAndReplace(_sheetName, find.text, replace.text); setState(() {}); }
    find.dispose();
    replace.dispose();
  }

  void _styleSelected({bool? bold, String? fill}) {
    final cell = _sheet.cell(_selectedIndex);
    final previous = cell.cellStyle ?? xls.CellStyle();
    cell.cellStyle = previous.copyWith(
      boldVal: bold ?? previous.bold,
      backgroundColorHexVal: fill == null ? null : xls.ExcelColor.fromHexString(fill),
    );
    setState(() {});
  }

  Future<void> _insertChart() async {
    if (_sheet.maxRows < 2 || _sheet.maxColumns < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add category labels in column A and values in column B first.')));
      return;
    }
    try {
      final lastRow = math.max(2, _sheet.maxRows);
      _sheet.addChart(xls.Chart.column(
        anchor: xls.CellIndex.indexByString(_cellAddress(0, _visibleColumns + 1)),
        title: 'Worksheet chart',
        categories: 'A2:A$lastRow',
        series: [xls.ChartSeries(name: 'Values', values: 'B2:B$lastRow')],
      ));
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Column chart added to the workbook.')));
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not add chart: $error')));
    }
  }

  Future<void> _exportCsv() async {
    await FilePicker.saveFile(fileName: '$_sheetName.csv',
      bytes: Uint8List.fromList(utf8.encode(_sheet.toCsv())), mimeType: 'text/csv', dialogTitle: 'Export active sheet as CSV');
  }

  void _menuAction(String action) {
    switch (action) {
      case 'row': _addRow(); break;
      case 'column': _addColumn(); break;
      case 'sheet': _addSheet(); break;
      case 'freeze': _sheet.freezePanes(rows: 1, columns: 1); setState(() {}); break;
      case 'filter':
        if (_sheet.maxRows > 1 && _sheet.maxColumns > 0) {
          _sheet.setAutoFilter(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
            xls.CellIndex.indexByColumnRow(columnIndex: math.min(_sheet.maxColumns - 1, _visibleColumns - 1), rowIndex: _sheet.maxRows - 1));
        }
        setState(() {});
        break;
      case 'chart': _insertChart(); break;
      case 'csv': _exportCsv(); break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_error != null) return Scaffold(appBar: AppBar(title: const Text('Excel')), body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!))));
    if (_workbook == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final names = _workbook!.tables.keys.toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(tooltip: 'Find and replace', onPressed: _findReplace, icon: const Icon(Icons.find_replace)),
          PopupMenuButton<String>(
            tooltip: 'Worksheet actions',
            onSelected: _menuAction,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'row', child: Text('Insert row')),
              PopupMenuItem(value: 'column', child: Text('Insert column')),
              PopupMenuItem(value: 'sheet', child: Text('Add worksheet')),
              PopupMenuItem(value: 'freeze', child: Text('Freeze first row and column')),
              PopupMenuItem(value: 'filter', child: Text('Enable autofilter')),
              PopupMenuItem(value: 'chart', child: Text('Insert column chart')),
              PopupMenuItem(value: 'csv', child: Text('Export active sheet as CSV')),
            ],
          ),
          IconButton(tooltip: 'Save workbook', onPressed: _saving ? null : _save,
            icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined)),
        ],
      ),
      body: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
          color: theme.colorScheme.surface,
          child: Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(11)),
              child: Text(_selectedAddress, style: const TextStyle(fontWeight: FontWeight.w800))),
            const SizedBox(width: 10),
            const Icon(Icons.functions, size: 19),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _formula, onSubmitted: _writeValue,
              decoration: const InputDecoration(hintText: 'Value or formula, e.g. =SUM(A1:A5)', isDense: true, border: InputBorder.none, filled: false))),
            IconButton(tooltip: 'Apply cell value', onPressed: () => _writeValue(_formula.text), icon: const Icon(Icons.check_circle_outline)),
          ]),
        ),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          IconButton(tooltip: 'Bold selected cell', onPressed: () => _styleSelected(bold: !(_sheet.cell(_selectedIndex).cellStyle?.bold ?? false)), icon: const Icon(Icons.format_bold)),
          IconButton(tooltip: 'Highlight selected cell', onPressed: () => _styleSelected(fill: '#FFF2CC'), icon: const Icon(Icons.format_color_fill)),
          IconButton(tooltip: 'Header style', onPressed: () => _styleSelected(bold: true, fill: '#DCE8FF'), icon: const Icon(Icons.table_chart_outlined)),
          const SizedBox(width: 8),
          ActionChip(avatar: const Icon(Icons.calculate_outlined, size: 17), label: const Text('Recalculate'), onPressed: () { _workbook!.recalculate(); setState(() {}); }),
          ActionChip(avatar: const Icon(Icons.add_chart_outlined, size: 17), label: const Text('Insert chart'), onPressed: _insertChart),
        ])),
        const Divider(height: 1),
        Expanded(child: SingleChildScrollView(child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            horizontalMargin: 4, columnSpacing: 4, headingRowHeight: 38, dataRowMinHeight: 38, dataRowMaxHeight: 46,
            columns: [
              const DataColumn(label: SizedBox(width: 32, child: Text('#'))),
              for (var col = 0; col < _visibleColumns; col++)
                DataColumn(label: SizedBox(width: 110, child: Text(_cellAddress(0, col).replaceAll(RegExp(r'\d'), ''), style: const TextStyle(fontWeight: FontWeight.w900)))),
            ],
            rows: [
              for (var row = 0; row < _visibleRows; row++)
                DataRow(
                  color: WidgetStateProperty.resolveWith((_) => row == 0 ? theme.colorScheme.primary.withAlpha(18) : null),
                  cells: [
                    DataCell(SizedBox(width: 32, child: Text('${row + 1}', style: theme.textTheme.labelSmall))),
                    for (var col = 0; col < _visibleColumns; col++)
                      DataCell(
                        Container(
                          width: 110, padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
                          decoration: BoxDecoration(
                            color: row == _row && col == _column ? theme.colorScheme.primary.withAlpha(20) : null,
                            border: Border.all(color: row == _row && col == _column ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                              width: row == _row && col == _column ? 1.5 : 0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(_valueText(_sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row)).value),
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                        ),
                        onTap: () => _select(row, col),
                        onDoubleTap: () { _select(row, col); _editCell(); },
                      ),
                  ],
                ),
            ],
          ),
        ))),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          decoration: BoxDecoration(color: theme.colorScheme.surface, border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant))),
          child: Row(children: [
            for (final name in names)
              Padding(padding: const EdgeInsetsDirectional.only(end: 6), child: ChoiceChip(label: Text(name), selected: name == _sheetName, onSelected: (_) {
                setState(() => _sheetName = name);
                _select(0, 0);
              })),
            IconButton(tooltip: 'Add worksheet', onPressed: _addSheet, icon: const Icon(Icons.add_circle_outline)),
            const Spacer(),
            Text('Cell $_selectedAddress', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ]),
        ),
      ]),
    );
  }
}

String _safeName(String value, String fallback) {
  final cleaned = value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();
  return cleaned.isEmpty ? fallback : cleaned;
}

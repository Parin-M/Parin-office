import 'package:flutter_test/flutter_test.dart';
import 'package:parin_office/theme/theme_catalog.dart';
import 'package:parin_office/engine/excel/formula_engine.dart';

void main(){
  test('has at least 100 themes',()=>expect(ThemeCatalog.presets.length,greaterThanOrEqualTo(100)));
  test('formula engine computes expressions',(){
    final result=FormulaEngine(cells:{'A1':const NumberValue(10),'A2':const NumberValue(5)}).evaluate('=SUM(A1,A2)*2');
    expect((result as NumberValue).value,30);
  });
}

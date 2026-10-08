sealed class CellValue { const CellValue(); }
class NumberValue extends CellValue { const NumberValue(this.value); final double value; }
class TextValue extends CellValue { const TextValue(this.value); final String value; }
class ErrorValue extends CellValue { const ErrorValue(this.code); final String code; }
class BlankValue extends CellValue { const BlankValue(); }

class FormulaEngine {
  FormulaEngine({Map<String,CellValue> cells=const {}}):_cells=cells;
  final Map<String,CellValue> _cells;

  CellValue evaluate(String input){
    final value=input.trim();
    final formula=value.startsWith('=')?value.substring(1):value;
    if(formula.isEmpty)return const BlankValue();
    try{return _Parser(formula,_cells).parse();}catch(_){return const ErrorValue('#ERROR!');}
  }
}

class _Parser {
  _Parser(this.source,this.cells);
  final String source; final Map<String,CellValue> cells; int index=0;

  CellValue parse()=>_expression();

  CellValue _expression(){
    var left=_term();
    while(true){
      _spaces();
      if(_match('+')){left=NumberValue(_num(left)+_num(_term()));}
      else if(_match('-')){left=NumberValue(_num(left)-_num(_term()));}
      else{return left;}
    }
  }

  CellValue _term(){
    var left=_factor();
    while(true){
      _spaces();
      if(_match('*')){left=NumberValue(_num(left)*_num(_factor()));}
      else if(_match('/')){
        final divisor=_num(_factor());
        if(divisor==0)return const ErrorValue('#DIV/0!');
        left=NumberValue(_num(left)/divisor);
      } else{return left;}
    }
  }

  CellValue _factor(){
    _spaces();
    if(_match('(')){
      final value=_expression();
      _expect(')');
      return value;
    }
    final start=index;
    if(_isDigit(_peek())||_peek()=='-'||_peek()=='.'){
      if(_peek()=='-'){index++;}
      while(_isDigit(_peek())||_peek()=='.'){index++;}
      return NumberValue(double.parse(source.substring(start,index)));
    }
    while(_isIdentifierChar(_peek())){index++;}
    final token=source.substring(start,index);
    if(token.isEmpty)throw StateError('Expected token');
    _spaces();
    if(_match('(')){
      final args=<CellValue>[];
      _spaces();
      if(!_match(')')){
        while(true){
          args.add(_expression());
          _spaces();
          if(_match(')')){break;}
          _expect(',');
        }
      }
      return _function(token.toUpperCase(),args);
    }
    return cells[token]??const BlankValue();
  }

  CellValue _function(String name,List<CellValue> args){
    final n=args.whereType<NumberValue>().map((e)=>e.value).toList();
    return switch(name){
      'SUM'=>NumberValue(n.fold(0.0,(a,b)=>a+b)),
      'AVERAGE'=>n.isEmpty?const ErrorValue('#DIV/0!'):NumberValue(n.reduce((a,b)=>a+b)/n.length),
      'MIN'=>n.isEmpty?const ErrorValue('#VALUE!'):NumberValue(n.reduce((a,b)=>a<b?a:b)),
      'MAX'=>n.isEmpty?const ErrorValue('#VALUE!'):NumberValue(n.reduce((a,b)=>a>b?a:b)),
      'ABS'=>NumberValue((n.firstOrNull??0).abs()),
      _=>const ErrorValue('#NAME?'),
    };
  }

  double _num(CellValue value){
    if(value is NumberValue)return value.value;
    throw StateError('#VALUE!');
  }

  bool _match(String c){
    if(_peek()==c){index++;return true;}
    return false;
  }

  void _expect(String c){if(!_match(c))throw StateError('Expected '+c);}
  void _spaces(){while(_peek()?.trim().isEmpty==true){index++;}}
  bool _isDigit(String? c)=>c!=null&&c.codeUnitAt(0)>=48&&c.codeUnitAt(0)<=57;
  bool _isIdentifierChar(String? c)=>c!=null&&((c.codeUnitAt(0)>=65&&c.codeUnitAt(0)<=90)||(c.codeUnitAt(0)>=97&&c.codeUnitAt(0)<=122)||_isDigit(c)||c=='_'||c=='$');
  String? _peek()=>index<source.length?source[index]:null;
}

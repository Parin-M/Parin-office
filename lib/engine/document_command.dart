abstract interface class DocumentCommand {
  String get id;
  String get title;
  void apply();
  void undo();
}

class CommandHistory {
  CommandHistory({this.maxDepth=250});
  final int maxDepth;
  final List<DocumentCommand> _undo=[];
  final List<DocumentCommand> _redo=[];
  bool get canUndo=>_undo.isNotEmpty;
  bool get canRedo=>_redo.isNotEmpty;
  void execute(DocumentCommand command){command.apply();_undo.add(command);_redo.clear();if(_undo.length>maxDepth)_undo.removeAt(0);}
  void undo(){if(_undo.isEmpty)return;final c=_undo.removeLast();c.undo();_redo.add(c);}
  void redo(){if(_redo.isEmpty)return;final c=_redo.removeLast();c.apply();_undo.add(c);}
  void clear(){_undo.clear();_redo.clear();}
}

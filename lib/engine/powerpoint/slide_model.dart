import 'dart:ui';

enum SlideObjectType { text, rectangle, ellipse, line, image, group, table, chart }

class SlideObjectModel {
  SlideObjectModel({required this.id,required this.type,required this.bounds,this.text='',this.rotation=0,this.locked=false});
  final String id; final SlideObjectType type; Rect bounds; String text; double rotation; bool locked; int zIndex=0;
  void move(Offset delta){if(!locked)bounds=bounds.shift(delta);}
  void resize(Size size){if(!locked)bounds=Rect.fromLTWH(bounds.left,bounds.top,size.width,size.height);}
}

class SlideDocument {
  SlideDocument({required this.size,this.objects=const []});
  final Size size; final List<SlideObjectModel> objects;
}

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gatepass_lab/api.dart';
import 'package:gatepass_lab/main.dart';
class FakeLabApi extends LabApi {
 final bool paired;
 FakeLabApi({this.paired=true});
 @override Future<void> restore() async {token=paired?'a'*64:null;}
 @override Future<Map<String,dynamic>> request(String action,[Map<String,dynamic> body=const{}])async=>{'employee':{'id':'SIM_EMP001','name':'พนักงานทดสอบ','department':'GATEPASS LAB','active':true,'permission':true,'card':true,'nfc':true,'qr':true,'starts':'00:00:00','ends':'23:59:59'},'events':<dynamic>[],'credentials':<dynamic>[]};
}
void main(){
 testWidgets('LAB card and permissions fit phone screen', (tester)async{
  tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  final font=FontLoader('Gatepass')..addFont(rootBundle.load('assets/fonts/gatepass.ttf'));await font.load();final icons=FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));await icons.load();
  final key=GlobalKey();await tester.pumpWidget(RepaintBoundary(key:key,child:LabApp(home:LabHome(api:FakeLabApi()))));await tester.pumpAndSettle();
  expect(find.text('สแกน QR ที่เครื่องจำลอง'),findsOneWidget);expect(find.text('พนักงานทดสอบ'),findsOneWidget);expect(tester.takeException(),isNull);
  await tester.runAsync(()async{final image=await(key.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage();final bytes=await image.toByteData(format:ui.ImageByteFormat.png);Directory('docs').createSync();File('docs/lab-card-test-fixture.png').writeAsBytesSync(bytes!.buffer.asUint8List());});
  await tester.tap(find.text('สิทธิ์'));await tester.pumpAndSettle();expect(find.text('สิทธิ์ของพนักงานทดสอบ'),findsOneWidget);expect(tester.takeException(),isNull);
  await tester.pumpWidget(const SizedBox());
 });
 testWidgets('Pairing screen is distinct from production login',(tester)async{
  await tester.pumpWidget(LabApp(home:LabHome(api:FakeLabApi(paired:false))));await tester.pumpAndSettle();expect(find.text('สแกน QR จับคู่แอป'),findsOneWidget);expect(find.text('จับคู่ด้วยลิงก์'),findsOneWidget);expect(tester.takeException(),isNull);await tester.pumpWidget(const SizedBox());
 });
}

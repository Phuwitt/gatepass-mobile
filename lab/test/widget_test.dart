import 'package:flutter_test/flutter_test.dart';
import 'package:gatepass_lab/api.dart';
void main(){
 final base=Uri.parse('https://gatepass-lab-phuwitt.vercel.app');
 final token='a'*64;
 test('accepts pairing and door QR only for configured lab',(){
  expect(LabApi.extractQr('${base.origin}/join?pair=$token',base,pairing:true),token);
  expect(LabApi.extractQr('${base.origin}/phone?token=$token',base,pairing:false),token);
 });
 test('rejects production QR, wrong path, invalid token, insecure and credential-bearing URLs',(){
  for(final raw in ['https://gatepass-prototype.vercel.app/phone?token=$token','${base.origin}/join?pair=$token','${base.origin}/phone?token=short','http://${base.host}/phone?token=$token','https://user@${base.host}/phone?token=$token']){
   expect(()=>LabApi.extractQr(raw,base,pairing:false),throwsA(isA<LabFailure>()));
  }
 });
}

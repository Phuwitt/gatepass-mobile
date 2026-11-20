# GATEPASS Mobile

โครงงาน CPE23267 · ชุดส่งซอร์ส 20 พฤศจิกายน 2569

| โฟลเดอร์ | แอป | Android package |
|---|---|---|
| `employee/` | GATEPASS ตัวใช้งานจริง ซอร์สรุ่น 0.6.0 | `com.gotoradiant.gatepass_employee` |
| `lab/` | GATEPASS LAB แอปทดลองรุ่น 1.0.0 | `com.gotoradiant.gatepass_lab` |

สองแอปแยก package และข้อมูลในเครื่อง ติดตั้งคู่กันได้ แอป LAB ใช้ backend LAB เท่านั้น ไม่ยกสิทธิ์เข้าฐานจริง

**APK LAB พร้อมดาวน์โหลด:** https://gatepass-lab-phuwitt.vercel.app/download.html
ไฟล์ APK ในชุดส่งสำรองอยู่ `../install/GATEPASS-LAB-1.0.0.apk` นอก Git repo พร้อม SHA-256

## เปิดซอร์ส

ใช้ Flutter 3.41.0 / Dart 3.11.0 (Flutter/Dart SDK ที่เข้ากันได้ตาม pubspec)

```sh
cd lab  # หรือ employee
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Android 7 ขึ้นไปสำหรับ LAB (minSdk ที่ตรวจจาก APK = 24) รองรับ source iOS ด้วย แต่รอบนี้ไม่ได้แจก IPA และไม่ได้อ้างว่าเปิด NFC HCE บน iPhone ได้

## บิวด์ Release

ซอร์สอ่าน signing properties ของเจ้าของจาก `~/.config/gatepass/android-signing.properties` ตัวอย่างชื่อ field ดู `android-signing.properties.example` ต้องใช้ keystore ของตนเอง ไม่รวม password/keystore ใน repo

```sh
flutter build apk --release
```

## LAB สำหรับพรีเซนต์

เปิดเว็บ https://gatepass-lab-phuwitt.vercel.app/admin ใช้รหัสของเจ้าของห้องที่ส่งแยกส่วนตัว จากนั้นเลือกพนักงาน → สร้าง QR จับคู่ → ให้แอป LAB สแกนจับคู่ → ขอ QR ที่เครื่องจำลองและสแกนเข้าอาคาร ดูผลและประวัติจาก server

ปุ่มทดสอบ NFC/บัตรเป็นการส่งคำขอจำลอง ไม่ใช่คลื่น NFC จากเบราว์เซอร์หรือมือถือ ไม่มีสแกนหน้า ผลผ่านสิทธิ์ไม่ใช่หลักฐานว่ากลอนจริงเปิด

## หลักฐานและข้อจำกัด

- LAB: analyze, tests 4 ชุด, signed release APK, live API และ download hash ผ่าน
- Employee: ซอร์สและ tests ของแอปเดิมคงไว้ ฟังก์ชันรูป/ครอป, QR, ประวัติ, สิทธิ์, Android HCE ตามเดิม
- การสแกนกล้อง/secure storage และ HCE บนเครื่องจริงต้องทดสอบแยก ไม่อ้างว่าทดสอบจากมือถือจริงในชุดส่งนี้
- Employee รุ่น 0.6.0 มี trusted QR origin list ของเว็บเดิม ก่อนใช้ URL Production ใหม่ต้องตรวจ/อัปเดตรายการแล้วบิวด์แอปจริงรอบใหม่ ไม่ใช้ LAB ไปสแกน QR ของเว็บจริง

Web: https://github.com/Phuwitt/gatepass-web
Hardware R1: https://github.com/Phuwitt/gatepass-hardware

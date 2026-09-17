# Motor Kontrol (Flutter)

Novagen'in gerçek üretim uygulaması — Firebase Auth + Firestore + MQTT (HiveMQ Cloud) tabanlı
çoklu cihaz motor/sürücü kontrol paneli. Bu klasör henüz **eksik bir proje iskeleti**:
`lib/main.dart`, `pubspec.yaml` ve `firestore.rules` var, ama platform klasörleri (`web/`,
`android/`, `ios/`) ve ESP32 firmware kodu henüz eklenmedi.

Bağımlılıklar (`pubspec.yaml`): `mqtt_client ^10.7.0`, `cloud_firestore ^5.0.0`,
`firebase_core ^3.6.0`, `firebase_auth ^5.3.1`. `lib/main.dart`'ta kullanılan tüm MQTT/Firebase
API'leri bu sürümlerle uyumlu görünüyor (elle kontrol edildi, `flutter pub get` ile doğrulanamadı).

## Bu main.dart'ta yapılan düzeltmeler

1. **Çift MQTT bağlantısı önlendi**: Dashboard listesi bir cihaza bağlandıktan sonra, o cihazın
   detay sayfası artık aynı `MqttBrowserClient`'ı devralıyor (`paylasilanClient`), ikinci bir
   bağlantı açmıyor. HiveMQ Cloud'un bağlantı sınırını gereksiz tüketmemek için önemli.
2. **Başlat / Ters Yön öncesi onay diyaloğu** eklendi — Durdur ve Arıza Sıfırla güvenli yönde
   işlemler olduğu için onaysız kaldı.
3. **JSON ayrıştırma** regex yerine `dart:convert`'in `jsonDecode`'u ile yapılıyor — hem
   `MotorKontrolPaneli.mesajiIsle` hem de dashboard'un `_durumMesajiniIsle`'ında.

## Bilinen sınırlama

Paylaşılan bağlantı senaryosunda, detay sayfası açıkken bağlantı koparsa dashboard'un kendi
`onDisconnected`/`onAutoReconnected` callback'leri zincirlenerek korunuyor, ama bu iki widget'ın
MQTT durumunu ayrı ayrı tutması hâlâ kırılgan bir tasarım. Tüm proje elimize geçince (Provider/
Riverpod gibi) paylaşılan bir bağlantı/durum servisine taşımak daha sağlıklı olur.

**Not:** Bu proje Flutter SDK'sı olmayan bir ortamda düzenlendi, bu yüzden `flutter analyze` /
`flutter test` ile doğrulanamadı — sözdizimi elle ve dikkatle kontrol edildi, ama tam proje
gelince mutlaka `flutter analyze` çalıştırılmalı.

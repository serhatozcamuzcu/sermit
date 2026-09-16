# Motor Kontrol (Flutter)

Novagen'in gerçek üretim uygulaması — Firebase Auth + Firestore + MQTT (HiveMQ Cloud) tabanlı
çoklu cihaz motor/sürücü kontrol paneli. Bu klasör henüz **eksik bir proje iskeleti**: yalnızca
`lib/main.dart` var. `pubspec.yaml`, Firestore Security Rules ve platform klasörleri (web/android/ios)
eklendiğinde proje tam hale gelecek.

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

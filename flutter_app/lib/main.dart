import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyB7jTNBh_rOSpM5k-wC-MlHv65RJdBYiWY",
      authDomain: "drive-control-4d979.firebaseapp.com",
      projectId: "drive-control-4d979",
      storageBucket: "drive-control-4d979.firebasestorage.app",
      messagingSenderId: "368398631281",
      appId: "1:368398631281:web:d8889f9ea0b0e4997736d0",
    ),
  );
  runApp(const RootApp());
}

// =====================================================================
// ARIZA KODLARI — tum dosyada (hem MotorKontrolPaneli hem de
// SurucuVerileriEkrani) ortak kullanilsin diye dosya seviyesinde sabit
// olarak tanimlandi.
// =====================================================================
const Map<int, String> arizaKodlari = {
  0x0000: 'Ariza yok',
  0x0002: 'Hizlanma sirasinda asiri akim',
  0x0003: 'Yavaslama sirasinda asiri akim',
  0x0004: 'Sabit hizda asiri akim',
  0x0005: 'Hizlanma sirasinda asiri gerilim',
  0x0006: 'Yavaslama sirasinda asiri gerilim',
  0x0007: 'Sabit hizda asiri gerilim',
  0x0008: 'On sarj direnci asiri yuklendi',
  0x0009: 'Dusuk gerilim',
  0x000A: 'Surucu asiri yuklendi',
  0x000B: 'Motor asiri yuklendi',
  0x000C: 'Giris faz kaybi',
  0x000D: 'Cikis faz kaybi',
  0x000E: 'IGBT asiri isindi',
  0x000F: 'Harici ariza',
  0x0010: 'Haberlesme hatasi',
  0x0012: 'Akim algilama hatasi',
  0x0013: 'Motor otomatik ayarlama hatasi',
  0x0015: 'Parametre okuma/yazma hatasi',
  0x0017: 'Motor topraga kisa devre',
  0x001A: 'Calisma suresi doldu',
  0x001B: 'Kullanici tanimli ariza 1',
  0x001C: 'Kullanici tanimli ariza 2',
  0x001D: 'Guc acma suresi doldu',
  0x001E: 'Yuk kaybi',
  0x001F: 'PID geri besleme kaybi',
  0x0028: 'Hizli akim siniri zaman asimi',
  0x0037: 'Hiz senkronizasyonunda slave arizasi',
};

// =====================================================================
// ROOT APP — tema (aydınlık/karanlık) durumunu burada tutuyoruz
// =====================================================================
class RootApp extends StatefulWidget {
  const RootApp({super.key});

  @override
  State<RootApp> createState() => _RootAppState();
}

class _RootAppState extends State<RootApp> {
  ThemeMode temaModu = ThemeMode.light;

  void temaDegistir() {
    setState(() {
      temaModu = temaModu == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Motor Kontrol',
      debugShowCheckedModeBanner: false,
      themeMode: temaModu,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
      ),
      home: GirisKontrol(temaDegistir: temaDegistir),
    );
  }
}

// =====================================================================
// GİRİŞ KONTROLÜ — Firebase oturum durumuna bakar
// =====================================================================
class GirisKontrol extends StatefulWidget {
  final VoidCallback temaDegistir;
  const GirisKontrol({super.key, required this.temaDegistir});

  @override
  State<GirisKontrol> createState() => _GirisKontrolState();
}

class _GirisKontrolState extends State<GirisKontrol> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          // Giris basarili: dogrudan bu hesaba tanimli TUM cihazlarin
          // listesini gosteren dashboard ekranina geciyoruz.
          return CihazlarEkrani(temaDegistir: widget.temaDegistir);
        }
        return GirisEkrani(temaDegistir: widget.temaDegistir);
      },
    );
  }
}

// =====================================================================
// GİRİŞ EKRANI — Kisisel hesap (e-posta + sifre)
// NOT: Artik "Cihaz ID" degil, kullanicinin KENDI hesabinin e-postasi
// ile giris yapiliyor. Bir hesabin altinda birden fazla cihaz olabilir
// (bkz. CihazlarEkrani). Firebase Authentication'da bu e-posta/sifre
// ile bir kullanici olusturulmus olmali (Firebase Console uzerinden).
// =====================================================================
class GirisEkrani extends StatefulWidget {
  final VoidCallback temaDegistir;
  const GirisEkrani({super.key, required this.temaDegistir});

  @override
  State<GirisEkrani> createState() => _GirisEkraniState();
}

class _GirisEkraniState extends State<GirisEkrani> {
  final TextEditingController hesapIdController = TextEditingController();
  final TextEditingController sifreController = TextEditingController();
  String hataMesaji = '';
  bool yukleniyor = false;

  // Kullaniciya sadece "Hesap ID" gosteriyoruz; Firebase Authentication
  // arka planda yine e-posta formati bekledigi icin bunu gorunmez bir
  // sekilde bir e-postaya ceviriyoruz. Kullanicinin bunu bilmesine gerek yok.
  String _emailOlustur(String hesapId) {
    return hesapId.trim().toLowerCase() + '@cihaz.motorkontrol.app';
  }

  Future<void> girisYap() async {
    if (hesapIdController.text.isEmpty || sifreController.text.isEmpty) {
      setState(() {
        hataMesaji = 'Hesap ID ve sifre gerekli';
      });
      return;
    }

    setState(() {
      yukleniyor = true;
      hataMesaji = '';
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailOlustur(hesapIdController.text),
        password: sifreController.text,
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
          hataMesaji = 'Hesap ID veya sifre hatali';
        } else if (e.code == 'wrong-password') {
          hataMesaji = 'Sifre hatali';
        } else {
          hataMesaji = 'Giris hatasi: ' + e.code;
        }
        yukleniyor = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo.shade50,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.developer_board, size: 48, color: Colors.indigo.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    'Motor Kontrol Paneli',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('Hesabinizla giris yapin'),
                  const SizedBox(height: 24),
                  TextField(
                    controller: hesapIdController,
                    decoration: InputDecoration(
                      labelText: 'Hesap ID',
                      hintText: 'ornek: novagen-firma1',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: sifreController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Sifre',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      errorText: hataMesaji.isEmpty ? null : hataMesaji,
                    ),
                    onSubmitted: (_) => girisYap(),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: yukleniyor ? null : girisYap,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: yukleniyor
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('GIRIS YAP'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const KayitEkrani()),
                      );
                    },
                    child: const Text('Hesabin yok mu? Kayit ol'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// KAYIT OL EKRANI
// Kullanici burada KENDI istedigi bir "Hesap ID" (kullanici adi) ve
// KENDI istedigi bir sifre belirleyerek yeni bir hesap olusturur.
// Firebase Authentication e-posta formati bekledigi icin, girilen
// Hesap ID gorunmez sekilde bir e-postaya cevriliyor (GirisEkrani'ndaki
// ile ayni yontem, boylece ayni hesapla sonra giris yapabiliyor).
// Kayit basarili olunca GirisKontrol'daki authStateChanges dinleyicisi
// bunu otomatik yakalayip kullaniciyi CihazlarEkrani'na yonlendirir,
// bu yuzden burada elle bir yonlendirme yapmamiza gerek yok.
// =====================================================================
class KayitEkrani extends StatefulWidget {
  const KayitEkrani({super.key});

  @override
  State<KayitEkrani> createState() => _KayitEkraniState();
}

class _KayitEkraniState extends State<KayitEkrani> {
  final TextEditingController hesapIdController = TextEditingController();
  final TextEditingController sifreController = TextEditingController();
  final TextEditingController sifreTekrarController = TextEditingController();
  String hataMesaji = '';
  bool yukleniyor = false;

  String _emailOlustur(String hesapId) {
    return hesapId.trim().toLowerCase() + '@cihaz.motorkontrol.app';
  }

  Future<void> kayitOl() async {
    final hesapId = hesapIdController.text.trim();
    final sifre = sifreController.text;
    final sifreTekrar = sifreTekrarController.text;

    if (hesapId.isEmpty || sifre.isEmpty) {
      setState(() => hataMesaji = 'Hesap ID ve sifre gerekli');
      return;
    }
    if (hesapId.contains('@') || hesapId.contains(' ')) {
      setState(() => hataMesaji = 'Hesap ID icinde bosluk veya @ olamaz');
      return;
    }
    if (sifre.length < 6) {
      setState(() => hataMesaji = 'Sifre en az 6 karakter olmali');
      return;
    }
    if (sifre != sifreTekrar) {
      setState(() => hataMesaji = 'Sifreler birbiriyle uyusmuyor');
      return;
    }

    setState(() {
      yukleniyor = true;
      hataMesaji = '';
    });

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailOlustur(hesapId),
        password: sifre,
      );
      // Basarili: authStateChanges dinleyicisi otomatik yonlendirecek,
      // bu ekran zaten kapanmis olacak (StreamBuilder yeniden build eder).
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'email-already-in-use') {
          hataMesaji = 'Bu Hesap ID zaten kullanimda, baska bir tane sec';
        } else if (e.code == 'weak-password') {
          hataMesaji = 'Sifre cok zayif, en az 6 karakter olmali';
        } else {
          hataMesaji = 'Kayit hatasi: ' + e.code;
        }
        yukleniyor = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kayit Ol')),
      backgroundColor: Colors.indigo.shade50,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_add_alt_1, size: 48, color: Colors.indigo.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    'Yeni Hesap Olustur',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('Kendi Hesap ID ve sifreni belirle'),
                  const SizedBox(height: 24),
                  TextField(
                    controller: hesapIdController,
                    decoration: InputDecoration(
                      labelText: 'Hesap ID (kullanici adi)',
                      hintText: 'ornek: novagen-firma1',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: sifreController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Sifre',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: sifreTekrarController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Sifre (tekrar)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      errorText: hataMesaji.isEmpty ? null : hataMesaji,
                    ),
                    onSubmitted: (_) => kayitOl(),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: yukleniyor ? null : kayitOl,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: yukleniyor
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('HESAP OLUSTUR'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// ŞİFRE DEĞİŞTİRME EKRANI
// =====================================================================
class SifreDegistirEkrani extends StatefulWidget {
  const SifreDegistirEkrani({super.key});

  @override
  State<SifreDegistirEkrani> createState() => _SifreDegistirEkraniState();
}

class _SifreDegistirEkraniState extends State<SifreDegistirEkrani> {
  final TextEditingController yeniSifreController = TextEditingController();
  String mesaj = '';
  bool basarili = false;

  Future<void> sifreyiDegistir() async {
    if (yeniSifreController.text.length < 6) {
      setState(() {
        mesaj = 'Sifre en az 6 karakter olmali';
        basarili = false;
      });
      return;
    }
    try {
      await FirebaseAuth.instance.currentUser!.updatePassword(yeniSifreController.text);
      setState(() {
        mesaj = 'Sifre basariyla degistirildi';
        basarili = true;
      });
    } catch (e) {
      setState(() {
        mesaj = 'Hata: ' + e.toString();
        basarili = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sifre Degistir')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: yeniSifreController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Yeni Sifre',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: sifreyiDegistir,
              child: const Text('DEGISTIR'),
            ),
            const SizedBox(height: 12),
            if (mesaj.isNotEmpty)
              Text(
                mesaj,
                style: TextStyle(color: basarili ? Colors.green : Colors.red),
              ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// CİHAZLAR EKRANI — hesaba tanimli TUM motorlarin listesini Firestore'dan
// ceker. Firestore yolu: hesaplar/{kullaniciUid}/cihazlar/{cihazId}
// Her cihaz dokumaninda "isim" alani (kullanicinin verdigi isim) bulunur.
// Cihaz sayisi degistikce alttaki _SekmeGorunumu yeniden olusturulur
// (TabController'in dogru sayida sekmeyle kurulmasi icin).
// =====================================================================
class CihazlarEkrani extends StatefulWidget {
  final VoidCallback temaDegistir;
  const CihazlarEkrani({super.key, required this.temaDegistir});

  @override
  State<CihazlarEkrani> createState() => _CihazlarEkraniState();
}

class _CihazlarEkraniState extends State<CihazlarEkrani> {
  Future<void> cikisYap() async {
    await FirebaseAuth.instance.signOut();
  }

  // -----------------------------------------------------------------
  // CIHAZ EKLEME — kullanici kendi motorunu kendisi ekleyebilsin diye.
  // Kullanici Cihaz ID + Anahtar (cihazla birlikte verilen/etiketteki
  // eslestirme kodu) giriyor. Bu yazma islemi, Firestore Security Rules
  // tarafindan sadece girilen anahtar mqtt_kimlik_bilgileri/{cihazId}
  // dokumanindaki gercek "pairingKey" ile eslesirse KABUL EDILIYOR.
  // Boylece kullanici rastgele bir cihaz ID'si yazip baskasinin
  // motoruna erisemiyor.
  // -----------------------------------------------------------------
  Future<void> cihazEkle() async {
    final cihazIdController = TextEditingController();
    final anahtarController = TextEditingController();
    final isimController = TextEditingController();
    String hataMesaji = '';
    bool ekleniyor = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> gonder() async {
              if (cihazIdController.text.trim().isEmpty || anahtarController.text.trim().isEmpty) {
                setDialogState(() => hataMesaji = 'Cihaz ID ve Anahtar gerekli');
                return;
              }

              setDialogState(() {
                ekleniyor = true;
                hataMesaji = '';
              });

              final cihazId = cihazIdController.text.trim().toLowerCase();
              final uid = FirebaseAuth.instance.currentUser!.uid;
              final isim = isimController.text.trim().isEmpty
                  ? cihazId
                  : isimController.text.trim();

              try {
                await FirebaseFirestore.instance
                    .collection('hesaplar')
                    .doc(uid)
                    .collection('cihazlar')
                    .doc(cihazId)
                    .set({
                  'isim': isim,
                  'anahtar': anahtarController.text.trim(),
                });
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              } catch (e) {
                setDialogState(() {
                  ekleniyor = false;
                  hataMesaji = 'Cihaz ID veya Anahtar hatali, ya da bu cihaz zaten baska bir hesaba kayitli';
                });
              }
            }

            return AlertDialog(
              title: const Text('Yeni Motor Ekle'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: cihazIdController,
                    decoration: const InputDecoration(labelText: 'Cihaz ID'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: anahtarController,
                    decoration: const InputDecoration(
                      labelText: 'Anahtar',
                      hintText: 'Cihaz etiketindeki kod',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: isimController,
                    decoration: const InputDecoration(
                      labelText: 'Motor Adi (istege bagli)',
                    ),
                  ),
                  if (hataMesaji.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(hataMesaji, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Iptal'),
                ),
                ElevatedButton(
                  onPressed: ekleniyor ? null : gonder,
                  child: ekleniyor
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Ekle'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> cihazSil(String cihazId) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance
        .collection('hesaplar')
        .doc(uid)
        .collection('cihazlar')
        .doc(cihazId)
        .delete();
  }

  String _isimAl(QueryDocumentSnapshot dokuman) {
    final veri = dokuman.data() as Map<String, dynamic>;
    final isim = veri['isim'] as String?;
    return (isim != null && isim.trim().isNotEmpty) ? isim : dokuman.id;
  }

  Future<void> cihazAdiDuzenle(String cihazId, String mevcutIsim) async {
    final controller = TextEditingController(text: mevcutIsim);
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final yeniIsim = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Motor Adini Duzenle'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Motor Adi'),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final onaylandi = await showDialog<bool>(
                context: dialogContext,
                builder: (onayContext) => AlertDialog(
                  title: const Text('Motoru Kaldir'),
                  content: const Text('Bu motoru hesabinizdan kaldirmak istediginize emin misiniz?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(onayContext).pop(false),
                      child: const Text('Vazgec'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(onayContext).pop(true),
                      child: const Text('Kaldir', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (onaylandi == true) {
                await cihazSil(cihazId);
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              }
            },
            child: const Text('Kaldir', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Iptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );

    if (yeniIsim != null && yeniIsim.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('hesaplar')
          .doc(uid)
          .collection('cihazlar')
          .doc(cihazId)
          .update({'isim': yeniIsim});
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('hesaplar')
          .doc(uid)
          .collection('cihazlar')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Hata: ' + snapshot.error.toString())),
          );
        }

        final dokumanlar = snapshot.data?.docs ?? [];

        if (dokumanlar.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Motor Kontrol'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.brightness_6),
                  onPressed: widget.temaDegistir,
                  tooltip: 'Tema degistir',
                ),
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: cikisYap,
                  tooltip: 'Cikis yap',
                ),
              ],
            ),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Hesabiniza henuz bir motor eklenmemis.\n'
                  'Asagidaki + butonuyla ilk motorunuzu ekleyin.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: cihazEkle,
              icon: const Icon(Icons.add),
              label: const Text('Motor Ekle'),
            ),
          );
        }

        // Cihaz listesi degistiginde (eklenince/silinince) durum takip
        // widget'inin dogru cihaz kumesiyle yeniden kurulmasi icin bu alt
        // widget'i cihaz ID'lerinin birlesiminden olusan bir Key ile
        // yeniden olusturuyoruz.
        final cihazIdListesi = dokumanlar.map((d) => d.id).join(',');

        return _MusteriDashboard(
          key: ValueKey(cihazIdListesi),
          dokumanlar: dokumanlar,
          temaDegistir: widget.temaDegistir,
          cikisYap: cikisYap,
          cihazAdiDuzenle: cihazAdiDuzenle,
          cihazEkle: cihazEkle,
          isimAl: _isimAl,
        );
      },
    );
  }
}

class _MotorDurumOzet {
  bool baglantiVar = false;
  bool calisiyor = false;
  int arizaKodu = 0;
}

// =====================================================================
// MÜŞTERİ DASHBOARD'U
// "Kuyu Takip" ornegindeki gibi: ustte ozet durum kartlari (toplam motor,
// calisiyor, durdu, arizali, baglanti yok), altinda musterinin KENDI
// motorlarinin listesi. Bir motora tiklayinca MotorDetaySayfasi'na
// (icinde MotorKontrolPaneli) geciliyor.
// =====================================================================
class _MusteriDashboard extends StatefulWidget {
  final List<QueryDocumentSnapshot> dokumanlar;
  final VoidCallback temaDegistir;
  final Future<void> Function() cikisYap;
  final Future<void> Function(String cihazId, String mevcutIsim) cihazAdiDuzenle;
  final Future<void> Function() cihazEkle;
  final String Function(QueryDocumentSnapshot) isimAl;

  const _MusteriDashboard({
    required this.dokumanlar,
    required this.temaDegistir,
    required this.cikisYap,
    required this.cihazAdiDuzenle,
    required this.cihazEkle,
    required this.isimAl,
    super.key,
  });

  @override
  State<_MusteriDashboard> createState() => _MusteriDashboardState();
}

class _MusteriDashboardState extends State<_MusteriDashboard> {
  final Map<String, _MotorDurumOzet> durumlar = {};
  final Map<String, MqttBrowserClient> clientlar = {};

  @override
  void initState() {
    super.initState();
    for (final d in widget.dokumanlar) {
      durumlar[d.id] = _MotorDurumOzet();
      _cihazaBaglan(d.id);
    }
  }

  Future<void> _cihazaBaglan(String cihazId) async {
    try {
      final dokuman = await FirebaseFirestore.instance
          .collection('mqtt_kimlik_bilgileri')
          .doc(cihazId)
          .get();
      if (!dokuman.exists) return;

      final veri = dokuman.data()!;
      final broker = veri['broker'] as String?;
      final kullaniciAdi = veri['kullaniciAdi'] as String?;
      final sifre = veri['sifre'] as String?;
      if (broker == null || kullaniciAdi == null || sifre == null) return;

      final client = MqttBrowserClient(
        'wss://$broker:8884/mqtt',
        'dashboard_${cihazId}_${DateTime.now().millisecondsSinceEpoch}',
      );
      client.port = 8884;
      client.keepAlivePeriod = 45;
      client.autoReconnect = true;
      // Motor detay sayfasi bu ayni client'i devralip kendi status
      // dinleyicisini eklesin diye (bkz. MotorKontrolPaneli.paylasilanClient),
      // yeniden baglandiktan sonra abonelikler kaybolmasin diye acik.
      client.resubscribeOnAutoReconnect = true;
      client.logging(on: false);
      client.onDisconnected = () {
        if (mounted) setState(() => durumlar[cihazId]?.baglantiVar = false);
      };

      final connMessage = MqttConnectMessage()
          .authenticateAs(kullaniciAdi, sifre)
          .withClientIdentifier('dashboard_' + cihazId)
          .startClean();
      client.connectionMessage = connMessage;

      await client.connect();

      if (client.connectionStatus!.state == MqttConnectionState.connected) {
        clientlar[cihazId] = client;
        if (mounted) setState(() => durumlar[cihazId]?.baglantiVar = true);
        client.subscribe('device/' + cihazId + '/status', MqttQos.atMostOnce);
        client.updates!.listen((mesajlar) {
          final recMess = mesajlar[0].payload as MqttPublishMessage;
          final payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
          _durumMesajiniIsle(cihazId, payload);
        });
      }
    } catch (e) {
      debugPrint('Dashboard baglanti hatasi ($cihazId): $e');
    }
  }

  void _durumMesajiniIsle(String cihazId, String jsonMetin) {
    Map<String, dynamic> veri;
    try {
      veri = jsonDecode(jsonMetin) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Dashboard JSON okuma hatasi ($cihazId): $e');
      return;
    }
    if (!mounted) return;
    setState(() {
      final durum = durumlar[cihazId];
      if (durum == null) return;
      final ariza = veri['ariza'];
      if (ariza is num) durum.arizaKodu = ariza.toInt();
      final calisiyor = veri['calisiyor'];
      if (calisiyor is bool) durum.calisiyor = calisiyor;
    });
  }

  @override
  void dispose() {
    for (final client in clientlar.values) {
      client.disconnect();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Genislik esigi: bundan DAR ekranlarda (telefon) sabit sol menu yerine
    // kayan bir cekmece (Drawer) kullaniyoruz, cunku sabit menu dar ekranda
    // ic kismi asiri sikistirip yazilari harf harf alt alta diziyordu.
    const genislikEsigi = 700.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final genisEkran = constraints.maxWidth >= genislikEsigi;

        if (genisEkran) {
          return Scaffold(
            floatingActionButton: FloatingActionButton(
              onPressed: widget.cihazEkle,
              tooltip: 'Yeni motor ekle',
              child: const Icon(Icons.add),
            ),
            body: Row(
              children: [
                SizedBox(
                  width: 220,
                  child: _yanMenu(context),
                ),
                Expanded(child: _anaIcerik(context)),
              ],
            ),
          );
        }

        // DAR EKRAN (telefon): normal AppBar + hamburger menu ile acilan Drawer
        return Scaffold(
          appBar: AppBar(title: const Text('Motor Kontrol')),
          drawer: Drawer(child: _yanMenu(context)),
          floatingActionButton: FloatingActionButton(
            onPressed: widget.cihazEkle,
            tooltip: 'Yeni motor ekle',
            child: const Icon(Icons.add),
          ),
          body: _anaIcerik(context),
        );
      },
    );
  }

  // ---------------------------------------------------------
  // SOL MENÜ — gonderdigin "Kuyu Takip" ornegindeki gibi. Genis
  // ekranda sabit sol serit olarak, dar ekranda Drawer icinde
  // kullaniliyor (ikisi de ayni bu widget'i paylasiyor).
  // ---------------------------------------------------------
  Widget _yanMenu(BuildContext context) {
    return Container(
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.grey.shade900
          : Colors.indigo.shade900,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Row(
                children: [
                  Icon(Icons.developer_board, color: Colors.white, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Motor Kontrol',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            _menuMaddesi(Icons.grid_view_rounded, 'Anasayfa', secili: true, onTap: () {
              if (Scaffold.maybeOf(context)?.isDrawerOpen == true) Navigator.of(context).pop();
            }),
            _menuMaddesi(Icons.engineering, 'Motorlarim', onTap: () {
              if (Scaffold.maybeOf(context)?.isDrawerOpen == true) Navigator.of(context).pop();
            }),
            _menuMaddesi(Icons.brightness_6, 'Tema Degistir', onTap: widget.temaDegistir),
            _menuMaddesi(
              Icons.lock_reset,
              'Sifre Degistir',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SifreDegistirEkrani()),
                );
              },
            ),
            const Spacer(),
            _menuMaddesi(Icons.logout, 'Cikis Yap', onTap: widget.cikisYap),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // SAG/ANA ICERIK — ust kartlar + motor listesi. Genis ekranda
  // sag panel, dar ekranda tum sayfanin body'si olarak kullaniliyor.
  // ---------------------------------------------------------
  Widget _anaIcerik(BuildContext context) {
    final toplam = durumlar.length;
    final calisan = durumlar.values.where((d) => d.baglantiVar && d.calisiyor).length;
    final durmus = durumlar.values.where((d) => d.baglantiVar && !d.calisiyor).length;
    final arizali = durumlar.values.where((d) => d.arizaKodu != 0).length;
    final baglantisiz = durumlar.values.where((d) => !d.baglantiVar).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          color: Colors.indigo.shade50,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.developer_board, color: Colors.indigo.shade400, size: 28),
                const SizedBox(width: 10),
                const Text('Toplam Motor', style: TextStyle(fontSize: 14)),
                const Spacer(),
                Text(toplam.toString(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          // Dar ekranda 2 sutun, genis ekranda 4 sutun: boylece telefonda
          // her kutu kendine yeterli genislik buluyor, harf harf sikismiyor.
          crossAxisCount: MediaQuery.of(context).size.width >= 700 ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.6,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: [
            _durumKarti('Calisiyor', calisan, Colors.green),
            _durumKarti('Durdu', durmus, Colors.blueGrey),
            _durumKarti('Arizali', arizali, Colors.red),
            _durumKarti('Baglanti Yok', baglantisiz, Colors.orange),
          ],
        ),
        const SizedBox(height: 20),
        const Text('Motorlarim', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        ...widget.dokumanlar.map((d) {
          final durum = durumlar[d.id];
          final isim = widget.isimAl(d);
          final renk = durum == null || !durum.baglantiVar
              ? Colors.orange
              : (durum.arizaKodu != 0
                  ? Colors.red
                  : (durum.calisiyor ? Colors.green : Colors.blueGrey));
          final metin = durum == null || !durum.baglantiVar
              ? 'Baglanti yok'
              : (durum.arizaKodu != 0 ? 'Arizali' : (durum.calisiyor ? 'Calisiyor' : 'Durdu'));

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: renk.withValues(alpha: 0.15),
                child: Icon(Icons.engineering, color: renk),
              ),
              title: Text(isim),
              subtitle: Text(metin, style: TextStyle(color: renk)),
              trailing: const Icon(Icons.chevron_right),
              onLongPress: () => widget.cihazAdiDuzenle(d.id, isim),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MotorDetaySayfasi(
                      cihazId: d.id,
                      isim: isim,
                      // Bu cihaz icin dashboard'un zaten actigi baglanti varsa
                      // (clientlar[d.id]) detay sayfasina aktariyoruz; boylece
                      // ayni cihaza IKINCI bir MQTT baglantisi acilmiyor.
                      paylasilanClient: clientlar[d.id],
                    ),
                  ),
                );
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _menuMaddesi(IconData ikon, String baslik, {bool secili = false, VoidCallback? onTap}) {
    return Material(
      color: secili ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          child: Row(
            children: [
              Icon(ikon, color: secili ? Colors.white : Colors.white70, size: 20),
              const SizedBox(width: 14),
              Text(
                baslik,
                style: TextStyle(
                  color: secili ? Colors.white : Colors.white70,
                  fontSize: 14,
                  fontWeight: secili ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _durumKarti(String baslik, int sayi, Color renk) {
    return Card(
      elevation: 0,
      color: renk.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(baslik, style: TextStyle(color: renk, fontSize: 12)),
            const SizedBox(height: 4),
            Text(sayi.toString(), style: TextStyle(color: renk, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// MOTOR DETAY SAYFASI — dashboard'dan bir motora tiklaninca acilan sayfa.
// Icinde, degismeden kalan MotorKontrolPaneli'ni (start/durdur, arizalar,
// hiz ayari vs.) barindirir; sadece bir AppBar/geri tusu ekliyor.
// =====================================================================
class MotorDetaySayfasi extends StatelessWidget {
  final String cihazId;
  final String isim;
  final MqttBrowserClient? paylasilanClient;
  const MotorDetaySayfasi({
    super.key,
    required this.cihazId,
    required this.isim,
    this.paylasilanClient,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isim)),
      body: MotorKontrolPaneli(cihazId: cihazId, paylasilanClient: paylasilanClient),
    );
  }
}

// =====================================================================
// MOTOR KONTROL PANELİ — tek bir motorun durumunu gosterir ve kontrol
// eder. MotorDetaySayfasi tarafindan body olarak kullaniliyor.
// AutomaticKeepAliveClientMixin: kullanici baska bir sekmeye gecse bile
// bu panelin state'i (ve MQTT baglantisi) canli kalir, veri akmaya devam
// eder.
// =====================================================================
class MotorKontrolPaneli extends StatefulWidget {
  final String cihazId;
  // Dashboard listesi bu cihaz icin zaten bagli bir MqttBrowserClient
  // tutuyorsa buradan aktarilir. Doluysa ve hala bagliysa, bu panel
  // AYNI client'i yeniden kullanir; boylece ayni cihaza dashboard +
  // detay sayfasindan iki ayri MQTT baglantisi acilmaz (HiveMQ Cloud
  // ucretsiz planinin baglanti sinirini bosuna tuketmemek icin onemli).
  final MqttBrowserClient? paylasilanClient;
  const MotorKontrolPaneli({super.key, required this.cihazId, this.paylasilanClient});

  @override
  State<MotorKontrolPaneli> createState() => _MotorKontrolPaneliState();
}

class _MotorKontrolPaneliState extends State<MotorKontrolPaneli>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  double hizAyari = 0;
  double hiz = 0;
  double akim = 0;
  double? gerilim;
  double? sicaklik;
  int arizaKodu = 0;
  int oncekiArizaKodu = 0;
  bool motorCalisiyor = false;
  bool baglantiVar = false;

  // Bu sayfanin client'i disaridan (dashboard'dan) mi devraldigini
  // tutar. true ise dispose() sirasinda baglantiyi KAPATMAYIZ, cunku
  // sahibi hala dashboard'dur.
  bool _clientDisaridanGeldi = false;

  final double akimLimiti = 8.0;
  final List<double> hizGecmisi = [];
  final int gecmisUzunlugu = 30;

  late MqttBrowserClient client;
  Timer? yenidenBaglanmaZamanlayicisi;

  // -----------------------------------------------------------------
  // GÜVENLİK NOTU:
  // MQTT broker adresi, kullanici adi ve sifre kodun icine gomulu
  // DEGIL. Sadece bu cihazin sahibi olan hesap giris yaptiginda,
  // Firestore Security Rules ile korunan mqtt_kimlik_bilgileri/<cihazId>
  // dokumanindan cekiliyor.
  // -----------------------------------------------------------------
  String? _broker;
  String? _kullaniciAdi;
  String? _sifre;
  bool bilgilerYukleniyor = true;
  String bilgiHatasi = '';

  String get statusTopic => 'device/' + widget.cihazId + '/status';
  String get commandTopic => 'device/' + widget.cihazId + '/command';

  String arizaMetni() {
    return arizaKodlari[arizaKodu] ?? 'Bilinmeyen ariza (kod: 0x' + arizaKodu.toRadixString(16) + ')';
  }

  @override
  void initState() {
    super.initState();

    final disaridanGelenClient = widget.paylasilanClient;
    if (disaridanGelenClient != null &&
        disaridanGelenClient.connectionStatus?.state == MqttConnectionState.connected) {
      // Dashboard'un zaten actigi ve bagli olan client'i devraliyoruz;
      // yeni bir MQTT baglantisi ACMIYORUZ.
      _clientDisaridanGeldi = true;
      client = disaridanGelenClient;
      baglantiVar = true;
      bilgilerYukleniyor = false;

      // Dashboard'un kendi onDisconnected/onAutoReconnected callback'lerini
      // EZMEDEN, bu sayfanin kendi durum guncellemesini de zincirliyoruz.
      final oncekiOnDisconnected = client.onDisconnected;
      client.onDisconnected = () {
        oncekiOnDisconnected?.call();
        _baglantiKoptu();
      };
      final oncekiOnAutoReconnected = client.onAutoReconnected;
      client.onAutoReconnected = () {
        oncekiOnAutoReconnected?.call();
        if (mounted) setState(() => baglantiVar = true);
      };

      // Ayni topic'e tekrar subscribe olmak MQTT protokolunde zararsizdir
      // (abonelik guncellenir, mesaj ikiye katlanmaz); dashboard baglantiyi
      // kapatmadan bu sayfa acilip kapanabildigi icin burada da subscribe
      // ediyoruz ki bu sayfa tek basina acilsa bile calissin.
      client.subscribe(statusTopic, MqttQos.atMostOnce);
      client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> mesajlar) {
        final recMess = mesajlar[0].payload as MqttPublishMessage;
        final payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        mesajiIsle(payload);
      });
    } else {
      _mqttBilgileriniGetirVeBaglan();
    }
  }

  Future<void> _mqttBilgileriniGetirVeBaglan() async {
    try {
      final dokuman = await FirebaseFirestore.instance
          .collection('mqtt_kimlik_bilgileri')
          .doc(widget.cihazId)
          .get();

      if (!dokuman.exists) {
        setState(() {
          bilgilerYukleniyor = false;
          bilgiHatasi = 'Bu cihaz icin MQTT bilgisi bulunamadi. Yonetici ile iletisime gecin.';
        });
        return;
      }

      final veri = dokuman.data()!;
      _broker = veri['broker'] as String?;
      _kullaniciAdi = veri['kullaniciAdi'] as String?;
      _sifre = veri['sifre'] as String?;

      if (_broker == null || _kullaniciAdi == null || _sifre == null) {
        setState(() {
          bilgilerYukleniyor = false;
          bilgiHatasi = 'MQTT bilgileri eksik. Yonetici ile iletisime gecin.';
        });
        return;
      }

      setState(() {
        bilgilerYukleniyor = false;
      });

      mqttBaglan();
    } catch (e) {
      setState(() {
        bilgilerYukleniyor = false;
        bilgiHatasi = 'MQTT bilgileri alinamadi: ' + e.toString();
      });
    }
  }

  Future<void> mqttBaglan() async {
    if (_broker == null || _kullaniciAdi == null || _sifre == null) return;

    client = MqttBrowserClient(
      'wss://${_broker}:8884/mqtt',
      'flutter_app_${widget.cihazId}_${DateTime.now().millisecondsSinceEpoch}',
    );
    client.port = 8884;
    client.keepAlivePeriod = 45;
    client.autoReconnect = true;
    client.resubscribeOnAutoReconnect = true;
    client.logging(on: false);
    client.onDisconnected = _baglantiKoptu;
    client.onAutoReconnect = () {
      debugPrint('[${widget.cihazId}] Otomatik yeniden baglaniliyor...');
    };
    client.onAutoReconnected = () {
      if (mounted) {
        setState(() {
          baglantiVar = true;
        });
      }
    };

    final connMessage = MqttConnectMessage()
        .authenticateAs(_kullaniciAdi!, _sifre!)
        .withClientIdentifier('flutter_motor_app_' + widget.cihazId)
        .startClean();
    client.connectionMessage = connMessage;

    try {
      await client.connect();
    } catch (e) {
      debugPrint('MQTT baglanti hatasi: $e');
      client.disconnect();
      _yenidenBaglanmayiPlanla();
      return;
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      if (mounted) {
        setState(() {
          baglantiVar = true;
        });
      }

      client.subscribe(statusTopic, MqttQos.atMostOnce);

      client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> mesajlar) {
        final recMess = mesajlar[0].payload as MqttPublishMessage;
        final payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        mesajiIsle(payload);
      });
    } else {
      client.disconnect();
      _yenidenBaglanmayiPlanla();
    }
  }

  void _baglantiKoptu() {
    if (mounted) {
      setState(() {
        baglantiVar = false;
      });
    }
    // Kutuphanenin autoReconnect ozelligi baglanti koptuktan sonra
    // kendisi tekrar deniyor; burada AYRICA elle bir zamanlayici
    // kurmuyoruz (iki mekanizmanin cakismasini onlemek icin). Elle
    // zamanlayici sadece ILK baglanti denemesi (connect() cagrisi)
    // basarisiz olursa devreye giriyor (bkz. mqttBaglan icindeki catch).
  }

  void _yenidenBaglanmayiPlanla() {
    yenidenBaglanmaZamanlayicisi?.cancel();
    yenidenBaglanmaZamanlayicisi = Timer(const Duration(seconds: 5), () {
      if (mounted && !baglantiVar) {
        mqttBaglan();
      }
    });
  }

  // Durum (status) mesaji artik gercek JSON ayristirma (jsonDecode) ile
  // okunuyor; eskiden burada regex kullaniliyordu, bu hem daha kirilgandi
  // (ic ice alanlar/negatif sayilarla yanlis eslesebilirdi) hem de her
  // alan icin ayri ayri regex calistirmak gereksiz bir maliyetti.
  void mesajiIsle(String jsonMetin) {
    Map<String, dynamic> veri;
    try {
      veri = jsonDecode(jsonMetin) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('JSON okuma hatasi: $e');
      return;
    }

    final yeniHiz = _sayiAl(veri, 'hiz') ?? hiz;
    final yeniAkim = _sayiAl(veri, 'akim') ?? akim;
    final yeniArizaKodu = (_sayiAl(veri, 'ariza') ?? arizaKodu.toDouble()).toInt();
    final yeniCalisiyor = veri['calisiyor'] is bool ? veri['calisiyor'] as bool : null;

    setState(() {
      hiz = yeniHiz;
      akim = yeniAkim;
      arizaKodu = yeniArizaKodu;
      gerilim = _sayiAl(veri, 'gerilim');
      sicaklik = _sayiAl(veri, 'sicaklik');

      // ESP32'nin gonderdigi gercek "calisiyor" bilgisini esas aliyoruz.
      // Boylece ekrandan cikip tekrar girildiginde (ya da baska bir
      // cihazdan bakildiginda) BASLAT/DURDUR butonlari cihazin GERCEK
      // durumuna gore aktif/pasif oluyor, uygulamanin kendi yerel
      // hafizasina degil.
      if (yeniCalisiyor != null) {
        motorCalisiyor = yeniCalisiyor;
      }

      hizGecmisi.add(yeniHiz);
      if (hizGecmisi.length > gecmisUzunlugu) {
        hizGecmisi.removeAt(0);
      }
    });

    // Yeni bir arizaya "gecis" oldugunda (ariza yokken bir ariza kodu
    // gelmeye basladiginda) bunu Firestore'a kaydediyoruz, boylece
    // gecmis ariza kayitlari sayfasinda listelenebiliyor. Ayni ariza
    // her mesajda tekrar tekrar kaydedilmesin diye onceki kodla
    // karsilastiriyoruz.
    if (yeniArizaKodu != 0 && yeniArizaKodu != oncekiArizaKodu) {
      _arizayiKaydet(yeniArizaKodu);
    }
    oncekiArizaKodu = yeniArizaKodu;
  }

  // JSON'daki bir alani double olarak okur; alan yoksa veya sayi degilse
  // null doner (cagiran taraf o zaman mevcut degeri korur).
  double? _sayiAl(Map<String, dynamic> veri, String anahtar) {
    final deger = veri[anahtar];
    if (deger is num) return deger.toDouble();
    return null;
  }

  // Ariza kaydini Firestore'a yaziyoruz:
  // hesaplar/{uid}/cihazlar/{cihazId}/arizalar/{otomatikId}
  Future<void> _arizayiKaydet(int kod) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('hesaplar')
          .doc(uid)
          .collection('cihazlar')
          .doc(widget.cihazId)
          .collection('arizalar')
          .add({
        'kod': kod,
        'mesaj': arizaKodlari[kod] ?? 'Bilinmeyen ariza (kod: 0x' + kod.toRadixString(16) + ')',
        'tarih': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Ariza kaydedilemedi: $e');
    }
  }

  void komutGonder(String jsonMesaj) {
    if (!baglantiVar) return;
    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonMesaj);
    client.publishMessage(commandTopic, MqttQos.atLeastOnce, builder.payload!);
  }

  // Motoru fiziksel olarak calistirmadan once kullanicidan onay istiyoruz.
  // Uzaktan, tek dokunusla bir motoru yanlislikla baslatmak (ozellikle
  // bakim/temizlik sirasinda) guvenlik acisindan riskli olabilir; DURDUR
  // ve ARIZA SIFIRLA icin onay istemiyoruz cunku onlar guvenli yondeki
  // islemler.
  Future<bool> _onayIste(String mesaj) async {
    final sonuc = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Onay Gerekli'),
        content: Text(mesaj),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgec'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('Evet, Calistir'),
          ),
        ],
      ),
    );
    return sonuc ?? false;
  }

  void motoruBaslat() {
    komutGonder('{"action": "start"}');
    setState(() => motorCalisiyor = true);
  }

  void motoruTersCalistir() {
    komutGonder('{"action": "reverse"}');
    setState(() => motorCalisiyor = true);
  }

  void motoruDurdur() {
    komutGonder('{"action": "stop"}');
    setState(() => motorCalisiyor = false);
  }

  void arizaSifirla() {
    komutGonder('{"action": "fault_reset"}');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ariza sifirlama komutu gonderildi')),
    );
  }

  void hizGonder(double deger) {
    komutGonder('{"action": "set_speed", "value": ' + deger.toStringAsFixed(0) + '}');
  }

  @override
  void dispose() {
    yenidenBaglanmaZamanlayicisi?.cancel();
    // Paylasilan (dashboard'dan devralinan) bir client'i burada KAPATMIYORUZ;
    // o baglantinin sahibi hala dashboard sayfasidir ve orada kullanilmaya
    // devam eder. Sadece bu sayfanin kendi actigi bir baglantiysa kapatiyoruz.
    if (!_clientDisaridanGeldi && !bilgilerYukleniyor && bilgiHatasi.isEmpty) {
      client.disconnect();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin icin gerekli

    if (bilgilerYukleniyor) {
      return const Center(child: CircularProgressIndicator());
    }

    if (bilgiHatasi.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(bilgiHatasi, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    final akimAsiri = akim > akimLimiti;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Chip(
              avatar: Icon(
                Icons.circle,
                size: 12,
                color: baglantiVar ? Colors.greenAccent : Colors.redAccent,
              ),
              label: Text(baglantiVar ? 'Bagli' : 'Baglaniyor...'),
            ),
          ),
          const SizedBox(height: 8),

          if (arizaKodu != 0)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red, width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ARIZA: ' + arizaMetni(),
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

          if (akimAsiri)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'DIKKAT: Akim limiti asildi (' + akimLimiti.toStringAsFixed(1) + ' A)',
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

          Row(
            children: [
              Expanded(
                child: _durumKarti(
                  baslik: 'Hiz',
                  deger: hiz.toStringAsFixed(0),
                  birim: 'RPM',
                  ikon: Icons.speed,
                  renk: Colors.indigo,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _durumKarti(
                  baslik: 'Akim',
                  deger: akim.toStringAsFixed(1),
                  birim: 'A',
                  ikon: Icons.bolt,
                  renk: akimAsiri ? Colors.red : Colors.orange,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Theme.of(context).dividerColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Hiz Gecmisi', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 80,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _SparklinePainter(hizGecmisi, Colors.indigo),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: motorCalisiyor
                  ? Colors.green.withValues(alpha: 0.12)
                  : Colors.red.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: motorCalisiyor ? Colors.green : Colors.red,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  motorCalisiyor ? Icons.play_circle_fill : Icons.stop_circle,
                  color: motorCalisiyor ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  motorCalisiyor ? 'MOTOR CALISIYOR' : 'MOTOR DURDU',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: motorCalisiyor ? Colors.green.shade700 : Colors.red.shade700,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('BASLAT (ILERI)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: motorCalisiyor
                      ? null
                      : () async {
                          final onay = await _onayIste(
                            'Motoru ileri yonde calistirmak istediginize emin misiniz?',
                          );
                          if (onay) motoruBaslat();
                        },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.stop),
                  label: const Text('DURDUR'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: motorCalisiyor ? motoruDurdur : null,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.u_turn_left),
                  label: const Text('TERS YON'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: motorCalisiyor
                      ? null
                      : () async {
                          final onay = await _onayIste(
                            'Motoru ters yonde calistirmak istediginize emin misiniz?',
                          );
                          if (onay) motoruTersCalistir();
                        },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('ARIZA SIFIRLA'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: arizaSifirla,
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Theme.of(context).dividerColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Hiz Ayari',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        hizAyari.toStringAsFixed(0) + ' RPM',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.indigo,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: hizAyari,
                    min: 0,
                    max: 1500,
                    divisions: 30,
                    label: hizAyari.toStringAsFixed(0),
                    onChanged: (deger) {
                      setState(() => hizAyari = deger);
                    },
                    onChangeEnd: (deger) {
                      hizGonder(deger);
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Surucunun tum anlik verilerini ve gecmis ariza kayitlarini
          // gosteren ayri sayfaya gecis karti.
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Theme.of(context).dividerColor),
            ),
            child: ListTile(
              leading: const Icon(Icons.assessment_outlined),
              title: const Text('Tum Veriler ve Ariza Kayitlari'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SurucuVerileriEkrani(
                      cihazId: widget.cihazId,
                      hiz: hiz,
                      akim: akim,
                      gerilim: gerilim,
                      sicaklik: sicaklik,
                      arizaKodu: arizaKodu,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _durumKarti({
    required String baslik,
    required String deger,
    required String birim,
    required IconData ikon,
    required Color renk,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(ikon, color: renk, size: 20),
                const SizedBox(width: 6),
                Text(baslik, style: TextStyle(color: Theme.of(context).hintColor)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  deger,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: renk),
                ),
                const SizedBox(width: 4),
                Text(birim, style: TextStyle(color: Theme.of(context).hintColor)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// SÜRÜCÜ VERİLERİ EKRANI
// Bir motora ait TUM anlik verileri (hiz, akim, ve varsa gerilim/sicaklik)
// ve o motorun gecmis ariza kayitlarini (Firestore'daki "arizalar"
// alt koleksiyonundan, en yeniden en eskiye dogru) listeler.
// =====================================================================
class SurucuVerileriEkrani extends StatelessWidget {
  final String cihazId;
  final double hiz;
  final double akim;
  final double? gerilim;
  final double? sicaklik;
  final int arizaKodu;

  const SurucuVerileriEkrani({
    super.key,
    required this.cihazId,
    required this.hiz,
    required this.akim,
    required this.arizaKodu,
    this.gerilim,
    this.sicaklik,
  });

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Surucu Verileri')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.6,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: [
              _veriKarti('Hiz', hiz.toStringAsFixed(0), 'RPM'),
              _veriKarti('Akim', akim.toStringAsFixed(1), 'A'),
              if (gerilim != null) _veriKarti('Gerilim', gerilim!.toStringAsFixed(0), 'V'),
              if (sicaklik != null) _veriKarti('Sicaklik', sicaklik!.toStringAsFixed(0), '°C'),
            ],
          ),

          const SizedBox(height: 12),

          if (arizaKodu != 0)
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red, width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'SU ANKI ARIZA: ' + (arizaKodlari[arizaKodu] ?? 'Bilinmeyen ariza'),
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),
          const Text('Ariza Kayitlari', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('hesaplar')
                .doc(uid)
                .collection('cihazlar')
                .doc(cihazId)
                .collection('arizalar')
                .orderBy('tarih', descending: true)
                .limit(50)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Ariza kayitlari yuklenemedi: ' + snapshot.error.toString()),
                );
              }

              final kayitlar = snapshot.data?.docs ?? [];
              if (kayitlar.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Henuz kayitli bir ariza yok.'),
                );
              }

              return Column(
                children: kayitlar.map((d) {
                  final veri = d.data() as Map<String, dynamic>;
                  final tarih = (veri['tarih'] as Timestamp?)?.toDate();
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.error_outline, color: Colors.red),
                      title: Text(veri['mesaj'] ?? '-'),
                      subtitle: Text(tarih != null ? tarih.toString() : ''),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _veriKarti(String baslik, String deger, String birim) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(baslik, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 4),
            Text('$deger $birim', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}


// =====================================================================
// Basit çizgi grafik (sparkline) çizen özel çizim sınıfı
// =====================================================================
class _SparklinePainter extends CustomPainter {
  final List<double> veriler;
  final Color renk;

  _SparklinePainter(this.veriler, this.renk);

  @override
  void paint(Canvas canvas, Size size) {
    if (veriler.length < 2) {
      final paint = Paint()
        ..color = renk.withValues(alpha: 0.3)
        ..strokeWidth = 2;
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        paint,
      );
      return;
    }

    final maksimum = veriler.reduce((a, b) => a > b ? a : b);
    final minimum = veriler.reduce((a, b) => a < b ? a : b);
    final aralik = (maksimum - minimum).abs() < 0.001 ? 1 : (maksimum - minimum);

    final path = Path();
    for (int i = 0; i < veriler.length; i++) {
      final x = (i / (veriler.length - 1)) * size.width;
      final normalizeDeger = (veriler[i] - minimum) / aralik;
      final y = size.height - (normalizeDeger * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final paint = Paint()
      ..color = renk
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.veriler != veriler;
  }
}

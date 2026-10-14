// Mağaza ayarları ve ürün listesi.
//
// ÜRÜNLERİ GOOGLE E-TABLODAN YÖNETMEK İÇİN:
//   Google E-Tablolar'da "Dosya > Paylaş > Web'de yayınla > CSV" ile aldığınız bağlantıyı
//   aşağıya yapıştırın. Bağlantı doluysa ürünler tablodan okunur, aşağıdaki URUNLER listesi
//   yalnızca tabloya ulaşılamazsa yedek olarak kullanılır. Ayrıntılar: URUN-YONETIMI.md
const GOOGLE_TABLO_CSV = '';

const KATEGORILER = [
  { id: 'jenerator', ad: 'Jeneratörler', ikon: '⚡', aciklama: 'Benzinli, dizel, portatif ve kabinli' },
  { id: 'yedek-parca', ad: 'Yedek Parça', ikon: '🔩', aciklama: 'AVR, kontrol modülü, governör, pikap' },
  { id: 'ats-pano', ad: 'ATS & Kontrol Panoları', ikon: '🔌', aciklama: 'Otomatik transfer ve kumanda panoları' },
  { id: 'bakim-servis', ad: 'Bakım & Servis', ikon: '🛠️', aciklama: 'Periyodik bakım ve arıza servisi' },
];

// Yedek ürün listesi (tablo bağlantısı yoksa bunlar gösterilir).
//   fiyat: TL cinsinden sayı. null ise "Fiyat Sorunuz" ve "Teklif Al" gösterilir.
//   gorsel: images/ klasöründeki dosya adı ya da tam bir internet bağlantısı.
//   ornek: true olan ürünler ÖRNEKTİR — gerçek ürün ve fiyatlarla değiştirilmelidir.
const URUNLER = [
  { kategori: 'jenerator', ad: 'Benzinli Portatif Jeneratör 3 kVA Monofaze', fiyat: 18500, gorsel: 'novagen-logo-jenerator.jpg', ozellikler: ['Güç: 3 kVA', 'Faz: Monofaze', 'Yakıt: Benzin', 'Marş: İpli + Elektrikli'], ornek: true },
  { kategori: 'jenerator', ad: 'Dizel Portatif Jeneratör 10 kVA Monofaze', fiyat: 74000, gorsel: 'jenerator-kurulum-bahce.jpg', ozellikler: ['Güç: 10 kVA', 'Faz: Monofaze', 'Yakıt: Dizel', 'Marş: Elektrikli'], ornek: true },
  { kategori: 'jenerator', ad: 'Kabinli Dizel Jeneratör 10 kVA Trifaze', fiyat: 98000, gorsel: 'jenerator-nakliye.jpg', ozellikler: ['Güç: 10 kVA', 'Faz: Trifaze', 'Ses yalıtımlı kabin', 'Otomatik transfer uyumlu'], ornek: true },
  { kategori: 'jenerator', ad: 'Sabit Tip Dizel Jeneratör (20 - 500 kVA)', fiyat: null, gorsel: 'jenerator-bakim-2.jpg', ozellikler: ['Projeye özel güç seçimi', 'Montaj ve devreye alma dahil teklif', 'Yerinde keşif'], ornek: true },

  { kategori: 'yedek-parca', ad: 'Jeneratör AVR (Voltaj Regülatörü) Monofaze', fiyat: 2450, gorsel: '', ozellikler: ['Monofaze alternatörler için', '220V çıkış'], ornek: true },
  { kategori: 'yedek-parca', ad: 'Jeneratör AVR (Voltaj Regülatörü) Trifaze', fiyat: 3900, gorsel: '', ozellikler: ['Trifaze alternatörler için', '380V çıkış'], ornek: true },
  { kategori: 'yedek-parca', ad: 'Jeneratör Otomatik Kontrol Modülü', fiyat: 11500, gorsel: '', ozellikler: ['Otomatik çalıştırma / durdurma', 'Şebeke ve jeneratör izleme', 'LCD ekran'], ornek: true },
  { kategori: 'yedek-parca', ad: 'Elektronik Governör (Hız Kontrol Ünitesi)', fiyat: 8200, gorsel: '', ozellikler: ['12/24V DC', 'Devir sabitleme'], ornek: true },
  { kategori: 'yedek-parca', ad: 'Manyetik Pikap (Magnetic Pick-up)', fiyat: 3100, gorsel: '', ozellikler: ['Devir algılama sensörü', 'Farklı diş ölçüleri mevcuttur'], ornek: true },
  { kategori: 'yedek-parca', ad: 'Stop Selenoid Bobini 12V', fiyat: 1650, gorsel: '', ozellikler: ['12V DC', 'Yakıt kesme selenoidi'], ornek: true },
  { kategori: 'yedek-parca', ad: 'Jeneratör Akü Şarj Cihazı 12V / 24V', fiyat: 2900, gorsel: '', ozellikler: ['12V / 24V seçilebilir', 'Pano montajlı'], ornek: true },
  { kategori: 'yedek-parca', ad: 'Jeneratör Blok Isıtıcı Rezistans', fiyat: 2350, gorsel: '', ozellikler: ['Soğuk havada kolay ilk hareket', 'Termostatlı'], ornek: true },

  { kategori: 'ats-pano', ad: 'Otomatik Transfer Panosu (ATS) Trifaze', fiyat: 16500, gorsel: 'elektrik-dagitim-panosu.jpg', ozellikler: ['Şebeke - jeneratör otomatik geçiş', 'Kontaktör + kontrol modülü', 'Güce göre boyutlandırılır'], ornek: true },
  { kategori: 'ats-pano', ad: 'Jeneratör Kumanda Panosu (Projeye Özel)', fiyat: null, gorsel: 'novagen-saha-bakim.jpg', ozellikler: ['Mevcut jeneratöre uyumlu', 'Montaj ve devreye alma'], ornek: true },

  { kategori: 'bakim-servis', ad: 'Periyodik Jeneratör Bakım Paketi', fiyat: null, gorsel: 'generator-bakim-1.jpg', ozellikler: ['Yağ ve filtre değişimi', 'Akü ve şarj kontrolü', 'Soğutma sistemi kontrolü', 'Yük testi'], ornek: true },
  { kategori: 'bakim-servis', ad: 'Jeneratör Arıza Tespit ve Onarım Servisi', fiyat: null, gorsel: 'teslimat-el-sikisma.jpg', ozellikler: ['Yerinde arıza tespiti', 'Onarım ve parça değişimi'], ornek: true },
];

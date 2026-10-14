// Mağaza ürün listesi.
// Yeni ürün eklemek için bu listeye bir satır eklemeniz yeterli.
//   fiyat: TL cinsinden sayı. null bırakılırsa "Fiyat Sorunuz" gösterilir ve sepete eklenemez.
//   gorsel: images/ klasöründeki dosya adı (boş bırakılırsa kategori ikonu gösterilir).
//   ornek: true olan ürünler ÖRNEKTİR — gerçek ürün ve fiyatlarla değiştirilmelidir.

const KATEGORILER = [
  { id: 'jenerator', ad: 'Jeneratörler', ikon: '⚡', aciklama: 'Benzinli, dizel ve kabinli jeneratörler' },
  { id: 'yedek-parca', ad: 'Jeneratör Yedek Parça', ikon: '🔩', aciklama: 'AVR, kontrol modülü, governör, pikap' },
  { id: 'otomasyon', ad: 'Otomasyon & Pano', ikon: '🛠️', aciklama: 'ATS panoları, sürücü ve kumanda ürünleri' },
  { id: 'ges', ad: 'GES Ürünleri', ikon: '☀️', aciklama: 'Güneş paneli, inverter ve aksesuarlar' },
];

const URUNLER = [
  { id: 'jen-benzinli-3', kategori: 'jenerator', ad: 'Benzinli Portatif Jeneratör 3 kVA Monofaze', fiyat: 18500, gorsel: 'novagen-logo-jenerator.jpg', ozellikler: ['Güç: 3 kVA', 'Faz: Monofaze', 'Yakıt: Benzin', 'Marş: İpli + Elektrikli'], ornek: true },
  { id: 'jen-dizel-10', kategori: 'jenerator', ad: 'Dizel Portatif Jeneratör 10 kVA Monofaze', fiyat: 74000, gorsel: 'jenerator-kurulum-bahce.jpg', ozellikler: ['Güç: 10 kVA', 'Faz: Monofaze', 'Yakıt: Dizel', 'Marş: Elektrikli'], ornek: true },
  { id: 'jen-kabinli-10t', kategori: 'jenerator', ad: 'Kabinli Dizel Jeneratör 10 kVA Trifaze', fiyat: 98000, gorsel: 'jenerator-nakliye.jpg', ozellikler: ['Güç: 10 kVA', 'Faz: Trifaze', 'Ses yalıtımlı kabin', 'Otomatik transfer uyumlu'], ornek: true },
  { id: 'jen-sabit-ozel', kategori: 'jenerator', ad: 'Sabit Tip Dizel Jeneratör (20 - 500 kVA)', fiyat: null, gorsel: 'generator-bakim-1.jpg', ozellikler: ['Projeye özel güç seçimi', 'Montaj ve devreye alma dahil teklif', 'Yerinde keşif'], ornek: true },

  { id: 'avr-mono', kategori: 'yedek-parca', ad: 'Jeneratör AVR (Voltaj Regülatörü) Monofaze', fiyat: 2450, gorsel: '', ozellikler: ['Monofaze alternatörler için', '220V çıkış'], ornek: true },
  { id: 'avr-tri', kategori: 'yedek-parca', ad: 'Jeneratör AVR (Voltaj Regülatörü) Trifaze', fiyat: 3900, gorsel: '', ozellikler: ['Trifaze alternatörler için', '380V çıkış'], ornek: true },
  { id: 'kontrol-modulu', kategori: 'yedek-parca', ad: 'Jeneratör Otomatik Kontrol Modülü', fiyat: 11500, gorsel: '', ozellikler: ['Otomatik çalıştırma / durdurma', 'Şebeke ve jeneratör izleme', 'LCD ekran'], ornek: true },
  { id: 'governor', kategori: 'yedek-parca', ad: 'Elektronik Governör (Hız Kontrol Ünitesi)', fiyat: 8200, gorsel: '', ozellikler: ['12/24V DC', 'Devir sabitleme'], ornek: true },
  { id: 'pikap', kategori: 'yedek-parca', ad: 'Manyetik Pikap (Magnetic Pick-up)', fiyat: 3100, gorsel: '', ozellikler: ['Devir algılama sensörü', 'Farklı diş ölçüleri mevcuttur'], ornek: true },
  { id: 'stop-selenoid', kategori: 'yedek-parca', ad: 'Stop Selenoid Bobini 12V', fiyat: 1650, gorsel: '', ozellikler: ['12V DC', 'Yakıt kesme selenoidi'], ornek: true },
  { id: 'aku-sarj', kategori: 'yedek-parca', ad: 'Jeneratör Akü Şarj Cihazı 12V / 24V', fiyat: 2900, gorsel: '', ozellikler: ['12V / 24V seçilebilir', 'Pano montajlı'], ornek: true },
  { id: 'blok-isitici', kategori: 'yedek-parca', ad: 'Jeneratör Blok Isıtıcı Rezistans', fiyat: 2350, gorsel: '', ozellikler: ['Soğuk havada kolay ilk hareket', 'Termostatlı'], ornek: true },

  { id: 'ats-pano', kategori: 'otomasyon', ad: 'Otomatik Transfer Panosu (ATS) Trifaze', fiyat: 16500, gorsel: 'elektrik-panosu-1.jpg', ozellikler: ['Şebeke - jeneratör otomatik geçiş', 'Kontaktör + kontrol modülü', 'Güce göre boyutlandırılır'], ornek: true },
  { id: 'ac-surucu', kategori: 'otomasyon', ad: 'AC Motor Sürücü (Hız Kontrol Cihazı)', fiyat: null, gorsel: 'otomasyon-panosu-1.jpg', ozellikler: ['Motor gücüne göre seçim', 'Kurulum ve parametre ayarı hizmeti'], ornek: true },
  { id: 'kumanda-panosu', kategori: 'otomasyon', ad: 'Projeye Özel Otomasyon / Kumanda Panosu', fiyat: null, gorsel: 'otomasyon-yazilim-plc.jpg', ozellikler: ['PLC programlama', 'Anahtar teslim kurulum'], ornek: true },

  { id: 'ges-panel', kategori: 'ges', ad: 'Monokristal Güneş Paneli 550W', fiyat: 4800, gorsel: 'ges-panel-sahada.jpg', ozellikler: ['Güç: 550W', 'Tip: Monokristal', 'Half-cut hücre'], ornek: true },
  { id: 'ges-inverter', kategori: 'ges', ad: 'Hibrit Solar İnverter 5 kW', fiyat: 32000, gorsel: 'ges-elektrik-kutusu.jpg', ozellikler: ['Güç: 5 kW', 'Akü destekli hibrit çalışma', 'MPPT şarj kontrolü'], ornek: true },
  { id: 'ges-anahtar-teslim', kategori: 'ges', ad: 'Anahtar Teslim GES Kurulumu', fiyat: null, gorsel: 'ges-kurulum-1.jpg', ozellikler: ['Keşif ve projelendirme', 'Malzeme + montaj', 'Devreye alma'], ornek: true },
];

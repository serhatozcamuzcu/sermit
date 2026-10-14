# Ürünleri kendiniz nasıl eklersiniz / çıkarırsınız?

Mağazadaki ürünler bir **Google E-Tablo**'dan okunur. Tabloyu telefondan ya da bilgisayardan
düzenlediğinizde site birkaç dakika içinde kendiliğinden güncellenir. Kod bilmeniz gerekmez.

## Bir kerelik kurulum

1. [sheets.google.com](https://sheets.google.com) adresinde yeni, boş bir tablo açın.
2. **Dosya > İçe aktar > Yükle** ile bu klasördeki `urun-tablosu-sablon.csv` dosyasını yükleyin
   ("Geçerli sayfayı değiştir" seçeneğiyle).
3. **Dosya > Paylaş > Web'de yayınla** menüsünü açın:
   - "Tüm doküman" yerine ürünlerin olduğu sayfayı seçin,
   - biçim olarak **Virgülle ayrılmış değerler (.csv)** seçin,
   - **Yayınla**'ya basın ve çıkan bağlantıyı kopyalayın.
4. Bu bağlantıyı Claude'a gönderin (ya da `products.js` dosyasındaki `GOOGLE_TABLO_CSV = ''`
   tırnaklarının arasına yapıştırın). Bu adım yalnızca bir kez yapılır.

## Sütunlar

| Sütun | Ne yazılır |
|---|---|
| **Kategori** | `Jeneratörler`, `Yedek Parça`, `ATS & Kontrol Panoları` veya `Bakım & Servis`. Yeni bir ad yazarsanız mağazada yeni kategori olarak çıkar. |
| **Ürün Adı** | Ürünün adı. Boş satırlar gösterilmez. |
| **Fiyat** | KDV dahil TL fiyatı, ör. `18.500` veya `18.500,50`. **Boş bırakırsanız** ürün "Fiyat Sorunuz" olarak çıkar ve "Teklif Al" butonu WhatsApp'a yönlendirir. |
| **Özellikler** | Noktalı virgülle ayırın: `Güç: 10 kVA; Faz: Trifaze; Yakıt: Dizel` |
| **Görsel** | Fotoğraf bağlantısı (aşağıya bakın). Boşsa kategori ikonu gösterilir. |
| **Yayında** | `Evet` ya da boş = sitede görünür. `Hayır` = gizlenir (satırı silmeden ürünü kaldırmak için). |

## Fotoğraf ekleme

1. Fotoğrafı Google Drive'a yükleyin.
2. Fotoğrafa sağ tıklayın > **Paylaş** > Genel erişim: **Bağlantıya sahip olan herkes**.
3. **Bağlantıyı kopyala** deyip tablodaki **Görsel** hücresine yapıştırın.

## Sık yapılanlar

- **Fiyat değiştirmek:** Fiyat hücresini değiştirin.
- **Ürünü kaldırmak:** Yayında sütununa `Hayır` yazın veya satırı silin.
- **Yeni ürün:** En alta yeni bir satır ekleyin.

Not: Google yayınlanan tabloyu birkaç dakikada bir yeniler; değişiklik siteye 5 dakika kadar
içinde yansır.

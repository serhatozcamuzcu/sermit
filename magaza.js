const WHATSAPP_NUMARA = '905353073060';
const SEPET_ANAHTARI = 'novagen-sepet';

document.getElementById('year').textContent = new Date().getFullYear();

const paraBicimi = new Intl.NumberFormat('tr-TR', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
const tl = (tutar) => `${paraBicimi.format(tutar)} TL`;

const kategoriBul = (id) => KATEGORILER.find((k) => k.id === id);
const urunBul = (id) => URUNLER.find((u) => u.id === id);

function escapeHtml(metin) {
  return String(metin).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

function whatsappLink(mesaj) {
  return `https://wa.me/${WHATSAPP_NUMARA}?text=${encodeURIComponent(mesaj)}`;
}

function urunGorseli(urun) {
  if (urun.gorsel) {
    return `<img src="images/${escapeHtml(urun.gorsel)}" alt="${escapeHtml(urun.ad)}" loading="lazy">`;
  }
  return `<span class="product-placeholder">${kategoriBul(urun.kategori)?.ikon || '📦'}</span>`;
}

/* ---------- Sepet ---------- */

function sepetiOku() {
  try {
    const kayit = JSON.parse(localStorage.getItem(SEPET_ANAHTARI) || '[]');
    return Array.isArray(kayit) ? kayit.filter((s) => urunBul(s.id)?.fiyat != null && s.adet > 0) : [];
  } catch {
    return [];
  }
}

let sepet = sepetiOku();

function sepetiKaydet() {
  try {
    localStorage.setItem(SEPET_ANAHTARI, JSON.stringify(sepet));
  } catch {
    // Tarayıcı depolaması kapalıysa sepet yalnızca bu sayfa açıkken tutulur.
  }
  sepetiCiz();
}

const sepetToplami = () => sepet.reduce((t, s) => t + urunBul(s.id).fiyat * s.adet, 0);

function sepeteEkle(id) {
  const satir = sepet.find((s) => s.id === id);
  if (satir) satir.adet += 1;
  else sepet.push({ id, adet: 1 });
  sepetiKaydet();
  bildirimGoster('Ürün sepete eklendi');
}

function adetDegistir(id, fark) {
  const satir = sepet.find((s) => s.id === id);
  if (!satir) return;
  satir.adet += fark;
  if (satir.adet <= 0) sepet = sepet.filter((s) => s.id !== id);
  sepetiKaydet();
}

const cartItems = document.getElementById('cartItems');

function sepetiCiz() {
  const adet = sepet.reduce((t, s) => t + s.adet, 0);
  const toplam = tl(sepetToplami());
  document.getElementById('cartCount').textContent = adet;
  document.getElementById('cartTotalHeader').textContent = toplam;
  document.getElementById('cartTotal').textContent = toplam;
  document.getElementById('cartEmpty').hidden = sepet.length > 0;
  document.getElementById('checkoutButton').disabled = sepet.length === 0;

  cartItems.innerHTML = sepet.map((s) => {
    const urun = urunBul(s.id);
    return `
      <li class="cart-item">
        <div class="cart-thumb">${urunGorseli(urun)}</div>
        <div class="cart-item-info">
          <p>${escapeHtml(urun.ad)}</p>
          <strong>${tl(urun.fiyat * s.adet)}</strong>
          <div class="qty">
            <button data-adet="-1" data-id="${urun.id}" aria-label="Azalt">−</button>
            <span>${s.adet}</span>
            <button data-adet="1" data-id="${urun.id}" aria-label="Arttır">+</button>
          </div>
        </div>
      </li>`;
  }).join('');
}

cartItems.addEventListener('click', (e) => {
  const buton = e.target.closest('button[data-id]');
  if (buton) adetDegistir(buton.dataset.id, Number(buton.dataset.adet));
});

/* ---------- Sepet çekmecesi ve sipariş ---------- */

const drawer = document.getElementById('cartDrawer');
const backdrop = document.getElementById('drawerBackdrop');
const checkoutForm = document.getElementById('checkoutForm');

function odemeAdimi(acik) {
  document.getElementById('cartView').hidden = acik;
  checkoutForm.hidden = !acik;
  document.getElementById('checkoutButton').hidden = acik;
  document.getElementById('sendOrderButton').hidden = !acik;
  document.getElementById('backToCart').hidden = !acik;
  document.getElementById('drawerTitle').textContent = acik ? 'Sipariş Bilgileri' : 'Sepetim';
}

function cekmeceyiAc() {
  odemeAdimi(false);
  drawer.classList.add('open');
  drawer.setAttribute('aria-hidden', 'false');
  backdrop.hidden = false;
  document.body.classList.add('no-scroll');
}

function cekmeceyiKapat() {
  drawer.classList.remove('open');
  drawer.setAttribute('aria-hidden', 'true');
  backdrop.hidden = true;
  document.body.classList.remove('no-scroll');
}

document.getElementById('cartButton').addEventListener('click', cekmeceyiAc);
document.getElementById('drawerClose').addEventListener('click', cekmeceyiKapat);
backdrop.addEventListener('click', cekmeceyiKapat);
document.getElementById('checkoutButton').addEventListener('click', () => odemeAdimi(true));
document.getElementById('backToCart').addEventListener('click', () => odemeAdimi(false));

checkoutForm.addEventListener('submit', (e) => {
  e.preventDefault();
  if (!sepet.length) return;
  const veri = new FormData(checkoutForm);
  const siparisNo = `NV${Date.now().toString().slice(-8)}`;
  const satirlar = sepet.map((s) => {
    const urun = urunBul(s.id);
    return `• ${s.adet} x ${urun.ad} — ${tl(urun.fiyat * s.adet)}`;
  });
  const mesaj = [
    `Merhaba, web sitesinden sipariş vermek istiyorum.`,
    `Sipariş No: ${siparisNo}`,
    '',
    ...satirlar,
    '',
    `Toplam: ${tl(sepetToplami())}`,
    '',
    `Ad Soyad: ${veri.get('ad')}`,
    `Telefon: ${veri.get('telefon')}`,
    `Adres: ${veri.get('adres')}`,
    `Ödeme: ${veri.get('odeme')}`,
    veri.get('not') ? `Not: ${veri.get('not')}` : '',
  ].filter((satir, i, dizi) => satir !== '' || dizi[i - 1] !== '').join('\n');

  window.open(whatsappLink(mesaj), '_blank', 'noopener');
  sepet = [];
  sepetiKaydet();
  checkoutForm.reset();
  cekmeceyiKapat();
  bildirimGoster(`Siparişiniz (${siparisNo}) WhatsApp'a aktarıldı`);
});

/* ---------- Ürün listesi ---------- */

let seciliKategori = 'hepsi';
let aramaMetni = '';

const productGrid = document.getElementById('productGrid');

function urunKarti(urun) {
  const fiyatVar = urun.fiyat != null;
  return `
    <article class="product-card" data-id="${urun.id}">
      <button class="product-media" data-detay="${urun.id}" aria-label="${escapeHtml(urun.ad)} detay">
        ${urunGorseli(urun)}
        ${urun.ornek ? '<span class="badge">Örnek ürün</span>' : ''}
      </button>
      <div class="product-body">
        <p class="product-category">${escapeHtml(kategoriBul(urun.kategori)?.ad || '')}</p>
        <h3><button data-detay="${urun.id}">${escapeHtml(urun.ad)}</button></h3>
        <p class="product-price">${fiyatVar ? tl(urun.fiyat) : 'Fiyat Sorunuz'}</p>
        ${fiyatVar
          ? `<button class="btn btn-primary btn-block" data-sepet="${urun.id}">Sepete Ekle</button>`
          : `<a class="btn btn-dark btn-block" href="${whatsappLink(`Merhaba, "${urun.ad}" için fiyat/teklif almak istiyorum.`)}" target="_blank" rel="noopener">Teklif Al</a>`}
      </div>
    </article>`;
}

function trKucuk(metin) {
  return metin.toLocaleLowerCase('tr-TR');
}

function urunleriCiz() {
  const arama = trKucuk(aramaMetni.trim());
  let liste = URUNLER.filter((u) =>
    (seciliKategori === 'hepsi' || u.kategori === seciliKategori) &&
    (!arama || trKucuk(`${u.ad} ${(u.ozellikler || []).join(' ')}`).includes(arama))
  );

  const siralama = document.getElementById('sortSelect').value;
  if (siralama !== 'onerilen') {
    const yon = siralama === 'artan' ? 1 : -1;
    liste = [...liste].sort((a, b) => {
      if (a.fiyat == null) return 1;
      if (b.fiyat == null) return -1;
      return (a.fiyat - b.fiyat) * yon;
    });
  }

  productGrid.innerHTML = liste.map(urunKarti).join('');
  document.getElementById('emptyNote').hidden = liste.length > 0;
  document.getElementById('productCount').textContent = `${liste.length} ürün`;
  document.getElementById('productsTitle').textContent = aramaMetni.trim()
    ? `"${aramaMetni.trim()}" için sonuçlar`
    : seciliKategori === 'hepsi' ? 'Tüm Ürünler' : kategoriBul(seciliKategori).ad;

  document.querySelectorAll('#categoryNav a').forEach((a) => {
    a.classList.toggle('active', a.dataset.kategori === seciliKategori);
  });
}

function kategoriSec(id) {
  seciliKategori = id;
  aramaMetni = '';
  document.getElementById('searchInput').value = '';
  urunleriCiz();
  document.getElementById('urunler').scrollIntoView({ behavior: 'smooth' });
}

productGrid.addEventListener('click', (e) => {
  const sepetButonu = e.target.closest('[data-sepet]');
  if (sepetButonu) return sepeteEkle(sepetButonu.dataset.sepet);
  const detayButonu = e.target.closest('[data-detay]');
  if (detayButonu) urunDetayAc(detayButonu.dataset.detay);
});

document.getElementById('sortSelect').addEventListener('change', urunleriCiz);

document.getElementById('searchForm').addEventListener('submit', (e) => {
  e.preventDefault();
  aramaMetni = document.getElementById('searchInput').value;
  seciliKategori = 'hepsi';
  urunleriCiz();
  document.getElementById('urunler').scrollIntoView({ behavior: 'smooth' });
});

document.getElementById('searchInput').addEventListener('input', (e) => {
  aramaMetni = e.target.value;
  urunleriCiz();
});

/* ---------- Kategoriler ---------- */

const categoryNav = document.getElementById('categoryNav');
categoryNav.insertAdjacentHTML('beforeend', KATEGORILER.map((k) =>
  `<a href="#urunler" data-kategori="${k.id}">${escapeHtml(k.ad)}</a>`
).join(''));
categoryNav.addEventListener('click', (e) => {
  const link = e.target.closest('a[data-kategori]');
  if (!link) return;
  e.preventDefault();
  kategoriSec(link.dataset.kategori);
});

const categoryCards = document.getElementById('categoryCards');
categoryCards.innerHTML = KATEGORILER.map((k) => `
  <button class="category-card" data-kategori="${k.id}">
    <span class="category-icon">${k.ikon}</span>
    <strong>${escapeHtml(k.ad)}</strong>
    <small>${escapeHtml(k.aciklama)}</small>
  </button>`).join('');
categoryCards.addEventListener('click', (e) => {
  const kart = e.target.closest('[data-kategori]');
  if (kart) kategoriSec(kart.dataset.kategori);
});

/* ---------- Ürün detayı ---------- */

const modal = document.getElementById('productModal');

function urunDetayAc(id) {
  const urun = urunBul(id);
  if (!urun) return;
  document.getElementById('modalMedia').innerHTML = urunGorseli(urun);
  document.getElementById('modalCategory').textContent = kategoriBul(urun.kategori)?.ad || '';
  document.getElementById('modalTitle').textContent = urun.ad;
  document.getElementById('modalPrice').textContent = urun.fiyat != null ? `${tl(urun.fiyat)} (KDV dahil)` : 'Fiyat için teklif alın';
  document.getElementById('modalSpecs').innerHTML = (urun.ozellikler || []).map((o) => `<li>${escapeHtml(o)}</li>`).join('');
  const soruLinki = whatsappLink(`Merhaba, "${urun.ad}" hakkında bilgi almak istiyorum.`);
  document.getElementById('modalActions').innerHTML = urun.fiyat != null
    ? `<button class="btn btn-primary" data-sepet="${urun.id}">Sepete Ekle</button>
       <a class="btn btn-outline" href="${soruLinki}" target="_blank" rel="noopener">WhatsApp'tan Sor</a>`
    : `<a class="btn btn-primary" href="${soruLinki}" target="_blank" rel="noopener">Teklif Al</a>
       <a class="btn btn-outline" href="tel:+905353073060">Hemen Ara</a>`;
  modal.hidden = false;
  document.body.classList.add('no-scroll');
}

function urunDetayKapat() {
  modal.hidden = true;
  if (!drawer.classList.contains('open')) document.body.classList.remove('no-scroll');
}

document.getElementById('modalClose').addEventListener('click', urunDetayKapat);
modal.addEventListener('click', (e) => {
  if (e.target === modal) return urunDetayKapat();
  const sepetButonu = e.target.closest('[data-sepet]');
  if (sepetButonu) {
    sepeteEkle(sepetButonu.dataset.sepet);
    urunDetayKapat();
  }
});

document.addEventListener('keydown', (e) => {
  if (e.key !== 'Escape') return;
  if (!modal.hidden) urunDetayKapat();
  else cekmeceyiKapat();
});

/* ---------- Bildirim ---------- */

const toast = document.getElementById('toast');
let toastZamanlayici;
function bildirimGoster(metin) {
  toast.textContent = metin;
  toast.classList.add('show');
  clearTimeout(toastZamanlayici);
  toastZamanlayici = setTimeout(() => toast.classList.remove('show'), 2400);
}

sepetiCiz();
urunleriCiz();

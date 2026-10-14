const slider = document.getElementById('heroSlider');
if (slider) {
  const slaytlar = Array.from(slider.querySelectorAll('.slide'));
  const noktalar = document.getElementById('sliderDots');
  let aktif = 0;
  let zamanlayici;

  noktalar.innerHTML = slaytlar.map((_, i) => `<button aria-label="${i + 1}. slayt"></button>`).join('');
  const butonlar = Array.from(noktalar.children);

  function goster(i) {
    aktif = (i + slaytlar.length) % slaytlar.length;
    slaytlar.forEach((s, n) => s.classList.toggle('active', n === aktif));
    butonlar.forEach((b, n) => b.classList.toggle('active', n === aktif));
  }

  function baslat() {
    clearInterval(zamanlayici);
    if (!window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      zamanlayici = setInterval(() => goster(aktif + 1), 6000);
    }
  }

  butonlar.forEach((b, i) => b.addEventListener('click', () => { goster(i); baslat(); }));
  goster(0);
  baslat();
}

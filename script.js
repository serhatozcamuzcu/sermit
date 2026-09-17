document.getElementById('year').textContent = new Date().getFullYear();

const preloader = document.getElementById('preloader');
if (preloader) {
  const reducePreloaderMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  document.body.classList.add('preloading');

  const finishPreload = () => {
    preloader.classList.add('hide');
    document.body.classList.remove('preloading');
  };

  preloader.addEventListener('transitionend', () => {
    if (preloader.classList.contains('hide')) preloader.remove();
  });

  if (reducePreloaderMotion) {
    setTimeout(finishPreload, 400);
  } else {
    requestAnimationFrame(() => preloader.classList.add('flicker'));
    setTimeout(finishPreload, 1750);
  }
}

const navToggle = document.getElementById('navToggle');
const nav = document.getElementById('nav');

navToggle.addEventListener('click', () => {
  nav.classList.toggle('open');
});

nav.querySelectorAll('a').forEach((link) => {
  link.addEventListener('click', () => nav.classList.remove('open'));
});

const lightbox = document.getElementById('lightbox');
const lightboxImg = document.getElementById('lightboxImg');
const lightboxClose = document.getElementById('lightboxClose');

document.querySelectorAll('.gallery img').forEach((img) => {
  img.addEventListener('click', () => {
    lightboxImg.src = img.src;
    lightboxImg.alt = img.alt;
    lightbox.classList.add('open');
  });
});

function closeLightbox() {
  lightbox.classList.remove('open');
  lightboxImg.src = '';
}

lightboxClose.addEventListener('click', closeLightbox);
lightbox.addEventListener('click', (e) => {
  if (e.target === lightbox) closeLightbox();
});
document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') closeLightbox();
});

const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
const explodeScenes = Array.from(document.querySelectorAll('.explode-scene')).map((scene) => ({
  el: scene,
  caption: scene.querySelector('.explode-caption'),
  parts: Array.from(scene.querySelectorAll('.part')).map((part) => ({
    el: part,
    tx: parseFloat(part.dataset.tx || '0'),
    ty: parseFloat(part.dataset.ty || '0'),
    rot: parseFloat(part.dataset.rot || '0'),
  })),
}));

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

function updateExplode() {
  const vh = window.innerHeight;
  explodeScenes.forEach(({ el, parts, caption }) => {
    const rect = el.getBoundingClientRect();
    const total = rect.height - vh;
    const progress = total <= 0 ? 0 : clamp(-rect.top / total, 0, 1);
    parts.forEach(({ el: partEl, tx, ty, rot }) => {
      partEl.style.transform = `translate(${tx * progress}%, ${ty * progress}%) rotate(${rot * progress}deg)`;
    });
    if (caption) caption.style.opacity = String(clamp(progress * 2.5, 0, 1));
  });
}

if (explodeScenes.length) {
  if (reduceMotion) {
    explodeScenes.forEach(({ parts, caption }) => {
      parts.forEach(({ el: partEl, tx, ty, rot }) => {
        partEl.style.transform = `translate(${tx * 0.6}%, ${ty * 0.6}%) rotate(${rot * 0.6}deg)`;
      });
      if (caption) caption.style.opacity = '1';
    });
  } else {
    let ticking = false;
    const onScroll = () => {
      if (!ticking) {
        ticking = true;
        requestAnimationFrame(() => {
          updateExplode();
          ticking = false;
        });
      }
    };
    window.addEventListener('scroll', onScroll, { passive: true });
    window.addEventListener('resize', onScroll);
    updateExplode();
  }
}

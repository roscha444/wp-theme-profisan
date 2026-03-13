// Scroll-to-top visibility + admin bar offset fix
(function() {
  var btn = document.querySelector('.scroll-top');
  var header = document.querySelector('.site-header');
  var adminBar = document.getElementById('wpadminbar');

  window.addEventListener('scroll', function() {
    if (btn) {
      if (window.scrollY > 400) {
        btn.classList.add('visible');
      } else {
        btn.classList.remove('visible');
      }
    }
    // On mobile, admin bar is position:absolute and scrolls away
    if (header && adminBar) {
      var barBottom = adminBar.getBoundingClientRect().bottom;
      if (barBottom <= 0) {
        header.classList.add('admin-bar-hidden');
      } else {
        header.classList.remove('admin-bar-hidden');
      }
    }
  });

  if (btn) {
    btn.addEventListener('click', function() {
      window.scrollTo({ top: 0, behavior: 'smooth' });
    });
  }
})();

document.addEventListener('DOMContentLoaded', function () {
  var fadeEls = document.querySelectorAll('.fade-in');
  if (!fadeEls.length) return;

  var observer = new IntersectionObserver(function (entries) {
    entries.forEach(function (entry) {
      if (entry.isIntersecting) {
        entry.target.classList.add('visible');
        observer.unobserve(entry.target);
      }
    });
  }, {
    threshold: 0.15,
    rootMargin: '0px 0px -40px 0px'
  });

  fadeEls.forEach(function (el) {
    observer.observe(el);
  });

  // Leistungen tile toggle
  document.querySelectorAll('.leistung-tile').forEach(function (tile) {
    tile.addEventListener('click', function (e) {
      if (e.target.closest('a')) return;
      var wasActive = tile.classList.contains('active');
      document.querySelectorAll('.leistung-tile.active').forEach(function (t) {
        t.classList.remove('active');
      });
      if (!wasActive) tile.classList.add('active');
    });
  });

  // Marquee: infinite scroll + drag
  var strip = document.querySelector('.marquee-strip');
  var track = document.querySelector('.marquee-track');
  if (strip && track) {
    // Duplicate content for seamless loop
    var original = track.innerHTML;
    track.innerHTML = original + original + original;

    var pos = 0;
    var speed = 0.3;
    var dragging = false;
    var dragStart = 0;
    var dragPos = 0;
    var halfWidth = 0;

    function measure() {
      halfWidth = track.scrollWidth / 3;
    }
    measure();

    function loop() {
      if (!dragging) {
        pos -= speed;
      }
      // Wrap seamlessly
      if (pos <= -halfWidth) pos += halfWidth;
      if (pos > 0) pos -= halfWidth;
      track.style.transform = 'translateX(' + pos + 'px)';
      requestAnimationFrame(loop);
    }
    requestAnimationFrame(loop);

    strip.addEventListener('mousedown', function (e) {
      dragging = true;
      dragStart = e.clientX;
      dragPos = pos;
    });
    window.addEventListener('mousemove', function (e) {
      if (!dragging) return;
      pos = dragPos + (e.clientX - dragStart);
    });
    window.addEventListener('mouseup', function () {
      dragging = false;
    });

    // Touch support
    strip.addEventListener('touchstart', function (e) {
      dragging = true;
      dragStart = e.touches[0].clientX;
      dragPos = pos;
    });
    strip.addEventListener('touchmove', function (e) {
      if (!dragging) return;
      pos = dragPos + (e.touches[0].clientX - dragStart);
    });
    strip.addEventListener('touchend', function () {
      dragging = false;
    });
  }
});

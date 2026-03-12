// Scroll-to-top visibility
(function() {
  var btn = document.querySelector('.scroll-top');
  if (btn) {
    window.addEventListener('scroll', function() {
      if (window.scrollY > 400) {
        btn.classList.add('visible');
      } else {
        btn.classList.remove('visible');
      }
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
});

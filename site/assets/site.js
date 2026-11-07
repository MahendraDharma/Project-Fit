// Progressive enhancement only: every piece of content is visible without this
// file. It fades in a few blocks on scroll, swaps the tour phone's screen to
// follow the step in view, and closes the language menu on an outside click.
(function () {
  var root = document.documentElement;
  root.classList.remove('no-js');
  root.classList.add('js');
  if (!('IntersectionObserver' in window)) {
    root.classList.remove('js');
    return;
  }

  // One fade and rise per block, once.
  var reveal = new IntersectionObserver(function (es) {
    es.forEach(function (e) {
      if (e.isIntersecting) {
        e.target.classList.add('in');
        reveal.unobserve(e.target);
      }
    });
  }, { rootMargin: '0px 0px -10% 0px' });
  document.querySelectorAll('[data-reveal]').forEach(function (el) {
    reveal.observe(el);
  });

  // The tour's text rises in as each step reaches the screen.
  var seen = new IntersectionObserver(function (es) {
    es.forEach(function (e) {
      if (e.isIntersecting) {
        e.target.classList.add('seen');
        seen.unobserve(e.target);
      }
    });
  }, { rootMargin: '0px 0px -15% 0px' });
  document.querySelectorAll('.step').forEach(function (el) { seen.observe(el); });

  // The mochi hops once as the hero settles, and again on a tap or hover of
  // the phone, as it does when tapped in the app.
  var mochi = document.querySelector('.mochi');
  var device = document.querySelector('.device');
  function hop() {
    if (!mochi) return;
    mochi.classList.remove('play');
    void mochi.offsetWidth; // restart the animation
    mochi.classList.add('play');
  }
  if (mochi) {
    setTimeout(hop, 700);
    mochi.addEventListener('animationend', function () { mochi.classList.remove('play'); }, true);
    if (device) {
      device.addEventListener('mouseenter', hop);
      device.addEventListener('click', hop);
    }
  }

  // The tour phone follows the step in the middle of the viewport.
  var shots = document.querySelectorAll('.screen img');
  var steps = document.querySelectorAll('.step');
  function show(i) {
    shots.forEach(function (s, j) { s.classList.toggle('on', j === i); });
    steps.forEach(function (s, j) { s.classList.toggle('active', j === i); });
  }
  if (shots.length) show(0);
  var follow = new IntersectionObserver(function (es) {
    es.forEach(function (e) {
      if (e.isIntersecting) show(Number(e.target.getAttribute('data-step')));
    });
  // On a phone the pinned phone covers the top half, so the line that picks
  // the step sits near three quarters of the screen.
  }, { rootMargin: window.matchMedia('(max-width: 960px)').matches
      ? '-72% 0px -24% 0px' : '-45% 0px -45% 0px' });
  steps.forEach(function (s) { follow.observe(s); });

  document.addEventListener('click', function (e) {
    document.querySelectorAll('details.lang[open]').forEach(function (d) {
      if (!d.contains(e.target)) d.removeAttribute('open');
    });
  });
})();

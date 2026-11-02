// Progressive enhancement only: every piece of content is visible without this
// file. It adds reveal-on-scroll (a few elements, not every section), swaps the
// phone screen to follow the feature step in view, and counts the facts up.
(function () {
  var root = document.documentElement;
  root.classList.remove('no-js');
  root.classList.add('js');
  var still = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  if (!('IntersectionObserver' in window)) {
    root.classList.remove('js');
    return;
  }

  // Reveal.
  var reveal = new IntersectionObserver(function (es) {
    es.forEach(function (e) {
      if (e.isIntersecting) {
        e.target.classList.add('in');
        reveal.unobserve(e.target);
      }
    });
  }, { rootMargin: '0px 0px -10% 0px' });
  document.querySelectorAll('[data-reveal], .step').forEach(function (el) {
    reveal.observe(el);
  });

  // The phone follows the step in the middle of the viewport.
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
  // The line that picks the step: mid-screen on a wide screen, and on a phone
  // below the pinned phone (which covers the top half), near three quarters.
  }, { rootMargin: window.matchMedia('(max-width: 900px)').matches
      ? '-72% 0px -24% 0px' : '-45% 0px -45% 0px' });
  steps.forEach(function (s) { follow.observe(s); });

  // Facts count up once.
  var count = new IntersectionObserver(function (es) {
    es.forEach(function (e) {
      if (!e.isIntersecting) return;
      count.unobserve(e.target);
      var el = e.target, to = Number(el.getAttribute('data-count'));
      var fmt = el.getAttribute('data-format') || '{n}';
      var loc = root.lang || 'en';
      function put(n) { el.textContent = fmt.replace('{n}', Math.round(n).toLocaleString(loc)); }
      if (still || to === 0) { put(to); return; }
      var t0 = null;
      function tick(t) {
        if (t0 === null) t0 = t;
        var k = Math.min(1, (t - t0) / 1200);
        put(to * (1 - Math.pow(1 - k, 3)));
        if (k < 1) requestAnimationFrame(tick);
      }
      requestAnimationFrame(tick);
    });
  });
  document.querySelectorAll('[data-count]').forEach(function (el) { count.observe(el); });

  // Close the language menu on outside click.
  document.addEventListener('click', function (e) {
    document.querySelectorAll('details.lang[open]').forEach(function (d) {
      if (!d.contains(e.target)) d.removeAttribute('open');
    });
  });
})();

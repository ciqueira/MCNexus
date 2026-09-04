/*
 * Hero background field.
 *
 * Every constant below is read off the Nexus symbol
 * (assets/brands/mcnexus/nexus-symbol.svg): the mark is eight grey dots and
 * three coloured squares, arranged on a diagonal that runs from the darkest
 * dot at the bottom left to the lightest one at the top right. The field
 * reuses the same shapes, the same palette and the same axis.
 *
 * Particles are emitted from the lower-left corner of the hero copy — the
 * foot of the headline block, measured from the DOM, so the origin follows
 * the layout instead of the window. They climb across the text and resolve
 * into the surface colour as they go. Because the path crosses the words,
 * they enter faint and only gain presence further along: MAX_ALPHA and
 * FADE_IN are the two knobs for that balance.
 */
(function () {
  "use strict";

  var canvas = document.querySelector("[data-hero-field]");
  if (!canvas || !canvas.getContext) return;

  var ctx = canvas.getContext("2d", { alpha: true });
  if (!ctx) return;

  var copy = canvas.parentNode && canvas.parentNode.querySelector(".hero-copy");

  /* Axis of the mark: darkest dot (183, 804) to lightest dot (841, 221). */
  var ANGLE = Math.atan2(221 - 804, 841 - 183);
  var AXIS_X = Math.cos(ANGLE);
  var AXIS_Y = Math.sin(ANGLE);
  /* Perpendicular to the axis, for scattering around the origin. */
  var PERP_X = -AXIS_Y;
  var PERP_Y = AXIS_X;

  /* Grey ramp of the eight dots, darkest first. */
  var DOT_GREYS = [
    [44, 44, 44],
    [44, 44, 44],
    [62, 62, 62],
    [73, 72, 73],
    [73, 73, 73],
    [73, 73, 73],
    [103, 103, 102],
    [103, 105, 104]
  ];

  /* The three squares of the mark. */
  var SQUARE_COLORS = [
    [92, 175, 250],
    [94, 224, 161],
    [250, 184, 71]
  ];

  /* Where every particle ends up: the surface colour of the site. */
  var RESOLVE = [34, 34, 34];

  var SQUARE_SHARE = 0.17;
  var MIN_PARTICLES = 40;
  var MAX_PARTICLES = 160;
  var AREA_PER_PARTICLE = 9000;

  /* How far past the origin the field stays dense, in pixels. Particles are
   * sampled across the whole hero and kept with a probability that decays
   * along the axis, so the foot of the copy reads as the source while every
   * corner still has traffic. Small values concentrate; large ones flatten
   * into a uniform field with no visible origin. */
  var FALLOFF = 900;

  /* The path crosses the headline, so nothing reaches full opacity. */
  var MAX_ALPHA = 0.72;
  var FADE_IN = 0.34;
  var FADE_OUT = 0.3;

  var reduceMotion = window.matchMedia
    ? window.matchMedia("(prefers-reduced-motion: reduce)")
    : null;

  var particles = [];
  var width = 0;
  var height = 0;
  var margin = 40;
  var originX = 0;
  var originY = 0;
  var rafId = null;
  var lastTime = 0;
  var visible = true;

  function rand(min, max) {
    return min + Math.random() * (max - min);
  }

  function pick(list) {
    return list[(Math.random() * list.length) | 0];
  }

  function makeParticle(p, seeded) {
    var isSquare = Math.random() < SQUARE_SHARE;

    p.square = isSquare;
    p.size = isSquare ? rand(4, 13) : rand(2.2, 7);
    p.speed = rand(8, 30);
    /* A few degrees of scatter keeps the field from reading as one sheet. */
    p.drift = rand(-0.11, 0.11);
    p.color = isSquare ? pick(SQUARE_COLORS) : pick(DOT_GREYS);
    p.span = rand(14, 34);
    p.dx = Math.cos(ANGLE + p.drift);
    p.dy = Math.sin(ANGLE + p.drift);

    /* Rejection sampling over the whole hero: a candidate is kept with a
     * probability that falls off along the axis, measured from the origin.
     * An emitter that only fires from an edge piles everything into the
     * corner it fires from — this fills the frame instead, and still reads
     * as coming from the foot of the copy. */
    p.x = originX;
    p.y = originY;
    for (var tries = 0; tries < 12; tries++) {
      var cx = rand(-margin, width + margin);
      var cy = rand(-margin, height + margin);
      var along = (cx - originX) * AXIS_X + (cy - originY) * AXIS_Y;
      if (Math.random() < Math.exp(-Math.max(0, along) / FALLOFF)) {
        p.x = cx;
        p.y = cy;
        break;
      }
    }

    /* Seeded particles are spread through their lifetimes so the first frame
     * shows a field in flight. A respawn always starts at zero, so it fades
     * in where it appears instead of popping in at full opacity. */
    p.life = seeded ? rand(0, p.span * 0.85) : 0;
    p.x += p.dx * p.speed * p.life;
    p.y += p.dy * p.speed * p.life;

    return p;
  }

  function measure() {
    var rect = canvas.getBoundingClientRect();
    if (!rect.width || !rect.height) return false;

    width = rect.width;
    height = rect.height;

    if (copy) {
      var box = copy.getBoundingClientRect();
      originX = box.left - rect.left;
      originY = box.bottom - rect.top;
    } else {
      originX = 0;
      originY = height;
    }

    return true;
  }

  function resize() {
    if (!measure()) return;

    var dpr = Math.min(window.devicePixelRatio || 1, 2);
    canvas.width = Math.round(width * dpr);
    canvas.height = Math.round(height * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);

    var target = Math.round((width * height) / AREA_PER_PARTICLE);
    target = Math.max(MIN_PARTICLES, Math.min(MAX_PARTICLES, target));

    while (particles.length > target) particles.pop();
    while (particles.length < target) particles.push(makeParticle({}, true));
  }

  function draw() {
    ctx.clearRect(0, 0, width, height);

    for (var i = 0; i < particles.length; i++) {
      var p = particles[i];
      var t = Math.min(p.life / p.span, 1);

      /* Colour eases from the mark's own tone into the surface colour. */
      var r = Math.round(p.color[0] + (RESOLVE[0] - p.color[0]) * t);
      var g = Math.round(p.color[1] + (RESOLVE[1] - p.color[1]) * t);
      var b = Math.round(p.color[2] + (RESOLVE[2] - p.color[2]) * t);

      var alpha = Math.min(t / FADE_IN, 1) * Math.min((1 - t) / FADE_OUT, 1) * MAX_ALPHA;
      if (alpha <= 0.01) continue;

      ctx.globalAlpha = Math.max(0, Math.min(alpha, 1));
      ctx.fillStyle = "rgb(" + r + "," + g + "," + b + ")";

      if (p.square) {
        ctx.fillRect(p.x, p.y, p.size, p.size);
      } else {
        ctx.beginPath();
        ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
        ctx.fill();
      }
    }

    ctx.globalAlpha = 1;
  }

  function step(now) {
    rafId = null;
    var dt = lastTime ? Math.min((now - lastTime) / 1000, 0.05) : 0.016;
    lastTime = now;

    for (var i = 0; i < particles.length; i++) {
      var p = particles[i];
      p.x += p.dx * p.speed * dt;
      p.y += p.dy * p.speed * dt;
      p.life += dt;

      if (p.life >= p.span || p.x > width + margin || p.y < -margin) {
        makeParticle(p, false);
      }
    }

    draw();
    schedule();
  }

  function schedule() {
    if (rafId === null && visible && !prefersReduced()) {
      rafId = window.requestAnimationFrame(step);
    }
  }

  function stop() {
    if (rafId !== null) {
      window.cancelAnimationFrame(rafId);
      rafId = null;
    }
    lastTime = 0;
  }

  function prefersReduced() {
    return !!(reduceMotion && reduceMotion.matches);
  }

  function start() {
    resize();
    if (prefersReduced()) {
      stop();
      draw();
      return;
    }
    schedule();
  }

  function setVisible(next) {
    if (next === visible) return;
    visible = next;
    if (visible) {
      lastTime = 0;
      schedule();
    } else {
      stop();
    }
  }

  var resizeTimer = null;
  window.addEventListener("resize", function () {
    window.clearTimeout(resizeTimer);
    resizeTimer = window.setTimeout(function () {
      resize();
      if (prefersReduced()) draw();
    }, 150);
  });

  document.addEventListener("visibilitychange", function () {
    setVisible(!document.hidden);
  });

  if (window.IntersectionObserver) {
    new window.IntersectionObserver(function (entries) {
      setVisible(entries[0].isIntersecting && !document.hidden);
    }, { threshold: 0 }).observe(canvas);
  }

  if (reduceMotion) {
    var onChange = function () {
      stop();
      start();
    };
    if (reduceMotion.addEventListener) reduceMotion.addEventListener("change", onChange);
    else if (reduceMotion.addListener) reduceMotion.addListener(onChange);
  }

  /* Web fonts can reflow the copy after load, moving the origin. */
  if (document.fonts && document.fonts.ready && document.fonts.ready.then) {
    document.fonts.ready.then(function () {
      if (measure()) resize();
    });
  }

  start();
})();

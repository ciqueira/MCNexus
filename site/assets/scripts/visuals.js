(function () {
  "use strict";

  const strips = document.querySelectorAll(".visual-strip");

  if (!strips.length) {
    return;
  }

  const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
  let frame = 0;

  function clamp(value, minimum, maximum) {
    return Math.min(Math.max(value, minimum), maximum);
  }

  function overflowFor(image, media) {
    return {
      x: Math.max(image.offsetWidth - media.clientWidth, 0),
      y: Math.max(image.offsetHeight - media.clientHeight, 0),
    };
  }

  function positionImage(image, x, y) {
    image.style.transform = `translate3d(${x}px, ${y}px, 0)`;
  }

  function update() {
    frame = 0;
    const viewportHeight = window.innerHeight;

    strips.forEach(function (strip) {
      const rect = strip.getBoundingClientRect();
      const progress = clamp(
        (viewportHeight - rect.top) / (viewportHeight + rect.height),
        0,
        1
      );
      const appMedia = strip.querySelector(".visual-card-app .visual-media");
      const flowMedia = strip.querySelector(".visual-card-flow .visual-media");
      const appImage = appMedia && appMedia.querySelector("img");
      const flowImage = flowMedia && flowMedia.querySelector("img");

      if (!appImage || !flowImage) {
        return;
      }

      const appOverflow = overflowFor(appImage, appMedia);
      const flowOverflow = overflowFor(flowImage, flowMedia);

      if (reducedMotion.matches) {
        positionImage(appImage, -appOverflow.x / 2, -appOverflow.y / 2);
        positionImage(flowImage, -flowOverflow.x / 2, -flowOverflow.y / 2);
        return;
      }

      positionImage(appImage, -appOverflow.x / 2, -appOverflow.y * progress);
      positionImage(flowImage, -flowOverflow.x * progress, -flowOverflow.y / 2);
    });
  }

  function scheduleUpdate() {
    if (!frame) {
      frame = window.requestAnimationFrame(update);
    }
  }

  window.addEventListener("scroll", scheduleUpdate, { passive: true });
  window.addEventListener("resize", scheduleUpdate);
  reducedMotion.addEventListener("change", scheduleUpdate);

  strips.forEach(function (strip) {
    strip.querySelectorAll("img").forEach(function (image) {
      image.addEventListener("load", scheduleUpdate, { once: true });
    });
  });

  scheduleUpdate();
})();

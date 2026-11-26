(function () {
  var toggle = document.querySelector(".nav-toggle");
  var nav = document.getElementById("primary-nav");

  function setMenuOpen(open) {
    if (!toggle || !nav) return;
    nav.setAttribute("data-open", open ? "true" : "false");
    toggle.setAttribute("aria-expanded", open ? "true" : "false");
    var mainEl = document.querySelector("main");
    var footerEl = document.querySelector("footer");
    if (mainEl) mainEl.inert = open;
    if (footerEl) footerEl.inert = open;
    if (open) {
      var firstLink = nav.querySelector("a");
      if (firstLink) firstLink.focus();
    }
  }

  if (toggle && nav) {
    toggle.addEventListener("click", function (event) {
      event.stopPropagation();
      var isOpen = nav.getAttribute("data-open") === "true";
      setMenuOpen(!isOpen);
    });

    nav.addEventListener("click", function (event) {
      if (event.target.closest("a")) {
        setMenuOpen(false);
      }
    });

    document.addEventListener("click", function (event) {
      if (nav.getAttribute("data-open") === "true" && !event.target.closest(".site-header")) {
        setMenuOpen(false);
      }
    });

    document.addEventListener("keydown", function (event) {
      if (event.key === "Escape" && nav.getAttribute("data-open") === "true") {
        setMenuOpen(false);
        toggle.focus();
      }
    });
  }

  function updateTableScroll(scroller) {
    var wrap = scroller.closest(".table-scroll-wrap");
    if (!wrap) return;
    var hasMore = scroller.scrollWidth - scroller.scrollLeft - scroller.clientWidth > 2;
    wrap.classList.toggle("has-scroll", hasMore);
  }

  function refreshAllTables() {
    document.querySelectorAll(".table-scroll").forEach(updateTableScroll);
  }

  document.querySelectorAll(".table-scroll").forEach(function (scroller) {
    scroller.addEventListener("scroll", function () {
      updateTableScroll(scroller);
    }, { passive: true });
  });

  window.addEventListener("resize", refreshAllTables, { passive: true });
  window.addEventListener("load", refreshAllTables);
  refreshAllTables();

  var paddlePromise = null;
  function ensurePaddle(token) {
    if (window.Paddle) return Promise.resolve(window.Paddle);
    if (paddlePromise) return paddlePromise;
    paddlePromise = new Promise(function (resolve, reject) {
      var script = document.createElement("script");
      script.src = "https://cdn.paddle.com/paddle/v2/paddle.js";
      script.async = true;
      script.onload = function () {
        if (window.Paddle && token) {
          window.Paddle.Initialize({ token: token });
        }
        resolve(window.Paddle);
      };
      script.onerror = reject;
      document.head.appendChild(script);
    });
    return paddlePromise;
  }

  document.addEventListener("click", function (event) {
    var trigger = event.target.closest("[data-paddle-checkout]");
    if (!trigger) return;
    var priceId = trigger.getAttribute("data-paddle-checkout");
    var token = document.body.getAttribute("data-paddle-token");
    if (!priceId || !token) return;
    event.preventDefault();
    ensurePaddle(token).then(function (Paddle) {
      if (Paddle && Paddle.Checkout) {
        Paddle.Checkout.open({ items: [{ priceId: priceId, quantity: 1 }] });
      }
    });
  });

  var imageDialog = null;
  function getImageDialog() {
    if (imageDialog) return imageDialog;
    var dialog = document.createElement("dialog");
    dialog.className = "image-modal";
    var closeLabel = (document.documentElement.lang || "").toLowerCase().startsWith("pt") ? "Fechar" : "Close";
    dialog.innerHTML =
      '<div class="image-modal-card">' +
        '<div class="image-modal-head">' +
          '<span class="image-modal-title"></span>' +
          '<button type="button" class="image-modal-close" aria-label="' + closeLabel + '">×</button>' +
        '</div>' +
        '<div class="image-modal-body"><img alt=""></div>' +
      '</div>';
    dialog.addEventListener("click", function (event) {
      if (event.target === dialog || event.target.closest(".image-modal-close")) {
        dialog.close();
      }
    });
    document.body.appendChild(dialog);
    imageDialog = dialog;
    return dialog;
  }

  document.addEventListener("click", function (event) {
    var link = event.target.closest("a[data-image-modal]");
    if (!link) return;
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
    var dialog = getImageDialog();
    if (typeof dialog.showModal !== "function") return;
    event.preventDefault();
    var title = link.getAttribute("data-image-modal") || link.textContent || "";
    dialog.querySelector(".image-modal-title").textContent = title;
    var img = dialog.querySelector("img");
    img.src = link.getAttribute("href");
    img.alt = title;
    dialog.showModal();
  });
})();

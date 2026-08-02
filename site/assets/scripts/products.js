(function () {
  "use strict";

  const lists = document.querySelectorAll("[data-product-list]");

  if (!lists.length) {
    return;
  }

  const typeLabels = {
    en: {
      app: "Application",
      plugin: "Plugin",
      service: "Service",
      sdk: "SDK",
    },
    "pt-BR": {
      app: "Aplicativo",
      plugin: "Plugin",
      service: "Serviço",
      sdk: "SDK",
    },
  };

  const statusLabels = {
    en: {
      beta: "Beta",
      "coming-soon": "Coming soon",
    },
    "pt-BR": {
      beta: "Beta",
      "coming-soon": "Em breve",
    },
  };

  const linkLabels = {
    en: {
      repository: "Repository",
      site: "Website",
    },
    "pt-BR": {
      repository: "Repositório",
      site: "Site",
    },
  };

  function createElement(tag, className, text) {
    const element = document.createElement(tag);

    if (className) {
      element.className = className;
    }

    if (text) {
      element.textContent = text;
    }

    return element;
  }

  function createProductCard(product, list) {
    const locale = list.dataset.locale || "en";
    const labels = typeLabels[locale] || typeLabels.en;
    const statuses = statusLabels[locale] || statusLabels.en;
    const links = linkLabels[locale] || linkLabels.en;
    const card = createElement("article", "product-card");
    const header = createElement("div", "product-card-header");
    const logo = document.createElement("img");
    const status = createElement(
      "span",
      "product-status",
      statuses[product.status] || product.status
    );
    const body = createElement("div", "product-card-body");
    const type = createElement(
      "p",
      "product-type",
      labels[product.type] || product.type
    );
    const description = createElement(
      "p",
      "",
      product.descriptions[locale] || product.descriptions.en
    );

    logo.className = "product-logo";
    logo.src = product.logo;
    logo.alt = product.name;
    logo.loading = "lazy";
    logo.decoding = "async";

    header.append(logo, status);
    body.append(type, description);
    card.append(header, body);

    const productUrl = product.url || product.repository;

    if (productUrl) {
      const linkType = product.linkType || "repository";
      const link = createElement(
        "a",
        "product-card-link",
        links[linkType] || links.repository
      );
      link.href = productUrl;
      link.target = "_blank";
      link.rel = "noreferrer";
      link.setAttribute("aria-label", `${product.name} — ${link.textContent}`);
      card.append(link);
    }

    return card;
  }

  fetch("/assets/data/products.json")
    .then(function (response) {
      if (!response.ok) {
        throw new Error(`Products request failed: ${response.status}`);
      }

      return response.json();
    })
    .then(function (products) {
      lists.forEach(function (list) {
        const fragment = document.createDocumentFragment();

        products.forEach(function (product) {
          fragment.append(createProductCard(product, list));
        });

        list.replaceChildren(fragment);
      });
    })
    .catch(function (error) {
      console.warn("MCNexus product catalog could not be loaded.", error);
    });
})();

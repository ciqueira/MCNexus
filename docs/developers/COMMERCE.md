# Commerce & Fulfillment

[English](COMMERCE.md) · [Português](../../pt-BR/docs/developers/COMMERCE.md)

[Home](../../README.md) · [Developer Guide](../DEVELOPERS.md) · [Licensing](LICENSING.md) · [Commerce](COMMERCE.md) · [Releases](RELEASES.md) · [DCTL](DCTL.md) · [MIDI](MIDI.md)

## 1. Architecture Overview (0% Commission Direct Stripe)

Nexus Commerce connects checkout directly to the developer's own **Stripe** account with **0% platform commission**. An offer catalog links price, product, edition, variant entitlements, payment account, and the legal URLs displayed at checkout.

- **Today in production:** native Stripe (Payment Links and verified webhooks).
- **On the roadmap:** standardized webhook adapters for Lemon Squeezy, Shopify, and Pix.

## 2. Buyer Identity (Email OTP, Google, GitHub)

Buyers and free-license users do not need a GitHub account to claim or purchase a plugin. In production, checkout and claim portals support:

- **Email OTP verification** (short-lived verification code with anti-abuse protection);
- **Google OAuth**;
- **GitHub OAuth**.

## 3. Idempotent Fulfillment & Webhook Deduplication

Upon payment confirmation, the webhook bridge records the order and payment event, tracks every fulfillment attempt per order, and deduplicates retried Stripe webhook deliveries so a single purchase never issues duplicate licenses. The issued key is shown on screen (one-time reveal) and delivered via transactional email.

## 4. In-Place Demo/Trial to Full Upgrade

When a customer evaluates a plugin using a `Demo` or `Trial` key and later purchases a `Full` license using the **same verified email address**, Nexus automatically promotes the existing license key to `Full`. On the next background sync, `NexKeyRuntime` updates `edition_enum` to `NEXKEYRUNTIME_EDITION_FULL` without reinstalling files or breaking existing timelines and projects.

## 5. Auditable Legal Acceptance & Division of Responsibilities

Every commercial order records the exact timestamp and version of the product's Terms, Privacy Policy, and Refund Policy accepted by the buyer. The developer remains the merchant of record on Stripe, sets pricing and refund terms, and handles product support; Nexus operates the checkout bridge, license issuance, and credential delivery. See [Tenant Legal Guide](../TENANT_LEGAL_GUIDE.md).

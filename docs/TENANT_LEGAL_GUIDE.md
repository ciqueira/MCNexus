# Tenant Legal Documentation Guide

[English](TENANT_LEGAL_GUIDE.md) · [Português](../pt-BR/docs/TENANT_LEGAL_GUIDE.md)

Last updated: July 13, 2026

This guide defines the minimum public-document structure for a developer using
Nexus as a licensing, distribution, commerce, and communication service. It is
an implementation checklist, not legal or accounting advice.

## Responsibility model

```text
Independent product tenant
  controls: product, offer, customer purpose, support, marketing choices
  publishes: product terms, product privacy, refunds, support, license

Nexus platform
  operates: app, APIs, configured license/payment/email orchestration
  publishes: Nexus terms and Nexus privacy
  processes: tenant-directed data under the service agreement
  controls: limited platform security, abuse, reliability, and legal records

External providers
  GitHub / site identity / magic link
  Stripe / another payment provider
  OpenKey / Cryptlex / another license provider
  MailerLite / Mailchimp / another email provider
```

The actual legal role follows the real decisions and processing, not the label
used in source code. A provider may be a processor for one activity and an
independent controller for its own fraud, billing, account, or compliance
operations.

## Required tenant tree

Each tenant should maintain a stable, versioned tree comparable to:

```text
legal/
├── README.md
├── TERMS.md
├── PRIVACY.md
├── REFUND_POLICY.md
├── SUPPORT_POLICY.md
└── pt-BR/
    ├── README.md
    ├── TERMS.md
    ├── PRIVACY.md
    ├── REFUND_POLICY.md
    └── SUPPORT_POLICY.md

LICENSE.md or EULA
THIRD_PARTY_NOTICES.md
SECURITY.md or a private security-reporting channel
```

Products distributed only for free may not need a refund policy, but they still
need accurate licensing, privacy, support, and platform disclosures. A paid
offer requires the refund/cancellation layer even when the underlying software
remains free.

## Minimum contents

### Product terms

- complete seller and controller identity, business registration, service
  address, and private contact channel;
- exact free and paid scopes;
- price presentation and Merchant of Record;
- duration, renewal, eligibility, and exclusions of each benefit;
- applicable software license and Nexus cross-reference;
- operational communication versus optional marketing;
- mandatory consumer-right savings clause; and
- document version and effective date.

### Product privacy

- controller and privacy contact;
- data categories and sources;
- specific purposes and legal bases;
- recipients/providers selected by that tenant;
- international transfers and safeguards;
- retention criteria;
- data-subject rights and identity-verification process;
- operational email/marketing separation; and
- security and incident handling.

### Refund policy

- cancellation channel and information required;
- mandatory withdrawal and statutory remedies;
- duplicate, unauthorized, fraudulent, failed-delivery, and defect cases;
- normal policy after mandatory periods;
- effect on paid benefits versus a separate free license; and
- refund timing controlled by the payment provider or issuer.

### Support policy

- public/free and paid/private channels;
- benefit duration and response target;
- included products, versions, hosts, platforms, and tasks;
- exclusions and diagnostic-data guidance; and
- no publication of private keys or personal data.

## Checkout and evidence

Before payment confirmation, the buyer should be able to see the seller,
offer, total price, currency, benefit duration, support channel, product terms,
privacy policy, and refund policy. The public product URL must point to the
Nexus Commerce entry, not directly to an internal provider Payment Link.

For account-scoped Commerce orders, Nexus retains an immutable snapshot of the
configured seller and product document URLs and versions, locale, acceptance
source and timestamp, offer, and provider transaction references. A mutable
GitHub page alone is not sufficient evidence, so reviewed document versions
should remain recoverable after publication.

Legacy tenant-scoped webhook orders might not have this evidence. A tenant must
not represent a legacy record as proof of acceptance when the Purchase detail
marks the evidence as unavailable.

## Provider-neutral configuration

The tenant configuration should provide logical fields such as:

```text
TERMS_URL
PRIVACY_URL
REFUND_POLICY_URL
SUPPORT_CONTACT_EMAIL
SUPPORT_DURATION_MONTHS
TRANSACTIONAL_EMAIL_PROVIDER
MARKETING_AUDIENCE_PROVIDER
```

Provider credentials remain encrypted tenant secrets. Public legal URLs,
support configuration, offer IDs, and provider-neutral document versions are
ordinary tenant configuration or database records. Replacing Stripe,
MailerLite, OpenKey, or Cryptlex must not require rewriting the product's public
legal URLs unless the real processing or recipients change.

## Launch gate

Before enabling a tenant's Live offer:

1. obtain legal and accounting review in the seller's jurisdiction;
2. verify seller identity, activity classification, taxes, and invoicing;
3. publish and configure every required URL;
4. verify checkout notice and cancellation channel;
5. verify provider agreements and international-transfer safeguards;
6. test purchase, delivery, operational email, refund, dispute, privacy request,
   and data correction/deletion restrictions; and
7. record the exact reviewed document versions in the release checklist.

The Color Equalizer repository is the first reference implementation of this
structure.

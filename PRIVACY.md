# Privacy Policy: Nexus

[English](PRIVACY.md) · [Português](pt-BR/PRIVACY.md)

Last updated: October 26, 2026

Document version: `nexus-privacy-2026-10-26`

This Privacy Policy explains how the Nexus platform ("Nexus", "we", "us") collects, uses, stores, and protects users' personal data. Processing is conducted under the Brazilian General Data Protection Law (LGPD: Law No. 13,709/2018) and, where applicable, other data protection laws.

By installing, activating, or using the MCNexus application, requesting a
license, or completing a purchase through the platform, the user acknowledges
having access to this policy. Each product may also publish a product-level
privacy policy that applies to the same workflow.

## 1. Controller Identification

Nexus is developed and maintained by Magno Ciqueira, a natural person acting
as controller (LGPD art. 5 VI) and responsible for the personal data processing
described in this policy. Correspondence address: Avenida Augusto de Lima, 233,
Belo Horizonte - MG, CEP 30190-000, Brazil.

The Nexus platform is not a separate legal entity. Where a purchase is
involved, the seller is identified before the transaction and publishes its own
documents; that identification, not this section, states who sells and issues
invoices.

**Channel for data subjects** (ANPD Resolution No. 2/2022, art. 11 §1, for
small-scale processing agents), and the address for exercising the rights in
section 9: [hello@mcnexus.app](mailto:hello@mcnexus.app)

For first-party products, the same person may control both product and platform
processing while keeping the purposes documented separately. When Nexus is
used by an independent tenant, the tenant normally controls its customer,
commerce, licensing, support, and communication purposes. Nexus processes data
under the tenant's instructions for those services and may independently
control limited data needed for platform security, abuse prevention, service
integrity, and legal compliance. The applicable agreement and product policy
must identify the roles for that deployment.

## 2. Legal Bases and Data Minimization

Each purpose below names the basis it relies on under the LGPD and, for users
in the European Economic Area and the United Kingdom, under the GDPR:

- **Providing, activating, protecting and administering a licence:**
  performance of a contract (LGPD art. 7 V; GDPR art. 6(1)(b)). Without this
  processing a licence cannot be issued, verified or supported. This includes
  processing the email address and identity details provided during checkout,
  one-time code verification, or license claim to deliver digital credentials
  and provide the license.
- **Invoicing, accounting and tax records:** compliance with a legal
  obligation (LGPD art. 7 II; GDPR art. 6(1)(c)).
- **Security, abuse prevention, rate limiting and fraud prevention:**
  legitimate interests (LGPD art. 7 IX; GDPR art. 6(1)(f)). The interest
  pursued is keeping the licensing service available and preventing a licence
  or a protected download from being used by someone other than its holder.
  It is balanced against the user's rights by processing the smallest signal
  that answers the question: a device identifier only as a one-way hash,
  security checks against abusive automated traffic, and a network address
  that is not stored alongside the activation record.
- **Establishing, exercising or defending legal claims, and handling
  data-subject requests:** LGPD art. 7 VI and art. 18; GDPR art. 6(1)(c) and
  art. 6(1)(f).
- **Optional marketing communications:** consent (LGPD art. 7 I; GDPR art.
  6(1)(a)), withdrawable at any time without affecting messages necessary for
  an active transaction, licence, security obligation or support request.

Where a purpose relies on legitimate interests, the user may object through the
contact in section 9, and the balance is reassessed for that case.

Nexus follows the principle of data minimization: we collect only the data required for licensing, product delivery, security, and support. We do not collect sensitive personal data or personal browsing information unrelated to these purposes.

Nexus may process limited technical data required for security, reliability, diagnostics, and service improvement. When these capabilities are used, the data involved and its purposes will be described in this policy. This data is not used for behavioral advertising.

## 3. Data We Process

- **Hardware identifier (hardware fingerprint):** generated locally by the application to bind node-locked licenses to a device and prevent unauthorized simultaneous use. The identifier is transmitted only as a one-way hash, never in its original form. Alongside activation and periodic license verification, the application may also send basic device diagnostics (operating system name and version, processor architecture, application version, the name of the reporting program [the main application or an installed plugin], and the licensing SDK's own version) used to correlate an activation with its device and program and to assist support. Local license data is protected using operating-system security mechanisms, and communications with licensing services use HTTPS.
- **IP address:** processed in transit during activation and service requests for security, abuse prevention and rate limiting. It is **not stored with the activation record**: the activation keeps only the country reported by our edge network, which is what supports approximate regional geolocation. Security logs may retain a full address for a short period; routine, non-security events record only the network portion of it.
- **Name and email address:** used to identify the license holder, deliver credentials, provide support, and send product-related transactional communications. This information is provided during purchase, registration, or support interactions.
- **Technical license data:** may include the license key, product, edition, version, activation status, device identifier, and dates associated with the license lifecycle.
- **Identity and authentication:** depending on the option chosen by the user to authenticate:
  - **Google:** account identifier, verified email address, name, and profile picture, requested solely for secure sign-in.
  - **Microsoft:** account identifier, verified email address, and display name.
  - **GitHub:** account identifier, username, and verified email. Nexus does not request access to private repositories or code.
  - **Email verification:** user-provided email address to receive temporary confirmation codes.
  This information is used exclusively to authenticate the license holder, issue and deliver the purchased license, and prevent duplicate or fraudulent redemptions.
- **Commerce and support records:** may include the provider's Checkout Session,
  Payment Link, Price, payment, refund and dispute references; amount, currency,
  environment, offer snapshot, accepted-document version, fulfillment status,
  support period, and operational email delivery fields.

Nexus does not collect or store full card numbers, banking information, or complete payment credentials.

### 3.1. Google Account Data Usage and Limited Use Policy

Nexus's use and transfer of information received from Google APIs adheres to the [Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy), including the Limited Use requirements:

1. **Specific Purpose:** Basic profile information (account identifier, verified email, name, and profile picture) is accessed exclusively to verify user identity during purchase or license claims, allowing us to associate and deliver the software license and support entitlements.
2. **Limited Use:** This information is not used for any purpose outside of identity authentication and software license delivery.
3. **No Advertising or Profiling:** We never use Google user data to serve ads, commercial offers, or for behavioral profiling, nor do we sell, rent, or transfer it to data brokers or advertising networks.
4. **No AI/ML Training:** Data received from Google APIs is not used to train, fine-tune, or develop artificial intelligence (AI) or machine learning (ML) models.
5. **Restricted Sharing:** Google user data is never shared with third parties, except essential infrastructure providers operating under strict security and confidentiality controls, or where required by law.
6. **Storage and Security:** Transmission is protected via encryption (HTTPS) and data is stored in secure environments with restricted access.
7. **User Control and Deletion:** Users may revoke the application's access at any time through their [Google Account Permissions](https://myaccount.google.com/permissions), or request data deletion by emailing [hello@mcnexus.app](mailto:hello@mcnexus.app).

## 4. Local File Access and System Permissions

To install and remove plugins, MCNexus accesses only the folders required for the application, licensing, and OFX plugin installation. On Windows, certain operations require administrator privileges to write to system folders such as `C:\Program Files\Common Files\OFX\Plugins`. On macOS, the system may request equivalent permissions when required.

MCNexus is not designed to access, copy, or transmit video projects, documents, or other personal files. Communication with online services is limited to licensing, update, download, security, and support operations.

## 5. Retention and Security

Data is retained for as long as necessary to provide and administer licenses, prevent fraud, handle data-subject requests, comply with legal obligations, and establish or defend legal claims.

Technical data directly controlled by Nexus is deleted or anonymized when it is no longer required, subject to applicable legal and operational periods. Data processed by service providers is also subject to their retention periods and procedures. Deletion requests will be forwarded and fulfilled where applicable, considering legal obligations, fraud prevention, and records necessary to perform the contract.

The activation and license-lifecycle history described above (activation, deactivation, and related events) is not kept indefinitely: it is retained for a limited period (typically between six months and one year, depending on volume) and deleted or aggregated afterward.

Temporary email verification codes and the records needed to validate them are automatically deleted within 24 hours. Operational system logs do not record verification codes or unmasked email addresses.

Local credentials and license data are stored using protection mechanisms provided by the operating system. Data transmitted between the application and backend uses HTTPS.

## 6. Payments

Paid licenses, Supporter benefits, and other identified offers may be processed
by Stripe or the checkout partner shown at purchase. Nexus does not receive full
card numbers or banking credentials. The backend receives only the references
and customer information required to verify the transaction, prevent duplicate
purchases, fulfill the configured benefit, provide support, and handle refunds
or disputes.

## 7. Sharing with Processors

Data may be shared, strictly for the purposes described above, with:

- **Authentication providers (Google, Microsoft, GitHub):** buyer identity verification during checkout or license claims. Each service independently controls its respective sign-in screen;
- **Stripe and payment partners:** payment processing and confirmation;
- **Resend:** transactional email delivery, including confirmation codes and license delivery (with infrastructure in Brazil and internationally);
- **Cloudflare:** network security, protection against abusive automated traffic, traffic distribution, and operational logs;
- **OpenKey/Nexus or Cryptlex:** issuance, validation, activation, and license management according to the product configuration;
- **Neon/PostgreSQL hosting:** platform, license, commerce, and audit records;
- **MailerLite, Mailchimp, or another identified email provider:** optional marketing communications (only with explicit consent), product release announcements, and maintenance communications.

These providers may process data outside Brazil. Where required by applicable law, appropriate international-transfer mechanisms are used. Each provider also maintains its own privacy policy.

Nexus does not sell or rent personal data for advertising.

Providers may independently control portions of their own account, billing,
fraud, security, and legal-compliance processing. Their current policies apply
to those operations.

## 8. Operational Communications and Marketing

Messages necessary for license delivery, activation, security, purchase,
refund, support, and product-specific release or maintenance benefits are
operational communications. They do not grant permission for advertising
unrelated products.

Optional marketing audiences must use a separate choice and an unsubscribe
mechanism. Withdrawing optional marketing does not prevent a message necessary
to fulfill an active transaction, security obligation, or support request.
Operational group membership must not be silently converted into marketing
consent.

## 9. Data-Subject Rights

Subject to applicable law, individuals may request:

- confirmation that processing takes place;
- access to their data;
- correction of incomplete, inaccurate, or outdated data;
- anonymization, blocking, or deletion of unnecessary or excessive data;
- information about data sharing;
- portability, where applicable;
- review of or objection to certain processing, where available;
- deletion of data, subject to legal, contractual, anti-fraud, and legal-claims requirements.

To exercise these rights, contact [hello@mcnexus.app](mailto:hello@mcnexus.app) and provide your name, registered email address, and, where necessary, a license reference. We may request additional information to confirm the requester's identity, limited to what is proportionate to that verification.

We reply in simplified form immediately where possible, and in full **within 15
days** of receipt (LGPD art. 19 §1 II). For requests covered by the GDPR the
deadline is **one month**, extendable by two further months for complex
requests, with notice (GDPR art. 12(3)). Where a request is refused in whole or
in part (because a record must be kept for a tax, contractual, anti-fraud or
legal-claims reason), we identify which part and the reason.

If you are not satisfied with our answer, you may complain to a supervisory
authority: in Brazil, the Autoridade Nacional de Proteção de Dados
([ANPD](https://www.gov.br/anpd/)); in the European Economic Area or the United
Kingdom, your national data protection authority.

Privacy requests should not be posted publicly through GitHub Issues.

## 10. Children and Minors

Nexus is a professional product intended for audiovisual post-production workstations and is not directed to people under 18. We do not intentionally collect data from children or minors.

## 11. International Users and Transfers

Nexus is operated from Brazil and may serve users in other countries. We seek to comply with the data-protection requirements applicable to each relationship, including, where relevant, the GDPR for residents of the European Economic Area and United Kingdom and privacy laws applicable to California residents.

For European users, processing required to provide a license is primarily based
on performance of the contract. International transfers must use mechanisms
recognized by applicable law. Transfers subject to Brazilian law are assessed
under the LGPD and the ANPD International Data Transfer Regulation, including
contractual safeguards where required.

Nexus does not sell or share personal information for cross-context behavioral advertising. Eligible users may request access, correction, or deletion through the channels identified in this policy.

## 12. Changes

This policy may be updated to reflect changes to the product, service providers, or legal requirements. The latest revision date will appear at the beginning of the document. Material changes may be communicated through the application, repository, or registered contact channels.

Where versioned acceptance is supported, the document version made available
for a transaction is recorded with that transaction. This does not turn silence
or unrelated service use into consent for optional marketing.

## 13. Contact

- Privacy: [hello@mcnexus.app](mailto:hello@mcnexus.app)
- Technical support: [github.com/ciqueira/MCNexus/issues](https://github.com/ciqueira/MCNexus/issues)

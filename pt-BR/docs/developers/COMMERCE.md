# Comércio e Entrega

[English](../../../docs/developers/COMMERCE.md) · [Português](COMMERCE.md)

[Início](../../README.md) · [Guia do Desenvolvedor](../DEVELOPERS.md) · [Licenciamento](LICENSING.md) · [Comércio e Entrega](COMMERCE.md) · [Releases](RELEASES.md) · [DCTL](DCTL.md) · [MIDI](MIDI.md)

## 1. Visão Geral (Stripe Direto com 0% de Comissão)

O Nexus Commerce conecta o checkout diretamente à conta **Stripe** do próprio desenvolvedor com **0% de comissão da plataforma** (aplicam-se apenas as taxas padrão do Stripe na conta do vendedor; o Nexus não atua como Merchant of Record). Um catálogo de ofertas vincula preço, produto, edição, entitlements por variante, conta de pagamento e as URLs jurídicas exibidas no checkout.

- **Em produção hoje:** Stripe nativo (Payment Links e webhooks verificados).
- **No roadmap:** adaptadores padronizados de webhook para Lemon Squeezy, Shopify e Pix.

## 2. Identidade do Comprador (E-mail OTP, Google, GitHub)

Compradores e usuários de plugins gratuitos não precisam de conta no GitHub para resgatar ou comprar um produto. Em produção, os portais de resgate e compra suportam:

- **Verificação por E-mail (OTP)** (código de verificação temporário com proteção anti-abuso);
- **Google OAuth**;
- **GitHub OAuth**.

## 3. Entrega Única e Proteção contra Duplicidade

Após a confirmação do pagamento, o webhook bridge registra o pedido e o evento de pagamento, rastreia cada tentativa de entrega por pedido e deduplica retentativas do Stripe para impedir emissão duplicada de chaves. A chave emitida é exibida em tela (revelação única) e enviada por e-mail transacional.

## 4. Upgrade na Mesma Chave de Demo/Trial para Full

Quando um cliente avalia um plugin com chave `Demo` ou `Trial` e depois compra a licença `Full` usando o **mesmo e-mail verificado**, o Nexus promove automaticamente a chave existente para `Full`. Na sincronização seguinte, a `NexKeyRuntime` atualiza `edition_enum` para `NEXKEYRUNTIME_EDITION_FULL` sem reinstalar arquivos e sem quebrar timelines ou projetos salvos.

## 5. Aceite Legal Auditável e Divisão de Responsabilidades

Cada compra registra o carimbo de data/hora e a versão exata dos Termos, Política de Privacidade e Política de Reembolso aceitos pelo comprador. O desenvolvedor permanece como vendedor direto no Stripe (responsável por configuração fiscal/VAT, preços, suporte funcional e estornos no Stripe Dashboard com revogação manual da chave hoje; a revogação automática por webhook está no roadmap), enquanto o Nexus opera a ponte de checkout, emissão de licença e entrega de credenciais. Veja [Guia Legal para Tenants](../TENANT_LEGAL_GUIDE.md).

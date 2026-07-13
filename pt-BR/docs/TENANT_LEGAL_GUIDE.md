# Guia de Documentação Legal por Tenant

[English](../../docs/TENANT_LEGAL_GUIDE.md) · [Português](TENANT_LEGAL_GUIDE.md)

Última atualização: 13 de julho de 2026

Este guia define a estrutura pública mínima para um desenvolvedor que usa o
Nexus como serviço de licenciamento, distribuição, comércio e comunicação. É um
checklist de implementação, não aconselhamento jurídico ou contábil.

## Modelo de responsabilidades

```text
Tenant independente do produto
  controla: produto, oferta, finalidade do cliente, suporte, marketing
  publica: termos, privacidade, reembolso, suporte e licença do produto

Plataforma Nexus
  opera: app, APIs e orquestração configurada de licença/pagamento/e-mail
  publica: termos e privacidade do Nexus
  trata: dados orientados pelo tenant sob o contrato de serviço
  controla: registros limitados de segurança, abuso, confiabilidade e lei

Provedores externos
  GitHub / identidade do site / magic link
  Stripe / outro provedor de pagamento
  OpenKey / Cryptlex / outro provedor de licença
  MailerLite / Mailchimp / outro provedor de e-mail
```

O papel jurídico real segue as decisões e o tratamento efetivo, não o nome no
código-fonte. Um provedor pode ser operador em uma atividade e controlador
independente em suas operações próprias de fraude, cobrança, conta ou
conformidade.

## Árvore obrigatória do tenant

Cada tenant deve manter uma árvore estável e versionada comparável a:

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

LICENSE.md ou EULA
THIRD_PARTY_NOTICES.md
SECURITY.md ou canal privado para segurança
```

Produtos somente gratuitos podem não precisar de política de reembolso, mas
ainda exigem licença, privacidade, suporte e informações corretas da plataforma.
Uma oferta paga exige a camada de cancelamento/reembolso mesmo quando o
software subjacente continua gratuito.

## Conteúdo mínimo

### Termos do produto

- identidade completa do vendedor/controlador, cadastro empresarial, endereço
  e canal privado;
- escopos exatos gratuito e pago;
- apresentação do preço e Merchant of Record;
- duração, renovação, elegibilidade e exclusões do benefício;
- licença do software e referência ao Nexus;
- comunicação operacional versus marketing opcional;
- preservação de direitos obrigatórios do consumidor; e
- versão e vigência do documento.

### Privacidade do produto

- controlador e contato;
- categorias e fontes dos dados;
- finalidades e bases legais específicas;
- destinatários/provedores selecionados pelo tenant;
- transferências e salvaguardas;
- critérios de retenção;
- direitos e verificação de identidade;
- separação entre e-mail operacional e marketing; e
- segurança e incidentes.

### Reembolso

- canal e informações para cancelamento;
- arrependimento e remédios legais;
- duplicidade, pagamento não autorizado, fraude, falha de entrega e vício;
- regra normal após prazos obrigatórios;
- efeito no benefício pago versus licença gratuita separada; e
- prazo sujeito ao provedor ou emissor.

### Suporte

- canais público/gratuito e pago/privado;
- duração e objetivo de resposta;
- produtos, versões, hosts, plataformas e tarefas cobertas;
- exclusões e orientação sobre diagnósticos; e
- proibição de publicar chaves ou dados pessoais.

## Checkout e evidência

Antes da confirmação, o comprador deve poder ver vendedor, oferta, preço total,
moeda, duração, canal de suporte, termos, privacidade e reembolso. A URL pública
do produto deve apontar à entrada Commerce do Nexus, não diretamente ao Payment
Link interno do provider.

Para cada pedido, o sistema deve futuramente manter evidência imutável de IDs,
versões, hashes, idioma, origem e data do aceite, vendedor, snapshot da oferta e
referências da transação. Uma página mutável do GitHub, sozinha, não comprova o
texto apresentado no checkout.

Enquanto o aceite versionado não estiver implementado, o tenant não pode
afirmar que o Nexus guarda essa evidência. Descrição e links no Stripe podem dar
ciência, mas essa limitação deve constar no checklist para revisão jurídica.

## Configuração neutra de providers

O tenant deve ter campos lógicos como:

```text
TERMS_URL
PRIVACY_URL
REFUND_POLICY_URL
SUPPORT_CONTACT_EMAIL
SUPPORT_DURATION_MONTHS
TRANSACTIONAL_EMAIL_PROVIDER
MARKETING_AUDIENCE_PROVIDER
```

Credenciais permanecem segredos cifrados do tenant. URLs legais públicas,
suporte, IDs da oferta e versões neutras são configuração comum ou registros do
banco. Trocar Stripe, MailerLite, OpenKey ou Cryptlex não deve exigir mudança das
URLs públicas, salvo alteração real do tratamento ou destinatários.

## Gate de lançamento

Antes de habilitar a oferta Live:

1. obter revisão jurídica e contábil na jurisdição do vendedor;
2. verificar identidade, atividade, tributos e emissão fiscal;
3. publicar e configurar todas as URLs;
4. verificar ciência no checkout e canal de cancelamento;
5. verificar contratos dos provedores e transferências internacionais;
6. testar compra, entrega, e-mail, reembolso, disputa, privacidade, correção e
   limites de exclusão; e
7. registrar no checklist as versões exatas revisadas.

O repositório Color Equalizer é a primeira implementação de referência dessa
estrutura.

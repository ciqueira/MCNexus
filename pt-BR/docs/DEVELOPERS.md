# Documentação para Desenvolvedores

[English](../../docs/DEVELOPERS.md) · [Português](DEVELOPERS.md)

[Início](../README.md) · [Discovery](DISCOVERY.md) · [Guia de Operação](USER_GUIDE.md) · [FAQ](FAQ.md) · [Roadmap](ROADMAP.md) · [Avaliações](REVIEWS.md)

O MCNexus mantém infraestrutura para hospedagem, licenciamento e distribuição de plugins OFX, sem exigir o desenvolvimento de um sistema completo de entrega e validação para cada plugin.

## Modelos de Distribuição

### Comercial

Plugins comerciais utilizam o Cryptlex para validação criptográfica de chaves de licença e ativação vinculada ao hardware. O Stripe e parceiros de checkout integrados podem acionar o cadastro do cliente, a emissão da licença e o envio transacional das credenciais.

As edições Demo e Full são suportadas.

### OpenKey

O OpenKey executa a distribuição de projetos open source sem dependência de um serviço comercial de licenciamento de terceiros. Os lançamentos são entregues pelo GitHub.

A distribuição híbrida pode combinar um projeto open source com uma modalidade comercial integrada ao Stripe.

## Canais de Lançamento

Os plugins podem ser organizados em canais controlados Beta, Demo e Full.

## Gerenciamento de Lançamentos

O gerenciamento inclui:

- sincronização com GitHub Releases;
- artefatos específicos para macOS e Windows;
- proxy protegido de downloads;
- notificações de atualização;
- instalação de versões anteriores e rollback.

## Fluxo Automatizado de Transação

1. Uma compra é concluída pelo Stripe ou por um parceiro de checkout integrado.
2. A transação é validada e a licença é gerada.
3. As credenciais e instruções de acesso são enviadas pelo MailerLite ou Mailchimp.
4. A chave é inserida no MCNexus e o plugin é instalado automaticamente.

A distribuição aberta pode utilizar um link direto de acesso em vez de uma compra comercial.

## Integrações Nativas

- **Pagamentos:** Stripe e parceiros de checkout.
- **Licenciamento:** Cryptlex e OpenKey.
- **E-mail transacional:** MailerLite e Mailchimp.
- **Lançamentos:** GitHub Releases.

## Plugins Integrados

A relação de plugins atualmente integrados ao MCNexus está no [Discovery](DISCOVERY.md).

# Documentação para Desenvolvedores

[English](../../docs/DEVELOPERS.md) · [Português](DEVELOPERS.md)

[Início](../README.md) · [Discovery](DISCOVERY.md) · [Guia de Operação](USER_GUIDE.md) · [Guia do Desenvolvedor](DEVELOPERS.md) · [FAQ](FAQ.md) · [Roadmap](ROADMAP.md) · [Continuidade](CONTINUITY.md)

Este hub é o ponto de entrada para integrar produtos ao MCNexus e à SDK `NexKeyRuntime`. As especificações técnicas completas de cada subsistema estão nos cinco guias abaixo.

## Guias para Desenvolvedores

- **[Licenciamento e Ativação](developers/LICENSING.md):** backends OpenKey e Cryptlex, como embarcar a `NexKeyRuntime` (`ABI 1.0`), campos do snapshot, janela offline, arquivos air-gap (`.req` / `.lic`) e keyrings de 4 slots.
- **[Commerce e Fulfillment](developers/COMMERCE.md):** checkout Stripe direto (0% de comissão), identidade do comprador (E-mail OTP, Google, GitHub), fulfillment sem emissão duplicada, promoção de edição na mesma chave (`Demo`/`Trial` para `Full`) e aceite legal.
- **[Releases, Rollback e Avisos](developers/RELEASES.md):** preparação de pacotes no GitHub Releases, `release-manifest.json`, proxy assinado, verificação `SHA256` em streaming, canais `stable` vs. `beta`, rollback em 1 clique e `Updates & Notices`.
- **[Conversão Nativa de DCTL para OFX](developers/DCTL.md):** empacotamento de scripts `.dctl` e LUTs 3D em plugins `.ofx.bundle` nativos (Metal/OpenCL) sem programar C++, sugestão de nome e slug, validação no sandbox e publicação gratuita ou comercial no Discovery.
- **[Controle por Hardware MIDI (NexControl)](developers/MIDI.md):** integração com `MCNexControl.h`, perfis embutidos vs. perfis JSON customizados (Tier 1), controles na bandeja e foco do nó ativo.

## 1. Intake do projeto

As integrações são revisadas e provisionadas por projeto. Para iniciar uma integração, copie o formulário abaixo e envie para [hello@mcnexus.app](mailto:hello@mcnexus.app) (ou use o [formulário de sugestão de plugin](https://github.com/ciqueira/MCNexus/issues/new?template=plugin_suggestion.yml) para projetos gratuitos/open-source).

### Formulário para copiar e preencher

```text
Nome do Projeto / Plugin:
Desenvolvedor / Marca:
E-mail de Contato:
URL do Repositório ou Site:
Plano de Distribuição: Gratuito (Comunidade) / Comercial Start / Comercial Pro / Comercial SDK
Modo de Uso da SDK: Plugin + App MCNexus / Distribuidor Próprio / Aplicação Standalone
Backend de Licença: OpenKey (nativo) / Cryptlex / Indefinido
Plataformas Alvo: macOS Universal / Windows x64 / Windows ARM
Origem de Releases: GitHub Releases Público / GitHub Releases Privado
Checkout (se comercial): Stripe Direto / Loja Externa
E-mail de Suporte e URLs Jurídicas (Termos, Privacidade, Reembolso):
```

## 2. Onde a SDK embarca

A `NexKeyRuntime` é um núcleo único em C/C++ (`ABI 1.0`) projetado para operar em três formatos:

1. **No plugin (caminho crítico):** o plugin OFX ou pacote DCTL vincula a SDK para decisões atômicas `< 1 ns` na thread de render, exibição de avisos e integração opcional com `NexControl` MIDI, enquanto o aplicativo MCNexus cuida em segundo plano de ativação, download, update em 1 clique e rollback.
2. **Em app de distribuição próprio:** instaladores, hubs ou launchers próprios do desenvolvedor embarcam a SDK para ativar vagas, sincronizar licenças em lote, consultar releases e exibir avisos sob sua própria interface.
3. **Em software nativo standalone:** aplicativos desktop, ferramentas CLI (`nexkeyctl`) e nós de render farm headless embarcam a SDK de ponta a ponta para ativação online ou air-gap sem aplicativo cliente externo.

No plano gratuito Comunidade, embarcar a SDK é opcional para distribuir binários compilados pelo MCNexus.

## 3. Providers integrados

Cada camada da plataforma opera isolada sob contrato explícito:

| Camada | Disponível em produção hoje | No roadmap |
|---|---|---|
| **Identidade** | Código por E-mail (OTP), Google OAuth, GitHub OAuth | Microsoft, Apple Sign-In |
| **Licenciamento** | OpenKey (nativo), Cryptlex | Motores externos próprios |
| **Checkout** | Stripe Direto (0% de comissão da plataforma) | Lemon Squeezy, Shopify, Pix |
| **Origem de releases** | GitHub Releases público ou privado | Cloudflare R2, AWS S3, GitLab Releases |
| **E-mail transacional** | MailerLite (Commerce) | Relays SMTP customizados |

## 4. Próximos passos

1. Teste localmente no [Sandbox da SDK NexKeyRuntime](https://github.com/ciqueira/NexKeyRuntime/tree/main/sandbox) (com chaves prontas, plugin OFX de referência, empacotador DCTL e CLI `nexkeyctl`).
2. Revise o [Guia Legal para Tenants](TENANT_LEGAL_GUIDE.md) se for publicar um produto comercial.
3. Envie o formulário preenchido para [hello@mcnexus.app](mailto:hello@mcnexus.app).

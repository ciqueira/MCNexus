<img src="../images/Nexus-Brand.png" alt="MCNexus" width="360">

---

[English](../README.md) · [Português](README.md)

**Licenciamento, distribuição e atualização de software nativo que roda offline.**

O Nexus é infraestrutura para licenciar, distribuir e atualizar software nativo
de desktop: certificados de ativação assinados por tenant e vinculados a uma
máquina, uma janela de validade offline que sobrevive a dias sem rede, entrega
protegida de releases e rollback para uma versão anterior. O MCNexus é o
aplicativo para macOS e Windows que executa ativação, instalação, atualizações
e rollback na estação de trabalho.

O núcleo de licenciamento não é específico de OFX: um certificado de ativação
tem escopo de tenant e máquina, não de produto ou formato de plugin. Plugins
OFX para hosts de pós-produção são onde ele roda em produção hoje, e toda
integração em operação agora é um projeto OFX.

As integrações para desenvolvedores são configuradas por projeto. As vendas
correm pela conta Stripe do próprio desenvolvedor: a compra registra o pedido,
emite a licença, entrega a chave por revelação única, envia o e-mail
transacional e guarda quais termos o cliente aceitou. O mesmo backend emite a licença de um
produto gratuito ou pago, então passar a cobrar não exige trocar de provedor de
licenciamento, e quem já usa outra plataforma de licenciamento pode mantê-la.
Outros providers, outros tipos de software e o onboarding público self-service
estão no [roadmap](docs/ROADMAP.md).

<table>
  <tr>
    <td width="65%">
      <img src="../images/screen_app.png" alt="Aplicativo MCNexus" width="100%">
    </td>
    <td>
      <a href="https://apps.microsoft.com/detail/9n1qqt1xc825?hl=pt-BR&gl=BR">
        <img src="https://get.microsoft.com/images/pt-br%20light.svg" width="200" alt="Disponível na Microsoft Store" />
      </a>
      <br>
      <small>Opção recomendada para Windows</small>
      <br><br>
      <a href="https://github.com/ciqueira/MCNexus/releases/download/windows-latest/MCNexus-Setup-Windows.exe">
        <img src="https://img.shields.io/badge/Baixar_para-Windows-0078D4?style=for-the-badge" alt="Baixar para Windows">
      </a>
      <br>
      <a href="https://github.com/ciqueira/MCNexus/releases/download/macos-latest/MCNexus-macOS.dmg">
        <img src="https://img.shields.io/badge/Baixar_para-macOS-000000?style=for-the-badge" alt="Baixar para macOS">
      </a>
    </td>
  </tr>
</table>

A **Microsoft Store é o canal oficial e recomendado para instalação no Windows**, garantindo integridade de código e atualizações automáticas em segundo plano. O instalador `.exe` continua disponível no GitHub como alternativa para instalação manual.

> **Observação sobre a instalação:** o instalador direto para Windows distribuído pelo GitHub ainda não possui assinatura de código e pode exibir um alerta do Microsoft Defender SmartScreen. A versão para macOS ainda não possui assinatura com certificado Apple Developer ID nem notarização pela Apple, portanto o Gatekeeper também pode exibir um alerta. Os downloads oficiais estão disponíveis na Microsoft Store e neste repositório.

## Plugins Integrados

Lista de plugins OFX integrados ao Nexus.

[Ver plugins integrados](docs/DISCOVERY.md) · [Indicar um plugin](https://github.com/ciqueira/MCNexus/issues/new?template=plugin_suggestion.yml)

## Operação em Ilhas de Pós-Produção

O MCNexus cuida do ciclo de vida dos plugins instalados na estação de trabalho, da primeira ativação à instalação de uma versão anterior.

- **Instalação automática:** baixa e instala os arquivos OFX no diretório nativo definido pelo sistema operacional.
- **Atualização e rollback:** identifica versões publicadas e permite instalar uma atualização ou retornar a uma versão anterior disponível.
- **Ações independentes:** ativar uma licença, desativá-la, remover a chave local e remover os arquivos do plugin são operações diferentes.
- **Transferência entre computadores:** quando o computador anterior está acessível, a licença pode ser desativada nele antes da ativação em outra máquina. Liberações remotas e ajustes de ativações continuam sendo tratados pelo suporte.

[Começar pelo Guia de Operação](docs/USER_GUIDE.md)

<img src="../images/infor-app_pt-br.jpg" alt="Fluxo de licença, ativação, instalação e gerenciamento de plugins no MCNexus" width="100%">

## Para Desenvolvedores

Backend, SDK nativa e aplicativo cliente, para software nativo que roda
offline, comercial ou open source. As integrações são revisadas e configuradas
por projeto; o onboarding self-service público está no
[roadmap](docs/ROADMAP.md). Toda integração em produção hoje é um plugin OFX.

- **Ativação node-lock.** Cada ativação é um certificado Ed25519, assinado por
  uma chave com escopo de um único tenant e preso ao fingerprint da máquina,
  com limite de vagas por licença e desativação em autoatendimento — a vaga é
  liberada pelo próprio usuário, sem passar pelo suporte. Dois backends emitem
  essa licença: o **OpenKey**, nativo do Nexus, e o **Cryptlex**, para quem já
  o usa como plataforma. Os dois fazem node-lock; a diferença é de quem é a
  plataforma, não do mecanismo.
  → [Modelos de distribuição](docs/DEVELOPERS.md#2-modelos-de-distribuição)

- **Offline e air-gap.** Um produto licenciado não pede permissão a um servidor
  para funcionar: a SDK verifica o certificado contra um keyring público
  compilado dentro do binário, na máquina, sem rede. O certificado carrega dois
  prazos independentes — `syncAfter`, quando a thread em segundo plano começa a
  *tentar* renovar (padrão 24 h), e `offlineValidUntil`, o limite rígido que a
  própria SDK aplica (padrão 30 dias, configurável por licença até 365). O
  emissor aplica uma trava sobre os dois: a janela offline cobre sempre pelo
  menos duas tentativas inteiras de renovação, de modo que uma sincronização com
  falha jamais seja o que nega uma licença. Uma máquina sem rede nenhuma ativa e
  desativa por arquivos exportados, pelo mesmo caminho.
  → [Por que uma interrupção não é uma negação](docs/CONTINUITY.md#1-por-que-uma-interrupção-não-é-uma-negação)
  · [Ativação offline na SDK](https://github.com/ciqueira/NexKeyRuntime/blob/main/docs/OFFLINE.md)

- **NexKeyRuntime, a SDK nativa.** C/C++14 com ABI C estável, para macOS
  universal (arm64 e x86_64) e Windows x64. Na thread de render a decisão de
  licença é uma única leitura atômica: sem lock, sem alocação, sem syscall, sem
  rede, sem I/O de arquivo e sem parsing de JSON. Dois perfis de integração: no
  **Perfil A** o MCNexus ativa a licença e o produto a verifica localmente; no
  **Perfil B** o produto ativa, sincroniza e desativa por conta própria, sem
  aplicativo cliente no caminho. O repositório publica o contrato completo sob
  Apache-2.0 — o header C, os JSON Schemas, a documentação de integração e
  exemplos; os binários compilados saem como releases com checksums, sob a
  licença dos binários. A API é estável desde a `1.0`: função, layout de struct
  ou código de resultado que já existe nunca muda de um jeito que quebre um
  binário já compilado — em `1.x` só entra mudança aditiva, e quebra de
  compatibilidade exigiria `2.0`.
  → [NexKeyRuntime](https://github.com/ciqueira/NexKeyRuntime)
  · [Integração](https://github.com/ciqueira/NexKeyRuntime/blob/main/docs/INTEGRATION.md)
  · [Política de ABI](https://github.com/ciqueira/NexKeyRuntime/blob/main/docs/ABI_POLICY.md)
  · [JSON Schemas](https://github.com/ciqueira/NexKeyRuntime/tree/main/schemas)
  · [SDK de cliente](docs/DEVELOPERS.md#7-sdk-de-cliente-nexkeyruntime)

- **Cliente MCNexus.** Para plugin OFX, o aplicativo para macOS e Windows ativa
  a licença e executa instalação, atualização e rollback na estação de trabalho
  — um produto do Perfil A não precisa escrever, assinar nem distribuir um
  cliente próprio. Ativar, desativar, remover a chave local e remover os
  arquivos do plugin são operações independentes.
  → [Guia de Operação](docs/USER_GUIDE.md)

- **Posse de chave e continuidade.** O que a SDK confia é o keyring do produto,
  não o servidor: quem detém a metade privada de uma chave desse keyring pode
  emitir certificados que cópias já instaladas aceitam, sem nenhuma
  infraestrutura do Nexus envolvida. O keyring comporta até quatro chaves, e uma
  chave aposentada continua nele e apenas para de assinar — por isso a rotação
  não invalida o que já está instalado. A chave de recuperação é gerada pelo
  próprio desenvolvedor: só a metade pública é enviada, um envio que contenha a
  metade privada é **recusado**, e ela não assina nada em operação normal.
  → [Se o operador não estiver mais disponível](docs/CONTINUITY.md#3-se-o-operador-não-estiver-mais-disponível)

- **Distribuição e rollback.** Os releases vêm da origem configurada para o
  projeto e são servidos por um proxy de download com token assinado de vida
  curta — o aplicativo nunca recebe a URL real do release. Pacotes por
  plataforma, descoberta de versão e reinstalação de uma versão publicada
  anterior quando um release quebra um projeto. A verificação criptográfica de
  integridade dos pacotes está no [roadmap](docs/ROADMAP.md).
  → [Segurança e distribuição](docs/DEVELOPERS.md#6-segurança-e-distribuição)

- **Edições e entitlements.** Beta, Demo, Trial e Full, as mesmas quatro num
  projeto gratuito ou pago — Trial tem prazo, Demo não. Quando um produto sai em
  várias variantes dentro do mesmo release, os entitlements por asset dizem o
  que cada licença libera, e o escopo de ativação é único por tenant,
  fingerprint e entitlement: a mesma máquina não ocupa duas vagas do mesmo
  direito. Em produtos Cryptlex, as edições e os limites de ativação vêm da
  conta do próprio desenvolvedor.
  → [Canais e edições](docs/DEVELOPERS.md#4-canais-e-edições)

- **Commerce e fulfillment.** As vendas correm pela conta Stripe do próprio
  desenvolvedor. Configurado uma vez, um catálogo de ofertas liga preço,
  produto, conta de pagamento e as URLs de termos, privacidade e reembolso
  apresentadas no checkout. A cada venda o Nexus registra o pedido, o evento de
  pagamento e qual versão dos termos o cliente aceitou, cria ou atualiza a
  licença e entrega a chave por revelação única, com e-mail transacional. As
  tentativas de fulfillment são registradas por pedido, então um evento de
  pagamento reenviado não emite uma segunda licença. Produtos Cryptlex têm a
  licença emitida pelo canal do próprio desenvolvedor; emiti-la pelo Nexus
  Commerce está no [roadmap](docs/ROADMAP.md).
  → [Fluxo Nexus Commerce atual](docs/DEVELOPERS.md#5-fluxo-nexus-commerce-atual)
  · [Providers integrados](docs/DEVELOPERS.md#8-providers-integrados)

- **Avisos dentro do produto.** Severidades `critical`, `recommended` e `info`,
  com conteúdo localizado e segmentação por host, faixa de versão do plugin,
  plataforma e arquitetura. O usuário dispensa ou adia um aviso, e o produto
  define a própria política de checagem e quantos avisos mostra de uma vez. O
  conteúdo é texto: HTML, Markdown arbitrário e script ficaram fora por decisão
  de escopo. Chega pelo mesmo canal das atualizações.
  → [Updates e avisos na SDK](https://github.com/ciqueira/NexKeyRuntime/blob/main/docs/UPDATES_AND_NOTICES.md)

[Entender a integração para desenvolvedores](docs/DEVELOPERS.md)

<img src="../images/infor-back_pt-br.jpg" alt="Nexus backend workflow" width="100%">

## Compatibilidade do Aplicativo

- **macOS:** macOS 15 ou posterior, incluindo Apple Silicon e Macs Intel compatíveis.
- **Windows:** Windows 10/11 x64, com suporte ao Windows 11 ARM por emulação x64.
- **Linux:** em consideração quando os plugins compatíveis e a demanda dos
  usuários justificarem o ciclo adicional de plataforma.

## Projeto

O Nexus combina engenharia de software com experiência prática em pós-produção
audiovisual. Desenvolvido de forma independente por
[Magno Ciqueira](https://www.linkedin.com/in/ciqueira/)
([Instagram](https://www.instagram.com/magnociqueira/)), o projeto tem como
objetivo reduzir fricções técnicas e oferecer infraestrutura de distribuição
para ferramentas comerciais e de código aberto.

## Documentação

- [Discovery](docs/DISCOVERY.md)
- [Guia de Operação](docs/USER_GUIDE.md)
- [Documentação para Desenvolvedores](docs/DEVELOPERS.md)
- [Perguntas Frequentes](docs/FAQ.md)
- [Roadmap](docs/ROADMAP.md)
- [Continuidade e Recuperação](docs/CONTINUITY.md)
- [Licença](../LICENSE.md)
- [Aviso sobre o Código-Fonte](../NOTICE.md)
- [Aviso de Marcas](../TRADEMARKS.md)
- [Política de Segurança](../SECURITY.md)
- [Termos de Uso](TERMS.md)
- [Política de Privacidade](PRIVACY.md)
- [Guia de Documentação Legal por Tenant](docs/TENANT_LEGAL_GUIDE.md)

## Disponibilidade do Código-Fonte

Este repositório é público para transparência e revisão. Ele é source-available, mas não é software open source. Redistribuição, builds não oficiais, produtos derivados e uso da marca MCNexus exigem autorização prévia por escrito. Consulte [LICENSE.md](../LICENSE.md), [NOTICE.md](../NOTICE.md) e [TRADEMARKS.md](../TRADEMARKS.md).

## Suporte

Problemas técnicos, dúvidas de ativação, relatórios de falhas e sugestões devem ser registrados pelos [formulários de suporte do GitHub](https://github.com/ciqueira/MCNexus/issues/new/choose). Inclua a versão do sistema operacional, a versão do MCNexus, o plugin afetado e os diagnósticos disponíveis.

O GitHub Issues é público e indexado por mecanismos de busca. Não publique uma chave de licença completa nem dados pessoais. Solicitações de privacidade devem ser enviadas para [hello@mcnexus.app](mailto:hello@mcnexus.app).

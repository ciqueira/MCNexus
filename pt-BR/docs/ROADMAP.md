# Roadmap do Nexus

[English](../../docs/ROADMAP.md) · [Português](ROADMAP.md)

[Início](../README.md) · [Discovery](DISCOVERY.md) · [Guia de Operação](USER_GUIDE.md) · [Desenvolvedores](DEVELOPERS.md) · [FAQ](FAQ.md) · [Continuidade](CONTINUITY.md)

Última atualização: 3 de setembro de 2026

Este roadmap separa capacidades implementadas, trabalho atual, trabalho
planejado e itens em consideração. As limitações conhecidas e os requisitos de
validação restantes aparecem junto ao trabalho relacionado. O roadmap não
atribui datas especulativas.

## Como Interpretar Este Roadmap

- Um item marcado significa que a capacidade está implementada no código e no
  modelo operacional atual. Isso não representa, por si só, um SLA,
  certificação independente de segurança, compatibilidade universal com hosts
  ou conformidade jurídica automática.
- Um item não marcado ainda não está disponível como capacidade completa. Seu
  escopo pode mudar conforme sejam coletados testes, evidências de produção e
  feedback de desenvolvedores.
- A Microsoft Store é o canal oficial e recomendado no Windows. O instalador
  direto do Windows ainda não possui assinatura de código, e a versão para
  macOS ainda não possui assinatura Apple Developer ID nem notarização.
- As integrações de desenvolvedores ainda são revisadas e configuradas por
  projeto. Não existe uma API pública de onboarding nem um portal do
  desenvolvedor totalmente self-service.
- O núcleo de licenciamento não é específico de OFX, mas plugins OFX são o
  único tipo de software com integrações em produção. Toda capacidade marcada
  como implementada abaixo deve ser lida como disponível hoje para projetos
  OFX, independentemente do que a arquitetura permita em princípio.
- As capacidades Commerce e o piloto inicial do Color Equalizer estão
  implementados. Uma divulgação mais ampla continua condicionada à ampliação
  dos testes operacionais de ponta a ponta e às revisões jurídica e contábil
  aplicáveis.
- Cada camada de provider — identidade, pagamento, licenciamento, fulfillment,
  e-mail e origem de releases — é separada por um contrato explícito. O que está
  conectado hoje, e o que está no roadmap de cada camada, está em
  [Desenvolvedores](DEVELOPERS.md) §8.
- O multi-tenant interno não é apresentado como uma oferta SaaS pública.
  Organizações externas, membros e RBAC, onboarding público, cobrança do
  serviço por tenant e operação contratual SaaS continuam como trabalho futuro.

## Escopo do Produto

O Nexus gerencia licenciamento, entrega de releases, instalação, atualizações e
rollback de software nativo que precisa continuar funcionando sem conexão de
rede. Ele recebe uma licença, compra ou concessão autorizada, resolve o
entitlement e o release aplicáveis e disponibiliza o artefato ao cliente.

A plataforma é organizada em duas camadas, que avançam de forma independente.

- **Núcleo de licenciamento — independente de host.** Certificados de ativação
  assinados por tenant, vínculo de máquina, entitlements, controle de seats,
  janela de validade offline, política de sincronização e trilha de auditoria.
  Um certificado de ativação tem escopo de tenant e máquina; ele não carrega
  produto, artefato ou formato de plugin.
- **Tipos de software — específicos de host.** Convenções de empacotamento,
  diretórios de instalação, ciclo de vida do host e a experiência do cliente
  para um tipo de software. **Plugins OFX para hosts de pós-produção são o
  único tipo atendido em produção**, entregues pelo MCNexus no macOS e no
  Windows.

- **Usuários finais** usam o MCNexus para ativar licenças, instalar software,
  verificar atualizações, instalar versões anteriores e executar rollback.
- **Desenvolvedores** utilizam integrações configuradas de licenciamento,
  Commerce, releases e comunicação.

O OpenKey é o License Provider mantido como parte do Nexus. O Commerce gerencia
ofertas, pedidos, pagamentos e fulfillment. Atualmente, o GitHub é usado para
identidade e artefatos de release nos fluxos OpenKey e Commerce descritos
abaixo.

A arquitetura planejada permite outros providers de identidade, licenciamento,
pagamento, e-mail e releases. O GitHub deverá se tornar opcional. Outros tipos
de software são trabalho planejado e não estão disponíveis hoje; o perfil da
SDK que permite a um produto ativar uma licença sem o MCNexus no fluxo está
implementado, mas abri-lo a desenvolvedores fora do Nexus depende da licença de
binário e do trabalho de onboarding listados abaixo. O trabalho SaaS planejado
adiciona organizações externas, controle de acesso, onboarding, cobrança do
serviço e isolamento de tenants.

## Capacidades Implementadas

### Experiência Desktop e Distribuição

- [x] **Distribuição oficial no Windows:** o MCNexus está disponível na
  [Microsoft Store](https://apps.microsoft.com/detail/9n1qqt1xc825), canal
  oficial e recomendado no Windows, com distribuição gerenciada pela Store e
  atualizações automáticas em segundo plano. O instalador direto permanece
  disponível como alternativa, com a limitação de assinatura descrita acima.
- [x] **Aplicativos nativos para macOS e Windows:** clientes específicos por
  plataforma para ativação de licenças, gerenciamento de plugins, detecção de
  atualizações, instalação de versões anteriores e rollback.
- [x] **Instalação e remoção de OFX:** instalação automática nos diretórios
  nativos do sistema, separação explícita entre ações de licença e plugin,
  recuperação de instalação e comportamento transparente na desinstalação.
- [x] **Estados operacionais claros:** o usuário consegue distinguir licenças
  ativas e inativas, produtos indisponíveis, plugins ausentes, problemas
  locais, atualizações e opções de rollback.

### Plataforma de Licenciamento e Releases

- [x] **Suporte a OpenKey e Cryptlex:** o backend OpenKey nativo do Nexus emite
  a licença de um produto gratuito e de um pago, pela mesma experiência no
  aplicativo do backend alternativo Cryptlex. Os dois fazem ativação vinculada
  ao hardware, por node-lock.
- [x] **Licenciamento multiproduto orientado por entitlements:** produtos,
  edições, plugins e múltiplas licenças do mesmo tenant permanecem separados
  durante ativação, sincronização, cache e instalação.
- [x] **Entrega protegida de releases:** artefatos por plataforma, resolução
  autenticada de downloads, streaming seguro, descoberta de versões e rollback
  sem exposição das chaves de licença.
- [x] **Sincronização agregada de dispositivos:** várias licenças podem ser
  verificadas e renovadas em uma solicitação, preservando seus ciclos de vida
  independentes.
- [x] **Janela de validade offline:** um certificado de ativação carrega dois
  prazos independentes — quando a renovação começa a ser tentada e o limite
  rígido que a própria SDK aplica. A janela padrão é de 30 dias, configurável
  por licença até 365, e o emissor garante que ela sempre cubra pelo menos
  duas tentativas inteiras de renovação, de modo que uma única falha de sync
  nunca seja o que nega uma licença. A validação ponta a ponta em instalações
  reais é acompanhada separadamente em Continuidade, abaixo.
- [x] **Ativação offline para máquinas sem rede:** uma máquina pode exportar
  uma requisição de ativação, receber um certificado emitido em outro lugar e
  instalá-lo sem nunca alcançar a rede; o mesmo caminho devolve a vaga com uma
  prova de desativação. Os certificados são verificados contra o keyring do
  produto na importação e em toda carga posterior, então essa rota não
  enfraquece nada. Usada em instalações air-gapped, e é o mesmo mecanismo em
  que o caminho de recuperação em Continuidade se apoia.
- [x] **SDK pública de cliente (NexKeyRuntime):** uma SDK C/C++14 para
  descoberta de atualizações, avisos de produto e verificação offline de
  certificados de ativação, publicada em
  [github.com/ciqueira/NexKeyRuntime](https://github.com/ciqueira/NexKeyRuntime).
  Seu contrato público — o header C, os schemas JSON, os exemplos e a
  documentação de integração — é Apache-2.0, e bibliotecas estáticas compiladas
  para macOS (universal) e Windows x64 são publicadas como releases com
  checksums. Dois limites se aplicam e estão listados como trabalho separado
  abaixo: a API ainda é `0.x` e pode evoluir, e a licença que rege os binários
  compilados é um rascunho.

### Commerce e Operação de Clientes

- [x] **Fundação Commerce independente de provider:** identidade, pagamento,
  licença, fulfillment, entrega e e-mail são separados por contratos explícitos
  em vez de depender de uma única composição de checkout.
- [x] **Fluxo de compra autenticado pelo Stripe:** identidade verificada pelo
  GitHub, proteção contra compras duplicadas, contas de pagamento por ambiente,
  Prices multimoeda, fulfillment idempotente e revelação protegida da chave.
- [x] **Piloto Commerce do Color Equalizer:** três pedidos já foram processados
  em produção pelo fluxo de compra configurado. Isso valida que o mecanismo
  funciona ponta a ponta; não é tração de vendas.
- [x] **Registros operacionais de compra:** ofertas, pedidos, pagamentos,
  benefícios de suporte, fulfillment e entrega de e-mail são administrados
  separadamente da licença técnica e ficam visíveis no Back Office.
- [x] **Comunicação e evidência jurídica auditáveis:** mensagens operacionais
  evitam entregas duplicadas, permitem reenvio controlado e preservam as
  versões dos documentos, idioma, aceite e referências da transação associados
  a cada pedido Commerce.

### Operação e Segurança da Plataforma

- [x] **Back Office multi-tenant interno:** produtos, tenants, releases,
  licenças, ativações, contas de pagamento, Commerce Offers e histórico
  operacional são gerenciados por acesso administrativo protegido.
- [x] **Controles de segurança:** configuração de tenants cifrada, tokens de
  sessão protegidos, payloads de licença protegidos, rate limiting, controles
  na borda da rede, cabeçalhos de segurança e registros estruturados de
  auditoria.
- [x] **Pipeline de entrega controlado:** mudanças de backend e migrations de
  banco seguem gates versionados de verificação, staging e promoção. Os pacotes
  para macOS e Windows são produzidos como artefatos específicos de cada
  plataforma por workflows versionados de release.
- [x] **Validação de compatibilidade de releases:** os links públicos
  existentes de claim, compra, ativação e download foram verificados após as
  mudanças de providers e caminhos legados e estão operacionais.
- [x] **Documentação operacional:** documentação bilíngue para usuários,
  desenvolvedores, aspectos jurídicos, suporte e solução de problemas acompanha
  a plataforma.

## Trabalho Atual

O trabalho atual cobre assinatura de código, verificação de pacotes,
comportamento de licenças e ampliação da validação e das operações Commerce.

- [ ] **Assinatura de código e validação de releases:** assinar o instalador
  direto do Windows, assinar e notarizar o aplicativo macOS, validar o
  comportamento do Gatekeeper e do SmartScreen e testar releases em máquinas
  limpas. A Microsoft Store permanece como o canal oficial no Windows durante
  esse trabalho.
- [ ] **Integridade de pacotes:** verificar os pacotes de plugin baixados antes
  da instalação. A publicação de metadados autoritativos por release já existe
  — cada release carrega um manifest declarando seus artefatos e os requisitos
  de cliente correspondentes, e o download é recusado quando um cliente não os
  atende. O que resta é a verificação de checksum do artefato baixado na
  estação, antes de instalar.
- [ ] **Consistência do ciclo de licença:** concluir a validação de reuso de
  ativações, os refinamentos do ciclo OpenKey e a paridade de comportamento
  entre macOS e Windows.
- [ ] **Cobertura do Commerce em produção e operações jurídicas:** ampliar a
  validação controlada para meios de pagamento, moedas, revisão pelo Radar,
  entrega, benefícios de suporte, logs e cenários de recuperação; adicionar
  fluxos de reembolso e disputa, visibilidade do país de cobrança, exportações
  financeiras, cancelamento eletrônico e as revisões jurídica e contábil
  exigidas para o lançamento.

## Planejado — Self-Service

- [ ] **Portal do cliente:** permitir que clientes consultem compras e
  licenças, gerenciem ativações, recuperem acesso e encontrem o canal correto de
  suporte. Mover uma licença entre máquinas já funciona sem suporte quando a
  máquina anterior está acessível — online ou air-gapped. O que este item
  acrescenta é o caso em que essa máquina foi perdida, formatada ou não liga
  mais, que hoje passa pelo formulário de problema de ativação.
- [ ] **Verificação de integridade de plugins:** detectar e reportar
  instalações ausentes, incompatíveis, incompletas ou bloqueadas. O período
  offline que este item incluía está implementado e listado em Plataforma de
  Licenciamento e Releases acima; o que resta aqui é a metade de integridade
  da instalação.
- [ ] **Kit de integração para desenvolvedores:** a SDK de cliente já está
  publicada e documentada, e os formatos de dados que ela consome —
  ProductData, o certificado de ativação e o manifest de atualização — estão
  publicados como JSON Schemas (ver NexKeyRuntime acima). Falta a especificação
  do manifest de *release*, que é um documento diferente, descrevendo os
  artefatos de uma release e os requisitos de cliente de cada um, além do fluxo
  de integridade de pacotes e dos testes de integração para macOS, Windows e
  projetos OFX.
- [ ] **Licença de binário para terceiros:** a licença que rege os releases
  compilados do NexKeyRuntime é um rascunho pendente de revisão, de modo que os
  binários publicados ainda não estão liberados para uso por desenvolvedores
  fora do Nexus. O conteúdo do próprio repositório continua Apache-2.0 e
  utilizável hoje. É isso, e não a disponibilidade da SDK, que hoje trava a
  adoção por terceiros.
- [ ] **Compromisso de estabilidade de API:** enquanto a SDK estiver em `0.x`,
  sua API pública pode evoluir. Os códigos de resultado são append-only por
  política e nunca são reutilizados ou renumerados, mas nenhum compromisso de
  compatibilidade 1.0 foi assumido.
- [ ] **Integração entre OpenKey e Commerce:** oferecer entitlements gratuitos
  ou pagos pelo mesmo fluxo, com o GitHub disponível como adapter de identidade
  e releases em vez de uma dependência obrigatória.
- [ ] **License Providers conectados ao Commerce:** concluir o fulfillment
  idempotente e reconciliável pelo Cryptlex e depois validar o Keygen ou outro
  backend de licenciamento pelos mesmos contratos Commerce.
- [ ] **Framework de integração direta de providers:** normalizar contas de
  providers, mappings de produtos e preços, eventos assinados, idempotência,
  reconciliação e ownership da conta antes de conectar outro provider
  comercial.
- [ ] **Separação de providers de e-mail:** manter mensagens operacionais e
  audiências de marketing consentidas em contratos diferentes e depois validar
  um provider transacional adicional.
- [ ] **Distribuição independente do canal comercial:** aceitar eventos
  normalizados de compra, concessão e entitlement originados no Nexus Commerce
  ou em canais externos autorizados e encaminhá-los pelo mesmo ciclo de
  distribuição.
- [ ] **Flexibilidade da origem de releases:** ampliar as origens atuais de
  releases pelo GitHub Releases e Cryptlex com armazenamento controlado
  compatível com S3, sem alterar a experiência de instalação, atualização e
  rollback no cliente.
- [ ] **Publicação assistida para desenvolvedores:** padronizar onboarding de
  produtos, credenciais, validação de releases e publicação antes de abrir
  essas operações como totalmente self-service.
- [ ] **Ciclo de vida do tenant:** substituir exclusões destrutivas por
  políticas controladas de desativação, retenção, exportação, restauração e
  exclusão final que preservem o histórico necessário de licenças, ativações,
  compras e auditoria.
- [ ] **Entrega assíncrona:** adicionar filas, retries automáticos,
  reconciliação de suppressions e bounces e monitoramento de entrega
  independente de provider.

## Planejado — Continuidade e Portabilidade de Tenants

Este é um trabalho planejado, não uma capacidade ou garantia atual. O desenho
técnico poderá evoluir conforme amadureçam o modelo de licenciamento, os
requisitos operacionais e o feedback de desenvolvedores. Um mecanismo
documentado e testado será necessário antes que o MCNexus seja apresentado
como infraestrutura com continuidade assegurada para desenvolvedores
comerciais externos.

[Continuidade e Recuperação](CONTINUITY.md) documenta os cenários cobertos, o
que já vale hoje e o que ainda é intenção, não capacidade.

- [ ] **Política de continuidade:** definir cenários de indisponibilidade
  temporária, encerramento planejado e indisponibilidade do operador,
  incluindo aviso quando possível, responsabilidades, condições de liberação
  e o tratamento de licenças perpétuas e assinaturas.
- [ ] **Portabilidade de dados e artefatos do tenant:** oferecer exportações
  documentadas e versionadas de produtos, releases, licenças, entitlements e
  registros de ativação, permitindo que desenvolvedores mantenham e
  redistribuam seus próprios artefatos de release verificados.
- [ ] **Caminho de recuperação independente:** um mecanismo de escopo restrito
  e verificável criptograficamente pelo qual um desenvolvedor possa ativar
  clientes legítimos de seus próprios produtos sem o serviço hospedado do
  Nexus. O desenho está definido e o mecanismo está implementado — uma chave
  de recuperação gerada pelo desenvolvedor, cuja metade pública viaja no
  keyring do produto e cuja metade privada nunca chega ao Nexus, mais um
  caminho de emissão offline que não consulta infraestrutura nenhuma. Este
  item permanece aberto até a verificação abaixo ser concluída; ver
  [Continuidade e Recuperação](CONTINUITY.md).
- [ ] **Verificação de recuperação:** documentar e testar o fluxo escolhido em
  ambientes limpos do macOS e Windows com os serviços hospedados indisponíveis,
  incluindo a rejeição de licenças e pacotes modificados, não assinados,
  expirados ou fora de escopo.

## Planejado — Além de OFX

O núcleo de licenciamento é independente de host, mas atender um tipo de
software é mais do que licenciamento: exige convenções de empacotamento,
diretórios de instalação, tratamento do ciclo de vida do host e uma
experiência de cliente. Nenhum dos itens abaixo está disponível hoje, e não
há ordem nem data comprometida entre eles.

- [ ] **Ativação independente de host (Perfil B da SDK) para terceiros:** a
  SDK implementa ativação, sincronização e desativação sem o MCNexus no fluxo,
  e as rotas do gateway que ela chama estão em operação. A capacidade não é a
  lacuna. Falta tudo o que está em volta dela para um desenvolvedor fora do
  Nexus: uma licença de binário aprovada e uma forma de obter um tenant e um
  blob ProductData sem uma conversa de configuração projeto a projeto.
- [ ] **Runtimes além de C e C++:** avaliar quais bindings de linguagem são
  efetivamente necessários para os runtimes que desenvolvedores independentes
  distribuem, antes de assumir qualquer compromisso.
- [ ] **Outros hosts de plugin:** avaliar formatos de plugin de áudio e demais
  hosts de vídeo, 3D e CAD. Cada host exige seu próprio adapter de
  empacotamento e instalação, e cada um é uma decisão separada.
- [ ] **Aplicações desktop standalone:** atender desenvolvedores que distribuem
  o próprio instalador e precisam de licenciamento, atualizações e rollback sem
  adotar o MCNexus como cliente de entrega.
- [ ] **Suporte a Linux:** hoje limitado pela identificação de máquina e pela
  ausência de um ciclo de vida de plataforma, não pelo modelo de licenciamento.

## Planejado — Preparação para SaaS

Este trabalho é necessário antes que uma organização externa de
desenvolvedores possa configurar e operar produtos pelo serviço.

- [ ] **Organizações, membros e RBAC:** introduzir a fronteira
  Organization/Seller com proprietários, membros, papéis e acesso de menor
  privilégio aos produtos e operações.
- [ ] **Portal do desenvolvedor e onboarding:** oferecer configuração guiada de
  organização, vendedor, produto, contas de providers, perfil jurídico e
  releases, com validação antes da ativação em produção.
- [ ] **Ownership e isolamento de tenants:** vincular produtos, credenciais,
  contas de pagamento e e-mail, evidências jurídicas e histórico de auditoria a
  uma organização; adicionar autorização, rotação de chaves e testes de
  isolamento entre tenants.
- [ ] **Configuração jurídica self-service:** oferecer documentos versionados
  do vendedor e do produto, herança controlada, histórico de publicação,
  evidências de aceite e gates de lançamento por ambiente.
- [ ] **Cobrança do serviço Nexus:** definir planos, quotas, medição de uso,
  trial, ciclo de assinatura e cobrança do serviço Nexus separadamente das
  transações Commerce realizadas por cada vendedor de plugins.
- [ ] **Pacote jurídico e operacional do SaaS:** estabelecer contrato de
  serviço, DPA, lista de subprocessadores, política de uso aceitável, política
  de suporte, SLA/SLOs, resposta a incidentes, exportação de dados e processo de
  encerramento.
- [ ] **Resiliência do serviço:** oferecer auditoria e observabilidade por
  organização, verificação de backup e restauração, controles de capacidade e
  objetivos de recuperação documentados.

## Em Consideração

Estas direções serão avaliadas depois dos marcos anteriores e não representam
compromissos com um provider ou uma data específica.

- [ ] **Integrações de checkout:** avaliar novas origens de pedidos além da
  composição atual com Stripe, normalizando seus eventos no Nexus Commerce e
  entregando licenças pelo License Provider configurado.
  - **Checkouts comerciais:** avaliar primeiro o Lemon Squeezy; comparar Polar,
    Dodo Payments e FastSpring depois da fundação independente de provider e
    dos gates atuais do Commerce.
  - **Checkouts diretos adicionais:** avaliar PayPal/Braintree como alternativa
    global para pagamentos diretos, recorrência e métodos de pagamento
    adicionais.
  - **Checkouts e storefronts existentes:** avaliar Gumroad, ThriveCart,
    Sellfy, Shopify e WooCommerce somente quando um desenvolvedor integrado
    tiver uma necessidade operacional concreta.
  - **Checkouts regionais:** avaliar Mercado Pago e PagBank quando meios de
    pagamento locais no Brasil ou na América Latina forem uma necessidade
    validada.
- [ ] **Integrações de licenciamento:** avaliar Keygen depois da conclusão do
  fulfillment Commerce pelo Cryptlex e comparar LicenseSpring como outro
  candidato de licenciamento e versionamento de produtos.
- [ ] **Releases e distribuição de artefatos:** validar armazenamento
  compatível com S3, usando Cloudflare R2 como primeiro alvo de implementação,
  e avaliar Keygen Software Distribution, Cloudsmith e GitLab Releases como
  soluções gerenciadas. Armazenamento, catálogo de versões e autorização de
  download devem permanecer capacidades independentes no Nexus.
- [ ] **E-mail transacional:** comparar Postmark e Resend para comunicação
  operacional e avaliar Cloudflare Email Service depois de sua estabilização.
  Mailchimp permanece candidato separado para marketing consentido.
- [ ] **Identidade:** avaliar WorkOS AuthKit, Clerk e ZITADEL para identidade,
  organizações e acesso no futuro modelo SaaS, mantendo o GitHub como adapter
  dos fluxos atuais durante a transição.
- [ ] Recursos de Commerce internacional, como precificação regional,
  relatórios ampliados de moedas e suporte fiscal por mercado quando houver
  necessidade operacional.
- [ ] Licenciamento para equipes, assentos, bundles e modelos mais ricos de
  produtos e entitlements.
- [ ] Aplicativo nativo para Linux quando os plugins compatíveis e a demanda dos
  usuários justificarem o ciclo adicional de plataforma.
- [ ] Relatórios de falha e insights de produto opcionais, com privacidade,
  para desenvolvedores participantes.
Os candidatos acima pressupõem contas de providers conectadas diretamente pelo
Nexus para seu próprio serviço ou por cada vendedor para seus produtos. Um
marketplace operado pelo Nexus, uma conta Merchant of Record agregada e um
modelo de valores compartilhados entre vendedores estão fora do escopo atual.

## Princípios de Desenvolvimento

- Validar um fluxo operacional completo antes de expandi-lo para mais produtos
  ou providers.
- Preservar fronteiras de domínio independentes de provider e evitar que
  direitos do cliente dependam do estado interno de um serviço terceiro.
- Manter a distribuição independente de um único canal comercial, backend de
  licenciamento, provider de pagamento, provider de e-mail ou host de releases.
- Manter compatibilidade com links públicos, licenças, releases e histórico de
  auditoria por meio de migrations explícitas.
- Tratar isolamento de tenants, segurança, privacidade e capacidade de
  recuperação como requisitos de produto, não como trabalho posterior de
  infraestrutura.
- Promover o trabalho por evidências e gates de lançamento; prioridades podem
  mudar conforme descobertas de produção e feedback de desenvolvedores sejam
  validados.

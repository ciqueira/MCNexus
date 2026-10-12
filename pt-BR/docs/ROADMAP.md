# Roadmap do Nexus

[English](../../docs/ROADMAP.md) · [Português](ROADMAP.md)

[Início](../README.md) · [Discovery](DISCOVERY.md) · [Guia de Operação](USER_GUIDE.md) · [Desenvolvedores](DEVELOPERS.md) · [FAQ](FAQ.md) · [Continuidade](CONTINUITY.md)

Última atualização: 12 de outubro de 2026

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
- O núcleo de licenciamento não é específico de OFX. Plugins OFX para hosts de
  pós-produção são o tipo de software atendido hoje; outros tipos são trabalho
  planejado, listado adiante.
- As capacidades Commerce estão implementadas. Uma divulgação mais ampla
  continua condicionada à ampliação dos testes operacionais de ponta a ponta e
  às revisões jurídica e contábil aplicáveis.
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
  tipo atendido hoje**, entregues pelo MCNexus no macOS e no Windows.

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
- [x] **Integridade de pacotes:** os pacotes de plugin baixados são verificados
  antes da instalação. Cada release carrega um manifest declarando seus
  artefatos e os requisitos de cliente correspondentes, e o download é recusado
  quando um cliente não os atende; além disso, cada artefato é publicado com um
  digest SHA256 que o aplicativo confere contra o arquivo baixado antes de
  instalar. Um pacote cujo digest não confere é recusado e descartado, nunca
  instalado.
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
  checksums. A API pública é estável desde a `1.0`, sob a política de
  compatibilidade publicada no repositório.
- [x] **Licença de binário para terceiros:** a licença que rege os releases
  compilados do NexKeyRuntime (`BINARY_LICENSE.md`) está finalizada, liberando
  os binários publicados para uso por desenvolvedores fora do Nexus. Embutir o
  binário no seu produto é gratuito em qualquer plano Nexus, inclusive o plano
  gratuito Comunidade; um plano comercial só é exigido se o produto que você
  distribui cobrar dos próprios usuários finais. O conteúdo do próprio
  repositório continua Apache-2.0 e utilizável hoje.

### Commerce e Operação de Clientes

- [x] **Fundação Commerce independente de provider:** identidade, pagamento,
  licença, fulfillment, entrega e e-mail são separados por contratos explícitos
  em vez de depender de uma única composição de checkout.
- [x] **Fluxo de compra autenticado pelo Stripe:** identidade verificada pelo
  GitHub, proteção contra compras duplicadas, contas de pagamento por ambiente,
  Prices multimoeda, fulfillment idempotente e revelação protegida da chave.
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
- [x] **Documentação operacional:** documentação bilíngue para usuários,
  desenvolvedores, aspectos jurídicos, suporte e solução de problemas acompanha
  a plataforma.

## Trabalho Atual

O trabalho atual cobre assinatura de código, comportamento de licenças e
ampliação da validação e das operações Commerce.

- [ ] **Assinatura de código e validação de releases:** assinar o instalador
  direto do Windows, assinar e notarizar o aplicativo macOS, validar o
  comportamento do Gatekeeper e do SmartScreen e testar releases em máquinas
  limpas. A Microsoft Store permanece como o canal oficial no Windows durante
  esse trabalho.
- [ ] **Consistência do ciclo de licença:** concluir a validação de reuso de
  ativações, os refinamentos do ciclo OpenKey e a paridade de comportamento
  entre macOS e Windows.
- [ ] **Cobertura do Commerce em produção e operações jurídicas:** ampliar a
  validação controlada para meios de pagamento, moedas, revisão pelo Radar,
  entrega, benefícios de suporte, logs e cenários de recuperação; adicionar
  fluxos de reembolso e disputa, visibilidade do país de cobrança, exportações
  financeiras, cancelamento eletrônico e as revisões jurídica e contábil
  exigidas para o lançamento.

## Planejado — Proteção de Propriedade Intelectual e Segurança

Este trabalho avança além da segurança de transporte para a proteção de runtime
da propriedade intelectual, elevando o custo matemático e de engenharia contra
adulterações binárias não autorizadas, sem comprometer a estabilidade do host
nem os orçamentos de tempo real de renderização.

- [ ] **Asset & Shader Vault (proteção de ativos GPU em memória):** empacotamento
  criptografado (AES-256) de shaders compilados para GPU (Metal, HLSL, CUDA),
  modelos de inferência de redes neurais e tabelas de convolução. Shaders e kernels
  são decodificados Just-in-Time diretamente na memória gráfica ou do processo
  vinculados a um certificado ativo, sem nunca gravar arquivos-fonte desprotegidos
  no disco do host.
- [ ] **Licenciamento cripto-funcional:** derivação criptográfica de constantes
  essenciais de processamento, matrizes de transformação de cor e coeficientes
  DSP diretamente de certificados Ed25519 verificados e do fingerprint de
  hardware da máquina. Substitui checagens booleanas facilmente contornáveis por
  dependências funcionais, garantindo que o algoritmo só processe o resultado
  legítimo quando matematicamente autenticado.
- [ ] **Ancoragem em enclave de hardware:** vinculação do node-lock aos chips
  dedicados de segurança de hardware da estação de trabalho (Apple Secure Enclave
  no macOS e TPM 2.0 no Windows), elevando a proteção contra clonagem de
  identidade de máquina e execução em ambientes virtualizados forjados.

## Planejado — Experiência Desktop e Fluxos de Estúdio

- [ ] **Ações em massa (Update All e Install All):** fila centralizada em
  segundo plano no MCNexus para baixar e verificar múltiplos plugins licenciados
  em paralelo, com instalação sequencial e segura quando as aplicações host
  estiverem fechadas.
- [ ] **Version Lock e perfil de estúdio:** fixação de versões em nível de projeto
  ou suíte de edição, permitindo que estúdios de pós-produção mantenham paridade
  exata de versões entre todas as ilhas durante produções longas, evitando
  atualizações acidentais em meio a entregas ativas.
- [ ] **Interface Dark-First calibrada:** interface de usuário desenvolvida com
  tons de cinza rigorosamente neutros para eliminar desvios de adaptação
  cromática de coloristas, combinada com presença discreta na bandeja/menu bar
  sem consumo ocioso de recursos do sistema.

## Planejado — Self-Service

- [ ] **Portal do cliente:** permitir que clientes consultem compras e licenças,
  gerenciem ativações, recuperem acesso e liberem máquinas perdidas ou inoperantes
  sem necessidade de suporte manual. A migração entre máquinas acessíveis já
  funciona de forma self-service online e air-gapped; este item cobre máquinas
  permanentemente inacessíveis.
- [ ] **Verificação de integridade de plugins:** detectar e reportar instalações
  ausentes, incompatíveis, incompletas ou bloqueadas, bem como divergências de
  versão do host e arquitetura.
- [ ] **Kit de integração para desenvolvedores:** especificação do manifest de
  release, requisitos de ativos, fluxo de integridade de pacotes e testes
  automatizados de integração para macOS, Windows e projetos nativos.
- [ ] **Integração de providers desacoplados:** suporte a autenticação por e-mail
  e magic-link além do GitHub, conexões diretas normalizadas de meios de
  pagamento e roteamento independente de e-mails transacionais.
- [ ] **Flexibilidade de armazenamento de releases:** expansão da entrega de
  artefatos de release com armazenamento compatível com S3 e Cloudflare R2 sem
  alterar a verificação de hash ou o rollback no cliente.
- [ ] **Publicação para desenvolvedores e ciclo do tenant:** padronização do
  onboarding, checklists de publicação e ciclo de vida controlado do tenant
  (desativação, retenção e exportação de dados).

## Planejado — Continuidade e Portabilidade de Tenants

Este é um trabalho planejado, não uma capacidade ou garantia atual. O desenho
técnico poderá evoluir conforme amadureçam o modelo de licenciamento, os
requisitos operacionais e o feedback de desenvolvedores. Um mecanismo
documentado e testado será necessário antes que o MCNexus seja apresentado
como infraestrutura com continuidade assegurada para desenvolvedores
comerciais externos.

[Continuidade e Recuperação](CONTINUITY.md) documenta os cenários cobertos, o
que já vale hoje e o que ainda é intenção, não capacidade.

- [ ] **Verificação de recuperação:** testar e validar o mecanismo de chave de
  recuperação criptográfica existente em ambientes limpos de macOS e Windows
  com os serviços hospedados indisponíveis, verificando a emissão offline e a
  rejeição estrita de licenças adulteradas ou fora de escopo.
- [ ] **Portabilidade de dados e artefatos do tenant:** oferecer exportações
  documentadas e versionadas de produtos, releases, licenças, entitlements e
  registros de ativação, permitindo que desenvolvedores mantenham e redistribuam
  seus próprios artefatos de release verificados.

## Planejado — Além de OFX

O núcleo de licenciamento é independente de host, mas atender um tipo de
software é mais do que licenciamento: exige convenções de empacotamento,
diretórios de instalação, tratamento do ciclo de vida do host e uma
experiência de cliente. Nenhum dos itens abaixo está disponível hoje, e não
há ordem nem data comprometida entre eles.

- [ ] **Formatos de plugins de áudio profissional:** adapters de empacotamento
  e instalação nativa para plugins de áudio (VST3, Audio Units, AAX), oferecendo
  aos desenvolvedores de áudio uma alternativa moderna e sem dongles aos sistemas
  legados de proteção contra cópia.
- [ ] **Bindings de linguagens para a SDK C:** wrappers de primeira classe para
  .NET, Python, Rust e Swift sobre a API C estável do NexKeyRuntime, permitindo
  que ferramentas de pipeline de estúdio, scripts e aplicações standalone usem o
  licenciamento do Nexus.
- [ ] **Ativação independente de host (Perfil B da SDK) para terceiros:** onboarding
  self-service e provisionamento de ProductData para desenvolvedores que distribuem
  instaladores próprios sem o MCNexus como cliente de entrega.
- [ ] **Suporte a Linux:** execução em estações de trabalho e nós de render, hoje
  limitado pela identificação de máquina e pelo ciclo de vida da plataforma, não
  pelo núcleo de licenciamento.

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

- [ ] Licenças flutuantes em rede local (Pool Flutuante LAN) para compartilhamento
  dinâmico de assentos entre ilhas de edição e nós de render sem dependência de
  conexão contínua com a internet.
- [ ] Recursos de Commerce internacional, como precificação regional,
  relatórios ampliados de moedas e suporte fiscal por mercado quando houver
  necessidade operacional.
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

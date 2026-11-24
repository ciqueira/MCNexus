# Roadmap do Nexus

[English](../../docs/ROADMAP.md) · [Português](ROADMAP.md)

[Início](../README.md) · [Discovery](DISCOVERY.md) · [Guia de Operação](USER_GUIDE.md) · [Desenvolvedores](DEVELOPERS.md) · [FAQ](FAQ.md) · [Continuidade](CONTINUITY.md)

Última atualização: 17 de novembro de 2026

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
- Cada camada de provider (identidade, pagamento, licenciamento, fulfillment,
  e-mail e origem de releases) é separada por um contrato explícito. O que está
  conectado hoje, e o que está no roadmap de cada camada, está em
  [Desenvolvedores](DEVELOPERS.md).
- O multi-tenant interno não é apresentado como uma oferta SaaS pública.
  Organizações externas, membros e RBAC, onboarding público, cobrança do
  serviço por tenant e operação contratual SaaS continuam como trabalho futuro.

## Escopo do Produto

O Nexus gerencia licenciamento, entrega de releases, instalação, atualizações e
rollback de software nativo que precisa continuar funcionando sem conexão de
rede. Ele recebe uma licença, compra ou concessão autorizada, resolve o
entitlement e o release aplicáveis e disponibiliza o artefato ao cliente.

A plataforma é organizada em duas camadas, que avançam de forma independente.

- **Núcleo de licenciamento (independente de host):** Certificados de ativação
  assinados por tenant, vínculo de máquina, entitlements, controle de seats,
  janela de validade offline, política de sincronização e trilha de auditoria.
  Um certificado de ativação tem escopo de tenant e máquina; ele não carrega
  produto, artefato ou formato de plugin.
- **Camada de entrega (específica de host):** Convenções de empacotamento,
  diretórios de instalação, ciclo de vida do host e a experiência do cliente
  para um tipo de software. **Plugins OFX para hosts de pós-produção são o
  tipo atendido hoje**, entregues pelo MCNexus no macOS e no Windows.

- **Usuários finais** usam o MCNexus para ativar licenças, instalar software,
  verificar atualizações, instalar versões anteriores e executar rollback.
- **Desenvolvedores** utilizam integrações configuradas de licenciamento,
  Commerce, releases e comunicação.

O OpenKey é o License Provider mantido como parte do Nexus. O Commerce gerencia
ofertas, pedidos, pagamentos e fulfillment. Códigos de verificação por e-mail e
login com Google operam hoje ao lado do GitHub para identidade do usuário nos
fluxos OpenKey e Commerce descritos abaixo, enquanto o GitHub permanece como a
origem atual dos artefatos de release.

A arquitetura planejada permite outros providers de identidade, licenciamento,
pagamento, e-mail e releases, tornando o GitHub opcional também como host de
releases. Outros tipos de software fora do padrão OFX são trabalho planejado e
não são atendidos pelo MCNexus hoje; o modo autocontido da SDK que permite a
um produto ativar uma licença sem o MCNexus no fluxo já está implementado e
coberto pela licença finalizada de binários para terceiros, enquanto o
onboarding completo por autoatendimento permanece listado adiante. O trabalho
SaaS planejado adiciona organizações externas, controle de acesso, onboarding,
cobrança do serviço e isolamento de tenants.

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
- [x] **Estados operacionais claros:** você consegue distinguir licenças
  ativas e inativas, produtos indisponíveis, plugins ausentes, problemas
  locais, atualizações e opções de rollback.
- [x] **Sincronização discreta em segundo plano e economia de recursos:**
  verificações periódicas de licença rodam em lotes espaçados sem interromper o
  playback ou a renderização ativa no host, monitoram a disponibilidade de rede
  de forma passiva e aguardam a conexão estabilizar antes de reconectar,
  exibem aviso claro com botão imediato de ressincronização quando a janela de
  tolerância offline expira, pausam verificações desnecessárias enquanto o
  aplicativo fica minimizado na bandeja ou na barra de menus e restauram a tela
  instantaneamente ao reabrir.
- [x] **Distribuição de DCTLs como plugins OFX:** scripts DCTL e LUTs podem ser
  empacotados em plugins `.ofx.bundle` nativos, assinados e criptografados,
  permitindo distribuir e licenciar efeitos pelo MCNexus sem precisar programar
  um plugin do zero. Suporte nativo para todas as principais GPUs no Windows e
  proteção de chaves gerenciada pela plataforma seguem no trabalho atual e
  planejado.
- [x] **Suporte a controladoras MIDI externas (NexControl):** suporte a controle
  físico por hardware para plugins OFX compatíveis no macOS e no Windows com
  atalhos e status ao vivo na bandeja do sistema e na barra de menus, seleção
  individual de portas MIDI (com auto-seleção inicial e estado `Busy`), perfis
  embutidos e mapeamentos customizados, modo genérico `Auto-Detect` com
  diagnóstico ao vivo, paginação por bancos virtuais, agrupamento de Undo no
  host, resposta em tempo real no visualizador e acompanhamento automático do
  nó em foco tanto no macOS quanto no Windows.

### Plataforma de Licenciamento e Releases

- [x] **Suporte a OpenKey e Cryptlex:** o backend OpenKey nativo do Nexus emite
  a licença de um produto gratuito e de um pago, pela mesma experiência no
  aplicativo do backend alternativo Cryptlex. Os dois fazem ativação vinculada
  ao hardware, por node-lock.
- [x] **Licenciamento multiproduto orientado por entitlements:** produtos,
  edições, plugins e múltiplas licenças do mesmo tenant permanecem separados
  durante ativação, sincronização, cache e instalação.
- [x] **Separação entre canais de release (`stable` e `beta`):** o backend
  restringe licenças padrão, trial e demo estritamente a releases estáveis,
  garantindo que pré-releases cheguem apenas a licenças beta. Um seletor visual
  de canal dentro do aplicativo desktop permanece em Trabalho Atual.
- [x] **Entrega protegida de releases:** artefatos por plataforma, resolução
  autenticada de downloads, streaming seguro, descoberta de versões e rollback
  sem exposição das chaves de licença.
- [x] **Integridade de pacotes:** os pacotes de plugin baixados são verificados
  antes da instalação. Cada release carrega um manifest declarando seus
  artefatos e os requisitos de cliente correspondentes, e o download é recusado
  quando um cliente não os atende; além disso, cada artefato é publicado com um
  digest SHA256 que o aplicativo confere contra o arquivo baixado antes de
  instalar. Um pacote cujo digest não confere é recusado e descartado, nunca
  instalado. A verificação dos cenários de rejeição de pacotes e a exigência
  estrita de checksum também em builds beta seguem na validação contínua de
  releases.
- [x] **Sincronização agregada de dispositivos:** várias licenças podem ser
  verificadas e renovadas em uma solicitação, preservando seus ciclos de vida
  independentes.
- [x] **Janela de validade offline:** um certificado de ativação carrega dois
  prazos independentes: quando a renovação começa a ser tentada e o limite
  rígido que a própria SDK aplica. A janela padrão é de 30 dias, configurável
  por licença até 365, e o emissor garante que ela sempre cubra pelo menos
  duas tentativas inteiras de renovação, de modo que uma única falha de sync
  nunca seja o que nega uma licença.
- [x] **Ativação offline para máquinas sem rede:** uma máquina pode exportar
  uma requisição de ativação, receber um certificado emitido em outro lugar e
  instalá-lo sem nunca alcançar a rede; o mesmo caminho devolve a vaga com uma
  prova de desativação. Os certificados são verificados contra o keyring do
  produto na importação e em toda carga posterior, então essa rota não
  enfraquece nada. Usada em instalações air-gapped, e é o mesmo mecanismo em
  que o caminho de recuperação em Continuidade se apoia.
- [x] **Autoridade de recuperação sob custódia do desenvolvedor:** uma chave
  offline Ed25519 de recuperação gerada pelo desenvolvedor cuja metade privada
  nunca passa pelos servidores do Nexus, permitindo emitir certificados de
  emergência aceitos pelos produtos instalados sem depender de infraestrutura
  externa.
- [x] **SDK pública de cliente (NexKeyRuntime):** uma SDK nativa em C/C++ para
  descoberta de atualizações, avisos de produto e verificação offline de
  certificados de ativação, publicada em
  [github.com/ciqueira/NexKeyRuntime](https://github.com/ciqueira/NexKeyRuntime).
  Seu contrato público (o header C, definições JSON, exemplos e documentação de
  integração) é Apache-2.0, e bibliotecas estáticas compiladas para macOS
  (universal) e Windows (x64, x86 e ARM) são publicadas como releases com
  checksums. A API pública é estável desde a `1.0`, evoluindo de forma aditiva
  sob a política de compatibilidade publicada no repositório.
- [x] **Licença de binário para terceiros:** a licença que rege os releases
  compilados do NexKeyRuntime (`BINARY_LICENSE.md`) está finalizada, liberando
  os binários publicados para uso por desenvolvedores fora do Nexus. Embutir o
  binário no seu produto é gratuito em qualquer plano Nexus, inclusive o plano
  gratuito Comunidade; um plano comercial só é exigido se o produto que você
  distribui cobrar dos próprios usuários finais. O conteúdo do próprio
  repositório continua Apache-2.0 e utilizável hoje.
- [x] **Sandbox Local para Desenvolvedores (Fase 1):** um ambiente isolado de
  testes com chaves pré-provisionadas, um plugin OFX de referência, um
  utilitário de linha de comando e o empacotador de efeitos DCTL permite testar
  licenciamento, atualizações, avisos e controle MIDI localmente antes do
  onboarding formal. Uma demonstração guiada com checkout na web segue em
  Trabalho Atual.

### Commerce e Operação de Clientes

- [x] **Fundação Commerce independente de provider:** identidade, pagamento,
  licença, fulfillment, entrega e e-mail são separados por contratos explícitos
  em vez de depender de uma única composição de checkout.
- [x] **Identidade flexível para compra e resgate (E-mail verificado, Google e
  GitHub):** clientes podem obter chaves gratuitas ou concluir compras comerciais
  usando código de verificação por e-mail ou conta Google sem exigir conta no
  GitHub, ao lado do login pelo GitHub.
- [x] **Fluxo de compra autenticado pelo Stripe:** identidade do comprador
  verificada (código por e-mail, Google ou GitHub), proteção contra compras
  duplicadas, contas de pagamento por ambiente, Prices multimoeda, fulfillment
  sem emissão duplicada, promoção automática de edição de avaliação para completa na
  mesma chave e revelação protegida da chave.
- [x] **Registros operacionais de compra:** ofertas, pedidos, pagamentos,
  benefícios de suporte, fulfillment e entrega de e-mail são administrados
  separadamente da licença técnica e ficam visíveis no Back Office.
- [x] **Comunicação e evidência jurídica auditáveis:** mensagens operacionais
  evitam entregas duplicadas, permitem reenvio controlado e preservam as
  versões dos documentos, idioma, aceite e referências da transação associados
  a cada pedido Commerce.

### Operação e Segurança da Plataforma

- [x] **Back Office multi-tenant interno:** produtos, tenants (incluindo criação
  padronizada e arquivamento de tenants), releases, licenças, ativações, contas
  de pagamento, Commerce Offers e histórico operacional são gerenciados por
  acesso administrativo protegido.
- [x] **Cache resiliente de metadados de releases:** cache em múltiplas camadas
  protege a descoberta de atualizações no aplicativo e o download de artefatos
  contra limites de requisição da origem dos releases.
- [x] **Controles de segurança:** configuração de tenants cifrada, tokens de
  sessão protegidos, payloads de licença protegidos, rate limiting, controles
  na borda da rede, cabeçalhos de segurança e registros estruturados de
  auditoria.
- [x] **Pipeline de entrega controlado:** mudanças de backend e procedimentos de
  verificação seguem gates versionados de staging e promoção. Os pacotes para
  macOS e Windows são produzidos como artefatos específicos de cada plataforma
  por workflows versionados de release.
- [x] **Documentação operacional:** documentação bilíngue para usuários,
  desenvolvedores, aspectos jurídicos, suporte e solução de problemas acompanha
  a plataforma.

## Trabalho Atual

O trabalho atual cobre assinatura de código, consistência entre plataformas,
ampliação das operações Commerce e avaliação interativa por desenvolvedores.

- [ ] **Assinatura de código e validação de releases:** assinar o instalador
  direto do Windows, assinar e notarizar o aplicativo macOS, validar o
  comportamento do Gatekeeper e do SmartScreen, concluir a verificação negativa
  de integridade de pacotes e testar releases em máquinas limpas. A Microsoft
  Store permanece como o canal oficial no Windows durante esse trabalho.
- [ ] **Consistência do ciclo de licença e paridade entre plataformas:** concluir
  a validação de reuso de ativações e adicionar um seletor de canal beta na
  interface do aplicativo desktop.
- [ ] **Cobertura do Commerce em produção, cobrança de planos e operações
  jurídicas:** ampliar a validação controlada para meios de pagamento, moedas,
  revisão pelo Radar, entrega, benefícios de suporte, logs e cenários de
  recuperação; adicionar fluxos automáticos de reembolso e disputa, modelagem
  estruturada e imposição de planos de serviço para desenvolvedores,
  visibilidade do país de cobrança, exportações financeiras, cancelamento
  eletrônico e as revisões jurídica e contábil exigidas para o lançamento.
- [ ] **Sandbox Web Interativo (Fases 2 e 3) e recursos comerciais para pacotes
  DCTL:** entregar a demonstração guiada ponta a ponta combinando aplicativo
  desktop e checkout de teste para avaliação antes do onboarding; ampliar a
  compatibilidade nativa de GPU no Windows e implementar a proteção de chaves
  gerenciada pela plataforma para pacotes comerciais.

## Planejado: Proteção de Propriedade Intelectual e Segurança

Este trabalho avança além da segurança de transporte e empacotamento para a
proteção em execução da propriedade intelectual, elevando o custo contra
adulterações binárias não autorizadas sem comprometer a estabilidade do host nem
o desempenho em tempo real durante a reprodução.

- [ ] **Expansão do Asset & Shader Vault:** estender o pacote cifrado de efeitos
  com suporte nativo para todas as principais GPUs no Windows, proteção de chave
  de conteúdo gerenciada pela plataforma e vinculada diretamente a uma licença
  ativa, além de descarte imediato em memória para que código desprotegido
  nunca toque o disco.
- [ ] **Licenciamento cripto-funcional:** substituir verificações simples de
  permissão ou negação por dependências funcionais entre certificados de
  ativação verificados e vinculados à máquina e constantes essenciais de
  processamento, transformações de cor ou coeficientes de efeito, garantindo que
  o algoritmo só produza o resultado legítimo quando autenticado.
- [ ] **Ancoragem em hardware da estação de trabalho:** vincular a identidade da
  máquina aos recursos dedicados de segurança em hardware disponíveis em
  sistemas macOS e Windows compatíveis para resistir à clonagem de identidade e
  execução em ambientes virtualizados forjados.
- [ ] **Escudo Anti-Tampering e integridade em execução:** proteger os binários
  compilados do plugin contra engenharia reversa automatizada e alterações não
  autorizadas em memória durante a execução.

## Planejado: Experiência Desktop e Fluxos de Estúdio

- [ ] **Ações em massa (Update All e Install All):** fila centralizada em
  segundo plano no MCNexus para baixar e verificar múltiplos plugins licenciados
  em paralelo, com instalação sequencial e segura quando as aplicações host
  estiverem fechadas.
- [ ] **Version Lock e perfil de estúdio:** fixação de versões em nível de projeto
  ou suíte de edição, permitindo que estúdios de pós-produção mantenham paridade
  exata de versões entre todas as ilhas durante produções longas, evitando
  atualizações acidentais em meio a entregas ativas.
- [ ] **Licenciamento elástico e passes de render (Guest Pass e Overdraft):**
  proteções contra entregas atrasadas e marcas d'água acidentais em picos de
  produção, permitindo delegar passes temporários de curta duração para nós de
  renderização ou freelancers (inclusive em modo *headless*, executando render
  em segundo plano sem interface gráfica) e autorizar capacidade emergencial
  excedente (*overdraft*) com conciliação posterior garantida por recibos
  criptográficos locais.
- [ ] **Feedback bidirecional para controladoras MIDI e suporte ampliado de
  hardware:** retornar automaticamente os valores ativos dos parâmetros do
  plugin para faders motorizados e anéis de LED, ampliando a compatibilidade com
  superfícies de controle de estúdio.

## Planejado: Self-Service

- [ ] **Portal do cliente:** com a verificação por e-mail e o login com Google
  já em operação, permitir que clientes consultem compras e licenças, gerenciem
  ativações, recuperem acesso, liberem máquinas perdidas ou inoperantes sem
  suporte manual e encontrem o canal de suporte correto. A migração entre
  máquinas acessíveis já funciona por autoatendimento online e offline; este
  item cobre máquinas permanentemente inacessíveis.
- [ ] **Verificação de integridade de plugins e persistência de avisos:**
  detectar e reportar instalações ausentes, incompatíveis, incompletas ou
  bloqueadas, bem como divergências de versão do host e arquitetura, e lembrar
  entre sessões quais avisos de produto foram dispensados ou adiados pelo
  usuário.
- [ ] **Kit de integração para desenvolvedores e ferramentas visuais de
  publicação:** expandir os guias e o Sandbox Local (Fase 1) já publicados com
  edição e validação visual de manifests de release no Back Office, disparo
  automático de anúncios de novas versões e suítes automatizadas de teste
  multiplataforma.
- [ ] **Expansão de provedores de identidade, checkout e e-mail:** verificação
  por e-mail e login com Google já operam ao lado do GitHub; o trabalho restante
  adiciona provedores opcionais de login (como Microsoft e Apple), integrações
  padronizadas com novos provedores de pagamento e roteamento independente de
  e-mail transacional.
- [ ] **Flexibilidade de armazenamento de releases:** estender a entrega de
  artefatos de release para usar armazenamento compatível com S3 e Cloudflare R2
  conectado pelo próprio desenvolvedor, sem alterar a verificação nem o rollback
  no aplicativo.
- [ ] **Publicação para desenvolvedores e ciclo do tenant:** evoluir a partir do
  arquivamento de tenants já existente com fluxos padronizados de onboarding,
  checklists de publicação, limpeza automática de retenção e exportação completa
  de dados do tenant.

## Planejado: Continuidade e Portabilidade de Tenants

[Continuidade e Recuperação](CONTINUITY.md) documenta a arquitetura de
continuidade, as salvaguardas ativas e os cenários cobertos.

- [ ] **Portabilidade de dados e artefatos do tenant:** oferecer exportações
  documentadas e versionadas de produtos, releases, licenças, entitlements e
  registros de ativação, permitindo que desenvolvedores mantenham e redistribuam
  seus próprios artefatos de release verificados.

## Planejado: Além de OFX

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
  .NET, Python, Rust e Swift sobre a interface C estável do NexKeyRuntime,
  permitindo que ferramentas de pipeline de estúdio, scripts e aplicações
  standalone usem o licenciamento do Nexus.
- [ ] **Ativação independente de host (SDK autônoma sem App MCNexus) para terceiros:**
  onboarding self-service e entrega das credenciais de projeto para
  desenvolvedores que distribuem instaladores próprios sem o MCNexus como
  cliente de entrega.
- [ ] **Suporte a Linux:** execução em estações de trabalho e nós de render, hoje
  limitado pela identificação de máquina e pelo ciclo de vida da plataforma, não
  pelo núcleo de licenciamento.

## Planejado: Preparação para SaaS

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
- [ ] **Cobrança do serviço Nexus:** impor planos, quotas, medição de uso,
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
  auditoria por meio de atualizações explícitas.
- Tratar isolamento de tenants, segurança, privacidade e capacidade de
  recuperação como requisitos de produto, não como trabalho posterior de
  infraestrutura.
- Promover o trabalho por evidências e gates de lançamento; prioridades podem
  mudar conforme descobertas de produção e feedback de desenvolvedores sejam
  validados.

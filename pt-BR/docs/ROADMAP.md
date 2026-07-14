# Roadmap do Nexus

[English](../../docs/ROADMAP.md) · [Português](ROADMAP.md)

[Início](../README.md) · [Discovery](DISCOVERY.md) · [Guia de Operação](USER_GUIDE.md) · [Desenvolvedores](DEVELOPERS.md) · [FAQ](FAQ.md)

Este roadmap acompanha o que está operacional, em desenvolvimento e planejado para o Nexus.

## Implementado

### Aplicativo Cliente

- [x] **Aplicativo nativo para macOS:** cliente desktop para ativação de licenças, gerenciamento de plugins, controle de versões e atualizações em segundo plano.
- [x] **Aplicativo nativo para Windows:** cliente desktop WPF / .NET 8.0 com instalador, ativação de licenças, gerenciamento de plugins, detecção de atualizações, rollback e fluxo nativo de desinstalação.
- [x] **Instalação silenciosa de OFX:** instalação automática dos plugins nas pastas corretas.
- [x] **Gerenciamento separado de licença e plugin:** ativação, desativação, remoção da chave e remoção dos arquivos do plugin são ações separadas.
- [x] **Estados de licença claros:** as mensagens distinguem licenças ativas, licenças inativas, plugins ausentes, chaves suspensas, licenças indisponíveis e problemas locais de licença.
- [x] **Controle de versão e rollback de OFX:** verificação automática de versões, notificações de atualização, instalação de versões anteriores e rollback.
- [x] **Fluxo de recuperação de instalação:** ações para tentar novamente ou cancelar instalações, atualizações e rollbacks com falha.

### Backend

- [x] **Motor dinâmico multiproduto:** API stateless para gerenciar múltiplos produtos com atualização de configuração sem indisponibilidade.
- [x] **Segurança e hardening:** tokens de sessão protegidos, payloads de licença criptografados, proteção progressiva contra força bruta, rate limiting em múltiplas camadas, regras na borda da rede e cabeçalhos de segurança.
- [x] **Proxy de streaming:** downloads protegidos de arquivos binários sem expor as chaves de licença.
- [x] **Sincronização agregada de dispositivos:** sincronização de status e renovação de múltiplas licenças em uma única solicitação.
- [x] **Módulo de licenciamento OpenKey:** distribuição de projetos open source junto ao licenciamento comercial.
- [x] **Back Office administrativo:** portal interno para gerenciar licenças, ativações, lançamentos, produtos e tenants por meio de SSO empresarial.
- [x] **Commerce multi-tenant:** ofertas, pedidos, pagamentos e benefícios comerciais são administrados separadamente das licenças técnicas.
- [x] **Operação comercial no Back Office:** criação e validação de ofertas de teste e produção, contas de pagamento compartilhadas, identificação de licenças pagas e detalhes de compra e entrega.
- [x] **Atualizações de dados controladas:** mudanças da plataforma são versionadas e verificadas antes da publicação, com proteções adicionais para produção.

### Integração

- [x] **Licenciamento Cryptlex vinculado ao hardware:** validação vinculada ao fingerprint da máquina.
- [x] **Checkout Commerce autenticado:** identidade verificada pelo GitHub, prevenção de compras duplicadas, proteção do e-mail do comprador e emissão ou atualização segura da licença após a confirmação do pagamento.
- [x] **Conclusão e entrega imediata:** página de conclusão independente da origem da compra, com estados de espera e revisão e revelação protegida da chave.
- [x] **Fundação de providers desacoplada:** identidade, pagamento, licença, entrega e e-mail podem evoluir de forma independente, preservando os links GitHub existentes.
- [x] **Configuração Stripe por conta e ambiente:** uma conta pode atender várias ofertas e tenants, com separação segura entre testes e produção.
- [x] **Comunicação operacional pelo MailerLite:** entrega de licença e confirmação de suporte evitam mensagens duplicadas e usam grupos operacionais por tenant; marketing permanece separado e desabilitado sem consentimento específico.
- [x] **Evidência jurídica versionada:** pedidos Commerce registram URLs e versões dos documentos do vendedor e do produto, idioma, origem e data do aceite e referências da transação; pedidos legados são identificados quando a evidência não está disponível.
- [x] **Pipeline automatizado de CI/CD:** implantação do backend e lançamentos de DMG para macOS e instalador para Windows pelo GitHub Releases.
- [x] **Links de claim por GitHub OAuth:** distribuição self-service de licenças por autenticação do GitHub.
- [x] **Suporte e documentação operacional:** formulários estruturados para problemas do aplicativo, plugins e ativações, além de guia de operação e FAQ bilíngues.

### Infraestrutura de Lançamento

- [x] **Lançamentos específicos por plataforma:** artefatos separados para macOS e Windows.
- [x] **Instalador do Windows:** `MCNexus-Setup-v{VERSION}.exe` com atalhos no menu Iniciar, registro em Aplicativos e Recursos, metadados e suporte à desinstalação.
- [x] **Fluxo de desinstalação no Windows:** informa que plugins OFX podem permanecer, inclui opções para manter ou remover dados locais do aplicativo e das licenças e fecha o MCNexus quando necessário.

## Em Desenvolvimento

- [ ] **Hardening de lançamento:** assinatura de código no Windows, validação em máquina limpa e revisão final de falhas.
- [ ] **Hardening da distribuição no macOS:** assinatura com Apple Developer ID, notarização, validação pelo Gatekeeper e melhorias de empacotamento.
- [ ] **Identidade visual do produto:** ícone final do aplicativo, elementos visuais do instalador, imagens do produto e recursos da marca.
- [ ] **Confiabilidade de licenças:** validação do reuso de ativações, melhorias no ciclo de vida do OpenKey e paridade de estados entre plataformas.
- [x] **Suporte a múltiplas licenças do mesmo tenant por entitlement:** permitir que um mesmo tenant/produto apareça mais de uma vez quando o backend retornar plugins distintos, mantendo sync, cache e instalação separados por licença.
- [ ] **Piloto Commerce do Color Equalizer:** concluir a matriz de testes em produção controlada, revisar Radar, meios de pagamento, moeda internacional, logs, disputas, reembolsos e o gate fiscal/jurídico antes de ampliar a divulgação.
- [ ] **Operação e reconciliação do Commerce:** ampliar o acompanhamento de e-mails, moedas, país de cobrança e histórico financeiro, com filtros e ações administrativas auditáveis.
- [ ] **Benefício de suporte junto à licença:** transformar os meses de suporte incluídos na compra em um período efetivo com início, término, renovação e comunicação próprios.
- [ ] **Hardening jurídico por tenant:** preservar versões publicadas dos documentos, concluir o fluxo eletrônico de cancelamento e manter revisão jurídica e contábil como requisito de lançamento, sem declarar conformidade automática.
- [ ] **Limpeza de compatibilidade legada:** retirar integrações antigas somente após a confirmação de que os links públicos atuais continuam operacionais.
- [ ] **Melhorias contínuas da plataforma:** refinamentos no aplicativo, backend, infraestrutura, confiabilidade e lançamentos.

## Planejado

- [ ] **Evolução do suporte:** refinamento dos diagnósticos, ampliação da base de soluções e melhoria contínua dos formulários e guias.
- [ ] **Gerenciamento de tenants:** soft delete com preservação do histórico de licenças e ativações.
- [ ] **Portal do cliente:** gerenciamento self-service de licenças, ativações, solicitações de suporte e histórico de compras.
- [ ] **SDK OpenKey:** SDK nativo para macOS, Windows e clientes OFX, com ativação, validação, desativação, cache offline e verificações em runtime.
- [ ] **Fluxo de transferência de licença:** liberação e reativação self-service ao trocar de máquina.
- [ ] **Período de uso offline:** janela de uso offline para licenças ativadas.
- [ ] **Verificação de lançamentos assinados:** verificação dos pacotes de plugin baixados antes da instalação.
- [ ] **Kit de integração para desenvolvedores:** documentação e exemplos de integração para desenvolvedores de plugins.
- [ ] **Verificação de integridade do plugin:** detecção de instalações ausentes, incompatíveis ou bloqueadas.
- [ ] **Expansão das integrações Commerce:** compras com licenciamento Cryptlex, identidade por conta web ou magic link e um segundo serviço transacional de e-mail.
- [ ] **Configuração jurídica self-service por tenant:** árvore de documentos do operador, vendedor e produto, publicação versionada, herança controlada e histórico de aceite no portal.
- [ ] **Comércio internacional avançado:** melhor acompanhamento de moedas, precificação regional opcional e suporte fiscal por mercado quando a operação exigir.
- [ ] **Novas integrações de checkout:**
  - [ ] Paddle
  - [ ] FastSpring
  - [ ] Dodo Payments
  - [ ] polar.sh
  - [ ] Gumroad
- [ ] **Expansão multiplataforma:**
  - [ ] Aplicativo nativo para Linux.
- [ ] **Analytics e telemetria:** relatórios de uso e relatórios automáticos de falhas para desenvolvedores parceiros.

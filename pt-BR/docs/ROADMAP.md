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

### Integração

- [x] **Licenciamento Cryptlex vinculado ao hardware:** validação vinculada ao fingerprint da máquina.
- [x] **Automação do Stripe e parceiros de checkout:** cadastro de clientes, criação de contas e emissão de licenças.
- [x] **Comunicação transacional pelo MailerLite:** mensagens automáticas de boas-vindas e credenciais de ativação.
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
- [ ] **Novas integrações de checkout:**
  - [ ] Paddle
  - [ ] FastSpring
  - [ ] Dodo Payments
  - [ ] polar.sh
  - [ ] Gumroad
- [ ] **Expansão multiplataforma:**
  - [ ] Aplicativo nativo para Linux.
- [ ] **Analytics e telemetria:** relatórios de uso e relatórios automáticos de falhas para desenvolvedores parceiros.

# Releases, Rollback e Avisos

[English](../../../docs/developers/RELEASES.md) · [Português](RELEASES.md)

[Início](../../README.md) · [Guia do Desenvolvedor](../DEVELOPERS.md) · [Licenciamento](LICENSING.md) · [Commerce](COMMERCE.md) · [Releases](RELEASES.md) · [DCTL](DCTL.md) · [MIDI](MIDI.md)

## 1. Preparação de Pacotes e Release Manifest

Os releases são publicados como pacotes compilados por plataforma (`.zip` ou `.pkg` contendo o `.ofx.bundle`) no **GitHub Releases** público ou privado (suporte a Cloudflare R2, AWS S3 e GitLab Releases está no roadmap). Cada release pode incluir um arquivo `release-manifest.json` declarando:

- Sistema operacional e arquitetura (`macos-arm64`, `macos-x86_64`, `macos-universal`, `windows-x64`, `windows-arm64`).
- Versão mínima do cliente MCNexus e permissões de download por variante.
- Digest `SHA256` publicado por arquivo.

## 2. Entrega Protegida por Proxy e Verificação SHA256

O aplicativo MCNexus nunca recebe a URL real do GitHub ou do storage. Os downloads passam pelo proxy autenticado do MCNexus com tokens assinados de curta duração. Antes de instalar, o aplicativo desktop confere o digest `SHA256` em streaming e descarta qualquer arquivo divergente.

## 3. Canais de Release (stable vs. beta) e Rollback em 1 Clique

O servidor aplica a separação de canais na resolução do release: licenças `Full`, `Trial` e `Demo` recebem apenas releases `stable`, enquanto chaves `Beta` recebem prereleases `beta`. No aplicativo MCNexus, o usuário final atualiza em 1 clique ou seleciona qualquer versão anterior publicada para executar rollback imediato.

## 4. Updates e Avisos In-App

Plugins e aplicações standalone podem consultar a `NexKeyRuntimeHandle` por polling em cache não bloqueante para descobrir atualizações e avisos do fabricante sem travar a interface nem a thread de render.

- **Severidades:** `critical`, `recommended` e `info`.
- **Segmentação:** filtro por aplicativo host, faixa de versão do plugin, sistema operacional e arquitetura, com janela opcional de agendamento.
- **Localização e Segurança:** avisos suportam texto localizado em `EN` e `pt-BR` e aceitam estritamente **texto puro** (sem HTML, Markdown arbitrário ou scripts). Veja [UPDATES_AND_NOTICES.md da NexKeyRuntime](https://github.com/ciqueira/NexKeyRuntime/blob/main/docs/UPDATES_AND_NOTICES.md).
